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
  static const bool USE_DEMO_DATA = true;

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
      // Build query
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
          .eq('status', 'approved'); // Only show approved tutors

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

      // Transform data to match demo format
      return (response as List).map((tutor) {
        final profile = tutor['profiles'];
        return {
          'id': tutor['user_id'],
          'full_name': profile['full_name'],
          'avatar_url': profile['avatar_url'],
          'email': profile['email'],
          'bio': tutor['bio'],
          'education': tutor['education'],
          'experience': tutor['experience'],
          'subjects': tutor['subjects'],
          'hourly_rate': tutor['hourly_rate'],
          'availability': tutor['availability'],
          'is_verified': tutor['is_verified'] ?? false,
          'rating': tutor['rating'] ?? 0.0,
          'city': tutor['city'],
          'quarter': tutor['quarter'],
          'video_intro': tutor['video_link'],
          'teaching_style': tutor['personal_statement'],
        };
      }).toList();
    } catch (e) {
      print('❌ Error fetching tutors from Supabase: $e');
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
      return {
        'id': response['user_id'],
        'full_name': profile['full_name'],
        'avatar_url': profile['avatar_url'],
        'email': profile['email'],
        'bio': response['bio'],
        'education': response['education'],
        'experience': response['experience'],
        'subjects': response['subjects'],
        'hourly_rate': response['hourly_rate'],
        'availability': response['availability'],
        'is_verified': response['is_verified'] ?? false,
        'rating': response['rating'] ?? 0.0,
        'city': response['city'],
        'quarter': response['quarter'],
        'video_intro': response['video_link'],
        'teaching_style': response['personal_statement'],
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
