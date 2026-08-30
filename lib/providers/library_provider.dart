import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../services/db_helper.dart';
import '../services/library_scanner.dart';
import '../services/metadata_service.dart';
import '../utils/format.dart';

enum SortOption {
  titleAZ,
  titleZA,
  artistAZ,
  artistZA,
  albumAZ,
  albumZA,
  dateAddedNewest,
  dateAddedOldest,
  genre,
}

String sortOptionLabel(SortOption opt) {
  switch (opt) {
    case SortOption.titleAZ: return 'Judul \u2191';
    case SortOption.titleZA: return 'Judul \u2193';
    case SortOption.artistAZ: return 'Artis \u2191';
    case SortOption.artistZA: return 'Artis \u2193';
    case SortOption.albumAZ: return 'Album \u2191';
    case SortOption.albumZA: return 'Album \u2193';
    case SortOption.dateAddedNewest: return 'Tanggal \u2191';
    case SortOption.dateAddedOldest: return 'Tanggal \u2193';
    case SortOption.genre: return 'Genre \u2191';
  }
}

class LibraryProvider extends ChangeNotifier {
  List<Song> songs = [];
  bool isScanning = false;
  bool isBulkScanningMetadata = false;
  int bulkScanProgress = 0;
  int bulkScanTotal = 0;
  String? scanError;
  SortOption sortOption = SortOption.titleAZ;

  static const _kSortOption = 'lib_sort_option';
  static const _kLastDeviceScan = 'last_device_scan_ms';
  // Scan otomatis hanya kalau sudah lebih dari 30 menit
  static const _scanIntervalMs = 1800000;

  LibraryProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kSortOption) ?? 0;
    sortOption = SortOption.values[idx.clamp(0, SortOption.values.length - 1)];
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSortOption, sortOption.index);
  }

  /// Load dari DB (instan, tidak scan device) - dipanggil saat app buka
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

  /// Load dari DB lalu scan device di background hanya jika diperlukan.
  /// Lagu muncul instan dari DB, scan hanya berjalan kalau sudah lama tidak scan.
  Future<void> autoLoadAndScanIfNeeded() async {
    // Step 1: Load DB dulu - musik langsung muncul
    await loadFromDb();

    // Step 2: Cek apakah perlu scan device
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastDeviceScan) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - lastMs;

    // Kalau lagu sudah ada dan scan terakhir belum lama, skip scan
    if (songs.isNotEmpty && elapsed < _scanIntervalMs) return;

    // Scan device (tanpa internet) di background
    await scanDevice();
    await prefs.setInt(_kLastDeviceScan, nowMs);
  }

  /// Scan file dari HP (deteksi lagu baru/hapus), TANPA fetch metadata internet.
  Future<void> scanDevice() async {
    isScanning = true;
    scanError = null;
    notifyListeners();
    try {
      await LibraryScanner().scanAndSync(autoFetchMetadata: false);
      await loadFromDb();
    } catch (e) {
      scanError = e.toString();
    }
    isScanning = false;
    notifyListeners();
  }

  /// Force scan device dan update timestamp
  Future<void> forceScanDevice() async {
    await scanDevice();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastDeviceScan, DateTime.now().millisecondsSinceEpoch);
  }

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

  Future<void> rescanSingleMetadata(Song song) async {
    await MetadataService.instance.enrichSong(song);
    await loadFromDb();
  }

  void setSortOption(SortOption option) {
    sortOption = option;
    _applySort();
    _savePrefs();
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
      case SortOption.artistZA:
        songs.sort((a, b) => b.artist.toLowerCase().compareTo(a.artist.toLowerCase()));
        break;
      case SortOption.albumAZ:
        songs.sort((a, b) => (a.album).toLowerCase().compareTo((b.album).toLowerCase()));
        break;
      case SortOption.albumZA:
        songs.sort((a, b) => (b.album).toLowerCase().compareTo((a.album).toLowerCase()));
        break;
      case SortOption.dateAddedNewest:
        songs.sort((a, b) {
          final da = a.addedAt;
          final db = b.addedAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
        break;
      case SortOption.dateAddedOldest:
        songs.sort((a, b) {
          final da = a.addedAt;
          final db = b.addedAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
        break;
      case SortOption.genre:
        songs.sort((a, b) => (a.genre ?? '').compareTo(b.genre ?? ''));
        break;
    }
  }

  List<Song> filteredSongs(String query) {
    if (query.trim().isEmpty) return songs;
    final q = query.toLowerCase();
    return songs.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q)).toList();
  }

  int get totalCount => songs.length;
  int get totalDurationMs => songs.fold(0, (sum, s) => sum + s.durationMs);

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

  Map<String, List<Song>> get groupedByArtist {
    final Map<String, List<Song>> map = {};
    for (final s in songs) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    return map;
  }

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

  Future<List<Song>> getRecentlyAdded({int limit = 50}) async {
    final all = await DBHelper.instance.getAllSongsByDateAdded();
    final excluded = await DBHelper.instance.getExcludedFolders();
    final filtered = excluded.isEmpty
        ? all
        : all.where((s) => !excluded.contains(folderOf(s.filePath))).toList();
    return filtered.take(limit).toList();
  }

  Future<List<Song>> getMostPlayed({int limit = 50}) async {
    return DBHelper.instance.getMostPlayedSongs(limit: limit);
  }
}
