import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const List<String> kAllLetters = [
  '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
  'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

/// Scrollbar A-Z minimalis: hanya menampilkan garis tipis di kanan layar.
/// Popup huruf muncul saat jari menyentuh/drag, hilang saat jari diangkat.
class AzScrollbar extends StatefulWidget {
  final Set<String> availableLetters;
  final void Function(String letter) onLetterSelected;

  const AzScrollbar({
    super.key,
    required this.availableLetters,
    required this.onLetterSelected,
  });

  @override
  State<AzScrollbar> createState() => _AzScrollbarState();
}

class _AzScrollbarState extends State<AzScrollbar>
    with SingleTickerProviderStateMixin {
  final _letterNotifier = ValueNotifier<String?>(null);
  late final AnimationController _fadeCtrl;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _letterNotifier.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String? _nearest(int idx) {
    for (int i = idx; i < kAllLetters.length; i++) {
      if (widget.availableLetters.contains(kAllLetters[i])) return kAllLetters[i];
    }
    for (int i = idx; i >= 0; i--) {
      if (widget.availableLetters.contains(kAllLetters[i])) return kAllLetters[i];
    }
    return null;
  }

  void _onTouch(Offset local, double height) {
    final idx = (local.dy / (height / kAllLetters.length))
        .floor()
        .clamp(0, kAllLetters.length - 1);
    final t = _nearest(idx);
    if (t == null) return;

    if (_overlayEntry == null) _showOverlay();

    if (_letterNotifier.value != t) {
      _letterNotifier.value = t;
      HapticFeedback.selectionClick();
      widget.onLetterSelected(t);
    }
  }

  void _showOverlay() {
    final animation = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    final scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutBack),
    );
    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: const Alignment(0.65, 0),
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _letterNotifier,
                    builder: (_, letter, __) {
                      if (letter == null) return const SizedBox.shrink();
                      return Material(
                        elevation: 6,
                        shadowColor: cs.primary.withOpacity(0.3),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                          bottomLeft: Radius.circular(30),
                        ),
                        color: cs.primary,
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                color: cs.onPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
    _fadeCtrl.forward();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onRelease() {
    _fadeCtrl.reverse().then((_) {
      _removeOverlay();
      if (mounted) _letterNotifier.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (d) => _onTouch(d.localPosition, constraints.maxHeight),
        onVerticalDragUpdate: (d) => _onTouch(d.localPosition, constraints.maxHeight),
        onVerticalDragEnd: (_) => _onRelease(),
        onTapDown: (d) => _onTouch(d.localPosition, constraints.maxHeight),
        onTapUp: (_) => _onRelease(),
        child: Container(
          width: 20,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    });
  }
}
