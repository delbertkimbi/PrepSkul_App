import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:intl/intl.dart';

/// Tutor Session Detail Screen
///
/// Full page view of a session with student analysis from survey
class TutorSessionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const TutorSessionDetailScreen({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<TutorSessionDetailScreen> createState() => _TutorSessionDetailScreenState();
}

class _TutorSessionDetailScreenState extends State<TutorSessionDetailScreen> {
  Map<String, dynamic>? _studentSurvey;
  bool _isLoadingSurvey = true;

  @override
  void initState() {
    super.initState();
    _loadStudentSurvey();
  }

  Future<void> _loadStudentSurvey() async {
    try {
      final studentId = _getStudentId();
      if (studentId != null) {
        final survey = await SurveyRepository.getStudentSurvey(studentId);
        if (mounted) {
          safeSetState(() {
            _studentSurvey = survey;
            _isLoadingSurvey = false;
          });
        }
      } else {
        safeSetState(() => _isLoadingSurvey = false);
      }
    } catch (e) {
      LogService.warning('Error loading student survey: $e');
      if (mounted) {
        safeSetState(() => _isLoadingSurvey = false);
      }
    }
  }

  String? _getStudentId() {
    // Try different ways to get student ID from session data
    if (widget.session.containsKey('student_id')) {
      return widget.session['student_id'] as String?;
    }
    if (widget.session.containsKey('recurring_sessions')) {
      final recurring = widget.session['recurring_sessions'] as Map<String, dynamic>?;
      return recurring?['student_id'] as String?;
    }
    return null;
  }

  String _getStudentName() {
    if (widget.session.containsKey('recurring_sessions')) {
      final recurring = widget.session['recurring_sessions'] as Map<String, dynamic>?;
      return recurring?['student_name']?.toString() ?? 'Student';
    }
    return widget.session['student_name']?.toString() ?? 'Student';
  }

  @override
  Widget build(BuildContext context) {
    final isIndividualSession = widget.session.containsKey('scheduled_date') &&
        widget.session.containsKey('scheduled_time');
    
    String studentName = _getStudentName();
    String location = widget.session['location'] as String? ?? 'online';
    String? address = widget.session['onsite_address'] as String? ?? widget.session['address'] as String?;
    DateTime? sessionDate;
    String? sessionTime;
    String? subject = widget.session['subject'] as String?;
    int? frequency;
    List<String> days = [];
    Map<String, String> times = {};
    double? monthlyTotal;
    String? paymentPlan;
    String status = widget.session['status'] as String? ?? 'scheduled';

    if (isIndividualSession) {
      final recurringData = widget.session['recurring_sessions'] as Map<String, dynamic>?;
      sessionDate = DateTime.parse(widget.session['scheduled_date'] as String);
      sessionTime = widget.session['scheduled_time'] as String?;
      
      if (recurringData != null) {
        frequency = recurringData['frequency'] as int?;
        days = List<String>.from(recurringData['days'] as List? ?? []);
        times = Map<String, String>.from(recurringData['times'] as Map? ?? {});
        monthlyTotal = (recurringData['monthly_total'] as num?)?.toDouble();
        paymentPlan = recurringData['payment_plan'] as String?;
      }
    } else {
      frequency = widget.session['frequency'] as int?;
      days = List<String>.from(widget.session['days'] as List? ?? []);
      times = Map<String, String>.from(widget.session['times'] as Map? ?? {});
      monthlyTotal = (widget.session['monthly_total'] as num?)?.toDouble();
      paymentPlan = widget.session['payment_plan'] as String?;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Session Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _buildStatusBanner(status),
            const SizedBox(height: 24),

            // Student Card
            _buildStudentCard(studentName),
            const SizedBox(height: 24),

            // Student Analysis (from survey)
            if (_studentSurvey != null) ...[
              _buildStudentAnalysisCard(),
              const SizedBox(height: 24),
            ] else if (!_isLoadingSurvey) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Student survey information not available',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Schedule Card
            _buildScheduleCard(
              isIndividualSession: isIndividualSession,
              sessionDate: sessionDate,
              sessionTime: sessionTime,
              frequency: frequency,
              days: days,
              times: times,
            ),
            const SizedBox(height: 20),

            // Location Card
            _buildLocationCard(location: location, address: address),
            const SizedBox(height: 20),

            // Subject Card (if available)
            if (subject != null) ...[
              _buildSubjectCard(subject),
              const SizedBox(height: 20),
            ],

            // Revenue Card (if available)
            if (monthlyTotal != null && paymentPlan != null) ...[
              _buildRevenueCard(monthlyTotal: monthlyTotal, paymentPlan: paymentPlan),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        statusColor = Colors.blue;
        statusIcon = Icons.event;
        statusText = 'SCHEDULED';
        break;
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
        statusColor = Colors.orange;
        statusIcon = Icons.play_circle;
        statusText = 'IN PROGRESS';
        break;
      case 'COMPLETED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'COMPLETED';
        break;
      case 'CANCELLED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'CANCELLED';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = status.toUpperCase();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Text(
            'Status: $statusText',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(String studentName) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Colors.blue[100],
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'STUDENT',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAnalysisCard() {
    if (_studentSurvey == null) return const SizedBox.shrink();
    
    final survey = _studentSurvey!;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue[200]!, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.psychology, color: Colors.blue[700], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Student Analysis',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Learning Path
            if (survey['learning_path'] != null) ...[
              _buildAnalysisRow(Icons.trending_up, 'Learning Path', survey['learning_path'].toString()),
              const SizedBox(height: 12),
            ],
            
            // Education Level
            if (survey['education_level'] != null) ...[
              _buildAnalysisRow(Icons.school, 'Education Level', survey['education_level'].toString()),
              const SizedBox(height: 12),
            ],
            
            // Subjects of Interest
            if (survey['subjects_of_interest'] != null) ...[
              _buildListAnalysisRow(Icons.menu_book, 'Subjects of Interest', survey['subjects_of_interest']),
              const SizedBox(height: 12),
            ],
            
            // Learning Goals
            if (survey['learning_goals'] != null) ...[
              _buildListAnalysisRow(Icons.flag, 'Learning Goals', survey['learning_goals']),
              const SizedBox(height: 12),
            ],
            
            // Challenges
            if (survey['challenges'] != null) ...[
              _buildListAnalysisRow(Icons.help_outline, 'Challenges', survey['challenges']),
              const SizedBox(height: 12),
            ],
            
            // Learning Style
            if (survey['learning_styles'] != null || survey['learning_style'] != null) ...[
              _buildListAnalysisRow(Icons.style, 'Learning Style', survey['learning_styles'] ?? survey['learning_style']),
              const SizedBox(height: 12),
            ],
            
            // Confidence Level
            if (survey['confidence_level'] != null) ...[
              _buildAnalysisRow(Icons.sentiment_satisfied, 'Confidence Level', survey['confidence_level'].toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListAnalysisRow(IconData icon, String label, dynamic data) {
    String text = '';
    if (data is List && data.isNotEmpty) {
      text = data.join(', ');
    } else if (data is String && data.isNotEmpty) {
      text = data;
    }
    
    if (text.isEmpty) return const SizedBox.shrink();
    
    return _buildAnalysisRow(icon, label, text);
  }

  Widget _buildScheduleCard({
    required bool isIndividualSession,
    DateTime? sessionDate,
    String? sessionTime,
    int? frequency,
    required List<String> days,
    required Map<String, String> times,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isIndividualSession && sessionDate != null) ...[
              _buildDetailRow(Icons.calendar_today, 'Date', DateFormat('EEEE, MMMM d, y').format(sessionDate)),
              if (sessionTime != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(Icons.access_time, 'Time', _formatTime(sessionTime)),
              ],
            ] else ...[
              if (frequency != null)
                _buildDetailRow(Icons.event_repeat, 'Frequency', '$frequency sessions per week'),
              if (days.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(Icons.calendar_today, 'Days', days.join(', ')),
              ],
              if (times.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Session Times',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 12),
                ...times.entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[100]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(entry.value),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard({required String location, String? address}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.location_on, 'Location', location.toUpperCase()),
            if (address != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(Icons.home, 'Address', address),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(String subject) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildDetailRow(Icons.menu_book, 'Subject', subject),
      ),
    );
  }

  Widget _buildRevenueCard({required double monthlyTotal, required String paymentPlan}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green[50]!,
              Colors.green[100]!.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildDetailRow(Icons.attach_money, 'Monthly Revenue', '${monthlyTotal.toStringAsFixed(0)} XAF', iconColor: Colors.green[700]),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.payment, 'Payment Plan', paymentPlan.toUpperCase(), iconColor: Colors.green[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    try {
      if (time.contains('AM') || time.contains('PM')) {
        return time; // Already formatted
      }
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
      }
      return time;
    } catch (e) {
      return time;
    }
  }
}
