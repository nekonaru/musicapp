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
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        id: map['id'],
        filePath: map['filePath'],
        title: map['title'] ?? 'Unknown Title',
        artist: map['artist'] ?? 'Unknown Artist',
        album: map['album'] ?? 'Unknown Album',
        genre: map['genre'],
        region: map['region'],
        albumArtPath: map['albumArtPath'],
        albumArtUrl: map['albumArtUrl'],
        lyrics: map['lyrics'],
        durationMs: map['durationMs'] ?? 0,
        isFavorite: (map['isFavorite'] ?? 0) == 1,
      );
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

  factory ListeningEntry.fromMap(Map<String, dynamic> map) => ListeningEntry(
        id: map['id'],
        songId: map['songId'],
        timestamp: DateTime.parse(map['timestamp']),
        listenedMs: map['listenedMs'],
      );
}
