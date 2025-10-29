import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/models/profile_completion.dart';

/// Widget to display profile completion status with progress bar and checklist
class ProfileCompletionWidget extends StatelessWidget {
  final ProfileCompletionStatus status;
  final VoidCallback? onEditSection;
  final bool showDetails;

  const ProfileCompletionWidget({
    super.key,
    required this.status,
    this.onEditSection,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${status.percentage.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: status.percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
            ),
          ),

          const SizedBox(height: 8),

          // Progress Text
          Text(
            '${status.completedSteps} of ${status.totalSteps} sections completed',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),

          // Show details if requested
          if (showDetails) ...[
            const SizedBox(height: 20),
            _buildSectionsList(context),
          ],

          // Warning if not complete
          if (!status.isComplete) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete all required sections to submit for verification',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade900,
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

  Widget _buildSectionsList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sections',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ...status.sections.map((section) => _buildSectionItem(section)),
      ],
    );
  }

  Widget _buildSectionItem(ProfileSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Checkbox Icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: section.isComplete
                  ? AppTheme.primaryColor
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: section.isComplete
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),

          const SizedBox(width: 12),

          // Section Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                ),
                if (!section.isComplete && section.missingFields.isNotEmpty)
                  Text(
                    'Missing: ${section.missingFields.map((f) => f.label).join(', ')}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.red.shade600,
                    ),
                  ),
              ],
            ),
          ),

          // Edit Button
          if (!section.isComplete && onEditSection != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              color: AppTheme.primaryColor,
              onPressed: onEditSection,
            ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (status.percentage == 100) {
      return Colors.green;
    } else if (status.percentage >= 70) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

/// Compact version for dashboard
class ProfileCompletionBanner extends StatelessWidget {
  final ProfileCompletionStatus status;
  final VoidCallback? onTap;

  const ProfileCompletionBanner({super.key, required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (status.isComplete) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${status.percentage.toStringAsFixed(0)}% complete • ${status.totalSteps - status.completedSteps} sections remaining',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

