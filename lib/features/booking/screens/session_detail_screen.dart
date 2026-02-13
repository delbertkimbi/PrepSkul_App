import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/config/live_session_test_config.dart';
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
import 'package:prepskul/features/booking/services/session_reschedule_service.dart';
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

  /// Show dialog to request reschedule for past/completed sessions.
  static Future<void> _showRescheduleDialog(
    BuildContext context,
    String sessionId,
    String currentDate,
    String currentTime,
  ) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final reasonController = TextEditingController();
    try {
      final dateTime = DateTime.tryParse(currentDate);
      if (dateTime != null) {
        final parts = currentTime.split(':');
        if (parts.length >= 2) {
          selectedDate = dateTime;
          selectedTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    } catch (_) {}
    selectedDate ??= DateTime.now().add(const Duration(days: 1));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Request reschedule', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a new date and time. The tutor will need to approve.',
                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      selectedDate != null
                          ? DateFormat('MMM d, yyyy').format(selectedDate!)
                          : 'Select date',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                  ListTile(
                    title: Text(
                      selectedTime != null
                          ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                          : 'Select time',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) setState(() => selectedTime = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Reason (optional)', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Missed session, need make-up',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textMedium)),
              ),
              ElevatedButton(
                onPressed: selectedDate != null && selectedTime != null
                    ? () {
                        final timeStr =
                            '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
                        Navigator.pop(context, {
                          'date': selectedDate,
                          'time': timeStr,
                          'reason': reasonController.text.trim().isEmpty ? 'Reschedule requested' : reasonController.text.trim(),
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                child: Text('Request', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
    reasonController.dispose();
    if (result == null || !context.mounted) return;
    try {
      await SessionRescheduleService.requestReschedule(
        sessionId: sessionId,
        proposedDate: result['date'] as DateTime,
        proposedTime: result['time'] as String,
        reason: result['reason'] as String? ?? 'Reschedule requested',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reschedule request sent. The tutor will be notified.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinAgoraSession(BuildContext context, String sessionId) async {
    try {
      if (!LiveSessionTestConfig.canUserJoinSession(SupabaseService.currentUser?.id)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LiveSessionTestConfig.localTestingRestrictionMessage),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
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

      // Fetch tutor profile so chat shows tutor name (not "Unknown User")
      String? otherUserName;
      String? otherUserAvatarUrl;
      try {
        final tutorProfile = await supabase
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', tutorId)
            .maybeSingle();
        if (tutorProfile != null) {
          otherUserName = tutorProfile['full_name'] as String?;
          otherUserAvatarUrl = tutorProfile['avatar_url'] as String?;
        }
      } catch (_) {}

      // Create Conversation object with tutor display info for chat header
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
        otherUserName: otherUserName,
        otherUserAvatarUrl: otherUserAvatarUrl,
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
                
                // Action buttons: upcoming or in progress
                if (status == 'scheduled' || status == 'in_progress') ...[
                  const SizedBox(height: 24),
                  // Join button: inactive until session time, with countdown
                  if (location == 'online')
                    _JoinVideoButtonWithCountdown(
                      sessionId: sessionId,
                      status: status,
                      scheduledDate: scheduledDate,
                      scheduledTime: scheduledTime,
                      currentUserId: SupabaseService.currentUser?.id,
                      onJoin: () => _joinAgoraSession(context, sessionId),
                    ),
                  const SizedBox(height: 12),
                  // Message Tutor button (white, deep blue border + text)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToChat(context, session),
                      icon: Icon(PhosphorIcons.chatCircleDots(), size: 20, color: AppTheme.primaryColor),
                      label: Text(
                        'Message Tutor',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                // Past/completed sessions: Message Tutor + Request reschedule (if missed)
                if (status != 'scheduled' && status != 'in_progress' && status != 'cancelled') ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToChat(context, session),
                      icon: Icon(PhosphorIcons.chatCircleDots(), size: 20, color: AppTheme.primaryColor),
                      label: Text(
                        'Message Tutor',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Request reschedule for completed or missed sessions
                  Builder(
                    builder: (context) {
                      final start = _parseSessionDateTime(scheduledDate, scheduledTime);
                      final isPast = start != null && start.isBefore(DateTime.now());
                      final canReschedule = status == 'completed' || isPast;
                      if (!canReschedule) return const SizedBox.shrink();
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showRescheduleDialog(context, sessionId, scheduledDate, scheduledTime),
                          icon: Icon(PhosphorIcons.calendarPlus(), size: 20, color: AppTheme.primaryColor),
                          label: Text(
                            'Request reschedule',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    },
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

/// Join button disabled until session time; shows countdown when scheduled.
class _JoinVideoButtonWithCountdown extends StatefulWidget {
  final String sessionId;
  final String status;
  final String scheduledDate;
  final String scheduledTime;
  final String? currentUserId;
  final VoidCallback onJoin;

  const _JoinVideoButtonWithCountdown({
    required this.sessionId,
    required this.status,
    required this.scheduledDate,
    required this.scheduledTime,
    this.currentUserId,
    required this.onJoin,
  });

  @override
  State<_JoinVideoButtonWithCountdown> createState() => _JoinVideoButtonWithCountdownState();
}

class _JoinVideoButtonWithCountdownState extends State<_JoinVideoButtonWithCountdown> {
  static DateTime? _parseStart(String date, String time) {
    try {
      final dateTime = DateTime.tryParse(date);
      if (dateTime == null) return null;
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return DateTime(dateTime.year, dateTime.month, dateTime.day, hour, minute);
      }
      return dateTime;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {});
        _scheduleTick();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _parseStart(widget.scheduledDate, widget.scheduledTime);
    final now = DateTime.now();
    final inProgress = widget.status == 'in_progress';
    final allowedToJoin = LiveSessionTestConfig.canUserJoinSession(widget.currentUserId);
    final canJoin = allowedToJoin &&
        (inProgress ||
            (start != null && !now.isBefore(start)) ||
            LiveSessionTestConfig.isTestUser(widget.currentUserId));

    String countdownText = '';
    if (!inProgress && start != null && now.isBefore(start)) {
      final diff = start.difference(now);
      if (diff.inDays > 0) {
        countdownText = 'Starts in ${diff.inDays}d ${diff.inHours % 24}h';
      } else if (diff.inHours > 0) {
        countdownText = 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else if (diff.inMinutes > 0) {
        countdownText = 'Starts in ${diff.inMinutes} min';
      } else {
        countdownText = 'Starting soon';
      }
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (countdownText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                countdownText,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textMedium,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton.icon(
            onPressed: canJoin ? widget.onJoin : null,
            icon: Icon(PhosphorIcons.videoCamera(), size: 20),
            label: Text(
              widget.status == 'in_progress' ? 'Join Session' : 'Join Video Session',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canJoin
                  ? (widget.status == 'in_progress' ? AppTheme.accentGreen : AppTheme.primaryColor)
                  : Colors.grey[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
