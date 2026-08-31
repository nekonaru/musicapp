import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'library_screen.dart';
import 'extra_screens.dart';
import 'albums_screen.dart';
import 'collections_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import '../providers/library_provider.dart';
import '../widgets/mini_player.dart';

// ─────────────────────────────────────────────────────────────
// Definisi tab Perpustakaan (id, label, visible, order)
// ─────────────────────────────────────────────────────────────

class _TabDef {
  final String id;
  final String label;
  bool visible;
  _TabDef({required this.id, required this.label, this.visible = true});
  _TabDef copy() => _TabDef(id: id, label: label, visible: visible);
}

const _kTabConfigKey = 'library_tab_config_v2';

final _defaultTabDefs = <_TabDef>[
  _TabDef(id: 'songs', label: 'Lagu'),
  _TabDef(id: 'albums', label: 'Album'),
  _TabDef(id: 'artists', label: 'Artis'),
  _TabDef(id: 'folders', label: 'Folder'),
  _TabDef(id: 'genres', label: 'Genre'),
];

// Buat widget berdasarkan id tab
Widget _tabWidget(String id) {
  switch (id) {
    case 'songs': return const LibraryScreen();
    case 'albums': return const AlbumsScreen();
    case 'artists': return const ArtistsScreen();
    case 'folders': return const FoldersScreen();
    case 'genres': return const GenresScreen();
    default: return const LibraryScreen();
  }
}

// ─────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _groupIndex = 0;
  DateTime? _lastBackPress;

  // Tab definitions untuk Perpustakaan
  late List<_TabDef> _allTabDefs;
  late TabController _libTabController;

  final _dashboardKey = GlobalKey<DashboardScreenState>();

  @override
  void initState() {
    super.initState();
    _allTabDefs = _defaultTabDefs.map((t) => t.copy()).toList();
    _libTabController = TabController(
        length: _allTabDefs.where((t) => t.visible).length, vsync: this);
    _loadTabConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLibrary());
  }

  Future<void> _loadTabConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kTabConfigKey);
    if (raw == null || raw.isEmpty) return;

    // Format: "id:visible" per item, urutan menentukan order
    final parsed = raw
        .map((s) {
          final parts = s.split(':');
          if (parts.length != 2) return null;
          final def = _defaultTabDefs
              .firstWhere((d) => d.id == parts[0], orElse: () => _TabDef(id: '', label: ''));
          if (def.id.isEmpty) return null;
          return _TabDef(
              id: def.id, label: def.label, visible: parts[1] == '1');
        })
        .whereType<_TabDef>()
        .toList();

    // Tambahkan tab baru yang belum ada di config
    for (final d in _defaultTabDefs) {
      if (!parsed.any((p) => p.id == d.id)) parsed.add(d.copy());
    }

    if (!mounted) return;
    _rebuildTabController(parsed);
  }

  Future<void> _saveTabConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kTabConfigKey,
      _allTabDefs.map((t) => '${t.id}:${t.visible ? 1 : 0}').toList(),
    );
  }

  void _rebuildTabController(List<_TabDef> newDefs) {
    final enabledCount = newDefs.where((t) => t.visible).length;
    final oldCtrl = _libTabController;
    setState(() {
      _allTabDefs = newDefs;
      _libTabController = TabController(
          length: enabledCount < 1 ? 1 : enabledCount, vsync: this);
    });
    // Dispose setelah frame selesai agar animasi tidak crash
    WidgetsBinding.instance.addPostFrameCallback((_) => oldCtrl.dispose());
  }

  Future<void> _initLibrary() async {
    final lib = context.read<LibraryProvider>();
    await lib.autoLoadAndScanIfNeeded();
  }

  @override
  void dispose() {
    _libTabController.dispose();
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

  String get _groupTitle {
    switch (_groupIndex) {
      case 0: return 'Perpustakaan';
      case 1: return 'Koleksi';
      default: return 'Dashboard';
    }
  }

  // Tab bar Perpustakaan dengan icon pengaturan
  PreferredSizeWidget _buildLibraryTabBar() {
    final enabledTabs = _allTabDefs.where((t) => t.visible).toList();
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _libTabController,
              isScrollable: enabledTabs.length > 3,
              tabAlignment: enabledTabs.length > 3
                  ? TabAlignment.start
                  : TabAlignment.fill,
              tabs: enabledTabs.map((t) => Tab(text: t.label)).toList(),
            ),
          ),
          // Icon pengaturan tab
          IconButton(
            icon: const Icon(Icons.tune, size: 20),
            tooltip: 'Pengaturan tab',
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _showTabSettings,
          ),
        ],
      ),
    );
  }

  void _showTabSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TabSettingsSheet(
        initialDefs: _allTabDefs.map((t) => t.copy()).toList(),
        onApply: (newDefs) {
          _rebuildTabController(newDefs);
          _saveTabConfig();
        },
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 200),
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
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, anim, __) => const SettingsScreen(),
        transitionsBuilder: (context, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabledTabs = _allTabDefs.where((t) => t.visible).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onBackPressed();
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
          bottom: _groupIndex == 0 ? _buildLibraryTabBar() : null,
        ),

        // IndexedStack: semua halaman tetap di memori
        body: IndexedStack(
          index: _groupIndex,
          children: [
            // Perpustakaan - TabBarView
            TabBarView(
              controller: _libTabController,
              children: enabledTabs
                  .map((t) => _tabWidget(t.id))
                  .toList()
                  .let((list) => list.isEmpty
                      ? [const LibraryScreen()]
                      : list),
            ),

            // Koleksi - layar tunggal (kartu + playlist)
            const CollectionsScreen(),

            // Dashboard
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

// ─────────────────────────────────────────────────────────────
// Tab Settings Sheet (drag reorder + toggle visibility)
// ─────────────────────────────────────────────────────────────

class _TabSettingsSheet extends StatefulWidget {
  final List<_TabDef> initialDefs;
  final void Function(List<_TabDef> newDefs) onApply;

  const _TabSettingsSheet({required this.initialDefs, required this.onApply});

  @override
  State<_TabSettingsSheet> createState() => _TabSettingsSheetState();
}

class _TabSettingsSheetState extends State<_TabSettingsSheet> {
  late List<_TabDef> _defs;

  @override
  void initState() {
    super.initState();
    _defs = widget.initialDefs.map((t) => t.copy()).toList();
  }

  void _reset() {
    setState(() {
      _defs = _defaultTabDefs.map((t) => t.copy()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pengaturan tab',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Seret tab untuk mengubah urutan',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Atur Ulang'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Reorderable list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx--;
                  final item = _defs.removeAt(oldIdx);
                  _defs.insert(newIdx, item);
                });
              },
              children: [
                for (int i = 0; i < _defs.length; i++)
                  ListTile(
                    key: ValueKey(_defs[i].id),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: Icon(Icons.drag_handle,
                          color: Colors.grey[500], size: 22),
                    ),
                    title: Text(
                      _defs[i].label,
                      style: TextStyle(
                        color: _defs[i].visible
                            ? cs.onSurface
                            : cs.onSurface.withOpacity(0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: GestureDetector(
                      onTap: () {
                        // Minimal 1 tab harus aktif
                        final enabledCount =
                            _defs.where((t) => t.visible).length;
                        if (_defs[i].visible && enabledCount <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Minimal 1 tab harus aktif')),
                          );
                          return;
                        }
                        setState(() => _defs[i].visible = !_defs[i].visible);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _defs[i].visible ? cs.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _defs[i].visible
                                ? cs.primary
                                : cs.outline.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: _defs[i].visible
                            ? Icon(Icons.check,
                                size: 14, color: cs.onPrimary)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onApply(_defs);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _LetterExtension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
