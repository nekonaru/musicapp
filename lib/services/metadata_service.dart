import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'db_helper.dart';

/// Menebak & melengkapi metadata lagu berdasarkan judul/nama file:
/// - Album art via iTunes Search API (gratis, tanpa API key)
/// - Lirik via lyrics.ovh (gratis, tanpa API key)
/// - Genre via iTunes Search API
/// - Region ditebak dari negara asal artis (heuristik sederhana, bisa diedit manual)
class MetadataService {
  MetadataService._();
  static final MetadataService instance = MetadataService._();

  /// Membersihkan judul dari nama file, menghapus angka track, underscore, dsb,
  /// dan mencoba memisahkan pola "Artist - Title.mp3"
  Map<String, String> parseFromFilename(String filePath) {
    String name = filePath.substring(filePath.lastIndexOf('/') + 1);
    name = name.replaceAll(RegExp(r'\.(mp3|flac|wav|m4a|ogg)$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'^\d+[\.\-_\s]*'), ''); // buang nomor track di depan
    name = name.replaceAll('_', ' ').trim();

    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      return {'artist': parts[0].trim(), 'title': parts.sublist(1).join(' - ').trim()};
    }
    return {'artist': '', 'title': name};
  }

  Future<void> enrichSong(Song song) async {
    try {
      final query = Uri.encodeComponent('${song.artist} ${song.title}'.trim());
      final url = Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&limit=1');
      final res = await http.get(url).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['resultCount'] != null && data['resultCount'] > 0) {
          final track = data['results'][0];
          song.title = (track['trackName'] ?? song.title).toString();
          song.artist = (track['artistName'] ?? song.artist).toString();
          song.album = (track['collectionName'] ?? song.album).toString();
          song.genre = track['primaryGenreName']?.toString();
          song.albumArtUrl = (track['artworkUrl100'] as String?)
              ?.replaceAll('100x100', '600x600');
          song.region = _guessRegion(track['country']?.toString(), song.artist);
        }
      }
    } catch (_) {
      // Kalau gagal fetch (offline/no result), biarkan metadata apa adanya
      song.region ??= 'Tidak diketahui';
      song.genre ??= 'Tidak diketahui';
    }

    // Fetch lirik terpisah
    try {
      final lyricsUrl = Uri.parse(
          'https://api.lyrics.ovh/v1/${Uri.encodeComponent(song.artist)}/${Uri.encodeComponent(song.title)}');
      final res = await http.get(lyricsUrl).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['lyrics'] != null) {
          song.lyrics = data['lyrics'].toString();
        }
      }
    } catch (_) {
      // lirik tidak ditemukan, biarkan null — user bisa isi manual lewat fitur edit
    }

    await DBHelper.instance.upsertSong(song);
  }

  String _guessRegion(String? countryCode, String artist) {
    if (countryCode == null || countryCode.isEmpty) return 'Tidak diketahui';
    const map = {
      'IDN': 'Indonesia',
      'USA': 'Amerika Serikat',
      'GBR': 'Inggris',
      'KOR': 'Korea Selatan',
      'JPN': 'Jepang',
      'CAN': 'Kanada',
      'AUS': 'Australia',
    };
    return map[countryCode] ?? countryCode;
  }
}
