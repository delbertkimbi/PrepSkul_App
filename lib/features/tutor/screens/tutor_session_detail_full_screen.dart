import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../features/booking/services/individual_session_service.dart';
import '../../../features/booking/services/trial_session_service.dart';
import '../../../features/booking/services/session_lifecycle_service.dart';
import '../../../features/booking/models/trial_session_model.dart';
import '../../../features/booking/services/session_reschedule_service.dart';
import '../../../features/sessions/services/meet_service.dart';
import '../../../features/sessions/screens/agora_video_session_screen.dart';
import '../../../features/sessions/widgets/session_location_map.dart';
import '../../../features/sessions/services/location_checkin_service.dart';
import '../../../core/widgets/image_picker_bottom_sheet.dart';

/// Full-screen detail view for tutor sessions
/// Profile-like UI with all session details and action buttons at the bottom
class TutorSessionDetailFullScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const TutorSessionDetailFullScreen({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<TutorSessionDetailFullScreen> createState() =>
      _TutorSessionDetailFullScreenState();
}

class _TutorSessionDetailFullScreenState
    extends State<TutorSessionDetailFullScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _sessionData;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    setState(() => _isLoading = true);
    try {
      _sessionData = widget.session;
    } catch (e) {
      LogService.error('Error loading session data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Refetch session status from DB after start/end so UI updates.
  Future<void> _refreshSessionStatus() async {
    final sessionId = _getSessionId();
    final isIndividual = _isIndividualSession();
    try {
      if (isIndividual) {
        final row = await SupabaseService.client
            .from('individual_sessions')
            .select('status')
            .eq('id', sessionId)
            .maybeSingle();
        if (row != null && mounted && _sessionData != null) {
          setState(() => _sessionData = {..._sessionData!, 'status': row['status']});
        }
      } else {
        final row = await SupabaseService.client
            .from('trial_sessions')
            .select('status')
            .eq('id', sessionId)
            .maybeSingle();
        if (row != null && mounted && _sessionData != null) {
          setState(() => _sessionData = {..._sessionData!, 'status': row['status']});
        }
      }
    } catch (e) {
      LogService.warning('Could not refresh session status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _sessionData == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Session Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Session Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Profile Section
                  _buildStudentProfileSection(),
                  const SizedBox(height: 32),

                  // Session Details Section
                  _buildSectionTitle('Session Details'),
                  const SizedBox(height: 16),
                  _buildSessionDetailsCard(),

                  const SizedBox(height: 24),

                  // Schedule Section (if recurring)
                  if (!_isIndividualSession()) ...[
                    _buildSectionTitle('Schedule'),
                    const SizedBox(height: 16),
                    _buildScheduleCard(),
                    const SizedBox(height: 24),
                  ],

                  // Location Section
                  _buildSectionTitle('Location'),
                  const SizedBox(height: 16),
                  _buildLocationCard(),

                  const SizedBox(height: 24),

                  // Payment Section (if available)
                  if (_getMonthlyTotal() != null) ...[
                    _buildSectionTitle('Payment'),
                    const SizedBox(height: 16),
                    _buildPaymentCard(),
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons at the bottom
          if (_shouldShowActions()) _buildActionButtons(),
        ],
      ),
    );
  }

  bool _isIndividualSession() {
    final sessionType = _sessionData!['_sessionType'] as String?;
    return sessionType == 'individual' ||
        (_sessionData!.containsKey('scheduled_date') &&
            _sessionData!.containsKey('scheduled_time') &&
            sessionType != 'trial');
  }

  bool _isTrialSession() {
    return _sessionData!['_sessionType'] == 'trial';
  }

  String _getStudentName() {
    if (_isTrialSession()) {
      return _sessionData!['student_name'] as String? ?? 'Student';
    } else if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      return recurringData?['student_name']?.toString() ?? 'Student';
    } else {
      return _sessionData!['student_name'] as String? ?? 'Student';
    }
  }

  String? _getStudentAvatar() {
    if (_isTrialSession()) {
      return _sessionData!['student_avatar_url'] as String?;
    } else if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      return recurringData?['student_avatar_url']?.toString();
    } else {
      return _sessionData!['student_avatar_url'] as String?;
    }
  }

  String _getStatus() {
    return _sessionData!['status'] as String? ?? 'scheduled';
  }

  String? _getSubject() {
    if (_isTrialSession()) {
      try {
        final trial = TrialSession.fromJson(_sessionData!);
        return trial.subject;
      } catch (e) {
        return _sessionData!['subject'] as String?;
      }
    } else {
      return _sessionData!['subject'] as String?;
    }
  }

  DateTime? _getSessionDate() {
    if (_isTrialSession()) {
      try {
        final trial = TrialSession.fromJson(_sessionData!);
        return trial.scheduledDate;
      } catch (e) {
        final dateStr = _sessionData!['scheduled_date'] as String?;
        return dateStr != null ? DateTime.parse(dateStr) : null;
      }
    } else {
      final dateStr = _sessionData!['scheduled_date'] as String?;
      return dateStr != null ? DateTime.parse(dateStr) : null;
    }
  }

  String? _getSessionTime() {
    if (_isTrialSession()) {
      try {
        final trial = TrialSession.fromJson(_sessionData!);
        return trial.scheduledTime;
      } catch (e) {
        return _sessionData!['scheduled_time'] as String?;
      }
    } else {
      return _sessionData!['scheduled_time'] as String?;
    }
  }

  String _getLocation() {
    if (_isTrialSession()) {
      try {
        final trial = TrialSession.fromJson(_sessionData!);
        return trial.location;
      } catch (e) {
        return _sessionData!['location'] as String? ?? 'online';
      }
    } else {
      return _sessionData!['location'] as String? ?? 'online';
    }
  }

  String? _getAddress() {
    if (_isTrialSession()) {
      return null; // Trial sessions don't have address
    } else {
      return _sessionData!['address'] as String? ??
          _sessionData!['onsite_address'] as String?;
    }
  }

  String? _getMeetLink() {
    if (_isTrialSession()) {
      return _sessionData!['meet_link'] as String?;
    } else {
      return _sessionData!['meeting_link'] as String?;
    }
  }

  double? _getMonthlyTotal() {
    if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      final total = recurringData?['monthly_total'];
      return total != null ? (total as num).toDouble() : null;
    } else {
      final total = _sessionData!['monthly_total'];
      return total != null ? (total as num).toDouble() : null;
    }
  }

  String? _getPaymentPlan() {
    if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      return recurringData?['payment_plan'] as String?;
    } else {
      return _sessionData!['payment_plan'] as String?;
    }
  }

  int? _getFrequency() {
    if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      return recurringData?['frequency'] as int?;
    } else {
      return _sessionData!['frequency'] as int?;
    }
  }

  List<String> _getDays() {
    if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      return List<String>.from(recurringData?['days'] as List? ?? []);
    } else {
      return List<String>.from(_sessionData!['days'] as List? ?? []);
    }
  }

  Map<String, String> _getTimes() {
    if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      return Map<String, String>.from(recurringData?['times'] as Map? ?? {});
    } else {
      return Map<String, String>.from(_sessionData!['times'] as Map? ?? {});
    }
  }

  DateTime? _getStartDate() {
    if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      final dateStr = recurringData?['start_date'] as String?;
      return dateStr != null ? DateTime.parse(dateStr) : null;
    } else {
      final dateStr = _sessionData!['start_date'] as String?;
      return dateStr != null ? DateTime.parse(dateStr) : null;
    }
  }

  int _getTotalSessionsCompleted() {
    if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      return recurringData?['total_sessions_completed'] as int? ?? 0;
    } else {
      return _sessionData!['total_sessions_completed'] as int? ?? 0;
    }
  }

  String _getSessionId() {
    return _sessionData!['id'] as String;
  }

  /// Combined date and time for check-in window (presence 1h before–2h after).
  DateTime? _getScheduledDateTime() {
    final d = _getSessionDate();
    final t = _getSessionTime();
    if (d == null || t == null) return null;
    final parts = t.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0].trim()) ?? 0) : 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1].trim().split(' ').first) ?? 0) : 0;
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case 'approved':
        return AppTheme.primaryColor;
      case 'in_progress':
      case 'active':
        return AppTheme.accentGreen;
      case 'completed':
        return AppTheme.textMedium;
      case 'cancelled':
      case 'expired':
        return Colors.red;
      default:
        return AppTheme.textMedium;
    }
  }

  Widget _buildStudentProfileSection() {
    final studentName = _getStudentName();
    final studentAvatar = _getStudentAvatar();
    final status = _getStatus();
    final statusColor = _getStatusColor(status);

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          backgroundImage: studentAvatar != null && studentAvatar.isNotEmpty
              ? CachedNetworkImageProvider(studentAvatar)
              : null,
          child: studentAvatar == null || studentAvatar.isEmpty
              ? Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 20),
        Text(
          studentName,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Student',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildSessionDetailsCard() {
    final subject = _getSubject();
    final sessionDate = _getSessionDate();
    final sessionTime = _getSessionTime();
    final frequency = _getFrequency();
    final totalSessions = _getTotalSessionsCompleted();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject != null)
            _buildInfoRow(
              Icons.book_outlined,
              'Subject',
              subject,
            ),
          if (_isIndividualSession() && sessionDate != null) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              DateFormat('MMM d, yyyy').format(sessionDate),
            ),
          ],
          if (_isIndividualSession() && sessionTime != null) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.access_time,
              'Time',
              sessionTime!,
            ),
          ],
          if (!_isIndividualSession() && frequency != null) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.repeat,
              'Frequency',
              '$frequency sessions per week',
            ),
          ],
          if (!_isIndividualSession() && totalSessions > 0) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.check_circle_outline,
              'Completed',
              '$totalSessions sessions',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    final days = _getDays();
    final times = _getTimes();
    final startDate = _getStartDate();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (days.isNotEmpty) ...[
            _buildInfoRow(
              Icons.calendar_view_week,
              'Days',
              days.join(', '),
            ),
            const SizedBox(height: 16),
          ],
          if (times.isNotEmpty) ...[
            _buildInfoRow(
              Icons.schedule,
              'Times',
              times.values.join(', '),
            ),
            const SizedBox(height: 16),
          ],
          if (startDate != null)
            _buildInfoRow(
              Icons.play_arrow,
              'Started',
              DateFormat('MMM d, yyyy').format(startDate!),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final location = _getLocation();
    final address = _getAddress();
    final meetLink = _getMeetLink();
    final isOnline = location == 'online';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            isOnline ? Icons.video_call : Icons.location_on,
            'Type',
            isOnline ? 'Online Session' : 'On-site Session',
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.place,
              'Address',
              address,
            ),
            // Onsite check-in / check-out and safety (tutor session detail)
            if (!isOnline && _shouldShowActions()) ...[
              const SizedBox(height: 16),
              SessionLocationMap(
                address: address,
                coordinates: null,
                sessionId: _getSessionId(),
                currentUserId: SupabaseService.client.auth.currentUser?.id,
                userType: 'tutor',
                showCheckIn: true,
                scheduledDateTime: _getScheduledDateTime(),
                locationType: 'onsite',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _handleUploadSelfie(_getSessionId()),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(
                  'Upload Selfie',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
          if (isOnline && meetLink != null && meetLink.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.link, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting Link',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _joinOrStartAndOpenVideo(),
                        child: Text(
                          'Join Meeting',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    final monthlyTotal = _getMonthlyTotal();
    final paymentPlan = _getPaymentPlan();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paymentPlan != null)
            _buildInfoRow(
              Icons.payment,
              'Payment Plan',
              _formatPaymentPlan(paymentPlan),
            ),
          if (monthlyTotal != null) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.attach_money,
              'Monthly Total',
              _formatCurrency(monthlyTotal!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldShowActions() {
    final status = _getStatus();
    return status == 'scheduled' || status == 'in_progress';
  }

  Widget _buildActionButtons() {
    final status = _getStatus();
    final location = _getLocation();
    final meetLink = _getMeetLink();
    final sessionId = _getSessionId();
    final isIndividual = _isIndividualSession();
    final isOnline = location == 'online';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Start & Join (scheduled + online) or Join (in_progress + online)
          if (isOnline && (status == 'scheduled' || (status == 'in_progress' && meetLink != null && meetLink.isNotEmpty)))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _joinOrStartAndOpenVideo(),
                icon: const Icon(Icons.video_call, size: 20),
                label: Text(
                  status == 'scheduled' ? 'Start & Join Session' : 'Join Session',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          // Start Session (scheduled + onsite)
          if (status == 'scheduled' && !isOnline)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _startSessionFromDetail(),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text(
                  'Start Session',
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
          // End Session (in_progress)
          if (status == 'in_progress')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _handleEndSession(),
                  icon: const Icon(Icons.stop, size: 20),
                  label: Text(
                    'End Session',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          if (status == 'scheduled' || status == 'in_progress') ...[
            if (status == 'in_progress' || status == 'scheduled') const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReschedule(sessionId, isIndividual),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      'Reschedule',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleCancel(sessionId, isIndividual),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startSessionFromDetail() async {
    final sessionId = _getSessionId();
    final isIndividual = _isIndividualSession();
    final isOnline = _getLocation() == 'online';
    setState(() => _isLoading = true);
    try {
      if (isIndividual) {
        await SessionLifecycleService.startSession(sessionId, isOnline: isOnline);
      } else {
        await TrialSessionService.startTrialSessionAsTutor(sessionId, isOnline: isOnline);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Session started', style: GoogleFonts.poppins()),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _refreshSessionStatus();
      }
    } catch (e) {
      LogService.error('Error starting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinOrStartAndOpenVideo() async {
    final sessionId = _getSessionId();
    final status = _getStatus();
    final isIndividual = _isIndividualSession();
    final isOnline = _getLocation() == 'online';
    setState(() => _isLoading = true);
    try {
      if (status == 'scheduled') {
        if (isIndividual) {
          await SessionLifecycleService.startSession(sessionId, isOnline: true);
        } else {
          await TrialSessionService.startTrialSessionAsTutor(sessionId, isOnline: true);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Session started', style: GoogleFonts.poppins()),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AgoraVideoSessionScreen(
              sessionId: sessionId,
              userRole: 'tutor',
            ),
          ),
        ).then((_) => _refreshSessionStatus());
      }
    } catch (e) {
      LogService.error('Error joining session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEndSession() async {
    final sessionId = _getSessionId();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final notesController = TextEditingController();
        return AlertDialog(
          title: Text('End Session', style: GoogleFonts.poppins()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add optional notes about this session:',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'E.g., "Great progress on algebra today!"',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('End Session', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    setState(() => _isLoading = true);
    try {
      await SessionLifecycleService.endSession(
        sessionId,
        tutorNotes: result['notes'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Session ended', style: GoogleFonts.poppins()),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _refreshSessionStatus();
      }
    } catch (e) {
      LogService.error('Error ending session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUploadSelfie(String sessionId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final pickedFile = await showModalBottomSheet<dynamic>(
        context: context,
        builder: (context) => const ImagePickerBottomSheet(),
        isScrollControlled: true,
      );
      if (pickedFile == null || !mounted) return;
      setState(() => _isLoading = true);
      final result = await LocationCheckInService.uploadPresenceSelfie(
        sessionId: sessionId,
        userId: userId,
        userType: 'tutor',
        selfieFile: pickedFile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Selfie uploaded'),
          backgroundColor: result['success'] == true ? AppTheme.accentGreen : Colors.red,
        ),
      );
    } catch (e) {
      LogService.error('Error uploading selfie: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload selfie: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinMeeting(String meetLink) async {
    try {
      final uri = Uri.parse(meetLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LogService.success('Opened Meet link: $meetLink');
      } else {
        throw Exception('Could not launch meeting link');
      }
    } catch (e) {
      LogService.error('Error opening meeting: $e');
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

  Future<void> _handleReschedule(String sessionId, bool isIndividual) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RescheduleSessionDialog(
        sessionId: sessionId,
        isIndividualSession: isIndividual,
      ),
    );

    if (result != null && result['confirmed'] == true) {
      setState(() => _isLoading = true);
      try {
        await SessionRescheduleService.requestReschedule(
          sessionId: sessionId,
          proposedDate: result['proposedDate'] as DateTime,
          proposedTime: result['proposedTime'] as String,
          reason: result['reason'] as String? ?? 'Reschedule requested by tutor',
          additionalNotes: result['additionalNotes'] as String?,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reschedule request sent. Waiting for student approval.',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true); // Return to refresh
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reschedule: $e', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleCancel(String sessionId, bool isIndividual) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CancelSessionDialog(),
    );

    if (result != null && result['confirmed'] == true) {
      setState(() => _isLoading = true);
      try {
        if (isIndividual) {
          await IndividualSessionService.cancelSession(
            sessionId,
            reason: result['reason'] as String? ?? 'Cancelled by tutor',
          );
        } else {
          // For trial sessions, use TrialSessionService
          await TrialSessionService.cancelApprovedTrialSession(
            sessionId: sessionId,
            cancellationReason: result['reason'] as String? ?? 'Cancelled by tutor',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Session cancelled', style: GoogleFonts.poppins()),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          Navigator.pop(context, true); // Return to refresh
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel session: $e', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String _formatPaymentPlan(String plan) {
    switch (plan.toLowerCase()) {
      case 'monthly':
        return 'Monthly';
      case 'biweekly':
        return 'Bi-weekly';
      case 'weekly':
        return 'Weekly';
      default:
        return plan;
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} XAF';
  }
}

// Reschedule Session Dialog
class _RescheduleSessionDialog extends StatefulWidget {
  final String sessionId;
  final bool isIndividualSession;

  const _RescheduleSessionDialog({
    required this.sessionId,
    required this.isIndividualSession,
  });

  @override
  State<_RescheduleSessionDialog> createState() => _RescheduleSessionDialogState();
}

class _RescheduleSessionDialogState extends State<_RescheduleSessionDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessionDetails();
  }

  Future<void> _loadSessionDetails() async {
    try {
      Map<String, dynamic>? session;
      if (widget.isIndividualSession) {
        final response = await SupabaseService.client
            .from('individual_sessions')
            .select('scheduled_date, scheduled_time')
            .eq('id', widget.sessionId)
            .maybeSingle();
        session = response;
      } else {
        final response = await SupabaseService.client
            .from('trial_sessions')
            .select('scheduled_date, scheduled_time')
            .eq('id', widget.sessionId)
            .maybeSingle();
        session = response;
      }

      if (session != null && mounted) {
        final scheduledDate = DateTime.parse(session['scheduled_date'] as String);
        final scheduledTime = session['scheduled_time'] as String? ?? '00:00';
        final timeParts = scheduledTime.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;

        setState(() {
          _selectedDate = scheduledDate;
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
        });
      }
    } catch (e) {
      LogService.error('Error loading session details: $e');
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _selectedDate != null && _selectedTime != null;

    return AlertDialog(
      title: Text('Reschedule Session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a new date and time for this session. The student will need to approve the change.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Date picker
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.softBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? DateFormat('MMM d, y').format(_selectedDate!)
                            : 'Select date',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _selectedDate != null ? AppTheme.textDark : AppTheme.textLight,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textLight),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Time picker
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.softBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Select time',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _selectedTime != null ? AppTheme.textDark : AppTheme.textLight,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textLight),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reason field
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for reschedule',
                hintText: 'E.g., "Schedule conflict"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Additional notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Additional notes (optional)',
                hintText: 'Any additional information for the student',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, {'confirmed': false}),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: (_isLoading || !isValid)
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted) {
                    final timeString = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
                    Navigator.pop(context, {
                      'confirmed': true,
                      'proposedDate': _selectedDate,
                      'proposedTime': timeString,
                      'reason': _reasonController.text.trim(),
                      'additionalNotes': _notesController.text.trim(),
                    });
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : Text('Request Reschedule', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// Cancel Session Dialog
class _CancelSessionDialog extends StatefulWidget {
  @override
  State<_CancelSessionDialog> createState() => _CancelSessionDialogState();
}

class _CancelSessionDialogState extends State<_CancelSessionDialog> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cancel Session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to cancel this session? This action cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'Please provide a reason for cancellation',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, {'confirmed': false}),
          child: Text('Keep Session', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            setState(() => _isLoading = true);
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              Navigator.pop(context, {
                'confirmed': true,
                'reason': _reasonController.text.trim(),
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : Text('Cancel Session', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

