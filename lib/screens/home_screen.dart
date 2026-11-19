import 'package:material_ui/material_ui.dart';

import '../export/memory_exporter.dart';
import '../models/picked_photo.dart';
import '../services/gallery_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/metadata_service.dart';
import '../services/photo_picker_service.dart';
import '../services/share_service.dart';
import 'about_screen.dart';
import 'editor_screen.dart';

/// Entry point: choose where the photograph comes from.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.picker,
    required this.metadataReader,
    required this.locationService,
    required this.geocodingProvider,
    this.exporter = const MemoryExporter(),
    this.galleryService = const DeviceGalleryService(),
    this.shareService = const DeviceShareService(),
  });

  final PhotoPicker picker;
  final PhotoMetadataReader metadataReader;
  final LocationService locationService;
  final GeocodingProvider geocodingProvider;
  final MemoryExporter exporter;
  final GalleryService galleryService;
  final ShareService shareService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    // Android can kill the app while the camera is open. Check once, after the
    // first frame, for a photograph that survived.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLost());
  }

  Future<void> _recoverLost() async {
    final photo = await widget.picker.recoverLost();
    if (!mounted || photo == null) return;
    _openEditor(photo);
  }

  Future<void> _pick(PhotoOrigin origin) async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      final photo = await widget.picker.pick(origin);
      if (!mounted || photo == null) return;
      _openEditor(photo);
    } on PhotoPickException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _openEditor(PickedPhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          photo: photo,
          metadataReader: widget.metadataReader,
          locationService: widget.locationService,
          geocodingProvider: widget.geocodingProvider,
          exporter: widget.exporter,
          galleryService: widget.galleryService,
          shareService: widget.shareService,
        ),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'LibreGeoTag',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('about-button'),
                    onPressed: _openAbout,
                    tooltip: 'About LibreGeoTag',
                    icon: const Icon(Icons.info_outline),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Give your photographs a place and a story.',
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _SourceButton(
                icon: Icons.photo_camera_outlined,
                label: 'Take a photo',
                onPressed: _picking ? null : () => _pick(PhotoOrigin.camera),
              ),
              const SizedBox(height: 12),
              _SourceButton(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                filled: false,
                onPressed: _picking ? null : () => _pick(PhotoOrigin.gallery),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Photos are processed on your device and never uploaded.',
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Icon(icon, size: 20), const SizedBox(width: 10), Text(label)],
    );

    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );

    return SizedBox(
      height: 60,
      width: double.infinity,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(shape: shape),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(shape: shape),
              child: child,
            ),
    );
  }
}
