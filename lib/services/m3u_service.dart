import 'dart:io';

// Requires the `file_picker` package (to be added to pubspec.yaml
// separately). Standard async picker pattern is used below.
import 'package:file_picker/file_picker.dart';

import '../models/song.dart';

// Result of matching M3U entries against the in-memory library.
class M3uMatch {
  final List<Song> matched;
  final int missing;

  const M3uMatch({required this.matched, required this.missing});
}

// Picked M3U file together with its library match result.
class M3uPicked {
  final String playlistName;
  final M3uMatch match;

  const M3uPicked({required this.playlistName, required this.match});
}

// Parses .m3u/.m3u8 playlist files and matches entries to library songs.
// Pure matching logic lives in [matchContent] so it can be tested
// without the file picker. Only existing model types are used.
class M3uService {
  M3uService._();

  // Parse M3U [content] and match each entry against [library].
  // Lines starting with '#' are skipped, except that '#EXTINF' title
  // lines are simply ignored (the following path line is what matters).
  // Relative paths resolve against [baseDir] (the M3U file folder).
  // Matching is exact on normalized filePath first, then falls back
  // to comparing file names with endsWith semantics.
  static M3uMatch matchContent({
    required String content,
    required String baseDir,
    required List<Song> library,
  }) {
    final entries = _parseEntries(content);
    final byPath = <String, Song>{};
    for (final song in library) {
      byPath.putIfAbsent(
        _normalizePath(song.filePath),
        () => song,
      );
    }

    final matched = <Song>[];
    final seenIds = <int>{};
    var missing = 0;
    for (final entry in entries) {
      final resolved = _resolveEntry(entry, baseDir);
      final normalized = _normalizePath(resolved);
      Song? hit = byPath[normalized];
      hit ??= _matchByFileName(normalized, library);
      if (hit == null) {
        missing++;
      } else if (seenIds.add(hit.id)) {
        matched.add(hit);
      }
    }
    return M3uMatch(matched: matched, missing: missing);
  }

  // Open the system file picker, read the chosen .m3u/.m3u8 file,
  // and match it against [library]. Returns null when the user
  // cancels or the picked file has no readable path.
  static Future<M3uPicked?> pickAndMatch(List<Song> library) async {
    final files = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['m3u', 'm3u8'],
    );
    if (files.isEmpty) return null;
    final path = files.first.path;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    final content = await file.readAsString();
    final match = matchContent(
      content: content,
      baseDir: _dirnameOf(path),
      library: library,
    );
    return M3uPicked(
      playlistName: _playlistNameFromPath(path),
      match: match,
    );
  }

  // Split raw M3U text into candidate path lines.
  static List<String> _parseEntries(String content) {
    final entries = <String>[];
    for (final rawLine in content.split('\n')) {
      var line = rawLine.trim();
      // Strip a UTF-8 BOM when the file starts with one.
      if (entries.isEmpty && line.startsWith('\uFEFF')) {
        line = line.substring(1);
      }
      if (line.isEmpty) continue;
      // Skip comments and directives; #EXTINF only carries a
      // display title, the path on the next line is what we need.
      if (line.startsWith('#')) continue;
      entries.add(line);
    }
    return entries;
  }

  // Resolve one M3U entry to an absolute path string.
  // file:// URIs are decoded, absolute paths pass through,
  // anything else is treated as relative to [baseDir].
  static String _resolveEntry(String entry, String baseDir) {
    final trimmed = entry.trim().replaceAll('\\', '/');
    if (trimmed.startsWith('file://')) {
      try {
        return Uri.parse(trimmed).toFilePath().replaceAll('\\', '/');
      } catch (_) {
        return trimmed;
      }
    }
    if (_isAbsolutePath(trimmed)) return trimmed;
    final base = baseDir.replaceAll('\\', '/');
    final sep = base.endsWith('/') ? '' : '/';
    return '$base$sep$trimmed';
  }

  static bool _isAbsolutePath(String value) {
    if (value.startsWith('/')) return true;
    // Windows drive letter, e.g. C:/Music/song.mp3
    if (value.length >= 3 &&
        RegExp(r'^[A-Za-z]:/').hasMatch(value)) {
      return true;
    }
    // UNC path, e.g. //server/share/song.mp3
    if (value.startsWith('//')) return true;
    return false;
  }

  // Lowercase with forward slashes and no trailing slash so
  // comparisons work across Windows and POSIX style paths.
  static String _normalizePath(String value) {
    var out = value.replaceAll('\\', '/');
    while (out.endsWith('/') && out.length > 1) {
      out = out.substring(0, out.length - 1);
    }
    return out.toLowerCase();
  }

  // Fallback match on the file name only: entry matches when the
  // library path ends with the entry file name. First hit wins.
  static Song? _matchByFileName(String normalizedEntry, List<Song> library) {
    final name = _basenameOf(normalizedEntry);
    if (name.isEmpty) return null;
    for (final song in library) {
      final libPath = _normalizePath(song.filePath);
      if (libPath == name ||
          libPath.endsWith('/$name') ||
          _basenameOf(libPath) == name) {
        return song;
      }
    }
    return null;
  }

  static String _basenameOf(String path) {
    final value = path.replaceAll('\\', '/');
    final idx = value.lastIndexOf('/');
    return idx < 0 ? value : value.substring(idx + 1);
  }

  // Folder of a picked file path without extra dependencies.
  static String _dirnameOf(String path) {
    final value = path.replaceAll('\\', '/');
    final idx = value.lastIndexOf('/');
    if (idx <= 0) return value;
    return path.substring(0, idx);
  }

  // Playlist default name: file name without its extension.
  static String _playlistNameFromPath(String path) {
    final base = _basenameOf(path);
    final dot = base.lastIndexOf('.');
    if (dot <= 0) return base;
    return base.substring(0, dot);
  }
}
