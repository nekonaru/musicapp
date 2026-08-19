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
          appBar: AppBar(
            title: const Text('Antrean Putar'),
          ),
          body: queue.isEmpty
              ? const Center(child: Text('Antrean kosong'))
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.drag_handle, size: 18, color: Colors.grey),
                          SizedBox(width: 6),
                          Text('Tahan dan geser untuk mengatur urutan',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) => _player.reorderQueue(oldIndex, newIndex),
                        itemBuilder: (context, i) {
                          final song = queue[i];
                          final isPlaying = i == currentIndex;
                          return Dismissible(
                            key: ValueKey('queue_${song.id}_$i'),
                            direction: i > currentIndex ? DismissDirection.endToStart : DismissDirection.none,
                            onDismissed: (_) => _player.removeFromQueue(i),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: ListTile(
                              tileColor: isPlaying
                                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                                  : null,
                              leading: isPlaying
                                  ? Icon(Icons.equalizer, color: Theme.of(context).colorScheme.primary)
                                  : Text('${i + 1}', style: TextStyle(color: Colors.grey[500])),
                              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal)),
                              subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (i > currentIndex)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () => _player.removeFromQueue(i),
                                    ),
                                  const Icon(Icons.drag_handle, color: Colors.grey),
                                ],
                              ),
                              onTap: () => _player.playAtQueueIndex(i),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
