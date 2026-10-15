import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:offline_music_player/providers/language_provider.dart';
import '../models/song.dart';
import 'db_helper.dart';
import 'equalizer_service.dart';

enum SwaraRepeatMode { off, all, one }

class PlayerService extends ChangeNotifier {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  final AudioPlayer _player = AudioPlayer();
  // Second player for crossfade, created lazily only when crossfade is
  // actually used, so idle playback never pays its memory cost.
  AudioPlayer? _crossfadePlayer;
  bool _usingCrossfadePlayer = false;

  // _queue: the original song list (source order, never changed by shuffle)
  List<Song> _queue = [];
  // _playOrder: the actual playback order (holds indices into _queue).
  // When shuffle is off: [0,1,2,...]. When shuffle is on: shuffled once,
  // kept stable across next/previous.
  List<int> _playOrder = [];
  int _posInOrder = 0;

  bool _shuffle = false;
  SwaraRepeatMode _repeatMode = SwaraRepeatMode.off;
  bool crossfadeEnabled = false;
  static const Duration crossfadeDuration = Duration(seconds: 3);

  Timer? _sleepTimer;
  DateTime? sleepTimerEndTime;
  int? sleepSongsRemaining;
  bool _finishCurrentSongOnSleep = false;
  bool _pendingSleepStop = false;
  // Sleep fade out state. When a time based timer expires in direct stop
  // mode, volume fades to 0 over [sleepFadeDuration] instead of pausing
  // at once. Generation guards against overlapping fades.
  bool _sleepFadeActive = false;
  int _sleepFadeGeneration = 0;
  static const Duration sleepFadeDuration = Duration(seconds: 30);
  // File path currently preloaded in the idle player (crossfade off only).
  // Best effort cache, never played directly from here.
  String? _preloadedFilePath;
  String? lastError;

  DateTime? _playStartedAt;
  int _accumulatedListenedMs = 0;

  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _crossfadeStateSub;
  bool _crossfadeTriggeredForCurrent = false;
  bool _crossfadeCancelled = false;
  bool _disposed = false;

  /// Subscribe to the active player position stream for crossfade triggers.
  /// Cancels any previous subscription first so only one stays active.
  Future<void> _subscribePosition() async {
    if (_disposed) return;
    await _positionSub?.cancel();
    _positionSub = null;
    if (_disposed) return;
    _positionSub = _activePlayer.positionStream.listen(_maybeStartCrossfade);
  }

  /// Stop listening to position updates to save battery while paused.
  Future<void> _unsubscribePosition() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  /// The player that is CURRENTLY audible (switches each time a crossfade finishes)
  AudioPlayer get _activePlayer {
    final crossfade = _crossfadePlayer;
    if (_usingCrossfadePlayer && crossfade != null) return crossfade;
    return _player;
  }

  /// The "standby" player used to fade in the next song. Creates the
  /// crossfade player on first real use so normal playback stays light.
  AudioPlayer get _fadeTargetPlayer {
    if (_usingCrossfadePlayer) return _player;
    return _ensureCrossfadePlayer();
  }

  /// Create the crossfade player on demand and attach its completion
  /// listener. Copies the current speed so the fade in starts in sync.
  AudioPlayer _ensureCrossfadePlayer() {
    final existing = _crossfadePlayer;
    if (existing != null) return existing;
    final created = AudioPlayer();
    _crossfadePlayer = created;
    created.setSpeed(_player.speed).catchError((Object e) {
      debugPrint('Crossfade speed sync failed: $e');
    });
    _crossfadeStateSub?.cancel();
    _crossfadeStateSub = created.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _usingCrossfadePlayer) {
        _logListening();
        _onTrackFinished();
      }
    });
    return created;
  }

  /// Release the standby crossfade player and drop the reference so it
  /// holds no audio resources. Skipped while it is the audible player;
  /// that case is released on the next track change instead.
  void _releaseCrossfadePlayer() {
    if (_usingCrossfadePlayer) return;
    _preloadedFilePath = null;
    _crossfadeStateSub?.cancel();
    _crossfadeStateSub = null;
    final standby = _crossfadePlayer;
    _crossfadePlayer = null;
    standby?.dispose().catchError((Object e) {
      debugPrint('Crossfade dispose failed: $e');
    });
  }

  AudioPlayer get player => _activePlayer;

  Song? get currentSong {
    if (_playOrder.isEmpty || _posInOrder < 0 || _posInOrder >= _playOrder.length) return null;
    return _queue[_playOrder[_posInOrder]];
  }

  bool get isShuffle => _shuffle;
  SwaraRepeatMode get repeatMode => _repeatMode;

  /// Queue in the actual playback order (used by the Queue page)
  List<Song> get queue => _playOrder.map((i) => _queue[i]).toList();
  int get currentIndex => _posInOrder;

  Future<void> init() async {
    await _playerStateSub?.cancel();
    await _unsubscribePosition();
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_usingCrossfadePlayer) {
        _logListening();
        _onTrackFinished();
      }
    });
    // The crossfade completion listener is attached inside
    // _ensureCrossfadePlayer, so nothing is created here. Reattach only
    // when the standby player already exists (for example after hot restart).
    final standby = _crossfadePlayer;
    if (standby != null) {
      await _crossfadeStateSub?.cancel();
      _crossfadeStateSub = standby.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && _usingCrossfadePlayer) {
          _logListening();
          _onTrackFinished();
        }
      });
    }
    // Subscribe only while playing so crossfade triggers keep working
    // without draining battery while paused.
    await _subscribePosition();
  }

  void _maybeStartCrossfade(Duration position) {
    // The guard only checks "already triggered for this song", and no longer
    // checks _usingCrossfadePlayer - so crossfade can trigger again for every
    // song instead of only once.
    if (!crossfadeEnabled || _crossfadeTriggeredForCurrent) return;
    final dur = _activePlayer.duration;
    if (dur == null) return;
    final remaining = dur - position;
    if (remaining <= crossfadeDuration && remaining > Duration.zero) {
      _crossfadeTriggeredForCurrent = true;
      _startCrossfadeToNext();
    }
  }

  Future<void> _startCrossfadeToNext() async {
    if (_playOrder.isEmpty) return;
    final nextPos = _computeNextPosition();
    if (nextPos == null) return;
    final nextSong = _queue[_playOrder[nextPos]];

    // Use the dynamic getters - never hardcode _player/_crossfadePlayer - so this
    // stays correct for ANY crossfade count, not just the first one.
    final outgoing = _activePlayer;
    final incoming = _fadeTargetPlayer;
    _crossfadeCancelled = false;

    try {
      await incoming.setFilePath(nextSong.filePath);
      // Move the equalizer to the incoming session as well.
      unawaited(EqualizerService.instance.attach(incoming));
      await incoming.setVolume(0);
      await incoming.play();

      const steps = 20;
      final stepDuration = crossfadeDuration ~/ steps;
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(stepDuration);
        if (_crossfadeCancelled || _disposed) break; // user pressed next/previous mid-crossfade
        final v = i / steps;
        await incoming.setVolume(v);
        await outgoing.setVolume(1 - v);
      }
      if (_crossfadeCancelled || _disposed) {
        // Cancelled halfway - clean up the standby player, do not swap
        await incoming.pause();
        await incoming.setVolume(1);
        await outgoing.setVolume(1);
        _crossfadeTriggeredForCurrent = false;
        return;
      }

      await outgoing.pause();
      await outgoing.setVolume(1);

      // IMPORTANT: record the listening history of the OLD song first (using
      // currentSong while it still points at the old song, before _posInOrder
      // moves), then reset the start clock for the NEW song - so
      // listening_entries never get the wrong attribution or doubled duration.
      _logListening();
      if (_disposed) return;
      _usingCrossfadePlayer = !_usingCrossfadePlayer;
      _posInOrder = nextPos;
      _playStartedAt = DateTime.now();
      _accumulatedListenedMs = 0;
      _crossfadeTriggeredForCurrent = false;
      await DBHelper.instance.markPlayed(nextSong.id);

      await _subscribePosition();

      notifyListeners();
    } catch (e) {
      debugPrint('Crossfade gagal, lanjut normal: $e');
      _crossfadeTriggeredForCurrent = false;
    }
  }

  int? _computeNextPosition() {
    // SwaraRepeatMode.one must be checked FIRST, before every other condition,
    // so crossfade also repeats the same song instead of moving to the next one.
    if (_repeatMode == SwaraRepeatMode.one) return _posInOrder;
    if (_posInOrder < _playOrder.length - 1) return _posInOrder + 1;
    if (_repeatMode == SwaraRepeatMode.all) return 0;
    return null;
  }

  /// Start playing a new song list. This ALWAYS replaces the whole queue
  /// with just `songs` (called from the All Songs / Folder / Playlist /
  /// Favorites pages respectively, so the queue is automatically scoped to
  /// its source).
  Future<void> setQueueAndPlay(List<Song> songs, int startIndex) async {
    _logListening();
    if (_sleepFadeActive) _cancelSleepFadeOut();
    _crossfadeCancelled = true;
    _crossfadeTriggeredForCurrent = false;
    _usingCrossfadePlayer = false;
    await _crossfadePlayer?.pause();
    // Drop the standby player while crossfade is off so manual
    // navigation does not leave audio resources allocated.
    if (!crossfadeEnabled) _releaseCrossfadePlayer();
    _queue = List.of(songs);

    if (_shuffle) {
      _playOrder = _buildShuffledOrder(_queue.length, startIndex);
      _posInOrder = 0;
    } else {
      _playOrder = List.generate(_queue.length, (i) => i);
      _posInOrder = startIndex;
    }

    notifyListeners(); // so the mini-player shows immediately, without waiting for the file to finish loading
    await _playCurrent();
    notifyListeners();
  }

  List<int> _buildShuffledOrder(int length, int startIndex) {
    final indices = List.generate(length, (i) => i);
    indices.remove(startIndex);
    indices.shuffle(Random());
    return [startIndex, ...indices];
  }

  Future<void> _playCurrent() async {
    final song = currentSong;
    if (song == null) return;
    try {
      await _player.setFilePath(song.filePath);
      await _player.setVolume(1);
    } catch (e) {
      debugPrint('Gagal memutar lagu: $e');
      lastError = '${lookupAppLocalizations(LanguageProvider.instance.locale).corePlayFailed} "${song.title}": $e';
      notifyListeners();
      return;
    }
    await _player.play();
    _playStartedAt = DateTime.now();
    _accumulatedListenedMs = 0;
    await DBHelper.instance.markPlayed(song.id);
    lastError = null;
    // Attach the system equalizer to this session (fire and forget,
    // the service guards its own errors and never blocks playback).
    unawaited(EqualizerService.instance.attach(_player));
    // Re-attach the position listener to the now-active player, so
    // crossfade keeps triggering for the following songs too (not just once).
    await _subscribePosition();
    // Warm the idle player with the next file when crossfade is off.
    _preloadNextSong();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      // A manual pause during a sleep fade stops the fade so the volume
      // does not keep dropping in the background.
      if (_sleepFadeActive) _cancelSleepFadeOut();
      _logListening();
      await player.pause();
      // Stop position updates while paused to save battery.
      await _unsubscribePosition();
    } else {
      // A manual play during a sleep fade cancels the fade and restores
      // full volume before resuming.
      if (_sleepFadeActive) _cancelSleepFadeOut();
      _playStartedAt = DateTime.now();
      await player.play();
      // Resume position updates for crossfade triggers.
      await _subscribePosition();
    }
    notifyListeners();
  }

  /// Next song FOLLOWING the queue order (_playOrder). When shuffle is on,
  /// the shuffled order is fixed once up front - next never reshuffles.
  Future<void> next() async {
    _logListening();
    if (_sleepFadeActive) _cancelSleepFadeOut();
    _crossfadeCancelled = true;
    await _crossfadePlayer?.pause();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    if (!crossfadeEnabled) _releaseCrossfadePlayer();
    if (_posInOrder < _playOrder.length - 1) {
      _posInOrder++;
    } else if (_repeatMode == SwaraRepeatMode.all) {
      _posInOrder = 0;
    } else {
      return; // already on the last song with no repeat, nothing to do
    }
    await _playCurrent();
  }

  /// Previous song FOLLOWING the queue order - truly steps one position
  /// back in _playOrder instead of picking a new random song.
  Future<void> previous() async {
    _logListening();
    if (_sleepFadeActive) _cancelSleepFadeOut();
    _crossfadeCancelled = true;
    await _crossfadePlayer?.pause();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    if (!crossfadeEnabled) _releaseCrossfadePlayer();
    if (_posInOrder > 0) {
      _posInOrder--;
    } else if (_repeatMode == SwaraRepeatMode.all) {
      _posInOrder = _playOrder.length - 1;
    } else {
      _posInOrder = 0;
    }
    await _playCurrent();
  }

  DateTime? _lastPreviousPressAt;
  static const _previousDoubleTapWindow = Duration(seconds: 3);

  /// Smart "previous" logic shared by the player screen and the
  /// notification button: one press restarts the song, a second press
  /// within 3 seconds actually moves to the previous song.
  Future<void> smartPrevious() async {
    final now = DateTime.now();
    if (_lastPreviousPressAt != null && now.difference(_lastPreviousPressAt!) < _previousDoubleTapWindow) {
      _lastPreviousPressAt = null;
      await previous();
    } else {
      _lastPreviousPressAt = now;
      await _activePlayer.seek(Duration.zero);
      notifyListeners();
    }
  }

  Future<void> playAtQueueIndex(int posInOrder) async {
    if (posInOrder < 0 || posInOrder >= _playOrder.length) return;
    _logListening();
    if (_sleepFadeActive) _cancelSleepFadeOut();
    _crossfadeCancelled = true;
    await _crossfadePlayer?.pause();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    if (!crossfadeEnabled) _releaseCrossfadePlayer();
    _posInOrder = posInOrder;
    await _playCurrent();
  }

  Future<void> playNext(Song song) async {
    if (_queue.isEmpty) {
      await setQueueAndPlay([song], 0);
      return;
    }
    _queue.add(song);
    _playOrder.insert(_posInOrder + 1, _queue.length - 1);
    // The next song changed, so any cached preload is stale.
    _preloadedFilePath = null;
    notifyListeners();
  }

  Future<void> addToQueueEnd(Song song) async {
    if (_queue.isEmpty) {
      await setQueueAndPlay([song], 0);
      return;
    }
    _queue.add(song);
    _playOrder.add(_queue.length - 1);
    notifyListeners();
  }

  /// Queue-slot IDs (original indices in _queue) for each _playOrder position -
  /// used by the UI so it can delete the CORRECT song even when the list
  /// changed mid-swipe (a plain positional index may be stale, this slot ID is not).
  List<int> get queueSlotIds => List.unmodifiable(_playOrder);

  /// Remove from the queue (position in _playOrder, not the currently playing item)
  void removeFromQueue(int posInOrder) {
    if (posInOrder == _posInOrder || posInOrder < 0 || posInOrder >= _playOrder.length) return;
    _playOrder.removeAt(posInOrder);
    if (posInOrder < _posInOrder) _posInOrder--;
    // Compact _queue: drop entries no longer referenced by any _playOrder slot
    // so _queue does not keep growing for the whole session without an app restart.
    _compactQueue();
    // Order changed, so any cached preload is stale.
    _preloadedFilePath = null;
    notifyListeners();
  }

  /// Drop _queue entries that are no longer in _playOrder.
  /// After compacting, remap every index in _playOrder to its new position.
  void _compactQueue() {
    final used = _playOrder.toSet();
    if (used.length == _queue.length) return; // nothing to drop

    // Build the old-index to new-index mapping
    final Map<int, int> remap = {};
    int newIdx = 0;
    final newQueue = <Song>[];
    for (int oldIdx = 0; oldIdx < _queue.length; oldIdx++) {
      if (used.contains(oldIdx)) {
        remap[oldIdx] = newIdx++;
        newQueue.add(_queue[oldIdx]);
      }
    }
    _queue = newQueue;
    _playOrder = _playOrder.map((old) => remap[old]!).toList();
  }

  /// Remove from the queue by (stable) slot ID instead of a plain positional
  /// index - safe to call from swipe-to-dismiss even when the list changed
  /// midway.
  void removeQueueSlot(int slotId) {
    final pos = _playOrder.indexOf(slotId);
    if (pos == -1) return; // already removed/changed first, safe to ignore
    removeFromQueue(pos);
  }

  /// Drag reorder on the Queue page - only the _playOrder sequence changes
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playOrder.length) return;
    if (newIndex < 0 || newIndex >= _playOrder.length) return;

    final moved = _playOrder.removeAt(oldIndex);
    _playOrder.insert(newIndex, moved);

    if (oldIndex == _posInOrder) {
      _posInOrder = newIndex;
    } else if (oldIndex < _posInOrder && newIndex >= _posInOrder) {
      _posInOrder--;
    } else if (oldIndex > _posInOrder && newIndex <= _posInOrder) {
      _posInOrder++;
    }
    // Order changed, so any cached preload is stale.
    _preloadedFilePath = null;
    notifyListeners();
  }

  double get playbackSpeed => _activePlayer.speed;

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _activePlayer.setSpeed(speed);
      // Mirror the speed on the standby player only when it already
      // exists, so this call never creates it just for a speed update.
      // A player created later copies the speed in _ensureCrossfadePlayer.
      await _crossfadePlayer?.setSpeed(speed);
    } catch (e) {
      debugPrint('Gagal set kecepatan: $e');
    }
    notifyListeners();
  }

  /// Toggle shuffle WITHOUT changing the currently playing song - only
  /// reorders the songs AFTER it (when ON) or restores the original
  /// order (when OFF).
  void toggleShuffle() {
    setShuffle(!_shuffle);
  }

  /// Set the shuffle state explicitly (not a toggle) - used by the
  /// "Shuffle" button so it always TURNS shuffle on instead of turning it off.
  void setShuffle(bool value) {
    _shuffle = value;
    final song = currentSong;
    if (song == null) {
      notifyListeners();
      return;
    }
    final currentQueueIndex = _playOrder[_posInOrder];

    if (_shuffle) {
      final rest = List.generate(_queue.length, (i) => i)..remove(currentQueueIndex);
      rest.shuffle(Random());
      _playOrder = [currentQueueIndex, ...rest];
      _posInOrder = 0;
    } else {
      _playOrder = List.generate(_queue.length, (i) => i);
      _posInOrder = currentQueueIndex;
    }
    // Order changed, so any cached preload is stale.
    _preloadedFilePath = null;
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = SwaraRepeatMode.values[(_repeatMode.index + 1) % SwaraRepeatMode.values.length];
    notifyListeners();
  }

  void setCrossfadeEnabled(bool value) {
    crossfadeEnabled = value;
    if (!value) {
      // Cancel any fade in flight and drop any stale crossfade state.
      // A fresh gap preload is prepared below, so the idle player keeps
      // at most one cached file while crossfade stays off. When the
      // standby player is currently audible, the release is deferred to
      // the next track change inside _releaseCrossfadePlayer.
      _crossfadeCancelled = true;
      _crossfadeTriggeredForCurrent = false;
      _releaseCrossfadePlayer();
      // Refresh the gap preload for the new mode.
      _preloadNextSong();
    } else {
      // Preload cache is only used when crossfade is off.
      _preloadedFilePath = null;
    }
    notifyListeners();
  }

  /// Time-based sleep timer with a countdown.
  /// [finishCurrentSong] true = do not stop right when the time runs out, but
  /// wait until the currently playing song ends before stopping.
  void setSleepTimer(Duration duration, {bool finishCurrentSong = false}) {
    _sleepTimer?.cancel();
    _cancelSleepFadeOut();
    sleepSongsRemaining = null; // time mode and song-count mode are mutually exclusive
    sleepTimerEndTime = DateTime.now().add(duration);
    _finishCurrentSongOnSleep = finishCurrentSong;
    _sleepTimer = Timer(duration, () async {
      sleepTimerEndTime = null;
      if (_finishCurrentSongOnSleep) {
        _pendingSleepStop = true; // handled in _onTrackFinished()
      } else {
        await _startSleepFadeOut();
        return;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// Song-count based sleep timer - stops automatically after N songs
  /// (counted from the currently playing song, inclusive).
  void setSleepTimerBySongs(int songCount) {
    _sleepTimer?.cancel();
    _cancelSleepFadeOut();
    sleepTimerEndTime = null; // time mode and song-count mode are mutually exclusive
    sleepSongsRemaining = songCount;
    notifyListeners();
  }

  Duration? get sleepTimerRemaining {
    if (sleepTimerEndTime == null) return null;
    final remaining = sleepTimerEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// True while the 30 second sleep fade out is running.
  bool get isSleepFadeOutActive => _sleepFadeActive;

  /// Cancel an in flight sleep fade and restore full volume.
  /// Used when the user cancels the timer or resumes playback mid fade.
  void _cancelSleepFadeOut() {
    if (!_sleepFadeActive) return;
    _sleepFadeGeneration++;
    _sleepFadeActive = false;
    // Restore full volume fire and forget so a resume starts loud.
    // Errors are only logged because this runs from sync UI handlers.
    _player.setVolume(1).catchError((Object e) {
      debugPrint('Sleep fade cancel failed: $e');
    });
    _crossfadePlayer?.setVolume(1).catchError((Object e) {
      debugPrint('Sleep fade cancel failed: $e');
    });
  }

  /// Fade the audible output to 0 over [sleepFadeDuration] then pause.
  /// Cancels silently when the generation changes (user cancel or play).
  Future<void> _startSleepFadeOut() async {
    if (_disposed) return;
    final isPlaying =
        _player.playing || (_crossfadePlayer?.playing ?? false);
    if (!isPlaying) {
      _logListening();
      await _unsubscribePosition();
      notifyListeners();
      return;
    }
    _sleepFadeActive = true;
    final generation = ++_sleepFadeGeneration;
    notifyListeners();
    const steps = 30;
    final stepDuration = sleepFadeDuration ~/ steps;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      if (_disposed) return;
      if (!_sleepFadeActive || generation != _sleepFadeGeneration) return;
      final v = (1 - i / steps).clamp(0.0, 1.0);
      try {
        await _player.setVolume(v);
      } catch (e) {
        debugPrint('Sleep fade failed: $e');
      }
      if (!_sleepFadeActive || generation != _sleepFadeGeneration) return;
      try {
        await _crossfadePlayer?.setVolume(v);
      } catch (e) {
        debugPrint('Sleep fade failed: $e');
      }
    }
    if (_disposed) return;
    if (!_sleepFadeActive || generation != _sleepFadeGeneration) return;
    _sleepFadeActive = false;
    _logListening();
    // Pause both players so playback really stops even mid crossfade.
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Sleep fade pause failed: $e');
    }
    try {
      await _crossfadePlayer?.pause();
    } catch (e) {
      debugPrint('Sleep fade pause failed: $e');
    }
    // Reset volume for the next manual play.
    try {
      await _player.setVolume(1);
    } catch (e) {
      debugPrint('Sleep fade reset failed: $e');
    }
    try {
      await _crossfadePlayer?.setVolume(1);
    } catch (e) {
      debugPrint('Sleep fade reset failed: $e');
    }
    // No crossfade trigger needed while paused, save battery.
    await _unsubscribePosition();
    notifyListeners();
  }

  /// Prepare the next song file in the idle player when crossfade is off.
  /// Loads the file only (never plays). Errors are ignored silently
  /// apart from a debug log so preload never breaks playback.
  void _preloadNextSong() {
    if (crossfadeEnabled) return;
    if (_disposed) return;
    if (_playOrder.isEmpty) return;
    final nextPos = _computeNextPosition();
    if (nextPos == null) return;
    if (nextPos == _posInOrder) return; // repeat-one, already loaded
    final nextSong = _queue[_playOrder[nextPos]];
    if (_preloadedFilePath == nextSong.filePath) return;
    final AudioPlayer idle;
    if (_usingCrossfadePlayer) {
      idle = _player;
    } else {
      try {
        idle = _ensureCrossfadePlayer();
      } catch (e) {
        debugPrint('Preload next failed: $e');
        return;
      }
    }
    final path = nextSong.filePath;
    idle.setFilePath(path).then((_) {
      if (_disposed) return;
      if (crossfadeEnabled) return;
      _preloadedFilePath = path;
    }).catchError((Object e) {
      debugPrint('Preload next failed: $e');
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerEndTime = null;
    sleepSongsRemaining = null;
    _pendingSleepStop = false;
    _cancelSleepFadeOut();
    notifyListeners();
  }

  void _onTrackFinished() {
    // Song-count mode: decrement by 1, stop when exhausted
    if (sleepSongsRemaining != null) {
      sleepSongsRemaining = sleepSongsRemaining! - 1;
      if (sleepSongsRemaining! <= 0) {
        sleepSongsRemaining = null;
        _logListening();
        // Fire-and-forget with an error guard - _onTrackFinished is triggered
        // from a stream listener that cannot be async.
        _player.pause().catchError((e) {
          debugPrint('Gagal pause saat sleep-timer: $e');
        });
        _crossfadePlayer?.pause().catchError((e) {
          debugPrint('Gagal pause saat sleep-timer: $e');
        });
        // Stop position updates while paused to save battery.
        _unsubscribePosition();
        notifyListeners();
        return;
      }
    }
    // Time mode with "finish the last song": the song that just ended was the last one
    if (_pendingSleepStop) {
      _pendingSleepStop = false;
      _logListening();
      _player.pause().catchError((e) {
        debugPrint('Gagal pause saat sleep-timer: $e');
      });
      _crossfadePlayer?.pause().catchError((e) {
        debugPrint('Gagal pause saat sleep-timer: $e');
      });
      // Stop position updates while paused to save battery.
      _unsubscribePosition();
      notifyListeners();
      return;
    }

    if (_repeatMode == SwaraRepeatMode.one) {
      _usingCrossfadePlayer = false;
      _crossfadeTriggeredForCurrent = false;
      if (!crossfadeEnabled) _releaseCrossfadePlayer();
      _playCurrent().then((_) {}, onError: (e) {
        debugPrint('Gagal repeat-one: $e');
      });
      return;
    }
    next().then((_) {}, onError: (e) {
      debugPrint('Gagal next: $e');
    });
  }

  void _logListening() {
    if (_disposed) return;
    if (_playStartedAt == null || currentSong == null) return;
    final elapsed = DateTime.now().difference(_playStartedAt!).inMilliseconds;
    _accumulatedListenedMs += elapsed;
    _playStartedAt = null;

    if (_accumulatedListenedMs > 1000) {
      // Do not await here (called from a sync listener) but catch
      // errors so a corrupt DB or full disk cannot become an unhandled async error.
      DBHelper.instance
          .addListeningEntry(ListeningEntry(
        songId: currentSong!.id,
        timestamp: DateTime.now(),
        listenedMs: _accumulatedListenedMs,
      ))
          .catchError((e) {
        debugPrint('Gagal simpan riwayat dengar: $e');
      });
    }
    _accumulatedListenedMs = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _crossfadeCancelled = true;
    _sleepFadeGeneration++;
    _sleepFadeActive = false;
    _preloadedFilePath = null;
    _logListening();
    _sleepTimer?.cancel();
    // Fire and forget: dispose is sync, the cancel future still runs.
    _unsubscribePosition();
    _playerStateSub?.cancel();
    _crossfadeStateSub?.cancel();
    // ChangeNotifier.dispose() is sync void - never turn it into a Future.
    // Players are disposed fire-and-forget because the singleton lives for the whole app run.
    _player.dispose().catchError((e) {
      debugPrint('Gagal dispose player: $e');
    });
    _crossfadePlayer?.dispose().catchError((e) {
      debugPrint('Gagal dispose crossfade player: $e');
    });
    _crossfadePlayer = null;
    unawaited(EqualizerService.instance.release());
    super.dispose();
  }
}
