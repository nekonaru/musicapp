import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'db_helper.dart';
import 'notification_service.dart';

enum RepeatMode { off, all, one }

class PlayerService extends ChangeNotifier {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  final AudioPlayer _player = AudioPlayer();
  // Player kedua khusus untuk crossfade (dinyalakan bergantian dengan _player)
  final AudioPlayer _crossfadePlayer = AudioPlayer();
  bool _usingCrossfadePlayer = false;

  // _queue: daftar lagu asli (urutan asal, tidak berubah oleh shuffle)
  List<Song> _queue = [];
  // _playOrder: urutan pemutaran sebenarnya (berisi index ke _queue).
  // Kalau shuffle mati: [0,1,2,...]. Kalau shuffle aktif: acak sekali, tidak berubah tiap next/previous.
  List<int> _playOrder = [];
  int _posInOrder = 0;

  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  bool crossfadeEnabled = false;
  static const Duration crossfadeDuration = Duration(seconds: 3);

  Timer? _sleepTimer;
  DateTime? sleepTimerEndTime;
  String? lastError;

  DateTime? _playStartedAt;
  int _accumulatedListenedMs = 0;

  StreamSubscription? _positionSub;
  bool _crossfadeTriggeredForCurrent = false;

  AudioPlayer get player => _usingCrossfadePlayer ? _crossfadePlayer : _player;

  Song? get currentSong {
    if (_playOrder.isEmpty || _posInOrder < 0 || _posInOrder >= _playOrder.length) return null;
    return _queue[_playOrder[_posInOrder]];
  }

  bool get isShuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;

  /// Antrean sesuai urutan pemutaran sebenarnya (dipakai halaman Antrean)
  List<Song> get queue => _playOrder.map((i) => _queue[i]).toList();
  int get currentIndex => _posInOrder;

  Future<void> init() async {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_usingCrossfadePlayer) {
        _logListening();
        _onTrackFinished();
      }
    });
    _crossfadePlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _usingCrossfadePlayer) {
        _logListening();
        _onTrackFinished();
      }
    });
    _positionSub = _player.positionStream.listen(_maybeStartCrossfade);
  }

  void _maybeStartCrossfade(Duration position) {
    if (!crossfadeEnabled || _usingCrossfadePlayer || _crossfadeTriggeredForCurrent) return;
    final dur = _player.duration;
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

    try {
      await _crossfadePlayer.setFilePath(nextSong.filePath);
      await _crossfadePlayer.setVolume(0);
      await _crossfadePlayer.play();

      const steps = 20;
      final stepDuration = crossfadeDuration ~/ steps;
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(stepDuration);
        final v = i / steps;
        _crossfadePlayer.setVolume(v);
        _player.setVolume(1 - v);
      }
      await _player.pause();
      await _player.setVolume(1);

      _usingCrossfadePlayer = true;
      _posInOrder = nextPos;
      _crossfadeTriggeredForCurrent = false;
      await DBHelper.instance.markPlayed(nextSong.id);
      _updateNotification();
      notifyListeners();

      // Swap peran: player utama sekarang jadi player crossfade untuk lagu berikutnya
      _swapPlayers();
    } catch (e) {
      debugPrint('Crossfade gagal, lanjut normal: $e');
      _crossfadeTriggeredForCurrent = false;
    }
  }

  void _swapPlayers() {
    // Setelah crossfade selesai, yang tadinya _crossfadePlayer jadi player utama secara logis.
    // Supaya kode tetap sederhana, kita cukup tukar flag _usingCrossfadePlayer dan pastikan
    // listener posisi tetap memantau player yang sedang aktif.
    _positionSub?.cancel();
    _positionSub = player.positionStream.listen(_maybeStartCrossfade);
  }

  int? _computeNextPosition() {
    if (_posInOrder < _playOrder.length - 1) return _posInOrder + 1;
    if (_repeatMode == RepeatMode.all) return 0;
    return null;
  }

  /// Mulai memutar daftar lagu baru. Ini SELALU mengganti seluruh antrean
  /// jadi cuma isi `songs` (dipakai dari halaman Semua Lagu / Folder / Playlist / Favorit
  /// masing-masing, jadi antrean otomatis terbatas sesuai sumbernya).
  Future<void> setQueueAndPlay(List<Song> songs, int startIndex) async {
    _logListening();
    _crossfadeTriggeredForCurrent = false;
    _usingCrossfadePlayer = false;
    _queue = List.of(songs);

    if (_shuffle) {
      _playOrder = _buildShuffledOrder(_queue.length, startIndex);
      _posInOrder = 0;
    } else {
      _playOrder = List.generate(_queue.length, (i) => i);
      _posInOrder = startIndex;
    }

    notifyListeners(); // supaya mini-player langsung muncul, tanpa nunggu file selesai load
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
      lastError = 'Gagal memutar "${song.title}": $e';
      notifyListeners();
      return;
    }
    await _player.play();
    _playStartedAt = DateTime.now();
    _accumulatedListenedMs = 0;
    await DBHelper.instance.markPlayed(song.id);
    lastError = null;
    _updateNotification();
    // Pasang ulang listener posisi ke player yang sekarang aktif, supaya
    // crossfade tetap terpicu untuk lagu-lagu berikutnya juga (bukan cuma sekali).
    _positionSub?.cancel();
    _positionSub = player.positionStream.listen(_maybeStartCrossfade);
    notifyListeners();
  }

  void _updateNotification() {
    final song = currentSong;
    if (song == null) return;
    NotificationService.instance.showOrUpdate(
      title: song.title,
      artist: song.artist,
      isPlaying: player.playing,
    );
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      _logListening();
      await player.pause();
    } else {
      _playStartedAt = DateTime.now();
      await player.play();
    }
    _updateNotification();
    notifyListeners();
  }

  /// Lagu berikutnya SESUAI urutan antrean (_playOrder). Kalau shuffle aktif,
  /// urutan acaknya sudah ditentukan sekali di awal - next tidak mengacak ulang.
  Future<void> next() async {
    _logListening();
    await _crossfadePlayer.pause();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    if (_posInOrder < _playOrder.length - 1) {
      _posInOrder++;
    } else if (_repeatMode == RepeatMode.all) {
      _posInOrder = 0;
    } else {
      return; // sudah di lagu terakhir, tidak ada repeat
    }
    await _playCurrent();
  }

  /// Lagu sebelumnya SESUAI urutan antrean - benar-benar mundur satu posisi
  /// di _playOrder, bukan lagu acak baru.
  Future<void> previous() async {
    _logListening();
    await _crossfadePlayer.pause();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    if (_posInOrder > 0) {
      _posInOrder--;
    } else if (_repeatMode == RepeatMode.all) {
      _posInOrder = _playOrder.length - 1;
    } else {
      _posInOrder = 0;
    }
    await _playCurrent();
  }

  Future<void> playAtQueueIndex(int posInOrder) async {
    if (posInOrder < 0 || posInOrder >= _playOrder.length) return;
    _logListening();
    _usingCrossfadePlayer = false;
    _crossfadeTriggeredForCurrent = false;
    _posInOrder = posInOrder;
    await _playCurrent();
  }

  void playNext(Song song) {
    if (_queue.isEmpty) {
      setQueueAndPlay([song], 0);
      return;
    }
    _queue.add(song);
    _playOrder.insert(_posInOrder + 1, _queue.length - 1);
    notifyListeners();
  }

  void addToQueueEnd(Song song) {
    if (_queue.isEmpty) {
      setQueueAndPlay([song], 0);
      return;
    }
    _queue.add(song);
    _playOrder.add(_queue.length - 1);
    notifyListeners();
  }

  /// Hapus dari antrean (posisi di _playOrder, bukan currently playing)
  void removeFromQueue(int posInOrder) {
    if (posInOrder == _posInOrder || posInOrder < 0 || posInOrder >= _playOrder.length) return;
    _playOrder.removeAt(posInOrder);
    if (posInOrder < _posInOrder) _posInOrder--;
    notifyListeners();
  }

  /// Drag reorder di halaman Antrean - yang diubah urutannya adalah _playOrder
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playOrder.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
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
    notifyListeners();
  }

  double get playbackSpeed => _player.speed;

  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
    await _crossfadePlayer.setSpeed(speed);
    notifyListeners();
  }

  /// Toggle shuffle TANPA mengubah lagu yang sedang diputar - cuma
  /// menyusun ulang urutan lagu-lagu SETELAHNYA (kalau ON) atau
  /// mengembalikan ke urutan asli (kalau OFF).
  void toggleShuffle() {
    setShuffle(!_shuffle);
  }

  /// Set status shuffle secara eksplisit (bukan toggle) - dipakai tombol
  /// "Acak" supaya selalu MENGAKTIFKAN shuffle, tidak pernah mematikannya.
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
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void setCrossfadeEnabled(bool value) {
    crossfadeEnabled = value;
    notifyListeners();
  }

  /// Timer tidur dengan hitung mundur yang bisa ditampilkan di UI
  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () async {
      _logListening();
      await player.pause();
      sleepTimerEndTime = null;
      notifyListeners();
    });
    notifyListeners();
  }

  Duration? get sleepTimerRemaining {
    if (sleepTimerEndTime == null) return null;
    final remaining = sleepTimerEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerEndTime = null;
    notifyListeners();
  }

  void _onTrackFinished() {
    if (_repeatMode == RepeatMode.one) {
      _usingCrossfadePlayer = false;
      _crossfadeTriggeredForCurrent = false;
      _playCurrent();
      return;
    }
    next();
  }

  void _logListening() {
    if (_playStartedAt == null || currentSong == null) return;
    final elapsed = DateTime.now().difference(_playStartedAt!).inMilliseconds;
    _accumulatedListenedMs += elapsed;
    _playStartedAt = null;

    if (_accumulatedListenedMs > 1000) {
      DBHelper.instance.addListeningEntry(ListeningEntry(
        songId: currentSong!.id,
        timestamp: DateTime.now(),
        listenedMs: _accumulatedListenedMs,
      ));
    }
    _accumulatedListenedMs = 0;
  }

  Future<void> dispose() async {
    _logListening();
    _positionSub?.cancel();
    await _player.dispose();
    await _crossfadePlayer.dispose();
  }
}
