import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:libregeotag/app.dart';
import 'package:libregeotag/export/export_options.dart';
import 'package:libregeotag/export/memory_exporter.dart';
import 'package:libregeotag/models/address.dart';
import 'package:libregeotag/models/geo_point.dart';
import 'package:libregeotag/models/location_fix.dart';
import 'package:libregeotag/models/memory_draft.dart';
import 'package:libregeotag/models/photo_metadata.dart';
import 'package:libregeotag/models/picked_photo.dart';
import 'package:libregeotag/services/gallery_service.dart';
import 'package:libregeotag/services/geocoding_service.dart';
import 'package:libregeotag/services/location_service.dart';
import 'package:libregeotag/services/metadata_service.dart';
import 'package:libregeotag/screens/memory_preview.dart';
import 'package:libregeotag/services/photo_picker_service.dart';
import 'package:libregeotag/services/share_service.dart';

/// A 1x1 PNG, enough for the editor to decode.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

late Directory _tempDir;
late String _photoPath;

class FakePicker implements PhotoPicker {
  FakePicker({this.photo, this.error, this.lostPhoto});

  PickedPhoto? photo;
  PhotoPickException? error;
  PickedPhoto? lostPhoto;
  final List<PhotoOrigin> calls = [];

  @override
  Future<PickedPhoto?> pick(PhotoOrigin origin) async {
    calls.add(origin);
    if (error != null) throw error!;
    return photo;
  }

  @override
  Future<PickedPhoto?> recoverLost() async => lostPhoto;
}

class FakeMetadataReader implements PhotoMetadataReader {
  FakeMetadataReader([this.metadata = PhotoMetadata.empty]);

  final PhotoMetadata metadata;
  String? lastPath;

  @override
  Future<PhotoMetadata> read(String path) async {
    lastPath = path;
    return metadata;
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService({this.fix, this.error});

  LocationFix? fix;
  LocationException? error;
  int calls = 0;

  @override
  Future<LocationFix> current() async {
    calls += 1;
    if (error != null) throw error!;
    return fix!;
  }
}

class FakeGeocodingProvider implements GeocodingProvider {
  FakeGeocodingProvider({this.parts, this.error});

  AddressParts? parts;
  GeocodingException? error;
  int calls = 0;
  GeoPoint? lastPoint;

  @override
  Future<AddressParts> reverse(GeoPoint point) async {
    calls += 1;
    lastPoint = point;
    if (error != null) throw error!;
    return parts!;
  }
}

class FakeExporter implements MemoryExporter {
  FakeExporter({this.error});

  ExportException? error;
  final List<ExportOptions> options = [];
  final List<MemoryDraft> drafts = [];

  @override
  Future<Uint8List> render(
    MemoryDraft draft,
    ui.Image photo,
    ExportOptions options,
  ) async {
    this.options.add(options);
    drafts.add(draft);
    if (error != null) throw error!;
    return Uint8List.fromList([0xFF, 0xD8, 0xFF]);
  }
}

class FakeGallery implements GalleryService {
  final List<Uint8List> saved = [];
  final List<String> names = [];
  GallerySaveException? error;

  @override
  Future<void> save(Uint8List bytes, {required String name}) async {
    if (error != null) throw error!;
    saved.add(bytes);
    names.add(name);
  }
}

class FakeShare implements ShareService {
  final List<String> names = [];
  final List<String> types = [];

  @override
  Future<void> share(
    Uint8List bytes, {
    required String name,
    required String mimeType,
  }) async {
    names.add(name);
    types.add(mimeType);
  }
}

const _london = GeoPoint(51.5074, -0.1278);

/// The shape Photon returns around the Eiffel Tower: district and city are both
/// "Paris".
const _parisParts = AddressParts(
  name: 'Madame Brasserie',
  street: 'Avenue Anatole France',
  housenumber: '5',
  locality: 'Gros-Caillou',
  district: 'Paris',
  city: 'Paris',
  state: 'Île-de-France',
  country: 'France',
  postcode: '75007',
);

const _fullParis =
    'Madame Brasserie, 5 Avenue Anatole France, Gros-Caillou, 75007 Paris, '
    'Île-de-France, France';

Widget _appWith(
  FakePicker picker, {
  PhotoMetadataReader? metadataReader,
  LocationService? locationService,
  GeocodingProvider? geocodingProvider,
  MemoryExporter? exporter,
  GalleryService? galleryService,
  ShareService? shareService,
}) {
  return LibreGeoTagApp(
    photoPicker: picker,
    metadataReader: metadataReader ?? FakeMetadataReader(),
    locationService: locationService ?? FakeLocationService(),
    geocodingProvider: geocodingProvider ?? FakeGeocodingProvider(),
    exporter: exporter ?? const MemoryExporter(),
    galleryService: galleryService ?? const DeviceGalleryService(),
    shareService: shareService ?? const DeviceShareService(),
  );
}

PickedPhoto _cameraPhoto() =>
    PickedPhoto(path: _photoPath, origin: PhotoOrigin.camera);

Future<void> _openEditor(
  WidgetTester tester, {
  PhotoMetadata metadata = PhotoMetadata.empty,
  FakeLocationService? locationService,
  FakeGeocodingProvider? geocodingProvider,
  MemoryExporter? exporter,
  GalleryService? galleryService,
  ShareService? shareService,
}) async {
  await tester.pumpWidget(
    _appWith(
      FakePicker(photo: _cameraPhoto()),
      metadataReader: FakeMetadataReader(metadata),
      locationService: locationService ?? FakeLocationService(),
      geocodingProvider: geocodingProvider ?? FakeGeocodingProvider(),
      exporter: exporter,
      galleryService: galleryService,
      shareService: shareService,
    ),
  );
  await tester.tap(find.text('Take a photo'));
  await tester.pumpAndSettle();
}

/// The editor is a long page; a tall viewport keeps every section on screen so
/// taps do not need scrolling.
Future<void> _openTall(
  WidgetTester tester, {
  PhotoMetadata metadata = PhotoMetadata.empty,
  FakeLocationService? locationService,
  FakeGeocodingProvider? geocodingProvider,
  MemoryExporter? exporter,
  GalleryService? galleryService,
  ShareService? shareService,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await _openEditor(
    tester,
    metadata: metadata,
    locationService: locationService,
    geocodingProvider: geocodingProvider,
    exporter: exporter,
    galleryService: galleryService,
    shareService: shareService,
  );
}

void main() {
  setUpAll(() {
    _tempDir = Directory.systemTemp.createTempSync('libregeotag_test');
    final file = File('${_tempDir.path}/photo.png');
    file.writeAsBytesSync(base64Decode(_pngBase64));
    _photoPath = file.path;
  });

  tearDownAll(() {
    if (_tempDir.existsSync()) _tempDir.deleteSync(recursive: true);
  });

  group('home', () {
    testWidgets('shows both photograph sources', (tester) async {
      await tester.pumpWidget(_appWith(FakePicker()));

      expect(find.text('LibreGeoTag'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
    });

    testWidgets('camera action picks from the camera and opens the editor', (
      tester,
    ) async {
      final picker = FakePicker(photo: _cameraPhoto());

      await tester.pumpWidget(_appWith(picker));
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(picker.calls, [PhotoOrigin.camera]);
      expect(find.text('New memory'), findsOneWidget);
      expect(find.text('From Camera'), findsOneWidget);
    });

    testWidgets('gallery action picks from the gallery', (tester) async {
      final picker = FakePicker(
        photo: PickedPhoto(path: _photoPath, origin: PhotoOrigin.gallery),
      );

      await tester.pumpWidget(_appWith(picker));
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();

      expect(picker.calls, [PhotoOrigin.gallery]);
      expect(find.text('From Gallery'), findsOneWidget);
    });

    testWidgets('cancelling keeps the user on the home screen', (tester) async {
      final picker = FakePicker();

      await tester.pumpWidget(_appWith(picker));
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('New memory'), findsNothing);
    });

    testWidgets('a denied permission is reported in a snack bar', (
      tester,
    ) async {
      final picker = FakePicker(
        error: const PhotoPickException('Camera access is denied.'),
      );

      await tester.pumpWidget(_appWith(picker));
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(find.text('Camera access is denied.'), findsOneWidget);
    });

    testWidgets('a photograph lost to Android app death is recovered', (
      tester,
    ) async {
      final picker = FakePicker(
        lostPhoto: PickedPhoto(path: _photoPath, origin: PhotoOrigin.unknown),
      );

      await tester.pumpWidget(_appWith(picker));
      await tester.pumpAndSettle();

      expect(find.text('New memory'), findsOneWidget);
      expect(find.text('From your device'), findsOneWidget);
    });

    testWidgets('editor can navigate back home', (tester) async {
      final picker = FakePicker(photo: _cameraPhoto());

      await tester.pumpWidget(_appWith(picker));
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Take a photo'), findsOneWidget);
    });
  });

  group('caption metadata', () {
    testWidgets('shows the capture date and takes the photo location', (
      tester,
    ) async {
      await _openEditor(
        tester,
        metadata: PhotoMetadata(
          takenAt: DateTime(2023, 7, 15, 14, 23),
          gps: _london,
        ),
      );

      expect(find.text('15 July 2023 at 14:23'), findsOneWidget);
      expect(find.text('51.50740, -0.12780'), findsOneWidget);
      expect(find.text('From the photo'), findsOneWidget);
    });

    testWidgets('says so when the photo carries no capture date', (
      tester,
    ) async {
      await _openEditor(tester);

      expect(find.text('No capture date in this photo'), findsOneWidget);
    });

    testWidgets('starts with no location when the photo has no GPS', (
      tester,
    ) async {
      await _openEditor(
        tester,
        metadata: PhotoMetadata(takenAt: DateTime(2024, 1, 2, 9, 5)),
      );

      expect(find.text('2 January 2024 at 09:05'), findsOneWidget);
      expect(find.text('No location yet'), findsOneWidget);
      expect(find.text('Use photo location'), findsNothing);
    });
  });

  group('location', () {
    testWidgets('a device fix replaces the photo location', (tester) async {
      final service = FakeLocationService(
        fix: const LocationFix(
          point: GeoPoint(48.8584, 2.2945),
          source: LocationSource.gps,
          accuracyMeters: 12,
        ),
      );

      await _openEditor(
        tester,
        metadata: PhotoMetadata(gps: _london),
        locationService: service,
      );

      expect(find.text('51.50740, -0.12780'), findsOneWidget);

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(service.calls, 1);
      expect(find.text('48.85840, 2.29450'), findsOneWidget);
      expect(find.text('Current location · ±12 m'), findsOneWidget);
    });

    testWidgets('warns when the fix is too loose to name a place', (
      tester,
    ) async {
      final service = FakeLocationService(
        fix: const LocationFix(
          point: GeoPoint(48.8584, 2.2945),
          source: LocationSource.gps,
          accuracyMeters: 340,
        ),
      );

      await _openEditor(tester, locationService: service);
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(find.text('Current location · ±340 m'), findsOneWidget);
      expect(find.textContaining('The signal is weak'), findsOneWidget);
    });

    testWidgets('a cached fix is labelled as last known', (tester) async {
      final service = FakeLocationService(
        fix: const LocationFix(
          point: GeoPoint(48.8584, 2.2945),
          source: LocationSource.gps,
          accuracyMeters: 30,
          cached: true,
        ),
      );

      await _openEditor(tester, locationService: service);
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(find.text('Last known location · ±30 m'), findsOneWidget);
    });

    testWidgets('a refused permission explains itself and keeps manual entry', (
      tester,
    ) async {
      final service = FakeLocationService(
        error: const LocationException(
          'Location access is denied. You can allow it in system settings, or '
          'enter coordinates by hand.',
        ),
      );

      await _openEditor(tester, locationService: service);
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Location access is denied'), findsOneWidget);
      expect(find.text('Enter coordinates'), findsOneWidget);
      expect(find.text('No location yet'), findsOneWidget);
    });

    testWidgets('coordinates can be typed in by hand', (tester) async {
      await _openEditor(tester);

      await tester.tap(find.text('Enter coordinates'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '40.7580, -73.9855',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Use'));
      await tester.pumpAndSettle();

      expect(find.text('40.75800, -73.98550'), findsOneWidget);
      expect(find.text('Entered by you'), findsOneWidget);
    });

    testWidgets(
      'nonsense coordinates are rejected without closing the dialog',
      (tester) async {
        await _openEditor(tester);

        await tester.tap(find.text('Enter coordinates'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'somewhere nice',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Use'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Enter latitude and longitude'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('No location yet'), findsOneWidget);
      },
    );

    testWidgets('the photo location can be restored after a manual entry', (
      tester,
    ) async {
      await _openTall(tester, metadata: const PhotoMetadata(gps: _london));

      await tester.tap(find.text('Enter coordinates'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '40.7580, -73.9855',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Use'));
      await tester.pumpAndSettle();

      expect(find.text('Entered by you'), findsOneWidget);

      await tester.tap(find.text('Use photo location'));
      await tester.pumpAndSettle();

      expect(find.text('51.50740, -0.12780'), findsOneWidget);
      expect(find.text('From the photo'), findsOneWidget);
    });
  });

  group('address', () {
    testWidgets('waits for a location before offering an address', (
      tester,
    ) async {
      await _openTall(tester);

      expect(
        find.text('Choose a location above, then name the place.'),
        findsOneWidget,
      );
      expect(find.text('Look up address'), findsNothing);
    });

    testWidgets('looks up the place the photo was taken', (tester) async {
      final geocoder = FakeGeocodingProvider(parts: _parisParts);
      await _openTall(
        tester,
        metadata: const PhotoMetadata(gps: _london),
        geocodingProvider: geocoder,
      );

      await tester.tap(find.text('Look up address'));
      await tester.pumpAndSettle();

      expect(geocoder.calls, 1);
      expect(geocoder.lastPoint, _london);
      expect(find.text(_fullParis), findsOneWidget);
    });

    testWidgets('the text can be narrowed to one part', (tester) async {
      await _openTall(
        tester,
        metadata: const PhotoMetadata(gps: _london),
        geocodingProvider: FakeGeocodingProvider(parts: _parisParts),
      );

      await tester.tap(find.text('Look up address'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Country only'));
      await tester.pumpAndSettle();

      expect(find.text('France'), findsOneWidget);
      expect(find.text(_fullParis), findsNothing);
    });

    testWidgets('a part can be switched off by hand', (tester) async {
      await _openTall(
        tester,
        metadata: const PhotoMetadata(gps: _london),
        geocodingProvider: FakeGeocodingProvider(parts: _parisParts),
      );

      await tester.tap(find.text('Look up address'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Place name'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '5 Avenue Anatole France, Gros-Caillou, 75007 Paris, '
          'Île-de-France, France',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed lookup leaves the address writable by hand', (
      tester,
    ) async {
      await _openTall(
        tester,
        metadata: const PhotoMetadata(gps: _london),
        geocodingProvider: FakeGeocodingProvider(
          error: const GeocodingException(
            'Could not reach the address service. You can type the address '
            'yourself.',
          ),
        ),
      );

      await tester.tap(find.text('Look up address'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not reach'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('address-field')),
        'A bench by the river',
      );
      await tester.pumpAndSettle();

      expect(find.text('A bench by the river'), findsOneWidget);
      expect(find.textContaining('Could not reach'), findsOneWidget);
    });

    testWidgets('changing the location clears the address', (tester) async {
      final service = FakeLocationService(
        fix: const LocationFix(
          point: GeoPoint(48.8584, 2.2945),
          source: LocationSource.gps,
          accuracyMeters: 12,
        ),
      );
      await _openTall(
        tester,
        metadata: const PhotoMetadata(gps: _london),
        locationService: service,
        geocodingProvider: FakeGeocodingProvider(parts: _parisParts),
      );

      await tester.tap(find.text('Look up address'));
      await tester.pumpAndSettle();
      expect(find.text(_fullParis), findsOneWidget);

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(find.text('No address yet'), findsOneWidget);
      expect(find.text(_fullParis), findsNothing);
    });
  });

  group('note and date', () {
    testWidgets('a note is kept when the location changes', (tester) async {
      await _openTall(tester, metadata: const PhotoMetadata(gps: _london));

      await tester.enterText(
        find.byKey(const Key('note-field')),
        'A bench by the river',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter coordinates'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '40.7580, -73.9855',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Use'));
      await tester.pumpAndSettle();

      expect(find.text('A bench by the river'), findsOneWidget);
      expect(find.text('40.75800, -73.98550'), findsOneWidget);
    });

    testWidgets('the date can be switched off', (tester) async {
      await _openTall(
        tester,
        metadata: PhotoMetadata(takenAt: DateTime(2023, 7, 15, 14, 23)),
      );

      expect(find.text('Show 15 July 2023 on the image'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('a photo without a date offers no switch', (tester) async {
      await _openTall(tester);

      expect(
        find.text('This photo has no capture date, so no date will be shown.'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('template and preview', () {
    testWidgets('the template can be switched to postcard', (tester) async {
      await _openTall(tester);

      expect(find.text('Text laid over the photograph'), findsOneWidget);

      await tester.tap(find.text('Postcard'));
      await tester.pumpAndSettle();

      expect(find.text('A print with a caption below'), findsOneWidget);
    });

    testWidgets('the preview replaces the plain photo once decoded', (
      tester,
    ) async {
      await _openTall(tester);
      for (
        var i = 0;
        i < 5 && find.byType(MemoryPreview).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }

      expect(find.byType(MemoryPreview), findsOneWidget);
    });
  });

  group('export', () {
    /// Opens the editor and waits for the photograph to decode, which is what
    /// enables the export buttons.
    Future<void> openExport(
      WidgetTester tester, {
      FakeExporter? exporter,
      FakeGallery? gallery,
      FakeShare? share,
      PhotoMetadata metadata = PhotoMetadata.empty,
    }) async {
      await _openTall(
        tester,
        metadata: metadata,
        // Rendering for real would need the asynchronous decoder and encoder;
        // these tests are about what the editor does with the result.
        exporter: exporter ?? FakeExporter(),
        galleryService: gallery,
        shareService: share,
      );
      for (
        var i = 0;
        i < 5 && find.byType(MemoryPreview).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.scrollUntilVisible(
        find.text('Save to gallery'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }

    testWidgets('saving writes a named file to the gallery', (tester) async {
      final gallery = FakeGallery();
      final exporter = FakeExporter();
      await openExport(tester, exporter: exporter, gallery: gallery);

      await tester.tap(find.text('Save to gallery'));
      await tester.pumpAndSettle();

      expect(gallery.saved, hasLength(1));
      expect(gallery.names.single, startsWith('libregeotag-'));
      expect(find.text('Saved to your gallery.'), findsOneWidget);
      expect(exporter.options.single.format, ExportFormat.jpeg);
    });

    testWidgets('the file is named after the photograph date', (tester) async {
      final gallery = FakeGallery();
      await openExport(
        tester,
        gallery: gallery,
        metadata: PhotoMetadata(takenAt: DateTime(2023, 7, 15, 14, 23)),
      );

      await tester.tap(find.text('Save to gallery'));
      await tester.pumpAndSettle();

      expect(gallery.names.single, 'libregeotag-2023-07-15-1423');
    });

    testWidgets('the chosen format and quality reach the exporter', (
      tester,
    ) async {
      final exporter = FakeExporter();
      final gallery = FakeGallery();
      await openExport(tester, exporter: exporter, gallery: gallery);

      await tester.tap(find.text('PNG'));
      await tester.pumpAndSettle();
      expect(find.text('Maximum'), findsNothing);

      await tester.tap(find.text('JPEG'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maximum'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save to gallery'));
      await tester.pumpAndSettle();

      expect(exporter.options.single.format, ExportFormat.jpeg);
      expect(exporter.options.single.quality, JpegQuality.maximum);
    });

    testWidgets('the chosen size reaches the exporter', (tester) async {
      final exporter = FakeExporter();
      await openExport(tester, exporter: exporter, gallery: FakeGallery());

      await tester.tap(find.text('Small'));
      await tester.pumpAndSettle();
      // The test photograph is 1 × 1, so nothing is downscaled — and the panel
      // says so rather than pretending the file will be 2048 px.
      expect(find.text('Full size — 1 × 1 px.'), findsOneWidget);

      await tester.tap(find.text('Save to gallery'));
      await tester.pumpAndSettle();

      expect(exporter.options.single.size, ExportSize.small);
    });

    testWidgets('a refused gallery explains why', (tester) async {
      final gallery = FakeGallery()
        ..error = const GallerySaveException(
          'LibreGeoTag is not allowed to add images to your gallery.',
        );
      await openExport(tester, gallery: gallery);

      await tester.tap(find.text('Save to gallery'));
      await tester.pumpAndSettle();

      expect(
        find.text('LibreGeoTag is not allowed to add images to your gallery.'),
        findsOneWidget,
      );
      expect(gallery.saved, isEmpty);
    });

    testWidgets('a failed render is reported rather than swallowed', (
      tester,
    ) async {
      final exporter = FakeExporter(
        error: const ExportException('The image could not be prepared.'),
      );
      final gallery = FakeGallery();
      await openExport(tester, exporter: exporter, gallery: gallery);

      await tester.tap(find.text('Save to gallery'));
      await tester.pumpAndSettle();

      expect(find.text('The image could not be prepared.'), findsOneWidget);
      expect(gallery.saved, isEmpty);
    });

    testWidgets('sharing hands over a file name and type', (tester) async {
      final share = FakeShare();
      await openExport(tester, share: share);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(share.names.single, endsWith('.jpg'));
      expect(share.types.single, 'image/jpeg');
    });

    testWidgets('the result is cleared when the file would change', (
      tester,
    ) async {
      await openExport(tester, gallery: FakeGallery());

      await tester.tap(find.text('Save to gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Saved to your gallery.'), findsOneWidget);

      await tester.tap(find.text('PNG'));
      await tester.pumpAndSettle();

      expect(find.text('Saved to your gallery.'), findsNothing);
    });

    testWidgets('sharing PNG sends a png', (tester) async {
      final share = FakeShare();
      await openExport(tester, share: share);

      await tester.tap(find.text('PNG'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(share.names.single, endsWith('.png'));
      expect(share.types.single, 'image/png');
    });
  });

  group('about', () {
    /// The page is longer than the default test viewport; a tall one keeps the
    /// attribution and licence text built instead of scrolled out of existence.
    Future<void> openAbout(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_appWith(FakePicker()));
      await tester.tap(find.byKey(const Key('about-button')));
      await tester.pumpAndSettle();
    }

    testWidgets('the about screen credits the map data', (tester) async {
      await openAbout(tester);

      expect(find.text('Version 0.1.0'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
      expect(find.textContaining('MIT licence'), findsOneWidget);
      expect(find.textContaining('no analytics'), findsOneWidget);
    });

    testWidgets('the licences page opens from about', (tester) async {
      await openAbout(tester);

      await tester.tap(find.byKey(const Key('about-licences')));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}
