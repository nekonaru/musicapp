import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../services/player_service.dart';
import '../services/art_cache_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/sort_chip.dart';
import 'extra_screens.dart';

// Sort mode for the album grid. Session only, no persistence needed.
enum _AlbumSortOption { titleAZ, titleZA, countDesc, countAsc }

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  _AlbumSortOption _sortOption = _AlbumSortOption.titleAZ;

  // Short label shown inside the sort chip.
  String _sortChipLabel(AppLocalizations l) {
    switch (_sortOption) {
      case _AlbumSortOption.titleAZ:
        return l.albumSortTitleAZ;
      case _AlbumSortOption.titleZA:
        return l.albumSortTitleZA;
      case _AlbumSortOption.countDesc:
        return l.albumSortCountDesc;
      case _AlbumSortOption.countAsc:
        return l.albumSortCountAsc;
    }
  }

  // Full label shown inside the sort sheet rows.
  String _sortSheetLabel(AppLocalizations l, _AlbumSortOption opt) {
    switch (opt) {
      case _AlbumSortOption.titleAZ:
        return l.albumSortTitleAZ;
      case _AlbumSortOption.titleZA:
        return l.albumSortTitleZA;
      case _AlbumSortOption.countDesc:
        return l.albumSortCountDesc;
      case _AlbumSortOption.countAsc:
        return l.albumSortCountAsc;
    }
  }

  // Order album keys by the current session sort option.
  List<String> _sortedAlbums(
      List<String> keys, Map<String, List<Song>> grouped) {
    final sorted = List<String>.of(keys);
    switch (_sortOption) {
      case _AlbumSortOption.titleAZ:
        sorted.sort(
            (a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        break;
      case _AlbumSortOption.titleZA:
        sorted.sort(
            (a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
        break;
      case _AlbumSortOption.countDesc:
        sorted.sort((a, b) =>
            (grouped[b]?.length ?? 0).compareTo(grouped[a]?.length ?? 0));
        break;
      case _AlbumSortOption.countAsc:
        sorted.sort((a, b) =>
            (grouped[a]?.length ?? 0).compareTo(grouped[b]?.length ?? 0));
        break;
    }
    return sorted;
  }

  // Simple bottom sheet with the four sort choices.
  void _showSortMenu() {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(l.librarySortBy,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ..._AlbumSortOption.values.map((opt) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  dense: true,
                  leading: _sortOption == opt
                      ? Icon(Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary)
                      : const SizedBox(width: 18),
                  title: Text(_sortSheetLabel(l, opt)),
                  onTap: () {
                    setState(() => _sortOption = opt);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(builder: (context, lib, _) {
      final l = AppLocalizations.of(context)!;
      if (lib.songs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.album_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(l.albumsEmpty, textAlign: TextAlign.center),
            ],
          ),
        );
      }

      // Group by album
      final Map<String, List<Song>> grouped = {};
      for (final s in lib.songs) {
        grouped.putIfAbsent(s.album, () => []).add(s);
      }
      final albums = _sortedAlbums(grouped.keys.toList(), grouped);

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.albumsCount(albums.length),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500])),
                ),
                // Shared ripple chip, same label as before.
                SortChip(
                  label: _sortChipLabel(l),
                  onTap: _showSortMenu,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: albums.length,
              itemBuilder: (context, i) {
                final album = albums[i];
                final songs = grouped[album]!;
                final cover = songs.firstWhere(
                    (s) => s.albumArtUrl != null,
                    orElse: () => songs.first);
                return TweenAnimationBuilder<double>(
                  key: ValueKey('album_$album'),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 160 + (i % 12) * 18),
                  curve: Curves.easeOut,
                  builder: (ctx, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                          offset: Offset(0, (1 - v) * 8), child: child)),
                  child: _AlbumCard(
                    album: album,
                    songs: songs,
                    coverUrl: cover.albumArtUrl,
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _AlbumCard extends StatelessWidget {
  final String album;
  final List<Song> songs;
  final String? coverUrl;

  const _AlbumCard(
      {required this.album, required this.songs, this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 280),
            pageBuilder: (_, anim, __) =>
                _AlbumSongsScreen(album: album, songs: songs),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover art
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: coverUrl != null
                    // Disk cached artwork with network fallback.
                    ? CachedArtImage(
                        url: coverUrl!,
                        fit: BoxFit.cover,
                        // Match grid column width to limit decoded size.
                        cacheWidth: 400,
                        fallback: _PlaceholderCover(cs: cs),
                      )
                    : _PlaceholderCover(cs: cs),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(l.librarySongCount(songs.length),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final ColorScheme cs;
  const _PlaceholderCover({required this.cs});
  @override
  Widget build(BuildContext context) => Container(
        color: cs.primaryContainer,
        child: Icon(Icons.album_outlined,
            size: 48, color: cs.onPrimaryContainer.withValues(alpha: 0.4)),
      );
}

class _AlbumSongsScreen extends StatelessWidget {
  final String album;
  final List<Song> songs;
  const _AlbumSongsScreen({required this.album, required this.songs});

  @override
  Widget build(BuildContext context) {
    final totalMs = songs.fold(0, (sum, s) => sum + s.durationMs);
    // Album artist (take the first/most common artist)
    final artistMap = <String, int>{};
    for (final s in songs) {
      artistMap[s.artist] = (artistMap[s.artist] ?? 0) + 1;
    }
    final topArtist = artistMap.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return Scaffold(
      appBar: AppBar(title: Text(album)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(topArtist,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[500])),
                ),
                buildCollectionHeader(
                    context: context,
                    songCount: songs.length,
                    totalMs: totalMs,
                    songs: songs),
              ],
            ),
          ),
          SliverFixedExtentList(
            itemExtent: 72,
            delegate: SliverChildBuilderDelegate(
              (context, i) => AnimatedBuilder(
                animation: PlayerService.instance,
                builder: (context, _) =>
                    buildSongTile(context, songs[i], songs, i),
              ),
              childCount: songs.length,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
