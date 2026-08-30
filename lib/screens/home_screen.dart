import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'library_screen.dart';
import 'extra_screens.dart';
import 'history_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import '../providers/library_provider.dart';
import '../widgets/mini_player.dart';
import '../utils/page_transitions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _groupIndex = 0;
  DateTime? _lastBackPress;

  late final TabController _libraryTabs =
      TabController(length: 4, vsync: this);
  late final TabController _collectionTabs =
      TabController(length: 5, vsync: this);

  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _initLibrary());
    _collectionTabs.addListener(_onCollectionTabChanged);
  }

  void _onCollectionTabChanged() {
    if (_collectionTabs.indexIsChanging) return;
    if (_collectionTabs.index == 2) _historyKey.currentState?.reload();
  }

  /// Load DB langsung (instan), lalu scan device di background jika diperlukan.
  /// Musik muncul segera tanpa menunggu scan selesai.
  Future<void> _initLibrary() async {
    final lib = context.read<LibraryProvider>();
    await lib.autoLoadAndScanIfNeeded();
  }

  @override
  void dispose() {
    _collectionTabs.removeListener(_onCollectionTabChanged);
    _libraryTabs.dispose();
    _collectionTabs.dispose();
    super.dispose();
  }

  Future<bool> _onBackPressed() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tekan sekali lagi untuk keluar'),
            duration: Duration(seconds: 2)),
      );
      return false;
    }
    SystemNavigator.pop();
    return false;
  }

  PreferredSizeWidget? _buildTabBar() {
    switch (_groupIndex) {
      case 0:
        return TabBar(
          controller: _libraryTabs,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Lagu'),
            Tab(text: 'Folder'),
            Tab(text: 'Artis'),
            Tab(text: 'Genre'),
          ],
        );
      case 1:
        return TabBar(
          controller: _collectionTabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Playlist'),
            Tab(text: 'Favorit'),
            Tab(text: 'Riwayat'),
            Tab(text: 'Baru'),
            Tab(text: 'Sering'),
          ],
        );
      default:
        return null;
    }
  }

  String get _groupTitle {
    switch (_groupIndex) {
      case 0: return 'Perpustakaan';
      case 1: return 'Koleksi';
      default: return 'Dashboard';
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, anim, __) => const SearchScreen(),
        transitionsBuilder: (context, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, anim, __) => const SettingsScreen(),
        transitionsBuilder: (context, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
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
          title: Text(_groupTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_outlined),
              tooltip: 'Cari',
              onPressed: _openSearch,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Pengaturan',
              onPressed: _openSettings,
            ),
          ],
          bottom: _buildTabBar(),
        ),
        // IndexedStack mempertahankan state semua halaman di memori
        // sehingga tidak ada loading berulang saat berpindah tab.
        body: IndexedStack(
          index: _groupIndex,
          children: [
            TabBarView(
              controller: _libraryTabs,
              children: const [
                LibraryScreen(),
                FoldersScreen(),
                const ArtistsScreen(),
                const GenresScreen(),
              ],
            ),
            TabBarView(
              controller: _collectionTabs,
              children: [
                const PlaylistsScreen(),
                const FavoritesScreen(),
                HistoryScreen(key: _historyKey),
                const RecentlyAddedScreen(),
                const MostPlayedScreen(),
              ],
            ),
            DashboardScreen(key: _dashboardKey),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _groupIndex,
              onDestinationSelected: (i) {
                setState(() => _groupIndex = i);
                if (i == 2) _dashboardKey.currentState?.reload();
                if (i == 1 && _collectionTabs.index == 2) {
                  _historyKey.currentState?.reload();
                }
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music),
                    label: 'Perpustakaan'),
                NavigationDestination(
                    icon: Icon(Icons.folder_special_outlined),
                    selectedIcon: Icon(Icons.folder_special),
                    label: 'Koleksi'),
                NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'Dashboard'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
