import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../services/player_service.dart';
import '../utils/format.dart';
import '../utils/song_options.dart';
import '../widgets/mini_player.dart';
import '../widgets/playing_indicator.dart';
import 'extra_screens.dart';
import '../widgets/playing_indicator.dart';
import 'extra_screens.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(builder: (context, lib, _) {
      if (lib.songs.isEmpty) {
        return const Center(child: Text('Belum ada data album.'));
      }

      // Group by album
      final Map<String, List<Song>> grouped = {};
      for (final s in lib.songs) {
        grouped.putIfAbsent(s.album, () => []).add(s);
      }
      final albums = grouped.keys.toList()..sort();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${albums.length} album',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
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
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _PlaceholderCover(cs: cs),
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
                  Text('${songs.length} lagu',
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
            size: 48, color: cs.onPrimaryContainer.withOpacity(0.4)),
      );
}

class _AlbumSongsScreen extends StatelessWidget {
  final String album;
  final List<Song> songs;
  const _AlbumSongsScreen({required this.album, required this.songs});

  @override
  Widget build(BuildContext context) {
    final totalMs = songs.fold(0, (sum, s) => sum + s.durationMs);
    // Artis album (ambil artis pertama/paling umum)
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
