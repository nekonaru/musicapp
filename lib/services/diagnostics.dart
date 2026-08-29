/// Penampung error startup yang gagal tapi gak fatal (dibungkus try-catch),
/// supaya bisa ditampilkan langsung di app buat debugging tanpa perlu adb/logcat.
class Diagnostics {
  static String? audioServiceError;
}
