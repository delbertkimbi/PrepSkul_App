import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/booking/utils/booking_time.dart';
import 'package:prepskul/features/booking/services/availability_service.dart';

void main() {
  test(
    'duration overlaps are blocked while adjacent sessions remain available',
    () {
      expect(BookingTime.overlaps('10:00', 60, 630, 690), isTrue);
      expect(BookingTime.overlaps('10:00', 30, 630, 690), isFalse);
      expect(BookingTime.overlaps('11:30', 60, 630, 690), isFalse);
      expect(BookingTime.overlaps('00:15', 30, -30, 30), isTrue);
    },
  );
  test('AM/PM and stored times identify the same slot', () {
    expect(BookingTime.normalize('7:00 PM'), '19:00');
    expect(BookingTime.normalize('19:00:00'), '19:00');
    expect(BookingTime.normalize('12:00 AM'), '00:00');
    expect(BookingTime.normalize('12:00 PM'), '12:00');
    expect(BookingTime.normalize(' 7:30pm '), '19:30');
  });
  test('malformed times never silently become midnight or another slot', () {
    for (final value in [
      '24:00',
      '7:60',
      '00:00 PM',
      '13:00 AM',
      'tomorrow',
      '',
    ]) {
      expect(() => BookingTime.normalize(value), throwsFormatException);
    }
  });
  test(
    'availability failure never returns invented bookable defaults',
    () async {
      await expectLater(
        AvailabilityService.getAvailableTimesForDay(
          tutorId: 'unavailable',
          day: 'Monday',
          date: DateTime(2026, 10, 26),
        ),
        throwsException,
      );
      await expectLater(
        AvailabilityService.getBlockedTimesForDate(
          'unavailable',
          DateTime(2026, 10, 26),
        ),
        throwsException,
      );
    },
  );
}
