import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../formatting.dart';
import '../models/memory_draft.dart';

/// Colours are fixed rather than taken from the app theme: an exported image
/// must not change because the phone happens to be in dark mode.
const _paper = Color(0xFFFCF8F1);
const _ink = Color(0xFF2A241D);
const _mutedInk = Color(0xFF7A7065);
const _light = Color(0xFFFFFFFF);
const _lightMuted = Color(0xD9FFFFFF);

/// Paints [draft] onto [canvas], filling [size].
///
/// The preview and the export both call this — the preview at screen size, the
/// export at the photograph's own pixel size — so the two cannot drift apart.
/// Every measurement is a fraction of the canvas width, which is why it scales.
void paintMemory(Canvas canvas, Size size, MemoryDraft draft, ui.Image photo) {
  switch (draft.template) {
    case MemoryTemplate.overlay:
      _paintOverlay(canvas, size, draft, photo);
    case MemoryTemplate.postcard:
      _paintPostcard(canvas, size, draft, photo);
  }
}

/// The photograph edge to edge, with the caption over a scrim in the corner.
void _paintOverlay(
  Canvas canvas,
  Size size,
  MemoryDraft draft,
  ui.Image photo,
) {
  final width = size.width;
  final padding = width * 0.065;
  final maxWidth = width - padding * 2;
  final bottom = size.height - width * 0.075;

  var lines = _overlayLines(draft, width, maxWidth, 1);
  var height = _stackHeight(lines);

  // A long caption on a short photograph would climb out of the scrim, so the
  // type shrinks rather than the text losing its background.
  final room = size.height * 0.5;
  if (height > room) {
    final scale = room / height * 0.96;
    lines = _overlayLines(draft, width, maxWidth, scale);
    height = _stackHeight(lines);
  }

  _drawCover(canvas, size, photo);

  if (lines.isEmpty) return;

  final top = bottom - height;
  final fadeFrom = (top - width * 0.16).clamp(0.0, size.height);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, fadeFrom),
        Offset(0, size.height),
        const [Color(0x00000000), Color(0x33000000), Color(0xCC000000)],
        const [0.0, 0.4, 1.0],
      ),
  );

  var y = top;
  for (final line in lines) {
    line.painter.paint(canvas, Offset(padding, y));
    y += line.painter.height + line.gapAfter;
  }
}

List<_Line> _overlayLines(
  MemoryDraft draft,
  double width,
  double maxWidth,
  double scale,
) {
  final lines = <_Line>[];
  final place = draft.place;

  if (place.isNotEmpty) {
    lines.add(
      _Line(
        _text(
          place,
          fontSize: width * (draft.hasAddress ? 0.058 : 0.05) * scale,
          maxWidth: maxWidth,
          color: _light,
          weight: FontWeight.w600,
          maxLines: 4,
          shadow: true,
          tabular: !draft.hasAddress,
        ),
        gapAfter: width * 0.028 * scale,
      ),
    );
  }

  final note = draft.note.trim();
  if (note.isNotEmpty) {
    lines.add(
      _Line(
        _text(
          note,
          fontSize: width * 0.036 * scale,
          maxWidth: maxWidth,
          color: _lightMuted,
          maxLines: 3,
          shadow: true,
        ),
        gapAfter: width * 0.026 * scale,
      ),
    );
  }

  final takenAt = draft.takenAt;
  if (draft.hasDate && takenAt != null) {
    lines.add(
      _Line(
        _text(
          formatPhotoDate(takenAt).toUpperCase(),
          fontSize: width * 0.026 * scale,
          maxWidth: maxWidth,
          color: _lightMuted,
          letterSpacing: width * 0.006 * scale,
          shadow: true,
        ),
        gapAfter: 0,
      ),
    );
  }

  return lines;
}

/// The photograph printed inside a card, with the caption in the margin below.
void _paintPostcard(
  Canvas canvas,
  Size size,
  MemoryDraft draft,
  ui.Image photo,
) {
  final width = size.width;
  final margin = width * 0.05;
  final maxWidth = width - margin * 2;

  var lines = _postcardLines(draft, width, maxWidth, 1);
  var block = _stackHeight(lines);
  var band = lines.isEmpty ? margin : width * 0.1 + block;

  // The caption may not eat the photograph. On very wide frames the type
  // shrinks, but only so far; the clip below stops it spilling onto the image.
  final maxBand = (size.height - margin) * 0.45;
  if (block > 0 && band > maxBand) {
    final scale = ((maxBand - width * 0.1) / block * 0.96).clamp(0.35, 1.0);
    lines = _postcardLines(draft, width, maxWidth, scale);
    block = _stackHeight(lines);
    band = width * 0.1 + block;
  }
  band = band.clamp(0.0, maxBand);

  final photoRect = Rect.fromLTRB(
    margin,
    margin,
    width - margin,
    size.height - band,
  );

  canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
  if (photoRect.height > 0) {
    canvas.drawImageRect(
      photo,
      _coverSource(photo, photoRect.width / photoRect.height),
      photoRect,
      _photoPaint(),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        photoRect.left,
        photoRect.bottom,
        photoRect.width,
        (width * 0.0015).clamp(1.0, 2.0),
      ),
      Paint()..color = _ink.withValues(alpha: 0.14),
    );
  }

  if (lines.isEmpty) return;

  canvas.save();
  canvas.clipRect(Rect.fromLTRB(0, photoRect.bottom, width, size.height));
  var y = photoRect.bottom + width * 0.05;
  for (final line in lines) {
    line.painter.paint(canvas, Offset(margin, y));
    y += line.painter.height + line.gapAfter;
  }
  canvas.restore();
}

List<_Line> _postcardLines(
  MemoryDraft draft,
  double width,
  double maxWidth,
  double scale,
) {
  final lines = <_Line>[];
  final place = draft.place;

  if (place.isNotEmpty) {
    lines.add(
      _Line(
        _text(
          place,
          fontSize: width * 0.045 * scale,
          maxWidth: maxWidth,
          color: _ink,
          weight: FontWeight.w600,
          maxLines: 3,
          tabular: !draft.hasAddress,
        ),
        gapAfter: width * 0.018 * scale,
      ),
    );
  }

  final note = draft.note.trim();
  if (note.isNotEmpty) {
    lines.add(
      _Line(
        _text(
          note,
          fontSize: width * 0.033 * scale,
          maxWidth: maxWidth,
          color: _mutedInk,
          maxLines: 2,
        ),
        gapAfter: width * 0.02 * scale,
      ),
    );
  }

  final takenAt = draft.takenAt;
  if (draft.hasDate && takenAt != null) {
    lines.add(
      _Line(
        _text(
          formatPhotoDate(takenAt).toUpperCase(),
          fontSize: width * 0.024 * scale,
          maxWidth: maxWidth,
          color: _mutedInk,
          letterSpacing: width * 0.007 * scale,
        ),
        gapAfter: 0,
      ),
    );
  }

  return lines;
}

class _Line {
  const _Line(this.painter, {required this.gapAfter});

  final TextPainter painter;
  final double gapAfter;
}

/// The height of a stack of lines, gaps between them included, none after the
/// last.
double _stackHeight(List<_Line> lines) {
  var height = 0.0;
  for (var i = 0; i < lines.length; i++) {
    height += lines[i].painter.height;
    if (i < lines.length - 1) height += lines[i].gapAfter;
  }
  return height;
}

TextPainter _text(
  String text, {
  required double fontSize,
  required double maxWidth,
  required Color color,
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
  int maxLines = 1,
  bool shadow = false,
  bool tabular = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.25,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
        shadows: shadow
            ? [
                Shadow(
                  color: const Color(0x66000000),
                  blurRadius: fontSize * 0.4,
                  offset: Offset(0, fontSize * 0.08),
                ),
              ]
            : null,
      ),
    ),
    maxLines: maxLines,
    ellipsis: '…',
    textDirection: TextDirection.ltr,
  );
  painter.layout(maxWidth: maxWidth);
  return painter;
}

Paint _photoPaint() => Paint()
  ..filterQuality = FilterQuality.high
  ..isAntiAlias = true;

void _drawCover(Canvas canvas, Size size, ui.Image photo) {
  canvas.drawImageRect(
    photo,
    _coverSource(photo, size.aspectRatio),
    Offset.zero & size,
    _photoPaint(),
  );
}

/// The part of [photo] that fills a frame of [targetAspect] without distortion.
///
/// Preview and export use the photograph's own aspect ratio, so this crops
/// nothing there; it only matters if the frame ever changes shape.
Rect _coverSource(ui.Image photo, double targetAspect) {
  final width = photo.width.toDouble();
  final height = photo.height.toDouble();
  if (width <= 0 || height <= 0 || !targetAspect.isFinite) {
    return Rect.fromLTWH(0, 0, width, height);
  }

  if (width / height > targetAspect) {
    final cropped = height * targetAspect;
    return Rect.fromLTWH((width - cropped) / 2, 0, cropped, height);
  }
  final cropped = width / targetAspect;
  return Rect.fromLTWH(0, (height - cropped) / 2, width, cropped);
}
