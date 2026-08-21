/// Ambil path folder dari path file secara aman - kalau tidak ada '/'
/// sama sekali (edge case), kembalikan string kosong alih-alih crash RangeError.
String folderOf(String filePath) {
  final idx = filePath.lastIndexOf('/');
  return idx == -1 ? '' : filePath.substring(0, idx);
}
String formatDuration(int ms) {
  final totalSeconds = (ms / 1000).round();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}';
  }
  return '${two(minutes)}:${two(seconds)}';
}

/// Format durasi total jadi teks ringkas seperti "2 jam 15 menit" atau "45 menit".
String formatDurationLong(int ms) {
  final totalMinutes = (ms / 60000).round();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0 && minutes > 0) return '$hours jam $minutes menit';
  if (hours > 0) return '$hours jam';
  return '$minutes menit';
}
