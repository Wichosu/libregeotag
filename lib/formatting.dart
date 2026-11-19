const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats a capture date for display: "15 July 2023".
///
/// Written by hand rather than with `intl` because the output is part of the
/// generated image and must be stable, and because there is nothing else to
/// localise yet.
String formatPhotoDate(DateTime date) {
  final month = _months[date.month - 1];
  return '${date.day} $month ${date.year}';
}

/// Formats a capture date and time for display: "15 July 2023 at 14:23".
String formatPhotoDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${formatPhotoDate(date)} at $hour:$minute';
}
