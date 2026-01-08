import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/conversation_model.dart';

/// Chat Suggestion Service
/// 
/// Determines which action suggestions to show in chat based on context
class ChatSuggestionService {
  /// Get suggestions for a conversation
  /// 
  /// Returns suggestion type and data based on:
  /// - User type (student/parent vs tutor)
  /// - Conversation context (has booking/trial or not)
  /// - Tutor availability
  static Future<ChatSuggestion?> getSuggestions(Conversation conversation) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return null;

      // Get current user's profile to determine user type
      final userProfile = await SupabaseService.client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      final userType = userProfile?['user_type'] as String?;
      
      // Only show suggestions for students/parents chatting with tutors
      if (userType != 'student' && userType != 'parent' && userType != 'learner') {
        return null;
      }

      // Determine if other user is a tutor
      final otherUserId = conversation.getOtherUserId(userId);
      final otherUserProfile = await SupabaseService.client
          .from('profiles')
          .select('user_type')
          .eq('id', otherUserId)
          .maybeSingle();

      final otherUserType = otherUserProfile?['user_type'] as String?;
      if (otherUserType != 'tutor') {
        return null; // Not chatting with a tutor
      }

      // Check if conversation already has a linked booking/trial
      final hasLinkedBooking = conversation.trialSessionId != null ||
          conversation.bookingRequestId != null ||
          conversation.recurringSessionId != null;

      if (hasLinkedBooking) {
        return null; // Already has booking, no need for suggestions
      }

      // Check if tutor has an active trial/booking with this student
      final hasExistingBooking = await _hasExistingBooking(userId, otherUserId);
      if (hasExistingBooking) {
        return null; // Already has booking with this tutor
      }

      // Get tutor info for suggestion
      final tutorProfile = await SupabaseService.client
          .from('tutor_profiles')
          .select('user_id, admin_approval_status')
          .eq('user_id', otherUserId)
          .maybeSingle();

      final isApproved = tutorProfile?['admin_approval_status'] == 'approved';
      if (!isApproved) {
        return null; // Tutor not approved yet
      }

      // Return book trial suggestion
      return ChatSuggestion(
        type: SuggestionType.bookTrial,
        tutorId: otherUserId,
        tutorName: conversation.otherUserName ?? 'Tutor',
        message: 'Book a trial while ${conversation.otherUserName ?? 'this tutor'} is still available',
      );
    } catch (e) {
      LogService.error('Error getting chat suggestions: $e');
      return null;
    }
  }

  /// Check if user has existing booking/trial with tutor
  static Future<bool> _hasExistingBooking(String studentId, String tutorId) async {
    try {
      // Check for active trial sessions
      final trialResponse = await SupabaseService.client
          .from('trial_sessions')
          .select('id')
          .eq('learner_id', studentId)
          .eq('tutor_id', tutorId)
          .inFilter('status', ['pending', 'approved', 'scheduled'])
          .limit(1);

      if ((trialResponse as List).isNotEmpty) {
        return true;
      }

      // Check for active booking requests
      final bookingResponse = await SupabaseService.client
          .from('booking_requests')
          .select('id')
          .eq('student_id', studentId)
          .eq('tutor_id', tutorId)
          .inFilter('status', ['pending', 'approved'])
          .limit(1);

      if ((bookingResponse as List).isNotEmpty) {
        return true;
      }

      // Check for active recurring sessions
      final recurringResponse = await SupabaseService.client
          .from('recurring_sessions')
          .select('id')
          .eq('learner_id', studentId)
          .eq('tutor_id', tutorId)
          .eq('status', 'active')
          .limit(1);

      return (recurringResponse as List).isNotEmpty;
    } catch (e) {
      LogService.error('Error checking existing booking: $e');
      return false;
    }
  }
}

/// Chat Suggestion Model
class ChatSuggestion {
  final SuggestionType type;
  final String tutorId;
  final String tutorName;
  final String message;

  ChatSuggestion({
    required this.type,
    required this.tutorId,
    required this.tutorName,
    required this.message,
  });
}

enum SuggestionType {
  bookTrial,
  bookTutor,
  viewProfile,
}

