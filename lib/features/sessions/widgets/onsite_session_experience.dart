import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/features/booking/utils/session_live_utils.dart';
import 'package:prepskul/features/sessions/domain/onsite_session_phase.dart';
import 'package:prepskul/features/sessions/widgets/onsite_location_card.dart';
import 'package:prepskul/features/sessions/widgets/onsite_live_connection_hero.dart';

/// Progressive onsite UI shell: pre-session → live → completed.
enum OnsiteExperienceStage { preSession, live, completed }

class OnsiteSessionExperience extends StatefulWidget {
  final OnsiteExperienceStage stage;
  final String counterpartyName;
  final String? subject;
  final String address;
  final String? addressCoordinates;
  final String? locationDescription;
  final DateTime? scheduledStart;
  final DateTime? sessionStartedAt;
  final String? statusLine;
  final String? tutorName;
  final String? tutorAvatarUrl;
  final String? studentName;
  final String? studentAvatarUrl;
  final Widget? checkInSlot;
  final Widget? familyTrackingSlot;
  final Widget? familyConfirmSlot;
  final VoidCallback? onBackToSessions;
  final VoidCallback? onViewWrapUp;
  final bool isLoading;
  final bool showProfileHeader;
  final Widget? sessionDetailsSlot;
  final bool showMapPreview;
  final String? userReferenceAddress;

  const OnsiteSessionExperience({
    super.key,
    required this.stage,
    required this.counterpartyName,
    required this.address,
    this.addressCoordinates,
    this.locationDescription,
    this.subject,
    this.scheduledStart,
    this.sessionStartedAt,
    this.statusLine,
    this.tutorName,
    this.tutorAvatarUrl,
    this.studentName,
    this.studentAvatarUrl,
    this.checkInSlot,
    this.familyTrackingSlot,
    this.familyConfirmSlot,
    this.onBackToSessions,
    this.onViewWrapUp,
    this.isLoading = false,
    this.showProfileHeader = true,
    this.sessionDetailsSlot,
    this.showMapPreview = true,
    this.userReferenceAddress,
  });

  @override
  State<OnsiteSessionExperience> createState() => _OnsiteSessionExperienceState();
}

class _OnsiteSessionExperienceState extends State<OnsiteSessionExperience>
    with SingleTickerProviderStateMixin {
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tickElapsed();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 15), (_) => _tickElapsed());
  }

  void _tickElapsed() {
    final started = widget.sessionStartedAt;
    if (started == null) return;
    setState(() => _elapsed = DateTime.now().difference(started));
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  String get _tutor => widget.tutorName ?? widget.counterpartyName;
  String get _student => widget.studentName ?? widget.counterpartyName;

  @override
  Widget build(BuildContext context) {
    final maxW = ResponsiveHelper.isDesktop(context) ? 560.0 : double.infinity;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: switch (widget.stage) {
          OnsiteExperienceStage.preSession => _buildPreSession(context),
          OnsiteExperienceStage.live => _buildLive(context),
          OnsiteExperienceStage.completed => _buildCompleted(context),
        },
      ),
    );
  }

  Widget _buildPreSession(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showProfileHeader) ...[
          _headerChip('On-site session', Icons.place_outlined, AppTheme.primaryColor),
          const SizedBox(height: 16),
          _personRow(),
          const SizedBox(height: 16),
        ],
        if (widget.sessionDetailsSlot != null) ...[
          widget.sessionDetailsSlot!,
          const SizedBox(height: 16),
        ],
        OnsiteLocationCard(
          address: widget.address,
          coordinates: widget.addressCoordinates,
          statusLine: widget.statusLine,
          locationDescription: widget.locationDescription,
          showMapPreview: widget.showMapPreview,
          userReferenceAddress: widget.userReferenceAddress,
        ),
        if (widget.checkInSlot != null) ...[
          const SizedBox(height: 16),
          widget.checkInSlot!,
        ],
      ],
    );
  }

  Widget _buildLive(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnsiteLiveConnectionHero(
          tutorName: _tutor,
          tutorAvatarUrl: widget.tutorAvatarUrl,
          studentName: _student,
          studentAvatarUrl: widget.studentAvatarUrl,
          subject: widget.subject,
          elapsed: _elapsed,
        ),
        if (widget.familyTrackingSlot != null) ...[
          const SizedBox(height: 16),
          widget.familyTrackingSlot!,
        ],
        if (widget.familyConfirmSlot != null) ...[
          const SizedBox(height: 16),
          widget.familyConfirmSlot!,
        ],
      ],
    );
  }

  Widget _buildCompleted(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 52),
                const SizedBox(height: 12),
                Text(
                  'Session complete',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Great work with ${_student.split(' ').first}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (widget.onViewWrapUp != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onViewWrapUp,
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(
                'View session summary',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (widget.onBackToSessions != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onBackToSessions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Back to sessions',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _personRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Text(
            widget.counterpartyName.isNotEmpty
                ? widget.counterpartyName[0].toUpperCase()
                : '?',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.counterpartyName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              if (widget.subject != null)
                Text(
                  widget.subject!,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMedium),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Resolve which experience stage to show from full session data.
///
/// Uses [SessionLiveUtils.isSessionGenuinelyLive] so stale `in_progress` rows
/// (no tutor check-in / outside the scheduled window) stay on pre-session UI.
OnsiteExperienceStage onsiteStageFromSession(Map<String, dynamic> session) {
  final effectiveStatus = SessionLiveUtils.effectiveStatus(session);
  if (effectiveStatus == 'completed' ||
      effectiveStatus == 'evaluated' ||
      effectiveStatus == 'cancelled') {
    return OnsiteExperienceStage.completed;
  }
  if (SessionLiveUtils.isSessionGenuinelyLive(session)) {
    return OnsiteExperienceStage.live;
  }
  return OnsiteExperienceStage.preSession;
}

/// @deprecated Prefer [onsiteStageFromSession] with the full session map.
OnsiteExperienceStage onsiteStageFromStatus(String status) {
  switch (status.toLowerCase()) {
    case 'in_progress':
      return OnsiteExperienceStage.live;
    case 'completed':
    case 'evaluated':
      return OnsiteExperienceStage.completed;
    default:
      return OnsiteExperienceStage.preSession;
  }
}

String onsiteStatusLine({
  required OnsiteExperienceStage stage,
  required DateTime? scheduledStart,
  required OnsiteSessionPhase phase,
}) {
  if (stage == OnsiteExperienceStage.live) return 'Teaching now';
  if (stage == OnsiteExperienceStage.completed) return 'Session ended';
  return OnsiteSessionPhaseResolver.tutorNextStepLabel(
    phase: phase,
    scheduledStart: scheduledStart,
    hasSelfie: false,
  );
}
