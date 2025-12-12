import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
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
      LogService.info('Saving step $stepNumber progress for user: $userId');

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

      LogService.success('Step $stepNumber progress saved successfully');
    } catch (e) {
      LogService.error('Error saving step progress: $e');
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
      LogService.info('Saving all progress for user: $userId');

      await SupabaseService.client
          .from('tutor_onboarding_progress')
          .upsert({
        'user_id': userId,
        'current_step': currentStep,
        'step_data': allStepData,
        'completed_steps': completedSteps,
        'is_complete': completedSteps.length >= 13, // Auto-set complete if mostly done
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      LogService.success('All progress saved successfully');
    } catch (e) {
      LogService.error('Error saving all progress: $e');
      rethrow;
    }
  }

  /// Load all progress for a user
  ///
  /// This method now includes synchronization logic to backfill progress
  /// from existing tutor profiles (for users who signed up before progress tracking).
  static Future<Map<String, dynamic>?> loadProgress(String userId) async {
    try {
      LogService.debug('📖 Loading progress for user: $userId');

      // 1. Try loading from progress table
      var progress = await SupabaseService.client
          .from('tutor_onboarding_progress')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // 2. Fetch Profiles (Tutor & Base) for Sync/Verification
      final profile = await SupabaseService.client
          .from('tutor_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final baseProfile = await SupabaseService.client
          .from('profiles')
          .select('email, phone_number')
          .eq('id', userId)
          .maybeSingle();

      // 3. Check Verification Status
      bool isVerified = false;
      if (profile != null) {
        final status = profile['status'];
        isVerified = (status == 'verified' || status == 'approved' || status == 'pending');
      }

      // 4. Decide whether to use existing progress or Sync
      bool useExisting = false;
      if (progress != null) {
        if (isVerified) {
           // If verified, only use existing if it's fully complete
           if (progress['is_complete'] == true) {
             useExisting = true;
           } else {
             LogService.warning('Verified user has incomplete progress. Forcing Sync...');
             useExisting = false;
           }
        } else {
           // Not verified: Use existing if it has data
           if (progress['step_data'] != null && (progress['step_data'] as Map).isNotEmpty) {
              final sData = progress['step_data'] as Map;
              // If Step 0 missing, Force Sync to pick up email/phone from baseProfile
              if (sData['0'] == null) {
                 LogService.debug('🛠️ Step 0 missing. Forcing Sync...');
                 useExisting = false; 
              } else {
                 useExisting = true;
              }
           }
        }
      }

      if (useExisting) {
        LogService.success('Using existing progress from tracking table');
        return progress;
      }

      // 5. Sync / Construct Progress
      LogService.debug('🔄 Syncing/Constructing progress from profiles...');
      
      if (profile == null) {
        LogService.info('No existing tutor profile found. New user.');
        return progress; 
      }

      final stepData = <String, dynamic>{};
      final completedSteps = <int>[];

      // Helper to add step data if fields exist
      void addStepIfPresent(int step, Map<String, dynamic> data) {
        // Check if any value in data is non-null and non-empty
        bool hasData = data.values.any((v) => v != null && v.toString().isNotEmpty);
        if (hasData) {
          stepData[step.toString()] = data;
          if (!completedSteps.contains(step)) {
            completedSteps.add(step);
          }
        }
      }

      // --- Map Profile Fields to Steps ---
      
      // Step 0: Contact Info (Prioritize base profile data)
      final contactEmail = baseProfile?['email'] ?? profile['email'];
      final contactPhone = baseProfile?['phone_number'] ?? profile['phone_number'];
      addStepIfPresent(0, {
        'phone': contactPhone,
        'email': contactEmail,
      });

      // Step 1: Academic
      if (profile['highest_education'] != null) {
        addStepIfPresent(1, {
          'selectedEducation': profile['highest_education'],
          'institution': profile['institution'],
          'fieldOfStudy': profile['field_of_study'],
          'hasTraining': profile['has_training'] ?? false,
        });
      }

      // Step 2: Location
      if (profile['city'] != null) {
        addStepIfPresent(2, {
          'selectedCity': profile['city'],
          'selectedQuarter': profile['quarter'],
          'customQuarter': profile['custom_quarter'],
        });
      }

      // Step 3: Teaching Focus
      if (profile['tutoring_areas'] != null || profile['selected_tutoring_areas'] != null) {
        addStepIfPresent(3, {
          'selectedTutoringAreas': profile['tutoring_areas'] ?? profile['selected_tutoring_areas'],
          'selectedLearnerLevels': profile['learner_levels'] ?? profile['selected_learner_levels'],
        });
      }

      // Step 4: Specializations
      if (profile['specializations'] != null || profile['selected_specializations'] != null) {
        addStepIfPresent(4, {
          'selectedSpecializations': profile['specializations'] ?? profile['selected_specializations'],
        });
      }

      // Step 5: Experience
      if (profile['teaching_experience'] != null || profile['has_experience'] != null) {
        addStepIfPresent(5, {
          'hasExperience': profile['has_experience'] ?? profile['teaching_experience'],
          'experienceDuration': profile['experience_duration'] ?? profile['teaching_duration'],
          'motivation': profile['motivation'] ?? profile['bio'],
        });
      }

      // Step 6: Teaching Style
      if (profile['preferred_mode'] != null) {
        addStepIfPresent(6, {
          'preferredMode': profile['preferred_mode'],
          'teachingApproaches': profile['teaching_approaches'],
          'hoursPerWeek': profile['hours_per_week'],
        });
      }

      // Step 7: Digital Readiness
      if (profile['has_internet'] != null) {
        addStepIfPresent(7, {
          'hasInternet': profile['has_internet'],
          'devices': profile['devices'],
        });
      }

      // Step 8: Availability
      if (profile['tutoring_availability'] != null || profile['availability_schedule'] != null) {
        addStepIfPresent(8, {
          'tutoringAvailability': profile['tutoring_availability'] ?? profile['availability_schedule'],
        });
      }

      // Step 9: Expectations
      if (profile['hourly_rate'] != null || profile['expected_rate'] != null) {
        addStepIfPresent(9, {
          'expectedRate': profile['expected_rate'] ?? profile['hourly_rate'],
        });
      }

      // Step 10: Payment Method
      if (profile['payment_method'] != null) {
        addStepIfPresent(10, {
          'paymentMethod': profile['payment_method'],
          'paymentNumber': (profile['payment_details'] is Map) ? profile['payment_details']['phone'] : null,
        });
      }

      // Step 11: Verification
      if (profile['id_card_front_url'] != null) {
        addStepIfPresent(11, {
          'idCardFrontUrl': profile['id_card_front_url'],
          'agreesToVerification': true,
        });
      }

      // Step 12: Media
      if (profile['video_link'] != null || profile['video_intro'] != null) {
        addStepIfPresent(12, {
          'videoLink': profile['video_intro'] ?? profile['video_link'],
        });
      }

      // Step 13: Statement
      if (profile['personal_statement'] != null || profile['bio'] != null) {
        addStepIfPresent(13, {
          'personalStatement': profile['personal_statement'] ?? profile['bio'],
          'finalAgreements': {'terms': true}, 
        });
      }

      // Sort completed steps
      completedSteps.sort();

      // 6. Finalize Sync
      // Force completion if verified
      if (isVerified) {
        LogService.success('User is verified. Forcing 100% completion.');
        // Ensure all steps 0-13 are in completedSteps
        for (int i = 0; i <= 13; i++) {
           if (!completedSteps.contains(i)) completedSteps.add(i);
        }
        completedSteps.sort();
      }

      // Determine current step
      int currentStep = 0;
      if (completedSteps.isNotEmpty) {
         for (int i = 0; i <= 13; i++) {
          if (!completedSteps.contains(i)) {
            currentStep = i;
            break;
          }
        }
        if (completedSteps.length == 14) currentStep = 13;
      }

      // Save synced progress
      await saveAllProgress(userId, stepData, currentStep, completedSteps);
      
      return {
        'user_id': userId,
        'current_step': currentStep,
        'step_data': stepData,
        'completed_steps': completedSteps,
        'is_complete': completedSteps.length >= 13,
        'skipped_onboarding': false,
      };

    } catch (e) {
      LogService.error('Error loading progress: $e');
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
      LogService.error('Error getting completed steps: $e');
      return [];
    }
  }

  /// Mark a step as complete
  static Future<void> markStepComplete(String userId, int stepNumber) async {
    try {
      LogService.success('Marking step $stepNumber as complete for user: $userId');

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

      LogService.success('Step $stepNumber marked as complete');
    } catch (e) {
      LogService.error('Error marking step complete: $e');
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
      LogService.error('Error checking onboarding completion: $e');
      return false;
    }
  }

  /// Mark onboarding as complete
  static Future<void> markOnboardingComplete(String userId) async {
    try {
      LogService.debug('🎉 Marking onboarding as complete for user: $userId');

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

      LogService.success('Onboarding marked as complete');
    } catch (e) {
      LogService.error('Error marking onboarding complete: $e');
      rethrow;
    }
  }

  /// Skip onboarding (called when tutor chooses "Skip for Later")
  static Future<void> skipOnboarding(String userId) async {
    try {
      LogService.debug('⏭️ Skipping onboarding for user: $userId');

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

      LogService.success('Onboarding skipped');
    } catch (e) {
      LogService.error('Error skipping onboarding: $e');
      rethrow;
    }
  }

  /// Resume onboarding (clear skip flag when they start onboarding)
  static Future<void> resumeOnboarding(String userId) async {
    try {
      LogService.debug('▶️ Resuming onboarding for user: $userId');

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

      LogService.success('Onboarding resumed');
    } catch (e) {
      LogService.error('Error resuming onboarding: $e');
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
      LogService.error('Error checking if onboarding skipped: $e');
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
      LogService.error('Error getting current step: $e');
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
      LogService.error('Error getting step data: $e');
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
      LogService.error('Error getting progress record: $e');
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
      LogService.success('Progress deleted');
    } catch (e) {
      LogService.error('Error deleting progress: $e');
      rethrow;
    }
  }
}
