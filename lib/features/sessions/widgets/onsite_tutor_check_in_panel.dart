import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/sessions/domain/onsite_session_phase.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';

/// Tutor check-in CTA shown only inside the presence window.
class OnsiteTutorCheckInPanel extends StatefulWidget {
  final String sessionId;
  final String userId;
  final String address;
  final DateTime? scheduledStart;
  final String sessionStatus;
  final VoidCallback? onCheckInComplete;
  final VoidCallback? onAddSelfie;

  const OnsiteTutorCheckInPanel({
    super.key,
    required this.sessionId,
    required this.userId,
    required this.address,
    this.scheduledStart,
    required this.sessionStatus,
    this.onCheckInComplete,
    this.onAddSelfie,
  });

  @override
  State<OnsiteTutorCheckInPanel> createState() => _OnsiteTutorCheckInPanelState();
}

class _OnsiteTutorCheckInPanelState extends State<OnsiteTutorCheckInPanel> {
  bool _loading = false;
  bool _hasCheckedIn = false;
  bool _hasSelfie = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await LocationCheckInService.getCheckInStatus(
      sessionId: widget.sessionId,
      userId: widget.userId,
    );
    final record = await LocationCheckInService.getAttendanceRecord(
      sessionId: widget.sessionId,
      userId: widget.userId,
    );
    if (!mounted) return;
    safeSetState(() {
      _hasCheckedIn = status?['has_checked_in'] == true;
      final url = record?['check_in_photo_url'];
      _hasSelfie = url != null && url.toString().trim().isNotEmpty;
    });
  }

  Future<void> _checkIn() async {
    safeSetState(() => _loading = true);
    try {
      final result = await LocationCheckInService.checkInToSession(
        sessionId: widget.sessionId,
        userId: widget.userId,
        userType: 'tutor',
        sessionAddress: widget.address,
        verifyProximity: true,
        scheduledDateTime: widget.scheduledStart,
      );
      if (mounted) {
        if (result['success'] == true) {
          await _load();
          widget.onCheckInComplete?.call();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Check-in updated'),
            backgroundColor: result['success'] == true ? AppTheme.accentGreen : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) safeSetState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = OnsiteSessionPhaseResolver.resolve(
      sessionStatus: widget.sessionStatus,
      scheduledStart: widget.scheduledStart,
      hasCheckedIn: _hasCheckedIn,
      hasCheckedOut: false,
    );

    if (phase != OnsiteSessionPhase.readyToCheckIn && !_hasCheckedIn) {
      return const SizedBox.shrink();
    }
    if (_hasCheckedIn && _hasSelfie) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_hasCheckedIn)
          ElevatedButton.icon(
            onPressed: _loading ? null : _checkIn,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.how_to_reg, size: 18),
            label: Text(
              'Check in at location',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        if (_hasCheckedIn && !_hasSelfie && widget.onAddSelfie != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onAddSelfie,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: Text('Add attendance selfie', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}
