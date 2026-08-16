import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'db_helper.dart';

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

  // Untuk mencatat berapa lama lagu benar-benar didengar
  DateTime? _playStartedAt;
  int _accumulatedListenedMs = 0;

  AudioPlayer get player => _player;
  Song? get currentSong => _queue.isEmpty ? null : _queue[_currentIndex];
  bool get isShuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;
  List<Song> get queue => _queue;

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
    _queue = songs;
    _currentIndex = startIndex;
    await _playCurrent();
    notifyListeners();
  }

  Future<void> _playCurrent() async {
    final song = currentSong;
    if (song == null) return;
    await _player.setFilePath(song.filePath);
    await _player.play();
    _playStartedAt = DateTime.now();
    _accumulatedListenedMs = 0;
    await DBHelper.instance.markPlayed(song.id);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      _logListening();
      await _player.pause();
    } else {
      _playStartedAt = DateTime.now();
      await _player.play();
    }
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
