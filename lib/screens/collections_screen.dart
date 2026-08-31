import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import '../utils/format.dart';
import '../utils/song_options.dart';
import 'extra_screens.dart';
import 'history_screen.dart';
import 'playlist_detail_screen.dart';

// Warna kartu referensi (sesuai gambar Nomad Music)
const _cardColors = [
  Color(0xFF7B1A1A), // Favorit - merah tua
  Color(0xFF6B5200), // Baru ditambahkan - emas
  Color(0xFF1A3A6B), // Baru diputar - biru
  Color(0xFF1A5C30), // Paling sering - hijau
];

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  String _sortLabel = 'Nama \u2191';
  bool _sortAZ = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<PlaylistProvider>().load());
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Playlist Baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama playlist'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Buat')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      context.read<PlaylistProvider>().create(name);
    }
  }

  Future<void> _confirmDelete(
      BuildContext ctx, PlaylistProvider prov, int id, String name) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Playlist'),
        content: Text('Hapus "$name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) prov.delete(id);
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, anim, __) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer2<PlaylistProvider, LibraryProvider>(
      builder: (context, playlists, lib, _) {
        final pl = List<Map<String, dynamic>>.from(playlists.playlists);
        if (_sortAZ) {
          pl.sort((a, b) => (a['name'] as String)
              .toLowerCase()
              .compareTo((b['name'] as String).toLowerCase()));
        } else {
          pl.sort((a, b) => (b['name'] as String)
              .toLowerCase()
              .compareTo((a['name'] as String).toLowerCase()));
        }

        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── Quick-access cards (Favorit, Baru ditambahkan, Baru diputar, Paling sering) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.6,
                      children: [
                        _QuickCard(
                          title: 'Favorit',
                          subtitle: '${lib.favorites.length} lagu',
                          icon: Icons.favorite,
                          bgColor: _cardColors[0],
                          onTap: () => _openPage(context, const _FavSheet()),
                        ),
                        _QuickCard(
                          title: 'Baru ditambahkan',
                          subtitle: '',
                          icon: Icons.add_box_outlined,
                          bgColor: _cardColors[1],
                          onTap: () =>
                              _openPage(context, const _RecentlySheet()),
                        ),
                        _QuickCard(
                          title: 'Baru diputar',
                          subtitle: '',
                          icon: Icons.history_outlined,
                          bgColor: _cardColors[2],
                          onTap: () =>
                              _openPage(context, const _HistorySheet()),
                        ),
                        _QuickCard(
                          title: 'Paling sering diputar',
                          subtitle: '',
                          icon: Icons.trending_up_outlined,
                          bgColor: _cardColors[3],
                          onTap: () =>
                              _openPage(context, const _MostPlayedSheet()),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Sort bar + count ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            _sortAZ = !_sortAZ;
                            _sortLabel = _sortAZ ? 'Nama \u2191' : 'Nama \u2193';
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort, size: 14),
                                const SizedBox(width: 4),
                                Text(_sortLabel,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: cs.primary)),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${pl.length} daftar putar',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Daftar playlist ──
                pl.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.queue_music_outlined,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              const Text('Belum ada playlist',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final p = pl[i];
                            return TweenAnimationBuilder<double>(
                              key: ValueKey('pl_${p['id']}'),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration:
                                  Duration(milliseconds: 160 + (i % 8) * 25),
                              curve: Curves.easeOut,
                              builder: (ctx, v, child) => Opacity(
                                opacity: v,
                                child: Transform.translate(
                                    offset: Offset(0, (1 - v) * 6),
                                    child: child),
                              ),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.fromLTRB(16, 4, 8, 4),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.queue_music,
                                      color: cs.onPrimaryContainer, size: 22),
                                ),
                                title: Text(p['name'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (action) {
                                    if (action == 'delete') {
                                      _confirmDelete(context, playlists,
                                          p['id'], p['name']);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Hapus')),
                                  ],
                                ),
                                onTap: () => _openPage(
                                  context,
                                  PlaylistDetailScreen(
                                      playlistId: p['id'],
                                      playlistName: p['name']),
                                ),
                              ),
                            );
                          },
                          childCount: pl.length,
                        ),
                      ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),

            // FAB tambah playlist
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'fab_new_playlist',
                onPressed: _createPlaylist,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Quick card widget
// ─────────────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Wrapper screens (dibuka dari quick cards)
// ─────────────────────────────────────────────────────────────

class _FavSheet extends StatelessWidget {
  const _FavSheet();
  @override
  Widget build(BuildContext context) => const Scaffold(
      body: FavoritesScreen());
}

class _RecentlySheet extends StatelessWidget {
  const _RecentlySheet();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: RecentlyAddedScreen());
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet();
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Baru Diputar')),
          body: HistoryScreen());
}

class _MostPlayedSheet extends StatelessWidget {
  const _MostPlayedSheet();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: MostPlayedScreen());
}
