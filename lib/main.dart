import 'package:flutter/widgets.dart';

import 'app.dart';
import 'services/geocoding_service.dart';
import 'services/location_service.dart';
import 'services/metadata_service.dart';
import 'services/photo_picker_service.dart';

void main() {
  runApp(
    LibreGeoTagApp(
      photoPicker: ImagePickerPhotoPicker(),
      metadataReader: const NativeExifMetadataReader(),
      locationService: const GeolocatorLocationService(),
      geocodingProvider: PhotonGeocodingProvider(),
    ),
  );
}
