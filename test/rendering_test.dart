import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:libregeotag/models/geo_point.dart';
import 'package:libregeotag/models/location_fix.dart';
import 'package:libregeotag/models/memory_draft.dart';
import 'package:libregeotag/models/picked_photo.dart';
import 'package:libregeotag/rendering/memory_renderer.dart';

const _photo = PickedPhoto(path: '/tmp/photo.jpg', origin: PhotoOrigin.gallery);
const _location = LocationFix(
  point: GeoPoint(48.8584, 2.2945),
  source: LocationSource.manual,
);

/// The "photograph" every test paints: one flat colour, so a pixel tells us
/// exactly what the renderer did to it.
const _source = Color(0xFF3366AA);

Future<ui.Image> _sourceImage(WidgetTester tester, {int width = 400}) async {
  final image = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), 300),
      Paint()..color = _source,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, 300);
    picture.dispose();
    return image;
  });
  return image!;
}

Future<ui.Image> _render(
  WidgetTester tester,
  MemoryDraft draft,
  ui.Image photo, {
  int width = 400,
}) async {
  final height = (width * photo.height / photo.width).round();
  final image = await tester.runAsync(() async {
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
    return image;
  });
  return image!;
}

Future<Color> _pixel(WidgetTester tester, ui.Image image, int x, int y) async {
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final offset = (y * image.width + x) * 4;
  final bytes = data!;
  return Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}

void main() {
  testWidgets('the overlay leaves the top of the photograph alone', (
    tester,
  ) async {
    final photo = await _sourceImage(tester);
    final image = await _render(
      tester,
      MemoryDraft(
        photo: _photo,
        location: _location,
        address: 'Trafalgar Square, London',
        takenAt: DateTime(2023, 7, 15),
      ),
      photo,
    );

    expect(await _pixel(tester, image, 200, 8), _source);
  });

  testWidgets('the overlay darkens the bottom so the text can be read', (
    tester,
  ) async {
    final photo = await _sourceImage(tester);
    final image = await _render(
      tester,
      MemoryDraft(
        photo: _photo,
        location: _location,
        address: 'Trafalgar Square, London',
        takenAt: DateTime(2023, 7, 15),
      ),
      photo,
    );

    final corner = await _pixel(tester, image, 396, 296);
    expect(corner.r, lessThan(_source.r));
    expect(corner.g, lessThan(_source.g));
    expect(corner.b, lessThan(_source.b));
  });

  testWidgets('an empty overlay is just the photograph', (tester) async {
    final photo = await _sourceImage(tester);
    final image = await _render(
      tester,
      const MemoryDraft(photo: _photo),
      photo,
    );

    expect(await _pixel(tester, image, 396, 296), _source);
  });

  testWidgets('the postcard surrounds the photograph with paper', (
    tester,
  ) async {
    final photo = await _sourceImage(tester);
    final image = await _render(
      tester,
      MemoryDraft(
        photo: _photo,
        template: MemoryTemplate.postcard,
        location: _location,
        address: 'Trafalgar Square, London',
      ),
      photo,
    );

    final corner = await _pixel(tester, image, 2, 2);
    expect(corner, isNot(_source));
    expect(corner.a, 1.0);
    expect(await _pixel(tester, image, 200, 120), _source);
  });

  testWidgets('a long postcard caption does not cover the photograph', (
    tester,
  ) async {
    final photo = await _sourceImage(tester);
    final image = await _render(
      tester,
      MemoryDraft(
        photo: _photo,
        template: MemoryTemplate.postcard,
        location: _location,
        address:
            'The long road along the river, past the old mill and the bridge, '
            'where the path turns north',
        note:
            'We walked here for an hour and stopped to watch the water, then '
            'carried on towards the town',
        takenAt: DateTime(2023, 7, 15),
      ),
      photo,
    );

    expect(await _pixel(tester, image, 200, 100), _source);
  });

  testWidgets('both templates survive a very small canvas', (tester) async {
    final photo = await _sourceImage(tester);

    for (final template in MemoryTemplate.values) {
      final image = await _render(
        tester,
        MemoryDraft(
          photo: _photo,
          template: template,
          location: _location,
          address: 'Trafalgar Square, London',
          note: 'A walk in the rain',
          takenAt: DateTime(2023, 7, 15),
        ),
        photo,
        width: 60,
      );

      expect(image.width, 60);
    }
  });
}
