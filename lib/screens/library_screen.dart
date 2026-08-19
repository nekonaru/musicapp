import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import '../widgets/az_scrollbar.dart';
import 'edit_metadata_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 72;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadFromDb();
      context.read<PlaylistProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _playSong(List<Song> queue, int index) async {
    await PlayerService.instance.setQueueAndPlay(queue, index);
    final error = PlayerService.instance.lastError;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
      );
    }
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

  void _showSongOptions(Song song) {
    final lib = context.read<LibraryProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Putar Berikutnya'),
              onTap: () {
                PlayerService.instance.playNext(song);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ditambahkan untuk diputar berikutnya')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check),
              title: const Text('Tambah ke Akhir Antrean'),
              onTap: () {
                PlayerService.instance.addToQueueEnd(song);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ditambahkan ke antrean')),
                );
              },
            ),
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
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Ganti Nama Lagu'),
              onTap: () async {
                Navigator.pop(ctx);
                _renameSong(song, lib);
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

  Future<void> _renameSong(Song song, LibraryProvider lib) async {
    final controller = TextEditingController(text: song.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Nama Lagu'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Simpan')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      song.title = newName.trim();
      await lib.updateMetadata(song);
    }
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
        final showAzBar = lib.searchQuery.isEmpty && lib.sortOption == SortOption.titleAZ;
        final availableLetters = <String>{
          for (final s in displayedSongs)
            RegExp(r'^[a-zA-Z]').hasMatch(s.title) ? s.title[0].toUpperCase() : '#'
        };

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
                    const Padding(
                      padding: EdgeInsets.all(8.0),
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
            if (lib.searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: displayedSongs.isEmpty ? null : () => _playSong(displayedSongs, 0),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Mulai Putar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: displayedSongs.isEmpty
                            ? null
                            : () {
                                final shuffled = List<Song>.of(displayedSongs)..shuffle();
                                _playSong(shuffled, 0);
                                PlayerService.instance.toggleShuffle();
                              },
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Acak'),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: displayedSongs.isEmpty
                  ? const Center(child: Text('Lagu tidak ditemukan'))
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: () => lib.scanDevice(),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: displayedSongs.length,
                            itemExtent: _itemHeight,
                            itemBuilder: (context, i) {
                              final song = displayedSongs[i];
                              return TweenAnimationBuilder<double>(
                                key: ValueKey('song_${song.id}'),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 220 + (i % 12) * 25),
                                curve: Curves.easeOut,
                                builder: (context, value, child) => Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - value) * 8),
                                    child: child,
                                  ),
                                ),
                                child: ListTile(
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
                                ),
                              );
                            },
                          ),
                        ),
                        if (showAzBar)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: AzScrollbar(
                              availableLetters: availableLetters,
                              onLetterSelected: (letter) => _jumpToLetter(letter, displayedSongs),
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
