import 'package:prepskul/core/services/supabase_service.dart';

/// Repository for saving and retrieving survey data
class SurveyRepository {
  // ==================== TUTOR PROFILE ====================

  /// Save tutor survey data
  static Future<void> saveTutorSurvey(
    String userId,
    Map<String, dynamic> data,
    String? email, // Pass email separately since it goes to profiles table
  ) async {
    try {
      print('📝 Saving tutor survey for user: $userId');

      // Save to tutor_profiles table (email is NOT in this table)
      await SupabaseService.client.from('tutor_profiles').upsert({
        'user_id': userId,
        ...data,
      });

      // Update profiles table with email and mark survey as completed
      final profileUpdates = <String, dynamic>{'survey_completed': true};

      if (email != null && email.isNotEmpty) {
        profileUpdates['email'] = email;
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

      // Save to learner_profiles table
      await SupabaseService.client.from('learner_profiles').upsert({
        'user_id': userId,
        ...data,
      });

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

      // Save to parent_profiles table
      await SupabaseService.client.from('parent_profiles').upsert({
        'user_id': userId,
        ...data,
      });

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
