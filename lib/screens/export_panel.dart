import 'package:material_ui/material_ui.dart';

import '../export/export_options.dart';

/// The controls for turning the preview into a file.
///
/// It owns no state: the editor decides what the options are and what happened
/// last, so the panel stays a plain description of the current choice.
class ExportPanel extends StatelessWidget {
  const ExportPanel({
    super.key,
    required this.width,
    required this.height,
    required this.format,
    required this.quality,
    required this.size,
    required this.busy,
    required this.message,
    required this.failed,
    required this.onFormatChanged,
    required this.onQualityChanged,
    required this.onSizeChanged,
    required this.onSave,
    required this.onShare,
  });

  /// Pixel size of the decoded photograph, or null while it is still loading.
  final int? width;
  final int? height;

  final ExportFormat format;
  final JpegQuality quality;
  final ExportSize size;
  final bool busy;

  /// The result of the last save or share, if any.
  final String? message;
  final bool failed;

  final ValueChanged<ExportFormat> onFormatChanged;
  final ValueChanged<JpegQuality> onQualityChanged;
  final ValueChanged<ExportSize> onSizeChanged;
  final VoidCallback onSave;
  final VoidCallback onShare;

  /// What the chosen size means for this photograph, in pixels.
  String _sizeLine() {
    final width = this.width;
    final height = this.height;
    if (width == null || height == null) {
      return 'Preparing the photograph…';
    }

    final output = exportDimensions(width, height, size);
    final unchanged = output.width == width && output.height == height;

    if (size == ExportSize.original || unchanged) {
      return 'Full size — ${output.width} × ${output.height} px.';
    }
    return 'Longest edge ${size.longestEdge} px — '
        '${output.width} × ${output.height} px.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.bodySmall?.copyWith(color: muted);
    final ready = width != null && height != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<ExportFormat>(
          segments: [
            for (final value in ExportFormat.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {format},
          showSelectedIcon: false,
          onSelectionChanged: busy
              ? null
              : (selection) => onFormatChanged(selection.first),
        ),
        const SizedBox(height: 10),
        Text(format.description, style: small),
        if (format == ExportFormat.jpeg) ...[
          const SizedBox(height: 18),
          SegmentedButton<JpegQuality>(
            segments: [
              for (final value in JpegQuality.values)
                ButtonSegment(value: value, label: Text(value.label)),
            ],
            selected: {quality},
            showSelectedIcon: false,
            onSelectionChanged: busy
                ? null
                : (selection) => onQualityChanged(selection.first),
          ),
          const SizedBox(height: 10),
          Text('Quality ${quality.value} of 100.', style: small),
        ],
        const SizedBox(height: 18),
        SegmentedButton<ExportSize>(
          segments: [
            for (final value in ExportSize.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {size},
          showSelectedIcon: false,
          onSelectionChanged: busy
              ? null
              : (selection) => onSizeChanged(selection.first),
        ),
        const SizedBox(height: 10),
        Text(_sizeLine(), style: small),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: ready && !busy ? onSave : null,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Save to gallery'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: ready && !busy ? onShare : null,
            icon: const Icon(Icons.ios_share_outlined, size: 18),
            label: const Text('Share'),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 18),
          const LinearProgressIndicator(),
          const SizedBox(height: 10),
          Text('Rendering — this can take a moment.', style: small),
        ],
        if (message != null) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                failed ? Icons.error_outline : Icons.check_circle_outline,
                size: 18,
                color: failed ? theme.colorScheme.error : muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message!,
                  key: const Key('export-message'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: failed ? theme.colorScheme.error : muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
