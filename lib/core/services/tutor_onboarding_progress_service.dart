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
  ///
  /// This method now includes synchronization logic to backfill progress
  /// from existing tutor profiles (for users who signed up before progress tracking).
  static Future<Map<String, dynamic>?> loadProgress(String userId) async {
    try {
      print('📖 Loading progress for user: $userId');

      // 1. Try loading from progress table
      var progress = await SupabaseService.client
          .from('tutor_onboarding_progress')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // PATCH: Check if Step 0 is missing in existing progress and patch it
      if (progress != null) {
        final stepData = progress['step_data'] as Map<String, dynamic>? ?? {};
        final step0 = stepData['0'];
        
        if (step0 == null || (step0 as Map).isEmpty) {
          print('🛠️ Progress exists but Step 0 missing. Patching from profiles...');
          try {
            final baseProfile = await SupabaseService.client
                .from('profiles')
                .select('email, phone_number')
                .eq('id', userId)
                .maybeSingle();
            
            if (baseProfile != null) {
               final email = baseProfile['email'];
               final phone = baseProfile['phone_number'];
               
               if (email != null || phone != null) {
                 final step0Data = {
                   'email': email,
                   'phone': phone,
                 };
                 
                 // Save to DB (this updates completed_steps too)
                 await saveStepProgress(userId, 0, step0Data);
                 
                 // Update local object
                 final updatedStepData = Map<String, dynamic>.from(stepData);
                 updatedStepData['0'] = step0Data;
                 progress['step_data'] = updatedStepData;
                 
                 // Update local completed_steps
                 final completed = List<dynamic>.from(progress['completed_steps'] ?? []);
                 if (!completed.contains(0)) {
                   completed.add(0);
                   progress['completed_steps'] = completed;
                 }
                 print('✅ Step 0 patched successfully');
               }
            }
          } catch (e) {
            print('⚠️ Error patching Step 0: $e');
          }
        }
      }

      // 2. If progress found and has actual step data, return it
      if (progress != null && 
          progress['step_data'] != null && 
          (progress['step_data'] as Map).isNotEmpty) {
        print('✅ Progress loaded successfully from tracking table');
        return progress;
      }

      // 3. If tracking record missing/empty, check existing tutor_profiles for sync
      print('⚠️ No tracking progress found. Checking existing profile for sync...');
      
      final profile = await SupabaseService.client
          .from('tutor_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // Fetch base profile for reliable contact info (email/phone)
      final baseProfile = await SupabaseService.client
          .from('profiles')
          .select('email, phone_number')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        print('ℹ️ No existing tutor profile found. New user.');
        return progress; // Return null or empty progress if new
      }

      // 4. Construct progress from profile data
      print('🔄 Syncing progress from existing profile...');
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
      
      // Step 0: Contact Info (from profile table mostly, but verify here)
      // Prioritize base profile data, fallback to tutor profile
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

      // Step 7: Digital Readiness (Often missing in older profiles, check specific fields)
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
          // Assuming details are in payment_details json
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

      // Step 13: Statement (use bio/motivation if not used in step 5, or personal_statement)
      if (profile['personal_statement'] != null || profile['bio'] != null) {
        addStepIfPresent(13, {
          'personalStatement': profile['personal_statement'] ?? profile['bio'],
          'finalAgreements': {'terms': true}, // Assume agreed if profile exists
        });
      }

      // Sort completed steps
      completedSteps.sort();

      // 5. Save synced progress
      // Only save if we found completed steps
      if (completedSteps.isNotEmpty) {
        // Determine current step (first incomplete step)
        int currentStep = 0;
        for (int i = 0; i <= 13; i++) {
          if (!completedSteps.contains(i)) {
            currentStep = i;
            break;
          }
        }
        if (completedSteps.length == 14) currentStep = 13;

        // Mark as complete if verified or pending
        bool isComplete = false;
        if (profile['status'] == 'verified' || profile['status'] == 'approved' || profile['status'] == 'pending') {
           isComplete = completedSteps.length >= 13; // Allow some slack or strict 14
        }

        await saveAllProgress(userId, stepData, currentStep, completedSteps);
        
        // Return newly constructed progress
        return {
          'user_id': userId,
          'current_step': currentStep,
          'step_data': stepData,
          'completed_steps': completedSteps,
          'is_complete': isComplete,
          'skipped_onboarding': false,
        };
      }

      return progress; // Return original null/empty if sync failed to find data
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

