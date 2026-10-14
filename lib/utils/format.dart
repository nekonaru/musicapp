/// Kategori urutan sortir: simbol/ikon dulu, lalu angka, lalu huruf latin,
/// terakhir aksara bahasa lain (Korea/China/Jepang/dll).
final _latinReg = RegExp(r'[a-zA-Z]');
final _digitReg = RegExp(r'[0-9]');

int _sortRank(String s) {
  if (s.isEmpty) return 0;
  final c = s.codeUnitAt(0);
  final ch = s[0];
  if (_latinReg.hasMatch(ch)) return 2; // huruf latin
  if (_digitReg.hasMatch(ch)) return 1; // angka
  if (c > 127) return 3; // aksara non-latin (CJK, dll)
  return 0; // simbol/ikon (#, [, dsb)
}

/// Bandingkan dua judul sesuai urutan: simbol < angka < huruf < aksara lain.
int compareTitles(String a, String b) {
  final rankA = _sortRank(a);
  final rankB = _sortRank(b);
  if (rankA != rankB) return rankA.compareTo(rankB);
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// Ambil path folder dari path file secara aman - dukung '/' (Android/Linux)
/// dan '\' (Windows) sekaligus. Kalau tidak ada separator sama sekali
/// (edge case), kembalikan string kosong alih-alih crash RangeError.
String folderOf(String filePath) {
  final normalized = filePath.replaceAll('\\', '/');
  final idx = normalized.lastIndexOf('/');
  if (idx == -1) return '';
  // Kembalikan folder dalam bentuk normal (slash) supaya perbandingan
  // excluded.contains(folder) konsisten di semua platform.
  return normalized.substring(0, idx);
}

/// Huruf pertama yang aman untuk avatar/A-Z - tidak pernah RangeError.
String safeInitial(String s) => s.isEmpty ? '#' : s[0].toUpperCase();
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
