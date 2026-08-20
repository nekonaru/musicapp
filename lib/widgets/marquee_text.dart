import 'package:flutter/material.dart';

/// Teks yang tampil center diam kalau muat, dan otomatis bergeser (marquee)
/// bolak-balik kalau kepanjangan untuk lebar yang tersedia.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const MarqueeText(this.text, {super.key, this.style});

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _isRunning = false;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
      _isRunning = false;
    }
  }

  Future<void> _runMarquee(double maxScroll) async {
    if (_isRunning) return;
    _isRunning = true;
    while (mounted && _scrollController.hasClients) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scrollController.hasClients) break;
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 30).clamp(1500, 8000).toInt()),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scrollController.hasClients) break;
      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: (maxScroll * 30).clamp(1500, 8000).toInt()),
        curve: Curves.linear,
      );
    }
    _isRunning = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final overflows = textPainter.width > constraints.maxWidth;

        if (!overflows) {
          // Teks muat: tampil diam, center seperti biasa
          return Center(
            child: Text(widget.text, style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }

        // Teks kepanjangan: mulai animasi marquee setelah frame ini selesai
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _runMarquee(_scrollController.position.maxScrollExtent);
          }
        });

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
        );
      },
    );
  }
}
