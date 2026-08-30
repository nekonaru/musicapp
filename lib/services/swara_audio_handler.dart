import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'player_service.dart';
import 'db_helper.dart';

/// Adapter tipis di atas [PlayerService]. Menerjemahkan state pemutaran ke
/// MediaSession Android untuk notifikasi, lockscreen, dan foreground service.
/// Tombol notifikasi: Favorit | Sebelumnya | Play/Pause | Berikutnya | Tutup
class SwaraAudioHandler extends BaseAudioHandler {
  Timer? _positionTicker;

  static const _favoriteAction = MediaControl(
    androidIcon: 'drawable/ic_notif_favorite',
    label: 'Favorit',
    action: MediaAction.custom,
    customAction: CustomMediaAction(name: 'favorite'),
  );

  // Gunakan stop action bawaan sebagai tombol "Tutup"
  static const _closeAction = MediaControl(
    androidIcon: 'drawable/ic_notif_close',
    label: 'Tutup',
    action: MediaAction.stop,
  );

  SwaraAudioHandler() {
    PlayerService.instance.addListener(_syncState);
    _positionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (PlayerService.instance.player.playing) _syncState();
    });
    _syncState();
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
              artUri: song.albumArtPath != null
                  ? Uri.file(song.albumArtPath!)
                  : null,
            ),
    );

    final playing = ps.player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          _favoriteAction,
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          _closeAction,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
          MediaAction.stop,
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
      case 'favorite':
        final song = PlayerService.instance.currentSong;
        if (song != null) {
          final newVal = !song.isFavorite;
          await DBHelper.instance.setFavorite(song.id, newVal);
          song.isFavorite = newVal;
          PlayerService.instance.notifyListeners();
        }
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
