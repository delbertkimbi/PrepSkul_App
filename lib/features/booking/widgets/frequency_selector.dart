import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/profile/screens/my_children_screen.dart';

/// Step 1: Session Frequency Selector
///
/// Lets user choose how many sessions per week (1x, 2x, 3x, 4x, custom)
/// Shows monthly pricing estimate for each option
/// Pre-fills from survey data if available
class FrequencySelector extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final int? initialFrequency;
  final Function(int) onFrequencySelected;
  final bool showMultiLearnerHint; // Show hint for parents with single learner
  final int? learnerCount; // Number of learners selected (for adapting pricing display)

  const FrequencySelector({
    Key? key,
    required this.tutor,
    this.initialFrequency,
    required this.onFrequencySelected,
    this.showMultiLearnerHint = false,
    this.learnerCount,
  }) : super(key: key);

  @override
  State<FrequencySelector> createState() => _FrequencySelectorState();
}

class _FrequencySelectorState extends State<FrequencySelector> {
  int? _selectedFrequency;

  @override
  void initState() {
    super.initState();
    _selectedFrequency = widget.initialFrequency;
  }

  Map<String, dynamic> _calculatePricing(int sessionsPerWeek) {
    return PricingService.calculateFromTutorData(
      widget.tutor,
      overrideSessionsPerWeek: sessionsPerWeek,
    );
  }

  /// When learnerCount > 1, returns map of frequency -> discounted monthly total.
  Future<Map<int, double>> _getMultiLearnerDiscountedMonthly() async {
    final count = widget.learnerCount ?? 1;
    if (count <= 1) return {};
    final result = <int, double>{};
    for (int f = 1; f <= 4; f++) {
      final pricing = _calculatePricing(f);
      final baseMonthly = pricing['perMonth'] as double;
      final discounted = await PricingService.calculateMultiLearnerMonthlyTotal(
        baseMonthlyTotal: baseMonthly,
        learnerCount: count,
      );
      result[f] = discounted;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final useMultiLearnerPricing = widget.learnerCount != null && widget.learnerCount! > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'How many sessions per week?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the frequency that works best for your schedule',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Frequency options (with multi-learner discounted prices when learnerCount > 1)
          useMultiLearnerPricing
              ? FutureBuilder<Map<int, double>>(
                  future: _getMultiLearnerDiscountedMonthly(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final discountedMap = snapshot.data ?? {};
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFrequencyOption(
                          frequency: 1,
                          label: '1x per week',
                          description: '4 sessions per month',
                          icon: Icons.calendar_today,
                          displayMonthlyOverride: discountedMap[1],
                        ),
                        const SizedBox(height: 12),
                        _buildFrequencyOption(
                          frequency: 2,
                          label: '2x per week',
                          description: '8 sessions per month',
                          icon: Icons.event_repeat,
                          isRecommended: true,
                          displayMonthlyOverride: discountedMap[2],
                        ),
                        const SizedBox(height: 12),
                        _buildFrequencyOption(
                          frequency: 3,
                          label: '3x per week',
                          description: '12 sessions per month',
                          icon: Icons.event_available,
                          displayMonthlyOverride: discountedMap[3],
                        ),
                        const SizedBox(height: 12),
                        _buildFrequencyOption(
                          frequency: 4,
                          label: '4x per week',
                          description: '16 sessions per month',
                          icon: Icons.event_note,
                          displayMonthlyOverride: discountedMap[4],
                        ),
                      ],
                    );
                  },
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFrequencyOption(
                      frequency: 1,
                      label: '1x per week',
                      description: '4 sessions per month',
                      icon: Icons.calendar_today,
                    ),
                    const SizedBox(height: 12),
                    _buildFrequencyOption(
                      frequency: 2,
                      label: '2x per week',
                      description: '8 sessions per month',
                      icon: Icons.event_repeat,
                      isRecommended: true,
                    ),
                    const SizedBox(height: 12),
                    _buildFrequencyOption(
                      frequency: 3,
                      label: '3x per week',
                      description: '12 sessions per month',
                      icon: Icons.event_available,
                    ),
                    const SizedBox(height: 12),
                    _buildFrequencyOption(
                      frequency: 4,
                      label: '4x per week',
                      description: '16 sessions per month',
                      icon: Icons.event_note,
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          // Multi-learner hint (for parents with single learner)
          if (widget.showMultiLearnerHint) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'If you have more than one child who needs personal guidance, you can add other children in your profile.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyChildrenScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        'Add other learners',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'More sessions per week lead to better learning outcomes. You can always adjust later.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyOption({
    required int frequency,
    required String label,
    String? description, // Make optional
    required IconData icon,
    bool isRecommended = false,
    double? displayMonthlyOverride, // When set (e.g. multi-learner discounted), use instead of single-learner perMonth
  }) {
    final isSelected = _selectedFrequency == frequency;
    final pricing = _calculatePricing(frequency);
    final monthlyTotal = displayMonthlyOverride ?? (pricing['perMonth'] as double);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFrequency = frequency);
        widget.onFrequencySelected(frequency);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 16),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Popular',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    PricingService.formatPrice(monthlyTotal),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    widget.learnerCount != null && widget.learnerCount! > 1
                        ? 'per month (${widget.learnerCount} learners)'
                        : 'per month',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
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
