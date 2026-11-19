import 'package:material_ui/material_ui.dart';

import 'export/memory_exporter.dart';
import 'screens/home_screen.dart';
import 'services/gallery_service.dart';
import 'services/geocoding_service.dart';
import 'services/location_service.dart';
import 'services/metadata_service.dart';
import 'services/photo_picker_service.dart';
import 'services/share_service.dart';

/// A single warm, earthy seed keeps the chrome out of the way of the photograph.
const _seedColor = Color(0xFF8A6A4F);

class LibreGeoTagApp extends StatelessWidget {
  const LibreGeoTagApp({
    super.key,
    required this.photoPicker,
    required this.metadataReader,
    required this.locationService,
    required this.geocodingProvider,
    this.exporter = const MemoryExporter(),
    this.galleryService = const DeviceGalleryService(),
    this.shareService = const DeviceShareService(),
  });

  final PhotoPicker photoPicker;
  final PhotoMetadataReader metadataReader;
  final LocationService locationService;
  final GeocodingProvider geocodingProvider;
  final MemoryExporter exporter;
  final GalleryService galleryService;
  final ShareService shareService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibreGeoTag',
      debugShowCheckedModeBanner: false,
      theme: _themeFor(Brightness.light),
      darkTheme: _themeFor(Brightness.dark),
      home: HomeScreen(
        picker: photoPicker,
        metadataReader: metadataReader,
        locationService: locationService,
        geocodingProvider: geocodingProvider,
        exporter: exporter,
        galleryService: galleryService,
        shareService: shareService,
      ),
    );
  }
}

ThemeData _themeFor(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
