import 'package:material_ui/material_ui.dart';

import '../models/address.dart';
import 'note.dart';
import 'section_card.dart';

/// Chooses how much of an address appears on the image.
///
/// The text field is always editable, so a place can be named by hand when the
/// lookup service is unreachable — or when its name is not the one the user
/// would have chosen.
class AddressPanel extends StatelessWidget {
  const AddressPanel({
    super.key,
    required this.hasLocation,
    required this.parts,
    required this.selected,
    required this.preset,
    required this.controller,
    required this.error,
    required this.lookingUp,
    required this.onLookUp,
    required this.onPreset,
    required this.onToggle,
  });

  final bool hasLocation;
  final AddressParts? parts;
  final Set<AddressField> selected;
  final AddressPreset? preset;
  final TextEditingController controller;
  final String? error;
  final bool lookingUp;
  final VoidCallback onLookUp;
  final ValueChanged<AddressPreset> onPreset;
  final ValueChanged<AddressField> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasLocation)
            Text(
              'Choose a location above, then name the place.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            if (parts == null) ...[
              Text(
                'No address yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: lookingUp ? null : onLookUp,
                icon: lookingUp
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.travel_explore, size: 18),
                label: Text(lookingUp ? 'Looking up…' : 'Look up address'),
              ),
              const SizedBox(height: 6),
              Text('Sends only the coordinates, to Photon.', style: muted),
              const SizedBox(height: 12),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final option in AddressPreset.values)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: preset == option,
                      onSelected: (_) => onPreset(option),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final field in AddressField.values)
                    if (parts!.availableFields.contains(field))
                      FilterChip(
                        label: Text(field.label),
                        selected: selected.contains(field),
                        onSelected: (_) => onToggle(field),
                      ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('address-field'),
              controller: controller,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Address on the image',
                hintText: parts == null ? 'Type the address yourself' : null,
                helperText: parts == null
                    ? 'Works with no connection.'
                    : 'Edit it freely.',
                border: const OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Note(
                icon: Icons.info_outline,
                text: error!,
                color: colorScheme.error,
              ),
            ],
            if (parts != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: lookingUp ? null : onLookUp,
                  icon: lookingUp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(lookingUp ? 'Looking up…' : 'Look up again'),
                ),
              ),
              Text('Sends only the coordinates, to Photon.', style: muted),
              const SizedBox(height: 4),
              Text('Address data: © OpenStreetMap contributors', style: muted),
            ],
          ],
        ],
      ),
    );
  }
}
