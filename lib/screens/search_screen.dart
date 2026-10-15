import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../services/player_service.dart';
import '../utils/format.dart';
import '../utils/song_options.dart';
import '../widgets/playing_indicator.dart';
import '../widgets/mini_player.dart';

enum _SearchFilter { lagu, album, artis, folder, genre }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  _SearchFilter _filter = _SearchFilter.lagu;
  Timer? _debounce;

  // Render only a prefix of the full search results to keep scrolling cheap.
  // Filtering and grouping still use the full result list.
  static const int _pageSize = 200;
  int _visibleCount = _pageSize;

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = v;
        _visibleCount = _pageSize;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<Song> _getResults(List<Song> songs) {
    if (_query.trim().isEmpty) return [];
    final q = _query.toLowerCase();
    switch (_filter) {
      case _SearchFilter.lagu:
        return songs
            .where((s) =>
                s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q))
            .toList();
      case _SearchFilter.album:
        return songs.where((s) => s.album.toLowerCase().contains(q)).toList();
      case _SearchFilter.artis:
        return songs.where((s) => s.artist.toLowerCase().contains(q)).toList();
      case _SearchFilter.folder:
        return songs.where((s) {
          final parts = s.filePath.split('/');
          final folderName = parts.length > 1
              ? parts[parts.length - 2].toLowerCase()
              : '';
          return folderName.contains(q);
        }).toList();
      case _SearchFilter.genre:
        return songs
            .where((s) => (s.genre ?? '').toLowerCase().contains(q))
            .toList();
    }
  }

  // Group results by album/artist/folder/genre for the grouped view
  Map<String, List<Song>> _groupResults(List<Song> results) {
    final l = AppLocalizations.of(context)!;
    final map = <String, List<Song>>{};
    for (final s in results) {
      String key;
      switch (_filter) {
        case _SearchFilter.album:
          key = s.album;
          break;
        case _SearchFilter.artis:
          key = s.artist;
          break;
        case _SearchFilter.folder:
          final parts = s.filePath.split('/');
          key = parts.length > 1 ? parts[parts.length - 2] : l.searchOther;
          break;
        case _SearchFilter.genre:
          key = s.genre ?? 'Tidak diketahui';
          break;
        default:
          key = '';
      }
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  Widget _buildFilterChips() {
    final l = AppLocalizations.of(context)!;
    final filters = [
      (_SearchFilter.lagu, l.searchFilterSong),
      (_SearchFilter.album, l.searchFilterAlbum),
      (_SearchFilter.artis, l.searchFilterArtist),
      (_SearchFilter.folder, l.searchFilterFolder),
      (_SearchFilter.genre, l.searchFilterGenre),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (filter, label) = filters[i];
          final isSelected = _filter == filter;
          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => setState(() {
              _filter = filter;
              _visibleCount = _pageSize;
            }),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildSongTile(Song song, List<Song> queue, int index) {
    final current = PlayerService.instance.currentSong;
    final isPlaying = current != null && current.id == song.id;
    return ListTile(
      leading: isPlaying
          ? Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: PlayingIndicator(
                isPlaying: PlayerService.instance.player.playing,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
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
                      child: Icon(Icons.music_note, size: 20),
                    ),
                  ),
                )
              : const CircleAvatar(
                  child: Icon(Icons.music_note, size: 20),
                ),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text('${song.artist} \u00B7 ${song.album}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatDuration(song.durationMs),
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showSongOptions(context, song),
          ),
        ],
      ),
      onTap: () async {
        try {
          await PlayerService.instance.setQueueAndPlay(queue, index);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context)!
                      .libraryPlayFailed('$e'))),
            );
          }
        }
      },
    );
  }

  Widget _buildResults(List<Song> results) {
    final l = AppLocalizations.of(context)!;
    if (_query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              l.searchPromptTitle,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              l.searchPromptSubtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              l.searchNoResults,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              l.searchNotFound(_query),
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_filter == _SearchFilter.lagu) {
      // Render a prefix of the flat results plus a pager row at the end.
      final visibleCount =
          results.length < _visibleCount ? results.length : _visibleCount;
      final hasMore = visibleCount < results.length;
      return AnimatedBuilder(
        animation: PlayerService.instance,
        builder: (context, _) => ListView.builder(
          itemCount: visibleCount + (hasMore ? 1 : 0),
          itemExtent: hasMore ? null : 72,
          itemBuilder: (context, i) {
            if (i >= visibleCount) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _visibleCount = visibleCount + _pageSize;
                  }),
                  child: Text(AppLocalizations.of(context)!
                      .loadMore(visibleCount, results.length)),
                ),
              );
            }
            return SizedBox(
              height: 72,
              child: _buildSongTile(results[i], results, i),
            );
          },
        ),
      );
    }

    // Grouped view for album/artist/folder/genre
    final grouped = _groupResults(results);
    final groups = grouped.keys.toList()..sort();

    // Allocate the visible tile budget across groups in display order.
    final visibleCount =
        results.length < _visibleCount ? results.length : _visibleCount;
    final hasMore = visibleCount < results.length;
    final alloc = <int>[];
    var remaining = visibleCount;
    for (final groupKey in groups) {
      final take = grouped[groupKey]!.length <= remaining
          ? grouped[groupKey]!.length
          : remaining;
      alloc.add(take);
      remaining -= take;
    }

    return AnimatedBuilder(
      animation: PlayerService.instance,
      builder: (context, _) => ListView.builder(
        itemCount: groups.length + (hasMore ? 1 : 0),
        itemBuilder: (context, gi) {
          if (gi >= groups.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              // TODO L10N: move hardcoded English label to .arb.
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _visibleCount = visibleCount + _pageSize;
                }),
                child: Text(
                    AppLocalizations.of(context)!
                        .loadMore(visibleCount, results.length)),
              ),
            );
          }
          final groupKey = groups[gi];
          final groupSongs = grouped[groupKey]!;
          final shown = groupSongs.take(alloc[gi]).toList();
          if (shown.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(groupKey,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    Text(l.librarySongCount(groupSongs.length),
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              // Shown rows are a prefix, so index k matches the full group queue.
              for (var k = 0; k < shown.length; k++)
                _buildSongTile(shown[k], groupSongs, k),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lib = context.watch<LibraryProvider>();
    // Compute once per build, reuse for the count + list.
    final results = _getResults(lib.songs);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: l.searchHint,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _debounce?.cancel();
                      _controller.clear();
                      setState(() {
                        _query = '';
                        _visibleCount = _pageSize;
                      });
                    },
                  )
                : null,
          ),
          onChanged: _onQueryChanged,
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildFilterChips(),
          const SizedBox(height: 8),
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Align(
                  key: ValueKey(_query + _filter.name),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.searchResultCount(results.length),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildResults(results),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
