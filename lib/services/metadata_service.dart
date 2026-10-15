import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'db_helper.dart';

/// Guesses and completes song metadata from the title/file name:
/// - Album art via the iTunes Search API (free, no API key)
/// - Lyrics via lyrics.ovh (free, no API key)
/// - Genre via the iTunes Search API
/// - Region guessed from the artist's home country (simple heuristic, manually editable)
class MetadataService {
  MetadataService._();
  static final MetadataService instance = MetadataService._();

  /// Start of the 429 backoff window. While now is before this value,
  /// enrich calls skip the network so a burst of 429s does not repeat.
  /// Single 30 second window, no retry loop. Leftovers are retried on
  /// a later scan because they keep metadataScanned false.
  DateTime? _rateLimitUntil;

  static const _rateLimitBackoff = Duration(seconds: 30);

  /// True while inside the 429 backoff window.
  bool get isRateLimited =>
      _rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!);

  /// Cleans the title from the file name, stripping track numbers, underscores, etc,
  /// and tries to split an "Artist - Title.mp3" pattern
  Map<String, String> parseFromFilename(String filePath) {
    String name = filePath.substring(filePath.lastIndexOf('/') + 1);
    name = name.replaceAll(RegExp(r'\.(mp3|flac|wav|m4a|ogg)$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'^\d+[\.\-_\s]*'), ''); // drop a leading track number
    name = name.replaceAll('_', ' ').trim();

    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      return {'artist': parts[0].trim(), 'title': parts.sublist(1).join(' - ').trim()};
    }
    return {'artist': '', 'title': name};
  }

  /// Enrich one song from iTunes + lyrics.
  /// Returns true when iTunes rate limited the request (HTTP 429) or the
  /// backoff window is still active, so batch callers can stop at once.
  /// Returns false otherwise. Success behavior is unchanged.
  Future<bool> enrichSong(Song song) async {
    // Inside the backoff window: skip the network and leave the song
    // unscanned so a later scan retries it. No retry loop here.
    if (isRateLimited) {
      debugPrint('iTunes backoff active, skip enrich ${song.title}');
      return true;
    }
    bool rateLimited = false;
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
        // iTunes rate limit during a bulk scan: start a single 30 second
        // backoff and leave this song unscanned for the next scan.
        // No retry loop here, the batch caller stops at once.
        rateLimited = true;
        _rateLimitUntil = DateTime.now().add(_rateLimitBackoff);
        debugPrint('iTunes rate-limit (429), skip enrich ${song.title}');
      }
    } catch (_) {
      // Fetch failed (offline/network error) - keep whatever metadata is there
    }
    if (rateLimited) {
      // Persist harmless fallbacks but keep metadataScanned false so the
      // next scan retries this song and the rest of the batch.
      song.region ??= 'Tidak diketahui';
      song.genre ??= 'Tidak diketahui';
      song.metadataScanned = false;
      await DBHelper.instance.upsertSong(song);
      return true;
    }
    // This fallback MUST stay outside the try-catch so it still runs when the
    // request succeeds but the song is simply not found on iTunes (resultCount == 0) -
    // the common case for local/indie songs that are not listed there.
    song.region ??= 'Tidak diketahui';
    song.genre ??= 'Tidak diketahui';

    // Fetch lyrics separately
    await fetchLyricsOnly(song);

    song.metadataScanned = true;
    await DBHelper.instance.upsertSong(song);
    return false;
  }

  /// Enrich [songs] in order and stop at the first 429 or backoff hit.
  /// Returns true when the batch stopped early because of rate limiting.
  /// Remaining songs keep metadataScanned false and are retried on a
  /// later scan. There is no retry loop here by design.
  Future<bool> enrichBatch(List<Song> songs) async {
    for (final song in songs) {
      final limited = await enrichSong(song);
      if (limited) return true;
    }
    return false;
  }

  /// Fetch lyrics only WITHOUT overwriting title/artist/album - used by the
  /// PlayerScreen auto-fetch so manual user edits are never clobbered.
  Future<bool> fetchLyricsOnly(Song song) async {
    // Never call the API with empty/unknown fields - guaranteed 404 + wasted quota.
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
          // Cap at 100KB so the DB does not bloat / OOM on anomalous lyrics.
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
      // Lyrics not found, keep null - the user can fill them in via the edit feature
    }
    return false;
  }

  /// Limit metadata field length (keep giant HTML out of the DB) + trim.
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
