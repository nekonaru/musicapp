import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swara/l10n/gen/app_localizations.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import '../services/art_cache_service.dart';
import '../widgets/az_scrollbar.dart';
import '../widgets/playing_indicator.dart';
import '../widgets/sort_chip.dart';
import '../utils/song_options.dart';
import '../utils/format.dart';
import 'missing_art_screen.dart';
import 'missing_lyrics_screen.dart';
import 'bulk_edit_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

// ─────────────────────────────────────────────────────────────
// First load skeleton: grey pulsing boxes, no new dependency.
// ─────────────────────────────────────────────────────────────

/// Single grey bar that fades in once on first load.
class _SkeletonBar extends StatelessWidget {
  final double height;
  final double width;
  const _SkeletonBar({required this.height, this.width = double.infinity});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.7),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, v, _) => Opacity(
        opacity: v,
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// Simple vertical skeleton list for the library first load.
class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: 10,
      itemBuilder: (context, i) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _SkeletonBar(height: 40, width: 40),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(height: 12, width: 160),
                  SizedBox(height: 6),
                  _SkeletonBar(height: 10, width: 110),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 72.0;

  bool _multiSelectMode = false;
  final Set<int> _selectedIds = {};

  // The whole filtered and sorted list is rendered. Rendering stays lazy
  // because the sliver uses a fixed item extent, so a list of 20k rows
  // costs the same per frame as a list of 200 rows.
  static const double _azStickyThreshold = 400.0;

  // Letter to row index map, rebuilt only when the visible list changes.
  // A-Z jumps are therefore a scroll offset lookup instead of a DB query.
  Map<String, int>? _azIndex;
  int _azIndexLength = -1;
  SortOption? _azIndexSort;

  // Show the "jump to playing song" affordance while scrolled away.
  bool _playingRowHidden = false;

  // Playlists are loaded lazily on first use to keep startup cheap.
  bool _playlistsRequested = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Track whether the currently playing row is far outside the viewport so
  // the jump button can appear. Only a boolean flips, never a setState per
  // pixel, because the state changes are compared before rebuilding.
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final song = PlayerService.instance.currentSong;
    if (song == null) {
      if (_playingRowHidden) setState(() => _playingRowHidden = false);
      return;
    }
    final hidden = _playingRowHidden;
    var next = hidden;
    final extent = position.viewportDimension;
    if (extent > 0) {
      final row = _visibleIndexOfSongId(song.id);
      if (row >= 0) {
        // Distance of the row top from the current viewport top.
        final distance = (row * _itemHeight) - position.pixels;
        next = distance > _azStickyThreshold + extent ||
            distance < -_azStickyThreshold;
      }
    }
    if (next != hidden) setState(() => _playingRowHidden = next);
  }

  void _jumpToPlayingRow() {
    final song = PlayerService.instance.currentSong;
    if (song == null || !_scrollController.hasClients) return;
    final row = _visibleIndexOfSongId(song.id);
    if (row < 0) return;
    final offset = (row * _itemHeight - 24)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // Index of a song inside the last rendered list. Kept in a field so the
  // scroll listener does not rebuild the list just to look the id up.
  List<Song> _lastVisibleList = const [];
  int _visibleIndexOfSongId(int id) {
    final list = _lastVisibleList;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) return i;
    }
    return -1;
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

  /// Build (or reuse) the letter to row index map for the visible list. One
  /// linear pass, no DB access, so an A-Z jump is a single scroll.
  Map<String, int> _buildAzIndex(List<Song> songs, SortOption sort) {
    final cached = _azIndex;
    if (cached != null && _azIndexLength == songs.length && _azIndexSort == sort) {
      return cached;
    }
    final map = <String, int>{};
    for (var i = 0; i < songs.length; i++) {
      final title = songs[i].title;
      final letter = title.isNotEmpty && RegExp(r'^[a-zA-Z]').hasMatch(title)
          ? safeInitial(title)
          : '#';
      // Keep the first row of each letter so the jump lands on the group head.
      map.putIfAbsent(letter, () => i);
    }
    _azIndex = map;
    _azIndexLength = songs.length;
    _azIndexSort = sort;
    return map;
  }

  void _jumpToLetter(String letter, Map<String, int> azIndex) {
    if (!_scrollController.hasClients) return;
    final index = azIndex[letter];
    if (index == null) return;
    final offset = (index * _itemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  // Select every song of the currently visible list, or clear the selection
  // when everything is already selected.
  void _toggleSelectAll(List<Song> visible) {
    setState(() {
      if (_selectedIds.length >= visible.length) {
        _selectedIds.clear();
        _multiSelectMode = false;
      } else {
        for (final s in visible) {
          _selectedIds.add(s.id);
        }
      }
    });
  }

  Future<void> _playSong(List<Song> queue, int index) async {
    await PlayerService.instance.setQueueAndPlay(queue, index);
    final err = PlayerService.instance.lastError;
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(err),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5)));
    }
  }

  // Play a song from the visible list by id so the queue matches what the
  // user sees, including every row of a long list.
  Future<void> _playSongInFullList(List<Song> allSongs, int songId) async {
    var index = allSongs.indexWhere((s) => s.id == songId);
    if (index < 0) index = 0;
    if (allSongs.isEmpty) return;
    await _playSong(allSongs, index);
  }

  void _showSortMenu(BuildContext context, LibraryProvider lib) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        // Cap height at 90 percent of the screen and scroll on small phones.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: SingleChildScrollView(
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
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
          SnackBar(
              content: Text(l.libraryCreatePlaylistFirst),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3)));
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        // Cap height at 90 percent of the screen and scroll long lists.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.libraryChoosePlaylist,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            ...playlists.map((p) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
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
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                          content: Text(l.libraryAddedToPlaylist(
                              songs.length, p['name']))));
                    }
                  },
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectBar(LibraryProvider lib, List<Song> visible) {
    final l = AppLocalizations.of(context)!;
    if (!_multiSelectMode) return const SizedBox.shrink();
    final selected =
        visible.where((s) => _selectedIds.contains(s.id)).toList();
    final allSelected =
        visible.isNotEmpty && _selectedIds.length >= visible.length;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(l.librarySelectedCount(_selectedIds.length),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          IconButton(
              constraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(allSelected
                  ? Icons.deselect
                  : Icons.select_all),
              tooltip: allSelected
                  ? AppLocalizations.of(context)!.libraryClearSelection
                  : AppLocalizations.of(context)!.librarySelectAll,
              onPressed: () => _toggleSelectAll(visible)),
          const Spacer(),
          IconButton(
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.playlist_add),
              tooltip: l.libraryAddToPlaylist,
              onPressed:
                  selected.isEmpty ? null : () => _bulkAddToPlaylist(selected)),
          IconButton(
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.edit),
              tooltip:
                  AppLocalizations.of(context)!.bulkEditAction,
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BulkEditScreen(songs: selected),
                        ),
                      );
                      if (!mounted) return;
                      _exitMultiSelect();
                    }),
          IconButton(
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
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
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.close),
              onPressed: _exitMultiSelect),
        ],
      ),
    );
  }

  Widget _buildSortHeader(LibraryProvider lib, List<Song> songs) {
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sort chip + total info
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              // Shared ripple chip, same label as before.
              SortChip(
                label: _sortLabel(context, lib.sortOption),
                onTap: () => _showSortMenu(context, lib),
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
                      constraints: const BoxConstraints(
                          minWidth: 48, minHeight: 48),
                      icon:
                          const Icon(Icons.cloud_sync_outlined, size: 18),
                      tooltip: l.libraryScanMetadata,
                      onPressed: () => _showScanMenu(context, lib),
                    ),
            ],
          ),
        ),
        // Play buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        return Column(
          children: [
            Expanded(child: const _LibrarySkeleton()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(l.libraryScanningMusic,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
          ],
        );
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

      // One list, no paging. The sliver below has a fixed item extent so
      // only the visible rows are built even with tens of thousands of songs.
      final songs = lib.filteredSongs('');
      _lastVisibleList = songs;
      final showAz = lib.sortOption == SortOption.titleAZ;
      final azIndex =
          showAz ? _buildAzIndex(songs, lib.sortOption) : <String, int>{};
      final available = azIndex.keys.toSet();

      return Column(
        children: [
          if (lib.isScanning) const LinearProgressIndicator(),
          if (lib.isBulkScanningMetadata)
            LinearProgressIndicator(
                value: lib.bulkScanTotal == 0
                    ? null
                    : lib.bulkScanProgress / lib.bulkScanTotal),
          _buildMultiSelectBar(lib, songs),
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => lib.forceScanDevice(),
                  child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Header: sort + play buttons (hidden on scroll)
                        SliverToBoxAdapter(
                            child: _buildSortHeader(lib, songs)),

                        // Full list with a fixed row height. Rows outside the
                        // viewport are never built, so the cost per frame is
                        // the same regardless of the library size.
                        SliverFixedExtentList(
                          itemExtent: _itemHeight,
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final song = songs[i];
                              final isSelected =
                                  _selectedIds.contains(song.id);
                              return _SongTile(
                                song: song,
                                index: i,
                                isSelected: isSelected,
                                isMultiSelect: _multiSelectMode,
                                onTap: () => _multiSelectMode
                                    ? _toggleSelect(song.id)
                                    : _playSongInFullList(songs, song.id),
                                onLongPress: () => setState(() {
                                  _multiSelectMode = true;
                                  _selectedIds.add(song.id);
                                }),
                                onOptions: _openSongOptions,
                              );
                            },
                            childCount: songs.length,
                          ),
                        ),
                        // Bottom padding so the last row is not flush against
                        // the mini player.
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),

                        ],
                    ),
                  ),
                if (showAz && !_multiSelectMode)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: AzScrollbar(
                      availableLetters: available,
                      onLetterSelected: (letter) =>
                          _jumpToLetter(letter, azIndex),
                    ),
                  ),
                // Jump back to the playing song when it is off screen.
                if (_playingRowHidden && !_multiSelectMode)
                  Positioned(
                    right: showAz ? 34 : 16,
                    bottom: 16,
                    child: Selector<PlayerService, int?>(
                      selector: (_, ps) => ps.currentSong?.id,
                      builder: (context, id, _) {
                        if (id == null) return const SizedBox.shrink();
                        return FloatingActionButton.small(
                          heroTag: 'jumpToPlaying',
                          onPressed: _jumpToPlayingRow,
                          tooltip:
                              AppLocalizations.of(context)!.libraryJumpPlaying,
                          child: const Icon(Icons.graphic_eq),
                        );
                      },
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
    // Count of songs with neither local art nor remote art URL.
    final missingCount = lib.songs.where((s) {
      final path = (s.albumArtPath ?? '').trim();
      final url = (s.albumArtUrl ?? '').trim();
      return path.isEmpty && url.isEmpty;
    }).length;
    // Count of songs with null or blank lyrics.
    final missingLyricsCount = lib.songs.where((s) {
      return (s.lyrics ?? '').trim().isEmpty;
    }).length;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.cloud_sync_outlined),
            title: Text(l.libraryScanMissing),
            onTap: () {
              Navigator.pop(ctx);
              lib.bulkScanMetadata(onlyMissing: true);
            },
          ),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
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
          // Entry to the screen listing songs without cover art.
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.image_not_supported_outlined),
            title: Text(AppLocalizations.of(context)!.artMissingEntry),
            trailing: missingCount > 0
                ? CircleAvatar(
                    radius: 12,
                    child: Text('$missingCount',
                        style: const TextStyle(fontSize: 12)),
                  )
                : null,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MissingArtScreen()),
              );
            },
          ),
          // Entry to the screen listing songs without lyrics.
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.lyrics_outlined),
            title: Text(AppLocalizations.of(context)!.missLyricsEntry),
            trailing: missingLyricsCount > 0
                ? CircleAvatar(
                    radius: 12,
                    child: Text('$missingLyricsCount',
                        style: const TextStyle(fontSize: 12)),
                  )
                : null,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MissingLyricsScreen()),
              );
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

// Small now playing icon that rebuilds only itself when the current
// song or the play state changes. The rest of the tile and the list
// stay untouched on PlayerService notifies.
class _NowPlayingIcon extends StatelessWidget {
  final int songId;
  final Widget fallback;
  const _NowPlayingIcon({required this.songId, required this.fallback});

  @override
  Widget build(BuildContext context) {
    // Provide the singleton locally so Selector works without
    // touching the global provider setup in main.dart.
    return ChangeNotifierProvider.value(
      value: PlayerService.instance,
      child: Selector<PlayerService, bool>(
        selector: (_, ps) => ps.currentSong?.id == songId,
        builder: (context, isCurrent, _) {
          if (!isCurrent) return fallback;
          final cs = Theme.of(context).colorScheme;
          return Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            // Inner selector so play and pause only rebuild the bars.
            child: Selector<PlayerService, bool>(
              selector: (_, ps) => ps.player.playing,
              builder: (context, playing, _) =>
                  PlayingIndicator(isPlaying: playing, color: cs.primary),
            ),
          );
        },
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final bool isSelected, isMultiSelect;
  final VoidCallback onTap, onLongPress;
  final Future<void> Function(Song song)? onOptions;

  const _SongTile({
    required this.song,
    required this.index,
    required this.isSelected,
    required this.isMultiSelect,
    required this.onTap,
    required this.onLongPress,
    this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Normal artwork shown when this row is not the current song.
    final Widget artFallback = song.albumArtUrl != null
        // Disk cached artwork with network fallback.
        ? ClipOval(
            child: CachedArtImage(
              url: song.albumArtUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              // Decode thumbnail size only to save image memory.
              cacheWidth: 88,
              fallback: const CircleAvatar(
                child: Icon(Icons.music_note, size: 20),
              ),
            ),
          )
        : const CircleAvatar(child: Icon(Icons.music_note, size: 20));
    // Provide the singleton locally so the Selector below works
    // without touching the global provider setup in main.dart.
    // Only this tile rebuilds when its own isCurrent flag flips.
    // Play and pause only rebuild the small icon inside.
    return ChangeNotifierProvider.value(
      value: PlayerService.instance,
      child: Selector<PlayerService, bool>(
        selector: (_, ps) => ps.currentSong?.id == song.id,
        builder: (context, isPlaying, _) => InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: isSelected
            ? cs.primaryContainer.withValues(alpha: 0.5)
            : isPlaying
                ? cs.primaryContainer.withValues(alpha: 0.25)
                : null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      child: _NowPlayingIcon(
                          songId: song.id, fallback: artFallback),
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
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => onOptions?.call(song) ??
                      showSongOptions(context, song)),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
