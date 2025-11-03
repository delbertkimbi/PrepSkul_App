import 'package:prepskul/core/services/supabase_service.dart';

/// Repository for saving and retrieving survey data
class SurveyRepository {
  // ==================== TUTOR PROFILE ====================

  /// Save tutor survey data
  static Future<void> saveTutorSurvey(
    String userId,
    Map<String, dynamic> data,
    String? contactInfo, // Email or phone based on auth method
  ) async {
    try {
      print('📝 Saving tutor survey for user: $userId');

      // Save to tutor_profiles table
      await SupabaseService.client.from('tutor_profiles').upsert({
        'user_id': userId,
        ...data,
      }, onConflict: 'user_id');

      // Update profiles table with contact info and mark survey as completed
      final profileUpdates = <String, dynamic>{'survey_completed': true};

      if (contactInfo != null && contactInfo.isNotEmpty) {
        // Determine if it's email or phone based on format
        if (contactInfo.contains('@')) {
          // It's an email
          profileUpdates['email'] = contactInfo;
        } else if (contactInfo.startsWith('+')) {
          // It's a phone number
          profileUpdates['phone_number'] = contactInfo;
        }
      }

      await SupabaseService.client
          .from('profiles')
          .update(profileUpdates)
          .eq('id', userId);

      print('✅ Tutor survey saved successfully');
    } catch (e) {
      print('❌ Error saving tutor survey: $e');
      rethrow;
    }
  }

  /// Get tutor survey data
  static Future<Map<String, dynamic>?> getTutorSurvey(String userId) async {
    try {
      print('📖 Fetching tutor survey for user: $userId');

      final response = await SupabaseService.client
          .from('tutor_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      print('✅ Tutor survey fetched: ${response != null}');
      return response;
    } catch (e) {
      print('❌ Error fetching tutor survey: $e');
      return null;
    }
  }

  /// Update tutor survey data
  static Future<void> updateTutorSurvey(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('📝 Updating tutor survey for user: $userId');

      await SupabaseService.client
          .from('tutor_profiles')
          .update(updates)
          .eq('user_id', userId);

      print('✅ Tutor survey updated successfully');
    } catch (e) {
      print('❌ Error updating tutor survey: $e');
      rethrow;
    }
  }

  // ==================== STUDENT PROFILE ====================

  /// Save student survey data
  static Future<void> saveStudentSurvey(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      print('📝 Saving student survey for user: $userId');

      // CRITICAL: Ensure profile exists before saving to learner_profiles
      // This prevents foreign key constraint violations
      final existingProfile = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existingProfile == null) {
        // Profile doesn't exist - create it first
        print('⚠️ Profile not found for user $userId, creating profile...');
        final user = SupabaseService.client.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated. Cannot create profile.');
        }

        await SupabaseService.client.from('profiles').upsert({
          'id': userId,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? 'Student',
          'phone_number': user.phone,
          'user_type': 'student',
          'survey_completed': false,
          'is_admin': false,
        }, onConflict: 'id');

        print('✅ Profile created for user: $userId');
      }

      // Save to learner_profiles table
      // Use 'id' as it's the primary key that references profiles.id
      await SupabaseService.client.from('learner_profiles').upsert({
        'id': userId, // Use id as it's the FK to profiles
        'user_id': userId, // Also set user_id if column exists
        ...data,
      }, onConflict: 'id'); // Conflict on id (primary key)

      // Mark survey as completed
      await SupabaseService.client
          .from('profiles')
          .update({'survey_completed': true})
          .eq('id', userId);

      print('✅ Student survey saved successfully');
    } catch (e) {
      print('❌ Error saving student survey: $e');
      rethrow;
    }
  }

  /// Get student survey data
  static Future<Map<String, dynamic>?> getStudentSurvey(String userId) async {
    try {
      print('📖 Fetching student survey for user: $userId');

      final response = await SupabaseService.client
          .from('learner_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      print('✅ Student survey fetched: ${response != null}');
      return response;
    } catch (e) {
      print('❌ Error fetching student survey: $e');
      return null;
    }
  }

  /// Update student survey data
  static Future<void> updateStudentSurvey(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('📝 Updating student survey for user: $userId');

      await SupabaseService.client
          .from('learner_profiles')
          .update(updates)
          .eq('user_id', userId);

      print('✅ Student survey updated successfully');
    } catch (e) {
      print('❌ Error updating student survey: $e');
      rethrow;
    }
  }

  // ==================== PARENT PROFILE ====================

  /// Save parent survey data
  static Future<void> saveParentSurvey(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      print('📝 Saving parent survey for user: $userId');

      // CRITICAL: Ensure profile exists before saving to parent_profiles
      // This prevents foreign key constraint violations
      final existingProfile = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existingProfile == null) {
        // Profile doesn't exist - create it first
        print('⚠️ Profile not found for user $userId, creating profile...');
        final user = SupabaseService.client.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated. Cannot create profile.');
        }

        await SupabaseService.client.from('profiles').upsert({
          'id': userId,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? 'Parent',
          'phone_number': user.phone,
          'user_type': 'parent',
          'survey_completed': false,
          'is_admin': false,
        }, onConflict: 'id');

        print('✅ Profile created for user: $userId');
      }

      // Save to parent_profiles table
      // Use 'id' as it's the primary key that references profiles.id
      await SupabaseService.client.from('parent_profiles').upsert({
        'id': userId, // Use id as it's the FK to profiles
        'user_id': userId, // Also set user_id if column exists
        ...data,
      }, onConflict: 'id'); // Conflict on id (primary key)

      // Mark survey as completed
      await SupabaseService.client
          .from('profiles')
          .update({'survey_completed': true})
          .eq('id', userId);

      print('✅ Parent survey saved successfully');
    } catch (e) {
      print('❌ Error saving parent survey: $e');
      rethrow;
    }
  }

  /// Get parent survey data
  static Future<Map<String, dynamic>?> getParentSurvey(String userId) async {
    try {
      print('📖 Fetching parent survey for user: $userId');

      final response = await SupabaseService.client
          .from('parent_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      print('✅ Parent survey fetched: ${response != null}');
      return response;
    } catch (e) {
      print('❌ Error fetching parent survey: $e');
      return null;
    }
  }

  /// Update parent survey data
  static Future<void> updateParentSurvey(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('📝 Updating parent survey for user: $userId');

      await SupabaseService.client
          .from('parent_profiles')
          .update(updates)
          .eq('user_id', userId);

      print('✅ Parent survey updated successfully');
    } catch (e) {
      print('❌ Error updating parent survey: $e');
      rethrow;
    }
  }
}
