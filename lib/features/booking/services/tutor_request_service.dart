import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/booking/models/tutor_request_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    String? locationDescription,
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
          .maybeSingle();
      
      if (userProfile == null) {
        throw Exception('User profile not found: $userId');
      }

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
        'additional_notes': additionalNotes != null && locationDescription != null
            ? '${additionalNotes}\n\nLocation Details: $locationDescription'
            : (additionalNotes ?? (locationDescription != null ? 'Location Details: $locationDescription' : null)),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        // Denormalized data
        'requester_name': userProfile['full_name'],
        'requester_phone': userProfile['phone_number'],
        'requester_type': userProfile['user_type'],
      };

      // Try to include location_description if column exists, otherwise append to additional_notes
      // First attempt with location_description
      Map<String, dynamic> insertData = Map<String, dynamic>.from(requestData);
      if (locationDescription != null && locationDescription.isNotEmpty) {
        insertData['location_description'] = locationDescription;
      }

      dynamic response;
      try {
        response = await _supabase
          .from('tutor_requests')
          .insert(insertData)
          .select('id')
          .maybeSingle();
      } catch (e) {
        // Check if error is about missing location_description column
        final errorStr = e.toString().toLowerCase();
        final isColumnError = e is PostgrestException ||
            errorStr.contains('location_description') || 
            errorStr.contains('pgrst204') ||
            (errorStr.contains('column') && errorStr.contains('not found') && errorStr.contains('location'));
        
        if (isColumnError && insertData.containsKey('location_description')) {
          LogService.warning('location_description column not found, using additional_notes instead');
          // Remove location_description and retry
          insertData.remove('location_description');
          try {
            response = await _supabase
              .from('tutor_requests')
              .insert(insertData)
              .select('id')
              .maybeSingle();
          } catch (retryError) {
            // If retry also fails, throw the original error
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      
      if (response == null) {
        throw Exception('Failed to create tutor request');
      }

      final requestId = response['id'] as String;

      // Notify admins about the new tutor request
      await _notifyAdmins(requestId, userProfile['full_name'] as String? ?? 'User');

      return requestId;
    } catch (e) {
      LogService.error('Error creating tutor request: $e');
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
      LogService.error('Error fetching user tutor requests: $e');
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
          .maybeSingle();

      if (response == null) {
        throw Exception('Tutor request not found: $requestId');
      }

      return TutorRequest.fromJson(response);
    } catch (e) {
      LogService.error('Error fetching tutor request: $e');
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
      LogService.error('Error updating tutor request: $e');
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
      LogService.error('Error cancelling tutor request: $e');
      throw Exception('Failed to cancel tutor request: $e');
    }
  }

  /// Update a tutor request (user can edit their own request)
  static Future<void> updateRequest({
    required String requestId,
    List<String>? subjects,
    String? educationLevel,
    String? specificRequirements,
    String? teachingMode,
    int? budgetMin,
    int? budgetMax,
    String? tutorGender,
    String? tutorQualification,
    List<String>? preferredDays,
    String? preferredTime,
    String? location,
    String? locationDescription,
    String? urgency,
    String? additionalNotes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Verify the request belongs to the user
      final requestResponse = await _supabase
          .from('tutor_requests')
          .select('requester_id, status')
          .eq('id', requestId)
          .maybeSingle();

      final request = requestResponse as Map<String, dynamic>?;

      if (request == null) {
        throw Exception('Request not found');
      }

      if (request['requester_id'] != userId) {
        throw Exception('You can only edit your own requests');
      }

      // Only allow editing if status is pending or in_progress
      final status = request['status'] as String;
      if (status != 'pending' && status != 'in_progress') {
        throw Exception('Cannot edit request with status: $status');
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (subjects != null) updateData['subjects'] = subjects;
      if (educationLevel != null) updateData['education_level'] = educationLevel;
      if (specificRequirements != null) updateData['specific_requirements'] = specificRequirements;
      if (teachingMode != null) updateData['teaching_mode'] = teachingMode;
      if (budgetMin != null) updateData['budget_min'] = budgetMin;
      if (budgetMax != null) updateData['budget_max'] = budgetMax;
      if (tutorGender != null) updateData['tutor_gender'] = tutorGender;
      if (tutorQualification != null) updateData['tutor_qualification'] = tutorQualification;
      if (preferredDays != null) updateData['preferred_days'] = preferredDays;
      if (preferredTime != null) updateData['preferred_time'] = preferredTime;
      if (location != null) updateData['location'] = location;
      if (locationDescription != null) updateData['location_description'] = locationDescription;
      if (urgency != null) updateData['urgency'] = urgency;
      if (additionalNotes != null) updateData['additional_notes'] = additionalNotes;

      await _supabase
          .from('tutor_requests')
          .update(updateData)
          .eq('id', requestId);

      // Notify admins about the edit
      final userProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final requesterName = userProfile?['full_name'] as String? ?? 'User';
      
      // Get all admins and notify them
      final adminResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_admin', true);

      for (var admin in adminResponse) {
        final adminId = admin['id'] as String;
        await NotificationHelperService.notifyTutorRequestUpdated(
          adminId: adminId,
          requestId: requestId,
          requesterName: requesterName,
        );
      }
    } catch (e) {
      LogService.error('Error updating tutor request: $e');
      throw Exception('Failed to update tutor request: $e');
    }
  }

  /// Delete a tutor request (user can delete their own request)
  static Future<void> deleteRequest(String requestId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Verify the request belongs to the user
      final requestResponse = await _supabase
          .from('tutor_requests')
          .select('requester_id, status')
          .eq('id', requestId)
          .maybeSingle();

      final request = requestResponse as Map<String, dynamic>?;

      if (request == null) {
        throw Exception('Request not found');
      }

      if (request['requester_id'] != userId) {
        throw Exception('You can only delete your own requests');
      }

      // Only allow deletion if status is pending or in_progress
      final status = request['status'] as String;
      if (status != 'pending' && status != 'in_progress') {
        throw Exception('Cannot delete request with status: $status');
      }

      // Get user name for admin notification
      final userProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final requesterName = userProfile?['full_name'] as String? ?? 'User';

      // Delete the request
      await _supabase
          .from('tutor_requests')
          .delete()
          .eq('id', requestId);

      // Notify admins about the deletion
      final adminResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_admin', true);

      for (var admin in adminResponse) {
        final adminId = admin['id'] as String;
        await NotificationHelperService.notifyTutorRequestDeleted(
          adminId: adminId,
          requestId: requestId,
          requesterName: requesterName,
        );
      }
    } catch (e) {
      LogService.error('Error deleting tutor request: $e');
      throw Exception('Failed to delete tutor request: $e');
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
      LogService.error('Error fetching pending tutor requests: $e');
      throw Exception('Failed to fetch pending tutor requests: $e');
    }
  }

  /// Notify all admins about a new tutor request
  static Future<void> _notifyAdmins(String requestId, String requesterName) async {
    try {
      // Get all admin users
      final adminResponse = await _supabase
          .from('profiles')
          .select('id, full_name, email')
          .eq('is_admin', true);

      if (adminResponse.isEmpty) {
        LogService.warning('No admin users found to notify');
        return;
      }

      // Send notification to each admin
      for (final admin in adminResponse) {
        final adminId = admin['id'] as String;
        
        // Create in-app notification for admin
        await NotificationHelperService.notifyTutorRequestCreated(
          adminId: adminId,
          requestId: requestId,
          requesterName: requesterName,
        );
      }

      LogService.success('Notified ${adminResponse.length} admin(s) about tutor request $requestId');
    } catch (e) {
      LogService.warning('Error notifying admins about tutor request: $e');
      // Don't throw - notification failure shouldn't block request creation
    }
  }
}