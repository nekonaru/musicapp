import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import '../utils/format.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final int playlistId;
  final String playlistName;
  const PlaylistDetailScreen({super.key, required this.playlistId, required this.playlistName});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Song> _songs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await context.read<PlaylistProvider>().songsIn(widget.playlistId);
    setState(() => _songs = songs);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final song = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, song);
    });
    await context.read<PlaylistProvider>().reorder(widget.playlistId, _songs.map((s) => s.id).toList());
  }

  Future<void> _removeSong(Song song) async {
    await context.read<PlaylistProvider>().removeSong(widget.playlistId, song.id);
    setState(() => _songs.removeWhere((s) => s.id == song.id));
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _songs.fold(0, (sum, s) => sum + s.durationMs);
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlistName)),
      body: _songs.isEmpty
          ? const Center(child: Text('Playlist ini masih kosong'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_songs.length} lagu · ${formatDurationLong(totalMs)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => PlayerService.instance.setQueueAndPlay(_songs, 0),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Mulai Putar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final shuffled = List<Song>.of(_songs)..shuffle();
                            PlayerService.instance.setQueueAndPlay(shuffled, 0);
                            PlayerService.instance.toggleShuffle();
                          },
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Acak'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('Tahan dan geser untuk mengatur urutan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: _songs.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, i) {
                      final song = _songs[i];
                      return Dismissible(
                        key: ValueKey('pls_${song.id}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeSong(song),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatDuration(song.durationMs), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              const SizedBox(width: 8),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                          onTap: () => PlayerService.instance.setQueueAndPlay(_songs, i),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
