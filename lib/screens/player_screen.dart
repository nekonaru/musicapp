import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../services/metadata_service.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../utils/song_options.dart';
import '../widgets/marquee_text.dart';
import 'edit_lyrics_screen.dart';
import 'queue_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _player = PlayerService.instance;
  bool _showLyrics = false;
  bool _isFetchingLyrics = false;
  double _dragOffset = 0;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    // Timer buat update tampilan hitung mundur sleep timer tiap detik
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_player.sleepTimerEndTime != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  Future<void> _pickSleepTimer() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Timer Tidur', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final m in [10, 15, 30, 45, 60])
            ListTile(title: Text('$m menit'), onTap: () => Navigator.pop(ctx, m)),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Kustom (jam & menit)...'),
            onTap: () => Navigator.pop(ctx, 'custom'),
          ),
          ListTile(
            title: const Text('Batalkan timer'),
            onTap: () => Navigator.pop(ctx, 0),
          ),
        ],
      ),
    );
    if (result == null) return;

    Duration? finalDuration;
    if (result == 'custom') {
      finalDuration = await _promptCustomDuration();
      if (finalDuration == null) return;
    } else if (result == 0) {
      _player.cancelSleepTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timer dibatalkan')));
      }
      return;
    } else if (result is int) {
      finalDuration = Duration(minutes: result);
    }

    if (finalDuration != null) {
      _player.setSleepTimer(finalDuration);
      if (mounted) {
        final h = finalDuration.inHours;
        final m = finalDuration.inMinutes % 60;
        final label = h > 0 ? '$h jam ${m > 0 ? '$m menit' : ''}'.trim() : '$m menit';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timer diatur $label')));
      }
    }
  }

  Future<Duration?> _promptCustomDuration() async {
    final hourController = TextEditingController();
    final minuteController = TextEditingController();
    return showDialog<Duration>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Timer Kustom'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: hourController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jam'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: minuteController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Menit'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final h = int.tryParse(hourController.text) ?? 0;
              final m = int.tryParse(minuteController.text) ?? 0;
              if (h == 0 && m == 0) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx, Duration(hours: h, minutes: m));
            },
            child: const Text('Atur'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPlaybackSpeed() async {
    final options = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final speed = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Kecepatan Putar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final s in options)
            ListTile(
              title: Text('${s}x'),
              trailing: _player.playbackSpeed == s ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (speed != null) await _player.setPlaybackSpeed(speed);
  }

  Future<void> _searchLyricsOnGoogle(song) async {
    final query = Uri.encodeComponent('${song.artist} ${song.title} lirik lyrics');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _autoFetchLyrics(song) async {
    setState(() => _isFetchingLyrics = true);
    await MetadataService.instance.enrichSong(song);
    if (mounted) {
      await context.read<LibraryProvider>().loadFromDb();
      setState(() => _isFetchingLyrics = false);
      final found = song.lyrics != null && song.lyrics.toString().isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(found ? 'Lirik ditemukan!' : 'Lirik tetap tidak ditemukan, coba tambah manual')),
      );
    }
  }

  Future<void> _addLyricsManually(song) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditLyricsScreen(song: song)));
    setState(() {});
  }

  String _fmtCountdown(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
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
    final lib = context.watch<LibraryProvider>();
    final matchInLib = lib.songs.where((s) => s.id == song.id);
    final isFavorite = matchInLib.isNotEmpty ? matchInLib.first.isFavorite : false;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0) {
          setState(() => _dragOffset += details.delta.dy);
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > 100 || (details.primaryVelocity ?? 0) > 600) {
          Navigator.pop(context);
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -250) {
          _player.next();
        } else if (velocity > 250) {
          _player.previous();
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Opacity(
          opacity: (1 - (_dragOffset / 400)).clamp(0.4, 1.0),
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                tooltip: 'Minimize',
                onPressed: () => Navigator.pop(context),
              ),
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(_showLyrics ? 'Lirik' : 'Sedang Diputar', key: ValueKey(_showLyrics)),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.queue_music_outlined),
                  tooltip: 'Antrean Putar',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueScreen())),
                ),
                if (_showLyrics)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Lirik',
                    onPressed: () => _addLyricsManually(song),
                  ),
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: child),
                    child: Icon(_showLyrics ? Icons.album : Icons.lyrics_outlined, key: ValueKey(_showLyrics)),
                  ),
                  onPressed: () => setState(() => _showLyrics = !_showLyrics),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _showLyrics ? _buildLyricsView(song) : _buildArtView(song, isFavorite, lib),
                  ),
                ),
                _buildControls(song),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView(song) {
    final hasLyrics = song.lyrics != null && song.lyrics.toString().trim().isNotEmpty;
    return SingleChildScrollView(
      key: ValueKey('lyrics_${song.id}'),
      padding: const EdgeInsets.all(20),
      child: hasLyrics
          ? GestureDetector(
              onTap: () => setState(() => _showLyrics = false),
              child: Column(
                children: [
                  Text(song.lyrics, style: const TextStyle(fontSize: 16, height: 1.6)),
                  const SizedBox(height: 16),
                  Text('Ketuk untuk kembali ke cover', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.lyrics_outlined, size: 56, color: Colors.grey[500]),
                const SizedBox(height: 12),
                const Text('Lirik tidak ditemukan', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _searchLyricsOnGoogle(song),
                      icon: const Icon(Icons.search),
                      label: const Text('Cari di Google'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isFetchingLyrics ? null : () => _autoFetchLyrics(song),
                      icon: _isFetchingLyrics
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_sync_outlined),
                      label: const Text('Cari Otomatis'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _addLyricsManually(song),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Tambah Manual'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildArtView(song, bool isFavorite, LibraryProvider lib) {
    return Center(
      key: ValueKey('art_${song.id}'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showLyrics = true),
            child: StreamBuilder(
              stream: _player.player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return AnimatedScale(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  scale: playing ? 1.0 : 0.92,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: playing
                          ? [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                                blurRadius: 28,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: song.albumArtUrl != null
                          ? CachedNetworkImage(
                              imageUrl: song.albumArtUrl!,
                              width: 260, height: 260, fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 260, height: 260, color: Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 260, height: 260, color: Colors.grey[300],
                                child: const Icon(Icons.music_note, size: 80),
                              ),
                            )
                          : Container(
                              width: 260,
                              height: 260,
                              color: Colors.grey[300],
                              child: const Icon(Icons.music_note, size: 80),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('Ketuk cover untuk lihat lirik', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 16),
          SizedBox(
            width: 280,
            child: MarqueeText(
              song.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(song.artist, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                tooltip: 'Favorit',
                onPressed: () => lib.toggleFavorite(song, !isFavorite),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: 'Tambah ke Playlist',
                onPressed: () => pickPlaylist(context, song, context.read<PlaylistProvider>()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(song) {
    final remaining = _player.sleepTimerRemaining;
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
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                      max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1,
                      onChanged: (v) => _player.player.seek(Duration(milliseconds: v.toInt())),
                    ),
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
                    color: _player.isShuffle ? Theme.of(context).colorScheme.primary : Colors.grey),
                onPressed: () => setState(() => _player.toggleShuffle()),
              ),
              IconButton(icon: const Icon(Icons.skip_previous), onPressed: _player.previous),
              StreamBuilder(
                stream: _player.player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return IconButton(
                    iconSize: 48,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        key: ValueKey(playing),
                      ),
                    ),
                    onPressed: () async {
                      await _player.togglePlayPause();
                      setState(() {});
                    },
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.skip_next), onPressed: _player.next),
              _buildRepeatButton(),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _pickSleepTimer,
                icon: const Icon(Icons.bedtime_outlined),
                label: Text(remaining != null ? _fmtCountdown(remaining) : 'Timer Tidur'),
              ),
              TextButton.icon(
                onPressed: _pickPlaybackSpeed,
                icon: const Icon(Icons.speed_outlined),
                label: Text('${_player.playbackSpeed}x'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tombol repeat yang kontras jelas untuk tiap mode: mati (abu-abu outline),
  /// ulang semua (chip ungu terisi), ulang satu lagu (chip ungu + angka "1").
  Widget _buildRepeatButton() {
    final mode = _player.repeatMode;
    final color = Theme.of(context).colorScheme.primary;
    final isActive = mode != RepeatMode.off;

    return GestureDetector(
      onTap: () => setState(() => _player.cycleRepeatMode()),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          mode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
          color: isActive ? color : Colors.grey,
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}
