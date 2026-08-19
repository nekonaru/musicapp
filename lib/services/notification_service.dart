import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'player_service.dart';

/// Menampilkan notifikasi kontrol musik (judul lagu + tombol play/pause/next/prev)
/// selama aplikasi masih hidup di background (belum di-swipe dari recent apps).
/// Pendekatan ini lebih ringan dan stabil dibanding audio_service/foreground service penuh.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const int _notificationId = 888;

  Future<void> init() async {
    if (_initialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      _initialized = true;
    } catch (e) {
      // Kalau gagal init, aplikasi tetap jalan normal cuma tanpa notifikasi kontrol
      _initialized = false;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    switch (response.actionId) {
      case 'play_pause':
        PlayerService.instance.togglePlayPause();
        break;
      case 'next':
        PlayerService.instance.next();
        break;
      case 'previous':
        PlayerService.instance.previous();
        break;
    }
  }

  Future<void> showOrUpdate({
    required String title,
    required String artist,
    required bool isPlaying,
  }) async {
    if (!_initialized) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        'swara_playback_channel',
        'Kontrol Musik Swara',
        channelDescription: 'Kontrol putar musik dari notifikasi',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: isPlaying,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        actions: [
          const AndroidNotificationAction('previous', 'Sebelumnya'),
          AndroidNotificationAction('play_pause', isPlaying ? 'Jeda' : 'Putar'),
          const AndroidNotificationAction('next', 'Berikutnya'),
        ],
      );
      final details = NotificationDetails(android: androidDetails);
      await _plugin.show(_notificationId, title, artist, details);
    } catch (_) {
      // Abaikan kalau gagal, tidak mengganggu pemutaran musik utama
    }
  }

  Future<void> cancel() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_notificationId);
    } catch (_) {}
  }
}
