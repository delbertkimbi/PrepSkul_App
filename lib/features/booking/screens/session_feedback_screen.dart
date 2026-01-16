import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../services/session_feedback_service.dart';

/// Session Feedback Screen
///
/// Allows students to submit feedback after a completed session
class SessionFeedbackScreen extends StatefulWidget {
  final String sessionId;

  const SessionFeedbackScreen({Key? key, required this.sessionId})
    : super(key: key);

  @override
  State<SessionFeedbackScreen> createState() => _SessionFeedbackScreenState();
}

class _SessionFeedbackScreenState extends State<SessionFeedbackScreen> {
  int? _selectedRating;
  final _reviewController = TextEditingController();
  final _whatWentWellController = TextEditingController();
  final _whatCouldImproveController = TextEditingController();
  bool? _wouldRecommend;
  bool? _learningObjectivesMet;
  int? _studentProgressRating;
  bool? _wouldContinueLessons;
  bool _isSubmitting = false;
  bool _canSubmit = false;
  Duration? _timeRemaining;

  @override
  void initState() {
    super.initState();
    _checkCanSubmit();
    _checkTimeRemaining();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _whatWentWellController.dispose();
    _whatCouldImproveController.dispose();
    super.dispose();
  }

  Future<void> _checkCanSubmit() async {
    final canSubmit = await SessionFeedbackService.canSubmitFeedback(
      widget.sessionId,
    );
    safeSetState(() {
      _canSubmit = canSubmit;
    });
  }

  Future<void> _checkTimeRemaining() async {
    final timeRemaining =
        await SessionFeedbackService.getTimeUntilFeedbackAvailable(
          widget.sessionId,
        );
    safeSetState(() {
      _timeRemaining = timeRemaining;
    });

    // Update countdown every minute if there's time remaining
    if (timeRemaining != null && timeRemaining.inMinutes > 0) {
      Future.delayed(const Duration(minutes: 1), () {
        if (mounted) {
          _checkTimeRemaining();
        }
      });
    }
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''} and ${duration.inHours % 24} hour${(duration.inHours % 24) > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''} and ${duration.inMinutes % 60} minute${(duration.inMinutes % 60) > 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }

  Future<void> _submitFeedback() async {
    if (_selectedRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please provide a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    safeSetState(() => _isSubmitting = true);

    try {
      await SessionFeedbackService.submitStudentFeedback(
        sessionId: widget.sessionId,
        rating: _selectedRating!,
        review: _reviewController.text.trim().isEmpty
            ? null
            : _reviewController.text.trim(),
        whatWentWell: _whatWentWellController.text.trim().isEmpty
            ? null
            : _whatWentWellController.text.trim(),
        whatCouldImprove: _whatCouldImproveController.text.trim().isEmpty
            ? null
            : _whatCouldImproveController.text.trim(),
        wouldRecommend: _wouldRecommend,
        learningObjectivesMet: _learningObjectivesMet,
        studentProgressRating: _studentProgressRating,
        wouldContinueLessons: _wouldContinueLessons,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Thank you for your feedback!')),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canSubmit) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Session Feedback', style: GoogleFonts.poppins()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _timeRemaining != null ? Icons.schedule : Icons.info_outline,
                  size: 64,
                  color: _timeRemaining != null
                      ? AppTheme.primaryColor
                      : AppTheme.textLight,
                ),
                const SizedBox(height: 16),
                Text(
                  _timeRemaining != null
                      ? 'Feedback Available Soon'
                      : 'Feedback Not Available',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _timeRemaining != null
                      ? 'You can provide feedback in ${_formatTimeRemaining(_timeRemaining!)}.\n\nWe wait 24 hours after your session ends to ensure you have time to reflect on your experience.'
                      : 'Feedback can only be submitted for completed sessions that ended at least 24 hours ago.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_timeRemaining != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimeRemaining(_timeRemaining!),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Session Feedback', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppTheme.softBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'How was your session?',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps us improve and helps your tutor grow.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 32),

            // Rating Section
            Text(
              'Rating *',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final rating = index + 1;
                return GestureDetector(
                  onTap: () => safeSetState(() => _selectedRating = rating),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _selectedRating == rating
                          ? AppTheme.primaryColor
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedRating == rating
                            ? AppTheme.primaryColor
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text('⭐', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              }),
            ),
            if (_selectedRating != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '$_selectedRating out of 5 stars',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Review Section
            Text(
              'Write a Review (optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your experience with this tutor...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // What Went Well
            Text(
              'What went well? (optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatWentWellController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'What did you like about the session?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // What Could Improve
            Text(
              'What could improve? (optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatCouldImproveController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any suggestions for improvement?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Would Recommend
            Text(
              'Would you recommend this tutor? (optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildRecommendButton(true)),
                const SizedBox(width: 12),
                Expanded(child: _buildRecommendButton(false)),
              ],
            ),
            const SizedBox(height: 32),

            // Learning Objectives Met
            Text(
              'Were learning objectives met? (optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildLearningObjectivesButton(true)),
                const SizedBox(width: 12),
                Expanded(child: _buildLearningObjectivesButton(false)),
              ],
            ),
            const SizedBox(height: 24),

            // Student Progress Rating
            Text(
              'How would you rate your progress? (optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final rating = index + 1;
                return GestureDetector(
                  onTap: () => safeSetState(() => _studentProgressRating = rating),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _studentProgressRating == rating
                          ? AppTheme.primaryColor
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _studentProgressRating == rating
                            ? AppTheme.primaryColor
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$rating',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _studentProgressRating == rating
                              ? Colors.white
                              : AppTheme.textMedium,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (_studentProgressRating != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Progress: $_studentProgressRating/5',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Would Continue Lessons
            Text(
              'Would you continue lessons with this tutor? (optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildContinueLessonsButton(true)),
                const SizedBox(width: 12),
                Expanded(child: _buildContinueLessonsButton(false)),
              ],
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Submit Feedback',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendButton(bool recommend) {
    final isSelected = _wouldRecommend == recommend;
    return OutlinedButton(
      onPressed: () => safeSetState(() => _wouldRecommend = recommend),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            recommend ? Icons.thumb_up : Icons.thumb_down,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            recommend ? 'Yes' : 'No',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningObjectivesButton(bool met) {
    final isSelected = _learningObjectivesMet == met;
    return OutlinedButton(
      onPressed: () => safeSetState(() => _learningObjectivesMet = met),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            met ? 'Yes' : 'No',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLessonsButton(bool continueLessons) {
    final isSelected = _wouldContinueLessons == continueLessons;
    return OutlinedButton(
      onPressed: () => safeSetState(() => _wouldContinueLessons = continueLessons),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            continueLessons ? Icons.arrow_forward : Icons.close,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            continueLessons ? 'Yes' : 'No',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Would Continue Lessons
            Text(
              'Would you continue lessons with this tutor? (optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildContinueLessonsButton(true)),
                const SizedBox(width: 12),
                Expanded(child: _buildContinueLessonsButton(false)),
              ],
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Submit Feedback',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendButton(bool recommend) {
    final isSelected = _wouldRecommend == recommend;
    return OutlinedButton(
      onPressed: () => safeSetState(() => _wouldRecommend = recommend),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            recommend ? Icons.thumb_up : Icons.thumb_down,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            recommend ? 'Yes' : 'No',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningObjectivesButton(bool met) {
    final isSelected = _learningObjectivesMet == met;
    return OutlinedButton(
      onPressed: () => safeSetState(() => _learningObjectivesMet = met),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            met ? 'Yes' : 'No',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLessonsButton(bool continueLessons) {
    final isSelected = _wouldContinueLessons == continueLessons;
    return OutlinedButton(
      onPressed: () => safeSetState(() => _wouldContinueLessons = continueLessons),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            continueLessons ? Icons.arrow_forward : Icons.close,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            continueLessons ? 'Yes' : 'No',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}