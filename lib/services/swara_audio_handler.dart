import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'player_service.dart';

/// Adapter tipis di atas [PlayerService] yang sudah ada, BUKAN pengganti
/// logic pemutaran. Semua state (queue, shuffle, crossfade, sleep timer, dst)
/// tetap sepenuhnya dikelola PlayerService seperti sebelumnya - handler ini
/// cuma menerjemahkan state itu ke MediaSession Android (untuk notifikasi
/// asli, lockscreen, dan foreground service), dan meneruskan balik perintah
/// dari tombol notifikasi/lockscreen ke PlayerService.
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
    // notifyListeners() di PlayerService tidak dipanggil tiap tick posisi
    // lagu berjalan, jadi progress bar di lockscreen perlu didorong berkala
    // sendiri di sini supaya tidak diam di tempat selama lagu diputar.
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
              artUri: song.albumArtPath != null ? Uri.file(song.albumArtPath!) : null,
            ),
    );

    final playing = ps.player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        // 5 tombol: acak, sebelumnya, play/pause, berikutnya, ulangi - sama
        // dengan baris kontrol utama di layar player. Notifikasi Android
        // umumnya cuma cukup buat 5 tombol, jadi favorit sengaja tidak
        // disertakan di sini (tetap ada di layar player).
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
  Future<void> seek(Duration position) => PlayerService.instance.player.seek(position);

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
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
