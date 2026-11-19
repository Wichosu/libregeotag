/// One labelled part of an address, so each can be shown or hidden on its own.
enum AddressField {
  name('Place name'),
  street('Street'),
  locality('Area'),
  district('District'),
  city('City'),
  county('County'),
  state('Region'),
  country('Country'),
  postcode('Postcode');

  const AddressField(this.label);

  final String label;
}

/// The pieces of a reverse-geocoded address, kept apart so the user can choose
/// which ones appear on the image.
///
/// Every part is optional: Photon returns whatever OpenStreetMap knows, which
/// for a park may be a name and a country and nothing else.
class AddressParts {
  const AddressParts({
    this.name,
    this.street,
    this.housenumber,
    this.locality,
    this.district,
    this.city,
    this.county,
    this.state,
    this.country,
    this.postcode,
  });

  /// Reads the `properties` object of a Photon GeoJSON feature.
  factory AddressParts.fromPhoton(Map<String, dynamic> properties) {
    return AddressParts(
      name: _text(properties['name']),
      street: _text(properties['street']),
      housenumber: _text(properties['housenumber']),
      locality: _text(properties['locality']),
      district: _text(properties['district']),
      city: _text(properties['city']),
      county: _text(properties['county']),
      state: _text(properties['state']),
      country: _text(properties['country']),
      postcode: _text(properties['postcode']),
    );
  }

  final String? name;
  final String? street;
  final String? housenumber;

  /// The neighbourhood, e.g. "Gros-Caillou".
  final String? locality;
  final String? district;
  final String? city;
  final String? county;
  final String? state;
  final String? country;
  final String? postcode;

  /// Street and number as one line: "5 Avenue Anatole France".
  String? get streetLine {
    final streetName = _clean(street);
    final number = _clean(housenumber);
    if (streetName == null) return number;
    if (number == null) return streetName;
    return '$number $streetName';
  }

  String? valueOf(AddressField field) => switch (field) {
    AddressField.name => _clean(name),
    AddressField.street => streetLine,
    AddressField.locality => _clean(locality),
    AddressField.district => _clean(district),
    AddressField.city => _clean(city),
    AddressField.county => _clean(county),
    AddressField.state => _clean(state),
    AddressField.country => _clean(country),
    AddressField.postcode => _clean(postcode),
  };

  Set<AddressField> get availableFields => {
    for (final field in AddressField.values)
      if (valueOf(field) != null) field,
  };

  bool get isEmpty => availableFields.isEmpty;
}

/// A shortcut selection of address parts.
enum AddressPreset {
  full('Full'),
  city('City level'),
  region('Regional'),
  country('Country only');

  const AddressPreset(this.label);

  final String label;

  /// The fields this preset selects, falling back to a coarser part when the
  /// exact one is missing — a park has no `city`, but it does have a district.
  Set<AddressField> fieldsFor(AddressParts parts) {
    final available = parts.availableFields;
    return switch (this) {
      AddressPreset.full => available,
      AddressPreset.city => _firstOf(available, const [
        AddressField.city,
        AddressField.district,
        AddressField.locality,
        AddressField.name,
      ]),
      AddressPreset.region => _firstOf(available, const [
        AddressField.state,
        AddressField.county,
        AddressField.city,
      ]),
      AddressPreset.country => _firstOf(available, const [
        AddressField.country,
      ]),
    };
  }

  static Set<AddressField> _firstOf(
    Set<AddressField> available,
    List<AddressField> order,
  ) {
    for (final field in order) {
      if (available.contains(field)) return {field};
    }
    return const {};
  }
}

/// The order address parts are written in. The postcode is not here: it is
/// attached to the place it belongs to instead of standing alone.
const _displayOrder = [
  AddressField.name,
  AddressField.street,
  AddressField.locality,
  AddressField.district,
  AddressField.city,
  AddressField.county,
  AddressField.state,
  AddressField.country,
];

/// Joins the selected parts into one line, omitting what is missing and
/// repeating nothing.
///
/// Photon routinely reports the same name twice — `district` and `city` are
/// both "Paris" for most of the city — so a value that appears more than once
/// is kept at its most structural position only.
String composeAddress(AddressParts parts, Set<AddressField> fields) {
  final selected = <MapEntry<AddressField, String>>[];
  for (final field in _displayOrder) {
    if (!fields.contains(field)) continue;
    final value = parts.valueOf(field);
    if (value != null) selected.add(MapEntry(field, value));
  }

  final postcode = fields.contains(AddressField.postcode)
      ? parts.valueOf(AddressField.postcode)
      : null;
  if (selected.isEmpty) return postcode ?? '';

  final keptFieldFor = <String, AddressField>{};
  for (final entry in selected) {
    final key = _normalize(entry.value);
    final existing = keptFieldFor[key];
    if (existing == null || _rank(entry.key) > _rank(existing)) {
      keptFieldFor[key] = entry.key;
    }
  }
  final kept = selected
      .where((entry) => keptFieldFor[_normalize(entry.value)] == entry.key)
      .toList(growable: false);

  final lines = [for (final entry in kept) entry.value];
  if (postcode != null) {
    // The postcode belongs to the town, not to the neighbourhood that happens
    // to be written first.
    final anchor = _postcodeAnchor(kept);
    if (anchor >= 0) {
      lines[anchor] = '$postcode ${lines[anchor]}';
    } else {
      final before = kept.indexWhere(
        (entry) => const {
          AddressField.state,
          AddressField.county,
          AddressField.country,
        }.contains(entry.key),
      );
      lines.insert(before < 0 ? lines.length : before, postcode);
    }
  }

  return lines.join(', ');
}

int _postcodeAnchor(List<MapEntry<AddressField, String>> kept) {
  for (final field in const [
    AddressField.city,
    AddressField.district,
    AddressField.locality,
  ]) {
    final index = kept.indexWhere((entry) => entry.key == field);
    if (index >= 0) return index;
  }
  return -1;
}

/// Which duplicate to keep when the same name appears in several fields.
int _rank(AddressField field) => switch (field) {
  AddressField.city => 6,
  AddressField.district => 5,
  AddressField.county => 5,
  AddressField.locality => 4,
  AddressField.street => 3,
  AddressField.state => 2,
  AddressField.country => 1,
  AddressField.name => 0,
  AddressField.postcode => 0,
};

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _text(Object? value) {
  if (value is String) return _clean(value);
  if (value is num) return value.toString();
  return null;
}
