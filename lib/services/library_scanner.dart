import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import 'db_helper.dart';
import 'metadata_service.dart';
import '../utils/format.dart';

class LibraryScanner {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> requestPermission() async {
    final status = await Permission.audio.request();
    if (status.isGranted) return true;
    // fallback untuk Android < 13
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  /// Scan semua file musik di device, simpan ke DB kalau belum ada,
  /// lalu jalankan auto-fetch metadata untuk lagu yang masih kosong.
  Future<List<Song>> scanAndSync({bool autoFetchMetadata = true}) async {
    final granted = await requestPermission();
    if (!granted) {
      throw Exception('Izin akses musik ditolak');
    }

    final excluded = await DBHelper.instance.getExcludedFolders();
    final tracks = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );

    final List<Song> result = [];
    for (final track in tracks) {
      final folder = folderOf(track.data);
      if (excluded.contains(folder)) continue;

      final song = Song(
        id: track.id,
        filePath: track.data,
        title: (track.title.isNotEmpty) ? track.title : _titleFromFilename(track.data),
        artist: (track.artist != null && track.artist != '<unknown>')
            ? track.artist!
            : 'Unknown Artist',
        album: track.album ?? 'Unknown Album',
        durationMs: track.duration ?? 0,
      );
      await DBHelper.instance.upsertSong(song);
      result.add(song);
    }

    if (autoFetchMetadata) {
      // Lengkapi metadata (genre, region, lirik, album art) di background
      // untuk lagu yang belum punya data lengkap.
      for (final song in result) {
        if (song.genre == null || song.lyrics == null || song.albumArtUrl == null) {
          await MetadataService.instance.enrichSong(song);
        }
      }
    }

    return result;
  }

  /// Daftar folder unik tempat file musik ditemukan, untuk fitur "Folder Lagu"
  Future<List<String>> listMusicFolders() async {
    final all = await DBHelper.instance.getAllSongs();
    final folders = <String>{};
    for (final s in all) {
      folders.add(folderOf(s.filePath));
    }
    return folders.toList()..sort();
  }

  Future<List<Song>> getSongsInFolder(String folderPath) async {
    final all = await DBHelper.instance.getAllSongs();
    return all.where((s) => s.filePath.startsWith(folderPath)).toList();
  }

  String _titleFromFilename(String path) {
    final name = path.substring(path.lastIndexOf('/') + 1);
    return name.replaceAll(RegExp(r'\.(mp3|flac|wav|m4a|ogg)$'), '');
  }
}
