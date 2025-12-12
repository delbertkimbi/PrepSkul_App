import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/tutor_onboarding_progress_service.dart';
import '../screens/tutor_onboarding_screen.dart';

/// Beautiful onboarding progress tracker widget
/// Shows all steps with completion status and allows jumping to specific steps
class OnboardingProgressTracker extends StatefulWidget {
  final String userId;

  const OnboardingProgressTracker({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<OnboardingProgressTracker> createState() =>
      _OnboardingProgressTrackerState();
}

class _OnboardingProgressTrackerState
    extends State<OnboardingProgressTracker> {
  Map<String, dynamic>? _progress;
  bool _isLoading = true;

  // Step definitions with icons and titles
  final List<Map<String, dynamic>> _steps = [
    {
      'step': 0,
      'title': 'Contact Information',
      'icon': Icons.phone_outlined,
      'description': 'Email and phone number',
    },
    {
      'step': 1,
      'title': 'Academic Background',
      'icon': Icons.school_outlined,
      'description': 'Education and qualifications',
    },
    {
      'step': 2,
      'title': 'Location',
      'icon': Icons.location_on_outlined,
      'description': 'City and quarter',
    },
    {
      'step': 3,
      'title': 'Teaching Focus',
      'icon': Icons.category_outlined,
      'description': 'Tutoring areas and learner levels',
    },
    {
      'step': 4,
      'title': 'Specializations',
      'icon': Icons.subject_outlined,
      'description': 'Subjects you can teach',
    },
    {
      'step': 5,
      'title': 'Experience',
      'icon': Icons.work_outline,
      'description': 'Teaching experience and motivation',
    },
    {
      'step': 6,
      'title': 'Teaching Style',
      'icon': Icons.psychology_outlined,
      'description': 'Preferred mode and approaches',
    },
    {
      'step': 7,
      'title': 'Digital Readiness',
      'icon': Icons.devices_outlined,
      'description': 'Devices and tools',
    },
    {
      'step': 8,
      'title': 'Availability',
      'icon': Icons.calendar_today_outlined,
      'description': 'Weekly schedule',
    },
    {
      'step': 9,
      'title': 'Payment Expectations',
      'icon': Icons.trending_up_outlined,
      'description': 'Expected rate and pricing',
    },
    {
      'step': 10,
      'title': 'Payment Method',
      'icon': Icons.payment_outlined,
      'description': 'How you receive payments',
    },
    {
      'step': 11,
      'title': 'Verification',
      'icon': Icons.verified_user_outlined,
      'description': 'Documents and credentials',
    },
    {
      'step': 12,
      'title': 'Media Links',
      'icon': Icons.link_outlined,
      'description': 'Social media and video',
    },
    {
      'step': 13,
      'title': 'Personal Statement',
      'icon': Icons.edit_note_outlined,
      'description': 'Final review and agreements',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final progress =
          await TutorOnboardingProgressService.loadProgress(widget.userId);
      setState(() {
        _progress = progress;
        _isLoading = false;
      });
    } catch (e) {
      LogService.warning('Error loading progress: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _isStepComplete(int step) {
    if (_progress == null) return false;
    final completedSteps =
        _progress!['completed_steps'] as List<dynamic>? ?? [];
    return completedSteps.contains(step);
  }

  bool _hasStepData(int step) {
    if (_progress == null) return false;
    final stepData = _progress!['step_data'] as Map<String, dynamic>? ?? {};
    final stepKey = step.toString();
    final data = stepData[stepKey] as Map<String, dynamic>?;
    if (data == null || data.isEmpty) return false;
    
    // Check if step has meaningful data (exclude null, empty strings, empty lists)
    return data.values.any((value) {
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      if (value is Map) return value.isNotEmpty;
      if (value is bool) return value;
      if (value is num) return value != 0;
      return true;
    });
  }

  void _navigateToStep(int step) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TutorOnboardingScreen(
          basicInfo: {
            'jumpToStep': step,
          },
        ),
      ),
    ).then((_) {
      // Reload progress after returning
      _loadProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final completedCount = _steps.where((s) => _isStepComplete(s['step'] as int)).length;
    final totalSteps = _steps.length;
    final progressPercentage = (completedCount / totalSteps * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.checklist_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Onboarding Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedCount of $totalSteps steps completed',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$progressPercentage%',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completedCount / totalSteps,
              minHeight: 8,
              backgroundColor: AppTheme.softBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Steps list
          ..._steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final stepNumber = step['step'] as int;
            final isComplete = _isStepComplete(stepNumber);
            final hasData = _hasStepData(stepNumber);
            final isInProgress = hasData && !isComplete;

            return _buildStepItem(
              step: step,
              stepNumber: stepNumber,
              isComplete: isComplete,
              isInProgress: isInProgress,
              isLast: index == _steps.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required Map<String, dynamic> step,
    required int stepNumber,
    required bool isComplete,
    required bool isInProgress,
    required bool isLast,
  }) {
    final title = step['title'] as String;
    final description = step['description'] as String;
    final icon = step['icon'] as IconData;

    return InkWell(
      onTap: () => _navigateToStep(stepNumber),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isComplete
              ? Colors.green[50]
              : isInProgress
                  ? Colors.blue[50]
                  : AppTheme.softCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isComplete
                ? Colors.green[300]!
                : isInProgress
                    ? Colors.blue[300]!
                    : AppTheme.softBorder,
            width: isComplete || isInProgress ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Step number and icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isComplete
                    ? Colors.green
                    : isInProgress
                        ? Colors.blue
                        : AppTheme.softBorder,
                shape: BoxShape.circle,
              ),
              child: isComplete
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    )
                  : isInProgress
                      ? const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        )
                      : Center(
                          child: Text(
                            '${stepNumber + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
            ),
            const SizedBox(width: 16),
            // Step info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isComplete
                            ? Colors.green[700]
                            : isInProgress
                                ? Colors.blue[700]
                                : AppTheme.textMedium,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isComplete
                                ? Colors.green[900]
                                : isInProgress
                                    ? Colors.blue[900]
                                    : AppTheme.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isComplete
                          ? Colors.green[700]
                          : isInProgress
                              ? Colors.blue[700]
                              : AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isComplete
                    ? Colors.green[100]
                    : isInProgress
                        ? Colors.blue[100]
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isComplete
                    ? 'Complete'
                    : isInProgress
                        ? 'In Progress'
                        : 'Not Started',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isComplete
                      ? Colors.green[900]
                      : isInProgress
                          ? Colors.blue[900]
                          : AppTheme.textMedium,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Arrow icon
            Icon(
              Icons.chevron_right,
              color: AppTheme.textMedium,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

