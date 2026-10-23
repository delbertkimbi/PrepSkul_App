/// Canonical minute precision for stored schedule times and UI choices.
class BookingTime {
  static bool overlaps(String time, int duration, int busyStart, int busyEnd) {
    final parts = normalize(time).split(':');
    final start = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    return start < busyEnd && start + duration > busyStart;
  }

  static String normalize(String raw) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::00)?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) throw FormatException('Invalid booking time', raw);
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();
    if (minute > 59 || (period == null ? hour > 23 : hour < 1 || hour > 12)) {
      throw FormatException('Invalid booking time', raw);
    }
    if (period != null) hour = hour % 12 + (period == 'PM' ? 12 : 0);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
