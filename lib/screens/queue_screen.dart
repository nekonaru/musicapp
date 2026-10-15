import 'package:flutter/material.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
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
  void initState() {
    super.initState();
    // Initial scroll once after the first frame; later queue changes
    // are observed through a listener - no side effects in build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentIfNeeded());
    _player.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    _player.removeListener(_onQueueChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueueChanged() => _scrollToCurrentIfNeeded();

  void _scrollToCurrentIfNeeded() {
    if (_scrolledOnce) return;
    if (_player.queue.isEmpty) return;
    _scrolledOnce = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final currentIndex = _player.currentIndex;
      // Show the currently playing song near the top of the screen (not flush with the very top)
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

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.queueTitle),
          ),
          body: queue.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.queue_music_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.queueEmpty,
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(AppLocalizations.of(context)!.queueReorderHint,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: _scrollController,
                        itemCount: queue.length,
                        onReorderItem: (oldIndex, newIndex) => _player.reorderQueue(oldIndex, newIndex),
                        itemBuilder: (context, i) {
                          final song = queue[i];
                          final slotId = slotIds[i]; // Stable ID - unchanged even when the list refreshes
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
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16),
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
                                          constraints:
                                              const BoxConstraints(
                                                  minWidth: 48,
                                                  minHeight: 48),
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
