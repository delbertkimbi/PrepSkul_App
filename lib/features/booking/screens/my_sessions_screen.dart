import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../services/individual_session_service.dart';
import '../services/session_feedback_service.dart';
import 'session_feedback_screen.dart';

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
      final upcoming = await IndividualSessionService.getStudentUpcomingSessions(
        limit: 50,
      );
      final past = await IndividualSessionService.getStudentPastSessions(
        limit: 50,
      );

      // Check feedback status for completed sessions
      for (final session in past) {
        if (session['status'] == 'completed') {
          final sessionId = session['id'] as String;
          final canSubmit = await SessionFeedbackService.canSubmitFeedback(
            sessionId,
          );
          _feedbackSubmitted[sessionId] = !canSubmit; // If can't submit, feedback already submitted
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sessions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        return 'In Progress';
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
    final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
    final tutorName = recurringData?['tutor_name'] as String? ?? 'Tutor';
    final tutorAvatar = recurringData?['tutor_avatar_url'] as String?;
    final subject = recurringData?['subject'] as String? ?? 'Session';
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
              if (isUpcoming && status == 'scheduled') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (location == 'online' && meetLink != null && meetLink.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _joinMeeting(meetLink),
                          icon: const Icon(Icons.video_call, size: 18),
                          label: Text('Join Meeting', style: GoogleFonts.poppins(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
    final tutorName = recurringData?['tutor_name'] as String? ?? 'Tutor';
    final subject = recurringData?['subject'] as String? ?? 'Session';
    final scheduledDate = session['scheduled_date'] as String;
    final scheduledTime = session['scheduled_time'] as String;
    final duration = session['duration_minutes'] as int? ?? 60;
    final location = session['location'] as String? ?? 'online';
    final meetLink = session['meeting_link'] as String?;
    final status = session['status'] as String;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Sessions',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
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

