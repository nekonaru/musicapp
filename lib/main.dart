import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/theme_provider.dart';
import 'services/player_service.dart';
import 'services/swara_audio_handler.dart';
import 'services/diagnostics.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlayerService.instance.init();

  // Android 13+ mewajibkan izin notifikasi diminta secara aktif saat runtime -
  // tanpa ini notifikasi kontrol musik dari AudioService tidak akan muncul.
  try {
    await Permission.notification.request();
  } catch (e) {
    debugPrint('Izin notifikasi tidak bisa diminta: $e');
  }

  // Kontrol musik lewat notifikasi + lockscreen (MediaSession asli) dan
  // foreground service, bersifat opsional - kalau gagal init, aplikasi
  // tetap berjalan normal cuma tanpa kontrol dari luar app.
  try {
    await AudioService.init(
      builder: () => SwaraAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.nikodwidharma.offline_music_player.channel.audio',
        androidNotificationChannelName: 'Kontrol Musik Swara',
        androidNotificationIcon: 'drawable/ic_stat_swara',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e, st) {
    debugPrint('AudioService gagal diinisialisasi, kontrol lockscreen/notifikasi tidak tersedia: $e');
    Diagnostics.audioServiceError = '$e\n\n$st';
  }

  final themeProvider = ThemeProvider();
  await themeProvider.load(); // baca tema tersimpan SEBELUM app pertama kali dirender

  runApp(MusicApp(themeProvider: themeProvider));
}

class MusicApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const MusicApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Swara',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            colorSchemeSeed: Colors.deepPurple,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.deepPurple,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
