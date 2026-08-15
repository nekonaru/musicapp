import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';

class EditMetadataScreen extends StatefulWidget {
  final Song song;
  const EditMetadataScreen({super.key, required this.song});

  @override
  State<EditMetadataScreen> createState() => _EditMetadataScreenState();
}

class _EditMetadataScreenState extends State<EditMetadataScreen> {
  late TextEditingController _title;
  late TextEditingController _artist;
  late TextEditingController _album;
  late TextEditingController _genre;
  late TextEditingController _region;
  late TextEditingController _lyrics;

  @override
  void initState() {
    super.initState();
    final s = widget.song;
    _title = TextEditingController(text: s.title);
    _artist = TextEditingController(text: s.artist);
    _album = TextEditingController(text: s.album);
    _genre = TextEditingController(text: s.genre ?? '');
    _region = TextEditingController(text: s.region ?? '');
    _lyrics = TextEditingController(text: s.lyrics ?? '');
  }

  Future<void> _save() async {
    final s = widget.song;
    s.title = _title.text.trim();
    s.artist = _artist.text.trim();
    s.album = _album.text.trim();
    s.genre = _genre.text.trim().isEmpty ? null : _genre.text.trim();
    s.region = _region.text.trim().isEmpty ? null : _region.text.trim();
    s.lyrics = _lyrics.text.trim().isEmpty ? null : _lyrics.text.trim();

    await context.read<LibraryProvider>().updateMetadata(s);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Metadata'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Judul')),
          const SizedBox(height: 12),
          TextField(controller: _artist, decoration: const InputDecoration(labelText: 'Artis')),
          const SizedBox(height: 12),
          TextField(controller: _album, decoration: const InputDecoration(labelText: 'Album')),
          const SizedBox(height: 12),
          TextField(controller: _genre, decoration: const InputDecoration(labelText: 'Genre')),
          const SizedBox(height: 12),
          TextField(controller: _region, decoration: const InputDecoration(labelText: 'Asal Region')),
          const SizedBox(height: 12),
          TextField(
            controller: _lyrics,
            decoration: const InputDecoration(labelText: 'Lirik', alignLabelWithHint: true),
            maxLines: 10,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Simpan Perubahan')),
        ],
      ),
    );
  }
}
