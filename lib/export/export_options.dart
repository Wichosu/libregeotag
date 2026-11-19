import 'dart:math' as math;

/// The file types a memory can be written as.
enum ExportFormat {
  jpeg,
  png;

  String get label => switch (this) {
    ExportFormat.jpeg => 'JPEG',
    ExportFormat.png => 'PNG',
  };

  String get extension => switch (this) {
    ExportFormat.jpeg => 'jpg',
    ExportFormat.png => 'png',
  };

  String get mimeType => switch (this) {
    ExportFormat.jpeg => 'image/jpeg',
    ExportFormat.png => 'image/png',
  };

  String get description => switch (this) {
    ExportFormat.jpeg => 'Smaller files, fine for sharing.',
    ExportFormat.png => 'Lossless, larger files.',
  };
}

/// JPEG compression levels offered. PNG is lossless and ignores this.
enum JpegQuality {
  good(80, 'Good'),
  high(90, 'High'),
  maximum(100, 'Maximum');

  const JpegQuality(this.value, this.label);

  final int value;
  final String label;
}

/// How large the written file may be.
///
/// Downscaling happens before painting, so it caps the memory the renderer
/// needs as well as the file size: a 48 MP photograph otherwise needs about
/// 190 MB of pixels before any encoding starts.
enum ExportSize {
  original('Original', null),
  large('Large', 4096),
  small('Small', 2048);

  const ExportSize(this.label, this.longestEdge);

  final String label;

  /// The longest edge in pixels, or null to keep the photograph's own size.
  final int? longestEdge;
}

/// The pixel size a file will have: the photograph's own, or its longest edge
/// capped to [size] with the aspect ratio kept.
///
/// A photograph already smaller than the cap is left alone — upscaling would
/// only invent pixels.
({int width, int height}) exportDimensions(
  int width,
  int height,
  ExportSize size,
) {
  final edge = size.longestEdge;
  if (edge == null) return (width: width, height: height);

  final longest = math.max(width, height);
  if (longest <= edge) return (width: width, height: height);

  final scale = edge / longest;
  final short = math.max(1, (math.min(width, height) * scale).round());
  return width >= height
      ? (width: edge, height: short)
      : (width: short, height: edge);
}

/// How one exported file should be written.
class ExportOptions {
  const ExportOptions({
    this.format = ExportFormat.jpeg,
    this.quality = JpegQuality.high,
    this.size = ExportSize.original,
  });

  final ExportFormat format;
  final JpegQuality quality;
  final ExportSize size;
}
