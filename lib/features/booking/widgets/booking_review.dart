import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/features/booking/services/abandoned_booking_service.dart';

/// Step 5: Booking Review
///
/// Beautiful summary of all booking details:
/// - Tutor info
/// - Session schedule (frequency, days, times)
/// - Location
/// - Total pricing breakdown
/// - Payment plan options (monthly, bi-weekly, weekly)
///
/// This is the final confirmation before submitting
class BookingReview extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final int frequency;
  final List<String> selectedDays;
  final Map<String, String> selectedTimes;
  final String location;
  final String? address;
  final String? locationDescription;
  final Map<String, String>? sessionLocations; // For flexible bookings
  final Map<String, Map<String, String?>>? locationDetails; // For flexible bookings
  final String? initialPaymentPlan;
  final Function(String paymentPlan) onPaymentPlanSelected;
  final double? estimatedTransportationCost; // Estimated transportation cost per session
  final int? learnerCount; // Number of learners selected (for adapting pricing display)

  const BookingReview({
    Key? key,
    required this.tutor,
    required this.frequency,
    required this.selectedDays,
    required this.selectedTimes,
    required this.location,
    this.address,
    this.locationDescription,
    this.sessionLocations,
    this.locationDetails,
    this.initialPaymentPlan,
    required this.onPaymentPlanSelected,
    this.estimatedTransportationCost,
    this.learnerCount,
  }) : super(key: key);

  @override
  State<BookingReview> createState() => _BookingReviewState();
}

class _BookingReviewState extends State<BookingReview> {
  String? _selectedPaymentPlan;
  DateTime? _reviewScreenShownAt; // Track when review screen was shown for timing check

  @override
  void initState() {
    super.initState();
    _selectedPaymentPlan =
        widget.initialPaymentPlan; // Don't default to monthly
    _reviewScreenShownAt = DateTime.now(); // Record when screen was shown
    // Track that user reached review screen (for abandoned booking reminders)
    _trackReviewScreenReached();
  }

  Future<void> _trackReviewScreenReached() async {
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String?;
      if (userId == null) return;

      final tutorId = widget.tutor['user_id'] as String?;
      if (tutorId == null) return;

      // Calculate monthly total
      final pricing = PricingService.calculateFromTutorData(widget.tutor);
      final perSession = pricing['perSession'] as double;
      final sessionsPerMonth = widget.frequency * 4; // 4 weeks
      final monthlySessionTotal = perSession * sessionsPerMonth;
      final transportationCostPerSession = widget.estimatedTransportationCost ?? 0.0;
      final isOnsite = widget.location == 'onsite' || widget.location == 'hybrid';
      final monthlyTransportationTotal = isOnsite && transportationCostPerSession > 0
          ? transportationCostPerSession * sessionsPerMonth
          : 0.0;
      final monthlyTotal = monthlySessionTotal + monthlyTransportationTotal;

      // Prepare booking data for tracking
      final bookingData = {
        'tutor_id': tutorId,
        'tutor_name': widget.tutor['full_name'] ?? widget.tutor['name'] ?? 'Tutor',
        'tutor_avatar_url': widget.tutor['avatar_url'] ?? widget.tutor['profile_photo_url'],
        'subject': widget.tutor['subjects'] != null 
            ? (widget.tutor['subjects'] as List).isNotEmpty 
                ? (widget.tutor['subjects'] as List)[0].toString()
                : null
            : null,
        'frequency': widget.frequency,
        'days': widget.selectedDays,
        'times': widget.selectedTimes,
        'location': widget.location,
        'address': widget.address,
        'monthly_total': monthlyTotal,
        'per_session': perSession,
        'transportation_cost': widget.estimatedTransportationCost,
      };

      await AbandonedBookingService.trackReviewScreenReached(
        userId: userId,
        tutorId: tutorId,
        bookingType: 'normal',
        bookingData: bookingData,
      );
    } catch (e) {
      // Silently fail - tracking shouldn't break the UI
    }
  }

  void _selectPaymentPlan(String plan) {
    setState(() => _selectedPaymentPlan = plan);
    widget.onPaymentPlanSelected(plan);
  }

  /// When learnerCount > 1, returns (baseTotal, discountedTotal) for payment screen display.
  Future<({double baseTotal, double discountedTotal})?> _getMultiLearnerTotals() async {
    final count = widget.learnerCount ?? 1;
    if (count <= 1) return null;
    final pricing = PricingService.calculateFromTutorData(widget.tutor);
    final perSession = pricing['perSession'] as double;
    final sessionsPerMonth = widget.frequency * 4;
    final baseSessionMonthly = perSession * sessionsPerMonth;
    final isOnsite = widget.location == 'onsite' || widget.location == 'hybrid';
    final transportationCostPerSession = widget.estimatedTransportationCost ?? 0.0;
    final monthlyTransportationTotal = isOnsite && transportationCostPerSession > 0
        ? transportationCostPerSession * sessionsPerMonth
        : 0.0;
    final discountedSessionMonthly = await PricingService.calculateMultiLearnerMonthlyTotal(
      baseMonthlyTotal: baseSessionMonthly,
      learnerCount: count,
    );
    return (
      baseTotal: baseSessionMonthly + monthlyTransportationTotal,
      discountedTotal: discountedSessionMonthly + monthlyTransportationTotal,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate pricing
    final pricing = PricingService.calculateFromTutorData(widget.tutor);
    final perSession = pricing['perSession'] as double;
    final sessionsPerMonth = widget.frequency * 4; // 4 weeks
    final monthlySessionTotal = perSession * sessionsPerMonth;
    
    // Calculate transportation cost (only for onsite sessions)
    final isOnsite = widget.location == 'onsite' || widget.location == 'hybrid';
    final transportationCostPerSession = widget.estimatedTransportationCost ?? 0.0;
    final monthlyTransportationTotal = isOnsite && transportationCostPerSession > 0
        ? transportationCostPerSession * sessionsPerMonth
        : 0.0;
    
    // Total monthly cost (session + transportation) - single learner or fallback
    final monthlyTotal = monthlySessionTotal + monthlyTransportationTotal;
    final useMultiLearnerDiscount = widget.learnerCount != null && widget.learnerCount! > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Review Your Booking',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check all details before sending request',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Tutor Card
          _buildTutorCard(),
          const SizedBox(height: 24),

          // Schedule Summary
          _buildSectionCard(
            title: 'Session Schedule',
            icon: Icons.calendar_today,
            color: Colors.blue,
            children: [
              _buildDetailRow('Frequency', '${widget.frequency}x per week'),
              const SizedBox(height: 12),
              _buildDetailRow('Days', widget.selectedDays.join(', ')),
              const SizedBox(height: 12),
              ...widget.selectedDays.map((day) {
                final time = widget.selectedTimes[day] ?? 'Not set';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$day: ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 16),

          // Location Summary
          _buildSectionCard(
            title: 'Location',
            icon: Icons.place,
            color: Colors.green,
            children: [
              if (widget.location == 'hybrid' && widget.sessionLocations != null) ...[
                // Flexible booking: show per-session locations
                ...widget.selectedDays.map((day) {
                  final time = widget.selectedTimes[day] ?? '';
                  if (time.isEmpty) return const SizedBox.shrink();
                  final sessionKey = '$day-$time';
                  final sessionLocation = widget.sessionLocations![sessionKey] ?? 'online';
                  final locationInfo = widget.locationDetails?[sessionKey];
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              sessionLocation == 'online' ? Icons.videocam : Icons.home,
                              size: 16,
                              color: sessionLocation == 'online' ? Colors.blue : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$day at $time',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                sessionLocation.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: sessionLocation == 'online' 
                                  ? Colors.blue[50] 
                                  : Colors.green[50],
                              labelStyle: TextStyle(
                                color: sessionLocation == 'online' 
                                    ? Colors.blue[900] 
                                    : Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                        if (sessionLocation == 'onsite' && locationInfo != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (locationInfo['address'] != null) ...[
                                  Text(
                                    locationInfo['address']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                                if (locationInfo['locationDescription'] != null &&
                                    locationInfo['locationDescription']!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    locationInfo['locationDescription']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ] else ...[
                // Standard booking: show single location
                _buildDetailRow('Format', widget.location.toUpperCase()),
                if (widget.address != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Address', widget.address!),
                ],
                if (widget.locationDescription != null && widget.locationDescription!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Description', widget.locationDescription!),
                ],
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Pricing Breakdown (and Payment Plan when multi-learner: use FutureBuilder for discounted totals)
          useMultiLearnerDiscount
              ? FutureBuilder<({double baseTotal, double discountedTotal})?>(
                  future: _getMultiLearnerTotals(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final totals = snapshot.data;
                    final displayTotal = totals?.discountedTotal ?? monthlyTotal;
                    final baseTotalForStrike = totals?.baseTotal;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.05),
                                AppTheme.primaryColor.withOpacity(0.02),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.payments,
                                    size: 24,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Pricing Breakdown',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildPricingRow(
                                'Per Session',
                                PricingService.formatPrice(perSession),
                                isSubtotal: true,
                              ),
                              if (isOnsite && transportationCostPerSession > 0) ...[
                                const SizedBox(height: 12),
                                _buildPricingRow(
                                  'Transportation (per session)',
                                  PricingService.formatPrice(transportationCostPerSession),
                                  isSubtotal: true,
                                  subtitle: 'Round trip compensation',
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Divider(color: Colors.grey[300], thickness: 1),
                              ),
                              if (baseTotalForStrike != null) ...[
                                _buildPricingRow(
                                  'Before discount',
                                  PricingService.formatPrice(baseTotalForStrike),
                                  isSubtotal: false,
                                  strikethrough: true,
                                ),
                                const SizedBox(height: 8),
                              ],
                              _buildPricingRow(
                                'Monthly Total',
                                PricingService.formatPrice(displayTotal),
                                isTotal: true,
                                subtitle: isOnsite && transportationCostPerSession > 0
                                    ? 'Session fee + Transportation (${widget.learnerCount} learners)'
                                    : 'Multi-learner discount applied',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Payment Plan',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPaymentPlanOption(
                          plan: 'monthly',
                          title: 'Pay Monthly',
                          subtitle: 'Full month upfront',
                          amount: displayTotal,
                          discount: null,
                          badge: 'Most Popular',
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentPlanOption(
                          plan: 'biweekly',
                          title: 'Pay Bi-Weekly',
                          subtitle: '2 weeks at a time',
                          amount: displayTotal / 2,
                          discount: null,
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentPlanOption(
                          plan: 'weekly',
                          title: 'Pay Weekly',
                          subtitle: '1 week at a time',
                          amount: displayTotal / 4,
                          discount: null,
                        ),
                      ],
                    );
                  },
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.05),
                            AppTheme.primaryColor.withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.payments,
                                size: 24,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Pricing Breakdown',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildPricingRow(
                            'Per Session',
                            PricingService.formatPrice(perSession),
                            isSubtotal: true,
                          ),
                          if (isOnsite && transportationCostPerSession > 0) ...[
                            const SizedBox(height: 12),
                            _buildPricingRow(
                              'Transportation (per session)',
                              PricingService.formatPrice(transportationCostPerSession),
                              isSubtotal: true,
                              subtitle: 'Round trip compensation',
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Colors.grey[300], thickness: 1),
                          ),
                          _buildPricingRow(
                            'Monthly Total',
                            PricingService.formatPrice(monthlyTotal),
                            isTotal: true,
                            subtitle: isOnsite && transportationCostPerSession > 0
                                ? 'Session fee + Transportation'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Payment Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentPlanOption(
                      plan: 'monthly',
                      title: 'Pay Monthly',
                      subtitle: 'Full month upfront',
                      amount: monthlyTotal,
                      discount: null,
                      badge: 'Most Popular',
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentPlanOption(
                      plan: 'biweekly',
                      title: 'Pay Bi-Weekly',
                      subtitle: '2 weeks at a time',
                      amount: monthlyTotal / 2,
                      discount: null,
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentPlanOption(
                      plan: 'weekly',
                      title: 'Pay Weekly',
                      subtitle: '1 week at a time',
                      amount: monthlyTotal / 4,
                      discount: null,
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your request will be sent to ${widget.tutor['full_name']}. They will review and either approve or suggest modifications.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.blue[900],
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

  /// Get tutor avatar image - handles both network URLs and asset paths
  ImageProvider? _getTutorAvatarImage() {
    final avatarUrl = widget.tutor['avatar_url'] ?? widget.tutor['profile_photo_url'];
    
    if (avatarUrl == null || avatarUrl.toString().isEmpty) {
      return null;
    }
    
    final urlString = avatarUrl.toString();
    
    // Check if it's a network URL
    if (urlString.startsWith('http://') || 
        urlString.startsWith('https://') ||
        urlString.startsWith('//')) {
      return NetworkImage(urlString);
    }
    
    // Otherwise, treat as asset path
    return AssetImage(urlString);
  }

  Widget _buildTutorCard() {
    final avatarImage = _getTutorAvatarImage();
    final tutorName = widget.tutor['full_name'] ?? 'Tutor';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: avatarImage,
            onBackgroundImageError: (exception, stackTrace) {
              // Image failed to load, will show fallback
            },
            child: avatarImage == null
                ? Text(
                    tutorName.isNotEmpty ? tutorName[0].toUpperCase() : 'T',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tutorName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.tutor['rating'] ?? 4.8}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.tutor['is_verified'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified,
                              size: 12,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingRow(
    String label,
    String value, {
    bool isSubtotal = false,
    bool isTotal = false,
    String? subtitle,
    bool strikethrough = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: isTotal ? 16 : 14,
                      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
                      color: isTotal ? Colors.black : Colors.grey[700],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isTotal ? 20 : 14,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                color: isTotal ? AppTheme.primaryColor : Colors.grey[700],
                decoration: strikethrough ? TextDecoration.lineThrough : null,
                decorationColor: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentPlanOption({
    required String plan,
    required String title,
    required String subtitle,
    required double amount,
    String? discount,
    String? badge,
  }) {
    final isSelected = _selectedPaymentPlan == plan;

    return GestureDetector(
      onTap: () => _selectPaymentPlan(plan),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio button
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Amount
            Flexible(
              child: Text(
                PricingService.formatPrice(amount),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
