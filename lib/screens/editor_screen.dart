import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../coordinates.dart';
import '../export/export_options.dart';
import '../export/memory_exporter.dart';
import '../formatting.dart';
import '../models/address.dart';
import '../models/geo_point.dart';
import '../models/location_fix.dart';
import '../models/memory_draft.dart';
import '../models/photo_metadata.dart';
import '../models/picked_photo.dart';
import '../services/gallery_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/metadata_service.dart';
import '../services/share_service.dart';
import 'address_panel.dart';
import 'export_panel.dart';
import 'memory_preview.dart';
import 'note.dart';
import 'section_card.dart';

/// Editor shell for a single memory.
///
/// Everything the image is made of is chosen here; the preview at the top is
/// painted by the same code that will write the file.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.photo,
    required this.metadataReader,
    required this.locationService,
    required this.geocodingProvider,
    this.exporter = const MemoryExporter(),
    this.galleryService = const DeviceGalleryService(),
    this.shareService = const DeviceShareService(),
  });

  final PickedPhoto photo;
  final PhotoMetadataReader metadataReader;
  final LocationService locationService;
  final GeocodingProvider geocodingProvider;
  final MemoryExporter exporter;
  final GalleryService galleryService;
  final ShareService shareService;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  PhotoMetadata? _metadata;
  LocationFix? _location;
  String? _locationError;
  bool _locating = false;

  AddressParts? _address;
  Set<AddressField> _addressFields = const {};
  AddressPreset? _addressPreset;
  String? _addressError;
  bool _lookingUpAddress = false;
  final _addressController = TextEditingController();

  final _noteController = TextEditingController();
  bool _showDate = true;
  MemoryTemplate _template = MemoryTemplate.overlay;

  /// The photograph, decoded once. The preview paints from it, and the export
  /// will encode from it.
  ui.Image? _photoImage;
  bool _photoUnreadable = false;

  ExportFormat _exportFormat = ExportFormat.jpeg;
  JpegQuality _exportQuality = JpegQuality.high;
  ExportSize _exportSize = ExportSize.original;
  bool _exporting = false;
  String? _exportMessage;
  bool _exportFailed = false;

  // What the last export was made from. The message is only worth showing
  // while nothing has changed since, otherwise it describes a file that no
  // longer matches the preview.
  MemoryDraft? _exportedDraft;
  ExportFormat? _exportedFormat;
  JpegQuality? _exportedQuality;
  ExportSize? _exportedSize;

  @override
  void initState() {
    super.initState();
    // The draft is rebuilt from the controllers, so a keystroke has to repaint
    // the preview.
    _addressController.addListener(_rebuild);
    _noteController.addListener(_rebuild);
    _loadMetadata();
    _loadPhoto();
  }

  @override
  void dispose() {
    _addressController.removeListener(_rebuild);
    _noteController.removeListener(_rebuild);
    _addressController.dispose();
    _noteController.dispose();
    _photoImage?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPhoto() async {
    try {
      final bytes = await File(widget.photo.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _photoImage = frame.image);
    } catch (_) {
      // The header falls back to a plain view of the file, which reports the
      // problem itself.
      if (mounted) setState(() => _photoUnreadable = true);
    }
  }

  Future<void> _loadMetadata() async {
    final metadata = await widget.metadataReader.read(widget.photo.path);
    if (!mounted) return;

    setState(() {
      _metadata = metadata;
      // The photo's own coordinates are a sensible starting point — it was
      // taken there. They never overwrite a location the user chose while the
      // metadata was still loading.
      final gps = metadata.gps;
      if (gps != null && _location == null) {
        _location = LocationFix(point: gps, source: LocationSource.exif);
      }
    });
  }

  /// A fix from the device always wins over the photo's coordinates: the user
  /// is asking about right now, not about the moment of capture.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      final fix = await widget.locationService.current();
      if (!mounted) return;
      setState(() {
        _location = fix;
        _clearAddress();
      });
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _enterCoordinates() async {
    final point = await showDialog<GeoPoint>(
      context: context,
      builder: (context) => const _CoordinatesDialog(),
    );
    if (point == null || !mounted) return;

    setState(() {
      _location = LocationFix(point: point, source: LocationSource.manual);
      _locationError = null;
      _clearAddress();
    });
  }

  void _usePhotoLocation() {
    final gps = _metadata?.gps;
    if (gps == null) return;
    setState(() {
      _location = LocationFix(point: gps, source: LocationSource.exif);
      _locationError = null;
      _clearAddress();
    });
  }

  /// The address describes the location it was looked up for, so it cannot
  /// survive a change of location.
  void _clearAddress() {
    _address = null;
    _addressFields = const {};
    _addressPreset = null;
    _addressError = null;
    _addressController.clear();
  }

  Future<void> _lookUpAddress() async {
    final location = _location;
    if (location == null || _lookingUpAddress) return;

    setState(() {
      _lookingUpAddress = true;
      _addressError = null;
    });

    try {
      final parts = await widget.geocodingProvider.reverse(location.point);
      if (!mounted) return;
      // The location may have changed while the request was in flight.
      if (_location?.point != location.point) return;
      setState(() {
        _address = parts;
        _addressPreset = AddressPreset.full;
        _addressFields = AddressPreset.full.fieldsFor(parts);
        _addressController.text = composeAddress(parts, _addressFields);
      });
    } on GeocodingException catch (error) {
      if (!mounted) return;
      setState(() => _addressError = error.message);
    } finally {
      if (mounted) setState(() => _lookingUpAddress = false);
    }
  }

  void _applyPreset(AddressPreset preset) {
    final parts = _address;
    if (parts == null) return;
    setState(() {
      _addressPreset = preset;
      _addressFields = preset.fieldsFor(parts);
      _addressController.text = composeAddress(parts, _addressFields);
    });
  }

  void _toggleField(AddressField field) {
    final parts = _address;
    if (parts == null) return;
    final fields = {..._addressFields};
    if (!fields.remove(field)) fields.add(field);
    setState(() {
      // A hand-picked selection is no longer any one preset.
      _addressPreset = null;
      _addressFields = fields;
      _addressController.text = composeAddress(parts, fields);
    });
  }

  /// Everything the image is made of, rebuilt whenever anything changes.
  MemoryDraft get _draft => MemoryDraft(
    photo: widget.photo,
    template: _template,
    location: _location,
    address: _addressController.text,
    note: _noteController.text,
    takenAt: _metadata?.takenAt,
    showDate: _showDate,
  );

  ExportOptions get _exportOptions => ExportOptions(
    format: _exportFormat,
    quality: _exportQuality,
    size: _exportSize,
  );

  String? get _visibleExportMessage =>
      _exportedDraft == _draft &&
          _exportedFormat == _exportFormat &&
          _exportedQuality == _exportQuality &&
          _exportedSize == _exportSize
      ? _exportMessage
      : null;

  Future<void> _saveToGallery() async {
    final image = _photoImage;
    if (image == null || _exporting) return;

    setState(() {
      _exporting = true;
      _exportMessage = null;
      _exportFailed = false;
    });

    final draft = _draft;
    final options = _exportOptions;

    try {
      final bytes = await widget.exporter.render(draft, image, options);
      await widget.galleryService.save(
        bytes,
        name: exportBaseName(draft, DateTime.now()),
      );
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _exportMessage = 'Saved to your gallery.';
        _exportedDraft = draft;
        _exportedFormat = options.format;
        _exportedQuality = options.quality;
        _exportedSize = options.size;
      });
    } on GallerySaveException catch (error) {
      _reportExportError(error.message);
    } on ExportException catch (error) {
      _reportExportError(error.message);
    } catch (_) {
      _reportExportError('The image could not be saved. Please try again.');
    }
  }

  Future<void> _shareMemory() async {
    final image = _photoImage;
    if (image == null || _exporting) return;

    setState(() {
      _exporting = true;
      _exportMessage = null;
      _exportFailed = false;
    });

    final draft = _draft;
    final options = _exportOptions;

    try {
      final bytes = await widget.exporter.render(draft, image, options);
      final name = exportBaseName(draft, DateTime.now());
      await widget.shareService.share(
        bytes,
        name: '$name.${options.format.extension}',
        mimeType: options.format.mimeType,
      );
      if (!mounted) return;
      setState(() => _exporting = false);
    } on ExportException catch (error) {
      _reportExportError(error.message);
    } catch (_) {
      _reportExportError('The image could not be shared. Please try again.');
    }
  }

  void _reportExportError(String message) {
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _exportMessage = message;
      _exportFailed = true;
      _exportedDraft = _draft;
      _exportedFormat = _exportFormat;
      _exportedQuality = _exportQuality;
      _exportedSize = _exportSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata;
    final image = _photoImage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New memory'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            // heightFactor keeps a wide photograph from leaving a tall empty
            // band above and below it.
            child: Align(
              alignment: Alignment.center,
              heightFactor: 1,
              child: image == null
                  ? _PlainPhoto(
                      photo: widget.photo,
                      unreadable: _photoUnreadable,
                    )
                  : MemoryPreview(draft: _draft, image: image),
            ),
          ),
          const SizedBox(height: 14),
          _MetaRow(
            icon: Icons.photo_outlined,
            text: 'From ${widget.photo.origin.label}',
          ),
          if (metadata != null) ...[
            const SizedBox(height: 6),
            _MetaRow(
              icon: Icons.calendar_today_outlined,
              text: metadata.takenAt == null
                  ? 'No capture date in this photo'
                  : formatPhotoDateTime(metadata.takenAt!),
              muted: metadata.takenAt == null,
            ),
          ],
          const SizedBox(height: 28),
          const _SectionTitle('Location'),
          const SizedBox(height: 10),
          _LocationPanel(
            location: _location,
            error: _locationError,
            locating: _locating,
            photoPoint: metadata?.gps,
            onUseCurrentLocation: _useCurrentLocation,
            onEnterCoordinates: _enterCoordinates,
            onUsePhotoLocation: _usePhotoLocation,
          ),
          const SizedBox(height: 32),
          const _SectionTitle('Address'),
          const SizedBox(height: 10),
          AddressPanel(
            hasLocation: _location != null,
            parts: _address,
            selected: _addressFields,
            preset: _addressPreset,
            controller: _addressController,
            error: _addressError,
            lookingUp: _lookingUpAddress,
            onLookUp: _lookUpAddress,
            onPreset: _applyPreset,
            onToggle: _toggleField,
          ),
          const SizedBox(height: 32),
          const _SectionTitle('Note'),
          const SizedBox(height: 10),
          SectionCard(
            child: TextField(
              key: const Key('note-field'),
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              maxLength: 140,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Optional — a few words about this moment',
                border: InputBorder.none,
                isCollapsed: true,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 32),
          const _SectionTitle('Date'),
          const SizedBox(height: 10),
          _DatePanel(
            takenAt: metadata?.takenAt,
            loading: metadata == null,
            showDate: _showDate,
            onChanged: (value) => setState(() => _showDate = value),
          ),
          const SizedBox(height: 32),
          const _SectionTitle('Template'),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<MemoryTemplate>(
                  segments: [
                    for (final template in MemoryTemplate.values)
                      ButtonSegment(
                        value: template,
                        label: Text(template.label),
                      ),
                  ],
                  selected: {_template},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _template = selection.first),
                ),
                const SizedBox(height: 10),
                Text(
                  _template.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const _SectionTitle('Export'),
          const SizedBox(height: 10),
          SectionCard(
            child: ExportPanel(
              width: image?.width,
              height: image?.height,
              format: _exportFormat,
              quality: _exportQuality,
              size: _exportSize,
              busy: _exporting,
              message: _visibleExportMessage,
              failed: _exportFailed,
              onFormatChanged: (format) =>
                  setState(() => _exportFormat = format),
              onQualityChanged: (quality) =>
                  setState(() => _exportQuality = quality),
              onSizeChanged: (size) => setState(() => _exportSize = size),
              onSave: _saveToGallery,
              onShare: _shareMemory,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'The original photograph is never changed. A new image is written '
            'alongside it, at its full size.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// The date comes only from the photo. When there is none there is nothing to
/// show, and nothing is invented to fill the gap.
class _DatePanel extends StatelessWidget {
  const _DatePanel({
    required this.takenAt,
    required this.loading,
    required this.showDate,
    required this.onChanged,
  });

  final DateTime? takenAt;
  final bool loading;
  final bool showDate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final date = takenAt;

    if (loading) {
      return SectionCard(
        child: Text('Reading the date from the photo…', style: muted),
      );
    }

    if (date == null) {
      return SectionCard(
        child: Text(
          'This photo has no capture date, so no date will be shown.',
          style: muted,
        ),
      );
    }

    return SectionCard(
      child: Row(
        children: [
          Expanded(child: Text('Show ${formatPhotoDate(date)} on the image')),
          const SizedBox(width: 12),
          Switch.adaptive(value: showDate, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({
    required this.location,
    required this.error,
    required this.locating,
    required this.photoPoint,
    required this.onUseCurrentLocation,
    required this.onEnterCoordinates,
    required this.onUsePhotoLocation,
  });

  final LocationFix? location;
  final String? error;
  final bool locating;
  final GeoPoint? photoPoint;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onEnterCoordinates;
  final VoidCallback onUsePhotoLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fix = location;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fix == null)
            Text(
              'No location yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Text(
              fix.point.coordinates,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fix.summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (fix.isImprecise) ...[
              const SizedBox(height: 8),
              Note(
                icon: Icons.warning_amber_rounded,
                text:
                    'The signal is weak. A place named from this may be '
                    'wrong.',
                color: colorScheme.error,
              ),
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Note(
              icon: Icons.info_outline,
              text: error!,
              color: colorScheme.error,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: locating ? null : onUseCurrentLocation,
                icon: locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(locating ? 'Finding you…' : 'Use my location'),
              ),
              TextButton(
                onPressed: locating ? null : onEnterCoordinates,
                child: const Text('Enter coordinates'),
              ),
              if (photoPoint != null && fix?.source != LocationSource.exif)
                TextButton(
                  onPressed: locating ? null : onUsePhotoLocation,
                  child: const Text('Use photo location'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Typing coordinates costs nothing and works with no signal, so it is always
/// available — including when permission is refused.
class _CoordinatesDialog extends StatefulWidget {
  const _CoordinatesDialog();

  @override
  State<_CoordinatesDialog> createState() => _CoordinatesDialogState();
}

class _CoordinatesDialogState extends State<_CoordinatesDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final point = parseCoordinates(_controller.text);
    if (point == null) {
      setState(
        () => _error =
            'Enter latitude and longitude in decimal degrees, for example '
            '51.5074, -0.1278.',
      );
      return;
    }
    Navigator.of(context).pop(point);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter coordinates'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Latitude, longitude',
              hintText: '51.5074, -0.1278',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(
            'Decimal degrees, latitude first. Negative values are south and '
            'west.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Use')),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.muted = false});

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: muted ? 0.6 : 1)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: muted ? 0.6 : 1),
            ),
          ),
        ),
      ],
    );
  }
}

/// The photograph before the preview can be painted: while it is still
/// decoding, or when it could not be decoded at all.
class _PlainPhoto extends StatelessWidget {
  const _PlainPhoto({required this.photo, required this.unreadable});

  final PickedPhoto photo;
  final bool unreadable;

  @override
  Widget build(BuildContext context) {
    if (unreadable) return _UnreadablePhoto(origin: photo.origin);

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: Image.file(
        File(photo.path),
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => _UnreadablePhoto(origin: photo.origin),
      ),
    );
  }
}

class _UnreadablePhoto extends StatelessWidget {
  const _UnreadablePhoto({required this.origin});

  final PhotoOrigin origin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'This photograph could not be displayed',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
