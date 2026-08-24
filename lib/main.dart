import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/theme_provider.dart';
import 'services/player_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Notifikasi kontrol musik bersifat opsional - kalau gagal init,
  // aplikasi tetap berjalan normal tanpa notifikasi kontrol.
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notifikasi kontrol musik tidak tersedia: $e');
  }
  await PlayerService.instance.init();

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
