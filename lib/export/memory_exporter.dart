import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../models/memory_draft.dart';
import '../rendering/memory_renderer.dart';
import 'export_options.dart';

/// Turns a draft into the bytes of a finished image.
///
/// The painting is the preview's painting, at the photograph's own pixel size
/// unless [ExportOptions.size] caps it: the preview is the export shown small,
/// so there is no second layout that could disagree with the file.
class MemoryExporter {
  const MemoryExporter();

  Future<Uint8List> render(
    MemoryDraft draft,
    ui.Image photo,
    ExportOptions options,
  ) async {
    final size = exportDimensions(photo.width, photo.height, options.size);
    final width = size.width;
    final height = size.height;

    final recorder = ui.PictureRecorder();
    paintMemory(
      Canvas(recorder),
      Size(width.toDouble(), height.toDouble()),
      draft,
      photo,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();

    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw const ExportException('The image could not be prepared.');
    }

    final png = data.buffer.asUint8List();
    if (options.format == ExportFormat.png) return png;

    // JPEG encoding is pure Dart and the slow part on a large photograph, so it
    // runs off the UI isolate; rendering has to stay here because it uses
    // dart:ui.
    return compute(_encodeJpeg, (
      png,
      options.quality.value,
    ), debugLabel: 'libregeotag jpeg');
  }
}

Uint8List _encodeJpeg((Uint8List, int) input) {
  final (png, quality) = input;
  final decoded = img.decodePng(png);
  if (decoded == null) {
    throw const ExportException('The image could not be encoded.');
  }
  return img.encodeJpg(decoded, quality: quality);
}

/// The file name without an extension: `libregeotag-2023-07-15-1423`.
///
/// The photograph's own date is used when it has one, so the file sorts next to
/// the picture it came from rather than next to the day it was made.
String exportBaseName(MemoryDraft draft, DateTime now) {
  final stamp = draft.takenAt ?? now;
  String two(int value) => value.toString().padLeft(2, '0');

  return 'libregeotag-${stamp.year}-${two(stamp.month)}-${two(stamp.day)}'
      '-${two(stamp.hour)}${two(stamp.minute)}';
}

/// Something went wrong while the image was being made.
class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
