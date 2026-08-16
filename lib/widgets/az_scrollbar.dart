import 'package:flutter/material.dart';

/// Strip huruf A-Z di sisi kanan layar. Seret jari di atasnya untuk
/// langsung lompat ke lagu yang judulnya diawali huruf tersebut.
class AzScrollbar extends StatefulWidget {
  final List<String> letters;
  final void Function(String letter) onLetterSelected;

  const AzScrollbar({super.key, required this.letters, required this.onLetterSelected});

  @override
  State<AzScrollbar> createState() => _AzScrollbarState();
}

class _AzScrollbarState extends State<AzScrollbar> {
  String? _activeLetter;

  void _handleTouch(Offset localPosition, double height) {
    final itemHeight = height / widget.letters.length;
    final index = (localPosition.dy / itemHeight).floor().clamp(0, widget.letters.length - 1);
    final letter = widget.letters[index];
    if (letter != _activeLetter) {
      setState(() => _activeLetter = letter);
      widget.onLetterSelected(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onVerticalDragUpdate: (details) => _handleTouch(details.localPosition, constraints.maxHeight),
          onVerticalDragStart: (details) => _handleTouch(details.localPosition, constraints.maxHeight),
          onVerticalDragEnd: (_) => setState(() => _activeLetter = null),
          child: Container(
            width: 22,
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.letters.map((l) {
                final isActive = l == _activeLetter;
                return Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 120),
                    style: TextStyle(
                      fontSize: isActive ? 13 : 9,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[500],
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
