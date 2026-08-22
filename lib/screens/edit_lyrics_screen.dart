import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';

class EditLyricsScreen extends StatefulWidget {
  final Song song;
  const EditLyricsScreen({super.key, required this.song});

  @override
  State<EditLyricsScreen> createState() => _EditLyricsScreenState();
}

class _EditLyricsScreenState extends State<EditLyricsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.song.lyrics ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = data?.text ?? '';
    if (clipboardText.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard kosong, tidak ada teks untuk ditempel')),
        );
      }
      return;
    }

    if (_controller.text.trim().isEmpty) {
      // Belum ada lirik sama sekali, langsung tempel
      setState(() => _controller.text = clipboardText);
      return;
    }

    // Sudah ada lirik - tanya mau ditimpa atau ditambahkan
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tempel Lirik'),
        content: const Text('Sudah ada lirik di sini. Mau ditimpa (mulai dari nol) atau ditambahkan ke lirik yang ada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'append'), child: const Text('Tambahkan')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), child: const Text('Timpa')),
        ],
      ),
    );
    if (choice == 'overwrite') {
      setState(() => _controller.text = clipboardText);
    } else if (choice == 'append') {
      setState(() => _controller.text = '${_controller.text}\n$clipboardText');
    }
  }

  Future<void> _searchOnWeb() async {
    final query = Uri.encodeComponent('${widget.song.artist} ${widget.song.title} lirik lyrics');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _clear() {
    setState(() => _controller.clear());
  }

  Future<void> _save() async {
    widget.song.lyrics = _controller.text.trim().isEmpty ? null : _controller.text.trim();
    await context.read<LibraryProvider>().updateMetadata(widget.song);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Lirik: ${widget.song.title}'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Tempelkan'),
                ),
                OutlinedButton.icon(
                  onPressed: _searchOnWeb,
                  icon: const Icon(Icons.search),
                  label: const Text('Cari di Web'),
                ),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.close),
                  label: const Text('Hapus'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Belum ada lirik. Tempel dari clipboard, cari di web, atau ketik manual di sini.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Simpan Lirik'),
            ),
          ),
        ],
      ),
    );
  }
}
