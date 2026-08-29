import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'library_screen.dart';
import 'extra_screens.dart';
import 'history_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import '../providers/library_provider.dart';
import '../services/diagnostics.dart';
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

  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDetectNewFiles();
      _showAudioServiceErrorIfAny();
      _showNativeCrashLogIfAny();
    });
    _collectionTabs.addListener(_onCollectionSubTabChanged);
  }

  /// Debug sementara: kalau app kemarin force-close karena crash native (bukan
  /// exception Dart biasa), MainApplication.kt di sisi Android sudah nyimpen
  /// stack trace-nya ke file. Baca ulang di sini dan tampilkan, biar gak perlu
  /// adb/file manager buat lihat isinya.
  Future<void> _showNativeCrashLogIfAny() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final file = File('${dir.path}/swara_crash_log.txt');
      if (!await file.exists()) return;
      final content = await file.readAsString();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Crash terakhir tercatat'),
          content: SingleChildScrollView(
            child: SelectableText(content, style: const TextStyle(fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Disalin ke clipboard')),
                );
              },
              child: const Text('Salin'),
            ),
            TextButton(
              onPressed: () async {
                await file.delete();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Hapus & Tutup'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Diam-diam gagal, ini cuma alat bantu debug, jangan sampai ganggu app utama.
    }
  }

  /// Debug sementara: kalau AudioService gagal diinisialisasi pas app dibuka
  /// (kontrol notifikasi/lockscreen gak akan muncul), tunjukkan error-nya
  /// langsung di sini biar gampang di-screenshot, gak perlu adb/logcat.
  void _showAudioServiceErrorIfAny() {
    final error = Diagnostics.audioServiceError;
    if (error == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AudioService gagal diinisialisasi'),
        content: SingleChildScrollView(
          child: SelectableText(error, style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: error));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Disalin ke clipboard')),
              );
            },
            child: const Text('Salin'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _onCollectionSubTabChanged() {
    if (_collectionTabs.indexIsChanging) return;
    if (_collectionTabs.index == 2) _historyKey.currentState?.reload();
  }

  /// Setiap app dibuka: hanya cek file baru/hilang di HP (cepat, tanpa internet).
  /// Scan metadata dilakukan manual lewat tombol di layar Semua Lagu/Folder.
  Future<void> _autoDetectNewFiles() async {
    final lib = context.read<LibraryProvider>();
    await lib.scanDevice();
  }

  @override
  void dispose() {
    _collectionTabs.removeListener(_onCollectionSubTabChanged);
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
        // IndexedStack (bukan AnimatedSwitcher) supaya ketiga grup halaman
        // TETAP HIDUP di memori saat berpindah tab - tidak dibangun ulang dari nol
        // tiap kali kembali, jadi tidak ada lagi loading berulang di Folder/Favorit/Playlist.
        body: IndexedStack(
          index: _groupIndex,
          children: [
            TabBarView(
              controller: _musicTabs,
              children: const [LibraryScreen(), FoldersScreen()],
            ),
            TabBarView(
              controller: _collectionTabs,
              children: [const FavoritesScreen(), const PlaylistsScreen(), HistoryScreen(key: _historyKey)],
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
                if (i == 1 && _collectionTabs.index == 2) _historyKey.currentState?.reload();
              },
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
