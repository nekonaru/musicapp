import 'package:flutter/foundation.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import 'package:offline_music_player/providers/language_provider.dart';
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
  // Auto scan only when more than 30 minutes have passed
  static const _scanIntervalMs = 1800000;

  // Guard so notifyListeners never runs after dispose.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

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

  /// Load from DB (instant, no device scan) - called when the app opens
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

  /// Load from DB then scan the device in the background only if needed.
  /// Songs appear instantly from the DB, the scan only runs when the last
  /// scan is old enough.
  Future<void> autoLoadAndScanIfNeeded() async {
    // Step 1: load the DB first - music shows up right away
    await loadFromDb();

    // Step 2: check whether a device scan is needed
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastDeviceScan) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - lastMs;

    // Skip the scan when songs already exist and the last scan is recent
    if (songs.isNotEmpty && elapsed < _scanIntervalMs) return;

    // Scan the device (no internet) in the background
    await scanDevice();
    await prefs.setInt(_kLastDeviceScan, nowMs);
  }

  /// Scan files from the phone (detect new/removed songs).
  /// Fast path: device read + DB write only, no internet fetch, so the
  /// song list appears instantly at startup. Pass [autoFetchMetadata] true
  /// only when the caller explicitly wants the slow internet enrich inline.
  Future<void> scanDevice({bool autoFetchMetadata = false}) async {
    isScanning = true;
    scanError = null;
    notifyListeners();
    try {
      await LibraryScanner().scanAndSync(autoFetchMetadata: autoFetchMetadata);
      await loadFromDb();
    } catch (e) {
      scanError = '${lookupAppLocalizations(LanguageProvider.instance.locale).coreScanFailed}: $e';
    }
    isScanning = false;
    notifyListeners();
  }

  /// Force a device scan and refresh the timestamp
  Future<void> forceScanDevice({bool autoFetchMetadata = false}) async {
    await scanDevice(autoFetchMetadata: autoFetchMetadata);
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
      final batch = targets.skip(i).take(batchSize).toList();
      // Await the batch and stop at once on iTunes 429: leftovers keep
      // metadataScanned false and are retried on a later scan.
      // Single backoff window lives in MetadataService, no retry loop here.
      final results =
          await Future.wait(batch.map((song) => MetadataService.instance.enrichSong(song)));
      bulkScanProgress += batch.length;
      notifyListeners();
      if (results.any((limited) => limited)) break;
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

  /// Set favorites for many songs at once: a single batch write to the DB
  /// then ONE reload + notify (via loadFromDb). On failure -> scanError.
  Future<void> setFavoritesBulk(List<Song> songs, bool value) async {
    if (songs.isEmpty) return;
    try {
      await DBHelper.instance
          .setFavoritesBulk(songs.map((s) => s.id).toList(), value);
      await loadFromDb();
    } catch (e) {
      scanError = '${lookupAppLocalizations(LanguageProvider.instance.locale).coreUpdateFavoritesFailed}: $e';
      notifyListeners();
    }
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
