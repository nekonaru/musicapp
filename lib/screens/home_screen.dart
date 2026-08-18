import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'library_screen.dart';
import 'extra_screens.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import '../widgets/mini_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  DateTime? _lastBackPress;

  final _pages = const [
    LibraryScreen(),
    FoldersScreen(),
    FavoritesScreen(),
    PlaylistsScreen(),
    DashboardScreen(),
  ];

  final _titles = const ['Semua Lagu', 'Folder', 'Favorit', 'Playlist', 'Dashboard'];

  Future<bool> _onBackPressed() async {
    final now = DateTime.now();
    // Tombol kembali TIDAK menghentikan musik selama aplikasi masih berjalan di background biasa (belum foreground service).
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tekan sekali lagi untuk keluar'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    // Tekan kedua kali: keluar dari aplikasi (bukan force-close, musik tetap lanjut sebagai background service)
    SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(_titles[_index], key: ValueKey(_index)),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 220),
                  pageBuilder: (context, anim, __) => const SettingsScreen(),
                  transitionsBuilder: (context, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
              ),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.library_music), label: 'Lagu'),
                NavigationDestination(icon: Icon(Icons.folder), label: 'Folder'),
                NavigationDestination(icon: Icon(Icons.favorite), label: 'Favorit'),
                NavigationDestination(icon: Icon(Icons.queue_music), label: 'Playlist'),
                NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Dashboard'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
