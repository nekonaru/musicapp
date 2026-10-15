import 'dart:io';

import 'package:image/image.dart' as img; // NOTE: requires `image:` in pubspec (NOT added, see task report).
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

// Automatic playlist cover art built as a small collage.
//
// Picks up to 4 songs that have a local cover file in [Song.albumArtPath],
// composes a 400x400 grid, and stores it under the app documents directory
// as playlist_art_<id>.jpg. All failures return null and never throw, so
// callers can always fall back to an icon.
//
// NOTE on package:image API: written against the standard v4 API
// (decodeImage, copyResize, Image(width,height), fill, compositeImage,
// encodeJpg). If the resolved package version differs, adjust these calls.
class PlaylistArtService {
  PlaylistArtService._();

  static const int artSize = 400;
  static const int cellSize = 200;
  static const int maxSources = 4;

  // Last song count each playlist id was built with. Cheap rebuild guard:
  // skip the compose step when the file already exists for the same count.
  static final Map<int, int> _builtCounts = <int, int>{};

  static String? _docsPath;

  static String _fileName(int playlistId) => 'playlist_art_$playlistId.jpg';

  static Future<Directory?> _artDir() async {
    try {
      var base = _docsPath;
      if (base == null) {
        final docs = await getApplicationDocumentsDirectory();
        base = docs.path;
        _docsPath = base;
      }
      final dir = Directory(p.join(base, 'playlist_art'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  // File location for a playlist cover, or null when none is cached.
  // Read only, never builds. Used by UI tiles and headers.
  static Future<File?> existingArt(int playlistId) async {
    try {
      final dir = await _artDir();
      if (dir == null) return null;
      final file = File(p.join(dir.path, _fileName(playlistId)));
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Build (or reuse) the collage for [playlistId] from [songs].
  // Returns the art file, or null when there is nothing to show
  // or any step fails. Never throws.
  static Future<File?> buildPlaylistArt(
      int playlistId, List<Song> songs) async {
    try {
      final dir = await _artDir();
      if (dir == null) return null;
      final outFile = File(p.join(dir.path, _fileName(playlistId)));

      // Collect up to 4 songs with a readable local cover file.
      final sources = <File>[];
      for (final song in songs) {
        if (sources.length >= maxSources) break;
        final artPath = song.albumArtPath;
        if (artPath == null || artPath.isEmpty) continue;
        try {
          final f = File(artPath);
          if (f.existsSync() && f.lengthSync() > 0) {
            sources.add(f);
          }
        } catch (_) {
          // Skip unreadable entries, keep scanning the rest.
        }
      }

      // No local covers: drop any stale collage so the UI shows fallback.
      if (sources.isEmpty) {
        try {
          if (await outFile.exists()) {
            await outFile.delete();
          }
        } catch (_) {
          // Best effort only.
        }
        _builtCounts.remove(playlistId);
        return null;
      }

      // Cheap cache: same song count and a valid file means reuse.
      // Intentionally simple, no mtime tracking of source images.
      try {
        if (_builtCounts[playlistId] == songs.length &&
            await outFile.exists() &&
            await outFile.length() > 0) {
          return outFile;
        }
      } catch (_) {
        // Fall through to rebuild on any stat failure.
      }

      // Compose the 400x400 canvas. Empty grid slots stay theme grey.
      final canvas = img.Image(width: artSize, height: artSize);
      img.fill(canvas, color: img.ColorRgb8(158, 158, 158));

      if (sources.length == 1) {
        final full = _decodeSized(sources.first, artSize, artSize);
        if (full != null) {
          img.compositeImage(canvas, full, dstX: 0, dstY: 0);
        }
      } else {
        for (var i = 0; i < sources.length && i < maxSources; i++) {
          final cell = _decodeSized(sources[i], cellSize, cellSize);
          if (cell == null) continue;
          final dx = (i % 2) * cellSize;
          final dy = (i ~/ 2) * cellSize;
          img.compositeImage(canvas, cell, dstX: dx, dstY: dy);
        }
      }

      final jpg = img.encodeJpg(canvas, quality: 85);
      await outFile.writeAsBytes(jpg, flush: true);
      _builtCounts[playlistId] = songs.length;
      return outFile;
    } catch (_) {
      return null;
    }
  }

  // Delete the cached collage for [playlistId]. Never throws.
  static Future<void> clearPlaylistArt(int playlistId) async {
    _builtCounts.remove(playlistId);
    try {
      final dir = await _artDir();
      if (dir == null) return;
      final file = File(p.join(dir.path, _fileName(playlistId)));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort only.
    }
  }

  // Decode [file] and scale it to exactly [width]x[height] for the grid.
  // Returns null when decoding or resizing fails.
  static img.Image? _decodeSized(File file, int width, int height) {
    try {
      final bytes = file.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return img.copyResize(decoded, width: width, height: height);
    } catch (_) {
      return null;
    }
  }
}
