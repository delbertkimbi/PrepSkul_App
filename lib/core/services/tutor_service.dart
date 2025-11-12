import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Tutor Service - Handles fetching tutor data
///
/// DESIGN: Easy to swap between demo data and real Supabase data
/// - Currently: Loads from JSON file (demo mode)
/// - Future: Just change USE_DEMO_DATA to false
///
/// When ready for production:
/// 1. Set USE_DEMO_DATA = false
/// 2. Delete assets/data/sample_tutors.json
/// 3. Everything works with Supabase!
class TutorService {
  // ⚠️ TOGGLE THIS TO SWITCH BETWEEN DEMO AND REAL DATA
  static const bool USE_DEMO_DATA = false; // Using real tutors from Supabase

  /// Fetch all tutors
  /// Returns list of tutor profiles with all details
  static Future<List<Map<String, dynamic>>> fetchTutors({
    String? subject,
    int? minRate,
    int? maxRate,
    double? minRating,
    bool? isVerified,
  }) async {
    if (USE_DEMO_DATA) {
      return _fetchDemoTutors(
        subject: subject,
        minRate: minRate,
        maxRate: maxRate,
        minRating: minRating,
        isVerified: isVerified,
      );
    } else {
      return _fetchSupabaseTutors(
        subject: subject,
        minRate: minRate,
        maxRate: maxRate,
        minRating: minRating,
        isVerified: isVerified,
      );
    }
  }

  /// Fetch single tutor by ID
  static Future<Map<String, dynamic>?> fetchTutorById(String tutorId) async {
    if (USE_DEMO_DATA) {
      return _fetchDemoTutorById(tutorId);
    } else {
      return _fetchSupabaseTutorById(tutorId);
    }
  }

  /// Search tutors by name or subject
  static Future<List<Map<String, dynamic>>> searchTutors(String query) async {
    if (USE_DEMO_DATA) {
      return _searchDemoTutors(query);
    } else {
      return _searchSupabaseTutors(query);
    }
  }

  // ========================================
  // DEMO DATA METHODS (JSON file)
  // ========================================

  static Future<List<Map<String, dynamic>>> _fetchDemoTutors({
    String? subject,
    int? minRate,
    int? maxRate,
    double? minRating,
    bool? isVerified,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Load from JSON file
    final String response = await rootBundle.loadString(
      'assets/data/sample_tutors.json',
    );
    final List<dynamic> data = json.decode(response);
    List<Map<String, dynamic>> tutors = List<Map<String, dynamic>>.from(data);

    // Apply filters
    if (subject != null && subject.isNotEmpty) {
      tutors = tutors.where((tutor) {
        final subjects = tutor['subjects'] as List?;
        return subjects?.any(
              (s) => s.toString().toLowerCase().contains(subject.toLowerCase()),
            ) ??
            false;
      }).toList();
    }

    if (minRate != null || maxRate != null) {
      tutors = tutors.where((tutor) {
        final rate = (tutor['hourly_rate'] ?? 0) as num;
        if (minRate != null && rate < minRate) return false;
        if (maxRate != null && rate > maxRate) return false;
        return true;
      }).toList();
    }

    if (minRating != null) {
      tutors = tutors.where((tutor) {
        final rating = (tutor['rating'] ?? 0.0) as num;
        return rating >= minRating;
      }).toList();
    }

    if (isVerified != null) {
      tutors = tutors.where((tutor) {
        return (tutor['is_verified'] ?? false) == isVerified;
      }).toList();
    }

    return tutors;
  }

  static Future<Map<String, dynamic>?> _fetchDemoTutorById(
    String tutorId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final String response = await rootBundle.loadString(
      'assets/data/sample_tutors.json',
    );
    final List<dynamic> data = json.decode(response);
    final tutors = List<Map<String, dynamic>>.from(data);

    try {
      return tutors.firstWhere((tutor) => tutor['id'] == tutorId);
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _searchDemoTutors(
    String query,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final String response = await rootBundle.loadString(
      'assets/data/sample_tutors.json',
    );
    final List<dynamic> data = json.decode(response);
    final tutors = List<Map<String, dynamic>>.from(data);

    if (query.isEmpty) return tutors;

    return tutors.where((tutor) {
      final name = tutor['full_name']?.toString().toLowerCase() ?? '';
      final subjects = tutor['subjects'] as List?;
      final queryLower = query.toLowerCase();

      // Search in name or subjects
      if (name.contains(queryLower)) return true;
      if (subjects?.any(
            (s) => s.toString().toLowerCase().contains(queryLower),
          ) ??
          false) {
        return true;
      }

      return false;
    }).toList();
  }

  // ========================================
  // SUPABASE METHODS (Real backend)
  // ========================================

  static Future<List<Map<String, dynamic>>> _fetchSupabaseTutors({
    String? subject,
    int? minRate,
    int? maxRate,
    double? minRating,
    bool? isVerified,
  }) async {
    try {
      // Build query - use LEFT join to include tutors even if profile data is incomplete
      // The relationship is: tutor_profiles.user_id -> profiles.id
      // Must specify the exact foreign key name to avoid ambiguity
      // Include all rating and pricing fields
      var query = SupabaseService.client
          .from('tutor_profiles')
          .select('''
            *,
            profiles!tutor_profiles_user_id_fkey(
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('status', 'approved'); // Only show approved tutors

      print(
        '🔍 Query: Fetching approved tutors with profile data via user_id relationship',
      );

      // Apply filters
      if (subject != null && subject.isNotEmpty) {
        query = query.contains('subjects', [subject]);
      }

      if (minRate != null) {
        query = query.gte('hourly_rate', minRate);
      }

      if (maxRate != null) {
        query = query.lte('hourly_rate', maxRate);
      }

      if (minRating != null) {
        query = query.gte('rating', minRating);
      }

      if (isVerified != null) {
        query = query.eq('is_verified', isVerified);
      }

      final response = await query.order('rating', ascending: false);

      final rawTutors = response as List;
      print(
        '📊 Raw query returned ${rawTutors.length} approved tutors from Supabase',
      );

      if (rawTutors.isEmpty) {
        print('⚠️ No tutors found with status="approved"');
        // Let's check what statuses exist
        try {
          final statusCheck = await SupabaseService.client
              .from('tutor_profiles')
              .select('status, user_id')
              .limit(10);
          print('📋 Sample tutor statuses: $statusCheck');
        } catch (e) {
          print('⚠️ Could not check tutor statuses: $e');
        }
      } else {
        // Debug: Print details of each tutor found
        for (var tutor in rawTutors) {
          final userId = tutor['user_id']?.toString() ?? 'unknown';
          final profile = tutor['profiles'];
          final subjects = tutor['subjects'];
          final status = tutor['status'];
          print('🔍 Tutor Debug - userId: $userId, status: $status');
          print('   - Profile: ${profile != null ? "exists" : "NULL"}');
          print('   - Full name: ${profile?['full_name'] ?? "MISSING"}');
          print(
            '   - Subjects: ${subjects ?? "NULL"} (type: ${subjects.runtimeType})',
          );
          print('   - Subjects is List: ${subjects is List}');
          if (subjects is List) {
            print('   - Subjects length: ${subjects.length}');
          }
        }
      }

      // Transform data to match demo format
      // Filter out tutors with missing critical data
      final filteredTutors = rawTutors.where((tutor) {
        final userId = tutor['user_id']?.toString() ?? 'unknown';

        // Ensure tutor has a profile and required fields
        final profile = tutor['profiles'];
        if (profile == null) {
          print('❌ FILTERED OUT: Tutor $userId has no profile data');
          return false;
        }

        // Check for required fields
        final fullName = profile['full_name']?.toString() ?? '';
        if (fullName.trim().isEmpty) {
          print(
            '❌ FILTERED OUT: Tutor $userId has no full_name (profile exists but name is empty)',
          );
          return false;
        }

        // Check if tutor has subjects or specializations (required for discovery)
        // Note: Database has both 'subjects' and 'specializations' columns
        // Use specializations if subjects is null/empty
        var subjects = tutor['subjects'];
        final specializations = tutor['specializations'];

        // If subjects is null/empty but specializations exists, use specializations
        if ((subjects == null ||
                (subjects is List && subjects.isEmpty) ||
                (subjects is String && subjects.trim().isEmpty)) &&
            specializations != null &&
            specializations is List &&
            specializations.isNotEmpty) {
          print(
            'ℹ️ Tutor $userId has specializations but no subjects - using specializations: $specializations',
          );
          subjects = specializations;
        }

        // Log if tutor has no subjects/specializations
        if (subjects == null) {
          print(
            '⚠️ Tutor $userId has null subjects and specializations - will show but may not match subject filters',
          );
        } else if (subjects is List && subjects.isEmpty) {
          print(
            '⚠️ Tutor $userId has empty subjects/specializations array - will show but may not match subject filters',
          );
        } else if (subjects is String && subjects.trim().isEmpty) {
          print(
            '⚠️ Tutor $userId has empty subjects/specializations string - will show but may not match subject filters',
          );
        }

        print(
          '✅ Tutor $userId PASSED all checks: name="$fullName", subjects=$subjects',
        );
        return true;
      }).toList();

      print(
        '✅ After filtering: ${filteredTutors.length} tutors available for display',
      );

      final tutors = filteredTutors.map((tutor) {
        final profile = tutor['profiles'] as Map<String, dynamic>?;

        // Use specializations if subjects is null/empty
        var subjects = tutor['subjects'];
        final specializations = tutor['specializations'];
        if ((subjects == null ||
                (subjects is List && subjects.isEmpty) ||
                (subjects is String && subjects.trim().isEmpty)) &&
            specializations != null &&
            specializations is List &&
            specializations.isNotEmpty) {
          subjects = specializations;
        }

        // Calculate effective rating: Use admin_approved_rating if total_reviews < 3
        final totalReviews = (tutor['total_reviews'] ?? 0) as int;
        final adminApprovedRating = tutor['admin_approved_rating'] as double?;
        final calculatedRating = (tutor['rating'] ?? 0.0) as double;

        // Use admin rating until we have at least 3 real reviews
        final effectiveRating =
            (totalReviews < 3 && adminApprovedRating != null)
            ? adminApprovedRating
            : (calculatedRating > 0
                  ? calculatedRating
                  : (adminApprovedRating ?? 0.0));

        // Use effective total_reviews (show 10 if using admin rating and reviews < 3)
        final effectiveTotalReviews =
            (totalReviews < 3 && adminApprovedRating != null)
            ? 10 // Temporary count until real reviews come in
            : totalReviews;

        // Get pricing: Prioritize base_session_price > admin_price_override > hourly_rate
        final baseSessionPrice = tutor['base_session_price'] as num?;
        final adminPriceOverride = tutor['admin_price_override'] as num?;
        final hourlyRate = tutor['hourly_rate'] as num?;
        final perSessionRate = tutor['per_session_rate'] as num?;

        // Determine the effective rate
        final effectiveRate = (baseSessionPrice != null && baseSessionPrice > 0)
            ? baseSessionPrice.toDouble()
            : (adminPriceOverride != null && adminPriceOverride > 0)
            ? adminPriceOverride.toDouble()
            : (perSessionRate != null && perSessionRate > 0)
            ? perSessionRate.toDouble()
            : (hourlyRate != null && hourlyRate > 0)
            ? hourlyRate.toDouble()
            : 0.0;

        // Get bio: Use personal_statement if bio is empty, or vice versa
        final bio = tutor['bio'] as String?;
        final personalStatement = tutor['personal_statement'] as String?;
        final effectiveBio = (bio != null && bio.trim().isNotEmpty)
            ? bio
            : (personalStatement != null && personalStatement.trim().isNotEmpty)
            ? personalStatement
            : '';

        // Format education data: Show "program • university" (field_of_study • institution)
        final educationJson = tutor['education'] as Map<String, dynamic>?;
        final institution = tutor['institution'] as String?;
        final fieldOfStudy = tutor['field_of_study'] as String?;

        String formattedEducation = '';
        // Priority: field_of_study (program) • institution (university)
        final program =
            educationJson?['field_of_study']?.toString() ?? fieldOfStudy;
        final university =
            educationJson?['institution']?.toString() ?? institution;

        final parts = <String>[];
        if (program != null && program.trim().isNotEmpty) {
          parts.add(program);
        }
        if (university != null && university.trim().isNotEmpty) {
          parts.add(university);
        }
        formattedEducation = parts.join(' • ');

        // Format teaching experience: Extract lower end value (e.g., "3-5 years" -> "3 Years")
        final teachingDuration = tutor['teaching_duration'] as String?;
        String formattedExperience = '';
        if (teachingDuration != null && teachingDuration.isNotEmpty) {
          // Extract first number from ranges like "3-5 years", "1-2 years", etc.
          final match = RegExp(r'^(\d+)').firstMatch(teachingDuration);
          if (match != null) {
            final years = match.group(1);
            formattedExperience = '$years Years';
          } else {
            formattedExperience = teachingDuration;
          }
        }

        // Get availability: Prioritize tutoring_availability
        final tutoringAvailability =
            tutor['tutoring_availability'] as Map<String, dynamic>?;
        final testSessionAvailability =
            tutor['test_session_availability'] as Map<String, dynamic>?;
        final availability = tutor['availability'] as Map<String, dynamic>?;
        final availabilitySchedule =
            tutor['availability_schedule'] as Map<String, dynamic>?;

        final effectiveAvailability =
            tutoringAvailability ??
            testSessionAvailability ??
            availability ??
            availabilitySchedule;

        // Get video: Use video_url (primary), fallback to video_link or video_intro
        final videoUrl = tutor['video_url'] as String?;
        final videoLink = tutor['video_link'] as String?;
        final videoIntro = tutor['video_intro'] as String?;
        final effectiveVideoUrl = videoUrl ?? videoLink ?? videoIntro;

        // Get student success metrics - use REAL session count from individual_sessions
        final totalStudents = (tutor['total_students'] ?? 0) as int;
        final totalHoursTaught = (tutor['total_hours_taught'] ?? 0) as int;

        // Note: completedSessions will be fetched separately after mapping
        // For now, use 0 as placeholder - will be updated in a follow-up query
        final completedSessions = 0;

        return {
          'id': tutor['user_id'],
          'full_name': profile?['full_name'] ?? 'Unknown',
          'avatar_url': profile?['avatar_url'],
          'email': profile?['email'],
          'bio': effectiveBio,
          'education':
              formattedEducation, // Formatted as "program • university"
          'education_data':
              educationJson ??
              {
                // Raw education data for detailed display
                if (institution != null) 'institution': institution,
                if (fieldOfStudy != null) 'field_of_study': fieldOfStudy,
              },
          'experience': formattedExperience.isNotEmpty
              ? formattedExperience
              : tutor['experience'],
          'teaching_duration': teachingDuration,
          'subjects': subjects ?? [],
          'hourly_rate': effectiveRate, // Use effective rate
          'base_session_price': baseSessionPrice?.toDouble(),
          'admin_price_override': adminPriceOverride?.toDouble(),
          'availability': effectiveAvailability, // Use effective availability
          'tutoring_availability': tutoringAvailability,
          'test_session_availability': testSessionAvailability,
          // Combine both availabilities for display
          'combined_availability': {
            if (tutoringAvailability != null && tutoringAvailability.isNotEmpty)
              ...tutoringAvailability,
            if (testSessionAvailability != null &&
                testSessionAvailability.isNotEmpty)
              ...testSessionAvailability,
          },
          'is_verified': tutor['is_verified'] ?? false,
          'rating': effectiveRating, // Use effective rating
          'total_reviews': effectiveTotalReviews, // Use effective review count
          'admin_approved_rating': adminApprovedRating,
          'total_students': totalStudents,
          'total_hours_taught': totalHoursTaught,
          'completed_sessions': completedSessions,
          'city': tutor['city'],
          'quarter': tutor['quarter'],
          'video_intro': effectiveVideoUrl, // Use effective video URL
          'video_url': effectiveVideoUrl,
          'teaching_style': personalStatement ?? bio ?? '',
        };
      }).toList();

      // Now fetch real completed sessions count for each tutor
      for (var tutorData in tutors) {
        try {
          final sessionsResponse = await SupabaseService.client
              .from('individual_sessions')
              .select('id')
              .eq('tutor_id', tutorData['id'])
              .eq('status', 'completed');
          tutorData['completed_sessions'] = (sessionsResponse as List).length;
        } catch (e) {
          print(
            '⚠️ Error fetching completed sessions for tutor ${tutorData['id']}: $e',
          );
          tutorData['completed_sessions'] = 0;
        }
      }

      return tutors;
    } catch (e) {
      print('❌ Error fetching tutors from Supabase: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> _fetchSupabaseTutorById(
    String tutorId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('tutor_profiles')
          .select('''
            *,
            profiles!inner(
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('user_id', tutorId)
          .eq('status', 'approved')
          .single();

      final profile = response['profiles'];

      // Calculate effective rating: Use admin_approved_rating if total_reviews < 3
      final totalReviews = (response['total_reviews'] ?? 0) as int;
      final adminApprovedRating = response['admin_approved_rating'] as double?;
      final calculatedRating = (response['rating'] ?? 0.0) as double;

      // Use admin rating until we have at least 3 real reviews
      final effectiveRating = (totalReviews < 3 && adminApprovedRating != null)
          ? adminApprovedRating
          : (calculatedRating > 0
                ? calculatedRating
                : (adminApprovedRating ?? 0.0));

      // Use effective total_reviews (show 10 if using admin rating and reviews < 3)
      final effectiveTotalReviews =
          (totalReviews < 3 && adminApprovedRating != null)
          ? 10 // Temporary count until real reviews come in
          : totalReviews;

      // Get pricing: Prioritize base_session_price > admin_price_override > hourly_rate
      final baseSessionPrice = response['base_session_price'] as num?;
      final adminPriceOverride = response['admin_price_override'] as num?;
      final hourlyRate = response['hourly_rate'] as num?;
      final perSessionRate = response['per_session_rate'] as num?;

      // Determine the effective rate
      final effectiveRate = (baseSessionPrice != null && baseSessionPrice > 0)
          ? baseSessionPrice.toDouble()
          : (adminPriceOverride != null && adminPriceOverride > 0)
          ? adminPriceOverride.toDouble()
          : (perSessionRate != null && perSessionRate > 0)
          ? perSessionRate.toDouble()
          : (hourlyRate != null && hourlyRate > 0)
          ? hourlyRate.toDouble()
          : 0.0;

      // Get bio: Use personal_statement if bio is empty, or vice versa
      final bio = response['bio'] as String?;
      final personalStatement = response['personal_statement'] as String?;
      final effectiveBio = (bio != null && bio.trim().isNotEmpty)
          ? bio
          : (personalStatement != null && personalStatement.trim().isNotEmpty)
          ? personalStatement
          : '';

      // Format education data: Show "program • university" (field_of_study • institution)
      final educationJson = response['education'] as Map<String, dynamic>?;
      final institution = response['institution'] as String?;
      final fieldOfStudy = response['field_of_study'] as String?;

      String formattedEducation = '';
      // Priority: field_of_study (program) • institution (university)
      final program =
          educationJson?['field_of_study']?.toString() ?? fieldOfStudy;
      final university =
          educationJson?['institution']?.toString() ?? institution;

      final parts = <String>[];
      if (program != null && program.trim().isNotEmpty) {
        parts.add(program);
      }
      if (university != null && university.trim().isNotEmpty) {
        parts.add(university);
      }
      formattedEducation = parts.join(' • ');

      // Format teaching experience: Extract lower end value (e.g., "3-5 years" -> "3 Years")
      final teachingDuration = response['teaching_duration'] as String?;
      String formattedExperience = '';
      if (teachingDuration != null && teachingDuration.isNotEmpty) {
        // Extract first number from ranges like "3-5 years", "1-2 years", etc.
        final match = RegExp(r'^(\d+)').firstMatch(teachingDuration);
        if (match != null) {
          final years = match.group(1);
          formattedExperience = '$years Years';
        } else {
          formattedExperience = teachingDuration;
        }
      }

      // Get availability: Prioritize tutoring_availability
      final tutoringAvailability =
          response['tutoring_availability'] as Map<String, dynamic>?;
      final testSessionAvailability =
          response['test_session_availability'] as Map<String, dynamic>?;
      final availability = response['availability'] as Map<String, dynamic>?;
      final availabilitySchedule =
          response['availability_schedule'] as Map<String, dynamic>?;

      final effectiveAvailability =
          tutoringAvailability ??
          testSessionAvailability ??
          availability ??
          availabilitySchedule;

      // Get video: Use video_url (primary), fallback to video_link or video_intro
      final videoUrl = response['video_url'] as String?;
      final videoLink = response['video_link'] as String?;
      final videoIntro = response['video_intro'] as String?;
      final effectiveVideoUrl = videoUrl ?? videoLink ?? videoIntro;

      // Get student success metrics - use REAL session count from individual_sessions
      final totalStudents = (response['total_students'] ?? 0) as int;
      final totalHoursTaught = (response['total_hours_taught'] ?? 0) as int;

      // Fetch real completed sessions count from individual_sessions table
      int completedSessions = 0;
      try {
        final sessionsResponse = await SupabaseService.client
            .from('individual_sessions')
            .select('id')
            .eq('tutor_id', tutorId)
            .eq('status', 'completed');
        completedSessions = (sessionsResponse as List).length;
      } catch (e) {
        print('⚠️ Error fetching completed sessions: $e');
        // Fallback to 0 if query fails
      }

      // Get subjects/specializations
      var subjects = response['subjects'];
      final specializations = response['specializations'];
      if ((subjects == null ||
              (subjects is List && subjects.isEmpty) ||
              (subjects is String && subjects.trim().isEmpty)) &&
          specializations != null &&
          specializations is List &&
          specializations.isNotEmpty) {
        subjects = specializations;
      }

      return {
        'id': response['user_id'],
        'full_name': profile['full_name'],
        'avatar_url': profile['avatar_url'],
        'email': profile['email'],
        'bio': effectiveBio,
        'education': formattedEducation, // Formatted as "program • university"
        'education_data':
            educationJson ??
            {
              // Raw education data for detailed display
              if (institution != null) 'institution': institution,
              if (fieldOfStudy != null) 'field_of_study': fieldOfStudy,
            },
        'experience': formattedExperience.isNotEmpty
            ? formattedExperience
            : response['experience'],
        'teaching_duration': teachingDuration,
        'subjects': subjects ?? [],
        'hourly_rate': effectiveRate, // Use effective rate
        'base_session_price': baseSessionPrice?.toDouble(),
        'admin_price_override': adminPriceOverride?.toDouble(),
        'availability': effectiveAvailability, // Use effective availability
        'tutoring_availability': tutoringAvailability,
        'test_session_availability': testSessionAvailability,
        // Combine both availabilities for display
        'combined_availability': {
          if (tutoringAvailability != null && tutoringAvailability.isNotEmpty)
            ...tutoringAvailability,
          if (testSessionAvailability != null &&
              testSessionAvailability.isNotEmpty)
            ...testSessionAvailability,
        },
        'is_verified': response['is_verified'] ?? false,
        'rating': effectiveRating, // Use effective rating
        'total_reviews': effectiveTotalReviews, // Use effective review count
        'admin_approved_rating': adminApprovedRating,
        'total_students': totalStudents,
        'total_hours_taught': totalHoursTaught,
        'completed_sessions': completedSessions,
        'city': response['city'],
        'quarter': response['quarter'],
        'video_intro': effectiveVideoUrl, // Use effective video URL
        'video_url': effectiveVideoUrl,
        'teaching_style': personalStatement ?? bio ?? '',
      };
    } catch (e) {
      print('❌ Error fetching tutor by ID from Supabase: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _searchSupabaseTutors(
    String query,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('tutor_profiles')
          .select('''
            *,
            profiles!inner(
              full_name,
              avatar_url,
              email
            )
          ''')
          .eq('status', 'approved')
          .or('profiles.full_name.ilike.%$query%,subjects.cs.{$query}');

      return (response as List).map((tutor) {
        final profile = tutor['profiles'];
        return {
          'id': tutor['user_id'],
          'full_name': profile['full_name'],
          'avatar_url': profile['avatar_url'],
          'subjects': tutor['subjects'],
          'hourly_rate': tutor['hourly_rate'],
          'is_verified': tutor['is_verified'] ?? false,
          'rating': tutor['rating'] ?? 0.0,
          'city': tutor['city'],
        };
      }).toList();
    } catch (e) {
      print('❌ Error searching tutors in Supabase: $e');
      return [];
    }
  }
}
