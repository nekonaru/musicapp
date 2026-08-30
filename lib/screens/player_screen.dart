import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../services/metadata_service.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../utils/song_options.dart';
import '../widgets/marquee_text.dart';
import '../widgets/sleep_timer_sheet.dart';
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

  void _onPreviousPressed() => _player.smartPrevious();

  Future<void> _pickSleepTimer() async {
    final result = await showSleepTimerSheet(context);
    if (result == null) return;

    if (result.cancel) {
      _player.cancelSleepTimer();
      return;
    }

    if (result.songCount != null) {
      _player.setSleepTimerBySongs(result.songCount!);
      return;
    }

    if (result.duration != null) {
      _player.setSleepTimer(result.duration!, finishCurrentSong: result.finishCurrentSong);
    }
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

  Future<void> _searchLyricsOnGoogle(Song song) async {
    final query = Uri.encodeComponent('${song.artist} ${song.title} lirik lyrics');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _autoFetchLyrics(Song song) async {
    setState(() => _isFetchingLyrics = true);
    await MetadataService.instance.enrichSong(song);
    if (mounted) {
      await context.read<LibraryProvider>().loadFromDb();
      if (mounted) {
        setState(() => _isFetchingLyrics = false);
        final found = song.lyrics != null && song.lyrics.toString().isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(found ? 'Lirik ditemukan!' : 'Lirik tetap tidak ditemukan, coba tambah manual'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).size.height * 0.55),
          ),
        );
      }
    }
  }

  /// Label singkat buat hitungan mundur sleep timer, ditampilkan langsung di
  /// player (bukan cuma di dalam sheet timer), null kalau timer gak aktif.
  String? _sleepTimerLabel() {
    final remaining = _player.sleepTimerRemaining;
    if (remaining != null) {
      final m = remaining.inMinutes;
      final s = remaining.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    final songsLeft = _player.sleepSongsRemaining;
    if (songsLeft != null) {
      return '$songsLeft lagu lagi';
    }
    return null;
  }

  Future<void> _addLyricsManually(Song song) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditLyricsScreen(song: song)));
    setState(() {});
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

  Widget _buildScaffold(Song song) {
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
            body: SafeArea(
              child: Column(
                children: [
                  // Bagian atas dibiarkan kosong dan bersih, cuma tombol
                  // minimize buat balik ke mini player, tanpa judul atau
                  // ikon lain.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down),
                          tooltip: 'Minimize',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
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
                      child: _showLyrics ? _buildLyricsView(song) : _buildArtView(song),
                    ),
                  ),
                  _buildControls(song, isFavorite, lib),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView(Song song) {
    final hasLyrics = song.lyrics != null && song.lyrics.toString().trim().isNotEmpty;
    return SingleChildScrollView(
      key: ValueKey('lyrics_${song.id}'),
      padding: const EdgeInsets.all(20),
      child: hasLyrics
          ? Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showLyrics = false),
                  child: Column(
                    children: [
                      Text(song.lyrics ?? '', style: const TextStyle(fontSize: 16, height: 1.6)),
                      const SizedBox(height: 16),
                      Text('Ketuk untuk kembali ke cover', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => _addLyricsManually(song),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Lirik'),
                ),
              ],
            )
          : Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showLyrics = false),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.lyrics_outlined, size: 56, color: Colors.grey[500]),
                      const SizedBox(height: 12),
                      const Text('Lirik tidak ditemukan', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Ketuk di sini untuk kembali ke cover', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
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

  Widget _buildArtView(Song song) {
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
          const SizedBox(height: 24),
          SizedBox(
            width: 280,
            child: MarqueeText(
              song.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(song.artist, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildControls(Song song, bool isFavorite, LibraryProvider lib) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              IconButton(
                icon: const Icon(Icons.skip_previous),
                tooltip: 'Sebelumnya',
                onPressed: _onPreviousPressed,
              ),
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
              IconButton(
                icon: const Icon(Icons.skip_next),
                tooltip: 'Berikutnya',
                onPressed: _player.next,
              ),
              _buildRepeatButton(),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                  size: 22,
                ),
                tooltip: 'Favorit',
                onPressed: () => lib.toggleFavorite(song, !isFavorite),
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add, size: 22, color: Colors.grey),
                tooltip: 'Tambah ke Playlist',
                onPressed: () => pickPlaylist(context, song, context.read<PlaylistProvider>()),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.bedtime_outlined,
                      color: (_player.sleepTimerRemaining != null || _player.sleepSongsRemaining != null)
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    tooltip: 'Timer Tidur',
                    onPressed: _pickSleepTimer,
                  ),
                  if (_sleepTimerLabel() != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _sleepTimerLabel()!,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.speed_outlined,
                  color: _player.playbackSpeed != 1.0 ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
                tooltip: 'Kecepatan Putar',
                onPressed: _pickPlaybackSpeed,
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_outlined, size: 22, color: Colors.grey),
                tooltip: 'Antrean Putar',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueScreen())),
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
