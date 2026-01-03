import 'dart:convert';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/tutor_onboarding_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      LogService.info('Saving tutor survey for user: $userId');

      // CRITICAL: Ensure profile exists in profiles table BEFORE saving tutor profile
      // This prevents foreign key constraint violations
      Map<String, dynamic>? existingProfile;
      try {
        existingProfile = await SupabaseService.client
            .from('profiles')
            .select('id, email, phone_number, full_name, user_type')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        LogService.warning('Error checking profile existence: $e');
        existingProfile = null;
      }

      if (existingProfile == null) {
        // Profile doesn't exist - create it first
        LogService.warning('Profile not found for user $userId, creating profile...');
        final user = SupabaseService.client.auth.currentUser;
        if (user == null) {
          throw Exception(
            'User not authenticated. Cannot create profile. Please log in again.',
          );
        }

        try {
          // Determine email and phone from contactInfo or user object
          String? email = user.email;
          String? phone = user.phone;

          // Override with contactInfo if provided
          if (contactInfo != null && contactInfo.isNotEmpty) {
            if (contactInfo.contains('@')) {
              email = contactInfo;
            } else if (contactInfo.startsWith('+')) {
              phone = contactInfo;
            }
          }

          await SupabaseService.client.from('profiles').upsert({
            'id': userId,
            'email': email ?? '',
            'full_name':
                user.userMetadata?['full_name'] ?? data['full_name'] ?? 'Tutor',
            'phone_number': phone,
            'user_type': 'tutor',
            'survey_completed': false,
            'is_admin': false,
          }, onConflict: 'id');

          LogService.success('Profile created for user: $userId');
        } catch (profileError) {
          LogService.error('Error creating profile: $profileError');
          throw Exception(
            'Failed to create user profile. Please ensure you are properly signed up and try again. Error: $profileError',
          );
        }
      } else {
        // Profile exists - update user_type to tutor if needed
        if (existingProfile['user_type'] != 'tutor') {
          try {
            await SupabaseService.client
                .from('profiles')
                .update({'user_type': 'tutor'})
                .eq('id', userId);
            LogService.success('Updated user_type to tutor for user: $userId');
          } catch (e) {
            LogService.warning('Error updating user_type: $e');
            // Continue anyway - not critical
          }
        }
      }

      // Check current status before saving (for upsert scenario)
      // CRITICAL: Also fetch admin_approved_rating and base_session_price to preserve them
      // Also fetch full current profile to compare changes for approved tutors
      final currentProfile = await SupabaseService.client
          .from('tutor_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      final currentStatus = currentProfile?['status'] as String?;
      final hasPendingUpdate = currentProfile?['has_pending_update'] as bool? ?? false;
      
      // Preserve admin fields for approved tutors (these should not be changed by tutor)
      final existingAdminRating = currentProfile?['admin_approved_rating'];
      final existingBasePrice = currentProfile?['base_session_price'];

      // Handle status changes based on current status:
      // - 'rejected' or 'needs_improvement' → 'pending' (initial submission or re-submission)
      // - 'approved' → KEEP 'approved' but set has_pending_update = TRUE (tutor stays visible)
      // - 'pending' → stays 'pending' (already pending)
      // IMPORTANT: Approved tutors remain visible with their current approved data
      // until admin approves the update. Changes are saved but marked as pending update.
      final wasApproved = currentStatus == 'approved';
      
      if (currentStatus == 'rejected' || currentStatus == 'needs_improvement') {
        // New submission or re-submission after rejection
        data['status'] = 'pending';
        data['has_pending_update'] = false; // Clear any pending update flag
        LogService.debug(
          '🔄 Status changed from $currentStatus to pending (new/re-submission)',
        );
      } else if (wasApproved) {
        // Approved tutor made changes - DON'T apply changes directly
        // Instead, store them in pending_changes for admin review
        // Keep current approved data visible until admin approves
        
        // Compare current vs new values to find what changed
        final pendingChanges = <String, dynamic>{};
        final currentProfileMap = currentProfile as Map<String, dynamic>? ?? {};
        
        LogService.info('🔍 Comparing current profile with new data for approved tutor...');
        LogService.debug('📊 Current profile keys: ${currentProfileMap.keys.toList()}');
        LogService.debug('📊 New data keys: ${data.keys.toList()}');
        
        // Find changed fields - check all fields in data, not just a predefined list
        // This ensures we catch all changes, even if field names don't match exactly
        data.forEach((key, newValue) {
          // Skip non-updatable fields (admin-only and system fields)
          if (key == 'id' || 
              key == 'user_id' || 
              key == 'status' || 
              key == 'has_pending_update' || 
              key == 'pending_changes' ||
              key == 'admin_approved_rating' ||
              key == 'base_session_price' ||
              key == 'created_at' ||
              key == 'updated_at' ||
              key == 'reviewed_by' ||
              key == 'reviewed_at' ||
              key == 'is_hidden' ||
              key == 'approval_banner_dismissed' ||
              key == 'admin_price_override' ||
              key == 'credential_multiplier' ||
              key == 'prepskul_certified' ||
              key == 'visibility_subscription_active' ||
              key == 'visibility_subscription_expires') {
            return; // Skip admin-only and system fields
          }
          
          // Skip null values (they don't represent changes)
          if (newValue == null) {
            return;
          }
          
          final currentValue = currentProfileMap[key];
          
          // CRITICAL: If current value is null and new value is null/empty, skip
          // This prevents empty values from being marked as changes
          if (currentValue == null && (newValue == null || newValue == '' || 
              (newValue is Map && newValue.isEmpty) || 
              (newValue is List && newValue.isEmpty))) {
            return;
          }
          
          // Compare values (handle different types)
          bool hasChanged = false;
          if (currentValue == null && newValue != null) {
            hasChanged = true;
            LogService.debug('📝 Field $key: null → $newValue (CHANGED)');
          } else if (currentValue != null && newValue == null) {
            // Only mark as changed if field was previously set (not just null)
            hasChanged = true;
            LogService.debug('📝 Field $key: $currentValue → null (CHANGED)');
          } else if (currentValue != null && newValue != null) {
            // Deep comparison for maps/lists using JSON serialization for accurate comparison
            if (currentValue is Map && newValue is Map) {
              // Convert both maps to JSON strings for reliable comparison
              // This handles key ordering and nested structures correctly
              try {
                final currentJson = jsonEncode(currentValue);
                final newJson = jsonEncode(newValue);
                hasChanged = currentJson != newJson;
                if (hasChanged) {
                  LogService.debug('📝 Field $key (Map): CHANGED');
                  LogService.debug('   Old: $currentJson');
                  LogService.debug('   New: $newJson');
                } else {
                  LogService.debug('✅ Field $key (Map): UNCHANGED (skipping)');
                }
              } catch (e) {
                // Fallback to string comparison if JSON encoding fails
                final currentStr = currentValue.toString();
                final newStr = newValue.toString();
                hasChanged = currentStr != newStr;
                if (hasChanged) {
                  LogService.debug('📝 Field $key (Map): CHANGED (using toString fallback)');
                  LogService.debug('   Old: $currentStr');
                  LogService.debug('   New: $newStr');
                } else {
                  LogService.debug('✅ Field $key (Map): UNCHANGED (skipping)');
                }
              }
            } else if (currentValue is List && newValue is List) {
              // Convert both lists to JSON strings for reliable comparison
              try {
                final currentJson = jsonEncode(currentValue);
                final newJson = jsonEncode(newValue);
                hasChanged = currentJson != newJson;
                if (hasChanged) {
                  LogService.debug('📝 Field $key (List): CHANGED');
                  LogService.debug('   Old: $currentJson');
                  LogService.debug('   New: $newJson');
                } else {
                  LogService.debug('✅ Field $key (List): UNCHANGED (skipping)');
                }
              } catch (e) {
                // Fallback to string comparison if JSON encoding fails
                final currentStr = currentValue.toString();
                final newStr = newValue.toString();
                hasChanged = currentStr != newStr;
                if (hasChanged) {
                  LogService.debug('📝 Field $key (List): CHANGED (using toString fallback)');
                  LogService.debug('   Old: $currentStr');
                  LogService.debug('   New: $newStr');
                } else {
                  LogService.debug('✅ Field $key (List): UNCHANGED (skipping)');
                }
              }
            } else {
              // For numeric values, normalize before comparison
              // This handles cases where values are stored as int vs double, or string vs number
              if ((currentValue is num || currentValue is String) && 
                  (newValue is num || newValue is String)) {
                // Convert both to double for accurate comparison
                final currentNum = currentValue is num 
                    ? currentValue.toDouble() 
                    : double.tryParse(currentValue.toString());
                final newNum = newValue is num 
                    ? newValue.toDouble() 
                    : double.tryParse(newValue.toString());
                
                if (currentNum != null && newNum != null) {
                  // Allow small floating point differences (0.01 tolerance)
                  hasChanged = (currentNum - newNum).abs() > 0.01;
                  if (hasChanged) {
                    LogService.debug('📝 Field $key (numeric): $currentNum → $newNum (CHANGED)');
                  } else {
                    LogService.debug('✅ Field $key (numeric): UNCHANGED (skipping) - values are equal');
                  }
                } else {
                  // Fallback to string comparison if parsing fails
                  final currentStr = currentValue.toString().trim();
                  final newStr = newValue.toString().trim();
                  hasChanged = currentStr != newStr;
                  if (hasChanged) {
                    LogService.debug('📝 Field $key: "$currentStr" → "$newStr" (CHANGED)');
                  } else {
                    LogService.debug('✅ Field $key: UNCHANGED (skipping) - values are equal');
                  }
                }
              } else {
                // For other types, use direct comparison
                hasChanged = currentValue != newValue;
                if (hasChanged) {
                  LogService.debug('📝 Field $key: $currentValue → $newValue (CHANGED)');
                } else {
                  LogService.debug('✅ Field $key: UNCHANGED (skipping) - values are equal');
                }
              }
            }
          }
          
          // Only add to pendingChanges if it actually changed
          if (hasChanged) {
            pendingChanges[key] = newValue;
            LogService.debug('✅ Added $key to pendingChanges');
          } else {
            LogService.debug('⏭️ Skipped $key (no change detected)');
          }
        });
        
        LogService.info('🔍 Comparison complete: Found ${pendingChanges.length} changed fields');
        if (pendingChanges.isNotEmpty) {
          LogService.info('📝 Changed fields: ${pendingChanges.keys.toList()}');
          // Log each changed field with its values for debugging
          pendingChanges.forEach((key, value) {
            final currentVal = currentProfileMap[key];
            LogService.debug('   - $key: $currentVal → $value');
          });
        } else {
          LogService.info('✅ No changes detected - all fields are identical');
        }
        
        // If there are changes, store them in pending_changes
        if (pendingChanges.isNotEmpty) {
          // CRITICAL: Convert Map to JSON-serializable format for Supabase JSONB
          // Supabase expects JSONB, so we need to ensure proper serialization
          final pendingChangesJson = <String, dynamic>{};
          pendingChanges.forEach((key, value) {
            // Ensure value is JSON-serializable
            if (value is Map) {
              pendingChangesJson[key] = Map<String, dynamic>.from(value);
            } else if (value is List) {
              pendingChangesJson[key] = List.from(value);
            } else {
              pendingChangesJson[key] = value;
            }
          });
          
          data['pending_changes'] = pendingChangesJson;
          data['has_pending_update'] = true;
          LogService.info('📝 Stored ${pendingChanges.length} pending changes for admin review: ${pendingChanges.keys.toList()}');
          LogService.debug('📝 Pending changes data: $pendingChangesJson');
          LogService.debug('📝 Pending changes JSON type check: ${pendingChangesJson.runtimeType}');
          
          // Send notification to tutor about pending update
          try {
            await SupabaseService.client.rpc('send_tutor_update_notification', params: {
              'tutor_user_id': userId,
            });
            LogService.success('✅ Sent notification to tutor about pending update');
          } catch (e) {
            // If RPC doesn't exist, create notification directly
            try {
              await SupabaseService.client.from('notifications').insert({
                'user_id': userId,
                'type': 'profile_update_pending',
                'title': 'Profile Update Submitted',
                'message': 'Your profile changes have been submitted for admin review. Your current profile remains active until approval.',
                'data': {'has_pending_update': true},
                'created_at': DateTime.now().toIso8601String(),
              });
              LogService.success('✅ Created notification for tutor about pending update');
            } catch (notifError) {
              LogService.warning('⚠️ Could not send notification: $notifError');
            }
          }
        } else {
          // No actual changes detected - but if has_pending_update was set, clear it
          LogService.warning('⚠️ No changes detected for approved tutor - clearing has_pending_update if it was set');
          if (hasPendingUpdate) {
            data['has_pending_update'] = false;
            data['pending_changes'] = null;
          }
        }
        
        // CRITICAL: Don't include status in update - we're already approved
        // Only update pending_changes and has_pending_update
        // This prevents the database trigger from firing (which checks for admin_approved_rating)
        // We're NOT changing status, just adding pending changes
        
        LogService.info(
          '📝 Approved tutor made profile changes - stored in pending_changes. Current profile remains unchanged until admin approval.',
        );
      } else if (currentStatus == 'pending') {
        // Already pending - keep as is
        data['status'] = 'pending';
        data['has_pending_update'] = false; // Clear pending update if it was set
      }

      // Always update the updated_at timestamp
      data['updated_at'] = DateTime.now().toIso8601String();

      // Filter out null values and empty lists to avoid unnecessary updates
      // Also remove fields that might not exist in the database schema yet
      // CRITICAL: Set both id and user_id to userId because:
      // - tutor_profiles.id is a PRIMARY KEY that REFERENCES profiles(id)
      // - tutor_profiles.user_id also REFERENCES profiles(id)
      // - When inserting, id must equal a valid profiles.id (which is userId)
      final filteredData = <String, dynamic>{
        'id': userId, // Must match profiles.id (foreign key constraint)
        'user_id': userId, // Also set user_id for consistency
      };

      // CRITICAL: Always include has_pending_update if it was set
      // For approved tutors with pending changes, DON'T include status to avoid trigger error
      if (data.containsKey('has_pending_update')) {
        filteredData['has_pending_update'] = data['has_pending_update'];
        LogService.debug('✅ Explicitly including has_pending_update: ${data['has_pending_update']}');
      }
      
      // Only include status if we're NOT already approved (to avoid trigger error)
      // If we're approved and have pending changes, we don't need to update status
      if (data.containsKey('status') && !wasApproved) {
        filteredData['status'] = data['status'];
        LogService.debug('✅ Explicitly including status: ${data['status']}');
      } else if (wasApproved && data.containsKey('pending_changes')) {
        // For approved tutors with pending changes, explicitly preserve admin fields
        // Don't include status - we're already approved
        if (existingAdminRating != null) {
          filteredData['admin_approved_rating'] = existingAdminRating;
          LogService.debug('✅ Preserving admin_approved_rating in filteredData: $existingAdminRating');
        }
        if (existingBasePrice != null) {
          filteredData['base_session_price'] = existingBasePrice;
          LogService.debug('✅ Preserving base_session_price in filteredData: $existingBasePrice');
        }
      }
      
      // CRITICAL: Always include pending_changes if it exists (for approved tutors)
      // This MUST be included in filteredData for it to be saved to the database
      if (data.containsKey('pending_changes') && data['pending_changes'] != null) {
        final pendingChangesValue = data['pending_changes'];
        if (pendingChangesValue is Map && pendingChangesValue.isNotEmpty) {
          // Ensure it's a proper Map<String, dynamic> for JSONB serialization
          final pendingChangesMap = Map<String, dynamic>.from(pendingChangesValue);
          filteredData['pending_changes'] = pendingChangesMap;
          LogService.info('✅ Including pending_changes in filteredData: ${pendingChangesMap.length} fields');
          LogService.debug('✅ Pending changes keys: ${pendingChangesMap.keys.toList()}');
          LogService.debug('✅ Pending changes sample: ${pendingChangesMap.entries.take(2).map((e) => '${e.key}: ${e.value}').join(', ')}');
          LogService.debug('✅ filteredData now contains pending_changes: ${filteredData.containsKey('pending_changes')}');
        } else {
          LogService.warning('⚠️ pending_changes exists but is empty or invalid: $pendingChangesValue (type: ${pendingChangesValue.runtimeType})');
        }
      } else {
        LogService.debug('ℹ️ No pending_changes in data for user: $userId');
        // If has_pending_update is true but pending_changes is missing, log a warning
        if (data.containsKey('has_pending_update') && data['has_pending_update'] == true) {
          LogService.error('❌ CRITICAL: has_pending_update is TRUE but pending_changes is missing! This should not happen.');
        }
      }
      
      // For approved tutors with pending changes, DON'T update the actual profile fields
      // Only store pending_changes - admin will approve/reject later
      if (wasApproved && data.containsKey('pending_changes') && data['pending_changes'] != null) {
        final pendingChangesMap = data['pending_changes'] as Map<String, dynamic>;
        LogService.info('📝 Approved tutor with ${pendingChangesMap.length} pending changes - NOT updating profile fields, only storing pending_changes');
        // Skip adding other updatable fields - they should remain unchanged until admin approval
      } else {
        // For non-approved tutors or approved tutors without pending changes, include all fields
        data.forEach((key, value) {
        // Skip null values
        if (value == null) return;
        // Skip empty lists (but keep non-empty lists and availability maps)
        if (value is List && value.isEmpty && key != 'certificates_urls') {
          return;
        }
        // IMPORTANT: Always include availability fields even if they're empty maps
        // This ensures availability updates are saved for approved tutors
        if (key == 'tutoring_availability' || 
            key == 'test_session_availability' || 
            key == 'availability_schedule' ||
            key == 'availability') {
          // Always include availability fields, even if empty (allows clearing availability)
          filteredData[key] = value;
          return;
        }
        // Skip 'id' field if it's already set (we set it above)
        if (key == 'id') return;
        // Skip 'has_pending_update', 'status', and 'pending_changes' if already set above
        if (key == 'has_pending_update' || key == 'status' || key == 'pending_changes') return;
        // Include all other values
        filteredData[key] = value;
        });
      }

      // Save to tutor_profiles table
      // Retry logic: if a column doesn't exist, remove it and try again
      // Continue until success or no more columns can be removed
      int maxRetries = 50; // Increased to handle many missing columns
      int retryCount = 0;
      Set<String> removedColumns = {};
      bool success = false;

      while (retryCount < maxRetries && !success) {
        try {
          // Use upsert with onConflict on 'id' since that's the primary key
          // Both 'id' and 'user_id' should be set to userId
          await SupabaseService.client
              .from('tutor_profiles')
              .upsert(filteredData, onConflict: 'id');
          // Success! Break out of retry loop
          success = true;
          
          // Log critical fields for debugging
          LogService.info('📦 filteredData keys being saved: ${filteredData.keys.toList()}');
          if (filteredData.containsKey('has_pending_update')) {
            LogService.info(
              '✅ has_pending_update saved: ${filteredData['has_pending_update']}',
            );
          } else {
            LogService.warning('⚠️ has_pending_update NOT in filteredData!');
          }
          if (filteredData.containsKey('pending_changes')) {
            final pendingChanges = filteredData['pending_changes'] as Map?;
            LogService.info(
              '✅ pending_changes saved: ${pendingChanges?.length ?? 0} fields',
            );
            if (pendingChanges != null && pendingChanges.isNotEmpty) {
              LogService.debug('✅ Pending changes fields: ${pendingChanges.keys.toList()}');
            } else {
              LogService.error('❌ pending_changes is in filteredData but is null or empty!');
            }
          } else {
            LogService.error('❌ pending_changes NOT in filteredData!');
          }
          
          // CRITICAL: Verify the save by fetching back from database
          try {
            final verifyResult = await SupabaseService.client
                .from('tutor_profiles')
                .select('has_pending_update, pending_changes')
                .eq('id', userId)
                .maybeSingle();
            
            if (verifyResult != null) {
              final savedHasPendingUpdate = verifyResult['has_pending_update'] as bool? ?? false;
              final savedPendingChanges = verifyResult['pending_changes'];
              LogService.info('🔍 Verification after save:');
              LogService.info('   has_pending_update: $savedHasPendingUpdate');
              LogService.info('   pending_changes type: ${savedPendingChanges.runtimeType}');
              if (savedPendingChanges is Map) {
                LogService.info('   pending_changes fields: ${savedPendingChanges.length}');
                LogService.info('   pending_changes keys: ${savedPendingChanges.keys.toList()}');
              } else {
                LogService.error('   ❌ pending_changes is NOT a Map! Value: $savedPendingChanges');
              }
            }
          } catch (verifyError) {
            LogService.warning('⚠️ Could not verify save: $verifyError');
          }
          
          // Log availability update specifically for debugging
          if (filteredData.containsKey('availability_schedule') || 
              filteredData.containsKey('tutoring_availability')) {
            final availSchedule = filteredData['availability_schedule'];
            final tutoringAvail = filteredData['tutoring_availability'];
            LogService.info(
              '✅ Availability updated - availability_schedule: ${availSchedule != null ? '${(availSchedule as Map).length} days' : 'null'}, '
              'tutoring_availability: ${tutoringAvail != null ? '${(tutoringAvail as Map).length} days' : 'null'}',
            );
          }
          
          if (removedColumns.isNotEmpty) {
            LogService.debug(
              '⚠️ Successfully saved after removing ${removedColumns.length} missing columns: ${removedColumns.join(", ")}',
            );
          } else {
            LogService.success('✅ Successfully saved tutor profile (including availability updates)');
          }
          break;
        } catch (e) {
          // Check if error is about foreign key constraint violation
          final errorStr = e.toString();

          // Check for foreign key constraint violation (error code 23503)
          if (errorStr.contains('23503') ||
              errorStr.contains('foreign key constraint') ||
              errorStr.contains('Key is not present in table "profiles"')) {
            LogService.debug(
              '❌ Foreign key constraint violation: Profile does not exist for user $userId',
            );
            throw Exception(
              'User profile not found. Please ensure you are properly signed up. If this error persists, please contact support.',
            );
          }

          // Check if error is about missing column
          if (errorStr.contains('PGRST204') ||
              (errorStr.contains('column') &&
                  errorStr.contains('does not exist'))) {
            // Extract column name from error message
            // Error format: "Could not find the 'column_name' column of 'tutor_profiles'"
            String? missingColumn;

            // Try pattern: "Could not find the 'column_name'"
            final findMatch = RegExp(
              r"find the '([^']+)'",
            ).firstMatch(errorStr);
            if (findMatch != null) {
              missingColumn = findMatch.group(1);
            } else {
              // Try pattern: "'column_name' column"
              final columnMatch = RegExp(
                r"'([^']+)' column",
              ).firstMatch(errorStr);
              if (columnMatch != null) {
                missingColumn = columnMatch.group(1);
              }
            }

            if (missingColumn != null &&
                filteredData.containsKey(missingColumn)) {
              removedColumns.add(missingColumn);
              filteredData.remove(missingColumn);
              LogService.debug(
                '⚠️ Removed missing column "$missingColumn" from update (column may not exist yet). Retry ${retryCount + 1}/$maxRetries',
              );
              retryCount++;
              continue; // Retry with the problematic column removed
            } else {
              // Couldn't extract column name or column already removed
              LogService.error('Column error but could not identify column: $errorStr');
              rethrow;
            }
          } else {
            // Different type of error, don't retry
            rethrow;
          }
        }
      }

      // If we exhausted retries, throw an error
      if (!success) {
        throw Exception(
          'Failed to save after $retryCount retries. Removed ${removedColumns.length} columns: ${removedColumns.join(", ")}. Please run migration 018 to add missing columns.',
        );
      }

      // Update profiles table with contact info and mark survey as completed
      // Only update if profile exists (it should after our check above)
      try {
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

        LogService.success('Updated profile with survey completion status');
      } catch (profileUpdateError) {
        LogService.warning('Error updating profile (non-critical): $profileUpdateError');
        // Don't throw - profile update is not critical for tutor profile save
      }

      // Mark onboarding as complete in progress tracking
      try {
        await TutorOnboardingProgressService.markOnboardingComplete(userId);
        LogService.success('Onboarding marked as complete');
      } catch (progressError) {
        LogService.warning('Error marking onboarding complete (non-critical): $progressError');
        // Don't throw - this is not critical for survey save
      }

      LogService.success('Tutor survey saved successfully');
    } catch (e) {
      LogService.error('Error saving tutor survey: $e');
      rethrow;
    }
  }

  /// Get tutor survey data
  static Future<Map<String, dynamic>?> getTutorSurvey(String userId) async {
    try {
      LogService.debug('Fetching tutor survey for user: $userId');

      // Fetch tutor profile
      final tutorResponse = await SupabaseService.client
          .from('tutor_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (tutorResponse == null) {
        return null;
      }

      // Fetch email and phone from profiles table
      try {
        final profileResponse = await SupabaseService.client
            .from('profiles')
            .select('email, phone_number')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse != null) {
          // Merge profile data into tutor data
          tutorResponse['email'] = profileResponse['email'];
          tutorResponse['phone_number'] = profileResponse['phone_number'];
        }
      } catch (e) {
        LogService.warning('Error fetching profile data: $e');
        // Continue without profile data
      }

      LogService.success('Tutor survey fetched successfully');
      return tutorResponse;
    } catch (e) {
      LogService.error('Error fetching tutor survey: $e');
      return null;
    }
  }

  /// Update tutor survey data
  static Future<void> updateTutorSurvey(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      LogService.info('Updating tutor survey for user: $userId');

      // Check current status before updating
      final currentProfile = await SupabaseService.client
          .from('tutor_profiles')
          .select('status, has_pending_update')
          .eq('user_id', userId)
          .maybeSingle();

      final currentStatus = currentProfile?['status'] as String?;
      final hasPendingUpdate = currentProfile?['has_pending_update'] as bool? ?? false;

      // Handle status changes based on current status:
      // - 'rejected' or 'needs_improvement' → 'pending' (re-submission after feedback)
      // - 'approved' → KEEP 'approved' but set has_pending_update = TRUE (tutor stays visible)
      // - 'pending' → stays 'pending' (already pending)
      if (currentStatus == 'rejected' || currentStatus == 'needs_improvement') {
        updates['status'] = 'pending';
        updates['has_pending_update'] = false; // Clear any pending update flag
        LogService.debug(
          '🔄 Status changed from $currentStatus to pending (re-submission)',
        );
      } else if (currentStatus == 'approved') {
        // Approved tutor made changes - keep status as 'approved' but mark as pending update
        updates['status'] = 'approved'; // Keep approved status
        updates['has_pending_update'] = true; // Mark as having pending update
        LogService.info(
          '📝 Approved tutor updated profile - status remains approved, has_pending_update set to TRUE. Tutor stays visible until admin approves update.',
        );
      } else if (currentStatus == 'pending') {
        // Already pending - keep as is
        updates['status'] = 'pending';
        updates['has_pending_update'] = false; // Clear pending update if it was set
      }

      // Always update the updated_at timestamp
      updates['updated_at'] = DateTime.now().toIso8601String();

      await SupabaseService.client
          .from('tutor_profiles')
          .update(updates)
          .eq('user_id', userId);

      LogService.success('Tutor survey updated successfully');
    } catch (e) {
      LogService.error('Error updating tutor survey: $e');
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
      LogService.info('Saving student survey for user: $userId');

      // CRITICAL: Ensure profile exists before saving to learner_profiles
      // This prevents foreign key constraint violations
      Map<String, dynamic>? existingProfile;
      try {
        existingProfile = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        LogService.warning('Error checking profile existence: $e');
        // If query fails, try to create profile anyway
        existingProfile = null;
      }

      if (existingProfile == null) {
        // Profile doesn't exist - create it first
        LogService.warning('Profile not found for user $userId, creating profile...');
        final user = SupabaseService.client.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated. Cannot create profile.');
        }

        try {
          // Get stored signup data if available
          final prefs = await SharedPreferences.getInstance();
          final storedName = prefs.getString('signup_full_name');

          // Determine the best name to use (priority: storedName > metadata > email extraction > empty string)
          String? nameToUse;
          if (storedName != null &&
              storedName.isNotEmpty &&
              storedName != 'User' &&
              storedName != 'Student') {
            nameToUse = storedName;
          } else if (user.userMetadata?['full_name'] != null) {
            final metadataName =
                user.userMetadata!['full_name']?.toString() ?? '';
            if (metadataName.isNotEmpty &&
                metadataName != 'User' &&
                metadataName != 'Student') {
              nameToUse = metadataName;
            }
          } else if (user.email != null) {
            // Extract name from email as last resort
            final emailName = user.email!.split('@')[0];
            if (emailName.isNotEmpty &&
                emailName != 'user' &&
                emailName != 'student') {
              nameToUse = emailName
                  .split('.')
                  .map(
                    (s) =>
                        s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '',
                  )
                  .where((s) => s.isNotEmpty)
                  .join(' ');
            }
          }

          await SupabaseService.client.from('profiles').upsert({
            'id': userId,
            'email': user.email ?? '',
            'full_name':
                nameToUse ?? '', // Use empty string instead of 'Student'
            'phone_number': user.phone,
            'user_type': 'student',
            'survey_completed': false,
            'is_admin': false,
          }, onConflict: 'id');

          LogService.success('Profile created for user: $userId');
        } catch (profileError) {
          LogService.warning('Error creating profile: $profileError');
          // If profile creation fails, continue anyway - might already exist
          // or will be handled by database constraints
        }
      }

      // Check if learner profile already exists
      final existingLearnerProfile = await SupabaseService.client
          .from('learner_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      // Filter out null values and handle missing columns
      final filteredData = <String, dynamic>{
        'user_id': userId, // Always set user_id
      };

      data.forEach((key, value) {
        // Skip null values
        if (value == null) return;
        // Skip empty lists (but keep non-empty lists)
        if (value is List &&
            value.isEmpty &&
            key != 'subjects' &&
            key != 'learning_goals' &&
            key != 'learning_styles') {
          return;
        }
        // Include all other values
        filteredData[key] = value;
      });

      // Save to learner_profiles table with retry logic for missing columns
      int maxRetries = 50;
      int retryCount = 0;
      Set<String> removedColumns = {};
      bool success = false;

      while (retryCount < maxRetries && !success) {
        try {
          if (existingLearnerProfile != null) {
            // Update existing record
            await SupabaseService.client
                .from('learner_profiles')
                .update(filteredData)
                .eq('user_id', userId);
          } else {
            // Insert new record (also set id to userId if it's the primary key)
            await SupabaseService.client.from('learner_profiles').insert({
              'id': userId, // Set id to userId if it's the FK
              ...filteredData,
            });
          }
          success = true;
          if (removedColumns.isNotEmpty) {
            LogService.debug(
              '⚠️ Successfully saved after removing ${removedColumns.length} missing columns: ${removedColumns.join(", ")}',
            );
          } else {
            LogService.success('Successfully saved learner profile');
          }
          break;
        } catch (e) {
          final errorStr = e.toString();

          // Check for duplicate key error - means record exists, try update instead
          if (errorStr.contains('23505') ||
              errorStr.contains('duplicate key')) {
            LogService.debug(
              '⚠️ Duplicate key detected, switching to update instead of insert',
            );
            try {
              await SupabaseService.client
                  .from('learner_profiles')
                  .update(filteredData)
                  .eq('user_id', userId);
              success = true;
              LogService.success('Successfully updated learner profile');
              break;
            } catch (updateError) {
              // If update also fails, continue with retry logic
              LogService.debug(
                '⚠️ Update also failed, continuing with retry: $updateError',
              );
            }
          }

          // Check if error is about missing column
          if (errorStr.contains('PGRST204') ||
              (errorStr.contains('column') &&
                  errorStr.contains('does not exist'))) {
            String? missingColumn;

            final findMatch = RegExp(
              r"find the '([^']+)'",
            ).firstMatch(errorStr);
            if (findMatch != null) {
              missingColumn = findMatch.group(1);
            } else {
              final columnMatch = RegExp(
                r"'([^']+)' column",
              ).firstMatch(errorStr);
              if (columnMatch != null) {
                missingColumn = columnMatch.group(1);
              }
            }

            if (missingColumn != null &&
                filteredData.containsKey(missingColumn)) {
              removedColumns.add(missingColumn);
              filteredData.remove(missingColumn);
              LogService.debug(
                '⚠️ Removed missing column "$missingColumn" from update (column may not exist yet). Retry ${retryCount + 1}/$maxRetries',
              );
              retryCount++;
              continue;
            } else {
              LogService.error('Column error but could not identify column: $errorStr');
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      }

      if (!success) {
        throw Exception(
          'Failed to save after $retryCount retries. Removed ${removedColumns.length} columns: ${removedColumns.join(", ")}. Please ensure all required migrations are applied.',
        );
      }

      // Mark survey as completed
      await SupabaseService.client
          .from('profiles')
          .update({'survey_completed': true})
          .eq('id', userId);

      LogService.success('Student survey saved successfully');
    } catch (e) {
      LogService.error('Error saving student survey: $e');
      rethrow;
    }
  }

  /// Get student survey data
  static Future<Map<String, dynamic>?> getStudentSurvey(String userId) async {
    try {
      LogService.debug('Fetching student survey for user: $userId');

      final response = await SupabaseService.client
          .from('learner_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      LogService.success('Student survey fetched: ${response != null}');
      return response;
    } catch (e) {
      LogService.error('Error fetching student survey: $e');
      return null;
    }
  }

  /// Update student survey data
  static Future<void> updateStudentSurvey(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      LogService.info('Updating student survey for user: $userId');

      await SupabaseService.client
          .from('learner_profiles')
          .update(updates)
          .eq('user_id', userId);

      LogService.success('Student survey updated successfully');
    } catch (e) {
      LogService.error('Error updating student survey: $e');
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
      LogService.info('Saving parent survey for user: $userId');

      // CRITICAL: Ensure profile exists before saving to parent_profiles
      // This prevents foreign key constraint violations
      Map<String, dynamic>? existingProfile;
      try {
        existingProfile = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        LogService.warning('Error checking profile existence: $e');
        // If query fails, try to create profile anyway
        existingProfile = null;
      }

      if (existingProfile == null) {
        // Profile doesn't exist - create it first
        LogService.warning('Profile not found for user $userId, creating profile...');
        final user = SupabaseService.client.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated. Cannot create profile.');
        }

        try {
          await SupabaseService.client.from('profiles').upsert({
            'id': userId,
            'email': user.email ?? '',
            'full_name': user.userMetadata?['full_name'] ?? 'Parent',
            'phone_number': user.phone,
            'user_type': 'parent',
            'survey_completed': false,
            'is_admin': false,
          }, onConflict: 'id');

          LogService.success('Profile created for user: $userId');
        } catch (profileError) {
          LogService.warning('Error creating profile: $profileError');
          // If profile creation fails, continue anyway - might already exist
          // or will be handled by database constraints
        }
      }

      // Check if parent profile already exists
      final existingParentProfile = await SupabaseService.client
          .from('parent_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      // Filter out null values and handle missing columns
      final filteredData = <String, dynamic>{
        'user_id': userId, // Always set user_id
      };

      data.forEach((key, value) {
        // Skip null values
        if (value == null) return;
        // Skip empty lists (but keep non-empty lists)
        if (value is List &&
            value.isEmpty &&
            key != 'subjects' &&
            key != 'learning_goals') {
          return;
        }
        // Include all other values
        filteredData[key] = value;
      });

      // Save to parent_profiles table with retry logic for missing columns
      int maxRetries = 50;
      int retryCount = 0;
      Set<String> removedColumns = {};
      bool success = false;

      while (retryCount < maxRetries && !success) {
        try {
          if (existingParentProfile != null) {
            // Update existing record
            await SupabaseService.client
                .from('parent_profiles')
                .update(filteredData)
                .eq('user_id', userId);
          } else {
            // Insert new record (also set id to userId if it's the primary key)
            await SupabaseService.client.from('parent_profiles').insert({
              'id': userId, // Set id to userId if it's the FK
              ...filteredData,
            });
          }
          success = true;
          if (removedColumns.isNotEmpty) {
            LogService.debug(
              '⚠️ Successfully saved after removing ${removedColumns.length} missing columns: ${removedColumns.join(", ")}',
            );
          } else {
            LogService.success('Successfully saved parent profile');
          }
          break;
        } catch (e) {
          final errorStr = e.toString();

          // Check for duplicate key error - means record exists, try update instead
          if (errorStr.contains('23505') ||
              errorStr.contains('duplicate key')) {
            LogService.debug(
              '⚠️ Duplicate key detected, switching to update instead of insert',
            );
            try {
              await SupabaseService.client
                  .from('parent_profiles')
                  .update(filteredData)
                  .eq('user_id', userId);
              success = true;
              LogService.success('Successfully updated parent profile');
              break;
            } catch (updateError) {
              // If update also fails, continue with retry logic
              LogService.debug(
                '⚠️ Update also failed, continuing with retry: $updateError',
              );
            }
          }

          // Check if error is about missing column
          if (errorStr.contains('PGRST204') ||
              (errorStr.contains('column') &&
                  errorStr.contains('does not exist'))) {
            String? missingColumn;

            final findMatch = RegExp(
              r"find the '([^']+)'",
            ).firstMatch(errorStr);
            if (findMatch != null) {
              missingColumn = findMatch.group(1);
            } else {
              final columnMatch = RegExp(
                r"'([^']+)' column",
              ).firstMatch(errorStr);
              if (columnMatch != null) {
                missingColumn = columnMatch.group(1);
              }
            }

            if (missingColumn != null &&
                filteredData.containsKey(missingColumn)) {
              removedColumns.add(missingColumn);
              filteredData.remove(missingColumn);
              LogService.debug(
                '⚠️ Removed missing column "$missingColumn" from update (column may not exist yet). Retry ${retryCount + 1}/$maxRetries',
              );
              retryCount++;
              continue;
            } else {
              LogService.error('Column error but could not identify column: $errorStr');
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      }

      if (!success) {
        throw Exception(
          'Failed to save after $retryCount retries. Removed ${removedColumns.length} columns: ${removedColumns.join(", ")}. Please ensure all required migrations are applied.',
        );
      }

      // Mark survey as completed
      await SupabaseService.client
          .from('profiles')
          .update({'survey_completed': true})
          .eq('id', userId);

      LogService.success('Parent survey saved successfully');
    } catch (e) {
      LogService.error('Error saving parent survey: $e');
      rethrow;
    }
  }

  /// Get parent survey data
  static Future<Map<String, dynamic>?> getParentSurvey(String userId) async {
    try {
      LogService.debug('Fetching parent survey for user: $userId');

      final response = await SupabaseService.client
          .from('parent_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      LogService.success('Parent survey fetched: ${response != null}');
      return response;
    } catch (e) {
      LogService.error('Error fetching parent survey: $e');
      return null;
    }
  }

  /// Update parent survey data
  static Future<void> updateParentSurvey(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      LogService.info('Updating parent survey for user: $userId');

      await SupabaseService.client
          .from('parent_profiles')
          .update(updates)
          .eq('user_id', userId);

      LogService.success('Parent survey updated successfully');
    } catch (e) {
      LogService.error('Error updating parent survey: $e');
      rethrow;
    }
  }
}
