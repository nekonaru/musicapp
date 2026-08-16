import 'package:flutter/material.dart';
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

  final _pages = const [
    LibraryScreen(),
    FoldersScreen(),
    FavoritesScreen(),
    PlaylistsScreen(),
    DashboardScreen(),
  ];

  final _titles = const ['Semua Lagu', 'Folder', 'Favorit', 'Playlist', 'Dashboard'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
