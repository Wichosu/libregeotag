import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:libregeotag/export/export_options.dart';
import 'package:libregeotag/export/memory_exporter.dart';
import 'package:libregeotag/models/geo_point.dart';
import 'package:libregeotag/models/location_fix.dart';
import 'package:libregeotag/models/memory_draft.dart';
import 'package:libregeotag/models/picked_photo.dart';

const _photo = PickedPhoto(path: '/tmp/photo.jpg', origin: PhotoOrigin.gallery);
const _location = LocationFix(
  point: GeoPoint(48.8584, 2.2945),
  source: LocationSource.manual,
);

/// A flat colour, or flat colour plus noise so JPEG quality has something to
/// throw away.
Future<ui.Image> _source(
  WidgetTester tester, {
  int width = 400,
  int height = 300,
  bool noise = false,
}) async {
  final image = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF3366AA),
    );
    if (noise) {
      final random = Random(7);
      for (var i = 0; i < 3000; i++) {
        canvas.drawRect(
          ui.Rect.fromLTWH(
            random.nextDouble() * width,
            random.nextDouble() * height,
            3,
            3,
          ),
          ui.Paint()
            ..color = ui.Color.fromARGB(
              255,
              random.nextInt(256),
              random.nextInt(256),
              random.nextInt(256),
            ),
        );
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  });
  return image!;
}

Future<Uint8List> _export(
  WidgetTester tester,
  ui.Image photo,
  MemoryDraft draft,
  ExportOptions options,
) async {
  final bytes = await tester.runAsync(
    () => const MemoryExporter().render(draft, photo, options),
  );
  return bytes!;
}

const _captioned = MemoryDraft(
  photo: _photo,
  location: _location,
  address: 'Trafalgar Square, London',
  note: 'A walk in the evening light',
);

void main() {
  group('exportBaseName', () {
    test('uses the photograph date, so files sort with their picture', () {
      final draft = MemoryDraft(
        photo: _photo,
        takenAt: DateTime(2023, 7, 15, 14, 23),
      );

      expect(
        exportBaseName(draft, DateTime(2026, 11, 13, 9, 5)),
        'libregeotag-2023-07-15-1423',
      );
    });

    test('falls back to now when the photograph has no date', () {
      const draft = MemoryDraft(photo: _photo);

      expect(
        exportBaseName(draft, DateTime(2026, 11, 13, 9, 5)),
        'libregeotag-2026-11-13-0905',
      );
    });
  });

  group('exportDimensions', () {
    test('original keeps the photograph size', () {
      expect(exportDimensions(6000, 4000, ExportSize.original), (
        width: 6000,
        height: 4000,
      ));
    });

    test('caps the longest edge and keeps the aspect ratio', () {
      expect(exportDimensions(6000, 4000, ExportSize.small), (
        width: 2048,
        height: 1365,
      ));
      expect(exportDimensions(4000, 6000, ExportSize.small), (
        width: 1365,
        height: 2048,
      ));
    });

    test('never upscales a photograph smaller than the cap', () {
      expect(exportDimensions(400, 300, ExportSize.small), (
        width: 400,
        height: 300,
      ));
    });

    test('leaves a photograph exactly at the cap alone', () {
      expect(exportDimensions(4096, 1000, ExportSize.large), (
        width: 4096,
        height: 1000,
      ));
    });
  });

  testWidgets('a smaller size is actually rendered smaller', (tester) async {
    final photo = await _source(tester, width: 3000, height: 2000);
    final bytes = await _export(
      tester,
      photo,
      _captioned,
      const ExportOptions(format: ExportFormat.png, size: ExportSize.small),
    );

    final decoded = img.decodePng(bytes);
    expect(decoded!.width, 2048);
    expect(decoded.height, 1365);
  });

  testWidgets('PNG export keeps the photograph size', (tester) async {
    final photo = await _source(tester);
    final bytes = await _export(
      tester,
      photo,
      _captioned,
      const ExportOptions(format: ExportFormat.png),
    );

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 400);
    expect(decoded.height, 300);
  });

  testWidgets('JPEG export is a JPEG of the photograph size', (tester) async {
    final photo = await _source(tester);
    final bytes = await _export(
      tester,
      photo,
      _captioned,
      const ExportOptions(),
    );

    expect(bytes[0], 0xFF);
    expect(bytes[1], 0xD8);

    final decoded = img.decodeJpg(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 400);
    expect(decoded.height, 300);
  });

  testWidgets('a higher JPEG quality writes a larger file', (tester) async {
    final photo = await _source(tester, noise: true);

    final good = await _export(
      tester,
      photo,
      _captioned,
      const ExportOptions(quality: JpegQuality.good),
    );
    final maximum = await _export(
      tester,
      photo,
      _captioned,
      const ExportOptions(quality: JpegQuality.maximum),
    );

    expect(maximum.length, greaterThan(good.length));
  });

  testWidgets('the caption is part of the exported image', (tester) async {
    final photo = await _source(tester);

    final plain = await _export(
      tester,
      photo,
      const MemoryDraft(photo: _photo),
      const ExportOptions(),
    );
    final captioned = await _export(
      tester,
      photo,
      _captioned,
      const ExportOptions(),
    );

    expect(captioned, isNot(equals(plain)));
  });

  testWidgets('the postcard keeps the photograph size too', (tester) async {
    final photo = await _source(tester);
    final bytes = await _export(
      tester,
      photo,
      const MemoryDraft(photo: _photo, template: MemoryTemplate.postcard),
      const ExportOptions(),
    );

    final decoded = img.decodeJpg(bytes);
    expect(decoded!.width, 400);
    expect(decoded.height, 300);
  });
}
