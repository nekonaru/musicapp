import 'package:flutter/material.dart';
import 'library_screen.dart';
import 'extra_screens.dart';
import 'dashboard_screen.dart';
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
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
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
