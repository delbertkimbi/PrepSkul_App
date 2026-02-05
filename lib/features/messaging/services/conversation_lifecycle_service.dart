import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Conversation Lifecycle Service
/// 
/// Handles automatic conversation creation and management:
/// - Auto-create conversations on booking approval
/// - Auto-close expired conversations
/// - Check conversation validity before messaging
class ConversationLifecycleService {

  /// Auto-create conversation for trial session
  /// 
  /// Called when trial is approved and paid
  static Future<String?> createConversationForTrial({
    required String trialSessionId,
    required String studentId,
    required String tutorId,
  }) async {
    try {
      // Call database function via API or direct Supabase call
      final supabase = SupabaseService.client;
      
      final response = await supabase.rpc('create_conversation_for_trial', params: {
        'p_trial_session_id': trialSessionId,
        'p_student_id': studentId,
        'p_tutor_id': tutorId,
      });
      
      if (response != null) {
        LogService.success('Conversation created for trial: $trialSessionId');
        return response as String;
      }
      
      return null;
    } catch (e) {
      LogService.error('Error creating conversation for trial: $e');
      // Fallback: try direct insert
      try {
        return await _createConversationDirectly(
          studentId: studentId,
          tutorId: tutorId,
          trialSessionId: trialSessionId,
        );
      } catch (e2) {
        LogService.error('Error creating conversation directly: $e2');
        return null;
      }
    }
  }

  /// Auto-create conversation for booking request
  /// 
  /// Called when booking is approved
  static Future<String?> createConversationForBooking({
    required String bookingRequestId,
    required String studentId,
    required String tutorId,
  }) async {
    try {
      // Call database function
      final supabase = SupabaseService.client;
      
      final response = await supabase.rpc('create_conversation_for_booking', params: {
        'p_booking_request_id': bookingRequestId,
        'p_student_id': studentId,
        'p_tutor_id': tutorId,
      });
      
      if (response != null) {
        LogService.success('Conversation created for booking: $bookingRequestId');
        return response as String;
      }
      
      return null;
    } catch (e) {
      LogService.error('Error creating conversation for booking: $e');
      // Fallback: try direct insert
      try {
        return await _createConversationDirectly(
          studentId: studentId,
          tutorId: tutorId,
          bookingRequestId: bookingRequestId,
        );
      } catch (e2) {
        LogService.error('Error creating conversation directly: $e2');
        return null;
      }
    }
  }

  /// Create conversation directly (fallback method)
  static Future<String?> _createConversationDirectly({
    required String studentId,
    required String tutorId,
    String? trialSessionId,
    String? bookingRequestId,
    String? recurringSessionId,
    String? individualSessionId,
    DateTime? expiresAt,
  }) async {
    try {
      final supabase = SupabaseService.client;
      
      // Check if conversation already exists
      var query = supabase
          .from('conversations')
          .select('id')
          .eq('student_id', studentId)
          .eq('tutor_id', tutorId);
      
      if (trialSessionId != null) {
        query = query.eq('trial_session_id', trialSessionId);
      } else if (bookingRequestId != null) {
        query = query.eq('booking_request_id', bookingRequestId);
      } else if (recurringSessionId != null) {
        query = query.eq('recurring_session_id', recurringSessionId);
      } else if (individualSessionId != null) {
        query = query.eq('individual_session_id', individualSessionId);
      }
      
      final existing = await query.maybeSingle();
      
      if (existing != null) {
        return existing['id'] as String;
      }
      
      // Create new conversation
      final response = await supabase
          .from('conversations')
          .insert({
            'student_id': studentId,
            'tutor_id': tutorId,
            if (trialSessionId != null) 'trial_session_id': trialSessionId,
            if (bookingRequestId != null) 'booking_request_id': bookingRequestId,
            if (recurringSessionId != null) 'recurring_session_id': recurringSessionId,
            if (individualSessionId != null) 'individual_session_id': individualSessionId,
            'status': 'active',
            if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
          })
          .select('id')
          .single();
      
      return response['id'] as String;
    } catch (e) {
      LogService.error('Error creating conversation directly: $e');
      return null;
    }
  }

  /// Check if conversation is valid for messaging
  static Future<bool> isConversationValid(String conversationId) async {
    try {
      final supabase = SupabaseService.client;
      final userId = SupabaseService.currentUser?.id;
      
      if (userId == null) {
        return false;
      }
      
      final response = await supabase
          .from('conversations')
          .select('status, expires_at, student_id, tutor_id')
          .eq('id', conversationId)
          .maybeSingle();
      
      if (response == null) {
        return false;
      }
      
      // Check user is participant
      if (response['student_id'] != userId && response['tutor_id'] != userId) {
        return false;
      }
      
      // Check status
      if (response['status'] != 'active') {
        return false;
      }
      
      // Check expiration
      if (response['expires_at'] != null) {
        final expiresAt = DateTime.parse(response['expires_at'] as String);
        if (expiresAt.isBefore(DateTime.now())) {
          // Auto-close expired conversation
          await supabase
              .from('conversations')
              .update({'status': 'expired'})
              .eq('id', conversationId);
          return false;
        }
      }
      
      return true;
    } catch (e) {
      LogService.error('Error checking conversation validity: $e');
      return false;
    }
  }

  /// Auto-close expired conversations
  /// 
  /// Should be called periodically (e.g., via cron job or on app start)
  static Future<void> closeExpiredConversations() async {
    try {
      final supabase = SupabaseService.client;
      
      // Call database function to close expired conversations
      await supabase.rpc('auto_close_expired_conversations');
      
      LogService.success('Expired conversations closed');
    } catch (e) {
      LogService.error('Error closing expired conversations: $e');
    }
  }

  /// Get conversation ID for a trial session
  static Future<String?> getConversationIdForTrial(String trialSessionId) async {
    try {
      final supabase = SupabaseService.client;
      
      final response = await supabase
          .from('conversations')
          .select('id')
          .eq('trial_session_id', trialSessionId)
          .maybeSingle();
      
      return response?['id'] as String?;
    } catch (e) {
      LogService.error('Error getting conversation ID for trial: $e');
      return null;
    }
  }

  /// Get conversation ID for a booking request
  static Future<String?> getConversationIdForBooking(String bookingRequestId) async {
    try {
      final supabase = SupabaseService.client;
      
      final response = await supabase
          .from('conversations')
          .select('id')
          .eq('booking_request_id', bookingRequestId)
          .maybeSingle();
      
      return response?['id'] as String?;
    } catch (e) {
      LogService.error('Error getting conversation ID for booking: $e');
      return null;
    }
  }

  /// Get conversation ID for a recurring session
  static Future<String?> getConversationIdForRecurring(String recurringSessionId) async {
    try {
      final supabase = SupabaseService.client;
      
      final response = await supabase
          .from('conversations')
          .select('id')
          .eq('recurring_session_id', recurringSessionId)
          .maybeSingle();
      
      return response?['id'] as String?;
    } catch (e) {
      LogService.error('Error getting conversation ID for recurring session: $e');
      return null;
    }
  }

  /// Get conversation ID for an individual session
  static Future<String?> getConversationIdForIndividual(String individualSessionId) async {
    try {
      final supabase = SupabaseService.client;
      
      final response = await supabase
          .from('conversations')
          .select('id')
          .eq('individual_session_id', individualSessionId)
          .maybeSingle();
      
      return response?['id'] as String?;
    } catch (e) {
      LogService.error('Error getting conversation ID for individual session: $e');
      return null;
    }
  }

  /// Get or create conversation for a booking request, recurring session, individual session, or trial session
  /// Returns the conversation ID and full Conversation object
  /// The one_context constraint requires exactly ONE context ID to be provided
  static Future<Map<String, dynamic>?> getOrCreateConversation({
    String? bookingRequestId,
    String? recurringSessionId,
    String? individualSessionId,
    String? trialSessionId,
    String? tutorId,
    String? studentId,
  }) async {
    try {
      final supabase = SupabaseService.client;
      final currentUserId = SupabaseService.currentUser?.id;
      
      if (currentUserId == null) {
        LogService.error('User not authenticated');
        return null;
      }

      // Determine student and tutor IDs
      String? finalStudentId = studentId;
      String? finalTutorId = tutorId;

      // If IDs not provided, fetch from session data
      if (finalStudentId == null || finalTutorId == null) {
        if (recurringSessionId != null) {
          final recurringSession = await supabase
              .from('recurring_sessions')
              .select('tutor_id, learner_id, student_id')
              .eq('id', recurringSessionId)
              .maybeSingle();
          
          if (recurringSession != null) {
            finalTutorId ??= recurringSession['tutor_id'] as String?;
            finalStudentId ??= (recurringSession['learner_id'] ?? recurringSession['student_id']) as String?;
          }
        } else if (individualSessionId != null) {
          final individualSession = await supabase
              .from('individual_sessions')
              .select('tutor_id, learner_id, parent_id, recurring_session_id')
              .eq('id', individualSessionId)
              .maybeSingle();
          
          if (individualSession != null) {
            finalTutorId ??= individualSession['tutor_id'] as String?;
            finalStudentId ??= (individualSession['learner_id'] ?? individualSession['parent_id']) as String?;
            
            // If no student ID found, try to get from recurring session
            if (finalStudentId == null && individualSession['recurring_session_id'] != null) {
              final recurringId = individualSession['recurring_session_id'] as String;
              final recurringSession = await supabase
                  .from('recurring_sessions')
                  .select('learner_id, student_id')
                  .eq('id', recurringId)
                  .maybeSingle();
              
              if (recurringSession != null) {
                finalStudentId = (recurringSession['learner_id'] ?? recurringSession['student_id']) as String?;
              }
            }
          }
        } else if (bookingRequestId != null) {
          final bookingRequest = await supabase
              .from('booking_requests')
              .select('tutor_id, student_id')
              .eq('id', bookingRequestId)
              .maybeSingle();
          
          if (bookingRequest != null) {
            finalTutorId ??= bookingRequest['tutor_id'] as String?;
            finalStudentId ??= bookingRequest['student_id'] as String?;
          }
        }
      }

      if (finalStudentId == null || finalTutorId == null) {
        LogService.error('Could not determine student or tutor ID');
        return null;
      }

      // Try to find existing conversation
      String? conversationId;
      
      if (bookingRequestId != null) {
        conversationId = await getConversationIdForBooking(bookingRequestId);
      } else if (recurringSessionId != null) {
        conversationId = await getConversationIdForRecurring(recurringSessionId);
      } else if (individualSessionId != null) {
        conversationId = await getConversationIdForIndividual(individualSessionId);
      }

      // If conversation exists, fetch full data
      if (conversationId != null) {
        final conversation = await supabase
            .from('conversations')
            .select('*')
            .eq('id', conversationId)
            .maybeSingle();
        
        if (conversation != null) {
          return {
            'id': conversationId,
            'conversation': conversation,
          };
        }
      }

      // Create new conversation if it doesn't exist
      conversationId = await _createConversationDirectly(
        studentId: finalStudentId,
        tutorId: finalTutorId,
        trialSessionId: trialSessionId,
        bookingRequestId: bookingRequestId,
        recurringSessionId: recurringSessionId,
        individualSessionId: individualSessionId,
      );

      if (conversationId != null) {
        final conversation = await supabase
            .from('conversations')
            .select('*')
            .eq('id', conversationId)
            .maybeSingle();
        
        if (conversation != null) {
          return {
            'id': conversationId,
            'conversation': conversation,
          };
        }
      }

      return null;
    } catch (e) {
      LogService.error('Error getting or creating conversation: $e');
      return null;
    }
  }
}

