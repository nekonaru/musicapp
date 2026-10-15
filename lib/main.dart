import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/language_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/theme_provider.dart';
import 'services/equalizer_service.dart';
import 'services/player_service.dart';
import 'services/swara_audio_handler.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap the in-memory image cache because the library can hold 2600 songs
  // with artwork, so unbounded cached art can spike memory on scroll.
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 32 << 20;

  final themeProvider = ThemeProvider();
  final languageProvider = LanguageProvider.instance;

  // Start all independent init tasks in parallel and paint first frame
  // immediately, so the user sees the splash instead of a black screen.
  final bootFuture = _bootApp(
    themeProvider: themeProvider,
    languageProvider: languageProvider,
  );

  runApp(MusicApp(
    themeProvider: themeProvider,
    languageProvider: languageProvider,
    bootFuture: bootFuture,
  ));
}

// Runs independent startup tasks concurrently. Each task guards its own
// failure so one failing init never blocks the others or the app launch.
// PlayerService and AudioService are safe to start together: the audio
// handler only attaches a listener to the existing PlayerService singleton
// and reads its state lazily at runtime.
Future<void> _bootApp({
  required ThemeProvider themeProvider,
  required LanguageProvider languageProvider,
}) {
  return Future.wait([
    () async {
      try {
        await PlayerService.instance.init();
      } catch (e) {
        // Keep the app usable when the player fails to init.
        debugPrint('PlayerService init failed: $e');
      }
    }(),
    () async {
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
    }(),
    () async {
      try {
        await themeProvider.load();
        // Seed the equalizer with the saved preset so the first
        // attach already uses it (no session yet, just stored).
        await EqualizerService.instance
            .applyPreset(themeProvider.equalizerPreset);
      } catch (e) {
        debugPrint('ThemeProvider failed to load: $e');
      }
    }(),
    () async {
      // Load the saved app language before startup (defaults to English).
      try {
        await languageProvider.load();
      } catch (e) {
        debugPrint('LanguageProvider failed to load: $e');
      }
    }(),
  ]);
}

class MusicApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final Future<void> bootFuture;
  const MusicApp(
      {super.key,
      required this.themeProvider,
      required this.languageProvider,
      required this.bootFuture});

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
          home: BootGate(bootFuture: bootFuture),
        ),
      ),
    );
  }
}

// Shows the splash while boot init runs, then hands off to StartupGate.
// Keeps the original StartupGate and HomeScreen flow untouched.
class BootGate extends StatelessWidget {
  final Future<void> bootFuture;
  const BootGate({super.key, required this.bootFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: bootFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        return const StartupGate();
      },
    );
  }
}

// Chooses the first screen based on the persisted onboarding flag.
// Shows onboarding when 'onboarding_done' is not true, else HomeScreen.
// Boot init above runs in parallel behind BootGate and SplashScreen.
// The notification permission is requested here (once, best effort) only
// after onboarding is done, so boot never pops a permission dialog.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  // Stored once so the FutureBuilder below never restarts the future
  // on rebuild (inline futures in build would refetch on every frame).
  late final Future<bool> _doneFuture = _loadAndMaybeRequestNotification();

  Future<bool> _loadAndMaybeRequestNotification() async {
    final bool done;
    try {
      final prefs = await SharedPreferences.getInstance();
      done = prefs.getBool(kOnboardingDoneKey) ?? false;
    } catch (e) {
      // On storage failure, fall back to home so the app stays usable.
      debugPrint('Failed to read onboarding flag: $e');
      return true;
    }
    if (done) {
      try {
        await Permission.notification.request();
      } catch (e) {
        debugPrint('Notification permission could not be requested: $e');
      }
    }
    return done;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _doneFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Minimal splash while the flag loads.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomeScreen();
        }
        return const OnboardingScreen();
      },
    );
  }
}
