import 'dart:async';
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
  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  Timer? _sleepTimer;
  String? lastError;

  // Untuk mencatat berapa lama lagu benar-benar didengar
  DateTime? _playStartedAt;
  int _accumulatedListenedMs = 0;

  AudioPlayer get player => _player;
  Song? get currentSong => _queue.isEmpty ? null : _queue[_currentIndex];
  bool get isShuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;

  /// Sisa antrean setelah lagu yang sedang diputar
  List<Song> get upNext =>
      _queue.isEmpty ? [] : _queue.sublist((_currentIndex + 1).clamp(0, _queue.length));

  Future<void> init() async {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _logListening();
        _onTrackFinished();
      }
    });
  }

  Future<void> setQueueAndPlay(List<Song> songs, int startIndex) async {
    _logListening(); // simpan sisa riwayat lagu sebelumnya kalau ada
    _queue = List.of(songs);
    _currentIndex = startIndex;
    // Notify SEGERA supaya mini-player langsung muncul menampilkan lagu yang
    // dipilih, tidak perlu menunggu proses loading file audio selesai dulu.
    notifyListeners();
    await _playCurrent();
    notifyListeners();
  }

  Future<void> _playCurrent() async {
    final song = currentSong;
    if (song == null) return;
    try {
      await _player.setFilePath(song.filePath);
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
    notifyListeners();
  }

  void _updateNotification() {
    final song = currentSong;
    if (song == null) return;
    NotificationService.instance.showOrUpdate(
      title: song.title,
      artist: song.artist,
      isPlaying: _player.playing,
    );
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      _logListening();
      await _player.pause();
    } else {
      _playStartedAt = DateTime.now();
      await _player.play();
    }
    _updateNotification();
    notifyListeners();
  }

  Future<void> next() async {
    _logListening();
    _advanceIndex();
    await _playCurrent();
  }

  Future<void> previous() async {
    _logListening();
    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = _queue.length - 1;
    }
    await _playCurrent();
  }

  /// Putar lagu tertentu di dalam antrean (dipanggil dari halaman Antrean)
  Future<void> playAtQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _logListening();
    _currentIndex = index;
    await _playCurrent();
  }

  /// Tambahkan lagu supaya diputar setelah lagu yang sedang berjalan
  void playNext(Song song) {
    if (_queue.isEmpty) {
      setQueueAndPlay([song], 0);
      return;
    }
    _queue.insert(_currentIndex + 1, song);
    notifyListeners();
  }

  /// Tambahkan lagu ke akhir antrean
  void addToQueueEnd(Song song) {
    if (_queue.isEmpty) {
      setQueueAndPlay([song], 0);
      return;
    }
    _queue.add(song);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index <= _currentIndex || index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    notifyListeners();
  }

  /// Pindahkan posisi lagu di antrean (drag reorder), otomatis
  /// menyesuaikan currentIndex kalau posisi lagu yang sedang diputar ikut bergeser.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= _queue.length) return;

    final movedSong = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, movedSong);

    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    notifyListeners();
  }

  void _onTrackFinished() {
    if (_repeatMode == RepeatMode.one) {
      _playCurrent();
      return;
    }
    _advanceIndex();
    if (_queue.isNotEmpty) _playCurrent();
  }

  void _advanceIndex() {
    if (_queue.isEmpty) return;
    if (_shuffle) {
      final rand = (DateTime.now().millisecondsSinceEpoch % _queue.length);
      _currentIndex = rand;
    } else if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = 0;
    }
  }

  double get playbackSpeed => _player.speed;

  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  /// Timer untuk berhenti otomatis setelah durasi tertentu
  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () async {
      _logListening();
      await _player.pause();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  /// Catat durasi dengar ke DB untuk keperluan dashboard
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
    await _player.dispose();
  }
}
