import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/db_helper.dart';
import '../services/library_scanner.dart';
import '../services/metadata_service.dart';

enum SortOption { titleAZ, titleZA, artistAZ, dateAddedNewest, genre }

class LibraryProvider extends ChangeNotifier {
  List<Song> songs = [];
  bool isScanning = false;
  bool isBulkScanningMetadata = false;
  int bulkScanProgress = 0;
  int bulkScanTotal = 0;
  String? scanError;
  SortOption sortOption = SortOption.titleAZ;
  String searchQuery = '';

  Future<void> loadFromDb() async {
    final all = await DBHelper.instance.getAllSongs();
    final excluded = await DBHelper.instance.getExcludedFolders();
    songs = excluded.isEmpty
        ? all
        : all.where((s) {
            final folder = s.filePath.substring(0, s.filePath.lastIndexOf('/'));
            return !excluded.contains(folder);
          }).toList();
    _applySort();
    notifyListeners();
  }

  Future<void> scanDevice() async {
    isScanning = true;
    scanError = null;
    notifyListeners();
    try {
      await LibraryScanner().scanAndSync();
      await loadFromDb();
      isScanning = false;
      notifyListeners();
      return;
    } catch (e) {
      scanError = e.toString();
    }
    isScanning = false;
    notifyListeners();
  }

  /// Scan ulang metadata untuk SEMUA lagu di library (dipanggil dari tombol bulk scan)
  Future<void> bulkScanMetadata() async {
    isBulkScanningMetadata = true;
    bulkScanTotal = songs.length;
    bulkScanProgress = 0;
    notifyListeners();
    for (final song in songs) {
      await MetadataService.instance.enrichSong(song);
      bulkScanProgress++;
      notifyListeners();
    }
    isBulkScanningMetadata = false;
    await loadFromDb();
  }

  /// Scan ulang metadata untuk satu lagu saja (dipanggil dari tombol di layar edit)
  Future<void> rescanSingleMetadata(Song song) async {
    await MetadataService.instance.enrichSong(song);
    await loadFromDb();
  }

  void setSortOption(SortOption option) {
    sortOption = option;
    _applySort();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void _applySort() {
    switch (sortOption) {
      case SortOption.titleAZ:
        songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.titleZA:
        songs.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case SortOption.artistAZ:
        songs.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortOption.dateAddedNewest:
        songs = songs.reversed.toList();
        break;
      case SortOption.genre:
        songs.sort((a, b) => (a.genre ?? '').compareTo(b.genre ?? ''));
        break;
    }
  }

  /// Lagu yang ditampilkan setelah difilter oleh search query (real-time)
  List<Song> get filteredSongs {
    if (searchQuery.trim().isEmpty) return songs;
    final q = searchQuery.toLowerCase();
    return songs.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q)).toList();
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
