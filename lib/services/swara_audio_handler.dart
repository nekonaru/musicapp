import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'player_service.dart';

/// Thin adapter over [PlayerService]. Translates state into the Android
/// MediaSession for notifications, the lockscreen, and the foreground service.
///
/// Notification buttons: Shuffle | Previous | Play/Pause | Next | Repeat
/// (using the built-in drawables already present in res/)
class SwaraAudioHandler extends BaseAudioHandler {
  Timer? _positionTicker;

  static const _shuffleAction = MediaControl(
    androidIcon: 'drawable/ic_notif_shuffle',
    label: 'Acak',
    action: MediaAction.custom,
    customAction: CustomMediaAction(name: 'shuffle'),
  );

  static const _repeatAction = MediaControl(
    androidIcon: 'drawable/ic_notif_repeat',
    label: 'Ulangi',
    action: MediaAction.custom,
    customAction: CustomMediaAction(name: 'repeat'),
  );

  SwaraAudioHandler() {
    PlayerService.instance.addListener(_syncState);
    _positionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      try {
        if (PlayerService.instance.player.playing) _syncState();
      } catch (e) {
        debugPrint('Gagal sync audio handler: $e');
      }
    });
    _syncState();
  }

  bool _disposed = false;

  /// Dispose listeners + ticker so nothing leaks when the handler is discarded.
  void disposeHandler() {
    _disposed = true;
    _positionTicker?.cancel();
    _positionTicker = null;
    try {
      PlayerService.instance.removeListener(_syncState);
    } catch (_) {}
  }

  Uri? _safeArtUri(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      // Guard against path traversal / deleted files breaking the notification.
      if (!file.existsSync()) return null;
      return Uri.file(path);
    } catch (_) {
      return null;
    }
  }

  void _syncState() {
    final ps = PlayerService.instance;
    final song = ps.currentSong;

    mediaItem.add(
      song == null
          ? null
          : MediaItem(
              id: song.filePath,
              title: song.title,
              artist: song.artist,
              album: song.album,
              duration: Duration(milliseconds: song.durationMs),
              artUri: _safeArtUri(song.albumArtPath),
            ),
    );

    final playing = ps.player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          _shuffleAction,
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          _repeatAction,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
        },
        androidCompactActionIndices: const [1, 2, 3],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: ps.player.position,
        speed: ps.player.speed,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (!PlayerService.instance.player.playing) {
      await PlayerService.instance.togglePlayPause();
    }
  }

  @override
  Future<void> pause() async {
    if (PlayerService.instance.player.playing) {
      await PlayerService.instance.togglePlayPause();
    }
  }

  @override
  Future<void> skipToNext() => PlayerService.instance.next();

  @override
  Future<void> skipToPrevious() => PlayerService.instance.smartPrevious();

  @override
  Future<void> seek(Duration position) =>
      PlayerService.instance.player.seek(position);

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'shuffle':
        PlayerService.instance.toggleShuffle();
        break;
      case 'repeat':
        PlayerService.instance.cycleRepeatMode();
        break;
    }
  }

  @override
  Future<void> stop() async {
    if (PlayerService.instance.player.playing) {
      await PlayerService.instance.togglePlayPause();
    }
    _positionTicker?.cancel();
    await super.stop();
  }
}
