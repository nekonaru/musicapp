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

  // Render only a prefix of the full sorted list to keep first paint cheap.
  // The full filter and sort results are untouched, only the row count grows.
  static const int _pageSize = 200;
  int _visibleCount = _pageSize;
  SortOption? _lastSortOption;

  // DB paged window via LibraryProvider.fetchSongsPage (querySongsPage).
  // When the paged query fails, [_paged] stays null and the screen falls
  // back to the full in memory list with the old prefix rendering.
  List<Song>? _paged;
  bool _pagedLoading = false;
  bool _pagedHasMore = false;
  SortOption? _pagedSort;

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

  /// First DB page (200 rows) with the current sort. Null means the paged
  /// query failed and the caller must use the full list fallback.
  Future<void> _loadFirstPage(LibraryProvider lib) async {
    if (_pagedLoading) return;
    _pagedLoading = true;
    final page = await lib.fetchSongsPage(limit: _pageSize, offset: 0);
    if (!mounted) return;
    setState(() {
      _pagedLoading = false;
      if (page == null) {
        _paged = null;
        _pagedHasMore = false;
      } else {
        _paged = page;
        _pagedHasMore = page.length >= _pageSize;
      }
      _pagedSort = lib.sortOption;
    });
  }

  /// Next DB page appended to the current window. Keeps the old rows when
  /// the query fails so scrolling never loses data.
  Future<void> _loadNextPage(LibraryProvider lib) async {
    if (_pagedLoading || _paged == null || !_pagedHasMore) return;
    _pagedLoading = true;
    final page =
        await lib.fetchSongsPage(limit: _pageSize, offset: _paged!.length);
    if (!mounted) return;
    setState(() {
      _pagedLoading = false;
      if (page == null || page.isEmpty) {
        _pagedHasMore = false;
      } else {
        _paged!.addAll(page);
        _pagedHasMore = page.length >= _pageSize;
      }
    });
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

  Future<void> _jumpToLetter(
      String letter, List<Song> songs, LibraryProvider lib, bool usePaged) async {
    if (!_scrollController.hasClients) return;
    int indexOf(List<Song> list) => letter == '#'
        ? list.indexWhere((s) =>
            s.title.isEmpty || !RegExp(r'^[a-zA-Z]').hasMatch(s.title))
        : list.indexWhere((s) =>
            s.title.isNotEmpty &&
            s.title.toUpperCase().startsWith(letter));
    var index = indexOf(songs);
    // In paged mode the target may live beyond the loaded window:
    // load DB pages until it is covered, then scroll to it.
    if (index == -1 && usePaged) {
      final all = lib.filteredSongs('');
      index = indexOf(all);
      if (index == -1) return;
      while (_paged != null &&
          _paged!.length <= index &&
          _pagedHasMore &&
          !_pagedLoading) {
        await _loadNextPage(lib);
      }
      if (!mounted || !_scrollController.hasClients) return;
      index = indexOf(_paged ?? songs);
      if (index == -1) return;
    } else if (index == -1) {
      return;
    }
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
          SnackBar(
              content: Text(err),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5)));
    }
  }

  // Play a song from the FULL list by id (rendering may show only a
  // paged window, but the queue must contain every song).
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
                    _loadFirstPage(lib);
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

  Widget _buildMultiSelectBar(LibraryProvider lib) {
    final l = AppLocalizations.of(context)!;
    if (!_multiSelectMode) return const SizedBox.shrink();
    final selected =
        lib.songs.where((s) => _selectedIds.contains(s.id)).toList();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(l.librarySelectedCount(_selectedIds.length),
              style: const TextStyle(fontWeight: FontWeight.bold)),
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

      // Paged DB window first, full list fallback when paging failed.
      // Kick off the first page once the full list is ready. The post frame
      // schedule keeps setState out of the build phase.
      if (_paged == null && !_pagedLoading && _pagedSort == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadFirstPage(lib);
        });
      }
      // Sort changed outside the sort menu (prefs restore): reload page.
      if (_pagedSort != null && _pagedSort != lib.sortOption) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadFirstPage(lib);
        });
      }
      final usePaged = _paged != null;
      final songs = usePaged ? _paged! : lib.filteredSongs('');
      // Queue actions (start, shuffle, tap to play) always use the FULL
      // filtered list so every song is reachable. Only rendering stays
      // paged for a fast first paint.
      final allSongs = usePaged ? lib.filteredSongs('') : songs;
      // Reset the rendered prefix when sort changes. Direct assignment here
      // is safe because it runs before the rows below are built.
      if (_lastSortOption != lib.sortOption) {
        _lastSortOption = lib.sortOption;
        _visibleCount = _pageSize;
      }
      final visibleCount = usePaged
          ? songs.length
          : (songs.length < _visibleCount ? songs.length : _visibleCount);
      final hasMore = usePaged
          ? _pagedHasMore
          : visibleCount < songs.length;
      final showAz = lib.sortOption == SortOption.titleAZ;
      final available = <String>{
        for (final s in allSongs)
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
                  onRefresh: () async {
                    await lib.forceScanDevice();
                    await _loadFirstPage(lib);
                  },
                  child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Header: sort + play buttons (hidden on scroll)
                        SliverToBoxAdapter(
                            child: _buildSortHeader(lib, allSongs)),

                        // Song list (rendered prefix only)
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
                                    : _playSongInFullList(
                                        allSongs, song.id),
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

                        // Load more button fetches the next DB page, or grows
                        // the rendered prefix in full list fallback mode.
                        if (hasMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              child: OutlinedButton(
                                onPressed: _pagedLoading
                                    ? null
                                    : () {
                                        if (usePaged) {
                                          _loadNextPage(lib);
                                        } else {
                                          setState(() {
                                            _visibleCount =
                                                visibleCount + _pageSize;
                                          });
                                        }
                                      },
                                child: Text(usePaged
                                    ? AppLocalizations.of(context)!.loadMore(
                                        visibleCount, lib.totalCount)
                                    : AppLocalizations.of(context)!.loadMore(
                                        visibleCount, songs.length)),
                              ),
                            ),
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
                      onLetterSelected: (l) =>
                          _jumpToLetter(l, songs, lib, usePaged),
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
