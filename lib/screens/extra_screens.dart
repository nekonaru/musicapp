import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../widgets/playing_indicator.dart';
import 'playlist_detail_screen.dart';

// ─────────────────────────────────────────────────────────────
// SHARED WIDGET: Song list tile yang konsisten di semua layar
// ─────────────────────────────────────────────────────────────

Widget buildSongTile(
  BuildContext context,
  Song song,
  List<Song> queue,
  int index, {
  Widget? leading,
  bool showOptions = true,
}) {
  final current = PlayerService.instance.currentSong;
  final isPlaying = current != null && current.id == song.id;
  final cs = Theme.of(context).colorScheme;
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    tileColor: isPlaying ? cs.primaryContainer.withOpacity(0.25) : null,
    leading: leading ??
        (isPlaying
            ? Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: PlayingIndicator(
                  isPlaying: PlayerService.instance.player.playing,
                  color: cs.primary,
                ),
              )
            : CircleAvatar(
                backgroundImage: song.albumArtUrl != null
                    ? CachedNetworkImageProvider(song.albumArtUrl!)
                    : null,
                child: song.albumArtUrl == null
                    ? const Icon(Icons.music_note, size: 20)
                    : null,
              )),
    title: Text(
      song.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
        color: isPlaying ? cs.primary : null,
      ),
    ),
    subtitle: Text(
      song.artist,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    ),
    onTap: () => PlayerService.instance.setQueueAndPlay(queue, index),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatDuration(song.durationMs),
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        if (showOptions)
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showSongOptions(context, song),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// SHARED WIDGET: Header info + tombol play/shuffle
// ─────────────────────────────────────────────────────────────

Widget buildCollectionHeader({
  required BuildContext context,
  required int songCount,
  required int totalMs,
  required List<Song> songs,
  Widget? extraAction,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(
          '$songCount lagu \u00B7 ${formatDurationLong(totalMs)}',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: songs.isEmpty
                    ? null
                    : () => PlayerService.instance.setQueueAndPlay(songs, 0),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Mulai Putar'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: songs.isEmpty
                    ? null
                    : () async {
                        final r = Random().nextInt(songs.length);
                        await PlayerService.instance.setQueueAndPlay(songs, r);
                        PlayerService.instance.setShuffle(true);
                      },
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('Acak'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            if (extraAction != null) ...[
              const SizedBox(width: 8),
              extraAction,
            ],
          ],
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// FOLDERS SCREEN
// ─────────────────────────────────────────────────────────────

enum FolderSortOption { nameAZ, nameZA, songCountDesc }

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});
  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

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
    setState(() => _sortOption =
        FolderSortOption.values[idx.clamp(0, FolderSortOption.values.length - 1)]);
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
    if (mounted) {
      setState(() {
        _folders = folders;
        _excluded = excluded;
        _songsByFolder = songsByFolder;
      });
    }
  }

  Future<void> _toggleHideFolder(String folder) async {
    final isHidden = _excluded.contains(folder);
    await DBHelper.instance.setFolderIncluded(folder, isHidden);
    await _load();
    if (mounted) {
      await context.read<LibraryProvider>().loadFromDb();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isHidden
                  ? 'Folder ditampilkan lagi'
                  : 'Folder disembunyikan dari library')),
        );
      }
    }
  }

  List<String> _sortedFolders(List<String> folders) {
    final sorted = List<String>.of(folders);
    switch (_sortOption) {
      case FolderSortOption.nameAZ:
        sorted.sort(
            (a, b) => compareTitles(a.split('/').last, b.split('/').last));
        break;
      case FolderSortOption.nameZA:
        sorted.sort(
            (a, b) => compareTitles(b.split('/').last, a.split('/').last));
        break;
      case FolderSortOption.songCountDesc:
        sorted.sort((a, b) => (_songsByFolder[b]?.length ?? 0)
            .compareTo(_songsByFolder[a]?.length ?? 0));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final visibleFolders = _sortedFolders(
      _showHidden
          ? _folders
          : _folders.where((f) => !_excluded.contains(f)).toList(),
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
              Expanded(
                child: Text(
                  '${visibleFolders.length} folder',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              PopupMenuButton<FolderSortOption>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort, size: 16),
                    const SizedBox(width: 4),
                    Text(_folderSortLabel(_sortOption),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                onSelected: (v) {
                  setState(() => _sortOption = v);
                  _savePrefs();
                },
                itemBuilder: (context) => [
                  _sortItem(FolderSortOption.nameAZ, 'Nama \u2191'),
                  _sortItem(FolderSortOption.nameZA, 'Nama \u2193'),
                  _sortItem(FolderSortOption.songCountDesc, 'Jumlah lagu'),
                ],
              ),
              IconButton(
                icon: Icon(
                    _showHidden ? Icons.visibility_off : Icons.visibility_outlined,
                    size: 18),
                tooltip: _showHidden
                    ? 'Sembunyikan folder tersembunyi'
                    : 'Tampilkan folder tersembunyi',
                onPressed: () => setState(() => _showHidden = !_showHidden),
              ),
            ],
          ),
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
                duration: Duration(milliseconds: 180 + (i % 8) * 25),
                curve: Curves.easeOut,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child:
                      Transform.translate(offset: Offset(0, (1 - v) * 6), child: child),
                ),
                child: ListTile(
                  leading: Icon(Icons.folder_outlined,
                      color: isHidden ? Colors.grey : Theme.of(context).colorScheme.primary),
                  title: Text(folder.split('/').last,
                      style: isHidden ? const TextStyle(color: Colors.grey) : null),
                  subtitle: Text('${songsInFolder.length} lagu \u00B7 ${formatDurationLong(totalMs)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: Icon(
                        isHidden ? Icons.visibility_off : Icons.visibility_outlined,
                        size: 18),
                    onPressed: () => _toggleHideFolder(folder),
                  ),
                  onTap: () async {
                    await Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 280),
                          pageBuilder: (context, anim, _) => _FolderSongsScreen(
                              folderName: folder.split('/').last,
                              songs: songsInFolder),
                          transitionsBuilder: (context, anim, _, child) =>
                              SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(1, 0), end: Offset.zero)
                                .animate(CurvedAnimation(
                                    parent: anim, curve: Curves.easeOutCubic)),
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

  String _folderSortLabel(FolderSortOption opt) {
    switch (opt) {
      case FolderSortOption.nameAZ: return 'Nama \u2191';
      case FolderSortOption.nameZA: return 'Nama \u2193';
      case FolderSortOption.songCountDesc: return 'Jumlah';
    }
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

// ─────────────────────────────────────────────────────────────
// FOLDER SONGS SCREEN
// ─────────────────────────────────────────────────────────────

enum _SongSortOption { titleAZ, titleZA, artistAZ, dateAddedNewest }

class _FolderSongsScreen extends StatefulWidget {
  final String folderName;
  final List<Song> songs;
  const _FolderSongsScreen({required this.folderName, required this.songs});
  @override
  State<_FolderSongsScreen> createState() => _FolderSongsScreenState();
}

class _FolderSongsScreenState extends State<_FolderSongsScreen> {
  late List<Song> _localSongs;
  final _scrollController = ScrollController();
  bool _isScanning = false;
  int _scanProgress = 0;
  _SongSortOption _sortOption = _SongSortOption.titleAZ;
  static const double _itemHeight = 72;
  static const _kFolderSongSort = 'folder_song_sort';

  @override
  void initState() {
    super.initState();
    _localSongs = List.of(widget.songs);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kFolderSongSort) ?? 0;
    if (mounted) {
      setState(() => _sortOption =
          _SongSortOption.values[idx.clamp(0, _SongSortOption.values.length - 1)]);
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFolderSongSort, _sortOption.index);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Song> get _sorted {
    final list = List<Song>.of(_localSongs);
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
          final da = a.addedAt; final db = b.addedAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
        break;
    }
    return list;
  }

  void _jumpToLetter(String letter, List<Song> songs) {
    final index = letter == '#'
        ? songs.indexWhere((s) => !RegExp(r'^[a-zA-Z]').hasMatch(s.title))
        : songs.indexWhere((s) => s.title.toUpperCase().startsWith(letter));
    if (index == -1) return;
    _scrollController.animateTo(index * _itemHeight,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _scanThisFolder({required bool onlyMissing}) async {
    final targets = onlyMissing
        ? _localSongs.where((s) => !s.metadataScanned).toList()
        : List<Song>.of(_localSongs);
    if (targets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua lagu di folder ini sudah pernah discan')),
        );
      }
      return;
    }
    setState(() { _isScanning = true; _scanProgress = 0; });
    const batchSize = 5;
    for (int i = 0; i < targets.length; i += batchSize) {
      final batch = targets.skip(i).take(batchSize);
      await Future.wait(batch.map((s) => MetadataService.instance.enrichSong(s)));
      if (mounted) setState(() => _scanProgress += batch.length);
    }
    if (mounted) {
      final lib = context.read<LibraryProvider>();
      await lib.loadFromDb();
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

  String _sortLabel(_SongSortOption opt) {
    switch (opt) {
      case _SongSortOption.titleAZ: return 'Judul \u2191';
      case _SongSortOption.titleZA: return 'Judul \u2193';
      case _SongSortOption.artistAZ: return 'Artis \u2191';
      case _SongSortOption.dateAddedNewest: return 'Tanggal \u2191';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _localSongs.fold(0, (sum, s) => sum + s.durationMs);
    final displayed = _sorted;
    final showAzBar = _sortOption == _SongSortOption.titleAZ;
    final availableLetters = <String>{
      for (final s in displayed)
        RegExp(r'^[a-zA-Z]').hasMatch(s.title) ? s.title[0].toUpperCase() : '#'
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          PopupMenuButton<_SongSortOption>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 16),
                const SizedBox(width: 4),
                Text(_sortLabel(_sortOption), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
              ],
            ),
            onSelected: (v) { setState(() => _sortOption = v); _savePrefs(); },
            itemBuilder: (context) => [
              _sortMenuItem(_SongSortOption.titleAZ, 'Judul \u2191'),
              _sortMenuItem(_SongSortOption.titleZA, 'Judul \u2193'),
              _sortMenuItem(_SongSortOption.artistAZ, 'Artis \u2191'),
              _sortMenuItem(_SongSortOption.dateAddedNewest, 'Tanggal \u2191'),
            ],
          ),
          _isScanning
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.cloud_sync_outlined),
                  onPressed: _localSongs.isEmpty
                      ? null
                      : () => _pickScanMode(),
                ),
        ],
      ),
      body: Column(
        children: [
          if (_isScanning)
            LinearProgressIndicator(
                value: _localSongs.isEmpty ? 0 : _scanProgress / _localSongs.length),
          Expanded(
            child: displayed.isEmpty
                ? const Center(child: Text('Tidak ada lagu'))
                : Stack(
                    children: [
                      AnimatedBuilder(
                        animation: PlayerService.instance,
                        builder: (context, _) => CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            SliverToBoxAdapter(
                              child: buildCollectionHeader(
                                context: context,
                                songCount: _localSongs.length,
                                totalMs: totalMs,
                                songs: displayed,
                              ),
                            ),
                            SliverFixedExtentList(
                              itemExtent: _itemHeight,
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => buildSongTile(context, displayed[i], displayed, i),
                                childCount: displayed.length,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showAzBar)
                        Positioned(
                          right: 0, top: 0, bottom: 0,
                          child: AzScrollbar(
                            availableLetters: availableLetters,
                            onLetterSelected: (l) => _jumpToLetter(l, displayed),
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

  void _pickScanMode() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Scan yang Belum Ada Metadata'),
              onTap: () { Navigator.pop(ctx); _scanThisFolder(onlyMissing: true); },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Scan Ulang Semua'),
              onTap: () { Navigator.pop(ctx); _scanThisFolder(onlyMissing: false); },
            ),
          ],
        ),
      ),
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

// ─────────────────────────────────────────────────────────────
// ARTISTS SCREEN
// ─────────────────────────────────────────────────────────────

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        if (lib.songs.isEmpty) {
          return const Center(child: Text('Belum ada data artis.'));
        }
        final grouped = lib.groupedByArtist;
        final artists = grouped.keys.toList()..sort();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${artists.length} artis',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: artists.length,
                itemBuilder: (context, i) {
                  final artist = artists[i];
                  final songs = grouped[artist]!;
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('artist_$artist'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 160 + (i % 10) * 20),
                    curve: Curves.easeOut,
                    builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                            offset: Offset(0, (1 - v) * 6), child: child)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          artist.isNotEmpty ? artist[0].toUpperCase() : '?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                      ),
                      title: Text(artist,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${songs.length} lagu',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 280),
                          pageBuilder: (context, anim, _) =>
                              _ArtistSongsScreen(artist: artist, songs: songs),
                          transitionsBuilder: (context, anim, _, child) =>
                              SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(1, 0), end: Offset.zero)
                                .animate(CurvedAnimation(
                                    parent: anim, curve: Curves.easeOutCubic)),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArtistSongsScreen extends StatelessWidget {
  final String artist;
  final List<Song> songs;
  const _ArtistSongsScreen({required this.artist, required this.songs});

  @override
  Widget build(BuildContext context) {
    final totalMs = songs.fold(0, (sum, s) => sum + s.durationMs);
    return Scaffold(
      appBar: AppBar(title: Text(artist)),
      body: AnimatedBuilder(
        animation: PlayerService.instance,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: buildCollectionHeader(
                context: context,
                songCount: songs.length,
                totalMs: totalMs,
                songs: songs,
              ),
            ),
            SliverFixedExtentList(
              itemExtent: 72,
              delegate: SliverChildBuilderDelegate(
                (context, i) => buildSongTile(context, songs[i], songs, i),
                childCount: songs.length,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GENRES SCREEN
// ─────────────────────────────────────────────────────────────

class GenresScreen extends StatelessWidget {
  const GenresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        if (lib.songs.isEmpty) {
          return const Center(child: Text('Belum ada data genre.'));
        }
        final grouped = lib.groupedByGenre;
        final genres = grouped.keys.toList()..sort();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${genres.length} genre',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: genres.length,
                itemBuilder: (context, i) {
                  final genre = genres[i];
                  final songs = grouped[genre]!;
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('genre_$genre'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 160 + (i % 10) * 20),
                    curve: Curves.easeOut,
                    builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                            offset: Offset(0, (1 - v) * 6), child: child)),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.music_note,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                            size: 20),
                      ),
                      title: Text(genre,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${songs.length} lagu',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 280),
                          pageBuilder: (context, anim, _) =>
                              _GenreSongsScreen(genre: genre, songs: songs),
                          transitionsBuilder: (context, anim, _, child) =>
                              SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(1, 0), end: Offset.zero)
                                .animate(CurvedAnimation(
                                    parent: anim, curve: Curves.easeOutCubic)),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GenreSongsScreen extends StatelessWidget {
  final String genre;
  final List<Song> songs;
  const _GenreSongsScreen({required this.genre, required this.songs});

  @override
  Widget build(BuildContext context) {
    final totalMs = songs.fold(0, (sum, s) => sum + s.durationMs);
    return Scaffold(
      appBar: AppBar(title: Text(genre)),
      body: Column(
        children: [
          buildCollectionHeader(
              context: context,
              songCount: songs.length,
              totalMs: totalMs,
              songs: songs),
          Expanded(
            child: AnimatedBuilder(
              animation: PlayerService.instance,
              builder: (context, _) => CustomScrollView(
                slivers: [
                  SliverFixedExtentList(
                    itemExtent: 72,
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => buildSongTile(context, songs[i], songs, i),
                      childCount: songs.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FAVORITES SCREEN
// ─────────────────────────────────────────────────────────────

enum _FavSortOption { titleAZ, titleZA, artistAZ, dateAddedNewest }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  _FavSortOption _sortOption = _FavSortOption.titleAZ;
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
    if (mounted) {
      setState(() => _sortOption =
          _FavSortOption.values[idx.clamp(0, _FavSortOption.values.length - 1)]);
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFavSort, _sortOption.index);
  }

  @override
  void dispose() {
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
          final da = a.addedAt; final db = b.addedAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1; if (db == null) return -1;
          return db.compareTo(da);
        });
        break;
    }
    return list;
  }

  void _jumpToLetter(String letter, List<Song> songs) {
    final index = letter == '#'
        ? songs.indexWhere((s) => !RegExp(r'^[a-zA-Z]').hasMatch(s.title))
        : songs.indexWhere((s) => s.title.toUpperCase().startsWith(letter));
    if (index == -1) return;
    _scrollController.animateTo(index * _itemHeight,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  String _sortLabel(_FavSortOption opt) {
    switch (opt) {
      case _FavSortOption.titleAZ: return 'Judul \u2191';
      case _FavSortOption.titleZA: return 'Judul \u2193';
      case _FavSortOption.artistAZ: return 'Artis \u2191';
      case _FavSortOption.dateAddedNewest: return 'Tanggal \u2191';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        final allFavs = lib.favorites;
        if (allFavs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Belum ada favorit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Tekan ikon hati pada lagu untuk menambahkan',
                    style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }
        final favs = _applySortAndFilter(allFavs);
        final totalMs = allFavs.fold(0, (sum, s) => sum + s.durationMs);
        final showAzBar = _sortOption == _FavSortOption.titleAZ;
        final availableLetters = <String>{
          for (final s in favs)
            RegExp(r'^[a-zA-Z]').hasMatch(s.title) ? s.title[0].toUpperCase() : '#'
        };

        return Column(
          children: [
            // Sort + total row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showSortMenu(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort, size: 14),
                          const SizedBox(width: 4),
                          Text(_sortLabel(_sortOption),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('${allFavs.length} lagu \u00B7 ${formatDurationLong(totalMs)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: favs.isEmpty ? null : () => PlayerService.instance.setQueueAndPlay(favs, 0),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Mulai Putar'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: favs.isEmpty ? null : () async {
                        final r = Random().nextInt(favs.length);
                        await PlayerService.instance.setQueueAndPlay(favs, r);
                        PlayerService.instance.setShuffle(true);
                      },
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text('Acak'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () => lib.loadFromDb(),
                    child: AnimatedBuilder(
                      animation: PlayerService.instance,
                      builder: (context, _) => CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverFixedExtentList(
                            itemExtent: _itemHeight,
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final song = favs[i];
                                final current = PlayerService.instance.currentSong;
                                final isPlaying = current != null && current.id == song.id;
                                return buildSongTile(
                                  context, song, favs, i,
                                  leading: isPlaying
                                      ? Container(
                                          width: 40, height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: PlayingIndicator(
                                            isPlaying: PlayerService.instance.player.playing,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        )
                                      : const Icon(Icons.favorite, color: Colors.red, size: 20),
                                );
                              },
                              childCount: favs.length,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showAzBar)
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      child: AzScrollbar(
                        availableLetters: availableLetters,
                        onLetterSelected: (l) => _jumpToLetter(l, favs),
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

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Urutkan berdasarkan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ..._FavSortOption.values.map((opt) => ListTile(
                  dense: true,
                  leading: _sortOption == opt
                      ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                      : const SizedBox(width: 18),
                  title: Text(_sortLabel(opt)),
                  onTap: () {
                    setState(() => _sortOption = opt);
                    _savePrefs();
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PLAYLISTS SCREEN
// ─────────────────────────────────────────────────────────────

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});
  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<PlaylistProvider>().load());
  }

  Future<void> _createPlaylist() async {
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
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Buat')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      if (mounted) context.read<PlaylistProvider>().create(name);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, PlaylistProvider provider, int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Playlist'),
        content: Text('Hapus playlist "$name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true) provider.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        if (provider.playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue_music_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Belum ada playlist',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _createPlaylist,
                  icon: const Icon(Icons.add),
                  label: const Text('Buat Playlist'),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${provider.playlists.length} playlist',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ),
                  IconButton.filled(
                    onPressed: _createPlaylist,
                    icon: const Icon(Icons.add, size: 18),
                    iconSize: 18,
                    style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: provider.playlists.length,
                itemBuilder: (context, i) {
                  final p = provider.playlists[i];
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('pl_${p['id']}'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 180 + (i % 8) * 25),
                    curve: Curves.easeOut,
                    builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                            offset: Offset(0, (1 - v) * 6), child: child)),
                    child: ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.queue_music,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            size: 20),
                      ),
                      title: Text(p['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 280),
                          pageBuilder: (context, anim, _) => PlaylistDetailScreen(
                              playlistId: p['id'], playlistName: p['name']),
                          transitionsBuilder: (context, anim, _, child) =>
                              SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(1, 0), end: Offset.zero)
                                .animate(CurvedAnimation(
                                    parent: anim, curve: Curves.easeOutCubic)),
                            child: child,
                          ),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () =>
                            _confirmDelete(context, provider, p['id'], p['name']),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RECENTLY ADDED SCREEN
// ─────────────────────────────────────────────────────────────

class RecentlyAddedScreen extends StatefulWidget {
  const RecentlyAddedScreen({super.key});
  @override
  State<RecentlyAddedScreen> createState() => _RecentlyAddedScreenState();
}

class _RecentlyAddedScreenState extends State<RecentlyAddedScreen> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lib = context.read<LibraryProvider>();
    final songs = await lib.getRecentlyAdded(limit: 100);
    if (mounted) setState(() { _songs = songs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_songs.isEmpty) {
      return const Center(child: Text('Belum ada lagu yang ditambahkan.'));
    }
    final totalMs = _songs.fold(0, (sum, s) => sum + s.durationMs);
    return RefreshIndicator(
      onRefresh: _load,
      child: AnimatedBuilder(
        animation: PlayerService.instance,
        builder: (context, _) => CustomScrollView(
          slivers: [
            // Header play buttons - collapse saat scroll
            SliverToBoxAdapter(
              child: buildCollectionHeader(
                  context: context,
                  songCount: _songs.length,
                  totalMs: totalMs,
                  songs: _songs),
            ),
            SliverFixedExtentList(
              itemExtent: 72,
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final song = _songs[i];
                  return buildSongTile(context, song, _songs, i,
                      leading: CircleAvatar(
                        backgroundImage: song.albumArtUrl != null
                            ? CachedNetworkImageProvider(song.albumArtUrl!)
                            : null,
                        child: song.albumArtUrl == null
                            ? const Icon(Icons.music_note, size: 20)
                            : null,
                      ));
                },
                childCount: _songs.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
    return '${(diff.inDays / 30).floor()} bulan lalu';
  }
}

// ─────────────────────────────────────────────────────────────
// MOST PLAYED SCREEN
// ─────────────────────────────────────────────────────────────

class MostPlayedScreen extends StatefulWidget {
  const MostPlayedScreen({super.key});
  @override
  State<MostPlayedScreen> createState() => _MostPlayedScreenState();
}

class _MostPlayedScreenState extends State<MostPlayedScreen> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lib = context.read<LibraryProvider>();
    final songs = await lib.getMostPlayed(limit: 100);
    if (mounted) setState(() { _songs = songs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Belum ada data pemutaran',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Mulai putar lagu untuk melihat statistik',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    final totalMs = _songs.fold(0, (sum, s) => sum + s.durationMs);
    return RefreshIndicator(
      onRefresh: _load,
      child: AnimatedBuilder(
        animation: PlayerService.instance,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: buildCollectionHeader(
                  context: context,
                  songCount: _songs.length,
                  totalMs: totalMs,
                  songs: _songs),
            ),
            SliverFixedExtentList(
              itemExtent: 72,
              delegate: SliverChildBuilderDelegate(
                (context, i) => buildSongTile(
                  context, _songs[i], _songs, i,
                  leading: SizedBox(
                    width: 40, height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          backgroundImage: _songs[i].albumArtUrl != null
                              ? CachedNetworkImageProvider(_songs[i].albumArtUrl!)
                              : null,
                          child: _songs[i].albumArtUrl == null
                              ? const Icon(Icons.music_note, size: 18)
                              : null,
                        ),
                        if (i < 3)
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? Colors.amber
                                    : i == 1
                                        ? Colors.grey[400]
                                        : Colors.brown[300],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                childCount: _songs.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
