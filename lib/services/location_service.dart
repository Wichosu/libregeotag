import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';
import '../models/location_fix.dart';

/// A location problem the user can act on, phrased for display.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reading the device's position. Abstract so screens can be tested without
/// the platform, and so a different provider can replace geolocator later.
abstract class LocationService {
  /// Takes a single fix. Never starts a stream and never runs in the
  /// background. Throws [LocationException] when no usable fix is possible.
  Future<LocationFix> current();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  /// Long enough for a cold fix, short enough that the UI does not appear
  /// frozen indoors. System dialogs raised during the request count against
  /// it, so leave room for the user to answer them.
  static const _timeout = Duration(seconds: 20);

  /// A cached fix this recent is indistinguishable from a fresh one for naming
  /// a place, so it is used at once instead of making the user wait for GPS.
  static const _freshCacheAge = Duration(minutes: 2);

  /// A cached fix older than this describes somewhere the user has probably
  /// left. Better to say nothing than to name the wrong place.
  static const _maxCacheAge = Duration(minutes: 30);

  @override
  Future<LocationFix> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Location is off. Turn it on in system settings, or enter coordinates '
        'by hand.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location access is denied. You can allow it in system settings, or '
        'enter coordinates by hand.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location access is blocked. You can allow it in system settings, or '
        'enter coordinates by hand.',
      );
    }

    try {
      // The platform's own cache is often the best answer seconds after the
      // app opens; asking the radio for a new fix would only add a delay.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && !_isStale(cached, _freshCacheAge)) {
        return _fixFrom(cached, cached: false);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      );
      return _fixFrom(position, cached: false);
    } on TimeoutException {
      return _lastKnown();
    } on LocationServiceDisabledException {
      throw const LocationException(
        'Location is unavailable right now. Try again, or enter coordinates by '
        'hand.',
      );
    } on PlatformException {
      throw const LocationException(
        'Your location could not be read. Enter coordinates by hand.',
      );
    }
  }

  /// A recent cached fix is still better than none, as long as it says it is
  /// cached and it is not from another day.
  Future<LocationFix> _lastKnown() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null || _isStale(position, _maxCacheAge)) {
      throw const LocationException(
        'No recent location fix. Try again outdoors, or enter coordinates by '
        'hand.',
      );
    }
    return _fixFrom(position, cached: true);
  }

  bool _isStale(Position position, Duration limit) =>
      DateTime.now().difference(position.timestamp) > limit;

  LocationFix _fixFrom(Position position, {required bool cached}) {
    return LocationFix(
      point: GeoPoint(position.latitude, position.longitude),
      source: LocationSource.gps,
      // Zero means the platform has no accuracy estimate, not "perfect".
      accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
      cached: cached,
    );
  }
}
