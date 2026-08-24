import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/db_helper.dart';
import '../services/player_service.dart';
import '../utils/song_options.dart';
import '../utils/format.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Song> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Dipanggil dari HomeScreen tiap kali tab Riwayat dipilih, supaya lagu
  /// yang baru saja diputar langsung muncul tanpa perlu pull-to-refresh manual.
  Future<void> reload() => _load();

  Future<void> _load() async {
    final history = await DBHelper.instance.getRecentlyPlayed();
    setState(() => _history = history);
  }

  @override
  Widget build(BuildContext context) {
    if (_history.isEmpty) {
      return const Center(child: Text('Belum ada riwayat pemutaran'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, i) {
          final song = _history[i];
          return ListTile(
            leading: const Icon(Icons.history),
            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatDuration(song.durationMs), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => showSongOptions(context, song),
                ),
              ],
            ),
            onTap: () => PlayerService.instance.setQueueAndPlay(_history, i),
          );
        },
      ),
    );
  }
}
