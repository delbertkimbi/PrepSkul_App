import '../models/booking_request_model.dart';

bool isTutorRequestPaid(String? paymentStatus) {
  final normalized = (paymentStatus ?? '').toLowerCase();
  return normalized == 'paid' || normalized == 'completed';
}

bool isTutorRequestSessionLinked(String status) {
  final normalized = status.toLowerCase();
  return normalized == 'approved' ||
      normalized == 'matched' ||
      normalized == 'scheduled';
}

/// Requests that still belong on the tutor Requests tab (needs action or awaiting payment).
bool isActiveTutorBookingRequest(BookingRequest request) {
  return !isPastTutorBookingRequest(request);
}

/// Handled history: rejected, cancelled, paid+linked, or very old records.
bool isPastTutorBookingRequest(BookingRequest request) {
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  final status = request.status.toLowerCase();

  if (request.createdAt.isBefore(cutoff)) return true;

  if (status == 'rejected' ||
      status == 'cancelled' ||
      status == 'completed' ||
      status == 'expired') {
    return true;
  }

  // Once paid, the booking lives under Sessions — not Requests.
  if (isTutorRequestSessionLinked(status) &&
      isTutorRequestPaid(request.paymentStatus)) {
    return true;
  }

  return false;
}
