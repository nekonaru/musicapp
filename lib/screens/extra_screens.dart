import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'playlist_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    final visibleFolders = _showHidden
        ? _folders
        : _folders.where((f) => !_excluded.contains(f)).toList();

    if (_folders.isEmpty) {
      return const Center(child: Text('Belum ada folder musik terdeteksi.'));
    }
    return Column(
      children: [
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
              return ListTile(
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
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _FolderSongsScreen(folderName: folder.split('/').last, songs: songsInFolder),
                  ));
                  _load(); // refresh durasi/jumlah kalau ada perubahan metadata di dalam folder
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FolderSongsScreen extends StatefulWidget {
  final String folderName;
  final List<Song> songs;
  const _FolderSongsScreen({required this.folderName, required this.songs});

  @override
  State<_FolderSongsScreen> createState() => _FolderSongsScreenState();
}

class _FolderSongsScreenState extends State<_FolderSongsScreen> {
  String _query = '';
  final _searchController = TextEditingController();
  bool _isScanning = false;
  int _scanProgress = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Song> get _filtered {
    if (_query.trim().isEmpty) return widget.songs;
    final q = _query.toLowerCase();
    return widget.songs.where((s) =>
        s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();
  }

  Future<void> _scanThisFolder() async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0;
    });
    const batchSize = 5;
    for (int i = 0; i < widget.songs.length; i += batchSize) {
      final batch = widget.songs.skip(i).take(batchSize);
      await Future.wait(batch.map((s) => MetadataService.instance.enrichSong(s)));
      setState(() => _scanProgress += batch.length);
    }
    if (mounted) {
      await context.read<LibraryProvider>().loadFromDb();
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selesai scan metadata folder ini')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.songs.fold(0, (sum, s) => sum + s.durationMs);
    final displayed = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync_outlined),
              tooltip: 'Scan ulang metadata folder ini',
              onPressed: widget.songs.isEmpty ? null : _scanThisFolder,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isScanning)
            LinearProgressIndicator(value: _scanProgress / widget.songs.length),
          if (widget.songs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.songs.length} lagu · ${formatDurationLong(totalMs)}',
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
                      onPressed: () => PlayerService.instance.setQueueAndPlay(widget.songs, 0),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mulai Putar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final shuffled = List<Song>.of(widget.songs)..shuffle();
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
                : ListView.builder(
                    itemCount: displayed.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(displayed[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(displayed[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => PlayerService.instance.setQueueAndPlay(displayed, i),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatDuration(displayed[i].durationMs), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => showSongOptions(context, displayed[i]),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        final favs = lib.favorites;
        if (favs.isEmpty) return const Center(child: Text('Belum ada lagu favorit.'));
        final totalMs = favs.fold(0, (sum, s) => sum + s.durationMs);
        return RefreshIndicator(
          onRefresh: () => lib.loadFromDb(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${favs.length} lagu · ${formatDurationLong(totalMs)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                child: ListView.builder(
                  itemCount: favs.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text(favs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(favs[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => PlayerService.instance.setQueueAndPlay(favs, i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatDuration(favs[i].durationMs), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          // showFullDelete: false -> "hapus" di sini cuma unfavorite,
                          // tidak menghapus lagu dari Semua Lagu/Folder/Playlist lain.
                          onPressed: () => showSongOptions(context, favs[i], showFullDelete: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
                  content: TextField(controller: controller, autofocus: true),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Buat')),
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
                    return ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(p['name']),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlistId: p['id'], playlistName: p['name']),
                        ));
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, provider, p['id'], p['name']),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
