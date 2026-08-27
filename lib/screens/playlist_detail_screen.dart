import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import '../utils/format.dart';
import '../utils/song_options.dart';
import '../widgets/az_scrollbar.dart';

enum _PlsSortOption { custom, titleAZ, titleZA, artistAZ }

class PlaylistDetailScreen extends StatefulWidget {
  final int playlistId;
  final String playlistName;
  const PlaylistDetailScreen({super.key, required this.playlistId, required this.playlistName});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Song> _songs = [];
  _PlsSortOption _sortOption = _PlsSortOption.custom;
  String _query = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  static const double _itemHeight = 72;

  String get _kPlsSort => 'pls_sort_${widget.playlistId}';

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _load());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kPlsSort) ?? 0;
    setState(() => _sortOption = _PlsSortOption.values[idx.clamp(0, _PlsSortOption.values.length - 1)]);
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPlsSort, _sortOption.index);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final songs = await context.read<PlaylistProvider>().songsIn(widget.playlistId);
    setState(() => _songs = songs);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final song = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, song);
    });
    await context.read<PlaylistProvider>().reorder(widget.playlistId, _songs.map((s) => s.id).toList());
  }

  Future<void> _removeSong(Song song) async {
    await context.read<PlaylistProvider>().removeSong(widget.playlistId, song.id);
    setState(() => _songs.removeWhere((s) => s.id == song.id));
  }

  List<Song> get _displayed {
    List<Song> list;
    switch (_sortOption) {
      case _PlsSortOption.custom:
        list = List<Song>.of(_songs);
        break;
      case _PlsSortOption.titleAZ:
        list = List<Song>.of(_songs)..sort((a, b) => compareTitles(a.title, b.title));
        break;
      case _PlsSortOption.titleZA:
        list = List<Song>.of(_songs)..sort((a, b) => compareTitles(b.title, a.title));
        break;
      case _PlsSortOption.artistAZ:
        list = List<Song>.of(_songs)
          ..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
    }
    if (_query.trim().isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((s) =>
        s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q)).toList();
  }

  void _jumpToLetter(String letter, List<Song> songs) {
    int index;
    if (letter == '#') {
      index = songs.indexWhere((s) => !RegExp(r'^[a-zA-Z]').hasMatch(s.title));
    } else {
      index = songs.indexWhere((s) => s.title.toUpperCase().startsWith(letter));
    }
    if (index == -1) return;
    _scrollController.animateTo(
      index * _itemHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayed;
    final totalMs = _songs.fold(0, (sum, s) => sum + s.durationMs);
    final showAzBar = _query.isEmpty && _sortOption == _PlsSortOption.titleAZ;
    final availableLetters = <String>{
      for (final s in displayed)
        RegExp(r'^[a-zA-Z]').hasMatch(s.title) ? s.title[0].toUpperCase() : '#'
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        actions: [
          PopupMenuButton<_PlsSortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (v) {
              setState(() => _sortOption = v);
              _savePrefs();
            },
            itemBuilder: (context) => [
              _sortMenuItem(_PlsSortOption.custom, 'Urutan kustom'),
              _sortMenuItem(_PlsSortOption.titleAZ, 'Judul A-Z'),
              _sortMenuItem(_PlsSortOption.titleZA, 'Judul Z-A'),
              _sortMenuItem(_PlsSortOption.artistAZ, 'Artis A-Z'),
            ],
          ),
        ],
      ),
      body: _songs.isEmpty
          ? const Center(child: Text('Playlist ini masih kosong'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_songs.length} lagu · ${formatDurationLong(totalMs)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ),
                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Cari di playlist ini...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => PlayerService.instance.setQueueAndPlay(displayed, 0),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Mulai Putar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await PlayerService.instance.setQueueAndPlay(displayed, 0);
                            PlayerService.instance.setShuffle(true);
                          },
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Acak'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_sortOption == _PlsSortOption.custom && _query.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.drag_handle, size: 16, color: Colors.grey),
                        SizedBox(width: 6),
                        Text('Tahan dan geser untuk mengatur urutan',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                Expanded(
                  child: displayed.isEmpty
                      ? const Center(child: Text('Lagu tidak ditemukan'))
                      : Stack(
                          children: [
                            // Gunakan ReorderableListView hanya di mode custom tanpa search
                            if (_sortOption == _PlsSortOption.custom && _query.isEmpty)
                              ReorderableListView.builder(
                                scrollController: _scrollController,
                                itemCount: displayed.length,
                                onReorder: _onReorder,
                                itemBuilder: (context, i) => _buildTile(displayed, i, reorderable: true),
                              )
                            else
                              ListView.builder(
                                controller: _scrollController,
                                itemCount: displayed.length,
                                itemExtent: _itemHeight,
                                itemBuilder: (context, i) => _buildTile(displayed, i, reorderable: false),
                              ),
                            if (showAzBar)
                              Positioned(
                                right: 0, top: 0, bottom: 0,
                                child: AzScrollbar(
                                  availableLetters: availableLetters,
                                  onLetterSelected: (letter) => _jumpToLetter(letter, displayed),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTile(List<Song> songs, int i, {required bool reorderable}) {
    final song = songs[i];
    final tile = Dismissible(
      key: ValueKey('pls_${song.id}_$i'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeSong(song),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: const Icon(Icons.music_note),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatDuration(song.durationMs),
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () async {
                await showSongOptions(context, song,
                    showFullDelete: false, playlistId: widget.playlistId);
                _load();
              },
            ),
            if (reorderable) const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
        onTap: () => PlayerService.instance.setQueueAndPlay(songs, i),
      ),
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey('plssong_${song.id}'), // tanpa $i - cegah animasi ulang saat reorder
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 180 + (i % 10) * 20),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 6), child: child),
      ),
      child: tile,
    );
  }

  PopupMenuItem<_PlsSortOption> _sortMenuItem(_PlsSortOption value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortOption == value) ...[
            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 24),
          Text(label),
        ],
      ),
    );
  }
}
