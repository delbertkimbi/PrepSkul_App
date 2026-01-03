import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Service for validating and sanitizing tutor data quality
class TutorDataValidationService {
  /// Validation result model
  static Map<String, dynamic> validateTutorData(Map<String, dynamic> tutorData) {
    final issues = <String>[];
    final warnings = <String>[];
    final isValid = true;

    final tutorId = tutorData['id'] as String?;
    final tutorName = tutorData['full_name'] as String? ?? 'Unknown';
    final status = tutorData['status'] as String?;

    // Check admin_approved_rating
    final adminApprovedRating = tutorData['admin_approved_rating'];
    if (status == 'approved') {
      if (adminApprovedRating == null) {
        issues.add('Missing admin_approved_rating for approved tutor');
      } else {
        final rating = adminApprovedRating is num 
            ? adminApprovedRating.toDouble() 
            : double.tryParse(adminApprovedRating.toString());
        if (rating == null || rating < 3.0 || rating > 4.5) {
          issues.add('admin_approved_rating ($rating) is outside valid range (3.0-4.5)');
        }
      }
    }

    // Check base_session_price
    final baseSessionPrice = tutorData['base_session_price'];
    if (status == 'approved') {
      if (baseSessionPrice == null) {
        issues.add('Missing base_session_price for approved tutor');
      } else {
        final price = baseSessionPrice is num 
            ? baseSessionPrice.toDouble() 
            : double.tryParse(baseSessionPrice.toString());
        if (price == null || price < 3000 || price > 15000) {
          issues.add('base_session_price ($price) is outside valid range (3000-15000)');
        }
      }
    }

    // Check hourly_rate
    final hourlyRate = tutorData['hourly_rate'];
    if (hourlyRate != null) {
      final rate = hourlyRate is num 
          ? hourlyRate.toDouble() 
          : double.tryParse(hourlyRate.toString());
      if (rate == null || rate < 1000 || rate > 50000) {
        issues.add('hourly_rate ($rate) is corrupted or outside valid range (1000-50000)');
      } else if (status == 'approved' && baseSessionPrice != null) {
        final price = baseSessionPrice is num 
            ? baseSessionPrice.toDouble() 
            : double.tryParse(baseSessionPrice.toString());
        if (price != null && (rate < price * 0.8 || rate > price * 1.2)) {
          warnings.add('hourly_rate ($rate) differs significantly from base_session_price ($price)');
        }
      }
    }

    return {
      'isValid': issues.isEmpty,
      'issues': issues,
      'warnings': warnings,
      'tutorId': tutorId,
      'tutorName': tutorName,
      'status': status,
    };
  }

  /// Sanitize corrupted tutor data
  static Map<String, dynamic> sanitizeTutorData(Map<String, dynamic> tutorData) {
    final sanitized = Map<String, dynamic>.from(tutorData);
    final status = tutorData['status'] as String?;

    // Sanitize hourly_rate
    final hourlyRate = tutorData['hourly_rate'];
    if (hourlyRate != null) {
      final rate = hourlyRate is num 
          ? hourlyRate.toDouble() 
          : double.tryParse(hourlyRate.toString());
      if (rate == null || rate < 1000 || rate > 50000) {
        // Try to use base_session_price as fallback
        final basePrice = tutorData['base_session_price'];
        if (basePrice != null) {
          final price = basePrice is num 
              ? basePrice.toDouble() 
              : double.tryParse(basePrice.toString());
          if (price != null && price >= 3000 && price <= 15000) {
            sanitized['hourly_rate'] = price;
            LogService.warning('Sanitized hourly_rate: $rate -> $price (using base_session_price)');
          } else {
            sanitized['hourly_rate'] = 3000.0;
            LogService.warning('Sanitized hourly_rate: $rate -> 3000 (default)');
          }
        } else {
          sanitized['hourly_rate'] = 3000.0;
          LogService.warning('Sanitized hourly_rate: $rate -> 3000 (default)');
        }
      }
    }

    // Set default admin_approved_rating for approved tutors
    if (status == 'approved' && tutorData['admin_approved_rating'] == null) {
      final initialRating = tutorData['initial_rating_suggested'];
      if (initialRating != null) {
        final rating = initialRating is num 
            ? initialRating.toDouble() 
            : double.tryParse(initialRating.toString());
        if (rating != null && rating >= 3.0 && rating <= 4.5) {
          sanitized['admin_approved_rating'] = rating;
          LogService.warning('Set admin_approved_rating: $rating (using initial_rating_suggested)');
        } else {
          sanitized['admin_approved_rating'] = 3.5;
          LogService.warning('Set admin_approved_rating: 3.5 (default)');
        }
      } else {
        sanitized['admin_approved_rating'] = 3.5;
        LogService.warning('Set admin_approved_rating: 3.5 (default)');
      }
    }

    // Set default base_session_price for approved tutors
    if (status == 'approved' && tutorData['base_session_price'] == null) {
      final adminOverride = tutorData['admin_price_override'];
      if (adminOverride != null) {
        final override = adminOverride is num 
            ? adminOverride.toDouble() 
            : double.tryParse(adminOverride.toString());
        if (override != null && override >= 3000 && override <= 15000) {
          sanitized['base_session_price'] = override;
          LogService.warning('Set base_session_price: $override (using admin_price_override)');
        } else {
          sanitized['base_session_price'] = 3000.0;
          LogService.warning('Set base_session_price: 3000 (default)');
        }
      } else {
        final hourlyRate = sanitized['hourly_rate'];
        if (hourlyRate != null) {
          final rate = hourlyRate is num 
              ? hourlyRate.toDouble() 
              : double.tryParse(hourlyRate.toString());
          if (rate != null && rate >= 3000 && rate <= 15000) {
            sanitized['base_session_price'] = rate;
            LogService.warning('Set base_session_price: $rate (using hourly_rate)');
          } else {
            sanitized['base_session_price'] = 3000.0;
            LogService.warning('Set base_session_price: 3000 (default)');
          }
        } else {
          sanitized['base_session_price'] = 3000.0;
          LogService.warning('Set base_session_price: 3000 (default)');
        }
      }
    }

    return sanitized;
  }

  /// Get data quality report for all tutors
  static Future<List<Map<String, dynamic>>> getDataQualityReport() async {
    try {
      final response = await SupabaseService.client
          .from('tutor_profiles')
          .select('id, full_name, status, admin_approved_rating, base_session_price, hourly_rate, initial_rating_suggested, admin_price_override')
          .order('created_at', ascending: false);

      final tutors = response as List<dynamic>;
      final report = <Map<String, dynamic>>[];

      for (final tutor in tutors) {
        final tutorMap = tutor as Map<String, dynamic>;
        final validation = validateTutorData(tutorMap);
        
        if (!validation['isValid'] as bool || (validation['warnings'] as List).isNotEmpty) {
          report.add(validation);
        }
      }

      LogService.info('Data quality report: ${report.length} tutors with issues');
      return report;
    } catch (e) {
      LogService.error('Error generating data quality report: $e');
      return [];
    }
  }

  /// Check if tutor can be approved (has all required data)
  static bool canApproveTutor(Map<String, dynamic> tutorData) {
    final validation = validateTutorData(tutorData);
    return validation['isValid'] as bool;
  }

  /// Get recommended values for missing/corrupted data
  static Map<String, dynamic> getRecommendedValues(Map<String, dynamic> tutorData) {
    final recommendations = <String, dynamic>{};

    // Recommend admin_approved_rating
    if (tutorData['admin_approved_rating'] == null) {
      final initialRating = tutorData['initial_rating_suggested'];
      if (initialRating != null) {
        final rating = initialRating is num 
            ? initialRating.toDouble() 
            : double.tryParse(initialRating.toString());
        if (rating != null && rating >= 3.0 && rating <= 4.5) {
          recommendations['admin_approved_rating'] = rating;
        } else {
          recommendations['admin_approved_rating'] = 3.5;
        }
      } else {
        recommendations['admin_approved_rating'] = 3.5;
      }
    }

    // Recommend base_session_price
    if (tutorData['base_session_price'] == null) {
      final adminOverride = tutorData['admin_price_override'];
      if (adminOverride != null) {
        final override = adminOverride is num 
            ? adminOverride.toDouble() 
            : double.tryParse(adminOverride.toString());
        if (override != null && override >= 3000 && override <= 15000) {
          recommendations['base_session_price'] = override;
        } else {
          recommendations['base_session_price'] = 3000.0;
        }
      } else {
        final hourlyRate = tutorData['hourly_rate'];
        if (hourlyRate != null) {
          final rate = hourlyRate is num 
              ? hourlyRate.toDouble() 
              : double.tryParse(hourlyRate.toString());
          if (rate != null && rate >= 3000 && rate <= 15000) {
            recommendations['base_session_price'] = rate;
          } else {
            recommendations['base_session_price'] = 3000.0;
          }
        } else {
          recommendations['base_session_price'] = 3000.0;
        }
      }
    }

    // Recommend hourly_rate fix
    final hourlyRate = tutorData['hourly_rate'];
    if (hourlyRate != null) {
      final rate = hourlyRate is num 
          ? hourlyRate.toDouble() 
          : double.tryParse(hourlyRate.toString());
      if (rate == null || rate < 1000 || rate > 50000) {
        final basePrice = tutorData['base_session_price'];
        if (basePrice != null) {
          final price = basePrice is num 
              ? basePrice.toDouble() 
              : double.tryParse(basePrice.toString());
          if (price != null && price >= 3000 && price <= 15000) {
            recommendations['hourly_rate'] = price;
          } else {
            recommendations['hourly_rate'] = 3000.0;
          }
        } else {
          recommendations['hourly_rate'] = 3000.0;
        }
      }
    }

    return recommendations;
  }
}

