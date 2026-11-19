import 'dart:typed_data';

import 'package:gal/gal.dart';

/// Where finished memories are kept.
///
/// An interface so the editor can be tested without a gallery, and so the
/// storage plugin stays in one file.
abstract interface class GalleryService {
  /// Saves [bytes] as a new image. [name] carries no extension; the platform
  /// derives it from the bytes.
  Future<void> save(Uint8List bytes, {required String name});
}

/// Saves into the device's photo gallery, in a LibreGeoTag album.
class DeviceGalleryService implements GalleryService {
  const DeviceGalleryService();

  @override
  Future<void> save(Uint8List bytes, {required String name}) async {
    try {
      await Gal.putImageBytes(bytes, album: 'LibreGeoTag', name: name);
    } on GalException catch (error) {
      throw GallerySaveException(switch (error.type) {
        GalExceptionType.permissionDenied =>
          'LibreGeoTag is not allowed to add images to your gallery. '
              'You can change that in your device settings.',
        GalExceptionType.notEnoughSpace =>
          'There is not enough space on your device to save this image.',
        GalExceptionType.notSupportedFormat =>
          'Your device cannot save this image format.',
        GalExceptionType.unexpected =>
          'The image could not be saved. Please try again.',
      });
    }
  }
}

/// Saving failed for a reason worth showing the user.
class GallerySaveException implements Exception {
  const GallerySaveException(this.message);

  final String message;

  @override
  String toString() => message;
}
