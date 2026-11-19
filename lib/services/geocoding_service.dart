import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/address.dart';
import '../models/geo_point.dart';

/// A geocoding problem the user can act on, phrased for display.
class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turning coordinates into an address. Abstract so the editor can be tested
/// without a network and so the provider can be replaced by a self-hosted one.
abstract class GeocodingProvider {
  /// Looks up the place at [point]. Only the coordinates are sent; no photo,
  /// note or device identifier leaves the app.
  Future<AddressParts> reverse(GeoPoint point);
}

/// Photon, the public OpenStreetMap geocoder. It needs no key and no account.
class PhotonGeocodingProvider implements GeocodingProvider {
  PhotonGeocodingProvider({
    http.Client? client,
    String baseUrl = 'https://photon.komoot.io',
    this.timeout = const Duration(seconds: 8),
    this.userAgent = defaultUserAgent,
  }) : _client = client ?? http.Client(),
       baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl;

  /// Photon's public server answers 403 to Dart's default agent
  /// (`Dart/3.14 (dart:io)`), so the app says who it is instead.
  static const defaultUserAgent =
      'LibreGeoTag/0.1 (https://github.com/wichosu/libregeotag)';

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;
  final String userAgent;

  /// Coordinates rounded to about eleven metres. Looking up the same spot twice
  /// in a session is common — changing the selected parts does not need the
  /// network.
  final Map<String, AddressParts> _cache = {};

  static const _unreachable =
      'Could not reach the address service. You can type the address yourself.';
  static const _busy =
      'The address service is busy right now. Try again in a moment, or type '
      'the address yourself.';
  static const _failed =
      'The address service did not answer properly. You can type the address '
      'yourself.';
  static const _notFound =
      'No address was found for this spot. You can type it yourself.';

  @override
  Future<AddressParts> reverse(GeoPoint point) async {
    final key =
        '${point.latitude.toStringAsFixed(4)},'
        '${point.longitude.toStringAsFixed(4)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final uri = Uri.parse('$baseUrl/reverse').replace(
      queryParameters: {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'limit': '1',
      },
    );

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'User-Agent': userAgent})
          .timeout(timeout);
    } on TimeoutException {
      throw const GeocodingException(_unreachable);
    } on SocketException {
      throw const GeocodingException(_unreachable);
    } on http.ClientException {
      throw const GeocodingException(_unreachable);
    }

    if (response.statusCode == 429) throw const GeocodingException(_busy);
    if (response.statusCode != 200) throw const GeocodingException(_failed);

    final AddressParts parts;
    try {
      parts = _parse(response.body);
    } on FormatException {
      throw const GeocodingException(_failed);
    }

    _cache[key] = parts;
    return parts;
  }

  AddressParts _parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Not a GeoJSON object');
    }

    final features = decoded['features'];
    if (features is! List || features.isEmpty) {
      throw const GeocodingException(_notFound);
    }

    final feature = features.first;
    final properties = feature is Map ? feature['properties'] : null;
    if (properties is! Map<String, dynamic>) {
      throw const GeocodingException(_notFound);
    }

    final parts = AddressParts.fromPhoton(properties);
    if (parts.isEmpty) throw const GeocodingException(_notFound);
    return parts;
  }
}
