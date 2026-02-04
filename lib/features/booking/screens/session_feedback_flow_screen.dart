import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/services/supabase_service.dart';
import '../services/session_feedback_service.dart';

/// Session Feedback Flow Screen
///
/// Multi-step flow for submitting session feedback
/// Step 1: Rating (required)
/// Step 2: Review (optional)
/// Step 3: Optional Details (optional)
/// Step 4: Submit
class SessionFeedbackFlowScreen extends StatefulWidget {
  final String sessionId;

  const SessionFeedbackFlowScreen({Key? key, required this.sessionId})
      : super(key: key);

  @override
  State<SessionFeedbackFlowScreen> createState() =>
      _SessionFeedbackFlowScreenState();
}

class _SessionFeedbackFlowScreenState extends State<SessionFeedbackFlowScreen> {
  int _currentStep = 0;
  int? _selectedRating;
  final _reviewController = TextEditingController();
  final _whatWentWellController = TextEditingController();
  final _whatCouldImproveController = TextEditingController();
  // Tutor-specific fields
  final _whatWasTaughtController = TextEditingController();
  final _learnerProgressController = TextEditingController();
  final _homeworkAssignedController = TextEditingController();
  final _nextFocusAreasController = TextEditingController();
  bool? _wouldRecommend;
  bool? _learningObjectivesMet;
  int? _studentProgressRating;
  bool? _wouldContinueLessons;
  int? _studentEngagement; // For tutors
  bool _isSubmitting = false;
  bool _canSubmit = false;
  bool _isTutor = false;
  bool _isParent = false;
  bool _isLoadingRole = true;
  
  // Parent-specific fields
  final _childResponseController = TextEditingController();
  int? _childEngagementRating; // 1-5 scale
  bool? _tutorCommunicatedWell;
  final _tutorCommunicationNotesController = TextEditingController();
  int? _comfortLevelWithSetup; // 1-5 scale (especially for onsite)
  final _locationSafetyNotesController = TextEditingController();
  final _nextSessionFocusController = TextEditingController();
  
  // Learner-specific fields
  final _whatLearnedController = TextEditingController();
  String? _helpfulTeachingMethod; // Multiple choice
  int? _confidenceLevel; // 1-5 scale
  
  // Tutor-specific additional field
  final _concernsController = TextEditingController();
  
  // Session context
  Map<String, dynamic>? _sessionData;

  @override
  void initState() {
    super.initState();
    _checkCanSubmit();
    _checkUserRole();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _whatWentWellController.dispose();
    _whatCouldImproveController.dispose();
    _whatWasTaughtController.dispose();
    _learnerProgressController.dispose();
    _homeworkAssignedController.dispose();
    _nextFocusAreasController.dispose();
    _childResponseController.dispose();
    _tutorCommunicationNotesController.dispose();
    _locationSafetyNotesController.dispose();
    _nextSessionFocusController.dispose();
    _whatLearnedController.dispose();
    _concernsController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final session = await SupabaseService.client
          .from('individual_sessions')
          .select('tutor_id, learner_id, parent_id, location, scheduled_date, scheduled_time')
          .eq('id', widget.sessionId)
          .maybeSingle();

      if (session != null) {
        safeSetState(() {
          _isTutor = session['tutor_id'] == userId;
          _isParent = session['parent_id'] == userId;
          _sessionData = session;
          _isLoadingRole = false;
        });
      } else {
        safeSetState(() {
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      safeSetState(() {
        _isLoadingRole = false;
      });
    }
  }

  Future<void> _checkCanSubmit() async {
    final canSubmit = await SessionFeedbackService.canSubmitFeedback(
      widget.sessionId,
    );
    safeSetState(() {
      _canSubmit = canSubmit;
    });
  }

  Future<void> _submitFeedback() async {
    safeSetState(() => _isSubmitting = true);

    try {
      if (_isTutor) {
        // Tutor feedback submission
        await SessionFeedbackService.submitStudentFeedback(
          sessionId: widget.sessionId,
          rating: _selectedRating!,
          whatWasTaught: _whatWasTaughtController.text.trim().isEmpty
              ? null
              : _whatWasTaughtController.text.trim(),
          learnerProgress: _learnerProgressController.text.trim().isEmpty
              ? null
              : _learnerProgressController.text.trim(),
          homeworkAssigned: _homeworkAssignedController.text.trim().isEmpty
              ? null
              : _homeworkAssignedController.text.trim(),
          nextFocusAreas: _nextFocusAreasController.text.trim().isEmpty
              ? null
              : _nextFocusAreasController.text.trim(),
          studentEngagement: _studentEngagement,
          review: _concernsController.text.trim().isEmpty
              ? null
              : _concernsController.text.trim(), // Use review field for concerns
        );
      } else if (_isParent) {
        // Parent feedback submission - combine child response and communication notes into review
        final parentReview = [
          if (_childResponseController.text.trim().isNotEmpty)
            'Child response: ${_childResponseController.text.trim()}',
          if (_tutorCommunicationNotesController.text.trim().isNotEmpty)
            'Communication: ${_tutorCommunicationNotesController.text.trim()}',
          if (_locationSafetyNotesController.text.trim().isNotEmpty)
            'Location safety: ${_locationSafetyNotesController.text.trim()}',
          if (_nextSessionFocusController.text.trim().isNotEmpty)
            'Next session focus: ${_nextSessionFocusController.text.trim()}',
        ].join('\n\n');
        
        await SessionFeedbackService.submitStudentFeedback(
          sessionId: widget.sessionId,
          rating: _selectedRating!,
          review: parentReview.isEmpty ? null : parentReview,
          whatWentWell: _childResponseController.text.trim().isEmpty
              ? null
              : _childResponseController.text.trim(),
          whatCouldImprove: _tutorCommunicationNotesController.text.trim().isEmpty
              ? null
              : _tutorCommunicationNotesController.text.trim(),
          wouldRecommend: _tutorCommunicatedWell,
          studentProgressRating: _childEngagementRating,
          studentEngagement: _comfortLevelWithSetup, // Reuse field for comfort level
        );
      } else {
        // Learner feedback submission
        final learnerReview = _whatLearnedController.text.trim().isEmpty
            ? _reviewController.text.trim()
            : _whatLearnedController.text.trim();
            
        await SessionFeedbackService.submitStudentFeedback(
          sessionId: widget.sessionId,
          rating: _selectedRating!,
          review: learnerReview.isEmpty ? null : learnerReview,
          whatWentWell: _whatWentWellController.text.trim().isEmpty
              ? null
              : _whatWentWellController.text.trim(),
          whatCouldImprove: _whatCouldImproveController.text.trim().isEmpty
              ? null
              : _whatCouldImproveController.text.trim(),
          wouldRecommend: _wouldRecommend,
          learningObjectivesMet: _learningObjectivesMet,
          studentProgressRating: _confidenceLevel ?? _studentProgressRating,
          wouldContinueLessons: _wouldContinueLessons,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(PhosphorIcons.checkCircle(), color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Thank you for your feedback!')),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 3),
          ),
        );
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

  void _nextStep() {
    if (_currentStep == 0 && _selectedRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please provide a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    safeSetState(() {
      if (_currentStep < 2) {
        _currentStep++;
      }
    });
  }

  void _previousStep() {
    safeSetState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  void _exitFeedbackFlow() {
    Navigator.of(context).popUntil(
      (route) => route.settings.name != '/session-feedback-flow',
    );
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
                  PhosphorIcons.info(),
                  size: 64,
                  color: AppTheme.textLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'Feedback Not Available',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Feedback can only be submitted for completed sessions.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _exitFeedbackFlow();
        return false;
      },
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                PhosphorIcons.chatCircle(),
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Session Feedback',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppTheme.textDark),
          onPressed: _exitFeedbackFlow,
        ),
      ),
      backgroundColor: AppTheme.softBackground,
      body: Column(
        children: [
          // Session Context Header
          if (_sessionData != null) _buildSessionContextHeader(),
          // Progress Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                _buildProgressStep(0, 'Rating'),
                _buildProgressLine(0),
                _buildProgressStep(1, 'Review'),
                _buildProgressLine(1),
                _buildProgressStep(2, 'Details'),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStepContent(),
            ),
          ),
          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppTheme.primaryColor),
                        ),
                        child: Text(
                          'Back',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentStep == 2
                          ? (_isSubmitting ? null : _submitFeedback)
                          : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        minimumSize: const Size(double.infinity, 56),
                        elevation: 2,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.3),
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _currentStep == 2 ? 'Submit' : 'Next',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildProgressStep(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.primaryColor
                  : isActive
                      ? AppTheme.primaryColor
                      : Colors.grey[300],
              shape: BoxShape.circle,
              boxShadow: isActive || isCompleted
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(PhosphorIcons.check(), color: Colors.white, size: 18)
                  : Text(
                      '${step + 1}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : Colors.grey[600],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive || isCompleted
                  ? AppTheme.primaryColor
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    final isCompleted = _currentStep > step;
    return Container(
      height: 2,
      width: 20,
      decoration: BoxDecoration(
        gradient: isCompleted
            ? LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
              )
            : null,
        color: isCompleted ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildRatingStep();
      case 1:
        return _buildReviewStep();
      case 2:
        return _buildDetailsStep();
      default:
        return _buildRatingStep();
    }
  }

  Widget _buildRatingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isTutor ? 'Rate this session' : 'How was your session?',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isTutor 
              ? 'Help us track session quality and learner progress.'
              : 'Your feedback helps us improve and helps your tutor grow.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final rating = index + 1;
              return GestureDetector(
                onTap: () => safeSetState(() => _selectedRating = rating),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 50,
                  height: 50,
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
                    child: Text(
                      '⭐',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (_selectedRating != null) ...[
          const SizedBox(height: 20),
          Center(
            child: Text(
              '$_selectedRating out of 5 stars',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    if (_isTutor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session content summary',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Document what topics and concepts were taught in this session.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _whatWasTaughtController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Example: Covered quadratic equations, factoring methods, and solved 5 practice problems...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      );
    }
    
    if (_isParent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How did your child respond?',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your observations about your child\'s engagement and response to this session.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _childResponseController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Example: My child seemed engaged and asked good questions. They understood the concepts better...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'How engaged was your child? (1-5)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final engagement = index + 1;
              return GestureDetector(
                onTap: () => safeSetState(() => _childEngagementRating = engagement),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _childEngagementRating == engagement
                        ? AppTheme.primaryColor
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _childEngagementRating == engagement
                          ? AppTheme.primaryColor
                          : AppTheme.softBorder,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$engagement',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _childEngagementRating == engagement
                            ? Colors.white
                            : AppTheme.textMedium,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      );
    }

    // Learner feedback
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What did you learn today?',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share what you learned or found helpful in this session.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _whatLearnedController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Example: I learned how to solve quadratic equations using factoring. The tutor explained it step by step...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Which teaching methods helped you most?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Visual examples',
            'Practice problems',
            'Clear explanations',
            'Interactive activities',
          ].map((method) {
            final isSelected = _helpfulTeachingMethod == method;
            return GestureDetector(
              onTap: () => safeSetState(() {
                _helpfulTeachingMethod = isSelected ? null : method;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  method,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          'How confident do you feel with the material covered? (1-5)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final confidence = index + 1;
            return GestureDetector(
              onTap: () => safeSetState(() => _confidenceLevel = confidence),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _confidenceLevel == confidence
                      ? AppTheme.primaryColor
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _confidenceLevel == confidence
                        ? AppTheme.primaryColor
                        : AppTheme.softBorder,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$confidence',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _confidenceLevel == confidence
                          ? Colors.white
                          : AppTheme.textMedium,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    if (_isTutor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learner progress & next steps',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track learner progress and plan ahead.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          // Learner Progress
          Text(
            'Specific progress observations',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _learnerProgressController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Example: Student showed strong understanding of algebra basics, needs more practice with word problems...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // Student Engagement
          Text(
            'How engaged was the learner? (1-5)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final engagement = index + 1;
              return GestureDetector(
                onTap: () => safeSetState(() => _studentEngagement = engagement),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _studentEngagement == engagement
                        ? AppTheme.primaryColor
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _studentEngagement == engagement
                          ? AppTheme.primaryColor
                          : AppTheme.softBorder,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$engagement',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _studentEngagement == engagement
                            ? Colors.white
                            : AppTheme.textMedium,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Homework Assigned
          Text(
            'Homework or assignments given (optional)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _homeworkAssignedController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Example: Complete exercises 1-10 on page 45, review chapter 3...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // Next Focus Areas
          Text(
            'What to focus on next session (optional)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nextFocusAreasController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Example: Continue with quadratic equations, introduce graphing, practice problem-solving...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // Concerns
          Text(
            'Any concerns or areas needing attention? (optional)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _concernsController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Example: Student seems to struggle with time management, may need extra support...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      );
    }
    
    if (_isParent) {
      final isOnsite = _sessionData != null && 
          (_sessionData!['location'] as String? ?? '').toLowerCase() == 'onsite';
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional feedback',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us understand your experience and improve.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          // Tutor Communication
          Text(
            'Did the tutor communicate clearly about your child\'s progress?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildYesNoButton(true, _tutorCommunicatedWell, (v) => _tutorCommunicatedWell = v)),
              const SizedBox(width: 12),
              Expanded(child: _buildYesNoButton(false, _tutorCommunicatedWell, (v) => _tutorCommunicatedWell = v)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tutorCommunicationNotesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Optional: Add any notes about communication...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // Comfort Level
          Text(
            'How comfortable did you feel with the session setup? (1-5)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final comfort = index + 1;
              return GestureDetector(
                onTap: () => safeSetState(() => _comfortLevelWithSetup = comfort),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _comfortLevelWithSetup == comfort
                        ? AppTheme.primaryColor
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _comfortLevelWithSetup == comfort
                          ? AppTheme.primaryColor
                          : AppTheme.softBorder,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$comfort',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _comfortLevelWithSetup == comfort
                            ? Colors.white
                            : AppTheme.textMedium,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (isOnsite) ...[
            const SizedBox(height: 20),
            Text(
              'Was the location safe and appropriate? (optional)',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationSafetyNotesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Example: Location was clean and safe, easy to find...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.softBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Next Session Focus
          Text(
            'Would you like the tutor to focus on anything specific next time? (optional)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nextSessionFocusController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Example: More practice with word problems, slower pace on difficult topics...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional details (optional)',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Help us understand what worked and what could be improved.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 24),
        // What Went Well
        Text(
          'What did you find most helpful?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _whatWentWellController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Example: Clear explanations, helpful examples, patient teaching style...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        // What Could Improve
        Text(
          'What could be improved?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _whatCouldImproveController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Example: More practice problems, slower pace on difficult topics...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        // Would Recommend
        Text(
          'Would you recommend this tutor?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildYesNoButton(true, _wouldRecommend, (v) => _wouldRecommend = v)),
            const SizedBox(width: 12),
            Expanded(child: _buildYesNoButton(false, _wouldRecommend, (v) => _wouldRecommend = v)),
          ],
        ),
      ],
    );
  }

  Widget _buildYesNoButton(bool yes, bool? currentValue, Function(bool) onChanged) {
    final isSelected = currentValue == yes;
    return OutlinedButton(
      onPressed: () => safeSetState(() => onChanged(yes)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        yes ? 'Yes' : 'No',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
        ),
      ),
    );
  }
  
  /// Build session context header showing location type and date/time
  Widget _buildSessionContextHeader() {
    if (_sessionData == null) return const SizedBox.shrink();
    
    final location = _sessionData!['location'] as String? ?? 'online';
    final isOnline = location.toLowerCase() == 'online';
    final scheduledDate = _sessionData!['scheduled_date'] as String?;
    final scheduledTime = _sessionData!['scheduled_time'] as String?;
    
    String dateTimeText = '';
    if (scheduledDate != null) {
      try {
        final date = DateTime.parse(scheduledDate);
        final formattedDate = '${date.day}/${date.month}/${date.year}';
        dateTimeText = scheduledTime != null 
            ? '$formattedDate at $scheduledTime'
            : formattedDate;
      } catch (e) {
        dateTimeText = scheduledDate;
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          // Location badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline 
                  ? AppTheme.accentBlue.withOpacity(0.1)
                  : AppTheme.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOnline 
                    ? AppTheme.accentBlue
                    : AppTheme.accentGreen,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? PhosphorIcons.videoCamera() : PhosphorIcons.mapPin(),
                  size: 14,
                  color: isOnline ? AppTheme.accentBlue : AppTheme.accentGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Onsite',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOnline ? AppTheme.accentBlue : AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ),
          if (dateTimeText.isNotEmpty) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dateTimeText,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

