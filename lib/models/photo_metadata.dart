import 'geo_point.dart';

/// What a photograph itself can tell us.
///
/// Every field is optional: a photo may carry no metadata at all, and some
/// sources — notably Android's Photo Picker — strip GPS before the app sees
/// the file.
class PhotoMetadata {
  const PhotoMetadata({this.takenAt, this.gps});

  static const empty = PhotoMetadata();

  /// When the photograph was taken, in the camera's local time.
  ///
  /// EXIF stores no time zone, so this must never be converted or assumed to
  /// be UTC.
  final DateTime? takenAt;

  /// Where the photograph was taken, if the file still carries it.
  final GeoPoint? gps;
}
