import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:libregeotag/models/geo_point.dart';
import 'package:libregeotag/services/geocoding_service.dart';

const _paris = GeoPoint(48.8584, 2.2945);

const _parisResponse = {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {
        'name': 'Madame Brasserie',
        'street': 'Avenue Anatole France',
        'housenumber': '5',
        'locality': 'Gros-Caillou',
        'district': 'Paris',
        'city': 'Paris',
        'state': 'Île-de-France',
        'country': 'France',
        'postcode': '75007',
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [2.2945757, 48.8584481],
      },
    },
  ],
};

PhotonGeocodingProvider _provider(
  MockClient client, {
  String baseUrl = 'https://photon.komoot.io',
}) {
  return PhotonGeocodingProvider(client: client, baseUrl: baseUrl);
}

void main() {
  test('parses the first feature Photon returns', () async {
    final provider = _provider(
      MockClient((_) async => http.Response(jsonEncode(_parisResponse), 200)),
    );

    final parts = await provider.reverse(_paris);

    expect(parts.city, 'Paris');
    expect(parts.streetLine, '5 Avenue Anatole France');
    expect(parts.postcode, '75007');
  });

  test('sends only the coordinates, as latitude and longitude', () async {
    late http.Request requested;
    final provider = _provider(
      MockClient((request) async {
        requested = request;
        return http.Response(jsonEncode(_parisResponse), 200);
      }),
    );

    await provider.reverse(_paris);

    expect(requested.url.path, '/reverse');
    expect(requested.url.queryParameters, {
      'lat': '48.8584',
      'lon': '2.2945',
      'limit': '1',
    });
  });

  test('identifies itself instead of using the blocked Dart agent', () async {
    late http.Request requested;
    final provider = _provider(
      MockClient((request) async {
        requested = request;
        return http.Response(jsonEncode(_parisResponse), 200);
      }),
    );

    await provider.reverse(_paris);

    expect(
      requested.headers['User-Agent'],
      PhotonGeocodingProvider.defaultUserAgent,
    );
    expect(requested.headers['User-Agent'], isNot(contains('dart:io')));
  });

  test('keeps a base URL that already carries a path', () async {
    late Uri requested;
    final provider = _provider(
      MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode(_parisResponse), 200);
      }),
      baseUrl: 'https://maps.example.org/photon/',
    );

    await provider.reverse(_paris);

    expect(
      requested.toString(),
      startsWith('https://maps.example.org/photon/reverse?'),
    );
  });

  test('the same spot is only asked for once', () async {
    var calls = 0;
    final provider = _provider(
      MockClient((_) async {
        calls += 1;
        return http.Response(jsonEncode(_parisResponse), 200);
      }),
    );

    await provider.reverse(_paris);
    await provider.reverse(_paris);

    expect(calls, 1);
  });

  test('a busy service says so', () async {
    final provider = _provider(MockClient((_) async => http.Response('', 429)));

    expect(
      () => provider.reverse(_paris),
      throwsA(
        isA<GeocodingException>().having(
          (error) => error.message,
          'message',
          contains('busy'),
        ),
      ),
    );
  });

  test('an empty result says nothing was found', () async {
    final provider = _provider(
      MockClient(
        (_) async => http.Response(
          jsonEncode({'type': 'FeatureCollection', 'features': []}),
          200,
        ),
      ),
    );

    expect(
      () => provider.reverse(_paris),
      throwsA(
        isA<GeocodingException>().having(
          (error) => error.message,
          'message',
          contains('No address was found'),
        ),
      ),
    );
  });

  test('a broken response is not mistaken for an address', () async {
    final provider = _provider(
      MockClient((_) async => http.Response('<html>nope</html>', 200)),
    );

    expect(() => provider.reverse(_paris), throwsA(isA<GeocodingException>()));
  });

  test('no connection is reported without losing the manual path', () async {
    final provider = _provider(
      MockClient((_) async => throw const SocketException('offline')),
    );

    expect(
      () => provider.reverse(_paris),
      throwsA(
        isA<GeocodingException>().having(
          (error) => error.message,
          'message',
          contains('type the address yourself'),
        ),
      ),
    );
  });
}
