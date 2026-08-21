import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/player_service.dart';
import '../screens/edit_metadata_screen.dart';

/// Menu opsi lagu (bottom sheet) yang dipakai bersama di semua layar
/// supaya perilakunya konsisten: Semua Lagu, Folder, Favorit, Playlist.
Future<void> showSongOptions(BuildContext context, Song song) async {
  final lib = context.read<LibraryProvider>();
  final playlistProvider = context.read<PlaylistProvider>();

  await showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              song.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('Putar Berikutnya'),
            onTap: () {
              PlayerService.instance.playNext(song);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ditambahkan untuk diputar berikutnya')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_check),
            title: const Text('Tambah ke Akhir Antrean'),
            onTap: () {
              PlayerService.instance.addToQueueEnd(song);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ditambahkan ke antrean')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Tambah/Hapus dari Favorit'),
            onTap: () {
              lib.toggleFavorite(song, true);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Tambah ke Playlist'),
            onTap: () async {
              Navigator.pop(ctx);
              pickPlaylist(context, song, playlistProvider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Ganti Nama Lagu'),
            onTap: () async {
              Navigator.pop(ctx);
              _renameSong(context, song, lib);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Metadata'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => EditMetadataScreen(song: song)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Hapus dari Library', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(ctx);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Hapus Lagu'),
                  content: Text('Hapus "${song.title}" dari library? (file asli di HP tidak terhapus)'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
                  ],
                ),
              );
              if (confirm == true) lib.deleteSong(song);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _renameSong(BuildContext context, Song song, LibraryProvider lib) async {
  final controller = TextEditingController(text: song.title);
  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ganti Nama Lagu'),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Simpan')),
      ],
    ),
  );
  if (newName != null && newName.trim().isNotEmpty) {
    song.title = newName.trim();
    await lib.updateMetadata(song);
  }
}

Future<void> pickPlaylist(BuildContext context, Song song, PlaylistProvider provider) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in provider.playlists)
            ListTile(
              title: Text(p['name']),
              onTap: () {
                provider.addSong(p['id'], song.id);
                Navigator.pop(ctx);
              },
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Buat Playlist Baru'),
            onTap: () async {
              Navigator.pop(ctx);
              final controller = TextEditingController();
              final name = await showDialog<String>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Nama Playlist'),
                  content: TextField(controller: controller, autofocus: true),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Buat')),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) {
                await provider.create(name);
                final newest = provider.playlists.first;
                await provider.addSong(newest['id'], song.id);
              }
            },
          ),
        ],
      ),
    ),
  );
}
