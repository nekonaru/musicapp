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
  /// lalu (opsional) jalankan auto-fetch metadata HANYA untuk lagu yang
  /// benar-benar belum pernah discan (dicek dari DB, bukan objek sementara).
  Future<List<Song>> scanAndSync({bool autoFetchMetadata = true}) async {
    final granted = await requestPermission();
    if (!granted) {
      throw Exception('Izin akses musik ditolak');
    }

    final excluded = await DBHelper.instance.getExcludedFolders();
    final alreadyScannedIds = await DBHelper.instance.getScannedSongIds();
    final tracks = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );

    // ID SEMUA lagu yang beneran masih ada di device (termasuk yang folder-nya
    // disembunyikan) - dipakai buat bersihkan "lagu hantu" tanpa ikut menghapus
    // lagu yang cuma disembunyikan (bukan beneran hilang).
    final allDeviceIds = tracks.map((t) => t.id).toSet();

    final List<Song> result = [];
    final List<Song> needsMetadata = [];
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

      // Cek status SEBENARNYA dari DB (bukan objek `song` yang baru dibuat,
      // yang selalu punya genre=null meski datanya sudah tersimpan di DB).
      if (!alreadyScannedIds.contains(song.id)) {
        needsMetadata.add(song);
      }
    }

    // Bersihkan lagu "hantu" - yang ada di DB tapi file aslinya sudah
    // dihapus/dipindah dari HP di luar aplikasi.
    await DBHelper.instance.deleteSongsMissingFromDevice(allDeviceIds);

    if (autoFetchMetadata && needsMetadata.isNotEmpty) {
      const batchSize = 5;
      for (int i = 0; i < needsMetadata.length; i += batchSize) {
        final batch = needsMetadata.skip(i).take(batchSize);
        await Future.wait(batch.map((s) => MetadataService.instance.enrichSong(s)));
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
