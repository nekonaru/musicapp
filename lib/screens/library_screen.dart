import 'dart:math';
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
  static const double _itemHeight = 72;

  // Multi-select
  bool _multiSelectMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int songId) {
    setState(() {
      if (_selectedIds.contains(songId)) {
        _selectedIds.remove(songId);
        if (_selectedIds.isEmpty) _multiSelectMode = false;
      } else {
        _selectedIds.add(songId);
      }
    });
  }

  Future<void> _playSong(List<Song> queue, int index) async {
    await PlayerService.instance.setQueueAndPlay(queue, index);
    final error = PlayerService.instance.lastError;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5)),
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

  void _showSortMenu(BuildContext context, LibraryProvider lib) {
    final options = SortOption.values;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Urutkan berdasarkan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ...options.map((opt) => ListTile(
                  dense: true,
                  leading: lib.sortOption == opt
                      ? Icon(Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary)
                      : const SizedBox(width: 18),
                  title: Text(sortOptionLabel(opt)),
                  onTap: () {
                    lib.setSortOption(opt);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Bulk action bottom bar
  Widget _buildMultiSelectBar(LibraryProvider lib) {
    final selected = lib.songs.where((s) => _selectedIds.contains(s.id)).toList();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: _multiSelectMode ? null : 0,
      child: _multiSelectMode
          ? Container(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text('${_selectedIds.length} dipilih',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.playlist_add),
                    tooltip: 'Tambahkan ke playlist',
                    onPressed: selected.isEmpty
                        ? null
                        : () => _bulkAddToPlaylist(selected),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    tooltip: 'Tambahkan ke favorit',
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            for (final s in selected) {
                              await lib.toggleFavorite(s, true);
                            }
                            _exitMultiSelect();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${selected.length} lagu ditambahkan ke favorit')),
                              );
                            }
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Batalkan pilihan',
                    onPressed: _exitMultiSelect,
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Future<void> _bulkAddToPlaylist(List<Song> songs) async {
    final playlistProvider =
        Provider.of<PlaylistProvider>(context, listen: false);
    final playlists = playlistProvider.playlists;
    if (!mounted) return;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buat playlist dulu di tab Koleksi')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pilih playlist',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...playlists.map((p) => ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(p['name']),
                  onTap: () async {
                    for (final s in songs) {
                      await playlistProvider.addSong(p['id'], s.id);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      _exitMultiSelect();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '${songs.length} lagu ditambahkan ke ${p['name']}')),
                      );
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, lib, _) {
        if (lib.isScanning && lib.songs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Memindai musik...'),
              ],
            ),
          );
        }

        if (lib.songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_music_outlined,
                    size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Belum ada musik',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Pindai HP untuk menemukan file musik',
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => lib.forceScanDevice(),
                  icon: const Icon(Icons.search),
                  label: const Text('Pindai Musik'),
                ),
              ],
            ),
          );
        }

        final displayedSongs = lib.filteredSongs('');
        final showAzBar = lib.sortOption == SortOption.titleAZ;
        final availableLetters = <String>{
          for (final s in displayedSongs)
            RegExp(r'^[a-zA-Z]').hasMatch(s.title)
                ? s.title[0].toUpperCase()
                : '#'
        };

        return Column(
          children: [
            // Scan progress bar
            if (lib.isScanning)
              const LinearProgressIndicator(),
            if (lib.isBulkScanningMetadata)
              LinearProgressIndicator(
                value: lib.bulkScanTotal == 0
                    ? null
                    : lib.bulkScanProgress / lib.bulkScanTotal,
              ),

            // Multi-select bar
            _buildMultiSelectBar(lib),

            // Sort row + total info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  // Sort button
                  GestureDetector(
                    onTap: () => _showSortMenu(context, lib),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            sortOptionLabel(lib.sortOption),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Total lagu + durasi
                  Text(
                    '${lib.totalCount} lagu \u00B7 ${formatDurationLong(lib.totalDurationMs)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 4),
                  // Scan icon
                  lib.isBulkScanningMetadata
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                          tooltip: 'Scan metadata',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _showScanMenu(context, lib),
                        ),
                ],
              ),
            ),

            // Play buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: displayedSongs.isEmpty
                          ? null
                          : () => _playSong(displayedSongs, 0),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Mulai Putar'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: displayedSongs.isEmpty
                          ? null
                          : () async {
                              final r = Random().nextInt(displayedSongs.length);
                              await _playSong(displayedSongs, r);
                              PlayerService.instance.setShuffle(true);
                            },
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text('Acak'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                ],
              ),
            ),

            // Song list
            Expanded(
              child: displayedSongs.isEmpty
                  ? const Center(child: Text('Lagu tidak ditemukan'))
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: () => lib.forceScanDevice(),
                          child: AnimatedBuilder(
                            animation: PlayerService.instance,
                            builder: (context, _) => ListView.builder(
                              controller: _scrollController,
                              itemCount: displayedSongs.length,
                              itemExtent: _itemHeight,
                              itemBuilder: (context, i) {
                                final song = displayedSongs[i];
                                final isSelected =
                                    _selectedIds.contains(song.id);
                                final current =
                                    PlayerService.instance.currentSong;
                                final isPlaying = current != null &&
                                    current.id == song.id;
                                return _SongTile(
                                  song: song,
                                  index: i,
                                  isPlaying: isPlaying,
                                  isSelected: isSelected,
                                  isMultiSelectMode: _multiSelectMode,
                                  onTap: () {
                                    if (_multiSelectMode) {
                                      _toggleSelect(song.id);
                                    } else {
                                      _playSong(displayedSongs, i);
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() {
                                      _multiSelectMode = true;
                                      _selectedIds.add(song.id);
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        if (showAzBar && !_multiSelectMode)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: AzScrollbar(
                              availableLetters: availableLetters,
                              onLetterSelected: (letter) =>
                                  _jumpToLetter(letter, displayedSongs),
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

  void _showScanMenu(BuildContext context, LibraryProvider lib) {
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
              subtitle: const Text('Proses lagu yang belum pernah discan'),
              onTap: () {
                Navigator.pop(ctx);
                lib.bulkScanMetadata(onlyMissing: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Scan Ulang Semua'),
              subtitle: Text('Paksa scan ulang ${lib.totalCount} lagu'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Scan Ulang Semua'),
                    content: Text(
                        'Ambil ulang metadata untuk semua ${lib.totalCount} lagu? Ini butuh waktu lebih lama.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Batal')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Mulai')),
                    ],
                  ),
                );
                if (confirm == true) lib.bulkScanMetadata(onlyMissing: false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Widget tile lagu yang mendukung multi-select
class _SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final bool isPlaying;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SongTile({
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey('song_${song.id}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 180 + (index % 12) * 20),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: isSelected
              ? cs.primaryContainer.withOpacity(0.5)
              : isPlaying
                  ? cs.primaryContainer.withOpacity(0.25)
                  : null,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 72,
          child: Row(
            children: [
              // Leading: checkbox or avatar
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isMultiSelectMode
                    ? Checkbox(
                        key: const ValueKey('checkbox'),
                        value: isSelected,
                        onChanged: (_) => onTap(),
                      )
                    : Padding(
                        key: const ValueKey('avatar'),
                        padding: const EdgeInsets.only(left: 8),
                        child: isPlaying
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
                              ),
                      ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isPlaying ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                        color: isPlaying ? cs.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} \u00B7 ${song.genre ?? "Genre ?"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Trailing
              Text(
                formatDuration(song.durationMs),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              if (!isMultiSelectMode)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => showSongOptions(context, song),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
