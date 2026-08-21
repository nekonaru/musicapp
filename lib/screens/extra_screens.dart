import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/library_scanner.dart';
import '../services/player_service.dart';
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
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _FolderSongsScreen(folderName: folder.split('/').last, songs: songsInFolder),
                  ));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FolderSongsScreen extends StatelessWidget {
  final String folderName;
  final List<Song> songs;
  const _FolderSongsScreen({required this.folderName, required this.songs});

  @override
  Widget build(BuildContext context) {
    final totalMs = songs.fold(0, (sum, s) => sum + s.durationMs);
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: Column(
        children: [
          if (songs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${songs.length} lagu · ${formatDurationLong(totalMs)}',
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
                      onPressed: () => PlayerService.instance.setQueueAndPlay(songs, 0),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mulai Putar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final shuffled = List<Song>.of(songs)..shuffle();
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
            child: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(songs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(songs[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => PlayerService.instance.setQueueAndPlay(songs, i),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatDuration(songs[i].durationMs), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => showSongOptions(context, songs[i]),
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

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Song> _favs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await DBHelper.instance.getFavorites();
    setState(() => _favs = favs);
  }

  @override
  Widget build(BuildContext context) {
    if (_favs.isEmpty) return const Center(child: Text('Belum ada lagu favorit.'));
    final totalMs = _favs.fold(0, (sum, s) => sum + s.durationMs);
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_favs.length} lagu · ${formatDurationLong(totalMs)}',
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
                    onPressed: () => PlayerService.instance.setQueueAndPlay(_favs, 0),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Mulai Putar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final shuffled = List<Song>.of(_favs)..shuffle();
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
              itemCount: _favs.length,
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.favorite, color: Colors.red),
                title: Text(_favs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_favs[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => PlayerService.instance.setQueueAndPlay(_favs, i),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatDuration(_favs[i].durationMs), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => showSongOptions(context, _favs[i]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
