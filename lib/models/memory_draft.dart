import 'location_fix.dart';
import 'picked_photo.dart';

/// The layouts a memory can be drawn in.
enum MemoryTemplate {
  /// Text over the photograph, the photograph edge to edge.
  overlay,

  /// The photograph printed on a card, with a caption beneath it.
  postcard;

  String get label => switch (this) {
    MemoryTemplate.overlay => 'Overlay',
    MemoryTemplate.postcard => 'Postcard',
  };

  String get description => switch (this) {
    MemoryTemplate.overlay => 'Text laid over the photograph',
    MemoryTemplate.postcard => 'A print with a caption below',
  };
}

/// Everything one memory image is made of.
///
/// A plain value: the editor builds a new one whenever anything changes, and
/// the renderer reads nothing else. Keeping it separate from the editor is what
/// lets the same painting code serve the preview and the export.
class MemoryDraft {
  const MemoryDraft({
    required this.photo,
    this.template = MemoryTemplate.overlay,
    this.location,
    this.address = '',
    this.note = '',
    this.takenAt,
    this.showDate = true,
  });

  final PickedPhoto photo;
  final MemoryTemplate template;
  final LocationFix? location;

  /// The address as it will be printed, already narrowed by the presets and
  /// possibly edited by hand.
  final String address;
  final String note;

  /// Only ever the photograph's own capture date, never today's.
  final DateTime? takenAt;
  final bool showDate;

  bool get hasAddress => address.trim().isNotEmpty;

  /// The place to print. Coordinates stand in when no address was given, so a
  /// memory is never left completely unlabelled.
  String get place =>
      hasAddress ? address.trim() : (location?.point.coordinates ?? '');

  bool get hasDate => showDate && takenAt != null;

  /// True when the image will carry anything besides the photograph.
  bool get hasCaption => place.isNotEmpty || note.trim().isNotEmpty || hasDate;

  @override
  bool operator ==(Object other) =>
      other is MemoryDraft &&
      other.photo.path == photo.path &&
      other.template == template &&
      other.location == location &&
      other.address == address &&
      other.note == note &&
      other.takenAt == takenAt &&
      other.showDate == showDate;

  @override
  int get hashCode => Object.hash(
    photo.path,
    template,
    location,
    address,
    note,
    takenAt,
    showDate,
  );
}
