import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../services/individual_session_service.dart';
import '../services/session_feedback_service.dart';
import 'session_feedback_screen.dart';
// TODO: Fix import path
// import 'package:prepskul/features/sessions/services/session_transcript_service.dart';
// TODO: Fix import path
// import 'package:prepskul/features/sessions/screens/session_summary_screen.dart';
import 'package:prepskul/features/sessions/widgets/session_location_map.dart';
import 'package:prepskul/core/services/auth_service.dart';
import '../../../core/localization/app_localizations.dart';

/// My Sessions Screen
///
/// Allows students/parents to view their upcoming and completed sessions
/// Shows feedback prompts for completed sessions
class MySessionsScreen extends StatefulWidget {
  const MySessionsScreen({Key? key}) : super(key: key);

  @override
  State<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends State<MySessionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _upcomingSessions = [];
  List<Map<String, dynamic>> _pastSessions = [];
  bool _isLoading = true;
  final Map<String, bool> _feedbackSubmitted = {}; // Cache feedback status
  final Map<String, bool> _hasTranscript = {}; // Cache transcript availability

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      // 1. Fetch Individual Sessions (Normal recurring sessions)
      try {
        final indUpcoming = await IndividualSessionService.getStudentUpcomingSessions(limit: 50);
        final indPast = await IndividualSessionService.getStudentPastSessions(limit: 50);
        upcoming.addAll(indUpcoming);
        past.addAll(indPast);
      } catch (e) {
        // Gracefully handle missing table or other errors
        print('ℹ️ Could not load individual sessions (table might not exist yet): $e');
      }

      // 2. Fetch Trial Sessions (only those not yet converted to full sessions)
      try {
        final trialSessions = await TrialSessionService.getStudentTrialSessions();

        for (final trial in trialSessions) {
          final sessionMap = _convertTrialToSessionMap(trial);
          if (sessionMap != null) {
            // Classify as upcoming or past based on status and date
            final status = sessionMap['status'];
            final date = DateTime.parse(sessionMap['scheduled_date']);
            final isPast = status == 'completed' || 
                           status == 'cancelled' || 
                           status == 'rejected' ||
                           (date.isBefore(DateTime.now()) && status != 'scheduled');
            
            if (isPast) {
              past.add(sessionMap);
            } else {
              upcoming.add(sessionMap);
            }
          }
        }
      } catch (e) {
        print('⚠️ Error loading trial sessions: $e');
      }

      // Sort combined lists
      upcoming.sort((a, b) {
        final dateA = DateTime.parse(a['scheduled_date']);
        final dateB = DateTime.parse(b['scheduled_date']);
        return dateA.compareTo(dateB);
      });
      
      past.sort((a, b) {
        final dateA = DateTime.parse(a['scheduled_date']);
        final dateB = DateTime.parse(b['scheduled_date']);
        return dateB.compareTo(dateA); // Descending for past
      });

      // Check feedback status and transcript availability for completed sessions
      for (final session in past) {
        if (session['status'] == 'completed') {
          final sessionId = session['id'] as String;
          final sessionType = session['type'] as String? ?? 'individual';
          
          // Check feedback status
          if (sessionType == 'individual') {
            final canSubmit = await SessionFeedbackService.canSubmitFeedback(
              sessionId,
            );
            _feedbackSubmitted[sessionId] = !canSubmit;
          }
          
          // Check transcript availability
          bool hasTranscript = false;
          if (sessionType == 'individual') {
            // hasTranscript = await SessionTranscriptService.hasIndividualSessionTranscript(sessionId);
          } else if (sessionType == 'trial') {
            // hasTranscript = await SessionTranscriptService.hasTranscript(sessionId, 'trial');
          }
          _hasTranscript[sessionId] = hasTranscript;
        }
      }

      setState(() {
        _upcomingSessions = upcoming;
        _pastSessions = past;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading sessions: $e');
      setState(() => _isLoading = false);
      // Only show error if we have absolutely nothing to show
      if (_upcomingSessions.isEmpty && _pastSessions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load sessions. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    }
  }

  Map<String, dynamic>? _convertTrialToSessionMap(TrialSession trial) {
    // Convert TrialSession object to the Map format used by _buildSessionCard
    // Returns null if the trial shouldn't be shown (e.g., rejected/cancelled might be hidden if old?)
    // For now, we show everything.
    
    // Skip pending/rejected trials if we want to keep the list clean? 
    // Usually users want to see pending requests too.
    
    return {
      'id': trial.id,
      'status': trial.status,
      'scheduled_date': trial.scheduledDate.toIso8601String(),
      'scheduled_time': trial.scheduledTime,
      'location': trial.location,
      'duration_minutes': trial.durationMinutes,
      'type': 'trial', // Mark as trial
      // Simulate the nested structure expected by UI
      'recurring_sessions': {
        'tutor_name': 'Tutor', // We might need to fetch tutor name if not in TrialSession model
        // Note: TrialSession model might not have tutor name directly if it's just ID.
        // TrialSessionService.getStudentTrialSessions returns TrialSession objects.
        // The TrialSession model has tutorId but maybe not name?
        // We might need to fetch profiles or rely on what's available.
        // Let's check TrialSession model properties.
        // Assuming we can't easily get the name without a join, we'll use a placeholder or fetch it.
        // For now, let's try to use what we have.
        'subject': trial.subject,
        'tutor_avatar_url': null, // Placeholder
      },
      // Add meeting link if available (generated after payment)
      'meeting_link': trial.meetLink,
    };
  }

  String _formatDateTime(String date, String time) {
    try {
      final dateTime = DateTime.parse(date);
      final formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
      return '$formattedDate at $time';
    } catch (e) {
      return '$date at $time';
    }
  }

  String _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return '#4CAF50'; // Green
      case 'in_progress':
        return '#2196F3'; // Blue
      case 'completed':
        return '#9E9E9E'; // Gray
      case 'cancelled':
        return '#F44336'; // Red
      default:
        return '#757575'; // Gray
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
      default:
        return status;
    }
  }

  Future<void> _openFeedbackScreen(String sessionId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFeedbackScreen(sessionId: sessionId),
      ),
    );

    // Reload sessions if feedback was submitted
    if (result == true) {
      _loadSessions();
    }
  }

  Future<void> _openSessionSummary(Map<String, dynamic> session) async {
    final sessionId = session['id'] as String;
    final sessionType = session['type'] as String? ?? 'individual';
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDialog(
          title: Text('Session Summary'),
          content: Text('Feature coming soon'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinMeeting(String? meetLink) async {
    if (meetLink == null || meetLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meeting link not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(meetLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch meeting link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSessionCard(Map<String, dynamic> session, bool isUpcoming) {
    final isTrial = session['type'] == 'trial';
    final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
    // For trial sessions, we might not have tutor name immediately if not joined.
    // But TrialSessionService.getStudentTrialSessions does a simple select.
    // We should ideally do a join there too.
    final tutorName = recurringData?['tutor_name'] as String? ?? (isTrial ? 'Trial Tutor' : 'Tutor');
    final tutorAvatar = recurringData?['tutor_avatar_url'] as String?;
    final subject = recurringData?['subject'] as String? ?? session['subject'] as String? ?? 'Session';
    final status = session['status'] as String;
    final scheduledDate = session['scheduled_date'] as String;
    final scheduledTime = session['scheduled_time'] as String;
    final location = session['location'] as String? ?? 'online';
    final meetLink = session['meeting_link'] as String?;
    final sessionId = session['id'] as String;
    final isCompleted = status == 'completed';
    final hasFeedback = _feedbackSubmitted[sessionId] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Show session details
          _showSessionDetails(session);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trial Badge
              if (isTrial)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    'TRIAL SESSION',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                      letterSpacing: 1,
                    ),
                  ),
                ),
              // Header: Tutor info and status
              Row(
                children: [
                  // Tutor avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: tutorAvatar != null && tutorAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(tutorAvatar)
                        : null,
                    child: tutorAvatar == null || tutorAvatar.isEmpty
                        ? Text(
                            tutorName.isNotEmpty ? tutorName[0].toUpperCase() : 'T',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Tutor name and subject
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutorName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(int.parse(_getStatusColor(status).replaceFirst('#', '0xFF'))).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(int.parse(_getStatusColor(status).replaceFirst('#', '0xFF'))),
                      ),
                    ),
                  ),
                ],
              ),
              // Session in Progress indicator
              if (status == 'in_progress') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.accentGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        color: AppTheme.accentGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Session is currently in progress',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              // Date and time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    _formatDateTime(scheduledDate, scheduledTime),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Location
              Row(
                children: [
                  Icon(
                    location == 'online' ? Icons.video_call : Icons.location_on,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    location == 'online' ? 'Online' : 'On-site',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              // Action buttons
              if (isUpcoming && (status == 'scheduled' || status == 'in_progress')) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (location == 'online' && meetLink != null && meetLink.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _joinMeeting(meetLink),
                          icon: Icon(
                            status == 'in_progress' ? Icons.video_call : Icons.video_call,
                            size: 18,
                          ),
                          label: Text(
                            status == 'in_progress' ? 'Join Session' : 'Join Meeting',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status == 'in_progress' 
                                ? AppTheme.accentGreen 
                                : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              // Feedback prompt for completed sessions
              if (isCompleted) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasFeedback
                        ? Colors.green[50]
                        : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasFeedback
                          ? Colors.green[200]!
                          : AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasFeedback ? Icons.check_circle : Icons.feedback,
                        color: hasFeedback ? Colors.green[700] : AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasFeedback ? 'Feedback Submitted' : 'Share Your Feedback',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: hasFeedback ? Colors.green[900] : Colors.black87,
                              ),
                            ),
                            if (!hasFeedback)
                              Text(
                                'Help us improve by rating your session',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!hasFeedback)
                        TextButton(
                          onPressed: () => _openFeedbackScreen(sessionId),
                          child: Text(
                            'Submit',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Session Summary button for completed online sessions
                if (isCompleted && _hasTranscript[sessionId] == true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openSessionSummary(session),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('View Session Summary'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDetails(Map<String, dynamic> session) async {
    final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
    final tutorName = recurringData?['tutor_name'] as String? ?? 'Tutor';
    final subject = recurringData?['subject'] as String? ?? 'Session';
    final scheduledDate = session['scheduled_date'] as String;
    final scheduledTime = session['scheduled_time'] as String;
    final duration = session['duration_minutes'] as int? ?? 60;
    final location = session['location'] as String? ?? 'online';
    final meetLink = session['meeting_link'] as String?;
    final status = session['status'] as String;
    final sessionId = session['id'] as String;
    final onsiteAddress = session['onsite_address'] as String?;
    
    // Get current user info for check-in
    String? currentUserId;
    String? userType;
    try {
      final userProfile = await AuthService.getUserProfile();
      currentUserId = userProfile?['id'] as String?;
      userType = userProfile?['user_type'] as String?;
    } catch (e) {
      print('⚠️ Error getting user profile: \$e');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Session Details',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Tutor', tutorName),
              _buildDetailRow('Subject', subject),
              _buildDetailRow('Date & Time', _formatDateTime(scheduledDate, scheduledTime)),
              _buildDetailRow('Duration', '$duration minutes'),
              _buildDetailRow('Location', location == 'online' ? 'Online' : 'On-site'),
              _buildDetailRow('Status', _getStatusLabel(status)),
              // Location map for onsite sessions
              if (location == 'onsite' && onsiteAddress != null && onsiteAddress.isNotEmpty) ...[
                const SizedBox(height: 16),
                SessionLocationMap(
                  address: onsiteAddress,
                  coordinates: null, // Could be extracted from address if available
                  sessionId: sessionId,
                  currentUserId: currentUserId,
                  userType: userType,
                  showCheckIn: status == 'scheduled' || status == 'in_progress',
                ),
              ],
              
                            if (location == 'online' && meetLink != null && meetLink.isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _joinMeeting(meetLink);
                  },
                  icon: const Icon(Icons.video_call, size: 18),
                  label: Text('Join Meeting', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.mySessionsTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Upcoming Sessions
                _upcomingSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Upcoming Sessions',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Book a session to get started',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSessions,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _upcomingSessions.length,
                          itemBuilder: (context, index) {
                            return _buildSessionCard(
                              _upcomingSessions[index],
                              true,
                            );
                          },
                        ),
                      ),
                // Completed Sessions
                _pastSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Completed Sessions',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your completed sessions will appear here',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSessions,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _pastSessions.length,
                          itemBuilder: (context, index) {
                            return _buildSessionCard(
                              _pastSessions[index],
                              false,
                            );
                          },
                        ),
                      ),
              ],
            ),
    );
  }
}

