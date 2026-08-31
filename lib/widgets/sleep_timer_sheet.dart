import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../utils/format.dart';

enum _TimerMode { waktu, lagu }


/// Fungsi top-level untuk kompatibilitas dengan pemanggil lama (player_screen.dart, dll).
Future<void> showSleepTimerSheet(BuildContext context) =>
    SleepTimerSheet.show(context);

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  _TimerMode _mode = _TimerMode.waktu;
  bool _finishSong = false;

  // Waktu mode
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;

  // Lagu mode
  late final FixedExtentScrollController _songCtrl;

  // Pilihan menit: 00, 05, 10, ..., 55
  static final List<int> _minuteOptions =
      List.generate(12, (i) => i * 5); // 0,5,10,...,55

  static const int _defaultHour = 0;
  static const int _defaultMinuteIndex = 3; // 15 menit
  static const int _defaultSongIndex = 4;   // 5 lagu

  @override
  void initState() {
    super.initState();
    _hourCtrl = FixedExtentScrollController(initialItem: _defaultHour);
    _minCtrl =
        FixedExtentScrollController(initialItem: _defaultMinuteIndex);
    _songCtrl =
        FixedExtentScrollController(initialItem: _defaultSongIndex);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    _songCtrl.dispose();
    super.dispose();
  }

  void _start() {
    final ps = PlayerService.instance;
    if (_mode == _TimerMode.waktu) {
      final hours = _hourCtrl.selectedItem;
      final minutes = _minuteOptions[_minCtrl.selectedItem];
      final total = hours * 60 + minutes;
      if (total == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set waktu lebih dari 0')),
        );
        return;
      }
      ps.setSleepTimer(
        Duration(minutes: total),
        finishCurrentSong: _finishSong,
      );
    } else {
      final count = _songCtrl.selectedItem + 1;
      ps.setSleepTimerBySongs(count);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_mode == _TimerMode.waktu
            ? 'Timer tidur diaktifkan (${_hourCtrl.selectedItem}j ${_minuteOptions[_minCtrl.selectedItem]}m)'
            : 'Timer tidur: ${_songCtrl.selectedItem + 1} lagu lagi'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Judul
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Timer tidur',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          // Mode toggle: Waktu | Lagu
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _ModeButton(
                  label: 'Waktu',
                  selected: _mode == _TimerMode.waktu,
                  onTap: () => setState(() => _mode = _TimerMode.waktu),
                  color: cs.primary,
                ),
                _ModeButton(
                  label: 'Lagu',
                  selected: _mode == _TimerMode.lagu,
                  onTap: () => setState(() => _mode = _TimerMode.lagu),
                  color: cs.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Picker area
          SizedBox(
            height: 160,
            child: _mode == _TimerMode.waktu
                ? _buildTimePicker(cs)
                : _buildSongPicker(cs),
          ),
          const SizedBox(height: 12),

          // Checkbox "Selesaikan lagu terakhir" - hanya untuk mode waktu
          if (_mode == _TimerMode.waktu)
            InkWell(
              onTap: () => setState(() => _finishSong = !_finishSong),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _finishSong,
                        onChanged: (v) =>
                            setState(() => _finishSong = v ?? false),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Selesaikan lagu terakhir',
                        style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Tutup',
                      style: TextStyle(
                          color: cs.onSurface, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _start,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Mulai',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTimePicker(ColorScheme cs) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Divider lines (highlight area picker aktif)
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
            const SizedBox(height: 52),
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
          ],
        ),

        // Dua kolom picker: jam dan menit
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Jam (0-12)
            SizedBox(
              width: 100,
              child: _WheelPicker(
                controller: _hourCtrl,
                itemCount: 13,
                labelBuilder: (i) => '$i',
              ),
            ),

            // Separator ":"
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(':',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ),

            // Menit (00, 05, 10, ..., 55)
            SizedBox(
              width: 100,
              child: _WheelPicker(
                controller: _minCtrl,
                itemCount: _minuteOptions.length,
                labelBuilder: (i) =>
                    _minuteOptions[i].toString().padLeft(2, '0'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSongPicker(ColorScheme cs) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Divider lines
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
            const SizedBox(height: 52),
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
          ],
        ),

        // Picker lagu (1-100)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: _WheelPicker(
                controller: _songCtrl,
                itemCount: 100,
                labelBuilder: (i) => '${i + 1}',
              ),
            ),
            const SizedBox(width: 12),
            Text('lagu',
                style: TextStyle(
                    fontSize: 16, color: cs.onSurface.withOpacity(0.7))),
          ],
        ),
      ],
    );
  }
}

// Drum-roll wheel picker menggunakan ListWheelScrollView
class _WheelPicker extends StatefulWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelBuilder;

  const _WheelPicker({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
  });

  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.controller.initialItem;
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) {
      setState(() => _selectedIndex = widget.controller.selectedItem);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListWheelScrollView.useDelegate(
      controller: widget.controller,
      itemExtent: 52,
      physics: const FixedExtentScrollPhysics(),
      perspective: 0.002,
      diameterRatio: 2.5,
      overAndUnderCenterOpacity: 0.35,
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index >= widget.itemCount) return null;
          final isSelected = index == _selectedIndex;
          return AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: isSelected ? 26 : 18,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? cs.onSurface
                  : cs.onSurface.withOpacity(0.35),
            ),
            child: Center(child: Text(widget.labelBuilder(index))),
          );
        },
        childCount: widget.itemCount,
      ),
    );
  }
}

// Toggle button untuk mode Waktu / Lagu
class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}
