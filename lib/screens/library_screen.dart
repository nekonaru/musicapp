import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
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

  // Render only a prefix of the full sorted list to keep first paint cheap.
  // The full filter and sort results are untouched, only the row count grows.
  static const int _pageSize = 200;
  int _visibleCount = _pageSize;
  SortOption? _lastSortOption;

  // Playlists are loaded lazily on first use to keep startup cheap.
  bool _playlistsRequested = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Load playlists once when first needed. Guarded by mounted.
  Future<void> _ensurePlaylistsLoaded() async {
    if (_playlistsRequested) return;
    _playlistsRequested = true;
    if (!mounted) return;
    await context.read<PlaylistProvider>().load();
  }

  // Song options need the playlist list, so ensure it is ready first.
  Future<void> _openSongOptions(Song song) async {
    await _ensurePlaylistsLoaded();
    if (!mounted) return;
    showSongOptions(context, song);
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
    if (!_scrollController.hasClients) return;
    final index = letter == '#'
        ? songs.indexWhere((s) =>
            s.title.isEmpty || !RegExp(r'^[a-zA-Z]').hasMatch(s.title))
        : songs.indexWhere((s) =>
            s.title.isNotEmpty &&
            s.title.toUpperCase().startsWith(letter));
    if (index == -1) return;
    // Expand the rendered prefix so the jump target exists before scrolling.
    if (index >= _visibleCount) {
      setState(() {
        _visibleCount = ((index ~/ _pageSize) + 1) * _pageSize;
      });
    }
    final offset =
        (index * _itemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
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
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(l.librarySortBy,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ...SortOption.values.map((opt) => ListTile(
                  dense: true,
                  leading: lib.sortOption == opt
                      ? Icon(Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary)
                      : const SizedBox(width: 18),
                  title: Text(_sortLabel(context, opt)),
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

  String _sortLabel(BuildContext context, SortOption opt) {
    final l = AppLocalizations.of(context)!;
    switch (opt) {
      case SortOption.titleAZ:
        return l.librarySortTitleAsc;
      case SortOption.titleZA:
        return l.librarySortTitleDesc;
      case SortOption.artistAZ:
        return l.librarySortArtistAsc;
      case SortOption.artistZA:
        return l.librarySortArtistDesc;
      case SortOption.albumAZ:
        return l.librarySortAlbumAsc;
      case SortOption.albumZA:
        return l.librarySortAlbumDesc;
      case SortOption.dateAddedNewest:
        return l.librarySortDateNewest;
      case SortOption.dateAddedOldest:
        return l.librarySortDateOldest;
      case SortOption.genre:
        return l.librarySortGenre;
    }
  }

  Future<void> _bulkAddToPlaylist(List<Song> songs) async {
    // Lazy load playlists on first need instead of at startup.
    await _ensurePlaylistsLoaded();
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    final provider = context.read<PlaylistProvider>();
    final playlists = provider.playlists;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.libraryCreatePlaylistFirst)));
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
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.libraryChoosePlaylist,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            ...playlists.map((p) => ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(p['name']),
                  onTap: () async {
                    await Future.wait(
                        songs.map((s) => provider.addSong(p['id'], s.id)));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    _exitMultiSelect();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l.libraryAddedToPlaylist(
                              songs.length, p['name']))));
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectBar(LibraryProvider lib) {
    final l = AppLocalizations.of(context)!;
    if (!_multiSelectMode) return const SizedBox.shrink();
    final selected =
        lib.songs.where((s) => _selectedIds.contains(s.id)).toList();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(l.librarySelectedCount(_selectedIds.length),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: l.libraryAddToPlaylist,
              onPressed:
                  selected.isEmpty ? null : () => _bulkAddToPlaylist(selected)),
          IconButton(
              icon: const Icon(Icons.favorite_border),
              tooltip: l.libraryAddToFavorites,
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      await lib.setFavoritesBulk(selected, true);
                      if (!mounted) return;
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
    final l = AppLocalizations.of(context)!;
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
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _sortLabel(context, lib.sortOption),
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
                l.librarySongCountDuration(
                    lib.totalCount, formatDurationLong(lib.totalDurationMs)),
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
                      tooltip: l.libraryScanMetadata,
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
                  label: Text(l.libraryStartPlaying),
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
                  label: Text(l.libraryShuffle),
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
    final l = AppLocalizations.of(context)!;
    return Consumer<LibraryProvider>(builder: (context, lib, _) {
      if (lib.isScanning && lib.songs.isEmpty) {
        return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l.libraryScanningMusic),
        ]));
      }
      if (lib.songs.isEmpty) {
        return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.library_music_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(l.libraryNoMusic,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: () => lib.forceScanDevice(),
              icon: const Icon(Icons.search),
              label: Text(l.libraryScanMusic)),
        ]));
      }

      final songs = lib.filteredSongs('');
      // Reset the rendered prefix when sort changes. Direct assignment here
      // is safe because it runs before the rows below are built.
      if (_lastSortOption != lib.sortOption) {
        _lastSortOption = lib.sortOption;
        _visibleCount = _pageSize;
      }
      final visibleCount =
          songs.length < _visibleCount ? songs.length : _visibleCount;
      final hasMore = visibleCount < songs.length;
      final showAz = lib.sortOption == SortOption.titleAZ;
      final available = <String>{
        for (final s in songs)
          RegExp(r'^[a-zA-Z]').hasMatch(s.title)
              ? safeInitial(s.title)
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
                        // Header: sort + play buttons (hidden on scroll)
                        SliverToBoxAdapter(
                            child: _buildSortHeader(lib, songs)),

                        // Song list (rendered prefix only)
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
                                onOptions: _openSongOptions,
                              );
                            },
                            childCount: visibleCount,
                          ),
                        ),

                        // Load more button grows the rendered prefix by one page.
                        if (hasMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              child: OutlinedButton(
                                onPressed: () => setState(() {
                                  _visibleCount = visibleCount + _pageSize;
                                }),
                                child: Text(
                                    AppLocalizations.of(context)!.loadMore(
                                        visibleCount, songs.length)),
                              ),
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
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: Text(l.libraryScanMissing),
            onTap: () {
              Navigator.pop(ctx);
              lib.bulkScanMetadata(onlyMissing: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(l.libraryRescanAll),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                        title: Text(l.libraryRescanAll),
                        content: Text(
                            l.libraryRescanConfirm(lib.totalCount)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(l.cancel)),
                          FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(l.libraryStart)),
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
  final Future<void> Function(Song song)? onOptions;

  const _SongTile({
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.isSelected,
    required this.isMultiSelect,
    required this.onTap,
    required this.onLongPress,
    this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: isSelected
            ? cs.primaryContainer.withValues(alpha: 0.5)
            : isPlaying
                ? cs.primaryContainer.withValues(alpha: 0.25)
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
                                  color: cs.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle),
                              child: PlayingIndicator(
                                  isPlaying: PlayerService
                                      .instance.player.playing,
                                  color: cs.primary))
                          : song.albumArtUrl != null
                              // Remote artwork without extra cache dependency.
                              ? ClipOval(
                                  child: Image.network(
                                    song.albumArtUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    // Decode thumbnail size only to save image memory.
                                    cacheWidth: 88,
                                    errorBuilder: (context, url, error) =>
                                        const CircleAvatar(
                                      child:
                                          Icon(Icons.music_note, size: 20),
                                    ),
                                  ),
                                )
                              : const CircleAvatar(
                                  child:
                                      Icon(Icons.music_note, size: 20)),
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
                  onPressed: () => onOptions?.call(song) ??
                      showSongOptions(context, song)),
          ],
        ),
      ),
    );
  }
}
