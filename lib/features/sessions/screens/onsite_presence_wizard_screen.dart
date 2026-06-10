import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/image_picker_bottom_sheet.dart';
import 'package:prepskul/features/sessions/services/location_checkin_service.dart';

enum OnsitePresenceWizardMode { checkIn, checkOut }

/// GPS + selfie wizard for onsite session check-in or check-out.
class OnsitePresenceWizardScreen extends StatefulWidget {
  final OnsitePresenceWizardMode mode;
  final String sessionId;
  final String userId;
  final String address;
  final DateTime? scheduledStart;

  const OnsitePresenceWizardScreen({
    super.key,
    required this.mode,
    required this.sessionId,
    required this.userId,
    required this.address,
    this.scheduledStart,
  });

  @override
  State<OnsitePresenceWizardScreen> createState() => _OnsitePresenceWizardScreenState();
}

class _OnsitePresenceWizardScreenState extends State<OnsitePresenceWizardScreen> {
  static const _userType = 'tutor';

  int _step = 0;
  bool _loading = false;
  bool _gpsDone = false;
  String? _gpsMessage;

  bool get _isCheckIn => widget.mode == OnsitePresenceWizardMode.checkIn;

  String get _title => _isCheckIn ? 'Check in' : 'Check out';

  String get _gpsStepTitle =>
      _isCheckIn ? 'Confirm your location' : 'Confirm you are leaving';

  String get _gpsStepBody => _isCheckIn
      ? 'We verify you are at the session address before starting.'
      : 'Record your location as you finish the session.';

  String get _selfieStepTitle =>
      _isCheckIn ? 'Attendance selfie' : 'Checkout selfie';

  String get _selfieStepBody => _isCheckIn
      ? 'Take a quick photo with your student to confirm presence and start the session.'
      : 'Take a quick photo with your student as you wrap up the session.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: Text(_title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step, labels: const ['Location', 'Selfie']),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step == 0) _buildGpsStep() else _buildSelfieStep(),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildGpsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(
          icon: Icons.location_on_outlined,
          title: _gpsStepTitle,
          body: _gpsStepBody,
          address: widget.address,
        ),
        if (_gpsDone) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _gpsMessage ?? 'Location verified',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelfieStep() {
    return _HeroCard(
      icon: Icons.camera_alt_outlined,
      title: _selfieStepTitle,
      body: _selfieStepBody,
      address: null,
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step == 0)
            ElevatedButton(
              onPressed: _loading ? null : (_gpsDone ? _goToSelfieStep : _runGpsStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _gpsDone ? 'Continue to selfie' : 'Verify location',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loading ? null : _runSelfieStep,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(
                'Take selfie',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runGpsStep() async {
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> result;
      if (_isCheckIn) {
        result = await LocationCheckInService.checkInToSession(
          sessionId: widget.sessionId,
          userId: widget.userId,
          userType: _userType,
          sessionAddress: widget.address,
          verifyProximity: true,
          scheduledDateTime: widget.scheduledStart,
        );
      } else {
        result = await LocationCheckInService.checkOutFromSession(
          sessionId: widget.sessionId,
          userId: widget.userId,
          userType: _userType,
        );
      }

      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _gpsDone = true;
          _gpsMessage = result['message'] as String?;
        });
      } else {
        _showMessage(result['message'] as String? ?? 'Location step failed', isError: true);
      }
    } catch (e) {
      if (mounted) _showMessage('Location step failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToSelfieStep() {
    setState(() => _step = 1);
  }

  Future<void> _runSelfieStep() async {
    final pickedFile = await showModalBottomSheet<dynamic>(
      context: context,
      builder: (context) => const ImagePickerBottomSheet(),
      isScrollControlled: true,
    );
    if (pickedFile == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final result = _isCheckIn
          ? await LocationCheckInService.uploadPresenceSelfie(
              sessionId: widget.sessionId,
              userId: widget.userId,
              userType: _userType,
              selfieFile: pickedFile,
            )
          : await LocationCheckInService.uploadCheckoutSelfie(
              sessionId: widget.sessionId,
              userId: widget.userId,
              userType: _userType,
              selfieFile: pickedFile,
            );

      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _showMessage(result['message'] as String? ?? 'Selfie upload failed', isError: true);
      }
    } catch (e) {
      if (mounted) _showMessage('Selfie upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red : AppTheme.accentGreen,
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;

  const _StepIndicator({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i <= current;
          final done = i < current;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: active
                          ? AppTheme.primaryColor
                          : AppTheme.softBorder,
                    ),
                  ),
                Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: active
                          ? AppTheme.primaryColor
                          : AppTheme.softBorder,
                      child: done
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active ? Colors.white : AppTheme.textMedium,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? AppTheme.primaryColor : AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < current ? AppTheme.primaryColor : AppTheme.softBorder,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? address;

  const _HeroCard({
    required this.icon,
    required this.title,
    required this.body,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 36),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (address != null && address!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: Colors.white.withValues(alpha: 0.9), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
