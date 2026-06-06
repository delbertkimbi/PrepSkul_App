import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/booking/utils/tutor_request_list_filters.dart';

BookingRequest _request({
  required String status,
  String? paymentStatus,
  DateTime? createdAt,
}) {
  return BookingRequest(
    id: 'req-1',
    studentId: 'student-1',
    tutorId: 'tutor-1',
    frequency: 2,
    days: const ['Monday', 'Wednesday'],
    times: const {'Monday': '4:00 PM', 'Wednesday': '4:00 PM'},
    location: 'online',
    paymentPlan: 'monthly',
    monthlyTotal: 50000,
    status: status,
    createdAt: createdAt ?? DateTime.now(),
    studentName: 'Test Student',
    studentType: 'student',
    tutorName: 'Test Tutor',
    tutorRating: 4.9,
    tutorIsVerified: true,
    paymentStatus: paymentStatus,
  );
}

void main() {
  group('tutor request list filters', () {
    test('approved and paid requests are not active', () {
      final request = _request(status: 'approved', paymentStatus: 'paid');
      expect(isActiveTutorBookingRequest(request), isFalse);
      expect(isPastTutorBookingRequest(request), isTrue);
    });

    test('approved awaiting payment stays active', () {
      final request = _request(status: 'approved', paymentStatus: 'pending');
      expect(isActiveTutorBookingRequest(request), isTrue);
    });

    test('pending requests stay active', () {
      final request = _request(status: 'pending');
      expect(isActiveTutorBookingRequest(request), isTrue);
    });

    test('matched and paid requests are not active', () {
      final request = _request(status: 'matched', paymentStatus: 'paid');
      expect(isActiveTutorBookingRequest(request), isFalse);
    });
  });
}
