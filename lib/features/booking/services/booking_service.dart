import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/booking/models/recurring_session_model.dart';

/// BookingService
///
/// Handles all booking-related operations:
/// - Creating booking requests
/// - Approving/rejecting requests
/// - Managing recurring sessions
/// - Fetching booking data
class BookingService {
  static final _supabase = SupabaseService.client;

  /// Create a new booking request
  static Future<BookingRequest> createBookingRequest({
    required String tutorId,
    required int frequency,
    required List<String> days,
    required Map<String, String> times,
    required String location,
    String? address,
    required String paymentPlan,
    required double monthlyTotal,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get current user profile
      final userProfile = await _supabase
          .from('profiles')
          .select('full_name, avatar_url, user_type')
          .eq('id', userId)
          .single();

      // Get tutor profile
      final tutorProfile = await _supabase
          .from('tutor_profiles')
          .select('*, profiles!inner(full_name, avatar_url)')
          .eq('user_id', tutorId)
          .single();

      // Create request data
      final requestData = {
        'student_id': userId,
        'tutor_id': tutorId,
        'frequency': frequency,
        'days': days,
        'times': times,
        'location': location,
        'address': address,
        'payment_plan': paymentPlan,
        'monthly_total': monthlyTotal,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        // Denormalized data for easy display
        'student_name': userProfile['full_name'],
        'student_avatar_url': userProfile['avatar_url'],
        'student_type': userProfile['user_type'],
        'tutor_name': tutorProfile['profiles']['full_name'],
        'tutor_avatar_url': tutorProfile['profiles']['avatar_url'],
        'tutor_rating': tutorProfile['rating'] ?? 4.8,
        'tutor_is_verified': tutorProfile['is_verified'] ?? false,
      };

      // Insert into database
      final response = await _supabase
          .from('session_requests')
          .insert(requestData)
          .select()
          .single();

      return BookingRequest.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create booking request: $e');
    }
  }

  /// Get all booking requests for a student/parent
  static Future<List<BookingRequest>> getStudentRequests({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('session_requests')
          .select()
          .eq('student_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      return (response as List)
          .map((json) => BookingRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch student requests: $e');
    }
  }

  /// Get all booking requests for a tutor
  static Future<List<BookingRequest>> getTutorRequests({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('session_requests')
          .select()
          .eq('tutor_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      return (response as List)
          .map((json) => BookingRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tutor requests: $e');
    }
  }

  /// Approve a booking request (tutor)
  static Future<BookingRequest> approveRequest(
    String requestId, {
    String? response,
  }) async {
    try {
      final updateData = {
        'status': 'approved',
        'responded_at': DateTime.now().toIso8601String(),
        'tutor_response': response,
      };

      final updated = await _supabase
          .from('session_requests')
          .update(updateData)
          .eq('id', requestId)
          .select()
          .single();

      // Create recurring session
      final request = BookingRequest.fromJson(updated);
      await _createRecurringSession(request);

      return request;
    } catch (e) {
      throw Exception('Failed to approve request: $e');
    }
  }

  /// Reject a booking request (tutor)
  static Future<BookingRequest> rejectRequest(
    String requestId, {
    required String reason,
  }) async {
    try {
      final updateData = {
        'status': 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      };

      final updated = await _supabase
          .from('session_requests')
          .update(updateData)
          .eq('id', requestId)
          .select()
          .single();

      return BookingRequest.fromJson(updated);
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  /// Cancel a booking request (student/parent)
  static Future<void> cancelRequest(String requestId) async {
    try {
      await _supabase
          .from('session_requests')
          .update({'status': 'cancelled'})
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to cancel request: $e');
    }
  }

  /// Create recurring session from approved request
  static Future<RecurringSession> _createRecurringSession(
      BookingRequest request) async {
    try {
      final sessionData = {
        'request_id': request.id,
        'student_id': request.studentId,
        'tutor_id': request.tutorId,
        'frequency': request.frequency,
        'days': request.days,
        'times': request.times,
        'location': request.location,
        'address': request.address,
        'payment_plan': request.paymentPlan,
        'monthly_total': request.monthlyTotal,
        'start_date': DateTime.now().toIso8601String(),
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'student_name': request.studentName,
        'student_avatar_url': request.studentAvatarUrl,
        'student_type': request.studentType,
        'tutor_name': request.tutorName,
        'tutor_avatar_url': request.tutorAvatarUrl,
        'tutor_rating': request.tutorRating,
      };

      final response = await _supabase
          .from('recurring_sessions')
          .insert(sessionData)
          .select()
          .single();

      return RecurringSession.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create recurring session: $e');
    }
  }

  /// Get all recurring sessions for a student/parent
  static Future<List<RecurringSession>> getStudentSessions({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('recurring_sessions')
          .select()
          .eq('student_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      return (response as List)
          .map((json) => RecurringSession.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch student sessions: $e');
    }
  }

  /// Get all recurring sessions for a tutor
  static Future<List<RecurringSession>> getTutorSessions({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      return (response as List)
          .map((json) => RecurringSession.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tutor sessions: $e');
    }
  }

  /// Update session status
  static Future<void> updateSessionStatus(
    String sessionId,
    String status,
  ) async {
    try {
      await _supabase
          .from('recurring_sessions')
          .update({'status': status})
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to update session status: $e');
    }
  }

  /// Get single booking request by ID
  static Future<BookingRequest> getRequestById(String requestId) async {
    try {
      final response = await _supabase
          .from('session_requests')
          .select()
          .eq('id', requestId)
          .single();

      return BookingRequest.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch request: $e');
    }
  }

  /// Get single recurring session by ID
  static Future<RecurringSession> getSessionById(String sessionId) async {
    try {
      final response = await _supabase
          .from('recurring_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      return RecurringSession.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch session: $e');
    }
  }
}

