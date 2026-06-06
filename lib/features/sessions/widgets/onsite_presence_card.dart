import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';
import 'package:prepskul/features/sessions/utils/onsite_presence_utils.dart';
import 'package:prepskul/features/tutor/widgets/onsite_presence_indicators.dart';

/// Unified on-site check-in / checkout card for tutor session detail.
class OnsitePresenceCard extends StatefulWidget {
  final String sessionId;
  final String userId;
  final String address;
  final DateTime? scheduledDateTime;
  final VoidCallback? onCheckInSelfie;
  final VoidCallback? onCheckoutSelfie;
  final VoidCallback? onStateChanged;

  const OnsitePresenceCard({
    super.key,
    required this.sessionId,
    required this.userId,
    required this.address,
    this.scheduledDateTime,
    this.onCheckInSelfie,
    this.onCheckoutSelfie,
    this.onStateChanged,
  });

  @override
  State<OnsitePresenceCard> createState() => _OnsitePresenceCardState();
}

class _OnsitePresenceCardState extends State<OnsitePresenceCard> {
  bool _checkingIn = false;
  bool _checkingOut = false;
  Map<String, dynamic>? _status;
  bool _adminApproved = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await LocationCheckInService.getCheckInStatus(
      sessionId: widget.sessionId,
      userId: widget.userId,
    );
    var adminApproved = false;
    try {
      final row = await SupabaseService.client
          .from('individual_sessions')
          .select('attendance_admin_status')
          .eq('id', widget.sessionId)
          .maybeSingle();
      adminApproved = row?['attendance_admin_status'] == 'approved';
    } catch (_) {}
    if (mounted) {
      safeSetState(() {
        _status = status;
        _adminApproved = adminApproved;
      });
    }
  }

  Future<void> _checkIn() async {
    final blocked = OnsitePresenceUtils.checkInBlockedMessage(widget.scheduledDateTime);
    if (blocked != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(blocked, style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    safeSetState(() => _checkingIn = true);
    try {
      final result = await LocationCheckInService.checkInToSession(
        sessionId: widget.sessionId,
        userId: widget.userId,
        userType: 'tutor',
        sessionAddress: widget.address,
        verifyProximity: true,
        scheduledDateTime: widget.scheduledDateTime,
      );
      if (!mounted) return;
      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] as String? ?? (ok ? 'Checked in' : 'Check-in failed'),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: ok ? AppTheme.accentGreen : AppTheme.primaryColor,
        ),
      );
      await _refresh();
      widget.onStateChanged?.call();
    } finally {
      if (mounted) safeSetState(() => _checkingIn = false);
    }
  }

  Future<void> _checkOut() async {
    safeSetState(() => _checkingOut = true);
    try {
      final result = await LocationCheckInService.checkOutFromSession(
        sessionId: widget.sessionId,
        userId: widget.userId,
        userType: 'tutor',
      );
      if (!mounted) return;
      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] as String? ?? (ok ? 'Checked out' : 'Check-out failed'),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: ok ? AppTheme.accentGreen : Colors.orange[800],
        ),
      );
      await _refresh();
      widget.onStateChanged?.call();
    } finally {
      if (mounted) safeSetState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCheckedIn = _status?['has_checked_in'] == true;
    final hasCheckedOut = _status?['has_checked_out'] == true;
    final hasCheckInSelfie = _status?['has_check_in_selfie'] == true;
    final hasCheckOutSelfie = _status?['has_check_out_selfie'] == true;

    String statusLine;
    Color statusColor;
    if (hasCheckedOut) {
      statusLine = 'Checked out — session ended, pending admin review';
      statusColor = AppTheme.textMedium;
    } else if (hasCheckedIn) {
      statusLine = 'Checked in at session location';
      statusColor = AppTheme.accentGreen;
    } else {
      final blocked = OnsitePresenceUtils.checkInBlockedMessage(widget.scheduledDateTime);
      statusLine = blocked ?? 'Check in when you arrive at the learner\'s address';
      statusColor = blocked != null ? AppTheme.textMedium : AppTheme.primaryColor;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'On-site presence',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusLine,
            style: GoogleFonts.poppins(fontSize: 13, color: statusColor),
          ),
          const SizedBox(height: 14),
          if (widget.scheduledDateTime != null) ...[
            Text(
              OnsitePresenceUtils.windowLabel(widget.scheduledDateTime),
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textMedium),
            ),
            const SizedBox(height: 10),
          ],
          OnsitePresenceIndicators(
            checkInDone: hasCheckedIn,
            checkOutDone: hasCheckedOut,
            adminApproved: _adminApproved,
          ),
          const SizedBox(height: 12),
          if (!hasCheckedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_checkingIn ||
                        OnsitePresenceUtils.checkInBlockedMessage(
                              widget.scheduledDateTime,
                            ) !=
                            null)
                    ? null
                    : _checkIn,
                icon: _checkingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.location_on_outlined, size: 18),
                label: Text(
                  _checkingIn ? 'Checking in…' : 'Check in',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          if (hasCheckedIn && !hasCheckedOut) ...[
            OutlinedButton.icon(
              onPressed: hasCheckInSelfie ? null : widget.onCheckInSelfie,
              icon: Icon(
                hasCheckInSelfie ? Icons.check_circle_outline : Icons.camera_alt_outlined,
                size: 18,
              ),
              label: Text(
                hasCheckInSelfie ? 'Check-in selfie uploaded' : 'Upload check-in selfie',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.softBorder),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: hasCheckOutSelfie ? null : widget.onCheckoutSelfie,
              icon: Icon(
                hasCheckOutSelfie ? Icons.check_circle_outline : Icons.camera_alt_outlined,
                size: 18,
              ),
              label: Text(
                hasCheckOutSelfie ? 'Checkout selfie uploaded' : 'Upload checkout selfie',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.softBorder),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_checkingOut || !hasCheckOutSelfie) ? null : _checkOut,
                icon: _checkingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.logout, size: 18),
                label: Text(
                  _checkingOut ? 'Checking out…' : 'Check out & end session',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          if (hasCheckedOut)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Session ended',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
