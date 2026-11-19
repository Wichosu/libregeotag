import 'package:flutter_test/flutter_test.dart';

import 'package:libregeotag/formatting.dart';
import 'package:libregeotag/models/geo_point.dart';

void main() {
  group('formatPhotoDate', () {
    test('formats a date without the time', () {
      expect(formatPhotoDate(DateTime(2023, 7, 15, 14, 23)), '15 July 2023');
    });

    test('formats single-digit days and December', () {
      expect(formatPhotoDate(DateTime(2024, 1, 2)), '2 January 2024');
      expect(formatPhotoDate(DateTime(2025, 12, 31)), '31 December 2025');
    });
  });

  group('formatPhotoDateTime', () {
    test('formats a date with zero-padded time', () {
      expect(
        formatPhotoDateTime(DateTime(2023, 7, 15, 14, 23)),
        '15 July 2023 at 14:23',
      );
    });

    test('pads single-digit hours and minutes', () {
      expect(
        formatPhotoDateTime(DateTime(2024, 1, 2, 9, 5)),
        '2 January 2024 at 09:05',
      );
    });

    test('formats midnight and December', () {
      expect(
        formatPhotoDateTime(DateTime(2025, 12, 31, 0, 0)),
        '31 December 2025 at 00:00',
      );
    });
  });

  group('GeoPoint', () {
    test('prints five decimals', () {
      expect(
        const GeoPoint(51.5074, -0.1278).coordinates,
        '51.50740, -0.12780',
      );
    });

    test('rejects coordinates out of range', () {
      expect(const GeoPoint(91, 0).isValid, isFalse);
      expect(const GeoPoint(0, 181).isValid, isFalse);
      expect(const GeoPoint(-90, -180).isValid, isTrue);
      expect(const GeoPoint(0, 0).isValid, isTrue);
    });

    test('rejects non-finite values', () {
      expect(const GeoPoint(double.nan, 0).isValid, isFalse);
      expect(const GeoPoint(double.infinity, 0).isValid, isFalse);
    });
  });
}
