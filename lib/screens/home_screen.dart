import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'library_screen.dart';
import 'extra_screens.dart';
import 'history_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import '../widgets/mini_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _groupIndex = 0;
  DateTime? _lastBackPress;

  late final TabController _musicTabs = TabController(length: 2, vsync: this);
  late final TabController _collectionTabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _musicTabs.dispose();
    _collectionTabs.dispose();
    super.dispose();
  }

  Future<bool> _onBackPressed() async {
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tekan sekali lagi untuk keluar'), duration: Duration(seconds: 2)),
      );
      return false;
    }
    SystemNavigator.pop();
    return false;
  }

  PreferredSizeWidget? _buildSubTabBar() {
    switch (_groupIndex) {
      case 0:
        return TabBar(
          controller: _musicTabs,
          tabs: const [Tab(text: 'Semua Lagu'), Tab(text: 'Folder')],
        );
      case 1:
        return TabBar(
          controller: _collectionTabs,
          tabs: const [Tab(text: 'Favorit'), Tab(text: 'Playlist'), Tab(text: 'Riwayat')],
        );
      default:
        return null;
    }
  }

  String get _groupTitle {
    switch (_groupIndex) {
      case 0:
        return 'Musik';
      case 1:
        return 'Koleksi';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildBody() {
    switch (_groupIndex) {
      case 0:
        return TabBarView(
          controller: _musicTabs,
          children: const [LibraryScreen(), FoldersScreen()],
        );
      case 1:
        return TabBarView(
          controller: _collectionTabs,
          children: const [FavoritesScreen(), PlaylistsScreen(), HistoryScreen()],
        );
      default:
        return const DashboardScreen();
    }
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
            child: Text(_groupTitle, key: ValueKey(_groupIndex)),
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
          bottom: _buildSubTabBar(),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_groupIndex), child: _buildBody()),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _groupIndex,
              onDestinationSelected: (i) => setState(() => _groupIndex = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.library_music), label: 'Musik'),
                NavigationDestination(icon: Icon(Icons.favorite), label: 'Koleksi'),
                NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Dashboard'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
