import 'package:flutter/material.dart';
import '../services/player_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _player = PlayerService.instance;
  bool _showLyrics = false;

  Future<void> _pickSleepTimer() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in [10, 15, 30, 45, 60])
            ListTile(title: Text('$m menit'), onTap: () => Navigator.pop(ctx, m)),
          ListTile(
            title: const Text('Batalkan timer'),
            onTap: () => Navigator.pop(ctx, 0),
          ),
        ],
      ),
    );
    if (minutes == null) return;
    if (minutes == 0) {
      _player.cancelSleepTimer();
    } else {
      _player.setSleepTimer(Duration(minutes: minutes));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(minutes == 0 ? 'Timer dibatalkan' : 'Timer diatur $minutes menit')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) {
        final song = _player.currentSong;
        if (song == null) {
          return const Scaffold(body: Center(child: Text('Belum ada lagu diputar')));
        }
        return _buildScaffold(song);
      },
    );
  }

  Widget _buildScaffold(song) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showLyrics ? 'Lirik' : 'Sedang Diputar'),
        actions: [
          IconButton(
            icon: Icon(_showLyrics ? Icons.album : Icons.lyrics_outlined),
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _showLyrics
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      song.lyrics ?? 'Lirik belum tersedia. Bisa ditambahkan lewat menu Edit Metadata.',
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: song.albumArtUrl != null
                              ? Image.network(song.albumArtUrl!, width: 260, height: 260, fit: BoxFit.cover)
                              : Container(
                                  width: 260,
                                  height: 260,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.music_note, size: 80),
                                ),
                        ),
                        const SizedBox(height: 24),
                        Text(song.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(song.artist, style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          StreamBuilder<Duration>(
            stream: _player.player.positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? Duration.zero;
              final dur = _player.player.duration ?? Duration.zero;
              return Column(
                children: [
                  Slider(
                    value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                    max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1,
                    onChanged: (v) => _player.player.seek(Duration(milliseconds: v.toInt())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos)),
                        Text(_fmt(dur)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.shuffle,
                    color: _player.isShuffle ? Theme.of(context).colorScheme.primary : null),
                onPressed: () => setState(() => _player.toggleShuffle()),
              ),
              IconButton(icon: const Icon(Icons.skip_previous), onPressed: _player.previous),
              StreamBuilder(
                stream: _player.player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return IconButton(
                    iconSize: 48,
                    icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    onPressed: () async {
                      await _player.togglePlayPause();
                      setState(() {});
                    },
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.skip_next), onPressed: _player.next),
              IconButton(
                icon: Icon(_repeatIcon()),
                onPressed: () => setState(() => _player.cycleRepeatMode()),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _pickSleepTimer,
            icon: const Icon(Icons.bedtime_outlined),
            label: const Text('Timer Tidur'),
          ),
        ],
      ),
    );
  }

  IconData _repeatIcon() {
    switch (_player.repeatMode) {
      case RepeatMode.off:
        return Icons.repeat;
      case RepeatMode.all:
        return Icons.repeat_on;
      case RepeatMode.one:
        return Icons.repeat_one_on;
    }
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}
