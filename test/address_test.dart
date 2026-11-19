import 'package:flutter_test/flutter_test.dart';

import 'package:libregeotag/models/address.dart';

/// The shape Photon actually returned for the Eiffel Tower's neighbourhood:
/// `district` and `city` are both "Paris".
const _paris = AddressParts(
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

const _london = AddressParts(
  name: 'London',
  state: 'England',
  country: 'United Kingdom',
);

void main() {
  group('fromPhoton', () {
    test('reads the parts Photon returns', () {
      final parts = AddressParts.fromPhoton({
        'name': 'Madame Brasserie',
        'street': 'Avenue Anatole France',
        'housenumber': '5',
        'locality': 'Gros-Caillou',
        'district': 'Paris',
        'city': 'Paris',
        'state': 'Île-de-France',
        'country': 'France',
        'postcode': '75007',
        'osm_key': 'amenity',
      });

      expect(parts.name, 'Madame Brasserie');
      expect(parts.streetLine, '5 Avenue Anatole France');
      expect(parts.locality, 'Gros-Caillou');
      expect(parts.city, 'Paris');
      expect(parts.postcode, '75007');
      expect(parts.country, 'France');
    });

    test('treats missing and blank values as absent', () {
      final parts = AddressParts.fromPhoton({
        'name': '  ',
        'city': null,
        'country': 'France',
      });

      expect(parts.name, isNull);
      expect(parts.city, isNull);
      expect(parts.availableFields, {AddressField.country});
    });

    test('assembles a street line from a number alone', () {
      const parts = AddressParts(housenumber: '12');
      expect(parts.streetLine, '12');
    });
  });

  group('composeAddress', () {
    test('full drops the repeated district but keeps the city', () {
      final fields = AddressPreset.full.fieldsFor(_paris);

      expect(
        composeAddress(_paris, fields),
        'Madame Brasserie, 5 Avenue Anatole France, Gros-Caillou, '
        '75007 Paris, Île-de-France, France',
      );
    });

    test('a city result is not written twice', () {
      const paris = AddressParts(
        name: 'Paris',
        city: 'Paris',
        state: 'Île-de-France',
        country: 'France',
        postcode: '75000',
      );

      expect(
        composeAddress(paris, AddressPreset.full.fieldsFor(paris)),
        '75000 Paris, Île-de-France, France',
      );
    });

    test('the postcode joins whatever place it belongs to', () {
      final fields = {AddressField.city, AddressField.postcode};

      expect(composeAddress(_paris, fields), '75007 Paris');
    });

    test('a postcode with no city stands on its own', () {
      const parts = AddressParts(postcode: '75007', country: 'France');
      final fields = {AddressField.postcode, AddressField.country};

      expect(composeAddress(parts, fields), '75007, France');
    });

    test('missing parts are simply left out', () {
      final fields = AddressPreset.full.fieldsFor(_london);

      expect(
        composeAddress(_london, fields),
        'London, England, United Kingdom',
      );
    });

    test('nothing selected gives an empty line', () {
      expect(composeAddress(_paris, const {}), '');
    });
  });

  group('presets', () {
    test('full selects every part that exists', () {
      expect(AddressPreset.full.fieldsFor(_paris), _paris.availableFields);
    });

    test('city level is the city alone', () {
      expect(AddressPreset.city.fieldsFor(_paris), {AddressField.city});
    });

    test('city level falls back to the district when there is no city', () {
      const parts = AddressParts(district: 'Camden', country: 'United Kingdom');
      expect(AddressPreset.city.fieldsFor(parts), {AddressField.district});
    });

    test('city level falls back to the name of a city result', () {
      expect(AddressPreset.city.fieldsFor(_london), {AddressField.name});
    });

    test('regional prefers the state, then the county', () {
      expect(AddressPreset.region.fieldsFor(_paris), {AddressField.state});

      const parts = AddressParts(county: 'Greater London', country: 'UK');
      expect(AddressPreset.region.fieldsFor(parts), {AddressField.county});
    });

    test('country only is the country', () {
      expect(AddressPreset.country.fieldsFor(_paris), {AddressField.country});
    });

    test('a preset with nothing to select selects nothing', () {
      const parts = AddressParts(city: 'Paris');
      expect(AddressPreset.country.fieldsFor(parts), isEmpty);
    });

    test('preset labels are the ones shown in the UI', () {
      expect(AddressPreset.values.map((preset) => preset.label), [
        'Full',
        'City level',
        'Regional',
        'Country only',
      ]);
    });
  });
}
