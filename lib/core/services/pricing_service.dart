import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Pricing Service - Calculates tutor pricing based on multiple factors
///
/// MARKET CONTEXT: In Cameroon & Africa, people think in monthly payments
/// This service converts per-session rates to monthly estimates

class PricingService {
  static SupabaseClient get _supabase => SupabaseService.client;
  /// Calculate monthly estimate from tutor data
  ///
  /// Formula:
  /// monthlyEstimate = sessionRate × sessionsPerWeek × 4 (weeks)
  ///
  /// Where sessionRate considers:
  /// - Base tutor rate
  /// - Rating multiplier (up to 20% premium for 5-star)
  /// - Credential multiplier (Bachelor=1.0, Master=1.15, PhD=1.3, PhD+Cert=1.4)
  /// - Location multiplier (online=1.0, onsite=1.2, hybrid=1.1)
  static Map<String, dynamic> calculateMonthlyPricing({
    required double baseTutorRate, // Per-session rate from tutor
    required double rating, // 0-5 stars
    required String qualification, // Education level
    required int sessionsPerWeek, // Frequency (default 2-3)
    String location = 'online', // online, onsite, hybrid
    double? adminPriceOverride, // Admin can manually override
    bool hasVisibilitySubscription = false, // Paid tutors
    bool hasPrepSkulCertification = false, // PrepSkul Academy
  }) {
    // Admin override takes precedence
    if (adminPriceOverride != null && adminPriceOverride > 0) {
      return {
        'perSession': adminPriceOverride,
        'perWeek': adminPriceOverride * sessionsPerWeek,
        'perMonth': adminPriceOverride * sessionsPerWeek * 4,
        'sessionsPerWeek': sessionsPerWeek,
        'sessionsPerMonth': sessionsPerWeek * 4,
        'adminOverride': true,
      };
    }

    // Calculate multipliers
    final ratingMultiplier = _getRatingMultiplier(rating);
    final credentialMultiplier = _getCredentialMultiplier(
      qualification,
      hasPrepSkulCertification,
    );
    final locationMultiplier = _getLocationMultiplier(location);

    // Calculate session rate with all multipliers
    double sessionRate =
        baseTutorRate *
        ratingMultiplier *
        credentialMultiplier *
        locationMultiplier;

    // Round to nearest 100 XAF for cleaner pricing
    sessionRate = (sessionRate / 100).round() * 100;

    // Calculate weekly and monthly totals
    final perWeek = sessionRate * sessionsPerWeek;
    final perMonth = perWeek * 4;

    return {
      'perSession': sessionRate,
      'perWeek': perWeek,
      'perMonth': perMonth,
      'sessionsPerWeek': sessionsPerWeek,
      'sessionsPerMonth': sessionsPerWeek * 4,
      'adminOverride': false,
      'breakdown': {
        'baseRate': baseTutorRate,
        'ratingMultiplier': ratingMultiplier,
        'credentialMultiplier': credentialMultiplier,
        'locationMultiplier': locationMultiplier,
      },
    };
  }

  /// Get rating multiplier (up to 20% premium for 5-star tutors)
  static double _getRatingMultiplier(double rating) {
    if (rating <= 0) return 1.0;
    if (rating > 5) rating = 5.0;

    // Linear scale: 4.0 stars = 1.0x, 5.0 stars = 1.2x
    // Formula: 0.8 + (rating / 5) * 0.4
    return 0.8 + (rating / 5) * 0.4;
  }

  /// Get credential multiplier based on education level
  static double _getCredentialMultiplier(
    String qualification,
    bool hasPrepSkulCertification,
  ) {
    double baseMultiplier = 1.0;

    // Education-based multiplier
    final qualLower = qualification.toLowerCase();
    if (qualLower.contains('phd') || qualLower.contains('doctorate')) {
      baseMultiplier = 1.3;
    } else if (qualLower.contains('master') || qualLower.contains('msc')) {
      baseMultiplier = 1.15;
    } else if (qualLower.contains('bachelor') ||
        qualLower.contains('bsc') ||
        qualLower.contains('undergraduate')) {
      baseMultiplier = 1.0;
    } else if (qualLower.contains('professional')) {
      baseMultiplier = 1.25;
    }

    // Additional certification bonus
    if (hasPrepSkulCertification) {
      baseMultiplier += 0.1; // +10% for PrepSkul Academy training
    }

    return baseMultiplier;
  }

  /// Get location multiplier
  static double _getLocationMultiplier(String location) {
    switch (location.toLowerCase()) {
      case 'onsite':
        return 1.2; // 20% premium for onsite (travel time/cost)
      case 'hybrid':
        return 1.1; // 10% premium for hybrid
      case 'online':
      default:
        return 1.0; // Base rate for online
    }
  }

  /// Format price for display (adds XAF, thousands separator)
  static String formatPrice(double amount) {
    // Round to nearest integer
    final rounded = amount.round();

    // Add thousands separator
    final formatted = rounded.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return '$formatted XAF';
  }

  /// Format monthly estimate (clean, no approximation symbol)
  static String formatMonthlyEstimate(double amount) {
    return '${formatPrice(amount)} / month';
  }

  /// Calculate discount for upfront payment
  static Map<String, dynamic> calculateDiscount({
    required double monthlyTotal,
    required String paymentPlan, // 'monthly', 'biweekly', 'weekly'
  }) {
    double discountPercent = 0.0;
    String description = '';

    switch (paymentPlan.toLowerCase()) {
      case 'monthly':
        discountPercent = 10.0; // 10% discount for full month upfront
        description = 'Full month upfront';
        break;
      case 'biweekly':
        discountPercent = 5.0; // 5% discount for bi-weekly
        description = 'Bi-weekly payments';
        break;
      case 'weekly':
        discountPercent = 0.0; // No discount for weekly
        description = 'Weekly payments';
        break;
    }

    final discountAmount = (monthlyTotal * discountPercent) / 100;
    final finalAmount = monthlyTotal - discountAmount;

    return {
      'originalAmount': monthlyTotal,
      'discountPercent': discountPercent,
      'discountAmount': discountAmount,
      'finalAmount': finalAmount,
      'description': description,
      'savings': discountAmount > 0 ? formatPrice(discountAmount) : null,
    };
  }

  /// Get default sessions per week based on student/parent survey data
  static int getDefaultSessionsPerWeek({
    String? learningPath,
    String? examType,
    String? confidenceLevel,
  }) {
    // Exam preparation typically needs more sessions
    if (examType != null && examType.isNotEmpty) {
      return 3; // 3x per week for exam prep
    }

    // Lower confidence students need more support
    if (confidenceLevel != null) {
      final confLower = confidenceLevel.toLowerCase();
      if (confLower.contains('struggling') || confLower.contains('beginner')) {
        return 3; // 3x per week for struggling students
      }
    }

    // Default: 2 sessions per week
    return 2;
  }

  /// Get trial session pricing from database with full details (price, discount)
  static Future<Map<int, Map<String, dynamic>>> getTrialSessionPricingWithDetails() async {
    try {
      // Fetch pricing with potential discount columns
      // Note: 'discount_percent' and 'discount_amount' are potential columns based on user feedback
      // If they don't exist, Supabase might ignore or throw. We handle both cases.
      List<dynamic> response;
      try {
        response = await _supabase
            .from('trial_session_pricing')
            .select('duration_minutes, price_xaf, discount_percent, discount_amount')
            .eq('is_active', true);
      } catch (e) {
        LogService.warning('Could not fetch discount columns, falling back to basic pricing: $e');
        response = await _supabase
            .from('trial_session_pricing')
            .select('duration_minutes, price_xaf')
            .eq('is_active', true);
      }

      final pricing = <int, Map<String, dynamic>>{};
      for (final row in response) {
        final duration = row['duration_minutes'] as int;
        final basePrice = (row['price_xaf'] as num).toDouble();
        final discountPercent = (row['discount_percent'] as num?)?.toDouble() ?? 0.0;
        final discountAmount = (row['discount_amount'] as num?)?.toDouble() ?? 0.0;
        
        // Calculate final price
        double finalPrice = basePrice;
        if (discountPercent > 0) {
          finalPrice = basePrice * (1 - discountPercent / 100);
        } else if (discountAmount > 0) {
          finalPrice = basePrice - discountAmount;
        }

        // Ensure price doesn't go below zero
        if (finalPrice < 0) finalPrice = 0;

        // Round to nearest 100
        finalPrice = (finalPrice / 100).round() * 100.0;

        pricing[duration] = {
          'basePrice': basePrice,
          'finalPrice': finalPrice,
          'discountPercent': discountPercent,
          'discountAmount': discountAmount,
          'hasDiscount': discountPercent > 0 || discountAmount > 0,
        };
      }

      // Default fallback if database is empty
      if (pricing.isEmpty) {
        pricing[30] = {
          'basePrice': 2000.0,
          'finalPrice': 2000.0,
          'hasDiscount': false,
        };
        pricing[60] = {
          'basePrice': 3500.0,
          'finalPrice': 3500.0,
          'hasDiscount': false,
        };
      }

      return pricing;
    } catch (e) {
      LogService.warning('Error fetching trial session pricing details: $e');
      // Return defaults on error
      return {
        30: {'basePrice': 2000.0, 'finalPrice': 2000.0, 'hasDiscount': false},
        60: {'basePrice': 3500.0, 'finalPrice': 3500.0, 'hasDiscount': false},
      };
    }
  }

  /// Get trial session pricing from database (simple map for backward compatibility)
  static Future<Map<int, int>> getTrialSessionPricing() async {
    final details = await getTrialSessionPricingWithDetails();
    final simplePricing = <int, int>{};
    details.forEach((duration, data) {
      simplePricing[duration] = (data['finalPrice'] as double).round();
    });
    return simplePricing;
  }

  /// Get trial session price for a specific duration
  static Future<int> getTrialSessionPrice(int durationMinutes) async {
    final details = await getTrialSessionPricingWithDetails();
    final data = details[durationMinutes];
    if (data != null) {
      return (data['finalPrice'] as double).round();
    }
    return durationMinutes == 30 ? 2000 : 3500;
  }

  /// Calculate pricing for tutor from JSON data (for demo mode)
  static Map<String, dynamic> calculateFromTutorData(
    Map<String, dynamic> tutorData, {
    int? overrideSessionsPerWeek,
  }) {
    // Extract pricing data with priority: discounted_price > base_session_price > admin_price_override > hourly_rate
    final discountedPrice = tutorData['discounted_price']?.toDouble();
    final baseSessionPrice = tutorData['base_session_price']?.toDouble();
    final adminPriceOverride = tutorData['admin_price_override']?.toDouble();
    final hourlyRate = (tutorData['hourly_rate'] ?? 3000).toDouble();
    final perSessionRate = tutorData['per_session_rate']?.toDouble();
    
    // Check if tutor has discount
    final discountPercent = (tutorData['discount_percent'] ?? 0.0).toDouble();
    final discountAmount = (tutorData['discount_amount_xaf'] ?? 0).toInt();
    final hasDiscount = discountPercent > 0 || discountAmount > 0;
    
    // Determine effective base rate (priority order)
    double effectiveBaseRate;
    if (discountedPrice != null && discountedPrice > 0 && hasDiscount) {
      // Use discounted price if available
      effectiveBaseRate = discountedPrice;
    } else if (baseSessionPrice != null && baseSessionPrice > 0) {
      effectiveBaseRate = baseSessionPrice;
    } else if (adminPriceOverride != null && adminPriceOverride > 0) {
      effectiveBaseRate = adminPriceOverride;
    } else if (perSessionRate != null && perSessionRate > 0) {
      effectiveBaseRate = perSessionRate;
    } else {
      effectiveBaseRate = hourlyRate;
    }
    
    final rating = (tutorData['rating'] ?? 4.0).toDouble();
    final qualification = tutorData['tutor_qualification'] ?? 'Professional';
    
    // If admin has set base_session_price or admin_price_override, use it directly
    final adminOverride = (baseSessionPrice != null && baseSessionPrice > 0)
        ? baseSessionPrice
        : adminPriceOverride;

    // Default sessions per week
    final sessionsPerWeek = overrideSessionsPerWeek ?? 2;

    // Calculate pricing
    final pricing = calculateMonthlyPricing(
      baseTutorRate: effectiveBaseRate,
      rating: rating,
      qualification: qualification,
      sessionsPerWeek: sessionsPerWeek,
      location: 'online', // Default to online
      adminPriceOverride: adminOverride,
      hasVisibilitySubscription: tutorData['visibility_subscription'] ?? false,
      hasPrepSkulCertification: tutorData['prepskul_certified'] ?? false,
    );

    // Add discount information if available
    if (hasDiscount) {
      // Calculate original price (before discount)
      double originalPerSession;
      if (discountPercent > 0) {
        originalPerSession = effectiveBaseRate / (1 - discountPercent / 100);
      } else if (discountAmount > 0) {
        originalPerSession = effectiveBaseRate + discountAmount;
      } else {
        originalPerSession = baseSessionPrice ?? effectiveBaseRate;
      }

      final originalPerMonth = originalPerSession * sessionsPerWeek * 4;

      pricing['hasDiscount'] = true;
      pricing['originalPerSession'] = originalPerSession;
      pricing['originalPerMonth'] = originalPerMonth;
      pricing['discountPercent'] = discountPercent;
      pricing['discountAmount'] = discountAmount;
    } else {
      pricing['hasDiscount'] = false;
    }

    return pricing;
  }

  /// Get pricing summary for display (human-readable)
  static String getPricingSummary(Map<String, dynamic> pricing) {
    final monthlyAmount = pricing['perMonth'] as double;
    final sessionsPerWeek = pricing['sessionsPerWeek'] as int;

    return '${formatMonthlyEstimate(monthlyAmount)}\nbased on $sessionsPerWeek session${sessionsPerWeek > 1 ? 's' : ''}/week';
  }

  /// Get pricing range for a list of tutors
  static Map<String, double> getPriceRange(List<Map<String, dynamic>> tutors) {
    if (tutors.isEmpty) {
      return {'min': 0.0, 'max': 0.0};
    }

    double minPrice = double.infinity;
    double maxPrice = 0.0;

    for (final tutor in tutors) {
      final pricing = calculateFromTutorData(tutor);
      final monthly = pricing['perMonth'] as double;

      if (monthly < minPrice) minPrice = monthly;
      if (monthly > maxPrice) maxPrice = monthly;
    }

    return {'min': minPrice, 'max': maxPrice};
  }
}
