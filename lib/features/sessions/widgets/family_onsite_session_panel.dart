import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/features/booking/utils/session_live_utils.dart';
import 'package:prepskul/features/sessions/widgets/onsite_session_experience.dart';

/// Progressive onsite UI for parent / learner session detail.
class FamilyOnsiteSessionPanel extends StatelessWidget {
  final Map<String, dynamic> session;
  final String status;
  final String tutorName;
  final String? tutorAvatarUrl;
  final String? studentName;
  final String? studentAvatarUrl;
  final String? addressCoordinates;
  final String subject;
  final String address;
  final String? locationDescription;
  final DateTime? scheduledStart;
  final DateTime? sessionStartedAt;
  final Widget? trackingWidget;
  final Widget? confirmStartWidget;
  final Widget? confirmEndWidget;
  final Widget? messageTutorButton;
  final Widget? sessionDetailsSlot;
  final String? userAddress;
  final bool? showMapPreview;

  const FamilyOnsiteSessionPanel({
    super.key,
    required this.session,
    required this.status,
    required this.tutorName,
    this.tutorAvatarUrl,
    this.studentName,
    this.studentAvatarUrl,
    this.addressCoordinates,
    required this.subject,
    required this.address,
    this.locationDescription,
    this.scheduledStart,
    this.sessionStartedAt,
    this.trackingWidget,
    this.confirmStartWidget,
    this.confirmEndWidget,
    this.messageTutorButton,
    this.sessionDetailsSlot,
    this.userAddress,
    this.showMapPreview,
  });

  @override
  Widget build(BuildContext context) {
    final stage = onsiteStageFromSession(session);
    final effectiveStatus = SessionLiveUtils.effectiveStatus(session);
    final mapVisible = showMapPreview ?? true;
    final statusLine = stage == OnsiteExperienceStage.preSession
        ? _preSessionStatusLine(
            scheduledStart: scheduledStart,
            rawStatus: status,
            effectiveStatus: effectiveStatus,
          )
        : null;
    final learnerName = studentName ?? 'Student';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnsiteSessionExperience(
          stage: stage,
          showProfileHeader: sessionDetailsSlot == null,
          sessionDetailsSlot: sessionDetailsSlot,
          counterpartyName: tutorName,
          tutorName: tutorName,
          tutorAvatarUrl: tutorAvatarUrl,
          studentName: learnerName,
          studentAvatarUrl: studentAvatarUrl,
          subject: subject,
          address: address,
          addressCoordinates: addressCoordinates,
          locationDescription: locationDescription,
          scheduledStart: scheduledStart,
          sessionStartedAt: sessionStartedAt,
          statusLine: statusLine,
          showMapPreview: mapVisible,
          familyTrackingSlot: stage == OnsiteExperienceStage.live ? trackingWidget : null,
          familyConfirmSlot: stage == OnsiteExperienceStage.live
              ? confirmStartWidget
              : (stage == OnsiteExperienceStage.completed ? confirmEndWidget : null),
          onBackToSessions: stage == OnsiteExperienceStage.completed
              ? () => Navigator.pop(context)
              : null,
        ),
        if (messageTutorButton != null &&
            stage != OnsiteExperienceStage.completed &&
            stage != OnsiteExperienceStage.live) ...[
          const SizedBox(height: 16),
          messageTutorButton!,
        ],
      ],
    );
  }

  String _preSessionStatusLine({
    required DateTime? scheduledStart,
    required String rawStatus,
    required String effectiveStatus,
  }) {
    if (rawStatus == 'in_progress' && effectiveStatus == 'scheduled') {
      return 'Waiting for your tutor to check in at the location.';
    }
    if (scheduledStart != null) {
      return 'Scheduled for ${DateFormat('EEE, MMM d · h:mm a').format(scheduledStart)}. '
          'Tutor check-in opens 1 hour before.';
    }
    return 'Tutor check-in opens 1 hour before your session.';
  }
}
