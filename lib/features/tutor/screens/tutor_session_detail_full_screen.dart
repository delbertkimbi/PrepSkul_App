import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/live_session_test_config.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../features/booking/services/individual_session_service.dart';
import '../../../features/booking/services/trial_session_service.dart';
import '../../../features/booking/services/session_lifecycle_service.dart';
import '../../../features/booking/models/trial_session_model.dart';
import '../../../features/booking/services/session_reschedule_service.dart';
import '../../../features/sessions/screens/agora_prejoin_screen.dart';
import '../../../features/sessions/screens/agora_video_session_screen.dart';
import '../../../features/sessions/widgets/session_start_countdown_ring.dart';
import '../../../core/utils/geocoding_helper.dart';
import '../../../features/sessions/domain/onsite_session_phase.dart';
import '../../../features/sessions/widgets/onsite_session_experience.dart';
import '../../../features/sessions/widgets/onsite_live_safety_bar.dart';
import '../../../features/sessions/screens/onsite_session_wrap_up_screen.dart';
import '../../../features/sessions/screens/onsite_presence_wizard_screen.dart';
import '../../../features/sessions/services/session_safety_service.dart';
import '../../../features/sessions/services/live_session_overlay_controller.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../features/booking/widgets/report_issue_bottom_sheet.dart';
import 'package:prepskul/core/utils/platform_utils_stub.dart'
    if (dart.library.html) 'package:prepskul/core/utils/platform_utils_web.dart' as platform_utils;

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
  bool _isActionLoading = false;
  Map<String, dynamic>? _sessionData;
  int _countdownTick = 0; // Force rebuild for countdown
  bool _onsiteBannerDismissed = false;
  String _tutorName = 'Tutor';
  String? _tutorAvatarUrl;

  @override
  void initState() {
    super.initState();
    _sessionData = widget.session;
    _loadSessionData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLiveOverlayIfNeeded());
    // Update countdown every 30s when on scheduled session
    Future.delayed(const Duration(seconds: 30), _tickCountdown);
  }

  void _syncLiveOverlayIfNeeded() {
    if (!mounted || _sessionData == null) return;
    if (_getStatus() != 'in_progress') return;
    LiveSessionOverlayController.instance.registerFromSessionMap(
      session: _sessionData!,
      userRole: 'tutor',
      counterpartyName: _getStudentName(),
      subject: _getSubject(),
      localAvatarUrl: _tutorAvatarUrl,
      counterpartyAvatarUrl: _getStudentAvatar(),
      isOnline: _getLocation() == 'online',
    );
    LiveSessionOverlayController.instance.setRouteSuppressed(true);
  }

  void _popSessionDetail() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      '/tutor-nav',
      arguments: {'initialTab': 2},
    );
  }

  @override
  void dispose() {
    LiveSessionOverlayController.instance.setRouteSuppressed(false);
    super.dispose();
  }

  void _tickCountdown() {
    if (!mounted || _sessionData == null) return;
    final status = _getStatus();
    if (status == 'scheduled' && _getScheduledDateTime() != null) {
      setState(() => _countdownTick++);
    }
    Future.delayed(const Duration(seconds: 30), _tickCountdown);
  }

  Future<void> _loadSessionData() async {
      _sessionData = widget.session;
    if (mounted) setState(() {});
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        final profile = await SupabaseService.client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null) {
          _tutorName = profile['full_name'] as String? ?? _tutorName;
          _tutorAvatarUrl = profile['avatar_url'] as String?;
        }
      }
      await _enrichStudentNameIfNeeded();
    } catch (e) {
      LogService.error('Error loading session data: $e');
    } finally {
      if (mounted) {
        setState(() {});
        if (_getStatus() == 'in_progress') {
          _syncLiveOverlayIfNeeded();
        }
      }
    }
  }

  bool _isGenericDisplayName(String? name) {
    if (name == null || name.trim().isEmpty) return true;
    final n = name.trim().toLowerCase();
    return n == 'student' || n == 'user' || n == 'parent' || n == 'learner';
  }

  Future<void> _enrichStudentNameIfNeeded() async {
    if (_sessionData == null) return;
    if (!_isGenericDisplayName(_getStudentName())) return;

    final recurringData =
        _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
    final learnerId = recurringData?['learner_id'] as String? ??
        _sessionData!['learner_id'] as String?;
    if (learnerId == null || learnerId.isEmpty) return;

    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', learnerId)
          .maybeSingle();
      if (profile == null) return;
      final fullName = profile['full_name'] as String?;
      if (_isGenericDisplayName(fullName)) return;
      _sessionData = {
        ..._sessionData!,
        'student_name': fullName!.trim(),
        'student_avatar_url': profile['avatar_url'] as String?,
      };
    } catch (e) {
      LogService.warning('Could not enrich student name: $e');
    } finally {
      if (mounted && _getStatus() == 'in_progress') {
        _syncLiveOverlayIfNeeded();
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
    if (_sessionData == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
            onPressed: _popSessionDetail,
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

    if (_getLocation() != 'online') {
      return _buildOnsiteProgressiveScaffold(context);
    }

    return _buildStandardDetailScaffold(context);
  }

  String _onsiteAppBarTitle() {
    final data = _sessionData;
    if (data == null) return 'Session details';
    return switch (onsiteStageFromSession(data)) {
      OnsiteExperienceStage.live => 'Live session',
      OnsiteExperienceStage.completed => 'Session complete',
      OnsiteExperienceStage.preSession => 'Session details',
    };
  }

  DateTime? _getSessionStartedAt() {
    final raw = _sessionData?['session_started_at'] as String?;
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Widget _buildOnsiteProgressiveScaffold(BuildContext context) {
    final data = _sessionData!;
    final stage = onsiteStageFromSession(data);
    final isLive = stage == OnsiteExperienceStage.live;
    final address = _getAddress() ?? '';
    final scheduled = _getScheduledDateTime();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: _popSessionDetail,
        ),
        title: Text(
          _onsiteAppBarTitle(),
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
              padding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: ResponsiveHelper.responsiveHorizontalPadding(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isLive) ...[
                    _buildStudentProfileSection(),
                    const SizedBox(height: 20),
                    _buildSectionTitle('Session details'),
                    const SizedBox(height: 12),
                    _buildSessionDetailsCard(),
                    const SizedBox(height: 20),
                  ],
                  OnsiteSessionExperience(
                    stage: stage,
                    showProfileHeader: false,
                    counterpartyName: _getStudentName(),
                    tutorName: _tutorName,
                    tutorAvatarUrl: _tutorAvatarUrl,
                    studentName: _getStudentName(),
                    studentAvatarUrl: _getStudentAvatar(),
                    subject: _getSubject(),
                    address: address,
                    addressCoordinates: _getAddressCoordinates(),
                    locationDescription: null,
                    scheduledStart: scheduled,
                    sessionStartedAt: _getSessionStartedAt(),
                    statusLine: stage == OnsiteExperienceStage.preSession
                        ? 'Take a selfie with your student to confirm presence, then start the session.'
                        : null,
                    showMapPreview: stage == OnsiteExperienceStage.preSession,
                    isLoading: _isActionLoading,
                    onBackToSessions: stage == OnsiteExperienceStage.completed
                        ? () => Navigator.pop(context)
                        : null,
                  ),
                  if (stage == OnsiteExperienceStage.preSession && _getPerSessionAmount() != null) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Payment'),
                    const SizedBox(height: 12),
                    _buildPaymentCard(),
                  ],
                ],
              ),
            ),
          ),
          if (stage == OnsiteExperienceStage.preSession && _shouldShowActions())
            _buildOnsitePreSessionFooter(),
          if (isLive) _buildOnsiteLiveFooter(),
        ],
      ),
    );
  }

  Widget _buildOnsiteLiveFooter() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    final sessionId = _getSessionId();
    final isIndividual = _isIndividualSession();

    return Container(
      padding: EdgeInsets.fromLTRB(
        ResponsiveHelper.responsiveHorizontalPadding(context),
        12,
        ResponsiveHelper.responsiveHorizontalPadding(context),
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isActionLoading ? null : _handleEndSession,
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: Text(
                'End session',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          OnsiteLiveSafetyBar(
            isLoading: _isActionLoading,
            onReport: isIndividual
                ? () => showReportIssueBottomSheet(
                      context: context,
                      sessionId: sessionId,
                      role: 'tutor',
                    )
                : null,
            onShareLocation: userId != null
                ? () => SessionSafetyService.shareWithEmergencyContact(
                      sessionId: sessionId,
                      userId: userId,
                      userType: 'tutor',
                    )
                : null,
            onPanic: userId != null
                ? () => SessionSafetyService.triggerPanicButton(
                      sessionId: sessionId,
                      userId: userId,
                      userType: 'tutor',
                    )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildOnsitePreSessionFooter() {
    final currentUserId = SupabaseService.client.auth.currentUser?.id;
    final withinWindow = OnsiteSessionPhaseResolver.isWithinPresenceWindow(
          _getScheduledDateTime(),
        ) ||
        LiveSessionTestConfig.canStartOnsiteEarly(currentUserId);
    final earlyStart = LiveSessionTestConfig.canStartOnsiteEarly(currentUserId) &&
        !OnsiteSessionPhaseResolver.isWithinPresenceWindow(_getScheduledDateTime());
    final opensAt = OnsiteSessionPhaseResolver.presenceWindowStart(_getScheduledDateTime());

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
          if (earlyStart)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Test mode: start anytime',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
                textAlign: TextAlign.center,
              ),
            )
          else if (!withinWindow && opensAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Start unlocks when check-in opens (${_formatShortTime(opensAt)})',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isActionLoading || !withinWindow) ? null : _startSessionFromDetail,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: Text(
                'Start session',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _showMoreSessionActions(
              sessionId: _getSessionId(),
              isIndividual: _isIndividualSession(),
            ),
            icon: const Icon(Icons.more_horiz),
            label: Text('More actions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardDetailScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: _popSessionDetail,
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
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.responsiveHorizontalPadding(context),
                vertical: ResponsiveHelper.responsiveVerticalPadding(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStudentProfileSection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Session Details'),
                  const SizedBox(height: 16),
                  _buildSessionDetailsCard(),
                  const SizedBox(height: 24),
                  if (!_isIndividualSession()) ...[
                    _buildSectionTitle('Schedule'),
                    const SizedBox(height: 16),
                    _buildScheduleCard(),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Location'),
                  const SizedBox(height: 16),
                  _buildLocationCard(),
                  if (_getMonthlyTotal() != null) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Payment'),
                    const SizedBox(height: 16),
                    _buildPaymentCard(),
                  ],
                ],
              ),
            ),
          ),
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
    final preResolved = _sessionData?['student_name'] as String?;
    if (!_isGenericDisplayName(preResolved)) return preResolved!.trim();

    if (_isTrialSession()) {
      return _sessionData!['student_name'] as String? ??
          _sessionData!['learner_name'] as String? ??
          'Student';
    } else if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      final learnerType = recurringData?['learner_type']?.toString().toLowerCase();
      final learnerName = recurringData?['learner_name']?.toString();
      if (learnerType != 'parent' &&
          !_isGenericDisplayName(learnerName)) {
        return learnerName!.trim();
      }
      return recurringData?['student_name']?.toString() ??
          _sessionData!['student_name']?.toString() ??
          (!_isGenericDisplayName(learnerName) ? learnerName!.trim() : null) ??
          _sessionData!['learner_name']?.toString() ??
          'Student';
    } else {
      return _sessionData!['learner_name'] as String? ??
          _sessionData!['student_name'] as String? ??
          'Student';
    }
  }

  String? _getStudentAvatar() {
    if (_isTrialSession()) {
      return _sessionData!['student_avatar_url'] as String? ??
          _sessionData!['learner_avatar_url'] as String?;
    } else if (_isIndividualSession()) {
      final recurringData =
          _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
      return recurringData?['learner_avatar_url']?.toString() ??
          recurringData?['student_avatar_url']?.toString() ??
          _sessionData!['learner_avatar_url']?.toString();
    } else {
      return _sessionData!['learner_avatar_url'] as String? ??
          _sessionData!['student_avatar_url'] as String?;
    }
  }

  /// Badge-only: show Scheduled until start time unless tutor already started early.
  String _badgeDisplayStatus() {
    final status = _getStatus();
    if (status != 'in_progress') return status;
    final start = _getScheduledDateTime();
    if (start == null) return status;
    if (DateTime.now().isBefore(start)) return 'started_early';
    return status;
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
      return null;
    }
    final raw = _sessionData!['address'] as String? ??
        _sessionData!['onsite_address'] as String? ??
        _sessionData!['location_description'] as String?;
    if (raw == null || raw.trim().isEmpty) return null;
    return GeocodingHelper.stripEmbeddedCoords(raw);
  }

  String? _getAddressCoordinates() {
    final direct = _sessionData?['onsite_coordinates'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;
    for (final field in ['address', 'location_description', 'onsite_address']) {
      final embedded = GeocodingHelper.extractEmbeddedCoordinates(
        _sessionData?[field] as String?,
      );
      if (embedded != null) return embedded;
    }
    return null;
  }

  String? _getMeetLink() {
    if (_isTrialSession()) {
      return _sessionData!['meet_link'] as String?;
    } else {
      return _sessionData!['meeting_link'] as String?;
    }
  }

  /// Per-session tutor earnings (monthly plan ÷ sessions per month).
  double? _getPerSessionAmount() {
    final monthly = _getMonthlyTotal();
    final frequency = _getFrequency();
    if (monthly == null || frequency == null || frequency <= 0) return null;
    return monthly / (frequency * 4);
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
    final badgeStatus = _badgeDisplayStatus();
    final statusColor = _getStatusColor(
      badgeStatus == 'started_early' ? 'in_progress' : badgeStatus,
    );

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
                (badgeStatus == 'started_early' ? 'IN PROGRESS' : badgeStatus.toUpperCase()),
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
    final scheduled = _getScheduledDateTime();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject != null)
                  _buildInfoRow(Icons.book_outlined, 'Subject', subject),
          if (_isIndividualSession() && sessionDate != null) ...[
                  const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              DateFormat('MMM d, yyyy').format(sessionDate),
            ),
          ],
          if (_isIndividualSession() && sessionTime != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.access_time, 'Time', sessionTime!),
          ],
          if (!_isIndividualSession() && frequency != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.repeat, 'Frequency', '$frequency sessions per week'),
          ],
          if (!_isIndividualSession() && totalSessions > 0) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.check_circle_outline, 'Completed', '$totalSessions sessions'),
                ],
              ],
            ),
          ),
          if (scheduled != null && _getStatus() == 'scheduled') ...[
            const SizedBox(width: 12),
            Builder(
              builder: (_) {
                final recurring =
                    _sessionData!['recurring_sessions'] as Map<String, dynamic>?;
                final window = SessionStartCountdownRing.bookingWindowFromRecurring(
                  recurring,
                  scheduled,
                );
                return SessionStartCountdownRing(
                  sessionStart: scheduled,
                  bookingWindowStart: window.windowStart,
                  bookingWindowEnd: window.windowEnd,
                  size: 84,
                );
              },
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

  /// One-line onsite reminder (Uber-style): no nagging, benefit-focused, dismissible.
  Widget _buildOnsiteBackgroundBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Teach in a visible area with an adult present for minors. Use Safety (shield icon) or Report issue if needed.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AppTheme.textMedium),
            onPressed: () => setState(() => _onsiteBannerDismissed = true),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
    final perSession = _getPerSessionAmount();
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
          if (perSession != null)
            _buildInfoRow(
              Icons.payments_outlined,
              'This session',
              _formatCurrency(perSession),
            ),
          if (paymentPlan != null) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.payment,
              'Billing plan',
              _formatPaymentPlan(paymentPlan),
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
          // Join only at session time (match learner UX): countdown when scheduled, enabled when in_progress or time reached
          if (isOnline && (status == 'scheduled' || (status == 'in_progress' && meetLink != null && meetLink.isNotEmpty))) ...[
            Builder(
              builder: (context) {
                final start = _getScheduledDateTime();
                final now = DateTime.now();
                final inProgress = status == 'in_progress';
                final currentUserId = SupabaseService.currentUser?.id;
                final allowedToJoin = LiveSessionTestConfig.canUserJoinSession(currentUserId);
                final canJoin = allowedToJoin &&
                    (inProgress ||
                        (start != null && !now.isBefore(start)) ||
                        LiveSessionTestConfig.isTestUser(currentUserId));
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
                return Column(
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isActionLoading || !canJoin) ? null : () => _joinOrStartAndOpenVideo(),
                        icon: const Icon(Icons.video_call, size: 20),
                        label: Text(
                          status == 'scheduled' ? 'Start & Join Session' : 'Join Session',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canJoin ? AppTheme.primaryColor : Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          // Start Session (onsite) — only within check-in window (1h before → 2h after)
          if (status == 'scheduled' && !isOnline) ...[
            Builder(
              builder: (context) {
                final currentUserId = SupabaseService.client.auth.currentUser?.id;
                final scheduled = _getScheduledDateTime();
                final withinWindow = OnsiteSessionPhaseResolver.isWithinPresenceWindow(scheduled) ||
                    LiveSessionTestConfig.canStartOnsiteEarly(currentUserId);
                final earlyStart = LiveSessionTestConfig.canStartOnsiteEarly(currentUserId) &&
                    !OnsiteSessionPhaseResolver.isWithinPresenceWindow(scheduled);
                final opensAt = OnsiteSessionPhaseResolver.presenceWindowStart(scheduled);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (earlyStart)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Test mode: start anytime',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (!withinWindow && opensAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'You can start when check-in opens (${_formatShortTime(opensAt)})',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                        onPressed: (_isActionLoading || !withinWindow)
                            ? null
                            : () => _startSessionFromDetail(),
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
                  ],
                );
              },
            ),
          ],
          // End Session (in_progress)
          if (status == 'in_progress')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading ? null : () => _handleEndSession(),
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
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showMoreSessionActions(
                sessionId: sessionId,
                isIndividual: isIndividual,
              ),
              icon: const Icon(Icons.more_horiz, size: 20),
                    label: Text(
                'More actions',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMoreSessionActions({
    required String sessionId,
    required bool isIndividual,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.schedule, color: AppTheme.primaryColor),
              title: Text('Reschedule', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _handleReschedule(sessionId, isIndividual);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: Text('Cancel session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _handleCancel(sessionId, isIndividual);
              },
            ),
            if (isIndividual)
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                title: Text('Report issue', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  showReportIssueBottomSheet(
                    context: context,
                    sessionId: sessionId,
                    role: 'tutor',
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _startSessionFromDetail() async {
    final sessionId = _getSessionId();
    final isIndividual = _isIndividualSession();
    final isOnline = _getLocation() == 'online';
    final userId = SupabaseService.client.auth.currentUser?.id;

    if (!isOnline) {
      if (userId == null) return;
      final checkedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => OnsitePresenceWizardScreen(
            mode: OnsitePresenceWizardMode.checkIn,
            sessionId: sessionId,
            userId: userId,
            address: _getAddress() ?? '',
            scheduledStart: _getScheduledDateTime(),
          ),
        ),
      );
      if (checkedIn != true || !mounted) return;
    }

    final previousStatus = _getStatus();
    final previousStartedAt = _sessionData?['session_started_at'];
    final startedAt = DateTime.now().toIso8601String();

    setState(() {
      _isActionLoading = true;
      _sessionData = {
        ..._sessionData!,
        'status': 'in_progress',
        'session_started_at': startedAt,
      };
    });
    LiveSessionOverlayController.instance.registerFromSessionMap(
      session: _sessionData!,
      userRole: 'tutor',
      counterpartyName: _getStudentName(),
      subject: _getSubject(),
      localAvatarUrl: _tutorAvatarUrl,
      counterpartyAvatarUrl: _getStudentAvatar(),
      isOnline: isOnline,
    );
    LiveSessionOverlayController.instance.setRouteSuppressed(true);

    try {
      if (isIndividual) {
        await SessionLifecycleService.startSession(
          sessionId,
          isOnline: isOnline,
          skipCloudRecording: kIsWeb && platform_utils.PlatformUtils.isMobileWeb,
        );
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
        setState(() {
          _sessionData = {
            ..._sessionData!,
            'status': previousStatus,
            'session_started_at': previousStartedAt,
          };
        });
        LiveSessionOverlayController.instance.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  String _formatShortTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _joinOrStartAndOpenVideo() async {
    final currentUserId = SupabaseService.currentUser?.id;
    if (!LiveSessionTestConfig.canUserJoinSession(currentUserId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LiveSessionTestConfig.localTestingRestrictionMessage),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final sessionId = _getSessionId();
    final status = _getStatus();
    final isIndividual = _isIndividualSession();
    final isOnline = _getLocation() == 'online';
    setState(() => _isActionLoading = true);
    try {
      if (status == 'scheduled') {
        if (isIndividual) {
          await SessionLifecycleService.startSession(
            sessionId,
            isOnline: true,
            skipCloudRecording: kIsWeb && platform_utils.PlatformUtils.isMobileWeb,
          );
        } else {
          await TrialSessionService.startTrialSessionAsTutor(sessionId, isOnline: true);
        }
        if (mounted) {
          setState(() {
            _sessionData = {
              ..._sessionData!,
              'status': 'in_progress',
              'session_started_at': DateTime.now().toIso8601String(),
            };
          });
          LiveSessionOverlayController.instance.registerFromSessionMap(
            session: _sessionData!,
            userRole: 'tutor',
            counterpartyName: _getStudentName(),
            subject: _getSubject(),
            localAvatarUrl: _tutorAvatarUrl,
            counterpartyAvatarUrl: _getStudentAvatar(),
            isOnline: true,
          );
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
        final preJoinResult = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => AgoraPreJoinScreen(
              sessionId: sessionId,
              userRole: 'tutor',
            ),
          ),
        );
        if (mounted && preJoinResult != null && preJoinResult['join'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AgoraVideoSessionScreen(
                sessionId: sessionId,
                userRole: 'tutor',
                initialCameraEnabled: preJoinResult['camera'] as bool? ?? false,
                initialMicEnabled: preJoinResult['mic'] as bool? ?? false,
              ),
            ),
          ).then((_) => _refreshSessionStatus());
        }
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
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleEndSession() async {
    final sessionId = _getSessionId();

    if (_getLocation() != 'online') {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final checkedOut = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => OnsitePresenceWizardScreen(
            mode: OnsitePresenceWizardMode.checkOut,
            sessionId: sessionId,
            userId: userId,
            address: _getAddress() ?? '',
            scheduledStart: _getScheduledDateTime(),
          ),
        ),
      );
      if (checkedOut != true || !mounted) return;

      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => OnsiteSessionWrapUpScreen(
            sessionId: sessionId,
            studentName: _getStudentName(),
            subject: _getSubject() ?? 'Tutoring Session',
          ),
        ),
      );
      if (completed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Session completed', style: GoogleFonts.poppins()),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        setState(() => _sessionData = {..._sessionData!, 'status': 'completed'});
        LiveSessionOverlayController.instance.clear();
        _refreshSessionStatus();
      }
      return;
    }

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
              onPressed: _popSessionDetail,
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
    setState(() => _isActionLoading = true);
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
        setState(() => _sessionData = {..._sessionData!, 'status': 'completed'});
        LiveSessionOverlayController.instance.clear();
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
      if (mounted) setState(() => _isActionLoading = false);
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
      setState(() => _isActionLoading = true);
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
          setState(() => _isActionLoading = false);
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
      setState(() => _isActionLoading = true);
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
          setState(() => _isActionLoading = false);
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
              labelText: 'Reason (required)',
              hintText: 'Why are you cancelling? Family will see this.',
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
            final reason = _reasonController.text.trim();
            if (reason.length < 8) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please add a short reason (at least 8 characters).',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );
              return;
            }
            setState(() => _isLoading = true);
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              Navigator.pop(context, {
                'confirmed': true,
                'reason': reason,
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

