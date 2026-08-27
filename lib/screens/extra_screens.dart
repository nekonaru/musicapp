import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/library_scanner.dart';
import '../services/player_service.dart';
import '../services/metadata_service.dart';
import '../services/db_helper.dart';
import '../utils/song_options.dart';
import '../utils/format.dart';
import '../widgets/mini_player.dart';
import '../widgets/az_scrollbar.dart';
import 'playlist_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────
// FOLDERS SCREEN
// ─────────────────────────────────────────────────────────────────

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});
  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

enum FolderSortOption { nameAZ, nameZA, songCountDesc }

class _FoldersScreenState extends State<FoldersScreen> {
  List<String> _folders = [];
  Set<String> _excluded = {};
  bool _showHidden = false;
  Map<String, List<Song>> _songsByFolder = {};
  FolderSortOption _sortOption = FolderSortOption.nameAZ;

  static const _kFolderSort = 'folder_list_sort';

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _load());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kFolderSort) ?? 0;
    setState(() => _sortOption = FolderSortOption.values[idx.clamp(0, FolderSortOption.values.length - 1)]);
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFolderSort, _sortOption.index);
  }

  Future<void> _load() async {
    final folders = await LibraryScanner().listMusicFolders();
    final excluded = await DBHelper.instance.getExcludedFolders();
    final songsByFolder = <String, List<Song>>{};
    for (final f in folders) {
      songsByFolder[f] = await LibraryScanner().getSongsInFolder(f);
    }
    setState(() {
      _folders = folders;
      _excluded = excluded;
      _songsByFolder = songsByFolder;
    });
  }

  Future<void> _toggleHideFolder(String folder) async {
    final isHidden = _excluded.contains(folder);
    await DBHelper.instance.setFolderIncluded(folder, isHidden);
    await _load();
    if (mounted) {
      await context.read<LibraryProvider>().loadFromDb();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isHidden ? 'Folder ditampilkan lagi' : 'Folder disembunyikan dari library')),
      );
    }
  }

  List<String> _sortedFolders(List<String> folders) {
    final sorted = List<String>.of(folders);
    switch (_sortOption) {
      case FolderSortOption.nameAZ:
        sorted.sort((a, b) => compareTitles(a.split('/').last, b.split('/').last));
        break;
      case FolderSortOption.nameZA:
        sorted.sort((a, b) => compareTitles(b.split('/').last, a.split('/').last));
        break;
      case FolderSortOption.songCountDesc:
        sorted.sort((a, b) => (_songsByFolder[b]?.length ?? 0).compareTo(_songsByFolder[a]?.length ?? 0));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final visibleFolders = _sortedFolders(
      _showHidden ? _folders : _folders.where((f) => !_excluded.contains(f)).toList(),
    );

    if (_folders.isEmpty) {
      return const Center(child: Text('Belum ada folder musik terdeteksi.'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              const Expanded(child: Text('Urutkan folder', style: TextStyle(fontSize: 12, color: Colors.grey))),
              PopupMenuButton<FolderSortOption>(
                icon: const Icon(Icons.sort),
                onSelected: (v) {
                  setState(() => _sortOption = v);
                  _savePrefs();
                },
                itemBuilder: (context) => [
                  _sortItem(FolderSortOption.nameAZ, 'Nama A-Z'),
                  _sortItem(FolderSortOption.nameZA, 'Nama Z-A'),
                  _sortItem(FolderSortOption.songCountDesc, 'Jumlah lagu terbanyak'),
                ],
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Tampilkan folder tersembunyi'),
          value: _showHidden,
          onChanged: (v) => setState(() => _showHidden = v),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: visibleFolders.length,
            itemBuilder: (context, i) {
              final folder = visibleFolders[i];
              final isHidden = _excluded.contains(folder);
              final songsInFolder = _songsByFolder[folder] ?? [];
              final totalMs = songsInFolder.fold(0, (sum, s) => sum + s.durationMs);
              return TweenAnimationBuilder<double>(
                key: ValueKey('folder_$folder'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 200 + (i % 8) * 30),
                curve: Curves.easeOut,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(0, (1 - v) * 6), child: child),
                ),
                child: ListTile(
                  leading: Icon(Icons.folder, color: isHidden ? Colors.grey : null),
                  title: Text(folder.split('/').last,
                      style: isHidden ? const TextStyle(color: Colors.grey) : null),
                  subtitle: Text(
                    '${songsInFolder.length} lagu · ${formatDurationLong(totalMs)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility_outlined),
                    tooltip: isHidden ? 'Tampilkan folder ini' : 'Sembunyikan folder ini',
                    onPressed: () => _toggleHideFolder(folder),
                  ),
                  onTap: () async {
                    await Navigator.push(context, PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 280),
                      pageBuilder: (context, anim, _) =>
                          _FolderSongsScreen(folderName: folder.split('/').last, songs: songsInFolder),
                      transitionsBuilder: (context, anim, _, child) => SlideTransition(
                        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    ));
                    _load();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  PopupMenuItem<FolderSortOption> _sortItem(FolderSortOption value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortOption == value) ...[
            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 24),
          Text(label),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// FOLDER SONGS SCREEN
// ─────────────────────────────────────────────────────────────────

enum _SongSortOption { titleAZ, titleZA, artistAZ, dateAddedNewest }

class _FolderSongsScreen extends StatefulWidget {
  final String folderName;
  final List<Song> songs;
  const _FolderSongsScreen({required this.folderName, required this.songs});

  @override
  State<_FolderSongsScreen> createState() => _FolderSongsScreenState();
}

class _FolderSongsScreenState extends State<_FolderSongsScreen> {
  // _localSongs: salinan lokal yang bisa di-update setelah scan metadata,
  // berbeda dengan widget.songs yang immutable dari constructor.
  late List<Song> _localSongs;
  String _query = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isScanning = false;
  int _scanProgress = 0;
  _SongSortOption _sortOption = _SongSortOption.titleAZ;
  static const double _itemHeight = 72;

  static const _kFolderSongSort = 'folder_song_sort';

  @override
  void initState() {
    super.initState();
    _localSongs = List.of(widget.songs); // salinan lokal yang bisa di-refresh
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kFolderSongSort) ?? 0;
    setState(() => _sortOption = _SongSortOption.values[idx.clamp(0, _SongSortOption.values.length - 1)]);
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFolderSongSort, _sortOption.index);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Song> get _sorted {
    final list = List<Song>.of(_localSongs); // pakai _localSongs, bukan widget.songs
    switch (_sortOption) {
      case _SongSortOption.titleAZ:
        list.sort((a, b) => compareTitles(a.title, b.title));
        break;
      case _SongSortOption.titleZA:
        list.sort((a, b) => compareTitles(b.title, a.title));
        break;
      case _SongSortOption.artistAZ:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case _SongSortOption.dateAddedNewest:
        list.sort((a, b) {
          final da = a.addedAt;
          final db = b.addedAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
        break;
    }
    return list;
  }

  List<Song> get _filtered {
    final base = _sorted;
    if (_query.trim().isEmpty) return base;
    final q = _query.toLowerCase();
    return base.where((s) =>
        s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();
  }

  void _jumpToLetter(String letter, List<Song> songs) {
    int index;
    if (letter == '#') {
      index = songs.indexWhere((s) => !RegExp(r'^[a-zA-Z]').hasMatch(s.title));
    } else {
      index = songs.indexWhere((s) => s.title.toUpperCase().startsWith(letter));
    }
    if (index == -1) return;
    _scrollController.animateTo(
      index * _itemHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _scanThisFolder({required bool onlyMissing}) async {
    final targets = onlyMissing ? _localSongs.where((s) => !s.metadataScanned).toList() : List<Song>.of(_localSongs);
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua lagu di folder ini sudah pernah discan')),
      );
      return;
    }
    setState(() {
      _isScanning = true;
      _scanProgress = 0;
    });
    const batchSize = 5;
    for (int i = 0; i < targets.length; i += batchSize) {
      final batch = targets.skip(i).take(batchSize);
      await Future.wait(batch.map((s) => MetadataService.instance.enrichSong(s)));
      setState(() => _scanProgress += batch.length);
    }
    if (mounted) {
      final lib = context.read<LibraryProvider>();
      await lib.loadFromDb();
      // Refresh _localSongs dari data terbaru di provider supaya UI langsung update
      // tanpa harus keluar-masuk folder lagi.
      final updatedIds = _localSongs.map((s) => s.id).toSet();
      setState(() {
        _isScanning = false;
        _localSongs = lib.songs.where((s) => updatedIds.contains(s.id)).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selesai scan metadata folder ini')),
      );
    }
  }

  void _pickScanMode() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Scan yang Belum Ada Metadata'),
              subtitle: const Text('Cuma proses lagu baru di folder ini'),
              onTap: () {
                Navigator.pop(ctx);
                _scanThisFolder(onlyMissing: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Scan Ulang Semua'),
              subtitle: const Text('Paksa ambil ulang semua lagu di folder ini'),
              onTap: () {
                Navigator.pop(ctx);
                _scanThisFolder(onlyMissing: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _localSongs.fold(0, (sum, s) => sum + s.durationMs);
    final displayed = _filtered;
    final showAzBar = _query.isEmpty && _sortOption == _SongSortOption.titleAZ;
    final availableLetters = <String>{
      for (final s in displayed)
        RegExp(r'^[a-zA-Z]').hasMatch(s.title) ? s.title[0].toUpperCase() : '#'
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          PopupMenuButton<_SongSortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (v) {
              setState(() => _sortOption = v);
              _savePrefs();
            },
            itemBuilder: (context) => [
              _sortMenuItem(_SongSortOption.titleAZ, 'Judul A-Z'),
              _sortMenuItem(_SongSortOption.titleZA, 'Judul Z-A'),
              _sortMenuItem(_SongSortOption.artistAZ, 'Artis A-Z'),
              _sortMenuItem(_SongSortOption.dateAddedNewest, 'Baru ditambahkan'),
            ],
          ),
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync_outlined),
              tooltip: 'Scan metadata folder ini',
              onPressed: _localSongs.isEmpty ? null : _pickScanMode,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isScanning)
            LinearProgressIndicator(value: _localSongs.isEmpty ? 0 : _scanProgress / _localSongs.length),
          if (_localSongs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_localSongs.length} lagu · ${formatDurationLong(totalMs)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Cari di folder ini...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => PlayerService.instance.setQueueAndPlay(displayed, 0),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mulai Putar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final shuffled = List<Song>.of(displayed)..shuffle();
                        await PlayerService.instance.setQueueAndPlay(shuffled, 0);
                        PlayerService.instance.setShuffle(true);
                      },
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Acak'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: displayed.isEmpty
                ? const Center(child: Text('Lagu tidak ditemukan'))
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        itemCount: displayed.length,
                        itemExtent: _itemHeight,
                        itemBuilder: (context, i) {
                          final song = displayed[i];
                          return TweenAnimationBuilder<double>(
                            key: ValueKey('fsong_${song.id}'),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 180 + (i % 10) * 20),
                            curve: Curves.easeOut,
                            builder: (context, v, child) => Opacity(
                              opacity: v,
                              child: Transform.translate(offset: Offset(0, (1 - v) * 6), child: child),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.music_note),
                              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => PlayerService.instance.setQueueAndPlay(displayed, i),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(formatDuration(song.durationMs),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () => showSongOptions(context, song),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (showAzBar)
                        Positioned(
                          right: 0, top: 0, bottom: 0,
                          child: AzScrollbar(
                            availableLetters: availableLetters,
                            onLetterSelected: (letter) => _jumpToLetter(letter, displayed),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  PopupMenuItem<_SongSortOption> _sortMenuItem(_SongSortOption value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortOption == value) ...[
            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 24),
          Text(label),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// FAVORITES SCREEN
// ─────────────────────────────────────────────────────────────────

enum _FavSortOption { titleAZ, titleZA, artistAZ, dateAddedNewest }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  _FavSortOption _sortOption = _FavSortOption.titleAZ;
  String _query = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  static const double _itemHeight = 72;

  static const _kFavSort = 'fav_sort_option';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kFavSort) ?? 0;
    setState(() => _sortOption = _FavSortOption.values[idx.clamp(0, _FavSortOption.values.length - 1)]);
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFavSort, _sortOption.index);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Song> _applySortAndFilter(List<Song> favs) {
    final list = List<Song>.of(favs);
    switch (_sortOption) {
      case _FavSortOption.titleAZ:
        list.sort((a, b) => compareTitles(a.title, b.title));
        break;
      case _FavSortOption.titleZA:
        list.sort((a, b) => compareTitles(b.title, a.title));
        break;
      case _FavSortOption.artistAZ:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case _FavSortOption.dateAddedNewest:
        list.sort((a, b) {
          final da = a.addedAt;
          final db = b.addedAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
        break;
    }
    if (_query.trim().isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((s) =>
        s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();
  }

  void _jumpToLetter(String letter, List<Song> songs) {
    int index;
    if (letter == '#') {
      index = songs.indexWhere((s) => !RegExp(r'^[a-zA-Z]').hasMatch(s.title));
    } else {
      index = songs.indexWhere((s) => s.title.toUpperCase().startsWith(letter));
    }
    if (index == -1) return;
    _scrollController.animateTo(
      index * _itemHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        final favs = _applySortAndFilter(lib.favorites);
        final allFavs = lib.favorites;
        if (allFavs.isEmpty) {
          return const Center(child: Text('Belum ada lagu favorit.'));
        }
        final totalMs = allFavs.fold(0, (sum, s) => sum + s.durationMs);
        final showAzBar = _query.isEmpty && _sortOption == _FavSortOption.titleAZ;
        final availableLetters = <String>{
          for (final s in favs)
            RegExp(r'^[a-zA-Z]').hasMatch(s.title) ? s.title[0].toUpperCase() : '#'
        };

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${allFavs.length} lagu · ${formatDurationLong(totalMs)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                  PopupMenuButton<_FavSortOption>(
                    icon: const Icon(Icons.sort),
                    onSelected: (v) {
                      setState(() => _sortOption = v);
                      _savePrefs();
                    },
                    itemBuilder: (context) => [
                      _sortMenuItem(_FavSortOption.titleAZ, 'Judul A-Z'),
                      _sortMenuItem(_FavSortOption.titleZA, 'Judul Z-A'),
                      _sortMenuItem(_FavSortOption.artistAZ, 'Artis A-Z'),
                      _sortMenuItem(_FavSortOption.dateAddedNewest, 'Baru ditambahkan'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Cari favorit...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => PlayerService.instance.setQueueAndPlay(favs, 0),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mulai Putar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final shuffled = List<Song>.of(favs)..shuffle();
                        await PlayerService.instance.setQueueAndPlay(shuffled, 0);
                        PlayerService.instance.setShuffle(true);
                      },
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Acak'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: favs.isEmpty
                  ? const Center(child: Text('Lagu tidak ditemukan'))
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: () => lib.loadFromDb(),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: favs.length,
                            itemExtent: _itemHeight,
                            itemBuilder: (context, i) {
                              final song = favs[i];
                              return TweenAnimationBuilder<double>(
                                key: ValueKey('fav_${song.id}'),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 180 + (i % 10) * 20),
                                curve: Curves.easeOut,
                                builder: (context, v, child) => Opacity(
                                  opacity: v,
                                  child: Transform.translate(offset: Offset(0, (1 - v) * 6), child: child),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.favorite, color: Colors.red),
                                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onTap: () => PlayerService.instance.setQueueAndPlay(favs, i),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(formatDuration(song.durationMs),
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                      IconButton(
                                        icon: const Icon(Icons.more_vert),
                                        onPressed: () => showSongOptions(context, song, showFullDelete: false),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (showAzBar)
                          Positioned(
                            right: 0, top: 0, bottom: 0,
                            child: AzScrollbar(
                              availableLetters: availableLetters,
                              onLetterSelected: (letter) => _jumpToLetter(letter, favs),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<_FavSortOption> _sortMenuItem(_FavSortOption value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortOption == value) ...[
            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 24),
          Text(label),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PLAYLISTS SCREEN
// ─────────────────────────────────────────────────────────────────

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PlaylistProvider>().load());
  }

  Future<void> _confirmDelete(BuildContext context, PlaylistProvider provider, int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Playlist'),
        content: Text('Hapus playlist "$name"? Lagu-lagu di dalamnya tidak akan terhapus dari library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true) provider.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final controller = TextEditingController();
              final name = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Playlist Baru'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Nama playlist'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Buat')),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) provider.create(name);
            },
            child: const Icon(Icons.add),
          ),
          body: provider.playlists.isEmpty
              ? const Center(child: Text('Belum ada playlist.'))
              : ListView.builder(
                  itemCount: provider.playlists.length,
                  itemBuilder: (context, i) {
                    final p = provider.playlists[i];
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('pl_${p['id']}'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 200 + (i % 8) * 25),
                      curve: Curves.easeOut,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(offset: Offset(0, (1 - v) * 6), child: child),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.queue_music),
                        title: Text(p['name']),
                        onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 280),
                            pageBuilder: (context, anim, _) =>
                                PlaylistDetailScreen(playlistId: p['id'], playlistName: p['name']),
                            transitionsBuilder: (context, anim, _, child) => SlideTransition(
                              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(context, provider, p['id'], p['name']),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
