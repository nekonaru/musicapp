import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import '../widgets/az_scrollbar.dart';
import '../widgets/playing_indicator.dart';
import '../utils/song_options.dart';
import '../utils/format.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 72.0;

  bool _multiSelectMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<PlaylistProvider>().load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _exitMultiSelect() => setState(() {
        _multiSelectMode = false;
        _selectedIds.clear();
      });

  void _toggleSelect(int id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
          if (_selectedIds.isEmpty) _multiSelectMode = false;
        } else {
          _selectedIds.add(id);
        }
      });

  void _jumpToLetter(String letter, List<Song> songs) {
    final index = letter == '#'
        ? songs.indexWhere((s) => !RegExp(r'^[a-zA-Z]').hasMatch(s.title))
        : songs.indexWhere((s) => s.title.toUpperCase().startsWith(letter));
    if (index == -1) return;
    _scrollController.animateTo(
      index * _itemHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _playSong(List<Song> queue, int index) async {
    await PlayerService.instance.setQueueAndPlay(queue, index);
    final err = PlayerService.instance.lastError;
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  void _showSortMenu(BuildContext context, LibraryProvider lib) {
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
            ...SortOption.values.map((opt) => ListTile(
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

  Future<void> _bulkAddToPlaylist(List<Song> songs) async {
    final provider = context.read<PlaylistProvider>();
    final playlists = provider.playlists;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buat playlist dulu di tab Koleksi')));
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
                    style: TextStyle(fontWeight: FontWeight.bold))),
            ...playlists.map((p) => ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(p['name']),
                  onTap: () async {
                    for (final s in songs) {
                      await provider.addSong(p['id'], s.id);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _exitMultiSelect();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              '${songs.length} lagu ditambahkan ke ${p['name']}')));
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectBar(LibraryProvider lib) {
    if (!_multiSelectMode) return const SizedBox.shrink();
    final selected =
        lib.songs.where((s) => _selectedIds.contains(s.id)).toList();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text('${_selectedIds.length} dipilih',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Tambah ke playlist',
              onPressed:
                  selected.isEmpty ? null : () => _bulkAddToPlaylist(selected)),
          IconButton(
              icon: const Icon(Icons.favorite_border),
              tooltip: 'Tambah ke favorit',
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      for (final s in selected) {
                        await lib.toggleFavorite(s, true);
                      }
                      _exitMultiSelect();
                    }),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitMultiSelect),
        ],
      ),
    );
  }

  Widget _buildSortHeader(LibraryProvider lib, List<Song> songs) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sort chip + total info
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showSortMenu(context, lib),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
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
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${lib.totalCount} lagu \u00B7 ${formatDurationLong(lib.totalDurationMs)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              lib.isBulkScanningMetadata
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon:
                          const Icon(Icons.cloud_sync_outlined, size: 18),
                      tooltip: 'Scan metadata',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      onPressed: () => _showScanMenu(context, lib),
                    ),
            ],
          ),
        ),
        // Play buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: songs.isEmpty
                      ? null
                      : () => _playSong(songs, 0),
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
                          await _playSong(songs, r);
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(builder: (context, lib, _) {
      if (lib.isScanning && lib.songs.isEmpty) {
        return const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memindai musik...'),
        ]));
      }
      if (lib.songs.isEmpty) {
        return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.library_music_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Belum ada musik',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: () => lib.forceScanDevice(),
              icon: const Icon(Icons.search),
              label: const Text('Pindai Musik')),
        ]));
      }

      final songs = lib.filteredSongs('');
      final showAz = lib.sortOption == SortOption.titleAZ;
      final available = <String>{
        for (final s in songs)
          RegExp(r'^[a-zA-Z]').hasMatch(s.title)
              ? s.title[0].toUpperCase()
              : '#'
      };

      return Column(
        children: [
          if (lib.isScanning) const LinearProgressIndicator(),
          if (lib.isBulkScanningMetadata)
            LinearProgressIndicator(
                value: lib.bulkScanTotal == 0
                    ? null
                    : lib.bulkScanProgress / lib.bulkScanTotal),
          _buildMultiSelectBar(lib),
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => lib.forceScanDevice(),
                  child: AnimatedBuilder(
                    animation: PlayerService.instance,
                    builder: (context, _) => CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Header: sort + play buttons (hilang saat scroll)
                        SliverToBoxAdapter(
                            child: _buildSortHeader(lib, songs)),

                        // Daftar lagu
                        SliverFixedExtentList(
                          itemExtent: _itemHeight,
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final song = songs[i];
                              final isSelected =
                                  _selectedIds.contains(song.id);
                              final isPlaying =
                                  PlayerService.instance.currentSong?.id ==
                                      song.id;
                              return _SongTile(
                                song: song,
                                index: i,
                                isPlaying: isPlaying,
                                isSelected: isSelected,
                                isMultiSelect: _multiSelectMode,
                                onTap: () => _multiSelectMode
                                    ? _toggleSelect(song.id)
                                    : _playSong(songs, i),
                                onLongPress: () => setState(() {
                                  _multiSelectMode = true;
                                  _selectedIds.add(song.id);
                                }),
                              );
                            },
                            childCount: songs.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showAz && !_multiSelectMode)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: AzScrollbar(
                      availableLetters: available,
                      onLetterSelected: (l) => _jumpToLetter(l, songs),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  void _showScanMenu(BuildContext context, LibraryProvider lib) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Scan yang Belum Ada Metadata'),
            onTap: () {
              Navigator.pop(ctx);
              lib.bulkScanMetadata(onlyMissing: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Scan Ulang Semua'),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                        title: const Text('Scan Ulang Semua'),
                        content: Text(
                            'Ambil ulang metadata untuk ${lib.totalCount} lagu?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Batal')),
                          FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Mulai')),
                        ],
                      ));
              if (ok == true) lib.bulkScanMetadata(onlyMissing: false);
            },
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Song Tile
// ─────────────────────────────────────────────────────────────

class _SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final bool isPlaying, isSelected, isMultiSelect;
  final VoidCallback onTap, onLongPress;

  const _SongTile({
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.isSelected,
    required this.isMultiSelect,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isMultiSelect
                  ? Checkbox(
                      key: const ValueKey('cb'),
                      value: isSelected,
                      onChanged: (_) => onTap())
                  : Padding(
                      key: const ValueKey('av'),
                      padding: const EdgeInsets.only(left: 8),
                      child: isPlaying
                          ? Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.15),
                                  shape: BoxShape.circle),
                              child: PlayingIndicator(
                                  isPlaying: PlayerService
                                      .instance.player.playing,
                                  color: cs.primary))
                          : CircleAvatar(
                              backgroundImage: song.albumArtUrl != null
                                  ? CachedNetworkImageProvider(
                                      song.albumArtUrl!)
                                  : null,
                              child: song.albumArtUrl == null
                                  ? const Icon(Icons.music_note, size: 20)
                                  : null),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: isPlaying
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isPlaying ? cs.primary : null)),
                  const SizedBox(height: 2),
                  Text(
                      '${song.artist} \u00B7 ${song.genre ?? ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Text(formatDuration(song.durationMs),
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            if (!isMultiSelect)
              IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => showSongOptions(context, song)),
          ],
        ),
      ),
    );
  }
}
