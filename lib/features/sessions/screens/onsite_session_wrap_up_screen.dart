import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/services/session_lifecycle_service.dart';

/// Collects tutor session summary after ending a live onsite session.
class OnsiteSessionWrapUpScreen extends StatefulWidget {
  final String sessionId;
  final String studentName;
  final String subject;

  const OnsiteSessionWrapUpScreen({
    super.key,
    required this.sessionId,
    required this.studentName,
    required this.subject,
  });

  @override
  State<OnsiteSessionWrapUpScreen> createState() => _OnsiteSessionWrapUpScreenState();
}

class _OnsiteSessionWrapUpScreenState extends State<OnsiteSessionWrapUpScreen> {
  final _whatTaughtController = TextEditingController();
  final _howItWentController = TextEditingController();
  final _homeworkController = TextEditingController();
  final _nextFocusController = TextEditingController();
  int _engagement = 4;
  bool _submitting = false;

  @override
  void dispose() {
    _whatTaughtController.dispose();
    _howItWentController.dispose();
    _homeworkController.dispose();
    _nextFocusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_whatTaughtController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please briefly describe what you covered.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await SessionLifecycleService.endSession(
        widget.sessionId,
        tutorNotes: _howItWentController.text.trim().isEmpty
            ? null
            : _howItWentController.text.trim(),
        progressNotes: _whatTaughtController.text.trim(),
        homeworkAssigned: _homeworkController.text.trim().isEmpty
            ? null
            : _homeworkController.text.trim(),
        nextFocusAreas: _nextFocusController.text.trim().isEmpty
            ? null
            : _nextFocusController.text.trim(),
        studentEngagement: _engagement,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete session: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: Text(
          'Session wrap-up',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Great session with ${widget.studentName.split(' ').first}!',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subject,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help the family see what happened today.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _fieldLabel('What did you cover? *'),
            _textField(_whatTaughtController, hint: 'Topics, skills, and activities taught today'),
            const SizedBox(height: 18),
            _fieldLabel('How did it go?'),
            _textField(_howItWentController, hint: 'Student engagement, breakthroughs, challenges'),
            const SizedBox(height: 18),
            _fieldLabel('Student engagement'),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _engagement = star),
                  icon: Icon(
                    star <= _engagement ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppTheme.softYellow,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            _fieldLabel('Homework'),
            _textField(_homeworkController, hint: 'Practice or assignments for next time'),
            const SizedBox(height: 18),
            _fieldLabel('Next focus'),
            _textField(_nextFocusController, hint: 'What to work on in upcoming sessions'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Complete session',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, {required String hint}) {
    return TextField(
      controller: controller,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMedium),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.softBorder),
        ),
      ),
    );
  }
}
