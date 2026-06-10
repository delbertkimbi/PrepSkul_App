/// Sort and format tutor availability time strings.
class ScheduleTimeUtils {
  ScheduleTimeUtils._();

  static int toMinutes(String raw) {
    final s = raw.trim().toUpperCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(s);
    if (match == null) return 0;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final meridiem = match.group(3);
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  static List<String> sorted(List<dynamic> times) {
    final list = times.map((e) => e.toString()).toList();
    list.sort((a, b) => toMinutes(a).compareTo(toMinutes(b)));
    return list;
  }

  static String dayAbbrev(String day) {
    const map = {
      'Monday': 'Mon',
      'Tuesday': 'Tue',
      'Wednesday': 'Wed',
      'Thursday': 'Thu',
      'Friday': 'Fri',
      'Saturday': 'Sat',
      'Sunday': 'Sun',
    };
    return map[day] ?? (day.length >= 3 ? day.substring(0, 3) : day);
  }

  static List<String> orderedDays(Map<String, dynamic> schedule) {
    const order = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return schedule.keys
        .where((day) {
          final times = schedule[day];
          if (times == null) return false;
          final list = times is List ? times : [times];
          return list.isNotEmpty;
        })
        .toList()
      ..sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
  }
}
