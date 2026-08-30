import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/theme_provider.dart';
import 'services/player_service.dart';
import 'services/swara_audio_handler.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlayerService.instance.init();

  try {
    await Permission.notification.request();
  } catch (e) {
    debugPrint('Izin notifikasi tidak bisa diminta: $e');
  }

  try {
    await AudioService.init(
      builder: () => SwaraAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.nikodwidharma.offline_music_player.channel.audio',
        androidNotificationChannelName: 'Kontrol Musik Swara',
        androidNotificationIcon: 'drawable/ic_stat_swara',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('AudioService gagal diinisialisasi: $e');
  }

  final themeProvider = ThemeProvider();
  await themeProvider.load();

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
        builder: (context, tp, _) => MaterialApp(
          title: 'Swara',
          debugShowCheckedModeBanner: false,
          themeMode: tp.themeMode,
          theme: ThemeData(
            colorSchemeSeed: tp.accentColor,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: tp.accentColor,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
