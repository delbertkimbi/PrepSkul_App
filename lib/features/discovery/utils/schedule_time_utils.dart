import 'package:intl/intl.dart';

/// Sort and format tutor availability time strings.
class ScheduleTimeUtils {
  ScheduleTimeUtils._();

  static const _weekdayOrder = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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
    return schedule.keys
        .where((day) {
          final times = schedule[day];
          if (times == null) return false;
          final list = times is List ? times : [times];
          return list.isNotEmpty;
        })
        .toList()
      ..sort((a, b) {
        final ai = _weekdayOrder.indexOf(a);
        final bi = _weekdayOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
  }

  /// Natural-language day list, e.g. "Mondays, Wednesdays & Fridays".
  static String availabilityDaysSummary(Map<String, dynamic> schedule) {
    final days = orderedDays(schedule);
    if (days.isEmpty) return 'Schedule not available';

    final labels = days.map((d) => '${d}s').toList();
    if (labels.length == 1) return 'Available ${labels.first}';
    if (labels.length == 2) {
      return 'Available ${labels[0]} and ${labels[1]}';
    }
    final head = labels.sublist(0, labels.length - 1).join(', ');
    return 'Available $head & ${labels.last}';
  }

  /// Natural-language period summary across all slots.
  static String availabilityPeriodsSummary(Map<String, dynamic> schedule) {
    var hasMorning = false;
    var hasAfternoon = false;
    var hasEvening = false;

    for (final day in orderedDays(schedule)) {
      final raw = schedule[day];
      final times = sorted(raw is List ? raw : [raw]);
      for (final time in times) {
        final minutes = toMinutes(time);
        if (minutes < 12 * 60) {
          hasMorning = true;
        } else if (minutes < 17 * 60) {
          hasAfternoon = true;
        } else {
          hasEvening = true;
        }
      }
    }

    final parts = <String>[
      if (hasMorning) 'morning',
      if (hasAfternoon) 'afternoon',
      if (hasEvening) 'evening',
    ];
    if (parts.isEmpty) return 'Sessions available on selected days';

    String joined;
    if (parts.length == 1) {
      joined = '${parts.first} sessions';
    } else if (parts.length == 2) {
      joined = '${parts[0]} and ${parts[1]} sessions';
    } else {
      joined = '${parts[0]}, ${parts[1]} and ${parts[2]} sessions';
    }
    return '${joined[0].toUpperCase()}${joined.substring(1)} available';
  }

  /// Upcoming calendar dates when the tutor has recurring availability.
  static List<DateTime> upcomingAvailableDates(
    Map<String, dynamic> schedule, {
    DateTime? from,
    int daysAhead = 56,
  }) {
    final availableWeekdays = orderedDays(schedule).toSet();
    if (availableWeekdays.isEmpty) return [];

    final start = from ?? DateTime.now();
    final today = DateTime(start.year, start.month, start.day);
    final dates = <DateTime>[];

    for (var i = 0; i < daysAhead; i++) {
      final date = today.add(Duration(days: i));
      final dayName = DateFormat('EEEE').format(date);
      if (availableWeekdays.contains(dayName)) {
        dates.add(date);
      }
    }
    return dates;
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return isSameDay(date, DateTime(now.year, now.month, now.day));
  }

  /// Prefer today when the tutor is available; otherwise the earliest weekday
  /// in Mon–Sun order among the tutor's available days (next occurrence).
  static int initialSelectedDateIndex(
    Map<String, dynamic> schedule,
    List<DateTime> upcomingDates,
  ) {
    if (upcomingDates.isEmpty) return 0;

    final todayIndex = upcomingDates.indexWhere(isToday);
    if (todayIndex >= 0) return todayIndex;

    final orderedWeekdays = orderedDays(schedule);
    for (final weekday in orderedWeekdays) {
      final index = upcomingDates.indexWhere(
        (d) => DateFormat('EEEE').format(d) == weekday,
      );
      if (index >= 0) return index;
    }
    return 0;
  }
}
