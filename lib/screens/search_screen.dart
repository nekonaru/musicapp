import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  void dispose() {
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

  // Kelompokkan hasil berdasarkan album/artis/folder/genre untuk tampilan grouped
  Map<String, List<Song>> _groupResults(List<Song> results) {
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
          key = parts.length > 1 ? parts[parts.length - 2] : 'Lainnya';
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
    const filters = [
      (_SearchFilter.lagu, 'Lagu'),
      (_SearchFilter.album, 'Album'),
      (_SearchFilter.artis, 'Artis'),
      (_SearchFilter.folder, 'Folder'),
      (_SearchFilter.genre, 'Genre'),
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
            onSelected: (_) => setState(() => _filter = filter),
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
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: PlayingIndicator(
                isPlaying: PlayerService.instance.player.playing,
                color: Theme.of(context).colorScheme.primary,
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
      onTap: () => PlayerService.instance.setQueueAndPlay(queue, index),
    );
  }

  Widget _buildResults(List<Song> songs) {
    final results = _getResults(songs);

    if (_query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Cari musik kamu',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Ketik judul, artis, album, atau lainnya',
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
              'Tidak ada hasil',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              '"$_query" tidak ditemukan',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_filter == _SearchFilter.lagu) {
      return AnimatedBuilder(
        animation: PlayerService.instance,
        builder: (context, _) => ListView.builder(
          itemCount: results.length,
          itemExtent: 72,
          itemBuilder: (context, i) => _buildSongTile(results[i], results, i),
        ),
      );
    }

    // Grouped view untuk album/artis/folder/genre
    final grouped = _groupResults(results);
    final groups = grouped.keys.toList()..sort();

    return AnimatedBuilder(
      animation: PlayerService.instance,
      builder: (context, _) => ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, gi) {
          final groupKey = groups[gi];
          final groupSongs = grouped[groupKey]!;
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
                    Text('${groupSongs.length} lagu',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              ...groupSongs.asMap().entries.map((e) {
                return _buildSongTile(e.value, groupSongs, e.key);
              }),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Cari musik...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          onChanged: (v) => setState(() => _query = v),
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
                    '${_getResults(lib.songs).length} hasil',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildResults(lib.songs),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
