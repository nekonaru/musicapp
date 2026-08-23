import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/db_helper.dart';
import '../services/library_scanner.dart';
import '../services/metadata_service.dart';
import '../utils/format.dart';

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
            final folder = folderOf(s.filePath);
            return !excluded.contains(folder);
          }).toList();
    _applySort();
    notifyListeners();
  }

  /// Scan file dari HP (deteksi lagu baru/hapus), TANPA fetch metadata internet.
  /// Cepat dan aman dipanggil otomatis tiap kali app dibuka.
  Future<void> scanDevice() async {
    isScanning = true;
    scanError = null;
    notifyListeners();
    try {
      await LibraryScanner().scanAndSync(autoFetchMetadata: false);
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

  /// Scan ulang metadata (dipanggil dari tombol bulk scan di Semua Lagu/Folder).
  /// [onlyMissing] true = cuma proses lagu yang belum pernah discan (hemat, dipakai
  /// otomatis buat lagu baru); false = paksa scan ulang semua lagu dari nol.
  Future<void> bulkScanMetadata({bool onlyMissing = false}) async {
    final targets = onlyMissing ? songs.where((s) => !s.metadataScanned).toList() : songs;
    if (targets.isEmpty) return;

    isBulkScanningMetadata = true;
    bulkScanTotal = targets.length;
    bulkScanProgress = 0;
    notifyListeners();

    const batchSize = 5;
    for (int i = 0; i < targets.length; i += batchSize) {
      final batch = targets.skip(i).take(batchSize);
      await Future.wait(batch.map((song) => MetadataService.instance.enrichSong(song)));
      bulkScanProgress += batch.length;
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
        songs.sort((a, b) => compareTitles(a.title, b.title));
        break;
      case SortOption.titleZA:
        songs.sort((a, b) => compareTitles(b.title, a.title));
        break;
      case SortOption.artistAZ:
        songs.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortOption.dateAddedNewest:
        songs.sort((a, b) {
          final da = a.addedAt;
          final db = b.addedAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da); // terbaru duluan
        });
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

  int get totalCount => songs.length;
  int get totalDurationMs => songs.fold(0, (sum, s) => sum + s.durationMs);

  /// Reactive - otomatis update begitu ada toggleFavorite, tanpa perlu refresh manual
  List<Song> get favorites => songs.where((s) => s.isFavorite).toList();

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
