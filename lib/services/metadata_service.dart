import 'package:flutter/services.dart';
import 'package:native_exif/native_exif.dart';

import '../models/geo_point.dart';
import '../models/photo_metadata.dart';

/// Reading metadata from a photograph file.
///
/// Abstract so screens can be tested without the platform channel.
abstract class PhotoMetadataReader {
  Future<PhotoMetadata> read(String path);
}

/// Reads EXIF with the platform's own parser (androidx ExifInterface,
/// ImageIO on iOS). Never writes: the photograph is only ever opened for
/// reading.
class NativeExifMetadataReader implements PhotoMetadataReader {
  const NativeExifMetadataReader();

  @override
  Future<PhotoMetadata> read(String path) async {
    Exif exif;
    try {
      exif = await Exif.fromPath(path);
    } on PlatformException {
      return PhotoMetadata.empty;
    } on MissingPluginException {
      return PhotoMetadata.empty;
    }

    try {
      return PhotoMetadata(takenAt: await _date(exif), gps: await _gps(exif));
    } finally {
      try {
        await exif.close();
      } on PlatformException {
        // Nothing to recover; the handle is discarded with the platform side.
      }
    }
  }

  Future<DateTime?> _date(Exif exif) async {
    try {
      final date = await exif.getOriginalDate();
      if (date == null) return null;
      // Defensive: malformed tags sometimes parse into nonsense years.
      if (date.year < 1826 || date.year > 2200) return null;
      return date;
    } on Exception {
      return null;
    }
  }

  Future<GeoPoint?> _gps(Exif exif) async {
    try {
      final latLong = await exif.getLatLong();
      if (latLong == null) return null;
      final point = GeoPoint(latLong.latitude, latLong.longitude);
      return point.isValid ? point : null;
    } on Exception {
      return null;
    }
  }
}
