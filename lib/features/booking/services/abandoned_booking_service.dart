import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Service for tracking abandoned bookings (when users reach review screen but don't complete)
class AbandonedBookingService {
  static final _supabase = SupabaseService.client;

  /// Track when user reaches the review screen for a booking
  /// This is called when the review/confirmation screen is displayed
  static Future<void> trackReviewScreenReached({
    required String userId,
    required String tutorId,
    required String bookingType, // 'trial' or 'normal'
    required Map<String, dynamic> bookingData, // Tutor info, subject, schedule, etc.
  }) async {
    try {
      // Check if there's already a pending abandoned booking for this user+tutor+type
      final existing = await _supabase
          .from('abandoned_bookings')
          .select('id')
          .eq('user_id', userId)
          .eq('tutor_id', tutorId)
          .eq('booking_type', bookingType)
          .eq('status', 'pending')
          .maybeSingle();

      if (existing != null) {
        // Update existing record with new review screen timestamp
        await _supabase
            .from('abandoned_bookings')
            .update({
              'reached_review_at': DateTime.now().toIso8601String(),
              'booking_data': bookingData,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'] as String);
        LogService.debug('Updated existing abandoned booking tracking');
      } else {
        // Create new abandoned booking record
        await _supabase.from('abandoned_bookings').insert({
          'user_id': userId,
          'tutor_id': tutorId,
          'booking_type': bookingType,
          'booking_data': bookingData,
          'reached_review_at': DateTime.now().toIso8601String(),
          'status': 'pending',
        });
        LogService.debug('Tracked abandoned booking: $bookingType for tutor $tutorId');
      }
    } catch (e) {
      LogService.warning('Error tracking abandoned booking: $e');
      // Don't throw - this is non-critical tracking
    }
  }

  /// Mark abandoned booking as completed when user completes the booking
  /// This is called when booking is successfully submitted
  static Future<void> markAsCompleted({
    required String userId,
    required String tutorId,
    required String bookingType,
  }) async {
    try {
      await _supabase.rpc('mark_abandoned_booking_completed', params: {
        'p_user_id': userId,
        'p_tutor_id': tutorId,
        'p_booking_type': bookingType,
      });
      LogService.debug('Marked abandoned booking as completed');
    } catch (e) {
      LogService.warning('Error marking abandoned booking as completed: $e');
      // Don't throw - this is non-critical
    }
  }

  /// Get abandoned bookings ready for reminder (used by scheduled job)
  static Future<List<Map<String, dynamic>>> getBookingsForReminder() async {
    try {
      final response = await _supabase.rpc('get_abandoned_bookings_for_reminder');
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      LogService.error('Error fetching abandoned bookings for reminder: $e');
      return [];
    }
  }

  /// Mark reminder as sent (update reminder_sent_at and increment count)
  static Future<void> markReminderSent(String abandonedBookingId) async {
    try {
      final record = await _supabase
          .from('abandoned_bookings')
          .select('reminder_count')
          .eq('id', abandonedBookingId)
          .maybeSingle();

      final currentCount = (record?['reminder_count'] as int?) ?? 0;
      final newStatus = currentCount >= 1 ? 'expired' : 'reminded'; // Max 2 reminders

      await _supabase
          .from('abandoned_bookings')
          .update({
            'reminder_sent_at': DateTime.now().toIso8601String(),
            'reminder_count': currentCount + 1,
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', abandonedBookingId);
      
      LogService.debug('Marked reminder as sent for abandoned booking: $abandonedBookingId');
    } catch (e) {
      LogService.error('Error marking reminder as sent: $e');
      rethrow;
    }
  }
}
