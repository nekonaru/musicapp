import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../screens/player_screen.dart';
import '../utils/page_transitions.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();
        return TweenAnimationBuilder<double>(
          key: ValueKey('mp_${song.id}'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: Opacity(opacity: value, child: child),
          ),
          child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            SlideUpRoute(page: const PlayerScreen()),
          ),
          child: Container(
            height: 64,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: song.albumArtUrl != null
                      ? Image.network(song.albumArtUrl!, width: 44, height: 44, fit: BoxFit.cover)
                      : Container(
                          width: 44,
                          height: 44,
                          color: Colors.grey[400],
                          child: const Icon(Icons.music_note, size: 20),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: player.previous,
                ),
                StreamBuilder(
                  stream: player.player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: player.togglePlayPause,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: player.next,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
