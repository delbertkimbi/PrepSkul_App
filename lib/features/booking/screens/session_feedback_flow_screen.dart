import 'package:flutter/foundation.dart';
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
  int? _wouldContinueLessonsChoice; // 0=No, 1=Yes, 2=Not sure (trial learner)
  int? _learningGoalsChoice; // 0=No, 1=Yes, 2=Partly (normal learner)
  int? _parentWouldBookChoice; // 0=No, 1=Yes, 2=Not sure (trial parent)
  int? _studentEngagement; // For tutors
  bool _isSubmitting = false;
  bool _canSubmit = false;
  bool _isTutor = false;
  bool _isParent = false;
  bool _isLoadingRole = true;
  bool _isTrial = true; // Default true until we fetch recurring_session_id
  
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
  
  // Onsite only: "Did this session take place?" (family confirmation / dispute)
  String? _sessionTookPlace; // 'yes', 'no', 'partially'
  final _sessionTookPlaceNotesController = TextEditingController();
  
  // Session context
  Map<String, dynamic>? _sessionData;
  
  bool get _isOnsiteSession {
    final loc = (_sessionData?['location'] as String?)?.toLowerCase().trim();
    return loc == 'onsite' || loc == 'hybrid';
  }

  /// Neumorphic raised plate (soft light + soft dark shadow).
  static const List<BoxShadow> _neuRaised = [
    BoxShadow(
      color: Color(0xFFFFFFFF),
      offset: Offset(-2, -2),
      blurRadius: 6,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(3, 3),
      blurRadius: 8,
    ),
  ];

  static const List<BoxShadow> _neuInsetHint = [
    BoxShadow(
      color: Color(0x12000000),
      offset: Offset(2, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color(0xCCFFFFFF),
      offset: Offset(-2, -2),
      blurRadius: 4,
    ),
  ];

  String get _stepTitleLabel {
    switch (_currentStep) {
      case 0:
        return 'Rating';
      case 1:
        return 'Review';
      case 2:
        return 'Details';
      default:
        return '';
    }
  }

  Widget _buildStepEyebrow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'Step ${_currentStep + 1} of 3 · $_stepTitleLabel',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppTheme.textLight,
        ),
      ),
    );
  }

  TextStyle get _questionStyle => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AppTheme.primaryDark,
      );

  TextStyle get _helperStyle => GoogleFonts.poppins(
        fontSize: 12,
        height: 1.4,
        color: AppTheme.textMedium,
      );

  TextStyle get _fieldLabelStyle => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textDark,
      );

  InputDecoration _neuInputDecoration(String hint, {int maxLines = 3}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textLight),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: InputBorder.none,
      counterText: '',
    );
  }

  Widget _neuMultilineField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 3,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _neuInsetHint,
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark, height: 1.45),
        decoration: _neuInputDecoration(hint, maxLines: maxLines),
      ),
    );
  }

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
    _sessionTookPlaceNotesController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final session = await SupabaseService.client
          .from('individual_sessions')
          .select('tutor_id, learner_id, parent_id, location, scheduled_date, scheduled_time, recurring_session_id')
          .eq('id', widget.sessionId)
          .maybeSingle();

      if (session != null) {
        final isNormal = session['recurring_session_id'] != null;
        safeSetState(() {
          _isTutor = session['tutor_id'] == userId;
          _isParent = session['parent_id'] == userId;
          _sessionData = session;
          _isTrial = !isNormal;
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
        // Trial parent: wouldContinueLessons from _parentWouldBookChoice (1=Yes, 0=No, 2=Not sure->null)
        final wouldBook = _parentWouldBookChoice != null
            ? (_parentWouldBookChoice == 1
                ? true
                : (_parentWouldBookChoice == 0 ? false : null))
            : null;
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
          wouldContinueLessons: wouldBook,
          studentProgressRating: _childEngagementRating,
          studentEngagement: _comfortLevelWithSetup, // Reuse field for comfort level
          // Onsite only: family confirmation / dispute
          sessionTookPlace: _isOnsiteSession ? _sessionTookPlace : null,
          sessionTookPlaceNotes: _isOnsiteSession
              ? (_sessionTookPlaceNotesController.text.trim().isEmpty
                  ? null
                  : _sessionTookPlaceNotesController.text.trim())
              : null,
        );
      } else {
        // Learner feedback submission
        final learnerReview = _whatLearnedController.text.trim().isEmpty
            ? _reviewController.text.trim()
            : _whatLearnedController.text.trim();
        // Trial: wouldContinueLessons from choice (1=Yes, 0=No, 2=Not sure->null)
        final wouldContinue = _wouldContinueLessonsChoice != null
            ? (_wouldContinueLessonsChoice == 1
                ? true
                : (_wouldContinueLessonsChoice == 0 ? false : null))
            : null;
        // Normal: learningObjectivesMet from choice (1=Yes, 0=No, 2=Partly->null)
        final learningMet = _learningGoalsChoice != null
            ? (_learningGoalsChoice == 1
                ? true
                : (_learningGoalsChoice == 0 ? false : null))
            : null;
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
          learningObjectivesMet: learningMet ?? _learningObjectivesMet,
          studentProgressRating: _confidenceLevel ?? _studentProgressRating,
          wouldContinueLessons: wouldContinue ?? _wouldContinueLessons,
          // Onsite only: family confirmation / dispute
          sessionTookPlace: _isOnsiteSession ? _sessionTookPlace : null,
          sessionTookPlaceNotes: _isOnsiteSession
              ? (_sessionTookPlaceNotesController.text.trim().isEmpty
                  ? null
                  : _sessionTookPlaceNotesController.text.trim())
              : null,
        );
      }

      if (mounted) {
        // Conversion CTA per PRD: pop with result so parent can show "Book now" action
        final wouldContinue = _isParent
            ? (_parentWouldBookChoice == 1)
            : (!_isTutor && _wouldContinueLessonsChoice == 1);
        Navigator.of(context).pop(
          _isTrial && !_isTutor
              ? {'submitted': true, 'wouldContinue': wouldContinue}
              : true,
        );
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final isFeedbackUnavailable = raw.contains('Feedback system is not available') ||
            raw.contains('PGRST205') ||
            raw.contains('42P01') ||
            raw.contains('Could not find the table');
        final userMessage = isFeedbackUnavailable
            ? (kDebugMode
                ? 'Feedback table missing on Supabase. Apply migration 022_normal_sessions_tables.sql (session_feedback), then retry.'
                : 'We couldn\'t save your feedback. Please try again later or contact support.')
            : 'Unable to submit feedback right now. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
          content: const Text('Please select a star rating to continue.'),
          backgroundColor: AppTheme.softYellow,
          behavior: SnackBarBehavior.floating,
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
        title: Text(
          _isTrial && !_isTutor ? 'How was your trial?' : 'Session feedback',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppTheme.textDark),
          onPressed: _exitFeedbackFlow,
        ),
      ),
      backgroundColor: AppTheme.surfaceColor,
      body: Column(
        children: [
          // Session Context Header
          if (_sessionData != null) _buildSessionContextHeader(),
          // Progress — neumorphic plate
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.neutral50,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _neuRaised,
              ),
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
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: _buildStepContent(),
            ),
          ),
          // Navigation — soft depth
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: InkWell(
                        onTap: _isSubmitting ? null : _previousStep,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.neutral50,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _neuRaised,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Back',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _currentStep == 2
                          ? (_isSubmitting ? null : _submitFeedback)
                          : _nextStep,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.92),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.35),
                              offset: const Offset(3, 4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
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
    final inactiveNeu = !isActive && !isCompleted;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: inactiveNeu ? AppTheme.neutral50 : null,
              gradient: !inactiveNeu
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.88),
                      ],
                    )
                  : null,
              shape: BoxShape.circle,
              boxShadow: inactiveNeu
                  ? _neuInsetHint
                  : [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.28),
                        blurRadius: 8,
                        offset: const Offset(2, 3),
                      ),
                    ],
            ),
            child: Center(
              child: isCompleted
                  ? Icon(PhosphorIcons.check(), color: Colors.white, size: 16)
                  : Text(
                      '${step + 1}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : AppTheme.textMedium,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive || isCompleted
                  ? AppTheme.primaryColor
                  : AppTheme.textLight,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepEyebrow(),
        if (_currentStep == 0) _buildRatingStep(),
        if (_currentStep == 1) _buildReviewStep(),
        if (_currentStep == 2) _buildDetailsStep(),
      ],
    );
  }

  Widget _buildRatingStep() {
    // Trial: conversion-focused; Normal: experience-focused
    final String ratingTitle;
    final String ratingSubtitle;
    if (_isTutor) {
      ratingTitle = 'Rate this session';
      ratingSubtitle = 'Help us track session quality and learner progress.';
    } else if (_isTrial) {
      ratingTitle = 'How was your trial session?';
      ratingSubtitle = 'Your feedback helps us match you with the right tutor.';
    } else {
      ratingTitle = 'How was your session?';
      ratingSubtitle = 'Your feedback helps us improve and helps your tutor grow.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ratingTitle,
          style: _questionStyle,
        ),
        const SizedBox(height: 6),
        Text(
          ratingSubtitle,
          style: _helperStyle,
        ),
        const SizedBox(height: 28),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final filled = (_selectedRating ?? 0) >= rating;
              return GestureDetector(
                onTap: () => safeSetState(() => _selectedRating = rating),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral50,
                    shape: BoxShape.circle,
                    boxShadow: filled ? _neuInsetHint : _neuRaised,
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    size: 34,
                    color: filled ? AppTheme.softYellow : AppTheme.textLight.withOpacity(0.45),
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
            style: _questionStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Document what topics and concepts were taught in this session.',
            style: _helperStyle,
          ),
          const SizedBox(height: 16),
          _neuMultilineField(
            controller: _whatWasTaughtController,
            hint: 'e.g. Quadratic equations, factoring, practice problems…',
            maxLines: 5,
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
            style: _questionStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Share your observations about your child\'s engagement and response to this session.',
            style: _helperStyle,
          ),
          const SizedBox(height: 16),
          _neuMultilineField(
            controller: _childResponseController,
            hint: 'e.g. Engaged, asked questions, clearer on the topic…',
            maxLines: 4,
          ),
          const SizedBox(height: 18),
          Text(
            'How engaged was your child? (1-5)',
            style: _fieldLabelStyle,
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

    // Learner feedback – trial: conversion prompts; normal: experience prompts
    if (_isTrial) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Would you continue lessons with this tutor?',
            style: _questionStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Quick tap — then add a sentence or two if you like.',
            style: _helperStyle,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildThreeOptionButton(
                  'Yes',
                  _wouldContinueLessonsChoice == 1,
                  () => safeSetState(() => _wouldContinueLessonsChoice = 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThreeOptionButton(
                  'No',
                  _wouldContinueLessonsChoice == 0,
                  () => safeSetState(() => _wouldContinueLessonsChoice = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThreeOptionButton(
                  'Not sure',
                  _wouldContinueLessonsChoice == 2,
                  () => safeSetState(() => _wouldContinueLessonsChoice = 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'What stood out positively?',
            style: _fieldLabelStyle,
          ),
          const SizedBox(height: 8),
          _neuMultilineField(
            controller: _whatWentWellController,
            hint: 'e.g. Clear explanations, patient pace…',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'What could be better next time?',
            style: _fieldLabelStyle,
          ),
          const SizedBox(height: 8),
          _neuMultilineField(
            controller: _whatCouldImproveController,
            hint: 'e.g. More practice, slower examples…',
            maxLines: 3,
          ),
        ],
      );
    }

    // Normal learner: experience-focused prompts per PRD
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Did you achieve your learning goals?',
          style: _questionStyle,
        ),
        const SizedBox(height: 6),
        Text(
          'Help us understand your session experience.',
          style: _helperStyle,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildThreeOptionButton(
                'Yes',
                _learningGoalsChoice == 1,
                () => safeSetState(() => _learningGoalsChoice = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildThreeOptionButton(
                'Partly',
                _learningGoalsChoice == 2,
                () => safeSetState(() => _learningGoalsChoice = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildThreeOptionButton(
                'No',
                _learningGoalsChoice == 0,
                () => safeSetState(() => _learningGoalsChoice = 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Would you recommend this tutor?',
          style: _fieldLabelStyle,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildYesNoButton(true, _wouldRecommend, (v) => safeSetState(() => _wouldRecommend = v))),
            const SizedBox(width: 12),
            Expanded(child: _buildYesNoButton(false, _wouldRecommend, (v) => safeSetState(() => _wouldRecommend = v))),
          ],
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
            style: _questionStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Track learner progress and plan ahead.',
            style: _helperStyle,
          ),
          const SizedBox(height: 16),
          // Learner Progress
          Text(
            'Specific progress observations',
            style: _fieldLabelStyle,
          ),
          const SizedBox(height: 8),
          _neuMultilineField(
            controller: _learnerProgressController,
            hint: 'e.g. Strong on algebra basics; needs word-problem practice…',
            maxLines: 3,
          ),
          const SizedBox(height: 18),
          // Student Engagement
          Text(
            'How engaged was the learner? (1-5)',
            style: _fieldLabelStyle,
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
                        : AppTheme.neutral50,
                    shape: BoxShape.circle,
                    boxShadow: _studentEngagement == engagement
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(2, 3),
                            ),
                          ]
                        : _neuRaised,
                    border: Border.all(
                      color: _studentEngagement == engagement
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      width: _studentEngagement == engagement ? 2 : 0,
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
          const SizedBox(height: 18),
          // Homework Assigned
          Text(
            'Homework or assignments given',
            style: _fieldLabelStyle,
          ),
          const SizedBox(height: 8),
          _neuMultilineField(
            controller: _homeworkAssignedController,
            hint: 'e.g. Exercises 1–10 p.45, review ch.3…',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // Next Focus Areas
          Text(
            'What to focus on next session',
            style: _fieldLabelStyle,
          ),
          const SizedBox(height: 8),
          _neuMultilineField(
            controller: _nextFocusAreasController,
            hint: 'e.g. Quadratics, graphing, timed practice…',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // Concerns
          Text(
            'Any concerns or areas needing attention?',
            style: _fieldLabelStyle,
          ),
          const SizedBox(height: 8),
          _neuMultilineField(
            controller: _concernsController,
            hint: 'e.g. Needs pacing support, confidence…',
            maxLines: 2,
          ),
        ],
      );
    }
    
    if (_isParent) {
      // Trial parent: conversion prompts – "Would you book regular sessions?"
      if (_isTrial) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Would you book regular sessions with this tutor?',
              style: _questionStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps us match your child with the right tutor.',
              style: _helperStyle,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildThreeOptionButton(
                    'Yes',
                    _parentWouldBookChoice == 1,
                    () => safeSetState(() => _parentWouldBookChoice = 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThreeOptionButton(
                    'No',
                    _parentWouldBookChoice == 0,
                    () => safeSetState(() => _parentWouldBookChoice = 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThreeOptionButton(
                    'Not sure',
                    _parentWouldBookChoice == 2,
                    () => safeSetState(() => _parentWouldBookChoice = 2),
                  ),
                ),
              ],
            ),
          ],
        );
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional feedback',
            style: _questionStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Help us understand your experience and improve.',
            style: _helperStyle,
          ),
          const SizedBox(height: 18),
          // Tutor Communication
          Text(
            'Did the tutor communicate clearly about your child\'s progress?',
            style: _fieldLabelStyle,
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
              hintText: 'Add any notes about communication...',
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
          if (_isOnsiteSession) ...[
            const SizedBox(height: 20),
            Text(
              'Was the location safe and appropriate?',
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
            const SizedBox(height: 20),
            _buildOnsiteSessionTookPlaceSection(),
          ],
          const SizedBox(height: 20),
          // Next Session Focus
          Text(
            'Would you like the tutor to focus on anything specific next time?',
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

    // Learner Details – trial: optional learn/confidence; normal: experience prompts
    if (_isTrial) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional details',
            style: _questionStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'Share more about your trial experience.',
            style: _helperStyle,
          ),
          const SizedBox(height: 16),
          Text(
            'What did you learn?',
            style: _fieldLabelStyle,
          ),
          const SizedBox(height: 8),
          _neuMultilineField(
            controller: _whatLearnedController,
            hint: 'e.g. Algebra basics, strategies you can reuse…',
            maxLines: 3,
          ),
          if (_isOnsiteSession) ...[
            const SizedBox(height: 20),
            _buildOnsiteSessionTookPlaceSection(),
          ],
          const SizedBox(height: 18),
          Text(
            'How confident do you feel about the topic? (1-5)',
            style: _fieldLabelStyle,
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
                        : AppTheme.neutral50,
                    shape: BoxShape.circle,
                    boxShadow: _confidenceLevel == confidence
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(2, 3),
                            ),
                          ]
                        : _neuRaised,
                    border: Border.all(
                      color: _confidenceLevel == confidence
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      width: _confidenceLevel == confidence ? 2 : 0,
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

    // Normal learner: optional experience details per PRD
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional feedback',
          style: _questionStyle,
        ),
        const SizedBox(height: 6),
        Text(
          'Share what worked and what could be improved.',
          style: _helperStyle,
        ),
        const SizedBox(height: 18),
        if (_isOnsiteSession) ...[
          _buildOnsiteSessionTookPlaceSection(),
          const SizedBox(height: 18),
        ],
        Text(
          'What went well?',
          style: _fieldLabelStyle,
        ),
        const SizedBox(height: 8),
        _neuMultilineField(
          controller: _whatWentWellController,
          hint: 'e.g. Clear explanations, helpful examples…',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        // What Could Improve
        Text(
          'What could improve?',
          style: _fieldLabelStyle,
        ),
        const SizedBox(height: 8),
        _neuMultilineField(
          controller: _whatCouldImproveController,
          hint: 'e.g. More practice, slower pace on harder parts…',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildThreeOptionButton(String label, bool isSelected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.12)
                : AppTheme.neutral50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.45)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(2, 3),
                    ),
                  ]
                : _neuRaised,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYesNoButton(bool yes, bool? currentValue, Function(bool) onChanged) {
    final isSelected = currentValue == yes;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => safeSetState(() => onChanged(yes)),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.12)
                : AppTheme.neutral50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.45)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(2, 3),
                    ),
                  ]
                : _neuRaised,
          ),
          alignment: Alignment.center,
          child: Text(
            yes ? 'Yes' : 'No',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
            ),
          ),
        ),
      ),
    );
  }
  
  /// Onsite-only: \"Did this session take place?\" section (family confirmation / dispute)
  Widget _buildOnsiteSessionTookPlaceSection() {
    if (!_isOnsiteSession || _isTutor) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Did this session take place as scheduled?',
          style: _fieldLabelStyle,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildThreeOptionButton(
                'Yes',
                _sessionTookPlace == 'yes',
                () => safeSetState(() => _sessionTookPlace = 'yes'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildThreeOptionButton(
                'Partly',
                _sessionTookPlace == 'partially',
                () => safeSetState(() => _sessionTookPlace = 'partially'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildThreeOptionButton(
                'No',
                _sessionTookPlace == 'no',
                () => safeSetState(() => _sessionTookPlace = 'no'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _neuMultilineField(
          controller: _sessionTookPlaceNotesController,
          hint: 'Brief detail if needed…',
          maxLines: 2,
        ),
      ],
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
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.neutral50,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _neuRaised,
        ),
        child: Row(
          children: [
            Icon(
              isOnline ? PhosphorIcons.monitor() : PhosphorIcons.mapPin(),
              size: 18,
              color: isOnline ? AppTheme.accentBlue : AppTheme.accentGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'Online lesson' : 'Onsite session',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (dateTimeText.isNotEmpty)
                    Text(
                      dateTimeText,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textMedium,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

