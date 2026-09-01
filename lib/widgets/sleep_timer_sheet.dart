import 'dart:async';
import 'package:flutter/material.dart';
import '../services/player_service.dart';

enum _TimerMode { waktu, lagu }

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
  Timer? _ticker;

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;
  late final FixedExtentScrollController _songCtrl;

  static final List<int> _minuteOptions = List.generate(12, (i) => i * 5);
  static const int _defaultMinuteIndex = 3; // 15 menit
  static const int _defaultSongIndex = 4;   // 5 lagu

  @override
  void initState() {
    super.initState();
    _hourCtrl = FixedExtentScrollController(initialItem: 0);
    _minCtrl  = FixedExtentScrollController(initialItem: _defaultMinuteIndex);
    _songCtrl = FixedExtentScrollController(initialItem: _defaultSongIndex);

    // Jika timer sudah berjalan, tick setiap detik untuk update countdown
    if (_isTimerActive) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hourCtrl.dispose();
    _minCtrl.dispose();
    _songCtrl.dispose();
    super.dispose();
  }

  bool get _isTimerActive {
    final ps = PlayerService.instance;
    return ps.sleepTimerRemaining != null || ps.sleepSongsRemaining != null;
  }

  void _start() {
    final ps = PlayerService.instance;
    if (_mode == _TimerMode.waktu) {
      final hours   = _hourCtrl.selectedItem;
      final minutes = _minuteOptions[_minCtrl.selectedItem];
      final total   = hours * 60 + minutes;
      if (total == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set waktu lebih dari 0')),
        );
        return;
      }
      ps.setSleepTimer(Duration(minutes: total), finishCurrentSong: _finishSong);
    } else {
      ps.setSleepTimerBySongs(_songCtrl.selectedItem + 1);
    }
    Navigator.pop(context);
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ps = PlayerService.instance;
    final isActive = _isTimerActive;

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
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Judul
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Timer tidur',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),

          // Konten: timer aktif ATAU picker
          if (isActive)
            _buildActiveState(ps, cs)
          else
            _buildPickerState(cs),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // STATE AKTIF: Countdown + Berhenti
  // ──────────────────────────────────────────────────────────

  Widget _buildActiveState(PlayerService ps, ColorScheme cs) {
    final remaining  = ps.sleepTimerRemaining;
    final songsLeft  = ps.sleepSongsRemaining;
    final isTimeMode = remaining != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Countdown besar
        if (isTimeMode) ...[
          Text(
            _fmt(remaining!),
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text('tersisa', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 20),
          // Checkbox selesaikan lagu terakhir
          InkWell(
            onTap: () {
              setState(() => _finishSong = !_finishSong);
              // Update ke PlayerService jika ada cara (opsional)
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      value: _finishSong,
                      onChanged: (v) => setState(() => _finishSong = v ?? false),
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
        ] else ...[
          // Mode lagu
          Text(
            '${songsLeft ?? 0}',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('lagu tersisa',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
        const SizedBox(height: 24),

        // Tombol: Tutup | Berhenti
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
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  ps.cancelSleepTimer();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Timer tidur dihentikan'),
                        duration: Duration(seconds: 2)),
                  );
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.red[700],
                ),
                child: const Text('Berhenti',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // STATE PICKER: Atur timer baru
  // ──────────────────────────────────────────────────────────

  Widget _buildPickerState(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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

        // Picker wheel
        SizedBox(
          height: 160,
          child: _mode == _TimerMode.waktu
              ? _buildTimePicker(cs)
              : _buildSongPicker(cs),
        ),
        const SizedBox(height: 12),

        // Checkbox selesaikan lagu - hanya mode waktu
        if (_mode == _TimerMode.waktu)
          InkWell(
            onTap: () => setState(() => _finishSong = !_finishSong),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      value: _finishSong,
                      onChanged: (v) => setState(() => _finishSong = v ?? false),
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

        // Tutup | Mulai
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
      ],
    );
  }

  Widget _buildTimePicker(ColorScheme cs) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
            const SizedBox(height: 52),
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              child: _WheelPicker(
                controller: _hourCtrl,
                itemCount: 13,
                labelBuilder: (i) => '$i',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(':',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ),
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
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
            const SizedBox(height: 52),
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
          ],
        ),
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
                    fontSize: 16,
                    color: cs.onSurface.withOpacity(0.7))),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Drum-roll wheel picker
// ─────────────────────────────────────────────────────────────

class _WheelPicker extends StatefulWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  const _WheelPicker(
      {required this.controller,
      required this.itemCount,
      required this.labelBuilder});
  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  int _sel = 0;
  @override
  void initState() {
    super.initState();
    _sel = widget.controller.initialItem;
    widget.controller.addListener(_onScroll);
  }
  void _onScroll() {
    if (mounted) setState(() => _sel = widget.controller.selectedItem);
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
          final isSel = index == _sel;
          return AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: isSel ? 26 : 18,
              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              color: isSel ? cs.onSurface : cs.onSurface.withOpacity(0.35),
            ),
            child: Center(child: Text(widget.labelBuilder(index))),
          );
        },
        childCount: widget.itemCount,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Toggle Waktu/Lagu
// ─────────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _ModeButton(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.color});
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
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fungsi top-level untuk kompatibilitas dengan pemanggil lama (player_screen.dart).
Future<void> showSleepTimerSheet(BuildContext context) =>
    SleepTimerSheet.show(context);
