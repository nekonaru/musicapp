import 'package:flutter/material.dart';
import '../services/player_service.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});
  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _player = PlayerService.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) {
        final queue = _player.queue;
        final currentIndex = _player.currentIndex;
        return Scaffold(
          appBar: AppBar(title: const Text('Antrean Putar')),
          body: queue.isEmpty
              ? const Center(child: Text('Antrean kosong'))
              : ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, i) {
                    final song = queue[i];
                    final isPlaying = i == currentIndex;
                    return ListTile(
                      tileColor: isPlaying
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : null,
                      leading: isPlaying
                          ? Icon(Icons.equalizer, color: Theme.of(context).colorScheme.primary)
                          : Text('${i + 1}', style: TextStyle(color: Colors.grey[500])),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: i > currentIndex
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => _player.removeFromQueue(i),
                            )
                          : null,
                      onTap: () => _player.playAtQueueIndex(i),
                    );
                  },
                ),
        );
      },
    );
  }
}
