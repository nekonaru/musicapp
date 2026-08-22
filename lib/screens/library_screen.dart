import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import '../widgets/az_scrollbar.dart';
import '../widgets/playing_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/song_options.dart';
import '../utils/format.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playSong(List<Song> queue, int index) async {
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
        final currentSong = PlayerService.instance.currentSong;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                '${lib.totalCount} lagu · ${formatDurationLong(lib.totalDurationMs)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => lib.setSearchQuery(v),
                      decoration: InputDecoration(
                        hintText: 'Cari judul, artis, album...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        suffixIcon: lib.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  lib.setSearchQuery('');
                                },
                              )
                            : null,
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
                            : () async {
                                final shuffled = List<Song>.of(displayedSongs)..shuffle();
                                await _playSong(shuffled, 0);
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
                              final isCurrentlyPlaying = currentSong != null && currentSong.id == song.id;
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
                                  tileColor: isCurrentlyPlaying
                                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                      : null,
                                  leading: isCurrentlyPlaying
                                      ? Container(
                                          width: 40, height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: AnimatedBuilder(
                                            animation: PlayerService.instance,
                                            builder: (context, _) => PlayingIndicator(
                                              isPlaying: PlayerService.instance.player.playing,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        )
                                      : CircleAvatar(
                                          backgroundImage: song.albumArtUrl != null ? CachedNetworkImageProvider(song.albumArtUrl!) : null,
                                          child: song.albumArtUrl == null ? const Icon(Icons.music_note) : null,
                                        ),
                                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal)),
                                  subtitle: Text('${song.artist} · ${song.genre ?? "Genre ?"}',
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onTap: () => _playSong(displayedSongs, i),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(formatDuration(song.durationMs), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
