import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/unblock_request_service.dart';

/// Tutor Admin Feedback Details Screen
///
/// Displays detailed admin feedback including:
/// - Admin review notes
/// - Improvement requests (specific areas to fix)
/// - Action buttons based on status (update profile, request unblock/unhide)
class TutorAdminFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> tutorProfile;

  const TutorAdminFeedbackScreen({Key? key, required this.tutorProfile})
    : super(key: key);

  @override
  State<TutorAdminFeedbackScreen> createState() =>
      _TutorAdminFeedbackScreenState();
}

class _TutorAdminFeedbackScreenState extends State<TutorAdminFeedbackScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _updatedProfile;

  @override
  void initState() {
    super.initState();
    _loadUpdatedProfile();
  }

  Future<void> _loadUpdatedProfile() async {
    safeSetState(() => _isLoading = true);
    try {
      final userId = widget.tutorProfile['user_id'] as String?;
      if (userId != null) {
        final profile = await SurveyRepository.getTutorSurvey(userId);
        safeSetState(() {
          _updatedProfile = profile;
          _isLoading = false;
        });
      } else {
        safeSetState(() => _isLoading = false);
      }
    } catch (e) {
      LogService.debug('Error loading profile: $e');
      safeSetState(() => _isLoading = false);
    }
  }

  String get _status =>
      (_updatedProfile ?? widget.tutorProfile)['status'] as String? ??
      'pending';
  String? get _adminNotes =>
      (_updatedProfile ?? widget.tutorProfile)['admin_review_notes'] as String?;
  List<String> get _improvementRequests {
    final requests =
        (_updatedProfile ?? widget.tutorProfile)['improvement_requests'];
    if (requests is List) {
      return requests.cast<String>();
    }
    return [];
  }

  String? get _reviewedAt {
    final reviewedAt =
        (_updatedProfile ?? widget.tutorProfile)['reviewed_at'] as String?;
    if (reviewedAt != null) {
      try {
        final date = DateTime.parse(reviewedAt);
        return date.toLocal().toString().split('.')[0]; // Remove milliseconds
      } catch (e) {
        return reviewedAt;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () =>
              Navigator.of(context).pop(true), // Return true to refresh
        ),
        title: Text(
          'Admin Feedback',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(),
                  const SizedBox(height: 16),
                  if (_adminNotes != null && _adminNotes!.isNotEmpty) ...[
                    _buildNeumorphicSection(
                      title: 'Admin Feedback',
                      icon: Icons.feedback_outlined,
                      color: AppTheme.primaryColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFeedbackContent(_adminNotes!),
                          if (_reviewedAt != null) ...[
                            const SizedBox(height: 12),
                            _buildTimestampBadge(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_improvementRequests.isNotEmpty) ...[
                    _buildNeumorphicSection(
                      title: 'Areas to Improve',
                      icon: Icons.checklist_rtl_outlined,
                      color: AppTheme.accentOrange,
                      child: _buildImprovementRequests(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusHeader() {
    Color statusColor;
    Color statusLightColor;
    IconData statusIcon;
    String statusText;

    switch (_status) {
      case 'needs_improvement':
        statusColor = AppTheme.accentOrange;
        statusLightColor = AppTheme.accentLightOrange;
        statusIcon = Icons.info_outline;
        statusText = 'Profile Needs Improvement';
        break;
      case 'rejected':
        statusColor = AppTheme.primaryColor;
        statusLightColor = AppTheme.accentLightBlue;
        statusIcon = Icons.cancel_outlined;
        statusText = 'Application Rejected';
        break;
      case 'blocked':
      case 'suspended':
        statusColor = AppTheme.error;
        statusLightColor = const Color(0xFFFFE5E5);
        statusIcon = Icons.block_outlined;
        statusText =
            'Account ${_status == 'blocked' ? 'Blocked' : 'Suspended'}';
        break;
      default:
        statusColor = AppTheme.textMedium;
        statusLightColor = AppTheme.neutral100;
        statusIcon = Icons.info_outline;
        statusText = 'Status: $_status';
    }

    return _buildNeumorphicCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusLightColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, size: 20, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildNeumorphicCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Light shadow (top-left)
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 10,
            offset: const Offset(-4, -4),
            spreadRadius: 0,
          ),
          // Dark shadow (bottom-right)
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTimestampBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.neutral200, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textMedium),
          const SizedBox(width: 6),
          Text(
            'Feedback given: $_reviewedAt',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackContent(String notes) {
    return Text(
      notes,
      style: GoogleFonts.poppins(
        fontSize: 13,
        color: AppTheme.textDark,
        height: 1.6,
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildImprovementRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Please address the following areas:',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMedium,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 12),
        ..._improvementRequests.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key < _improvementRequests.length - 1 ? 10 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 10),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textDark,
                      height: 1.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    // If status changed to pending/approved, show success message
    if (_status == 'pending' || _status == 'approved') {
      return _buildNeumorphicCard(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentLightGreen.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 32,
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _status == 'approved'
                    ? 'Your profile has been approved!'
                    : 'Your updates have been submitted for review.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentGreen,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Action buttons based on status
    if (_status == 'needs_improvement' || _status == 'rejected') {
      return _buildNeumorphicButton(
        onPressed: () => _navigateToOnboarding(),
        icon: Icons.edit_rounded,
        label: _status == 'rejected'
            ? 'Update Profile & Re-apply'
            : 'Update Profile',
        color: _status == 'rejected'
            ? AppTheme.primaryColor
            : AppTheme.accentOrange,
      );
    }

    // Blocked/Suspended - Request unblock/unhide
    if (_status == 'blocked' || _status == 'suspended') {
      return Column(
        children: [
          _buildNeumorphicCard(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5).withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you believe this action was taken in error, you can request a review of your account.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textDark,
                        height: 1.4,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildNeumorphicOutlinedButton(
            onPressed: () => _requestUnblock(),
            icon: Icons.lock_open_rounded,
            label:
                'Request ${_status == 'blocked' ? 'Unblock' : 'Reactivation'}',
            color: AppTheme.error,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNeumorphicButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicOutlinedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 8,
            offset: const Offset(-3, -3),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(3, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToOnboarding() async {
    final userId = widget.tutorProfile['user_id'] as String?;
    if (userId == null) return;

    final result = await Navigator.of(context).pushNamed(
      '/tutor-onboarding',
      arguments: {
        'userId': userId,
        'existingData': _updatedProfile ?? widget.tutorProfile,
        'needsImprovement': true,
      },
    );

    // Reload profile after returning from onboarding
    if (result == true || result == null) {
      await _loadUpdatedProfile();
      // Check if status changed - if so, pop this screen too
      final newStatus = _updatedProfile?['status'] as String?;
      if (newStatus == 'pending' || newStatus == 'approved') {
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to refresh home screen
        }
      }
    }
  }

  Future<void> _requestUnblock() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Request Account Review',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your request will be sent to the admin team for review. You will be notified once a decision has been made.',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            Text(
              'Reason (Optional):',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Explain why you believe this action was taken in error...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text('Submit Request', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        final tutorId = widget.tutorProfile['id'] as String?;
        if (tutorId == null) {
          throw Exception('Tutor ID not found');
        }

        final requestType = _status == 'blocked' ? 'unblock' : 'unhide';

        await UnblockRequestService.submitRequest(
          tutorId: tutorId,
          requestType: requestType,
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : null,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Your request has been submitted. Admins will review it shortly.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to submit request: ${e.toString()}',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        reasonController.dispose();
      }
    }
  }
}
