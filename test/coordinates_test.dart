import 'package:flutter_test/flutter_test.dart';

import 'package:libregeotag/coordinates.dart';
import 'package:libregeotag/models/geo_point.dart';

void main() {
  group('parseCoordinates', () {
    test('parses a comma-separated pair', () {
      expect(
        parseCoordinates('51.5074, -0.1278'),
        const GeoPoint(51.5074, -0.1278),
      );
    });

    test('tolerates extra whitespace and a semicolon', () {
      expect(
        parseCoordinates('  48.8584 ;  2.2945  '),
        const GeoPoint(48.8584, 2.2945),
      );
    });

    test('tolerates a space-separated pair', () {
      expect(
        parseCoordinates('48.8584 2.2945'),
        const GeoPoint(48.8584, 2.2945),
      );
    });

    test('keeps negative coordinates south and west', () {
      expect(
        parseCoordinates('-33.8688, -151.2093'),
        const GeoPoint(-33.8688, -151.2093),
      );
    });

    test('accepts the extremes', () {
      expect(parseCoordinates('-90, -180'), const GeoPoint(-90, -180));
      expect(parseCoordinates('90, 180'), const GeoPoint(90, 180));
    });

    test('rejects text', () {
      expect(parseCoordinates('somewhere nice'), isNull);
      expect(parseCoordinates(''), isNull);
      expect(parseCoordinates('   '), isNull);
    });

    test('rejects a single number', () {
      expect(parseCoordinates('51.5074'), isNull);
    });

    test('rejects three numbers', () {
      expect(parseCoordinates('51, 30, 26'), isNull);
    });

    test('rejects values out of range', () {
      expect(parseCoordinates('91, 0'), isNull);
      expect(parseCoordinates('0, 181'), isNull);
    });

    test('rejects malformed numbers', () {
      expect(parseCoordinates('51.5.4, 0'), isNull);
      expect(parseCoordinates('51,5, 0'), isNull);
      expect(parseCoordinates('51N, 0W'), isNull);
    });
  });
}
