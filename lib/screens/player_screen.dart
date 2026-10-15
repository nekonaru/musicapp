import 'dart:async';
import 'package:flutter/material.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../services/art_cache_service.dart';
import '../services/metadata_service.dart';
import '../services/db_helper.dart';
import '../utils/lrc.dart';
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

  // Synced (LRC) lyrics state. Lines load once per song from the DB,
  // then a positionStream listener highlights the active line.
  final ScrollController _lrcScrollController = ScrollController();
  final Map<int, GlobalKey> _lrcLineKeys = {};
  StreamSubscription<Duration>? _lrcPositionSub;
  List<LrcLine> _lrcLines = [];
  int _lrcIndex = -1;
  int? _lrcSongId;
  bool _lrcLoading = false;
  bool _syncedMode = true;

  @override
  void initState() {
    super.initState();
    // Timer to refresh the sleep timer countdown display every second
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_player.sleepTimerEndTime != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _stopLrcFollow();
    _lrcScrollController.dispose();
    super.dispose();
  }

  void _onPreviousPressed() => _player.smartPrevious();

  Future<void> _pickSleepTimer() async {
    // The timer is set directly inside SleepTimerSheet._start()
    // so there is no return value to handle here.
    await showSleepTimerSheet(context);
  }

  Future<void> _pickPlaybackSpeed() async {
    final options = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final speed = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(AppLocalizations.of(ctx)!.playerPlaybackSpeed,
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.playerCannotOpenBrowser)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.playerSearchOpenFailed)),
        );
      }
    }
  }

  Future<void> _autoFetchLyrics(Song song) async {
    if (_isFetchingLyrics) return;
    setState(() => _isFetchingLyrics = true);
    var found = false;
    try {
      // fetchLyricsOnly does NOT overwrite title/artist/album (unlike enrichSong),
      // so manual user edits are safe; it only fills song.lyrics.
      found = await MetadataService.instance.fetchLyricsOnly(song);
      if (found && mounted) {
        await context.read<LibraryProvider>().updateMetadata(song);
        found = song.lyrics?.trim().isNotEmpty ?? false;
      }
    } catch (_) {
      found = song.lyrics?.trim().isNotEmpty ?? false;
    }
    if (!mounted) return;
    setState(() => _isFetchingLyrics = false);
    // fetchLyricsOnly also refreshes the synced store, so reload the lines.
    _lrcSongId = null;
    _lrcLineKeys.clear();
    await _maybeLoadSyncedLyrics(song);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(found ? l10n.playerLyricsFound : l10n.playerLyricsNotFoundHint),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).size.height * 0.55),
      ),
    );
  }

  /// Show or hide the lyrics view, starting or stopping the synced
  /// line follower so no position updates arrive while it is hidden.
  void _setShowLyrics(bool value) {
    if (_showLyrics == value) return;
    setState(() => _showLyrics = value);
    if (value) {
      if (_lrcLines.isNotEmpty && _syncedMode) _startLrcFollow();
    } else {
      _stopLrcFollow();
    }
  }

  /// Load synced lyrics for [song] once per song from the DB and parse
  /// them into display lines. Safe to call from build: guarded by song id.
  Future<void> _maybeLoadSyncedLyrics(Song song) async {
    if (_lrcSongId == song.id || _lrcLoading) return;
    _lrcSongId = song.id;
    _lrcLoading = true;
    _lrcLines = [];
    _lrcIndex = -1;
    _lrcLineKeys.clear();
    _stopLrcFollow();
    try {
      final lrc = await DBHelper.instance.getSyncedLyrics(song.id);
      if (!mounted) return;
      final lines =
          (lrc == null || lrc.isEmpty) ? <LrcLine>[] : parseLrc(lrc);
      setState(() {
        _lrcLoading = false;
        _lrcLines = lines;
        _lrcIndex = -1;
        // Default to synced view when lines exist, plain text otherwise.
        _syncedMode = lines.isNotEmpty;
      });
      if (lines.isNotEmpty && _showLyrics && _syncedMode) _startLrcFollow();
    } catch (_) {
      if (!mounted) return;
      setState(() => _lrcLoading = false);
    }
  }

  /// Follow the player position and highlight the active synced line.
  /// Rebuilds only when the active line index actually changes.
  void _startLrcFollow() {
    _stopLrcFollow();
    if (!_syncedMode || _lrcLines.isEmpty) return;
    _lrcPositionSub = _player.player.positionStream.listen((pos) {
      if (!mounted) return;
      final idx = _lrcIndexFor(pos.inMilliseconds);
      if (idx == _lrcIndex) return;
      setState(() => _lrcIndex = idx);
      _scrollToLrcLine(idx);
    });
  }

  void _stopLrcFollow() {
    _lrcPositionSub?.cancel();
    _lrcPositionSub = null;
  }

  /// Switch between the synced and plain lyric views.
  void _setSyncedMode(bool value) {
    if (_syncedMode == value) return;
    setState(() {
      _syncedMode = value;
      _lrcIndex = -1;
    });
    if (value) {
      _startLrcFollow();
    } else {
      _stopLrcFollow();
    }
  }

  /// Index of the last line whose timestamp is at or before [positionMs].
  int _lrcIndexFor(int positionMs) {
    var idx = -1;
    for (var i = 0; i < _lrcLines.length; i++) {
      if (_lrcLines[i].timeMs <= positionMs) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  /// Bring line [idx] into view after the highlight rebuild settles.
  void _scrollToLrcLine(int idx) {
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_lrcScrollController.hasClients) return;
      final ctx = _lrcLineKeys[idx]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        alignment: 0.4,
      );
    });
  }

  /// Short label for the sleep timer countdown, shown directly in the
  /// player (not only inside the timer sheet), null when the timer is inactive.
  String? _sleepTimerLabel(BuildContext context) {
    final remaining = _player.sleepTimerRemaining;
    if (remaining != null) {
      final m = remaining.inMinutes;
      final s = remaining.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    final songsLeft = _player.sleepSongsRemaining;
    if (songsLeft != null) {
      return AppLocalizations.of(context)!.playerSongsRemaining(songsLeft);
    }
    return null;
  }

  Future<void> _addLyricsManually(Song song) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditLyricsScreen(song: song)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) {
        final song = _player.currentSong;
        if (song == null) {
          return Scaffold(body: Center(child: Text(AppLocalizations.of(context)!.playerEmptyState)));
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
                  // The top area is kept empty and clean, only a
                  // minimize button to go back to the mini player,
                  // without a title or other icons.
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
    _maybeLoadSyncedLyrics(song);
    final hasSynced = _lrcLines.isNotEmpty;
    if (hasSynced && _syncedMode && _lrcPositionSub == null && _showLyrics) {
      _startLrcFollow();
    }
    final Widget body =
        (hasSynced && _syncedMode) ? _buildSyncedLyricsView() : _buildPlainLyricsView(song);
    if (!hasSynced) return body;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: true,
                  label: Text(AppLocalizations.of(context)!.lyricsSynced)),
              ButtonSegment(
                  value: false,
                  label: Text(AppLocalizations.of(context)!.lyricsPlain)),
            ],
            selected: {_syncedMode},
            onSelectionChanged: (s) => _setSyncedMode(s.first),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  /// Synced lyrics list with the active line highlighted and kept visible.
  Widget _buildSyncedLyricsView() {
    return ListView.builder(
      key: ValueKey('synced_$_lrcSongId'),
      controller: _lrcScrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _lrcLines.length,
      itemBuilder: (context, i) {
        final line = _lrcLines[i];
        final active = i == _lrcIndex;
        final key = _lrcLineKeys.putIfAbsent(i, () => GlobalKey());
        return Container(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            line.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: active ? 18 : 15,
              height: 1.6,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainLyricsView(Song song) {
    final hasLyrics = song.lyrics != null && song.lyrics.toString().trim().isNotEmpty;
    return SingleChildScrollView(
      key: ValueKey('lyrics_${song.id}'),
      padding: const EdgeInsets.all(20),
      child: hasLyrics
          ? Column(
              children: [
                GestureDetector(
                  onTap: () => _setShowLyrics(false),
                  child: Column(
                    children: [
                      Text(song.lyrics ?? '', style: const TextStyle(fontSize: 16, height: 1.6)),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.playerTapToReturnToCover, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => _addLyricsManually(song),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(AppLocalizations.of(context)!.playerEditLyrics),
                ),
              ],
            )
          : Column(
              children: [
                GestureDetector(
                  onTap: () => _setShowLyrics(false),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.lyrics_outlined, size: 56, color: Colors.grey[500]),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context)!.playerLyricsNotFound, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(AppLocalizations.of(context)!.playerTapHereToReturnToCover, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
                      label: Text(AppLocalizations.of(context)!.playerSearchOnGoogle),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isFetchingLyrics ? null : () => _autoFetchLyrics(song),
                      icon: _isFetchingLyrics
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_sync_outlined),
                      label: Text(AppLocalizations.of(context)!.playerAutoSearch),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _addLyricsManually(song),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(AppLocalizations.of(context)!.playerAddManually),
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
            onTap: () => _setShowLyrics(true),
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
                          // Disk cached artwork with network fallback.
                          ? CachedArtImage(
                              url: song.albumArtUrl!,
                              width: 260, height: 260, fit: BoxFit.cover,
                              // Decode near display size to save image memory.
                              cacheWidth: 520,
                              loading: Container(
                                width: 260,
                                height: 260,
                                color: Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              fallback: Container(
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
                onPressed: _player.toggleShuffle,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous),
                tooltip: AppLocalizations.of(context)!.playerPrevious,
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
                    onPressed: _player.togglePlayPause,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                tooltip: AppLocalizations.of(context)!.playerNext,
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
                tooltip: AppLocalizations.of(context)!.playerFavorite,
                onPressed: () => lib.toggleFavorite(song, !isFavorite),
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add, size: 22, color: Colors.grey),
                tooltip: AppLocalizations.of(context)!.playerAddToPlaylist,
                onPressed: () => pickPlaylist(context, song, context.read<PlaylistProvider>()),
              ),
              // ListenableBuilder so the "N more songs" label stays updated
              // whenever sleepSongsRemaining changes (without waiting for another rebuild).
              ListenableBuilder(
                listenable: _player,
                builder: (context, _) {
                  final label = _sleepTimerLabel(context);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.bedtime_outlined,
                          color: (_player.sleepTimerRemaining != null || _player.sleepSongsRemaining != null)
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        tooltip: AppLocalizations.of(context)!.playerSleepTimer,
                        onPressed: _pickSleepTimer,
                      ),
                      if (label != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.speed_outlined,
                  color: _player.playbackSpeed != 1.0 ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
                tooltip: AppLocalizations.of(context)!.playerPlaybackSpeed,
                onPressed: _pickPlaybackSpeed,
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_outlined, size: 22, color: Colors.grey),
                tooltip: AppLocalizations.of(context)!.queueTitle,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Repeat button with clear contrast for each mode: off (grey outline),
  /// repeat all (filled purple chip), repeat one (purple chip with a "1").
  Widget _buildRepeatButton() {
    final mode = _player.repeatMode;
    final color = Theme.of(context).colorScheme.primary;
    final isActive = mode != SwaraRepeatMode.off;

    return GestureDetector(
      onTap: _player.cycleRepeatMode,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          mode == SwaraRepeatMode.one ? Icons.repeat_one : Icons.repeat,
          color: isActive ? color : Colors.grey,
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return '${d.inMinutes}:${two(d.inSeconds % 60)}';
  }
}
