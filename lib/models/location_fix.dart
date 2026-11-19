import 'geo_point.dart';

/// Where a chosen location came from. Shown to the user, never guessed.
enum LocationSource {
  /// A fix from the device's location services, taken on request.
  gps,

  /// Coordinates stored in the photograph's EXIF.
  exif,

  /// Typed in by the user.
  manual;

  String get label => switch (this) {
    LocationSource.gps => 'Current location',
    LocationSource.exif => 'From the photo',
    LocationSource.manual => 'Entered by you',
  };
}

/// The location a memory will carry.
class LocationFix {
  const LocationFix({
    required this.point,
    required this.source,
    this.accuracyMeters,
    this.cached = false,
  });

  /// Above this radius a location is too loose to name a place honestly.
  static const poorAccuracyMeters = 100.0;

  final GeoPoint point;
  final LocationSource source;

  /// Horizontal accuracy in metres, when the source reports one. EXIF and
  /// manual entry carry none.
  final double? accuracyMeters;

  /// True when the fix came from the platform's cache rather than a fresh
  /// reading, so it may describe somewhere the user has since left.
  final bool cached;

  bool get isImprecise =>
      accuracyMeters != null && accuracyMeters! > poorAccuracyMeters;

  /// "Current location · ±12 m", "Last known location · ±340 m".
  String get summary {
    final buffer = StringBuffer(cached ? 'Last known location' : source.label);
    final accuracy = accuracyMeters;
    if (accuracy != null) {
      buffer.write(' · ±${accuracy.round()} m');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is LocationFix &&
      other.point == point &&
      other.source == source &&
      other.accuracyMeters == accuracyMeters &&
      other.cached == cached;

  @override
  int get hashCode => Object.hash(point, source, accuracyMeters, cached);
}
