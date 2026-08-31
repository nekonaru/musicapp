import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const List<String> kAllLetters = [
  '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
  'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

class _PopupData {
  final String letter;
  final double globalY;
  const _PopupData(this.letter, this.globalY);
}

/// Scrollbar A-Z minimalis: garis tipis di kanan layar.
/// Popup huruf mengikuti posisi jari (Y), menghilang saat jari diangkat.
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
  final _scrollbarKey = GlobalKey();
  final _popupData = ValueNotifier<_PopupData?>(null);
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _removeOverlay();
    _popupData.dispose();
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

    // Hitung posisi Y global agar popup bisa mengikuti jari
    final RenderBox? box =
        _scrollbarKey.currentContext?.findRenderObject() as RenderBox?;
    final double globalY =
        box != null ? box.localToGlobal(local).dy : local.dy;

    if (_overlayEntry == null) _showOverlay();

    final current = _popupData.value;
    _popupData.value = _PopupData(t, globalY);

    if (current?.letter != t) {
      HapticFeedback.selectionClick();
      widget.onLetterSelected(t);
    }
  }

  void _showOverlay() {
    final scaleAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutBack));

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final screenH = MediaQuery.of(ctx).size.height;

        return ValueListenableBuilder<_PopupData?>(
          valueListenable: _popupData,
          builder: (_, data, __) {
            if (data == null) return const SizedBox.shrink();

            // Clamp agar tidak keluar layar
            final top = (data.globalY - 32).clamp(60.0, screenH - 80.0);

            return Positioned(
              right: 44,
              top: top,
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: scaleAnim,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                          bottomLeft: Radius.circular(30),
                          // bottomRight lancip seperti speech bubble mengarah kanan
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          data.letter,
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
      if (mounted) _popupData.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _scrollbarKey,
      width: 20,
      child: LayoutBuilder(builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (d) =>
              _onTouch(d.localPosition, constraints.maxHeight),
          onVerticalDragUpdate: (d) =>
              _onTouch(d.localPosition, constraints.maxHeight),
          onVerticalDragEnd: (_) => _onRelease(),
          onTapDown: (d) =>
              _onTouch(d.localPosition, constraints.maxHeight),
          onTapUp: (_) => _onRelease(),
          child: Center(
            child: Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.outlineVariant.withOpacity(0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}
