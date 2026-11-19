import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Hands a finished memory to another app.
abstract interface class ShareService {
  /// Opens the system share sheet with one image. [name] includes the file
  /// extension.
  Future<void> share(
    Uint8List bytes, {
    required String name,
    required String mimeType,
  });
}

/// The platform share sheet.
class DeviceShareService implements ShareService {
  const DeviceShareService();

  @override
  Future<void> share(
    Uint8List bytes, {
    required String name,
    required String mimeType,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: name, mimeType: mimeType)],
        title: 'LibreGeoTag',
      ),
    );
  }
}
