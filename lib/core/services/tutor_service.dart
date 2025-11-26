import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:prepskul/core/services/supabase_service.dart';

// Helper function to safely cast dynamic values
T? _safeCast<T>(dynamic value) {
  if (value is T) {
    return value;
  }
  return null;
}

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
      // Build query - use INNER join to ensure we only get tutors with profiles
      // The relationship is: tutor_profiles.user_id -> profiles.id
      // Try multiple relationship syntaxes for compatibility
      print(
        '🔍 Query: Fetching approved tutors with profile data via user_id relationship',
      );
      
      var query = SupabaseService.client
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
          .neq('is_hidden', true); // Only show approved & not-hidden tutors

      // Also fetch profile_photo_url from tutor_profiles (if it exists)

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

      print('🔍 Executing query...');
      List rawTutors;
      try {
      final response = await query.order('rating', ascending: false);
        rawTutors = response as List;
        print(
          '✅ Query successful! Raw query returned ${rawTutors.length} approved tutors from Supabase',
        );
      } catch (queryError) {
        print('❌ Query failed with error: $queryError');
        print('❌ Query error type: ${queryError.runtimeType}');
        
        // Try fallback query without relationship join
        print('🔄 Attempting fallback query without relationship join...');
        try {
          final fallbackQuery = SupabaseService.client
              .from('tutor_profiles')
              .select('*')
              .eq('status', 'approved')
              .neq('is_hidden', true);
          
          final fallbackResponse = await fallbackQuery.order('rating', ascending: false);
          final fallbackTutors = fallbackResponse as List;
          print('✅ Fallback query returned ${fallbackTutors.length} tutors');
          
          if (fallbackTutors.isEmpty) {
            print('⚠️ Fallback query also returned no tutors');
            return [];
          }
          
          // Fetch profiles separately for each tutor
          print('🔄 Fetching profiles separately...');
          final tutorsWithProfiles = <Map<String, dynamic>>[];
          for (var tutor in fallbackTutors) {
            try {
              final userId = tutor['user_id']?.toString();
              if (userId == null) continue;
              
              final profileResponse = await SupabaseService.client
                  .from('profiles')
                  .select('full_name, avatar_url, email')
                  .eq('id', userId)
                  .maybeSingle();
              
              if (profileResponse != null) {
                tutor['profiles'] = profileResponse;
                tutorsWithProfiles.add(tutor);
              }
            } catch (e) {
              print('⚠️ Could not fetch profile for tutor ${tutor['user_id']}: $e');
            }
          }
          
          print('✅ Successfully fetched ${tutorsWithProfiles.length} tutors with profiles');
          rawTutors = tutorsWithProfiles;
        } catch (fallbackError) {
          print('❌ Fallback query also failed: $fallbackError');
          rethrow; // Re-throw the original error
        }
      }

      if (rawTutors.isEmpty) {
        print('⚠️ No tutors found with status="approved"');
        // Let's check what statuses exist and if there are any tutors at all
        try {
          final statusCheck = await SupabaseService.client
              .from('tutor_profiles')
              .select('status, user_id')
              .limit(10);
          print('📋 Sample tutor statuses: $statusCheck');
          
          // Also check total tutors without filter
          final allTutors = await SupabaseService.client
              .from('tutor_profiles')
              .select('status')
              .limit(100);
          print('📋 Total tutors checked: ${(allTutors as List).length}');
          if ((allTutors as List).isNotEmpty) {
            final statuses = (allTutors as List).map((t) => t['status']).toSet();
            print('📋 Available statuses: $statuses');
          }
        } catch (e) {
          print('⚠️ Could not check tutor statuses: $e');
        }
        return []; // Return empty list if no tutors found
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
        final profilesData = tutor['profiles'];
        if (profilesData == null) {
          print('❌ FILTERED OUT: Tutor $userId has no profile data');
          return false;
        }

        // Safely handle profiles - might be Map, String (JSON), or List
        Map<String, dynamic>? profile;
        if (profilesData is Map) {
          profile = Map<String, dynamic>.from(profilesData);
        } else if (profilesData is String) {
          // Try to parse JSON string
          try {
            final decoded = json.decode(profilesData);
            if (decoded is Map) {
              profile = Map<String, dynamic>.from(decoded);
            } else if (decoded is List && decoded.isNotEmpty) {
              // Sometimes Supabase returns a list with one item
              profile = Map<String, dynamic>.from(decoded[0]);
            }
          } catch (e) {
            print('⚠️ Tutor $userId: Could not parse profile JSON string: $e');
            return false;
          }
        } else if (profilesData is List && profilesData.isNotEmpty) {
          // Profile might be returned as a list
          final firstItem = profilesData[0];
          if (firstItem is Map) {
            profile = Map<String, dynamic>.from(firstItem);
          }
        }

        if (profile == null) {
          print('❌ FILTERED OUT: Tutor $userId has invalid profile data type: ${profilesData.runtimeType}');
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
        // Safely handle profiles - might be Map, String (JSON), or List (from Supabase response)
        Map<String, dynamic>? profile;
        final profilesData = tutor['profiles'];
        
        if (profilesData is Map) {
          profile = Map<String, dynamic>.from(profilesData);
        } else if (profilesData is String) {
          // Try to parse JSON string
          try {
            final decoded = json.decode(profilesData);
            if (decoded is Map) {
              profile = Map<String, dynamic>.from(decoded);
            } else if (decoded is List && decoded.isNotEmpty) {
              // Sometimes Supabase returns a list with one item
              final firstItem = decoded[0];
              if (firstItem is Map) {
                profile = Map<String, dynamic>.from(firstItem);
              }
            }
          } catch (e) {
            print('⚠️ Tutor ${tutor['user_id']}: Could not parse profile JSON string: $e');
            return null;
          }
        } else if (profilesData is List && profilesData.isNotEmpty) {
          // Profile might be returned as a list
          final firstItem = profilesData[0];
          if (firstItem is Map) {
            profile = Map<String, dynamic>.from(firstItem);
          } else if (firstItem is String) {
            // List of strings (JSON strings) - parse the first one
            try {
              final decoded = json.decode(firstItem);
              if (decoded is Map) {
                profile = Map<String, dynamic>.from(decoded);
              }
            } catch (e) {
              print('⚠️ Tutor ${tutor['user_id']}: Could not parse profile from list: $e');
              return null;
            }
          }
        }
        
        // If we couldn't get a valid profile, skip this tutor
        if (profile == null) {
          print('⚠️ Tutor ${tutor['user_id']}: No valid profile data found (type: ${profilesData?.runtimeType ?? 'null'})');
          return null;
        }

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
        final totalReviews = _safeCast<int>(tutor['total_reviews']) ?? 0;
        final adminApprovedRating = _safeCast<double>(tutor['admin_approved_rating']);
        final calculatedRating = _safeCast<double>(tutor['rating']) ?? 0.0;

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
        final baseSessionPrice = _safeCast<num>(tutor['base_session_price']);
        final adminPriceOverride = _safeCast<num>(tutor['admin_price_override']);
        final hourlyRate = _safeCast<num>(tutor['hourly_rate']);
        final perSessionRate = _safeCast<num>(tutor['per_session_rate']);

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

        // Bio mapping:
        // - 'bio': Dynamic bio for cards (starts with subjects, no "Hello!")
        // - 'personal_statement': Full bio with "Hello! I am..." for detail page "About" section
        // - 'motivation': Raw motivation text (fallback)
        final bio = _safeCast<String>(tutor['bio']); // Dynamic bio for cards
        final personalStatement = _safeCast<String>(tutor['personal_statement']); // Full bio for detail page
        final motivation = _safeCast<String>(tutor['motivation']); // Raw motivation (fallback)

        // For cards: Use personal_statement (the "about" section) - no "Hello!" in cards
        // Priority: personal_statement (about) > bio (dynamic) > motivation (raw fallback)
        // Note: personal_statement may start with "Hello!" but we'll handle that in the card display
        final effectiveBio =
            (personalStatement != null && personalStatement.trim().isNotEmpty)
            ? personalStatement
            : (bio != null && bio.trim().isNotEmpty)
            ? bio
            : (motivation != null && motivation.trim().isNotEmpty)
            ? motivation
            : '';

        // Store personal_statement separately for detail page "About" section
        final effectivePersonalStatement =
            (personalStatement != null && personalStatement.trim().isNotEmpty)
            ? personalStatement
            : '';

        // Format education data: Show "program • university" (field_of_study • institution)
        // Safely handle education - might be Map, String (JSON), or null
        Map<String, dynamic>? educationJson;
        final educationData = tutor['education'];
        if (educationData is Map) {
          educationJson = Map<String, dynamic>.from(educationData);
        } else if (educationData is String) {
          try {
            final decoded = json.decode(educationData);
            if (decoded is Map) {
              educationJson = Map<String, dynamic>.from(decoded);
            }
          } catch (e) {
            print('⚠️ Tutor ${tutor['user_id']}: Could not parse education JSON: $e');
          }
        }
        final institution = tutor['institution'] is String ? tutor['institution'] as String : null;
        final fieldOfStudy = tutor['field_of_study'] is String ? tutor['field_of_study'] as String : null;
        final highestEducation = tutor['highest_education'] is String ? tutor['highest_education'] as String : null;

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
        final teachingDuration = _safeCast<String>(tutor['teaching_duration']);
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
        // Safely handle availability - might be Map, String (JSON), or null
        Map<String, dynamic>? tutoringAvailability;
        final tutoringAvailData = tutor['tutoring_availability'];
        if (tutoringAvailData is Map) {
          tutoringAvailability = Map<String, dynamic>.from(tutoringAvailData);
        } else if (tutoringAvailData is String) {
          try {
            final decoded = json.decode(tutoringAvailData);
            if (decoded is Map) {
              tutoringAvailability = Map<String, dynamic>.from(decoded);
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }

        Map<String, dynamic>? testSessionAvailability;
        final testSessionAvailData = tutor['test_session_availability'];
        if (testSessionAvailData is Map) {
          testSessionAvailability = Map<String, dynamic>.from(testSessionAvailData);
        } else if (testSessionAvailData is String) {
          try {
            final decoded = json.decode(testSessionAvailData);
            if (decoded is Map) {
              testSessionAvailability = Map<String, dynamic>.from(decoded);
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }

        Map<String, dynamic>? availability;
        final availabilityData = tutor['availability'];
        if (availabilityData is Map) {
          availability = Map<String, dynamic>.from(availabilityData);
        } else if (availabilityData is String) {
          try {
            final decoded = json.decode(availabilityData);
            if (decoded is Map) {
              availability = Map<String, dynamic>.from(decoded);
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }

        Map<String, dynamic>? availabilitySchedule;
        final availabilityScheduleData = tutor['availability_schedule'];
        if (availabilityScheduleData is Map) {
          availabilitySchedule = Map<String, dynamic>.from(availabilityScheduleData);
        } else if (availabilityScheduleData is String) {
          try {
            final decoded = json.decode(availabilityScheduleData);
            if (decoded is Map) {
              availabilitySchedule = Map<String, dynamic>.from(decoded);
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }

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

        // Get avatar from tutor_profiles.profile_photo_url first, then fallback to profiles.avatar_url
        final profilePhotoUrl = tutor['profile_photo_url'] as String?;
        final avatarUrl = profile?['avatar_url'] as String?;
        final effectiveAvatarUrl =
            (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
            ? profilePhotoUrl
            : (avatarUrl != null && avatarUrl.isNotEmpty)
            ? avatarUrl
            : null;

        return {
          'id': tutor['user_id'],
          'full_name': profile?['full_name'] ?? 'Unknown',
          'avatar_url': effectiveAvatarUrl, // Use consolidated avatar URL
          'email': profile?['email'],
          'bio': effectiveBio, // Dynamic bio for cards (no "Hello!")
          'personal_statement':
              effectivePersonalStatement, // Full bio for detail page (with "Hello!")
          'education':
              formattedEducation, // Formatted as "program • university"
          'highest_education':
              highestEducation, // Highest education level for certifications section
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
          // Teaching style: Build from teaching_approaches, preferred_mode, preferred_session_type
          'teaching_style': _buildTeachingStyleText(
            tutor['teaching_approaches'] as List?,
            tutor['preferred_mode'] as String?,
            tutor['preferred_session_type'] as String?,
            tutor['handles_multiple_learners'] as bool?,
          ),
          'teaching_approaches': tutor['teaching_approaches'],
          'preferred_mode': tutor['preferred_mode'],
          'preferred_session_type': tutor['preferred_session_type'],
          'handles_multiple_learners': tutor['handles_multiple_learners'],
        };
      }).whereType<Map<String, dynamic>>().toList(); // Filter out nulls

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
          // Table might not exist yet - silently fallback to 0
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
          .neq('is_hidden', true)
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

      // Bio mapping:
      // - 'bio': Dynamic bio for cards (starts with subjects, no "Hello!")
      // - 'personal_statement': Full bio with "Hello! I am..." for detail page "About" section
      // - 'motivation': Raw motivation text (fallback)
      final bio = response['bio'] as String?; // Dynamic bio for cards
      final personalStatement =
          response['personal_statement'] as String?; // Full bio for detail page
      final motivation =
          response['motivation'] as String?; // Raw motivation (fallback)

      // For cards: Use personal_statement (the "about" section) - no "Hello!" in cards
      // Priority: personal_statement (about) > bio (dynamic) > motivation (raw fallback)
      // Note: personal_statement may start with "Hello!" but we'll handle that in the card display
      final effectiveBio =
          (personalStatement != null && personalStatement.trim().isNotEmpty)
          ? personalStatement
          : (bio != null && bio.trim().isNotEmpty)
          ? bio
          : (motivation != null && motivation.trim().isNotEmpty)
          ? motivation
          : '';

      // Store personal_statement separately for detail page "About" section
      final effectivePersonalStatement =
          (personalStatement != null && personalStatement.trim().isNotEmpty)
          ? personalStatement
          : '';

      // Format education data: Show "program • university" (field_of_study • institution)
      final educationJson = response['education'] as Map<String, dynamic>?;
      final institution = response['institution'] as String?;
      final fieldOfStudy = response['field_of_study'] as String?;
      final highestEducation = response['highest_education'] as String?;

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
        // Table might not exist yet - silently fallback to 0
        completedSessions = 0;
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
        'bio': effectiveBio, // Dynamic bio for cards (no "Hello!")
        'personal_statement':
            effectivePersonalStatement, // Full bio for detail page (with "Hello!")
        'education': formattedEducation, // Formatted as "program • university"
        'highest_education':
            highestEducation, // Highest education level for certifications section
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
        // Teaching style: Build from teaching_approaches, preferred_mode, preferred_session_type
        'teaching_style': _buildTeachingStyleText(
          response['teaching_approaches'] as List?,
          response['preferred_mode'] as String?,
          response['preferred_session_type'] as String?,
          response['handles_multiple_learners'] as bool?,
        ),
        'teaching_approaches': response['teaching_approaches'],
        'preferred_mode': response['preferred_mode'],
        'preferred_session_type': response['preferred_session_type'],
        'handles_multiple_learners': response['handles_multiple_learners'],
      };
    } catch (e) {
      print('❌ Error fetching tutor by ID from Supabase: $e');
      return null;
    }
  }

  /// Build teaching style text from collected data
  static String _buildTeachingStyleText(
    List? teachingApproaches,
    String? preferredMode,
    String? preferredSessionType,
    bool? handlesMultipleLearners,
  ) {
    final parts = <String>[];

    // Preferred teaching mode
    if (preferredMode != null && preferredMode.isNotEmpty) {
      parts.add('Teaching Mode: $preferredMode');
    }

    // Teaching approaches
    if (teachingApproaches != null && teachingApproaches.isNotEmpty) {
      final approaches = teachingApproaches.map((a) => a.toString()).join(', ');
      parts.add('Approach: $approaches');
    }

    // Preferred session type
    if (preferredSessionType != null && preferredSessionType.isNotEmpty) {
      parts.add('Session Type: $preferredSessionType');
    }

    // Multiple learners
    if (handlesMultipleLearners == true) {
      parts.add('Can handle multiple learners');
    }

    if (parts.isEmpty) {
      return 'Teaching style information not available';
    }

    return parts.join('. ');
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
          .neq('is_hidden', true)
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
