import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'player_service.dart';

@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
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
      // Android 13+ mewajibkan izin notifikasi diminta secara aktif saat runtime
      await Permission.notification.request();
      const androidInit = AndroidInitializationSettings('ic_stat_swara');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
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
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.transport,
        ongoing: isPlaying,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        showWhen: false,
        actions: [
          const AndroidNotificationAction(
            'previous', 'Sebelumnya',
            icon: DrawableResourceAndroidBitmap('ic_notif_previous'),
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'play_pause', isPlaying ? 'Jeda' : 'Putar',
            icon: DrawableResourceAndroidBitmap(isPlaying ? 'ic_notif_pause' : 'ic_notif_play'),
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'next', 'Berikutnya',
            icon: DrawableResourceAndroidBitmap('ic_notif_next'),
            showsUserInterface: false,
          ),
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
