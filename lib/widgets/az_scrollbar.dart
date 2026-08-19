import 'package:flutter/material.dart';

const List<String> kAllLetters = ['#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
  'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];

/// Strip huruf A-Z (selalu penuh 27 slot: # + A-Z) di sisi kanan layar.
/// Huruf yang tidak ada lagunya ditampilkan pudar, tapi tetap bisa di-tap -
/// akan otomatis lompat ke huruf terdekat yang tersedia.
class AzScrollbar extends StatefulWidget {
  final Set<String> availableLetters;
  final void Function(String letter) onLetterSelected;

  const AzScrollbar({super.key, required this.availableLetters, required this.onLetterSelected});

  @override
  State<AzScrollbar> createState() => _AzScrollbarState();
}

class _AzScrollbarState extends State<AzScrollbar> {
  String? _activeLetter;

  String? _nearestAvailable(int index) {
    // Cari maju dulu, kalau tidak ada baru mundur
    for (int i = index; i < kAllLetters.length; i++) {
      if (widget.availableLetters.contains(kAllLetters[i])) return kAllLetters[i];
    }
    for (int i = index; i >= 0; i--) {
      if (widget.availableLetters.contains(kAllLetters[i])) return kAllLetters[i];
    }
    return null;
  }

  void _handleTouch(Offset localPosition, double height) {
    final itemHeight = height / kAllLetters.length;
    final index = (localPosition.dy / itemHeight).floor().clamp(0, kAllLetters.length - 1);
    final target = _nearestAvailable(index);
    if (target == null) return;
    if (target != _activeLetter) {
      setState(() => _activeLetter = target);
      widget.onLetterSelected(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (details) => _handleTouch(details.localPosition, constraints.maxHeight),
          onVerticalDragStart: (details) => _handleTouch(details.localPosition, constraints.maxHeight),
          onVerticalDragEnd: (_) => setState(() => _activeLetter = null),
          onTapDown: (details) => _handleTouch(details.localPosition, constraints.maxHeight),
          onTapUp: (_) => setState(() => _activeLetter = null),
          child: Container(
            width: 24,
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: kAllLetters.map((l) {
                final isActive = l == _activeLetter;
                final isAvailable = widget.availableLetters.contains(l);
                return Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 120),
                    style: TextStyle(
                      fontSize: isActive ? 13 : 9,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : (isAvailable ? Colors.grey[500] : Colors.grey[800]),
                    ),
                    child: Center(child: Text(l)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
