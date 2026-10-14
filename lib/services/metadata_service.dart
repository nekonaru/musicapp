import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      final url = Uri.https('itunes.apple.com', '/search', {
        'term': '${song.artist} ${song.title}'.trim(),
        'entity': 'song',
        'limit': '1',
      });
      final res = await http
          .get(url, headers: {'User-Agent': 'Swara/1.0'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['resultCount'] != null && data['resultCount'] > 0) {
          final track = data['results'][0];
          song.title = _sanitizeField(track['trackName'], song.title);
          song.artist = _sanitizeField(track['artistName'], song.artist);
          song.album = _sanitizeField(track['collectionName'], song.album);
          final genre = track['primaryGenreName']?.toString();
          song.genre = genre != null ? _sanitizeField(genre, genre) : song.genre;
          song.albumArtUrl = (track['artworkUrl100'] as String?)
              ?.replaceAll('100x100', '600x600');
          song.region = _guessRegion(track['country']?.toString(), song.artist);
        }
      } else if (res.statusCode == 429) {
        // Rate-limit iTunes saat bulk scan — jangan tandai gagal permanen,
        // biarkan retry di scan berikutnya.
        debugPrint('iTunes rate-limit (429), skip enrich ${song.title}');
      }
    } catch (_) {
      // Gagal fetch (offline/error jaringan) - biarkan metadata apa adanya
    }
    // Fallback ini HARUS di luar try-catch supaya tetap jalan walau request
    // sukses tapi lagunya memang tidak ketemu di iTunes (resultCount == 0) -
    // kasus umum buat lagu lokal/indie yang tidak terdaftar di sana.
    song.region ??= 'Tidak diketahui';
    song.genre ??= 'Tidak diketahui';

    // Fetch lirik terpisah
    await fetchLyricsOnly(song);

    song.metadataScanned = true;
    await DBHelper.instance.upsertSong(song);
  }

  /// Fetch lirik saja TANPA menimpa judul/artis/album — dipakai PlayerScreen
  /// auto-fetch supaya edit manual user tidak ketimpa.
  Future<bool> fetchLyricsOnly(Song song) async {
    // Jangan panggil API dengan field kosong/unknown — pasti 404 + buang kuota.
    if (song.artist.isEmpty ||
        song.title.isEmpty ||
        song.artist == 'Unknown Artist' ||
        song.title == 'Unknown Title') {
      return false;
    }
    try {
      final lyricsUrl = Uri.https('api.lyrics.ovh', '/v1/${song.artist}/${song.title}');
      final res = await http
          .get(lyricsUrl, headers: {'User-Agent': 'Swara/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['lyrics'] != null) {
          var lyrics = data['lyrics'].toString().trim();
          // Cap 100KB supaya DB tidak bloat / OOM saat lagu punya lirik anomali.
          if (lyrics.length > 100 * 1024) {
            lyrics = lyrics.substring(0, 100 * 1024);
          }
          if (lyrics.isNotEmpty) {
            song.lyrics = lyrics;
            return true;
          }
        }
      }
    } catch (_) {
      // lirik tidak ditemukan, biarkan null — user bisa isi manual lewat fitur edit
    }
    return false;
  }

  /// Batasi panjang field metadata (cegah HTML raksasa masuk DB) + trim.
  String _sanitizeField(dynamic raw, String fallback) {
    final s = (raw ?? fallback).toString().trim();
    if (s.isEmpty) return fallback;
    return s.length > 300 ? s.substring(0, 300) : s;
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
