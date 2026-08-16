import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import 'edit_metadata_screen.dart';
import 'player_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadFromDb();
      context.read<PlaylistProvider>().load();
    });
  }

  void _playSong(List<Song> queue, int index) async {
    await PlayerService.instance.setQueueAndPlay(queue, index);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
    }
  }

  void _showSongOptions(Song song) {
    final lib = context.read<LibraryProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Tambah/Hapus dari Favorit'),
              onTap: () {
                lib.toggleFavorite(song, true);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Tambah ke Playlist'),
              onTap: () async {
                Navigator.pop(ctx);
                _pickPlaylist(song, playlistProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Metadata'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => EditMetadataScreen(song: song)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Hapus dari Library', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Hapus Lagu'),
                    content: Text('Hapus "${song.title}" dari library? (file asli di HP tidak terhapus)'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
                    ],
                  ),
                );
                if (confirm == true) lib.deleteSong(song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickPlaylist(Song song, PlaylistProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in provider.playlists)
              ListTile(
                title: Text(p['name']),
                onTap: () {
                  provider.addSong(p['id'], song.id);
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Buat Playlist Baru'),
              onTap: () async {
                Navigator.pop(ctx);
                final name = await _promptPlaylistName();
                if (name != null && name.isNotEmpty) {
                  await provider.create(name);
                  final newest = provider.playlists.first;
                  await provider.addSong(newest['id'], song.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptPlaylistName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nama Playlist'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Buat')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        if (lib.isScanning) {
          return const Center(child: CircularProgressIndicator());
        }
        if (lib.songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Belum ada lagu. Pindai musik di HP dulu.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => lib.scanDevice(),
                  icon: const Icon(Icons.search),
                  label: const Text('Pindai Musik'),
                ),
              ],
            ),
          );
        }
        final displayedSongs = lib.filteredSongs;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => lib.setSearchQuery(v),
                      decoration: InputDecoration(
                        hintText: 'Cari judul, artis, album...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<SortOption>(
                    icon: const Icon(Icons.sort),
                    onSelected: (v) => lib.setSortOption(v),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: SortOption.titleAZ, child: Text('Judul A-Z')),
                      PopupMenuItem(value: SortOption.titleZA, child: Text('Judul Z-A')),
                      PopupMenuItem(value: SortOption.artistAZ, child: Text('Artis A-Z')),
                      PopupMenuItem(value: SortOption.dateAddedNewest, child: Text('Baru ditambahkan')),
                      PopupMenuItem(value: SortOption.genre, child: Text('Genre')),
                    ],
                  ),
                  if (lib.isBulkScanningMetadata)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.cloud_sync_outlined),
                      tooltip: 'Scan ulang semua metadata',
                      onPressed: () => _confirmBulkScan(context, lib),
                    ),
                ],
              ),
            ),
            if (lib.isBulkScanningMetadata)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LinearProgressIndicator(
                  value: lib.bulkScanTotal == 0 ? null : lib.bulkScanProgress / lib.bulkScanTotal,
                ),
              ),
            Expanded(
              child: displayedSongs.isEmpty
                  ? const Center(child: Text('Lagu tidak ditemukan'))
                  : RefreshIndicator(
                      onRefresh: () => lib.scanDevice(),
                      child: ListView.builder(
                        itemCount: displayedSongs.length,
                        itemBuilder: (context, i) {
                          final song = displayedSongs[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: song.albumArtUrl != null ? NetworkImage(song.albumArtUrl!) : null,
                              child: song.albumArtUrl == null ? const Icon(Icons.music_note) : null,
                            ),
                            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${song.artist} · ${song.genre ?? "Genre ?"}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _playSong(displayedSongs, i),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => _showSongOptions(song),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _confirmBulkScan(BuildContext context, LibraryProvider lib) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Ulang Semua Metadata'),
        content: Text('Ini akan mengambil ulang judul, artis, album art, genre, dan lirik untuk semua ${lib.songs.length} lagu dari internet. Proses ini butuh koneksi internet dan bisa memakan waktu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              lib.bulkScanMetadata();
            },
            child: const Text('Mulai Scan'),
          ),
        ],
      ),
    );
  }
}
