import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swara/l10n/gen/app_localizations.dart';
import '../providers/playlist_provider.dart';
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

  // Default name for the "save queue as playlist" dialog.
  // Includes hour and minute so saving twice in one day does not collide.
  String _defaultQueuePlaylistName() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return 'Queue ${now.year}-$mm-$dd $hh-$min';
  }

  // Remove one queue entry by stable slot id. Resolves the live position
  // first; a null result means the entry is already gone, so ignore it.
  void _removeSlot(int slotId) {
    final int? pos = _player.queuePosForSlot(slotId);
    if (pos == null) return;
    _player.removeFromQueue(pos);
  }

  // Save the current queue (in playback order) as a new playlist.
  // Uses only the existing PlaylistProvider API. Shows success or
  // failure feedback via snackbar.
  Future<void> _saveQueueAsPlaylist() async {
    final queue = _player.queue;
    if (queue.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final controller =
        TextEditingController(text: _defaultQueuePlaylistName());
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.queueSaveTooltip),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.queueSaveHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      final prov = context.read<PlaylistProvider>();
      // Same duplicate name handling as collections: on a UNIQUE error
      // retry with a numeric suffix until creation succeeds.
      var base = name.trim();
      if (base.isEmpty) base = _defaultQueuePlaylistName();
      var finalName = base;
      var suffix = 2;
      var playlistId = -1;
      while (playlistId < 0) {
        try {
          await prov.create(finalName);
          if (!mounted) return;
          final found = prov.playlists.firstWhere(
            (p) => (p['name'] as String) == finalName,
          );
          playlistId = found['id'] as int;
        } catch (e) {
          // Retry with a suffix only on duplicate name errors.
          if (!e.toString().contains('UNIQUE')) rethrow;
          finalName = '$base ($suffix)';
          suffix++;
        }
      }
      // Add every queued song in order. Per-song failures (for example
      // duplicates) are skipped so the rest of the queue still saves.
      var added = 0;
      for (final song in queue) {
        try {
          await prov.addSong(playlistId, song.id);
          added++;
        } catch (_) {
          // Skip this song and continue with the rest.
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!
              .queueSaved(added, queue.length, finalName)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!
              .queueSaveFailed(e.toString())),
        ),
      );
    }
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
            actions: [
              IconButton(
                tooltip:
                    AppLocalizations.of(context)!.queueSaveTooltip,
                icon: const Icon(Icons.playlist_add),
                onPressed: queue.isEmpty ? null : _saveQueueAsPlaylist,
              ),
            ],
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
                              onDismissed: (_) => _removeSlot(slotId),
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
                                          onPressed: () => _removeSlot(slotId),
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
