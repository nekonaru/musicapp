import 'package:flutter/material.dart';
import '../services/player_service.dart';

/// Hasil dari SleepTimerSheet: bisa berupa Duration (mode waktu),
/// int (mode jumlah lagu), atau null kalau dibatalkan/ditutup.
class SleepTimerResult {
  final Duration? duration;
  final bool finishCurrentSong;
  final int? songCount;
  final bool cancel;
  SleepTimerResult({this.duration, this.finishCurrentSong = false, this.songCount, this.cancel = false});
}

Future<SleepTimerResult?> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<SleepTimerResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _SleepTimerSheet(),
  );
}

class _SleepTimerSheet extends StatefulWidget {
  const _SleepTimerSheet();
  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> with SingleTickerProviderStateMixin {
  late final PageController _pageController = PageController();
  int _tabIndex = 0;
  bool _finishCurrentSong = false;
  int _songCount = 5;
  int? _selectedMinutes;
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _submitTime(int minutes) {
    Navigator.pop(context, SleepTimerResult(
      duration: Duration(minutes: minutes),
      finishCurrentSong: _finishCurrentSong,
    ));
  }

  void _submitCustomTime() {
    final h = int.tryParse(_hourController.text) ?? 0;
    final m = int.tryParse(_minuteController.text) ?? 0;
    if (h == 0 && m == 0) return;
    Navigator.pop(context, SleepTimerResult(
      duration: Duration(hours: h, minutes: m),
      finishCurrentSong: _finishCurrentSong,
    ));
  }

  void _submitSongCount() {
    Navigator.pop(context, SleepTimerResult(songCount: _songCount));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: 460,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Timer Tidur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              // Toggle dua mode - bisa tap ATAU swipe kiri/kanan lewat PageView di bawah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Waktu'), icon: Icon(Icons.timer_outlined)),
                    ButtonSegment(value: 1, label: Text('Jumlah Lagu'), icon: Icon(Icons.queue_music)),
                  ],
                  selected: {_tabIndex},
                  onSelectionChanged: (s) {
                    setState(() => _tabIndex = s.first);
                    _pageController.animateToPage(s.first,
                        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _tabIndex = i),
                  children: [_buildTimeMode(), _buildSongCountMode()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, SleepTimerResult(cancel: true)),
                  child: const Text('Batalkan Timer yang Aktif'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeMode() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final m in [10, 15, 30, 45, 60])
          RadioListTile<int>(
            title: Text('$m menit'),
            value: m,
            groupValue: _selectedMinutes,
            onChanged: (v) => setState(() => _selectedMinutes = v),
          ),
        const Divider(),
        const Text('Kustom (jam & menit)', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hourController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jam', isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _minuteController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Menit', isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Selesaikan lagu terakhir'),
          subtitle: const Text('Jangan berhenti mendadak di tengah lagu'),
          value: _finishCurrentSong,
          onChanged: (v) => setState(() => _finishCurrentSong = v ?? false),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            if (_hourController.text.isNotEmpty || _minuteController.text.isNotEmpty) {
              _submitCustomTime();
            } else if (_selectedMinutes != null) {
              _submitTime(_selectedMinutes!);
            }
          },
          child: const Text('Atur Timer'),
        ),
      ],
    );
  }

  Widget _buildSongCountMode() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text('Berhenti setelah berapa lagu lagi?', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _songCount > 1 ? () => setState(() => _songCount--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 80,
                child: Text('$_songCount', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              IconButton.filledTonal(
                onPressed: _songCount < 99 ? () => setState(() => _songCount++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Text(_songCount == 1 ? 'lagu' : 'lagu', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Slider(
            value: _songCount.toDouble(),
            min: 1,
            max: 99,
            divisions: 98,
            label: '$_songCount',
            onChanged: (v) => setState(() => _songCount = v.round()),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submitSongCount, child: const Text('Atur Timer')),
        ],
      ),
    );
  }
}
