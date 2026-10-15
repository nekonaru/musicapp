/// Pure LRC (synced lyrics) parser, no Flutter or DB dependencies.
///
/// Supported line shape: one or more `[mm:ss.xx]text` timestamps followed
/// by the lyric text. Fractions may use `.` or `:` and carry 1 to 3 digits
/// (decisecond, centisecond, or millisecond). Metadata tags such as
/// `[ar:]`, `[ti:]`, `[al:]`, or `[length:]` carry no timing info and are
/// skipped, as are lines without any timestamp or without lyric text.

/// One synced lyric line: display [text] starting at [timeMs].
class LrcLine {
  final int timeMs;
  final String text;

  const LrcLine({required this.timeMs, required this.text});
}

/// Timestamps like `[mm:ss.xx]`; the fraction part is optional.
final RegExp _lrcTimestamp =
    RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// Metadata tags such as `[ar:artist]` or `[length: 03:45]`.
final RegExp _lrcMetaTag = RegExp(
  r'^\s*\[(ar|ti|al|au|by|length|offset|re|ve)\s*:',
  caseSensitive: false,
);

/// Parse raw LRC text into time ordered [LrcLine] entries.
///
/// A line with several timestamps yields one entry per timestamp sharing
/// the same text. Tag lines, timestamp-free lines, and lines with empty
/// text are skipped. The result is sorted by [LrcLine.timeMs].
List<LrcLine> parseLrc(String raw) {
  final lines = <LrcLine>[];
  for (final rawLine in raw.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (_lrcMetaTag.hasMatch(line)) continue;
    final matches = _lrcTimestamp.allMatches(line).toList();
    if (matches.isEmpty) continue;
    final text = line.replaceAll(_lrcTimestamp, '').trim();
    if (text.isEmpty) continue;
    for (final m in matches) {
      final minutes = int.parse(m.group(1)!);
      final seconds = int.parse(m.group(2)!);
      var millis = 0;
      final frac = m.group(3);
      if (frac != null) {
        // Normalize 1-3 digit fractions to milliseconds.
        millis = int.parse((frac + '000').substring(0, 3));
      }
      lines.add(LrcLine(
        timeMs: minutes * 60000 + seconds * 1000 + millis,
        text: text,
      ));
    }
  }
  lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return lines;
}
