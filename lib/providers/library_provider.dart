import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/db_helper.dart';
import '../services/library_scanner.dart';

class LibraryProvider extends ChangeNotifier {
  List<Song> songs = [];
  bool isScanning = false;
  String? scanError;

  Future<void> loadFromDb() async {
    songs = await DBHelper.instance.getAllSongs();
    notifyListeners();
  }

  Future<void> scanDevice() async {
    isScanning = true;
    scanError = null;
    notifyListeners();
    try {
      songs = await LibraryScanner().scanAndSync();
    } catch (e) {
      scanError = e.toString();
    }
    isScanning = false;
    notifyListeners();
  }

  Future<void> toggleFavorite(Song song, bool value) async {
    await DBHelper.instance.setFavorite(song.id, value);
    await loadFromDb();
  }

  Future<void> deleteSong(Song song) async {
    await DBHelper.instance.deleteSong(song.id);
    songs.removeWhere((s) => s.id == song.id);
    notifyListeners();
  }

  Future<void> updateMetadata(Song song) async {
    await DBHelper.instance.updateSongMetadata(song);
    await loadFromDb();
  }

  List<Song> get sortedByArtist =>
      [...songs]..sort((a, b) => a.artist.compareTo(b.artist));

  Map<String, List<Song>> get groupedByGenre {
    final Map<String, List<Song>> map = {};
    for (final s in songs) {
      final key = s.genre ?? 'Tidak diketahui';
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  Map<String, List<Song>> get groupedByRegion {
    final Map<String, List<Song>> map = {};
    for (final s in songs) {
      final key = s.region ?? 'Tidak diketahui';
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }
}
