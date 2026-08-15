import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/song.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();
  Database? _db;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'music_app.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE songs(
            id INTEGER PRIMARY KEY,
            filePath TEXT UNIQUE,
            title TEXT,
            artist TEXT,
            album TEXT,
            genre TEXT,
            region TEXT,
            albumArtPath TEXT,
            albumArtUrl TEXT,
            lyrics TEXT,
            durationMs INTEGER,
            isFavorite INTEGER DEFAULT 0,
            lastPlayedAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE listening_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            songId INTEGER,
            timestamp TEXT,
            listenedMs INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE playlists(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            createdAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_songs(
            playlistId INTEGER,
            songId INTEGER,
            addedAt TEXT,
            PRIMARY KEY (playlistId, songId)
          )
        ''');
        await db.execute('''
          CREATE TABLE folders(
            path TEXT PRIMARY KEY,
            includeInLibrary INTEGER DEFAULT 1
          )
        ''');
      },
    );
  }

  // ---------- Songs ----------
  Future<void> upsertSong(Song s) async {
    final database = await db;
    await database.insert('songs', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Song>> getAllSongs() async {
    final database = await db;
    final rows = await database.query('songs', orderBy: 'title ASC');
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  Future<void> deleteSong(int id) async {
    final database = await db;
    await database.delete('songs', where: 'id = ?', whereArgs: [id]);
    await database
        .delete('playlist_songs', where: 'songId = ?', whereArgs: [id]);
    await database
        .delete('listening_entries', where: 'songId = ?', whereArgs: [id]);
  }

  Future<void> updateSongMetadata(Song s) async {
    final database = await db;
    await database.update('songs', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> setFavorite(int songId, bool value) async {
    final database = await db;
    await database.update('songs', {'isFavorite': value ? 1 : 0},
        where: 'id = ?', whereArgs: [songId]);
  }

  Future<List<Song>> getFavorites() async {
    final database = await db;
    final rows =
        await database.query('songs', where: 'isFavorite = 1', orderBy: 'title ASC');
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  Future<void> markPlayed(int songId) async {
    final database = await db;
    await database.update(
        'songs', {'lastPlayedAt': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [songId]);
  }

  Future<List<Song>> getRecentlyPlayed({int limit = 30}) async {
    final database = await db;
    final rows = await database.query('songs',
        where: 'lastPlayedAt IS NOT NULL',
        orderBy: 'lastPlayedAt DESC',
        limit: limit);
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  // ---------- Listening history (untuk dashboard) ----------
  Future<void> addListeningEntry(ListeningEntry e) async {
    final database = await db;
    await database.insert('listening_entries', e.toMap());
  }

  /// Total ms didengar per hari, 7 hari terakhir (untuk grafik dashboard)
  Future<Map<DateTime, int>> getDailyListeningLast7Days() async {
    final database = await db;
    final since = DateTime.now().subtract(const Duration(days: 6));
    final sinceStr =
        DateTime(since.year, since.month, since.day).toIso8601String();
    final rows = await database.query('listening_entries',
        where: 'timestamp >= ?', whereArgs: [sinceStr]);

    final Map<DateTime, int> result = {};
    for (int i = 0; i < 7; i++) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      result[DateTime(d.year, d.month, d.day)] = 0;
    }
    for (final r in rows) {
      final ts = DateTime.parse(r['timestamp'] as String);
      final key = DateTime(ts.year, ts.month, ts.day);
      if (result.containsKey(key)) {
        result[key] = result[key]! + (r['listenedMs'] as int);
      }
    }
    return result;
  }

  /// Top lagu berdasarkan jumlah listening_entries
  Future<List<MapEntry<int, int>>> getTopSongIds({int limit = 10}) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT songId, COUNT(*) as playCount
      FROM listening_entries
      GROUP BY songId
      ORDER BY playCount DESC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((r) => MapEntry(r['songId'] as int, r['playCount'] as int))
        .toList();
  }

  /// Top artis berdasarkan total listening_entries gabung ke tabel songs
  Future<List<MapEntry<String, int>>> getTopArtists({int limit = 10}) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT s.artist as artist, COUNT(*) as playCount
      FROM listening_entries le
      JOIN songs s ON s.id = le.songId
      GROUP BY s.artist
      ORDER BY playCount DESC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((r) => MapEntry(r['artist'] as String, r['playCount'] as int))
        .toList();
  }

  /// Distribusi genre (jumlah lagu per genre)
  Future<Map<String, int>> getGenreDistribution() async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT COALESCE(genre, 'Tidak diketahui') as genre, COUNT(*) as cnt
      FROM songs GROUP BY genre ORDER BY cnt DESC
    ''');
    return {for (final r in rows) r['genre'] as String: r['cnt'] as int};
  }

  /// Distribusi region asal lagu
  Future<Map<String, int>> getRegionDistribution() async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT COALESCE(region, 'Tidak diketahui') as region, COUNT(*) as cnt
      FROM songs GROUP BY region ORDER BY cnt DESC
    ''');
    return {for (final r in rows) r['region'] as String: r['cnt'] as int};
  }

  // ---------- Playlists ----------
  Future<int> createPlaylist(String name) async {
    final database = await db;
    return database.insert('playlists', {
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final database = await db;
    return database.query('playlists', orderBy: 'createdAt DESC');
  }

  Future<void> deletePlaylist(int id) async {
    final database = await db;
    await database.delete('playlists', where: 'id = ?', whereArgs: [id]);
    await database
        .delete('playlist_songs', where: 'playlistId = ?', whereArgs: [id]);
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final database = await db;
    await database.insert(
      'playlist_songs',
      {
        'playlistId': playlistId,
        'songId': songId,
        'addedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final database = await db;
    await database.delete('playlist_songs',
        where: 'playlistId = ? AND songId = ?', whereArgs: [playlistId, songId]);
  }

  Future<List<Song>> getSongsInPlaylist(int playlistId) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT s.* FROM songs s
      JOIN playlist_songs ps ON ps.songId = s.id
      WHERE ps.playlistId = ?
      ORDER BY ps.addedAt ASC
    ''', [playlistId]);
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  // ---------- Folders ----------
  Future<void> setFolderIncluded(String path, bool included) async {
    final database = await db;
    await database.insert(
      'folders',
      {'path': path, 'includeInLibrary': included ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<String>> getExcludedFolders() async {
    final database = await db;
    final rows = await database.query('folders', where: 'includeInLibrary = 0');
    return rows.map((r) => r['path'] as String).toSet();
  }
}
