class Song {
  final int id;
  final String filePath;
  String title;
  String artist;
  String album;
  String? genre;
  String? region; // asal negara/daerah lagu, dideteksi dari artis/metadata
  String? albumArtPath; // path lokal ke cover yang sudah di-cache
  String? albumArtUrl; // url dari API kalau belum di-cache
  String? lyrics;
  int durationMs;
  bool isFavorite;
  DateTime? addedAt;
  bool metadataScanned;

  Song({
    required this.id,
    required this.filePath,
    required this.title,
    required this.artist,
    required this.album,
    this.genre,
    this.region,
    this.albumArtPath,
    this.albumArtUrl,
    this.lyrics,
    this.durationMs = 0,
    this.isFavorite = false,
    this.addedAt,
    this.metadataScanned = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'filePath': filePath,
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'region': region,
        'albumArtPath': albumArtPath,
        'albumArtUrl': albumArtUrl,
        'lyrics': lyrics,
        'durationMs': durationMs,
        'isFavorite': isFavorite ? 1 : 0,
        'addedAt': addedAt?.toIso8601String(),
        'metadataScanned': metadataScanned ? 1 : 0,
      };

  factory Song.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final rawPath = map['filePath'];
    if (rawId is! int || rawPath is! String || rawPath.isEmpty) {
      throw const FormatException('Baris songs korup: id/filePath tidak valid');
    }
    DateTime? parsedAddedAt;
    final rawAdded = map['addedAt'];
    if (rawAdded is String && rawAdded.isNotEmpty) {
      parsedAddedAt = DateTime.tryParse(rawAdded);
    }
    return Song(
      id: rawId,
      filePath: rawPath,
      title: (map['title'] as String?)?.isNotEmpty == true
          ? map['title'] as String
          : 'Unknown Title',
      artist: (map['artist'] as String?)?.isNotEmpty == true
          ? map['artist'] as String
          : 'Unknown Artist',
      album: (map['album'] as String?)?.isNotEmpty == true
          ? map['album'] as String
          : 'Unknown Album',
        genre: map['genre'] as String?,
        region: map['region'] as String?,
        albumArtPath: map['albumArtPath'] as String?,
        albumArtUrl: map['albumArtUrl'] as String?,
        lyrics: map['lyrics'] as String?,
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
        isFavorite: (map['isFavorite'] ?? 0) == 1,
        addedAt: parsedAddedAt,
        metadataScanned: (map['metadataScanned'] ?? 0) == 1,
      );
  }
}

/// Satu baris riwayat dengar, dicatat tiap sesi putar lagu selesai/berhenti.
class ListeningEntry {
  final int? id;
  final int songId;
  final DateTime timestamp;
  final int listenedMs; // durasi yang benar-benar didengar

  ListeningEntry({
    this.id,
    required this.songId,
    required this.timestamp,
    required this.listenedMs,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'songId': songId,
        'timestamp': timestamp.toIso8601String(),
        'listenedMs': listenedMs,
      };

  factory ListeningEntry.fromMap(Map<String, dynamic> map) {
    final rawTs = map['timestamp'];
    final parsedTs = rawTs is String ? DateTime.tryParse(rawTs) : null;
    return ListeningEntry(
      id: map['id'] as int?,
      songId: (map['songId'] as num?)?.toInt() ?? 0,
      timestamp: parsedTs ?? DateTime.fromMillisecondsSinceEpoch(0),
      listenedMs: (map['listenedMs'] as num?)?.toInt() ?? 0,
    );
  }
}
