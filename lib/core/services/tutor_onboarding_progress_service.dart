import 'package:prepskul/core/services/supabase_service.dart';
import 'dart:convert';

/// Service to manage tutor onboarding progress tracking
class TutorOnboardingProgressService {
  /// Save progress for a specific step
  /// stepData should be a Map with field names as keys and their values
  static Future<void> saveStepProgress(
    String userId,
    int stepNumber,
    Map<String, dynamic> stepData,
  ) async {
    try {
      print('💾 Saving step $stepNumber progress for user: $userId');

      // Get current progress
      final currentProgress = await _getProgressRecord(userId);

      // Merge step data into existing step_data
      Map<String, dynamic> updatedStepData;
      if (currentProgress != null) {
        final existingStepData =
            currentProgress['step_data'] as Map<String, dynamic>? ?? {};
        updatedStepData = Map<String, dynamic>.from(existingStepData);
        updatedStepData[stepNumber.toString()] = stepData;
      } else {
        updatedStepData = {stepNumber.toString(): stepData};
      }

      // Update completed_steps if step is valid
      List<int> completedSteps = [];
      if (currentProgress != null) {
        final existingCompleted =
            currentProgress['completed_steps'] as List<dynamic>? ?? [];
        completedSteps = existingCompleted.map((e) => e as int).toList();
      }

      // Upsert progress record
      await SupabaseService.client
          .from('tutor_onboarding_progress')
          .upsert({
        'user_id': userId,
        'current_step': stepNumber,
        'step_data': updatedStepData,
        'completed_steps': completedSteps,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      print('✅ Step $stepNumber progress saved successfully');
    } catch (e) {
      print('❌ Error saving step progress: $e');
      rethrow;
    }
  }

  /// Save all progress data at once (useful for bulk updates)
  static Future<void> saveAllProgress(
    String userId,
    Map<String, dynamic> allStepData,
    int currentStep,
    List<int> completedSteps,
  ) async {
    try {
      print('💾 Saving all progress for user: $userId');

      await SupabaseService.client
          .from('tutor_onboarding_progress')
          .upsert({
        'user_id': userId,
        'current_step': currentStep,
        'step_data': allStepData,
        'completed_steps': completedSteps,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      print('✅ All progress saved successfully');
    } catch (e) {
      print('❌ Error saving all progress: $e');
      rethrow;
    }
  }

  /// Load all progress for a user
  static Future<Map<String, dynamic>?> loadProgress(String userId) async {
    try {
      print('📖 Loading progress for user: $userId');

      final response = await SupabaseService.client
          .from('tutor_onboarding_progress')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ No progress found for user: $userId');
        return null;
      }

      print('✅ Progress loaded successfully');
      return response;
    } catch (e) {
      print('❌ Error loading progress: $e');
      return null;
    }
  }

  /// Get completed steps array
  static Future<List<int>> getCompletedSteps(String userId) async {
    try {
      final progress = await loadProgress(userId);
      if (progress == null) {
        return [];
      }

      final completedSteps = progress['completed_steps'] as List<dynamic>? ?? [];
      return completedSteps.map((e) => e as int).toList();
    } catch (e) {
      print('❌ Error getting completed steps: $e');
      return [];
    }
  }

  /// Mark a step as complete
  static Future<void> markStepComplete(String userId, int stepNumber) async {
    try {
      print('✅ Marking step $stepNumber as complete for user: $userId');

      final currentProgress = await _getProgressRecord(userId);
      List<int> completedSteps = [];

      if (currentProgress != null) {
        final existingCompleted =
            currentProgress['completed_steps'] as List<dynamic>? ?? [];
        completedSteps = existingCompleted.map((e) => e as int).toList();
      }

      // Add step if not already in list
      if (!completedSteps.contains(stepNumber)) {
        completedSteps.add(stepNumber);
        completedSteps.sort();
      }

      await SupabaseService.client
          .from('tutor_onboarding_progress')
          .upsert({
        'user_id': userId,
        'completed_steps': completedSteps,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      print('✅ Step $stepNumber marked as complete');
    } catch (e) {
      print('❌ Error marking step complete: $e');
      rethrow;
    }
  }

  /// Check if onboarding is complete
  static Future<bool> isOnboardingComplete(String userId) async {
    try {
      final progress = await loadProgress(userId);
      if (progress == null) {
        return false;
      }
      return progress['is_complete'] as bool? ?? false;
    } catch (e) {
      print('❌ Error checking onboarding completion: $e');
      return false;
    }
  }

  /// Mark onboarding as complete
  static Future<void> markOnboardingComplete(String userId) async {
    try {
      print('🎉 Marking onboarding as complete for user: $userId');

      await SupabaseService.client
          .from('tutor_onboarding_progress')
          .upsert({
        'user_id': userId,
        'is_complete': true,
        'skipped_onboarding': false, // Clear skip flag if completing
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // Also update profiles table
      await SupabaseService.client
          .from('profiles')
          .update({'onboarding_skipped': false})
          .eq('id', userId);

      print('✅ Onboarding marked as complete');
    } catch (e) {
      print('❌ Error marking onboarding complete: $e');
      rethrow;
    }
  }

  /// Skip onboarding (called when tutor chooses "Skip for Later")
  static Future<void> skipOnboarding(String userId) async {
    try {
      print('⏭️ Skipping onboarding for user: $userId');

      // Create progress record with skipped flag
      await SupabaseService.client
          .from('tutor_onboarding_progress')
          .upsert({
        'user_id': userId,
        'skipped_onboarding': true,
        'is_complete': false,
        'current_step': 0,
        'step_data': {},
        'completed_steps': [],
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // Also update profiles table
      await SupabaseService.client
          .from('profiles')
          .update({'onboarding_skipped': true})
          .eq('id', userId);

      print('✅ Onboarding skipped');
    } catch (e) {
      print('❌ Error skipping onboarding: $e');
      rethrow;
    }
  }

  /// Resume onboarding (clear skip flag when they start onboarding)
  static Future<void> resumeOnboarding(String userId) async {
    try {
      print('▶️ Resuming onboarding for user: $userId');

      await SupabaseService.client
          .from('tutor_onboarding_progress')
          .update({
        'skipped_onboarding': false,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', userId);

      // Also update profiles table
      await SupabaseService.client
          .from('profiles')
          .update({'onboarding_skipped': false})
          .eq('id', userId);

      print('✅ Onboarding resumed');
    } catch (e) {
      print('❌ Error resuming onboarding: $e');
      rethrow;
    }
  }

  /// Check if onboarding was skipped
  static Future<bool> isOnboardingSkipped(String userId) async {
    try {
      final progress = await loadProgress(userId);
      if (progress == null) {
        return false;
      }
      return progress['skipped_onboarding'] as bool? ?? false;
    } catch (e) {
      print('❌ Error checking if onboarding skipped: $e');
      return false;
    }
  }

  /// Get current step number
  static Future<int> getCurrentStep(String userId) async {
    try {
      final progress = await loadProgress(userId);
      if (progress == null) {
        return 0;
      }
      return progress['current_step'] as int? ?? 0;
    } catch (e) {
      print('❌ Error getting current step: $e');
      return 0;
    }
  }

  /// Get step data for a specific step
  static Future<Map<String, dynamic>?> getStepData(
    String userId,
    int stepNumber,
  ) async {
    try {
      final progress = await loadProgress(userId);
      if (progress == null) {
        return null;
      }

      final stepData = progress['step_data'] as Map<String, dynamic>? ?? {};
      return stepData[stepNumber.toString()] as Map<String, dynamic>?;
    } catch (e) {
      print('❌ Error getting step data: $e');
      return null;
    }
  }

  /// Helper method to get progress record
  static Future<Map<String, dynamic>?> _getProgressRecord(
    String userId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('tutor_onboarding_progress')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Error getting progress record: $e');
      return null;
    }
  }

  /// Delete progress (useful for testing or reset)
  static Future<void> deleteProgress(String userId) async {
    try {
      await SupabaseService.client
          .from('tutor_onboarding_progress')
          .delete()
          .eq('user_id', userId);
      print('✅ Progress deleted');
    } catch (e) {
      print('❌ Error deleting progress: $e');
      rethrow;
    }
  }
}

