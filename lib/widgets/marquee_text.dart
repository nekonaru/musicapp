import 'package:flutter/material.dart';

/// Teks yang otomatis bergeser (marquee) kalau kepanjangan untuk muat di layar.
/// Kalau teksnya cukup pendek, tampil diam seperti Text biasa.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const MarqueeText(this.text, {super.key, this.style, this.textAlign = TextAlign.center});

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartMarquee());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartMarquee());
    }
  }

  Future<void> _maybeStartMarquee() async {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return; // teks muat, tidak perlu bergerak

    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: (maxScroll * 30).clamp(1500, 8000).toInt()),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: (maxScroll * 30).clamp(1500, 8000).toInt()),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
    );
  }
}
