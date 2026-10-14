import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/theme_provider.dart';
import 'services/player_service.dart';
import 'services/swara_audio_handler.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await PlayerService.instance.init();
  } catch (e) {
    // Keep the app usable when the player fails to init:
    // the home page shows a retryable error state instead of a black splash.
    debugPrint('PlayerService init failed: $e');
  }

  try {
    await Permission.notification.request();
  } catch (e) {
    debugPrint('Notification permission could not be requested: $e');
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
    debugPrint('AudioService failed to initialize: $e');
  }

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // Load the saved app language before startup (defaults to English).
  final languageProvider = LanguageProvider.instance;
  try {
    await languageProvider.load();
  } catch (e) {
    debugPrint('LanguageProvider failed to load: $e');
  }

  runApp(MusicApp(
      themeProvider: themeProvider, languageProvider: languageProvider));
}

class MusicApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  const MusicApp(
      {super.key,
      required this.themeProvider,
      required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: languageProvider),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, tp, lp, _) => MaterialApp(
          title: 'Swara',
          debugShowCheckedModeBanner: false,
          locale: lp.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
