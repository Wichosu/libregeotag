import 'package:flutter_test/flutter_test.dart';

import 'package:libregeotag/models/geo_point.dart';
import 'package:libregeotag/models/location_fix.dart';
import 'package:libregeotag/models/memory_draft.dart';
import 'package:libregeotag/models/picked_photo.dart';

const _photo = PickedPhoto(path: '/tmp/photo.jpg', origin: PhotoOrigin.gallery);
const _location = LocationFix(
  point: GeoPoint(51.5074, -0.1278),
  source: LocationSource.exif,
);

void main() {
  group('MemoryDraft', () {
    test('prints the address when there is one', () {
      const draft = MemoryDraft(
        photo: _photo,
        location: _location,
        address: '  Trafalgar Square, London  ',
      );

      expect(draft.place, 'Trafalgar Square, London');
      expect(draft.hasAddress, isTrue);
    });

    test('falls back to the coordinates rather than print nothing', () {
      const draft = MemoryDraft(photo: _photo, location: _location);

      expect(draft.hasAddress, isFalse);
      expect(draft.place, '51.50740, -0.12780');
    });

    test('has no place without a location or an address', () {
      const draft = MemoryDraft(photo: _photo);

      expect(draft.place, isEmpty);
    });

    test('the date only counts when it is shown', () {
      final takenAt = DateTime(2023, 7, 15, 14, 23);

      expect(MemoryDraft(photo: _photo, takenAt: takenAt).hasCaption, isTrue);
      expect(
        MemoryDraft(
          photo: _photo,
          takenAt: takenAt,
          showDate: false,
        ).hasCaption,
        isFalse,
      );
    });

    test('a note alone is a caption', () {
      const draft = MemoryDraft(photo: _photo, note: 'A quiet morning');

      expect(draft.hasCaption, isTrue);
    });

    test('compares by value', () {
      final takenAt = DateTime(2023, 7, 15);
      final one = MemoryDraft(
        photo: _photo,
        location: _location,
        address: 'London',
        note: 'A walk',
        takenAt: takenAt,
      );
      final same = MemoryDraft(
        photo: _photo,
        location: _location,
        address: 'London',
        note: 'A walk',
        takenAt: takenAt,
      );

      expect(one, same);
      expect(one.hashCode, same.hashCode);
      expect(one, isNot(const MemoryDraft(photo: _photo)));
      expect(
        one,
        isNot(
          MemoryDraft(
            photo: _photo,
            location: _location,
            address: 'London',
            note: 'A walk',
            takenAt: takenAt,
            template: MemoryTemplate.postcard,
          ),
        ),
      );
    });
  });
}
