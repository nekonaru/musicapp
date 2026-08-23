import 'package:flutter/material.dart';
import '../services/player_service.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});
  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _player = PlayerService.instance;
  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 68;
  bool _scrolledOnce = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentIfNeeded(int currentIndex) {
    if (_scrolledOnce) return;
    _scrolledOnce = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Tampilkan lagu yang sedang diputar di dekat bagian atas layar (bukan mepet atas banget)
      final target = (currentIndex * _itemHeight - _itemHeight).clamp(0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(target.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) {
        final queue = _player.queue;
        final slotIds = _player.queueSlotIds;
        final currentIndex = _player.currentIndex;
        if (queue.isNotEmpty) _scrollToCurrentIfNeeded(currentIndex);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Antrean Putar'),
          ),
          body: queue.isEmpty
              ? const Center(child: Text('Antrean kosong'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('Tahan-geser untuk urutkan · geser ke kiri untuk hapus',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: _scrollController,
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) => _player.reorderQueue(oldIndex, newIndex),
                        itemBuilder: (context, i) {
                          final song = queue[i];
                          final slotId = slotIds[i]; // ID stabil - tidak berubah meski list ke-refresh
                          final isPlaying = i == currentIndex;
                          return Container(
                            key: ValueKey('queue_slot_$slotId'),
                            height: _itemHeight,
                            child: Dismissible(
                              key: ValueKey('queue_dismiss_slot_$slotId'),
                              direction: isPlaying ? DismissDirection.none : DismissDirection.endToStart,
                              onDismissed: (_) => _player.removeQueueSlot(slotId),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              child: Container(
                                color: isPlaying
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                                    : null,
                                child: ListTile(
                                  leading: isPlaying
                                      ? Icon(Icons.equalizer, color: Theme.of(context).colorScheme.primary)
                                      : Text('${i + 1}', style: TextStyle(color: Colors.grey[500])),
                                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal)),
                                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isPlaying)
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 20),
                                          onPressed: () => _player.removeQueueSlot(slotId),
                                        ),
                                      const Icon(Icons.drag_handle, color: Colors.grey),
                                    ],
                                  ),
                                  onTap: () => _player.playAtQueueIndex(i),
                                ),
                              ),
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
