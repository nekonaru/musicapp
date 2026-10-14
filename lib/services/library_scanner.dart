import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import 'package:offline_music_player/providers/language_provider.dart';
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
    // fallback for Android < 13
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  /// Scan every music file on the device, store new ones in the DB,
  /// then (optionally) run auto-fetch metadata ONLY for songs that
  /// were truly never scanned before (checked from the DB, not the transient object).
  Future<List<Song>> scanAndSync({bool autoFetchMetadata = true}) async {
    final granted = await requestPermission();
    if (!granted) {
      throw Exception(lookupAppLocalizations(LanguageProvider.instance.locale).corePermissionDenied);
    }

    final excluded = await DBHelper.instance.getExcludedFolders();
    final alreadyScannedIds = await DBHelper.instance.getScannedSongIds();
    final tracks = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );

    // IDs of ALL songs that truly still exist on the device (including ones in
    // hidden folders) - used to clean up "ghost" songs without also deleting
    // songs that are merely hidden (not really gone).
    final allDeviceIds = tracks.map((t) => t.id).toSet();

    // Safety guard: never delete anything when querySongs() looks like it
    // returned a suspicious result - the MediaStore may not have finished
    // indexing, storage permission may have just been granted (race condition),
    // or the plugin may have failed temporarily. Without this guard, the whole
    // library could be wiped from the DB even though the files are still on
    // the phone.
    //
    // Conditions treated as unsafe:
    //   1. The device returns no songs at all (the most dangerous case)
    //   2. The song count drops by more than 50% versus what is already in the
    //      DB in a single scan - a normal drop is only a few songs (files the
    //      user really deleted), never half the library at once.
    final bool safeToDelete;
    if (allDeviceIds.isEmpty) {
      // No songs detected at all - almost certainly not a normal state.
      safeToDelete = false;
    } else {
      final dbCount = await DBHelper.instance.getSongCount();
      if (dbCount > 0 && allDeviceIds.length < dbCount * 0.5) {
        // The device reports fewer than 50% of the songs in the DB: suspect a partial query.
        safeToDelete = false;
      } else {
        safeToDelete = true;
      }
    }

    final List<Song> result = [];
    final List<Song> needsMetadata = [];
    for (final track in tracks) {
      final folder = folderOf(track.data);
      if (excluded.contains(folder)) continue;

      final song = Song(
        id: track.id,
        filePath: track.data,
        title: (track.title.isNotEmpty)
            ? track.title
            : _titleFromFilename(track.data),
        artist: (track.artist != null &&
                track.artist!.isNotEmpty &&
                track.artist != '<unknown>')
            ? track.artist!
            : 'Unknown Artist',
        album: (track.album?.isNotEmpty == true)
            ? track.album!
            : 'Unknown Album',
        durationMs: track.duration ?? 0,
      );
      await DBHelper.instance.upsertSong(song);
      result.add(song);

      // Check the REAL status from the DB (not the freshly built `song` object,
      // which always has genre=null even when the data is already stored in the DB).
      if (!alreadyScannedIds.contains(song.id)) {
        needsMetadata.add(song);
      }
    }

    // Clean up "ghost" songs - rows in the DB whose original files were
    // deleted/moved from the phone outside the app.
    // Only runs when querySongs() returns a sane result (see the guard above).
    if (safeToDelete) {
      await DBHelper.instance.deleteSongsMissingFromDevice(allDeviceIds);
    }

    if (autoFetchMetadata && needsMetadata.isNotEmpty) {
      const batchSize = 5;
      for (int i = 0; i < needsMetadata.length; i += batchSize) {
        final batch = needsMetadata.skip(i).take(batchSize);
        await Future.wait(batch.map((s) => MetadataService.instance.enrichSong(s)));
      }
    }

    return result;
  }

  /// Unique list of folders where music files were found, for the "Song Folders" feature
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
    // Append a trailing '/' so '/storage/Music' never matches '/storage/Music2'
    return all.where((s) => s.filePath.startsWith('$folderPath/')).toList();
  }

  String _titleFromFilename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.substring(normalized.lastIndexOf('/') + 1);
    return name
        .replaceAll(
            RegExp(r'\.(mp3|flac|wav|m4a|ogg|opus|aac|wma)$',
                caseSensitive: false),
            '')
        .trim();
  }
}
