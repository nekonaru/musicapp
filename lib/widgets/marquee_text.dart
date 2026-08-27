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
  // _loopId: bertambah setiap kali teks ganti. Loop lama cek ID ini —
  // kalau sudah beda, loop lama langsung berhenti tanpa perlu flag terpisah.
  // Ini menghilangkan race-condition "dua loop jalan bareng sesaat" yang
  // terjadi kalau hanya pakai _isRunning = false di didUpdateWidget.
  int _loopId = 0;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _scrollController.hasClients) {
      _loopId++; // batalkan loop lama sebelum jump
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _runMarquee(double maxScroll, int myLoopId) async {
    // Loop ini hanya boleh jalan kalau myLoopId masih sama dengan _loopId saat ini.
    // Begitu teks ganti (_loopId naik), loop ini akan berhenti di cek berikutnya.
    while (mounted && _scrollController.hasClients && myLoopId == _loopId) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scrollController.hasClients || myLoopId != _loopId) break;
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 30).clamp(1500, 8000).toInt()),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scrollController.hasClients || myLoopId != _loopId) break;
      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: (maxScroll * 30).clamp(1500, 8000).toInt()),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _loopId++; // pastikan loop yang mungkin masih berjalan langsung berhenti
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

        // Teks kepanjangan: mulai animasi marquee setelah frame ini selesai.
        // Capture _loopId saat ini supaya hanya satu loop yang aktif per teks.
        final currentLoopId = _loopId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients && currentLoopId == _loopId) {
            _runMarquee(_scrollController.position.maxScrollExtent, currentLoopId);
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
