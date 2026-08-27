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
      version: 4,
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Tambahkan kolom position untuk fitur reorder playlist
          try {
            await db.execute('ALTER TABLE playlist_songs ADD COLUMN position INTEGER DEFAULT 0');
          } catch (_) {
            // Kolom mungkin sudah ada, abaikan
          }
        }
        if (oldVersion < 3) {
          // Tambahkan kolom addedAt supaya sort "Baru ditambahkan" benar-benar
          // berdasarkan waktu insert, bukan cuma membalik urutan list
          try {
            await db.execute('ALTER TABLE songs ADD COLUMN addedAt TEXT');
          } catch (_) {
            // Kolom mungkin sudah ada, abaikan
          }
        }
        if (oldVersion < 4) {
          // Tandai eksplisit lagu yang sudah pernah di-scan metadata-nya,
          // supaya fitur "scan yang belum ada metadata saja" akurat.
          try {
            await db.execute('ALTER TABLE songs ADD COLUMN metadataScanned INTEGER DEFAULT 0');
            await db.execute("UPDATE songs SET metadataScanned = 1 WHERE genre IS NOT NULL OR lyrics IS NOT NULL");
          } catch (_) {
            // Kolom mungkin sudah ada, abaikan
          }
        }
      },
    );
  }

  // ---------- Songs ----------
  Future<void> upsertSong(Song s) async {
    final database = await db;
    // Pertahankan status favorit, lastPlayedAt, dan addedAt yang sudah ada,
    // supaya tidak ke-reset tiap kali library di-scan ulang.
    final existing = await database.query('songs', where: 'id = ?', whereArgs: [s.id], limit: 1);
    final map = s.toMap();
    if (existing.isNotEmpty) {
      map['isFavorite'] = existing.first['isFavorite'];
      map['lastPlayedAt'] = existing.first['lastPlayedAt'];
      map['addedAt'] = existing.first['addedAt'];
      // PENTING: pakai OR, bukan sekadar copy nilai lama.
      // - Dipanggil dari library_scanner (file-sync tiap app dibuka): objek `s` selalu
      //   metadataScanned=false, jadi hasil OR = nilai lama di DB (benar, tidak ke-reset).
      // - Dipanggil dari metadata_service (setelah enrich): objek `s` metadataScanned=true,
      //   jadi hasil OR = true (benar, TERSIMPAN, tidak ketiban nilai lama yang masih false).
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

  /// Hapus dari DB lagu-lagu yang file aslinya sudah tidak ada lagi di HP
  /// (dihapus/dipindah user di luar aplikasi). [existingIds] adalah SEMUA id
  /// lagu yang masih benar-benar terdeteksi di device (termasuk yang folder-nya
  /// disembunyikan - supaya lagu di folder tersembunyi TIDAK ikut kehapus).
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

  /// Set ID lagu yang sudah pernah discan metadata-nya (dipakai supaya
  /// tidak fetch ulang ke internet untuk lagu yang sama berkali-kali).
  Future<Set<int>> getScannedSongIds() async {
    final database = await db;
    final rows = await database.query('songs', where: 'metadataScanned = 1', columns: ['id']);
    return rows.map((r) => r['id'] as int).toSet();
  }

  /// Lagu diurutkan berdasarkan waktu benar-benar ditambahkan ke library,
  /// bukan sekadar membalik urutan list saat ini.
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
    // Baca isFavorite dari DB dulu supaya tidak ter-reset oleh objek Song yang stale.
    // Sama seperti perlindungan di upsertSong() — user bisa saja me-favorite lagu
    // di tab lain sementara layar Edit Metadata masih terbuka.
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

  /// Simpan ulang urutan lagu dalam playlist (dipanggil setelah drag reorder)
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
}
