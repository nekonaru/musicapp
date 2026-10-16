import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:swara/l10n/gen/app_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:swara/providers/language_provider.dart';
import '../models/song.dart';
import 'db_helper.dart';
import 'equalizer_service.dart';

enum SwaraRepeatMode { off, all, one }

// Decision returned by _onNaturalTrackEnd after applying sleep logic.
enum _TrackEndDecision { stop, repeatOne, advance }

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

  // Public version counter for queue/order mutations. Incremented on every
  // queue or order change so UI can detect stale snapshots.
  int queueVersion = 0;
  int _playGeneration = 0;
  double _lastSpeed = 1.0;

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
  // Manual pause/resume fade state. Short 300ms ramp used only around
  // togglePlayPause, separate from the 30s sleep fade and crossfade.
  // Generation guards against overlapping fades when toggle is pressed
  // mid fade. Only the audible player is faded, never the standby one.
  int _pauseFadeGeneration = 0;
  bool _pauseFadeOutActive = false;
  static const Duration pauseFadeDuration = Duration(milliseconds: 300);
  static const int pauseFadeSteps = 4;
  // Serializes every volume and pause operation (fades, cancels,
  // restores). Overlapping fades used to interleave setVolume calls,
  // leaving the player stuck quiet. Chained ops run strictly in call
  // order and the chain never breaks (errors are logged, not rethrown).
  Future<void> _volumeChain = Future<void>.value();

  Future<void> _vol(Future<void>? Function() op) {
    final next = _volumeChain.then((_) async {
      try {
        await op();
      } catch (e) {
        debugPrint('Volume op failed: $e');
      }
    });
    _volumeChain = next;
    return next;
  }
  // File path currently preloaded in the idle player (crossfade off only).
  // Best effort cache, never played directly from here.
  String? _preloadedFilePath;
  String? lastError;

  DateTime? _playStartedAt;
  int _accumulatedListenedMs = 0;

  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _crossfadeStateSub;
  // Crossfade generation guards overlapping fades. Incremented on every
  // start and every cancel. A fade loop captures its own generation and
  // aborts when the global value no longer matches. _crossfadeActiveGeneration
  // tracks the in flight fade for the current song (-1 means idle) so the
  // position trigger fires only once per song without a bool flag.
  int _crossfadeGeneration = 0;
  int _crossfadeActiveGeneration = -1;
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
    created.setSpeed(_lastSpeed).catchError((Object e) {
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
    // Trigger only once per song: an in flight fade is marked by a
    // non idle _crossfadeActiveGeneration, so later position ticks skip.
    if (!crossfadeEnabled || _crossfadeActiveGeneration != -1) return;
    final dur = _activePlayer.duration;
    if (dur == null) return;
    final remaining = dur - position;
    if (remaining <= crossfadeDuration && remaining > Duration.zero) {
      _startCrossfadeToNext();
    }
  }

  Future<void> _startCrossfadeToNext() async {
    if (_disposed) return;
    if (_playOrder.isEmpty) return;
    final playGen = _playGeneration;
    final nextPos = _computeNextPosition();
    if (nextPos == null) return;
    final nextSong = _queue[_playOrder[nextPos]];

    // Use the dynamic getters, never hardcode _player/_crossfadePlayer, so this
    // stays correct for any crossfade count, not just the first one.
    final outgoing = _activePlayer;
    final incoming = _fadeTargetPlayer;
    // Claim the trigger slot so position ticks do not start a second fade.
    final fadeGen = ++_crossfadeGeneration;
    _crossfadeActiveGeneration = fadeGen;

    try {
      await incoming.setFilePath(nextSong.filePath);
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;
      await incoming.setSpeed(_lastSpeed);
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;
      await _vol(() => incoming.setVolume(0));
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;
      await incoming.play();
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;

      const steps = 20;
      final stepDuration = crossfadeDuration ~/ steps;
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(stepDuration);
        // Abort without side effects when a newer navigation took over.
        if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;
        final v = i / steps;
        await _vol(() => incoming.setVolume(v));
        if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;
        await _vol(() => outgoing.setVolume(1 - v));
      }
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;

      await _vol(() => outgoing.pause());
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;
      // Keep the outgoing player muted at restore level; its volume is
      // reset to full so a later reuse starts loud. Do not release it here.
      await _vol(() => outgoing.setVolume(1));
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;

      // IMPORTANT: record the listening history of the OLD song first (using
      // currentSong while it still points at the old song, before _posInOrder
      // moves), then reset the start clock for the NEW song, so
      // listening entries never get the wrong attribution or doubled duration.
      _logListening();
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;
      _usingCrossfadePlayer = !_usingCrossfadePlayer;
      // Attach the equalizer only after the flip, to the now audible player.
      // The outgoing player is left alone until its pause above.
      unawaited(EqualizerService.instance.attach(_activePlayer));
      _posInOrder = nextPos;
      _playStartedAt = DateTime.now();
      _accumulatedListenedMs = 0;
      _crossfadeActiveGeneration = -1;
      await DBHelper.instance.markPlayed(nextSong.id);
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;

      await _subscribePosition();
      if (playGen != _playGeneration || fadeGen != _crossfadeGeneration || _disposed) return;

      // Apply the same natural end completion (sleep decrement first, then
      // repeat decision). When sleep is exhausted this pauses both players
      // at full restored volume and notifies, so return without extra notify.
      final decision = _onNaturalTrackEnd();
      if (decision == _TrackEndDecision.stop) return;

      notifyListeners();
    } catch (e) {
      debugPrint('Crossfade failed, continue normal: $e');
      if (fadeGen == _crossfadeGeneration) _crossfadeActiveGeneration = -1;
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

  /// Cancel any in flight crossfade by bumping the generation. The fade loop
  /// aborts without side effects when its captured generation mismatches.
  void _cancelCrossfade() {
    _crossfadeGeneration++;
    _crossfadeActiveGeneration = -1;
  }

  /// Start playing a new song list. This ALWAYS replaces the whole queue
  /// with just `songs` (called from the All Songs / Folder / Playlist /
  /// Favorites pages respectively, so the queue is automatically scoped to
  /// its source).
  Future<void> setQueueAndPlay(List<Song> songs, int startIndex) async {
    if (_disposed) return;
    _playGeneration++;
    queueVersion++;
    _logListening();
    if (_sleepFadeActive) _cancelSleepFadeOut();
    _cancelPauseFade();
    _cancelCrossfade();
    _usingCrossfadePlayer = false;
    await _vol(() => _crossfadePlayer?.pause() ?? Future<void>.value());
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
    if (_disposed) return;
    final playGen = _playGeneration;
    final song = currentSong;
    if (song == null) return;
    try {
      await _player.setFilePath(song.filePath);
      if (playGen != _playGeneration || _disposed) return;
      await _player.setSpeed(_lastSpeed);
      if (playGen != _playGeneration || _disposed) return;
      await _vol(() => _player.setVolume(1));
    } catch (e) {
      if (playGen != _playGeneration || _disposed) return;
      debugPrint('Failed to play song: $e');
      lastError = '${lookupAppLocalizations(LanguageProvider.instance.locale).corePlayFailed} "${song.title}": $e';
      notifyListeners();
      return;
    }
    if (playGen != _playGeneration || _disposed) return;
    await _player.play();
    if (playGen != _playGeneration || _disposed) return;
    _playStartedAt = DateTime.now();
    _accumulatedListenedMs = 0;
    await DBHelper.instance.markPlayed(song.id);
    if (playGen != _playGeneration || _disposed) return;
    lastError = null;
    // Attach the system equalizer to this session (fire and forget,
    // the service guards its own errors and never blocks playback).
    unawaited(EqualizerService.instance.attach(_player));
    // Re-attach the position listener to the now-active player, so
    // crossfade keeps triggering for the following songs too (not just once).
    await _subscribePosition();
    if (playGen != _playGeneration || _disposed) return;
    // Warm the idle player with the next file when crossfade is off.
    _preloadNextSong();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    // Second press while a pause fade out is still running cancels the
    // pause and keeps playback at full volume.
    if (_pauseFadeOutActive) {
      _pauseFadeGeneration++;
      _pauseFadeOutActive = false;
      await _vol(() => _activePlayer.setVolume(1));
      notifyListeners();
      return;
    }
    if (player.playing) {
      // A manual pause during a sleep fade stops the fade so the volume
      // does not keep dropping in the background.
      if (_sleepFadeActive) _cancelSleepFadeOut();
      // Cancel any in flight resume fade before starting the pause fade.
      final generation = ++_pauseFadeGeneration;
      _pauseFadeOutActive = true;
      _logListening();
      final target = _activePlayer;
      try {
        final stepDuration = pauseFadeDuration ~/ pauseFadeSteps;
        for (int i = 1; i <= pauseFadeSteps; i++) {
          await Future.delayed(stepDuration);
          if (_disposed) return;
          if (generation != _pauseFadeGeneration) return;
          final v = (1 - i / pauseFadeSteps).clamp(0.0, 1.0);
          await _vol(() => target.setVolume(v));
        }
        if (_disposed) return;
        if (generation != _pauseFadeGeneration) return;
        await _vol(() => target.pause());
        // Restore full volume on both players so the next play starts loud.
        await _vol(() => _player.setVolume(1));
        await _vol(
            () => _crossfadePlayer?.setVolume(1) ?? Future<void>.value());
      } catch (e) {
        debugPrint('Pause fade failed: $e');
      } finally {
        if (generation == _pauseFadeGeneration) {
          _pauseFadeOutActive = false;
        }
      }
      // Stop position updates while paused to save battery.
      await _unsubscribePosition();
    } else {
      // A manual play during a sleep fade cancels the fade and restores
      // full volume before resuming.
      if (_sleepFadeActive) _cancelSleepFadeOut();
      // Cancel any in flight pause fade before starting the resume fade.
      final generation = ++_pauseFadeGeneration;
      _playStartedAt = DateTime.now();
      final target = _activePlayer;
      await _vol(() => target.setVolume(0));
      await target.play();
      // Resume position updates for crossfade triggers.
      await _subscribePosition();
      try {
        final stepDuration = pauseFadeDuration ~/ pauseFadeSteps;
        for (int i = 1; i <= pauseFadeSteps; i++) {
          await Future.delayed(stepDuration);
          if (_disposed) return;
          if (generation != _pauseFadeGeneration) return;
          final v = (i / pauseFadeSteps).clamp(0.0, 1.0);
          await _vol(() => target.setVolume(v));
        }
        if (_disposed) return;
        if (generation != _pauseFadeGeneration) return;
        await _vol(() => target.setVolume(1));
      } catch (e) {
        debugPrint('Resume fade failed: $e');
      }
    }
    notifyListeners();
  }

  /// Cancel an in flight manual pause/resume fade. Restores go through the
  /// volume chain so they can never land before a stale fade step.
  void _cancelPauseFade() {
    _pauseFadeGeneration++;
    _pauseFadeOutActive = false;
    // Restore full volume so a cancelled resume fade never leaves the
    // player quiet. Ordered by the chain, fire and forget is safe.
    _vol(() => _player.setVolume(1));
    _vol(() => _crossfadePlayer?.setVolume(1) ?? Future<void>.value());
  }

  /// Next song FOLLOWING the queue order (_playOrder). When shuffle is on,
  /// the shuffled order is fixed once up front, next never reshuffles.
  Future<void> next() async {
    if (_disposed) return;
    _playGeneration++;
    queueVersion++;
    _logListening();
    if (_sleepFadeActive) _cancelSleepFadeOut();
    _cancelPauseFade();
    _cancelCrossfade();
    await _vol(() => _crossfadePlayer?.pause() ?? Future<void>.value());
    _usingCrossfadePlayer = false;
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

  /// Previous song FOLLOWING the queue order, truly steps one position
  /// back in _playOrder instead of picking a new random song.
  Future<void> previous() async {
    if (_disposed) return;
    _playGeneration++;
    queueVersion++;
    _logListening();
    if (_sleepFadeActive) _cancelSleepFadeOut();
    _cancelPauseFade();
    _cancelCrossfade();
    await _vol(() => _crossfadePlayer?.pause() ?? Future<void>.value());
    _usingCrossfadePlayer = false;
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
    if (_disposed) return;
    if (posInOrder < 0 || posInOrder >= _playOrder.length) return;
    _playGeneration++;
    queueVersion++;
    _logListening();
    if (_sleepFadeActive) _cancelSleepFadeOut();
    _cancelPauseFade();
    _cancelCrossfade();
    await _vol(() => _crossfadePlayer?.pause() ?? Future<void>.value());
    _usingCrossfadePlayer = false;
    if (!crossfadeEnabled) _releaseCrossfadePlayer();
    _posInOrder = posInOrder;
    await _playCurrent();
  }

  Future<void> playNext(Song song) async {
    if (_queue.isEmpty) {
      await setQueueAndPlay([song], 0);
      return;
    }
    queueVersion++;
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
    queueVersion++;
    _queue.add(song);
    _playOrder.add(_queue.length - 1);
    notifyListeners();
  }

  /// Queue-slot IDs (original indices in _queue) for each _playOrder position,
  /// used by the UI so it can delete the correct song even when the list
  /// changed mid-swipe (a plain positional index may be stale, this slot ID is not).
  List<int> get queueSlotIds => List.unmodifiable(_playOrder);

  /// Position in _playOrder for a stable slot ID, or null when gone.
  int? queuePosForSlot(int slotId) {
    final pos = _playOrder.indexOf(slotId);
    if (pos == -1) return null;
    return pos;
  }

  /// Remove from the queue (position in _playOrder, not the currently playing item)
  void removeFromQueue(int posInOrder) {
    if (posInOrder == _posInOrder || posInOrder < 0 || posInOrder >= _playOrder.length) return;
    queueVersion++;
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
  /// index, safe to call from swipe-to-dismiss even when the list changed
  /// midway.
  void removeQueueSlot(int slotId) {
    final pos = _playOrder.indexOf(slotId);
    if (pos == -1) return; // already removed or changed first, safe to ignore
    queueVersion++;
    removeFromQueue(pos);
  }

  /// Drag reorder on the Queue page, only the _playOrder sequence changes
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playOrder.length) return;
    if (newIndex < 0 || newIndex >= _playOrder.length) return;
    queueVersion++;
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
    if (_disposed) return;
    _lastSpeed = speed;
    try {
      await _activePlayer.setSpeed(speed);
      // Mirror the speed on the standby player only when it already
      // exists, so this call never creates it just for a speed update.
      // A player created later copies the speed in _ensureCrossfadePlayer.
      await _crossfadePlayer?.setSpeed(speed);
    } catch (e) {
      debugPrint('Failed to set speed: $e');
    }
    notifyListeners();
  }

  /// Toggle shuffle WITHOUT changing the currently playing song, only
  /// reorders the songs AFTER it (when ON) or restores the original
  /// order (when OFF).
  void toggleShuffle() {
    setShuffle(!_shuffle);
  }

  /// Set the shuffle state explicitly (not a toggle), used by the
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
      _cancelCrossfade();
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
    // Restore full volume through the chain so a resume starts loud.
    // Errors are only logged because this runs from sync UI handlers.
    _vol(() => _player.setVolume(1));
    _vol(() => _crossfadePlayer?.setVolume(1) ?? Future<void>.value());
  }

  /// Fade the audible output to 0 over [sleepFadeDuration] then pause.
  /// Cancels silently when the generation changes (user cancel or play).
  Future<void> _startSleepFadeOut() async {
    if (_disposed) return;
    _cancelPauseFade();
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
      await _vol(() => _player.setVolume(v));
      if (!_sleepFadeActive || generation != _sleepFadeGeneration) return;
      await _vol(
          () => _crossfadePlayer?.setVolume(v) ?? Future<void>.value());
    }
    if (_disposed) return;
    if (!_sleepFadeActive || generation != _sleepFadeGeneration) return;
    _sleepFadeActive = false;
    _logListening();
    // Pause both players so playback really stops even mid crossfade.
    await _vol(() => _player.pause());
    await _vol(
        () => _crossfadePlayer?.pause() ?? Future<void>.value());
    // Reset volume for the next manual play.
    await _vol(() => _player.setVolume(1));
    await _vol(
        () => _crossfadePlayer?.setVolume(1) ?? Future<void>.value());
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
      if (_disposed) return null;
      if (crossfadeEnabled) return null;
      return idle.setSpeed(_lastSpeed);
    }).then((_) {
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

  /// Shared natural track end completion used by both the normal completion
  /// listener and the crossfade swap path. Applies the sleep decrement first,
  /// then the pending sleep stop, then the repeat one decision. Stop paths
  /// pause both players, restore full volume on both, stop position updates,
  /// and notify. Returns whether playback should continue to the next song.
  _TrackEndDecision _onNaturalTrackEnd() {
    // Song count mode: decrement by 1, stop when exhausted.
    if (sleepSongsRemaining != null) {
      sleepSongsRemaining = sleepSongsRemaining! - 1;
      if (sleepSongsRemaining! <= 0) {
        sleepSongsRemaining = null;
        _logListening();
        // Fire and forget with an error guard, called from sync listeners.
        _pauseBothForSleep();
        // Stop position updates while paused to save battery.
        _unsubscribePosition();
        notifyListeners();
        return _TrackEndDecision.stop;
      }
    }
    // Time mode with finish last song: the song that just ended was the last one.
    if (_pendingSleepStop) {
      _pendingSleepStop = false;
      _logListening();
      _pauseBothForSleep();
      // Stop position updates while paused to save battery.
      _unsubscribePosition();
      notifyListeners();
      return _TrackEndDecision.stop;
    }
    if (_repeatMode == SwaraRepeatMode.one) {
      return _TrackEndDecision.repeatOne;
    }
    return _TrackEndDecision.advance;
  }

  /// Pause both players for a sleep stop and always restore full volume on
  /// both, so the next manual play starts loud.
  void _pauseBothForSleep() {
    _vol(() => _player.pause()).then((_) => _vol(() => _player.setVolume(1)));
    final standby = _crossfadePlayer;
    if (standby == null) return;
    standby.pause().catchError((Object e) {
      debugPrint('Failed to pause for sleep timer: $e');
    }).then((_) => standby.setVolume(1)).catchError((Object e) {
      debugPrint('Failed to reset volume for sleep timer: $e');
    });
  }

  void _onTrackFinished() {
    if (_disposed) return;
    final decision = _onNaturalTrackEnd();
    if (decision == _TrackEndDecision.stop) return;

    if (decision == _TrackEndDecision.repeatOne) {
      _usingCrossfadePlayer = false;
      _cancelCrossfade();
      if (!crossfadeEnabled) _releaseCrossfadePlayer();
      _playCurrent().then((_) {}, onError: (Object e) {
        debugPrint('Failed repeat-one: $e');
      });
      return;
    }
    next().then((_) {}, onError: (Object e) {
      debugPrint('Failed next: $e');
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
        debugPrint('Failed to save listening history: $e');
      });
    }
    _accumulatedListenedMs = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelCrossfade();
    _sleepFadeGeneration++;
    _sleepFadeActive = false;
    _pauseFadeGeneration++;
    _pauseFadeOutActive = false;
    _preloadedFilePath = null;
    _logListening();
    _sleepTimer?.cancel();
    // Fire and forget: dispose is sync, the cancel future still runs.
    _unsubscribePosition();
    _playerStateSub?.cancel();
    _crossfadeStateSub?.cancel();
    // ChangeNotifier.dispose() is sync void, never turn it into a Future.
    // Players are disposed fire and forget because the singleton lives for the whole app run.
    _player.dispose().catchError((e) {
      debugPrint('Failed to dispose player: $e');
    });
    _crossfadePlayer?.dispose().catchError((e) {
      debugPrint('Failed to dispose crossfade player: $e');
    });
    _crossfadePlayer = null;
    unawaited(EqualizerService.instance.release());
    super.dispose();
  }
}
