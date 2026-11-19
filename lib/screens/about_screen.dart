import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import 'section_card.dart';

/// What the app is, what it does with your data, and what it is built on.
///
/// The attribution here is the one the OpenStreetMap licence requires; it is
/// deliberately not painted onto exported images, which belong to the user.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final body = theme.textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'LibreGeoTag',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text('Version $appVersion', style: body?.copyWith(color: muted)),
            const SizedBox(height: 16),
            Text(
              'Give your photographs a place and a story. A photo, the place it '
              'was taken, a few words, and a date — turned into one image you '
              'can keep or send.',
              style: body,
            ),
            const SizedBox(height: 28),
            const _Heading('Your data'),
            const SizedBox(height: 10),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Point(
                    icon: Icons.phonelink_lock_outlined,
                    text:
                        'Everything happens on this device. There is no '
                        'account, no analytics, and no upload of your photos.',
                  ),
                  _Point(
                    icon: Icons.location_off_outlined,
                    text:
                        'Location is requested once, when you ask for it. '
                        'There is no background location and no history.',
                  ),
                  _Point(
                    icon: Icons.cloud_outlined,
                    text:
                        'Looking up an address sends only the coordinates to '
                        'the geocoding service. If you never tap the lookup, '
                        'nothing leaves the device.',
                  ),
                  _Point(
                    icon: Icons.photo_outlined,
                    text:
                        'The original photograph is only ever read. A new '
                        'image is written when you save or share.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _Heading('Address data'),
            const SizedBox(height: 10),
            Text(
              'Addresses come from OpenStreetMap, through the Photon geocoding '
              'service.',
              style: body,
            ),
            const SizedBox(height: 8),
            Text(
              'Data © OpenStreetMap contributors, available under the Open '
              'Database License (ODbL).',
              style: body?.copyWith(color: muted),
            ),
            const SizedBox(height: 28),
            const _Heading('Source code'),
            const SizedBox(height: 10),
            Text(
              'LibreGeoTag is free software under the MIT licence.',
              style: body,
            ),
            const SizedBox(height: 8),
            SelectableText(sourceUrl, style: body?.copyWith(color: muted)),
            const SizedBox(height: 28),
            const _Heading('Open-source licences'),
            const SizedBox(height: 10),
            Text(
              'Flutter, the plugins, and their dependencies each carry their '
              'own licence.',
              style: body,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('about-licences'),
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'LibreGeoTag',
                  applicationVersion: appVersion,
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('View licences'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
