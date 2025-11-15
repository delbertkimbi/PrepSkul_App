import 'package:prepskul/core/services/supabase_service.dart';
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
      print('📝 Saving tutor survey for user: $userId');

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
        print('⚠️ Error checking profile existence: $e');
        existingProfile = null;
      }

      if (existingProfile == null) {
        // Profile doesn't exist - create it first
        print('⚠️ Profile not found for user $userId, creating profile...');
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

          print('✅ Profile created for user: $userId');
        } catch (profileError) {
          print('❌ Error creating profile: $profileError');
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
            print('✅ Updated user_type to tutor for user: $userId');
          } catch (e) {
            print('⚠️ Error updating user_type: $e');
            // Continue anyway - not critical
          }
        }
      }

      // Check current status before saving (for upsert scenario)
      final currentProfile = await SupabaseService.client
          .from('tutor_profiles')
          .select('status')
          .eq('user_id', userId)
          .maybeSingle();

      final currentStatus = currentProfile?['status'] as String?;

      // If status is 'rejected' or 'needs_improvement', set to 'pending' when tutor updates
      if (currentStatus == 'rejected' || currentStatus == 'needs_improvement') {
        data['status'] = 'pending';
        print(
          '🔄 Status changed from $currentStatus to pending due to profile update',
        );
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

      data.forEach((key, value) {
        // Skip null values
        if (value == null) return;
        // Skip empty lists (but keep non-empty lists)
        if (value is List && value.isEmpty && key != 'certificates_urls') {
          return;
        }
        // Skip 'id' field if it's already set (we set it above)
        if (key == 'id') return;
        // Include all other values
        filteredData[key] = value;
      });

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
          if (removedColumns.isNotEmpty) {
            print(
              '⚠️ Successfully saved after removing ${removedColumns.length} missing columns: ${removedColumns.join(", ")}',
            );
          } else {
            print('✅ Successfully saved tutor profile');
          }
          break;
        } catch (e) {
          // Check if error is about foreign key constraint violation
          final errorStr = e.toString();

          // Check for foreign key constraint violation (error code 23503)
          if (errorStr.contains('23503') ||
              errorStr.contains('foreign key constraint') ||
              errorStr.contains('Key is not present in table "profiles"')) {
            print(
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
              print(
                '⚠️ Removed missing column "$missingColumn" from update (column may not exist yet). Retry ${retryCount + 1}/$maxRetries',
              );
              retryCount++;
              continue; // Retry with the problematic column removed
            } else {
              // Couldn't extract column name or column already removed
              print('❌ Column error but could not identify column: $errorStr');
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

        print('✅ Updated profile with survey completion status');
      } catch (profileUpdateError) {
        print('⚠️ Error updating profile (non-critical): $profileUpdateError');
        // Don't throw - profile update is not critical for tutor profile save
      }

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
        print('⚠️ Error fetching profile data: $e');
        // Continue without profile data
      }

      print('✅ Tutor survey fetched successfully');
      return tutorResponse;
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

      // Check current status before updating
      final currentProfile = await SupabaseService.client
          .from('tutor_profiles')
          .select('status')
          .eq('user_id', userId)
          .maybeSingle();

      final currentStatus = currentProfile?['status'] as String?;

      // If status is 'rejected' or 'needs_improvement', set to 'pending' when tutor updates
      if (currentStatus == 'rejected' || currentStatus == 'needs_improvement') {
        updates['status'] = 'pending';
        print(
          '🔄 Status changed from $currentStatus to pending due to profile update',
        );
      }

      // Always update the updated_at timestamp
      updates['updated_at'] = DateTime.now().toIso8601String();

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
      Map<String, dynamic>? existingProfile;
      try {
        existingProfile = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        print('⚠️ Error checking profile existence: $e');
        // If query fails, try to create profile anyway
        existingProfile = null;
      }

      if (existingProfile == null) {
        // Profile doesn't exist - create it first
        print('⚠️ Profile not found for user $userId, creating profile...');
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
          if (storedName != null && storedName.isNotEmpty && 
              storedName != 'User' && storedName != 'Student') {
            nameToUse = storedName;
          } else if (user.userMetadata?['full_name'] != null) {
            final metadataName = user.userMetadata!['full_name']?.toString() ?? '';
            if (metadataName.isNotEmpty && 
                metadataName != 'User' && metadataName != 'Student') {
              nameToUse = metadataName;
            }
          } else if (user.email != null) {
            // Extract name from email as last resort
            final emailName = user.email!.split('@')[0];
            if (emailName.isNotEmpty && emailName != 'user' && emailName != 'student') {
              nameToUse = emailName.split('.').map((s) => 
                s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : ''
              ).where((s) => s.isNotEmpty).join(' ');
            }
          }
          
          await SupabaseService.client.from('profiles').upsert({
            'id': userId,
            'email': user.email ?? '',
            'full_name': nameToUse ?? '', // Use empty string instead of 'Student'
            'phone_number': user.phone,
            'user_type': 'student',
            'survey_completed': false,
            'is_admin': false,
          }, onConflict: 'id');

          print('✅ Profile created for user: $userId');
        } catch (profileError) {
          print('⚠️ Error creating profile: $profileError');
          // If profile creation fails, continue anyway - might already exist
          // or will be handled by database constraints
        }
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
      Map<String, dynamic>? existingProfile;
      try {
        existingProfile = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        print('⚠️ Error checking profile existence: $e');
        // If query fails, try to create profile anyway
        existingProfile = null;
      }

      if (existingProfile == null) {
        // Profile doesn't exist - create it first
        print('⚠️ Profile not found for user $userId, creating profile...');
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

          print('✅ Profile created for user: $userId');
        } catch (profileError) {
          print('⚠️ Error creating profile: $profileError');
          // If profile creation fails, continue anyway - might already exist
          // or will be handled by database constraints
        }
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
