import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/picked_photo.dart';

/// A problem the user can act on, phrased for display.
class PhotoPickException implements Exception {
  const PhotoPickException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Selecting a photograph. Abstract so screens can be tested without a
/// platform channel.
abstract class PhotoPicker {
  /// Returns null when the user cancels.
  Future<PickedPhoto?> pick(PhotoOrigin origin);

  /// Android may kill the app while the camera is open. On the next start the
  /// photograph is recoverable. Returns null when there is nothing to recover.
  Future<PickedPhoto?> recoverLost();
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pick(PhotoOrigin origin) async {
    try {
      final file = await _picker.pickImage(
        source: origin == PhotoOrigin.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // Ask for full metadata so the photograph's original date and GPS
        // survive picking. Phase 3 reads them.
        requestFullMetadata: true,
      );
      if (file == null) return null;
      return PickedPhoto(path: file.path, origin: origin);
    } on PlatformException catch (error) {
      throw PhotoPickException(_messageFor(error));
    }
  }

  @override
  Future<PickedPhoto?> recoverLost() async {
    if (!Platform.isAndroid) return null;

    try {
      final response = await _picker.retrieveLostData();
      final file = response.file;
      if (response.isEmpty || file == null) return null;
      return PickedPhoto(path: file.path, origin: PhotoOrigin.unknown);
    } on PlatformException {
      // Recovery is best effort; failing it must not block the app.
      return null;
    }
  }

  String _messageFor(PlatformException error) {
    return switch (error.code) {
      'camera_access_denied' =>
        'Camera access is denied. You can turn it on in system settings.',
      'photo_access_denied' =>
        'Photo access is denied. You can turn it on in system settings.',
      _ => 'The photo could not be opened.',
    };
  }
}
