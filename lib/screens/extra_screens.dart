import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/library_scanner.dart';
import '../services/player_service.dart';
import '../services/db_helper.dart';
import 'player_screen.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});
  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<String> _folders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folders = await LibraryScanner().listMusicFolders();
    setState(() => _folders = folders);
  }

  @override
  Widget build(BuildContext context) {
    if (_folders.isEmpty) {
      return const Center(child: Text('Belum ada folder musik terdeteksi.'));
    }
    return ListView.builder(
      itemCount: _folders.length,
      itemBuilder: (context, i) {
        final folder = _folders[i];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(folder.split('/').last),
          subtitle: Text(folder, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () async {
            final songs = await LibraryScanner().getSongsInFolder(folder);
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => _FolderSongsScreen(folderName: folder.split('/').last, songs: songs),
              ));
            }
          },
        );
      },
    );
  }
}

class _FolderSongsScreen extends StatelessWidget {
  final String folderName;
  final List<Song> songs;
  const _FolderSongsScreen({required this.folderName, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(songs[i].title),
          subtitle: Text(songs[i].artist),
          onTap: () async {
            await PlayerService.instance.setQueueAndPlay(songs, i);
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
            }
          },
        ),
      ),
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _favs.length,
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.favorite, color: Colors.red),
          title: Text(_favs[i].title),
          subtitle: Text(_favs[i].artist),
          onTap: () async {
            await PlayerService.instance.setQueueAndPlay(_favs, i);
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
            }
          },
        ),
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
                      onTap: () async {
                        final songs = await provider.songsIn(p['id']);
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => _FolderSongsScreen(folderName: p['name'], songs: songs),
                          ));
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => provider.delete(p['id']),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
