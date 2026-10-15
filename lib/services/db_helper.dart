import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import 'package:offline_music_player/providers/language_provider.dart';
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
      version: 5,
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
            lastPlayedAt TEXT,
            addedAt TEXT,
            metadataScanned INTEGER DEFAULT 0
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
            position INTEGER DEFAULT 0,
            PRIMARY KEY (playlistId, songId)
          )
        ''');
        await db.execute('''
          CREATE TABLE folders(
            path TEXT PRIMARY KEY,
            includeInLibrary INTEGER DEFAULT 1
          )
        ''');
        // Index so ORDER BY / dashboard filters never full-scan.
        await db.execute('CREATE INDEX idx_songs_title ON songs(title)');
        await db.execute(
            'CREATE INDEX idx_songs_lastPlayedAt ON songs(lastPlayedAt)');
        await db.execute(
            'CREATE INDEX idx_listening_song_ts ON listening_entries(songId, timestamp)');
        await db.execute(
            'CREATE INDEX idx_playlist_songs_pid_pos ON playlist_songs(playlistId, position)');
        // Disk cache for iTunes search responses so reinstalls do not
        // refetch songs that were already looked up (hits and misses).
        await db.execute('''
          CREATE TABLE metadata_cache(
            query TEXT PRIMARY KEY,
            response TEXT,
            fetchedAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add the position column for the playlist reorder feature
          try {
            await db.execute('ALTER TABLE playlist_songs ADD COLUMN position INTEGER DEFAULT 0');
          } catch (_) {
            // Column may already exist, ignore
          }
        }
        if (oldVersion < 3) {
          // Add the addedAt column so the "Recently added" sort truly reflects
          // insert time instead of just reversing the current list order
          try {
            await db.execute('ALTER TABLE songs ADD COLUMN addedAt TEXT');
          } catch (_) {
            // Column may already exist, ignore
          }
        }
        if (oldVersion < 4) {
          // Explicitly mark songs whose metadata was already scanned,
          // so the "scan only songs missing metadata" feature stays accurate.
          try {
            await db.execute('ALTER TABLE songs ADD COLUMN metadataScanned INTEGER DEFAULT 0');
            // Never mark 'Tidak diketahui' as scanned - that is a fallback
            // value, not a real fetch result. Only genuine genre/lyrics count.
            await db.execute(
                "UPDATE songs SET metadataScanned = 1 WHERE (genre IS NOT NULL AND genre != 'Tidak diketahui') OR lyrics IS NOT NULL");
          } catch (_) {
            // Column may already exist, ignore
          }
          // Index for old DBs (v1-v3) that do not have them yet.
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_songs_title ON songs(title)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_songs_lastPlayedAt ON songs(lastPlayedAt)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_listening_song_ts ON listening_entries(songId, timestamp)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_playlist_songs_pid_pos ON playlist_songs(playlistId, position)');
          } catch (_) {}
        }
        if (oldVersion < 5) {
          // Disk cache for iTunes responses (hits and miss markers).
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS metadata_cache(
                query TEXT PRIMARY KEY,
                response TEXT,
                fetchedAt TEXT
              )
            ''');
          } catch (_) {
            // Table may already exist, ignore
          }
        }
      },
    );
  }

  // ---------- Songs ----------
  Future<void> upsertSong(Song s) async {
    final database = await db;
    // Keep the existing favorite status, lastPlayedAt, and addedAt,
    // so they are not reset every time the library is rescanned.
    final existing = await database.query('songs', where: 'id = ?', whereArgs: [s.id], limit: 1);
    final map = s.toMap();
    if (existing.isNotEmpty) {
      map['isFavorite'] = existing.first['isFavorite'];
      map['lastPlayedAt'] = existing.first['lastPlayedAt'];
      map['addedAt'] = existing.first['addedAt'];
      // IMPORTANT: use OR, not a plain copy of the old value.
      // - Called from library_scanner (file sync on every app open): the `s`
      //   object always has metadataScanned=false, so the OR result keeps the
      //   stored DB value (correct, never reset).
      // - Called from metadata_service (after enrich): the `s` object has
      //   metadataScanned=true, so the OR result is true (correct, SAVED,
      //   never clobbered by the still-false stored value).
      final wasScanned = existing.first['metadataScanned'] == 1;
      map['metadataScanned'] = (wasScanned || s.metadataScanned) ? 1 : 0;
    } else {
      map['addedAt'] = DateTime.now().toIso8601String();
    }
    await database.insert('songs', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Song>> getAllSongs() async {
    final database = await db;
    final rows = await database.query('songs', orderBy: 'title ASC');
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  /// Delete from the DB the songs whose original files no longer exist on the
  /// phone (deleted/moved by the user outside the app). [existingIds] holds
  /// ALL ids that are still truly detected on the device (including ones in
  /// hidden folders - so songs in hidden folders are NOT deleted).
  /// Song count in the DB - used by the safety guard in scanAndSync()
  /// to detect when querySongs() returns a suspicious result.
  Future<int> getSongCount() async {
    final database = await db;
    final result = await database.rawQuery('SELECT COUNT(*) as count FROM songs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteSongsMissingFromDevice(Set<int> existingIds) async {
    final database = await db;
    final allDbIds = (await database.query('songs', columns: ['id']))
        .map((r) => r['id'] as int)
        .toSet();
    final ghostIds = allDbIds.difference(existingIds);
    if (ghostIds.isEmpty) return 0;

    final batch = database.batch();
    for (final id in ghostIds) {
      batch.delete('songs', where: 'id = ?', whereArgs: [id]);
      batch.delete('playlist_songs', where: 'songId = ?', whereArgs: [id]);
      batch.delete('listening_entries', where: 'songId = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
    return ghostIds.length;
  }

  /// IDs of songs whose metadata was already scanned (so the app does not
  /// re-fetch from the internet for the same song over and over).
  Future<Set<int>> getScannedSongIds() async {
    final database = await db;
    final rows = await database.query('songs', where: 'metadataScanned = 1', columns: ['id']);
    return rows.map((r) => r['id'] as int).toSet();
  }

  /// Songs ordered by the time they were actually added to the library,
  /// not just by reversing the current list order.
  Future<List<Song>> getAllSongsByDateAdded() async {
    final database = await db;
    final rows = await database.query('songs', orderBy: 'addedAt DESC');
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
    // Read isFavorite from the DB first so it is not reset by a stale Song object.
    // Same protection as in upsertSong() - the user may have favorited the song
    // in another tab while the Edit Metadata screen was still open.
    final existing = await database.query('songs', columns: ['isFavorite'], where: 'id = ?', whereArgs: [s.id], limit: 1);
    final map = s.toMap();
    if (existing.isNotEmpty) {
      map['isFavorite'] = existing.first['isFavorite'];
    }
    await database.update('songs', map, where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> setFavorite(int songId, bool value) async {
    final database = await db;
    await database.update('songs', {'isFavorite': value ? 1 : 0},
        where: 'id = ?', whereArgs: [songId]);
  }

  /// Set favorites for many songs at once in a single batch + single commit.
  Future<void> setFavoritesBulk(List<int> songIds, bool value) async {
    if (songIds.isEmpty) return;
    try {
      final database = await db;
      final batch = database.batch();
      for (final id in songIds) {
        batch.update('songs', {'isFavorite': value ? 1 : 0},
            where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw StateError('${lookupAppLocalizations(LanguageProvider.instance.locale).coreUpdateFavoritesFailed} ${songIds.length} ${lookupAppLocalizations(LanguageProvider.instance.locale).coreSongs}: $e');
    }
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

  Future<List<Song>> getRecentlyPlayed({int limit = 50}) async {
    final database = await db;
    final rows = await database.query('songs',
        where: 'lastPlayedAt IS NOT NULL',
        orderBy: 'lastPlayedAt DESC',
        limit: limit);
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  // ---------- Listening history (for the dashboard) ----------
  Future<void> addListeningEntry(ListeningEntry e) async {
    final database = await db;
    await database.insert('listening_entries', e.toMap());
  }

  /// Total ms listened per day for the last 7 days (for the dashboard chart)
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

  /// Top songs by listening_entries count
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

  /// Top artists by total listening_entries joined against the songs table
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

  /// Genre distribution (song count per genre)
  Future<Map<String, int>> getGenreDistribution() async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT COALESCE(genre, 'Tidak diketahui') as genre, COUNT(*) as cnt
      FROM songs GROUP BY genre ORDER BY cnt DESC
    ''');
    return {for (final r in rows) r['genre'] as String: r['cnt'] as int};
  }

  /// Song origin-region distribution
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
    final maxPos = Sqflite.firstIntValue(await database.rawQuery(
        'SELECT MAX(position) as m FROM playlist_songs WHERE playlistId = ?', [playlistId])) ?? 0;
    await database.insert(
      'playlist_songs',
      {
        'playlistId': playlistId,
        'songId': songId,
        'addedAt': DateTime.now().toIso8601String(),
        'position': maxPos + 1,
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
      ORDER BY ps.position ASC, ps.addedAt ASC
    ''', [playlistId]);
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  /// Re-save the song order inside a playlist (called after a drag reorder)
  Future<void> reorderPlaylistSongs(int playlistId, List<int> songIdsInOrder) async {
    final database = await db;
    final batch = database.batch();
    for (int i = 0; i < songIdsInOrder.length; i++) {
      batch.update(
        'playlist_songs',
        {'position': i},
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, songIdsInOrder[i]],
      );
    }
    await batch.commit(noResult: true);
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

  /// Songs ordered by play count (most played first).
  /// A single JOIN query - no longer loads the whole songs table into memory.
  Future<List<Song>> getMostPlayedSongs({int limit = 50}) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT s.*, COUNT(le.id) as playCount
      FROM songs s
      JOIN listening_entries le ON le.songId = s.id
      GROUP BY s.id
      ORDER BY playCount DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  /// Songs that were never played at all
  Future<List<Song>> getNeverPlayedSongs() async {
    final database = await db;
    final rows = await database.query(
      'songs',
      where: 'lastPlayedAt IS NULL',
      orderBy: 'title ASC',
    );
    return rows.map((r) => Song.fromMap(r)).toList();
  }

  /// Total all-time listening time (ms)
  Future<int> getTotalListeningMs() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COALESCE(SUM(listenedMs), 0) as total FROM listening_entries');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Total listening time this month (ms)
  Future<int> getThisMonthListeningMs() async {
    final database = await db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toIso8601String();
    final result = await database.rawQuery(
        'SELECT COALESCE(SUM(listenedMs), 0) as total FROM listening_entries WHERE timestamp >= ?',
        [start]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------- iTunes metadata disk cache ----------
  /// Raw cached iTunes response for [query], or null when absent.
  /// The returned map holds 'response' and 'fetchedAt' strings.
  /// TTL checks are done by the caller so hit and miss markers can
  /// use different lifetimes.
  Future<Map<String, String>?> getMetadataCache(String query) async {
    final database = await db;
    final rows = await database.query('metadata_cache',
        columns: ['response', 'fetchedAt'],
        where: 'query = ?',
        whereArgs: [query],
        limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return {
      'response': (row['response'] ?? '').toString(),
      'fetchedAt': (row['fetchedAt'] ?? '').toString(),
    };
  }

  /// Insert or replace the cached iTunes response for [query].
  Future<void> putMetadataCache(String query, String response) async {
    final database = await db;
    await database.insert(
      'metadata_cache',
      {
        'query': query,
        'response': response,
        'fetchedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
