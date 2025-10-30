import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/models/tutor_request_model.dart';

/// Service for handling tutor requests (custom tutors not on platform)
class TutorRequestService {
  static final _supabase = SupabaseService.client;

  /// Create a new tutor request
  static Future<String> createRequest({
    required List<String> subjects,
    required String educationLevel,
    String? specificRequirements,
    required String teachingMode,
    required int budgetMin,
    required int budgetMax,
    String? tutorGender,
    String? tutorQualification,
    required List<String> preferredDays,
    required String preferredTime,
    required String location,
    required String urgency,
    String? additionalNotes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get user profile for denormalized data
      final userProfile = await _supabase
          .from('profiles')
          .select('full_name, phone_number, user_type')
          .eq('id', userId)
          .single();

      final requestData = {
        'requester_id': userId,
        'subjects': subjects,
        'education_level': educationLevel,
        'specific_requirements': specificRequirements,
        'teaching_mode': teachingMode,
        'budget_min': budgetMin,
        'budget_max': budgetMax,
        'tutor_gender': tutorGender,
        'tutor_qualification': tutorQualification,
        'preferred_days': preferredDays,
        'preferred_time': preferredTime,
        'location': location,
        'urgency': urgency,
        'additional_notes': additionalNotes,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        // Denormalized data
        'requester_name': userProfile['full_name'],
        'requester_phone': userProfile['phone_number'],
        'requester_type': userProfile['user_type'],
      };

      final response = await _supabase
          .from('tutor_requests')
          .insert(requestData)
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      print('❌ Error creating tutor request: $e');
      throw Exception('Failed to create tutor request: $e');
    }
  }

  /// Get all tutor requests for current user
  static Future<List<TutorRequest>> getUserRequests({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('tutor_requests')
          .select()
          .eq('requester_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => TutorRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching user tutor requests: $e');
      throw Exception('Failed to fetch tutor requests: $e');
    }
  }

  /// Get single tutor request by ID
  static Future<TutorRequest> getRequestById(String requestId) async {
    try {
      final response = await _supabase
          .from('tutor_requests')
          .select()
          .eq('id', requestId)
          .single();

      return TutorRequest.fromJson(response);
    } catch (e) {
      print('❌ Error fetching tutor request: $e');
      throw Exception('Failed to fetch tutor request: $e');
    }
  }

  /// Update request status (admin only)
  static Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    String? adminNotes,
    String? matchedTutorId,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (adminNotes != null) {
        updateData['admin_notes'] = adminNotes;
      }

      if (matchedTutorId != null) {
        updateData['matched_tutor_id'] = matchedTutorId;
        updateData['matched_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('tutor_requests')
          .update(updateData)
          .eq('id', requestId);
    } catch (e) {
      print('❌ Error updating tutor request: $e');
      throw Exception('Failed to update tutor request: $e');
    }
  }

  /// Cancel a tutor request
  static Future<void> cancelRequest(String requestId) async {
    try {
      await _supabase
          .from('tutor_requests')
          .update({
            'status': 'closed',
            'admin_notes': 'Cancelled by user',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      print('❌ Error cancelling tutor request: $e');
      throw Exception('Failed to cancel tutor request: $e');
    }
  }

  /// Get all pending tutor requests (admin only)
  static Future<List<TutorRequest>> getAllPendingRequests() async {
    try {
      final response = await _supabase
          .from('tutor_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => TutorRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching pending tutor requests: $e');
      throw Exception('Failed to fetch pending tutor requests: $e');
    }
  }
}

