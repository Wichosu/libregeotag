import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../models/memory_draft.dart';
import '../rendering/memory_renderer.dart';

/// The memory as it will be saved.
///
/// Drawn by the same function the export uses, so what is on screen is what
/// lands in the file — only the size differs.
class MemoryPreview extends StatelessWidget {
  const MemoryPreview({super.key, required this.draft, required this.image});

  final MemoryDraft draft;
  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return AspectRatio(
      aspectRatio: image.width / image.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: _PreviewPainter(draft: draft, image: image),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({required this.draft, required this.image});

  final MemoryDraft draft;
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) =>
      paintMemory(canvas, size, draft, image);

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.draft != draft || oldDelegate.image != image;
}
