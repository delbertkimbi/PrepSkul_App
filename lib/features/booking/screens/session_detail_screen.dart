import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/widgets/session_location_map.dart';
import 'package:prepskul/features/sessions/widgets/location_tracking_widget.dart';
import 'package:prepskul/features/sessions/widgets/session_mode_statistics_widget.dart';
import 'package:prepskul/features/sessions/services/meet_service.dart';
import 'package:prepskul/features/sessions/screens/agora_video_session_screen.dart';
import 'package:prepskul/features/messaging/services/conversation_lifecycle_service.dart';
import 'package:prepskul/features/messaging/screens/chat_screen.dart';
import 'package:prepskul/features/messaging/models/conversation_model.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

/// Session Detail Screen
///
/// Full-screen view for session details (replaces popup dialog)
class SessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const SessionDetailScreen({
    Key? key,
    required this.session,
  }) : super(key: key);

  String _formatDateTime(String date, String time) {
    try {
      final dateTime = DateTime.parse(date);
      final formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
      return '$formattedDate at $time';
    } catch (e) {
      return '$date at $time';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'Session in Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      case 'approved':
        return 'Approved';
      default:
        return status;
    }
  }

  DateTime? _parseSessionDateTime(String date, String time) {
    try {
      final dateTime = DateTime.parse(date);
      final timeParts = time.split(':');
      if (timeParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        return DateTime(dateTime.year, dateTime.month, dateTime.day, hour, minute);
      }
      return dateTime;
    } catch (e) {
      return null;
    }
  }

  Future<void> _joinAgoraSession(BuildContext context, String sessionId) async {
    try {
      // Get user type to determine role
      final userProfile = await AuthService.getUserProfile();
      final userType = userProfile?['user_type'] as String?;
      final userRole = (userType == 'tutor') ? 'tutor' : 'learner';
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgoraVideoSessionScreen(
            sessionId: sessionId,
            userRole: userRole,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error joining session: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToChat(BuildContext context, Map<String, dynamic> session) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get or create conversation
      final supabase = SupabaseService.client;
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) {
        if (context.mounted) {
          Navigator.pop(context); // Dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to message.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get tutor ID from session
      String? tutorId;
      String? studentId = currentUserId;
      
      final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
      if (recurringData != null) {
        tutorId = recurringData['tutor_id'] as String?;
        studentId = recurringData['learner_id'] as String? ?? currentUserId;
      }

      if (tutorId == null) {
        if (context.mounted) {
          Navigator.pop(context); // Dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to find tutor information.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get or create conversation
      // The one_context constraint requires exactly ONE context ID
      // Determine which context ID to use based on session type
      final isTrial = session['type'] == 'trial';
      String? individualSessionId;
      String? recurringSessionId;
      String? trialSessionId;
      
      if (isTrial) {
        // For trial sessions, use trial_session_id
        trialSessionId = session['id'] as String?;
      } else if (session['id'] != null) {
        // For individual sessions (which may belong to a recurring session), use individual_session_id
        individualSessionId = session['id'] as String?;
      } else if (recurringData?['id'] != null) {
        // For recurring sessions without individual sessions, use recurring_session_id
        recurringSessionId = recurringData!['id'] as String?;
      }
      
      final conversationData = await ConversationLifecycleService.getOrCreateConversation(
        trialSessionId: trialSessionId,
        individualSessionId: individualSessionId,
        recurringSessionId: recurringSessionId,
        tutorId: tutorId,
        studentId: studentId,
      );

      // Dismiss loading
      if (context.mounted) Navigator.pop(context);

      if (conversationData == null || conversationData['id'] == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to start conversation. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get full conversation data
      final conversationResponse = await supabase
          .from('conversations')
          .select('*')
          .eq('id', conversationData['id'] as String)
          .maybeSingle();

      if (conversationResponse == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation not found. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create Conversation object
      final conversation = Conversation(
        id: conversationResponse['id'] as String,
        studentId: conversationResponse['student_id'] as String,
        tutorId: conversationResponse['tutor_id'] as String,
        bookingRequestId: conversationResponse['booking_request_id'] as String?,
        recurringSessionId: conversationResponse['recurring_session_id'] as String?,
        individualSessionId: conversationResponse['individual_session_id'] as String?,
        trialSessionId: conversationResponse['trial_session_id'] as String?,
        status: conversationResponse['status'] as String? ?? 'active',
        expiresAt: conversationResponse['expires_at'] != null
            ? DateTime.parse(conversationResponse['expires_at'] as String)
            : null,
        lastMessageAt: conversationResponse['last_message_at'] != null
            ? DateTime.parse(conversationResponse['last_message_at'] as String)
            : null,
        createdAt: conversationResponse['created_at'] != null
            ? DateTime.parse(conversationResponse['created_at'] as String)
            : DateTime.now(),
      );

      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading if still showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
    final tutorName = recurringData?['tutor_name'] as String? ?? 'Tutor';
    final subject = recurringData?['subject'] as String? ?? 'Session';
    final scheduledDate = session['scheduled_date'] as String;
    final scheduledTime = session['scheduled_time'] as String;
    final duration = session['duration_minutes'] as int? ?? 60;
    final location = session['location'] as String? ?? 'online';
    final status = session['status'] as String;
    final sessionId = session['id'] as String;
    final onsiteAddress = session['onsite_address'] as String?;
    final locationDescription = session['location_description'] as String?;
    
    // Get current user info for check-in
    String? currentUserId;
    String? userType;
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.getUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          currentUserId = snapshot.data?['id'] as String?;
          userType = snapshot.data?['user_type'] as String?;
        }
        
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(PhosphorIcons.arrowLeft(), color: AppTheme.textDark),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Session Details',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: AppTheme.textDark,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Details Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Tutor', tutorName),
                      _buildDetailRow('Subject', subject),
                      _buildDetailRow('Date & Time', _formatDateTime(scheduledDate, scheduledTime)),
                      _buildDetailRow('Duration', '$duration minutes'),
                      _buildDetailRow('Location', location == 'online' ? 'Online' : 'On-site'),
                      _buildDetailRow('Status', _getStatusLabel(status)),
                    ],
                  ),
                ),
                
                // Mode statistics for flexible sessions
                if (recurringData != null && recurringData['id'] != null) ...[
                  const SizedBox(height: 20),
                  SessionModeStatisticsWidget(
                    recurringSessionId: recurringData['id'] as String,
                    currentSessionLocation: location,
                  ),
                ],
                
                // Location map for onsite sessions
                if (location == 'onsite' && 
                    onsiteAddress != null && onsiteAddress.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SessionLocationMap(
                    address: onsiteAddress,
                    coordinates: null,
                    locationDescription: locationDescription,
                    sessionId: sessionId,
                    currentUserId: currentUserId,
                    userType: userType,
                    showCheckIn: status == 'scheduled' || status == 'in_progress',
                    scheduledDateTime: _parseSessionDateTime(scheduledDate, scheduledTime),
                    locationType: location,
                  ),
                  // Real-time location tracking for parents during active sessions
                  if (status == 'in_progress' && 
                      (userType == 'parent' || userType == 'student')) ...[
                    const SizedBox(height: 20),
                    LocationTrackingWidget(
                      sessionId: sessionId,
                      sessionAddress: onsiteAddress,
                      sessionCoordinates: null,
                    ),
                  ],
                ],
                
                // Action buttons
                if (status == 'scheduled' || status == 'in_progress') ...[
                  const SizedBox(height: 24),
                  // Agora Video Session button - show for ALL online sessions
                  if (location == 'online')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _joinAgoraSession(context, sessionId),
                        icon: Icon(PhosphorIcons.videoCamera(), size: 20),
                        label: Text(
                          status == 'in_progress' ? 'Join Session' : 'Join Video Session',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status == 'in_progress' 
                              ? AppTheme.accentGreen 
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Message tutor/student/parents button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToChat(context, session),
                      icon: Icon(PhosphorIcons.chatCircleDots(), size: 20),
                      label: Text(
                        'Message Tutor',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
