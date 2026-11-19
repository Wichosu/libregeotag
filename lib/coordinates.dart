import 'models/geo_point.dart';

/// Parses coordinates typed by hand.
///
/// Accepts decimal degrees separated by a comma, semicolon or spaces, in
/// latitude-first order: `51.5074, -0.1278`. Returns null for anything else,
/// including values outside the valid range — the caller decides how to
/// explain that.
///
/// Degrees/minutes/seconds are deliberately not accepted: the format is
/// ambiguous to parse confidently, and the coordinate readout elsewhere in the
/// app is decimal, so it can simply be copied.
GeoPoint? parseCoordinates(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'[()\[\]]'), '');
  if (cleaned.isEmpty) return null;

  final parts = cleaned
      .split(RegExp(r'[,;\s]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length != 2) return null;

  final latitude = double.tryParse(parts[0]);
  final longitude = double.tryParse(parts[1]);
  if (latitude == null || longitude == null) return null;

  final point = GeoPoint(latitude, longitude);
  return point.isValid ? point : null;
}
