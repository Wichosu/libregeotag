/// Where a photograph came from.
enum PhotoOrigin {
  camera,
  gallery,

  /// Used when the source cannot be determined, for example a photograph
  /// recovered after Android killed the app during picking.
  unknown;

  String get label => switch (this) {
    PhotoOrigin.camera => 'Camera',
    PhotoOrigin.gallery => 'Gallery',
    PhotoOrigin.unknown => 'your device',
  };
}

/// A photograph selected on the device.
///
/// [path] points at a copy the picker placed in the app's cache. The original
/// photograph is never opened for writing, and the copy is disposable.
class PickedPhoto {
  const PickedPhoto({required this.path, required this.origin});

  final String path;
  final PhotoOrigin origin;
}
