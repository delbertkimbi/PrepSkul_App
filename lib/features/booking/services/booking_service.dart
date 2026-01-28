import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:prepskul/features/booking/services/recurring_session_service.dart';
import 'package:prepskul/features/booking/services/availability_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';
import 'package:prepskul/features/messaging/services/conversation_lifecycle_service.dart';

class BookingService {
  /// Create a booking request in the database
  static Future<void> createBookingRequest({
    required String tutorId,
    required int frequency,
    required List<String> days,
    required Map<String, String> times,
    required String location,
    String? address,
    String? locationDescription,
    required String paymentPlan,
    required double monthlyTotal,
    String? customRequestId, // Link to original custom tutor request
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile for denormalized data
      final userProfile = await SupabaseService.client
          .from('profiles')
          .select('full_name, user_type, avatar_url, email, phone_number')
          .eq('id', userId)
          .maybeSingle();
      
      if (userProfile == null) {
        throw Exception('User profile not found: $userId');
      }

      // SECURITY CHECK: Verify profile completeness before booking
      final fullName = userProfile['full_name'] as String?;
      final email = userProfile['email'] as String?;
      if (fullName == null || fullName.trim().isEmpty) {
        throw Exception('Please complete your profile (name is required) before booking a tutor.');
      }
      if (email == null || email.trim().isEmpty) {
        throw Exception('Please complete your profile (email is required) before booking a tutor.');
      }

      // Get tutor profile for denormalized data
      final tutorProfile = await SupabaseService.client
          .from('tutor_profiles')
          .select('user_id, admin_approved_rating, base_session_price, profile_photo_url, status')
          .eq('user_id', tutorId)
          .maybeSingle();

      // SECURITY CHECK: Verify tutor is approved and available
      if (tutorProfile == null) {
        throw Exception('Tutor profile not found. This tutor may no longer be available.');
      }
      
      final tutorStatus = tutorProfile['status'] as String?;
      if (tutorStatus != 'approved') {
        throw Exception('This tutor is not currently available for booking. Status: ${tutorStatus ?? "unknown"}');
      }

      final tutorUserId = tutorProfile['user_id'] as String? ?? tutorId;

      final tutorProfileData = await SupabaseService.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', tutorUserId)
          .maybeSingle();

      // Map user_type to student_type for booking_requests constraint
      // Constraint expects: ('learner', 'parent')
      // user_type can be: ('learner', 'student', 'tutor', 'parent')
      final rawUserType = userProfile['user_type'] as String?;
      
      // Handle null or empty user_type
      if (rawUserType == null || rawUserType.toString().trim().isEmpty) {
        LogService.error('CRITICAL: user_type is null or empty for user $userId. Profile: $userProfile');
        throw Exception('Your account type is not set. Please contact support or try logging out and back in.');
      }
      
      final userType = rawUserType.toString().toLowerCase().trim();

      // Determine student_type with explicit validation
      String studentType;
      if (userType == 'learner' || userType == 'student') {
        studentType = 'learner';
      } else if (userType == 'parent') {
        studentType = 'parent';
      } else if (userType == 'tutor') {
        // Tutors cannot create booking requests
        throw Exception('Tutors cannot create booking requests. Please use a student or parent account.');
      } else {
        // Log unexpected value and throw error
        LogService.error('CRITICAL: Unexpected user_type: "$rawUserType" (normalized: "$userType") for user $userId');
        throw Exception('Invalid account type. Please contact support. Your account type: "$rawUserType"');
      }

      // Final validation - ensure it's one of the allowed values (should never fail at this point)
      if (studentType != 'learner' && studentType != 'parent') {
        LogService.error('CRITICAL: Invalid student_type after mapping: "$studentType" for user $userId');
        throw Exception('System error: Invalid account type mapping. Please contact support.');
      }

      LogService.debug('Booking request', 'user_type: "$rawUserType" → student_type: "$studentType"');

      // SECURITY CHECK: Rate limiting - prevent spam bookings
      // Check for recent booking requests (within last 5 minutes)
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
      final recentRequestsQuery = SupabaseService.client
          .from('booking_requests')
          .select('id, created_at')
          .eq('student_id', userId)
          .gte('created_at', fiveMinutesAgo)
          .order('created_at', ascending: false);
      
      final recentRequests = await recentRequestsQuery;
      if (recentRequests.length >= 5) {
        throw Exception('Too many booking requests. Please wait a few minutes before creating another request.');
      }

      // Check for duplicate approved bookings (tutor accepted twice)
      final approvedBookingsQuery = SupabaseService.client
          .from('booking_requests')
          .select('id')
          .eq('student_id', userId)
          .eq('tutor_id', tutorUserId)
          .eq('status', 'approved');
      
      final approvedBookings = await approvedBookingsQuery;
      
      if (approvedBookings.length >= 2) {
        throw Exception('TRIAL_SESSION_BLOCK:trialId=null:You cannot book this tutor again. You already have multiple approved bookings with this tutor.');
      }

      // Check for existing pending/active booking requests with this tutor
      final existingRequestsQuery = SupabaseService.client
          .from('booking_requests')
          .select('id, status, created_at, tutor_name')
          .eq('student_id', userId)
          .eq('tutor_id', tutorUserId)
          .or('status.eq.pending,status.eq.approved')
          .order('created_at', ascending: false)
          .limit(1);
      
      final existingRequests = await existingRequestsQuery;

      if (existingRequests.isNotEmpty) {
        final existingRequest = existingRequests[0];
        final existingRequestId = existingRequest['id'] as String;
        final existingStatus = existingRequest['status'] as String;
        final tutorName = existingRequest['tutor_name'] as String? ?? 'this tutor';
        
        String message;
        if (existingStatus == 'pending') {
          message = 'EXISTING_BOOKING_REQUEST:requestId=$existingRequestId:You already have a pending booking request with $tutorName. Please wait for the tutor to respond before creating another request.';
        } else if (existingStatus == 'approved') {
          message = 'EXISTING_BOOKING_REQUEST:requestId=$existingRequestId:You already have an approved booking with $tutorName.';
        } else {
          message = 'EXISTING_BOOKING_REQUEST:requestId=$existingRequestId:You already have an active booking request with $tutorName. Please wait for it to be processed.';
        }
        
        throw Exception(message);
      }

      // Check for upcoming trial sessions with this tutor (only approved/scheduled, not pending)
      // Only block if trial is upcoming (not expired/completed)
      final existingTrialsQuery = SupabaseService.client
          .from('trial_sessions')
          .select('id, status, scheduled_date, scheduled_time')
          .eq('requester_id', userId)
          .eq('tutor_id', tutorUserId)
          .or('status.eq.approved,status.eq.scheduled')
          .order('created_at', ascending: false);
      
      final existingTrials = await existingTrialsQuery;

      if (existingTrials.isNotEmpty) {
        // Check each trial to see if it's upcoming
        for (final trialData in existingTrials) {
          final trialId = trialData['id'] as String;
          final trialStatus = trialData['status'] as String;
          final scheduledDateStr = trialData['scheduled_date'] as String?;
          final scheduledTimeStr = trialData['scheduled_time'] as String?;
          
          // Only block if trial has scheduled date/time and is upcoming
          if (scheduledDateStr != null && scheduledTimeStr != null) {
            try {
              // Parse scheduled date and time
              final scheduledDate = DateTime.parse(scheduledDateStr);
              final timeParts = scheduledTimeStr.split(':');
              final hour = int.tryParse(timeParts[0]) ?? 0;
              final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
              final sessionDateTime = DateTime(
                scheduledDate.year,
                scheduledDate.month,
                scheduledDate.day,
                hour,
                minute,
              );
              
              // Check if session is upcoming (in the future)
              final isUpcoming = sessionDateTime.isAfter(DateTime.now());
              
              if (isUpcoming) {
                // Block booking - trial is upcoming
                final message = 'TRIAL_SESSION_BLOCK:trialId=$trialId:You cannot book a regular session with this tutor since you have an upcoming trial session (if the trial session passes, booking tutor is possible).';
                throw Exception(message);
              }
              // If trial is expired, don't block - continue to next trial
            } catch (e) {
              // If parsing fails, assume it's not upcoming and continue
              LogService.warning('Error parsing trial session date/time: $e');
            }
          }
        }
        // If we get here, no upcoming trials were found - allow booking
      }

      // Check for schedule conflicts on student/parent side
      final studentConflict = await checkStudentScheduleConflicts(
        studentId: userId,
        requestedDays: days,
        requestedTimes: times,
      );
      
      if (studentConflict.hasConflict) {
        // Build conflict message
        final conflictMessages = studentConflict.conflictDetails.values.toList();
        final conflictMessage = conflictMessages.join('\n');
        throw Exception(
          '⏰ Time Slot Conflict\n\nYou already have a session scheduled at the same time with another tutor:\n\n$conflictMessage\n\nPlease choose a different time slot for this booking.'
        );
      }

      // Final validation before insert - ensure student_type is valid
      if (studentType != 'learner' && studentType != 'parent') {
        LogService.error('CRITICAL: Invalid student_type before insert: "$studentType". User profile: $userProfile');
        throw Exception('Invalid user type. Please contact support.');
      }

      // Get avatar URLs
      final studentAvatarUrl = userProfile['avatar_url'] as String?;
      final tutorAvatarUrl = tutorProfileData?['avatar_url'] as String?;
      
      // Also check tutor_profiles for profile_photo_url
      final tutorProfilePhotoUrl = tutorProfile?['profile_photo_url'] as String?;
      final effectiveTutorAvatarUrl = (tutorProfilePhotoUrl != null && tutorProfilePhotoUrl.isNotEmpty)
          ? tutorProfilePhotoUrl
          : tutorAvatarUrl;

      // Create booking request data
      final requestData = {
        'student_id': userId,
        'tutor_id': tutorUserId,
        'frequency': frequency,
        'days': days,
        'times': times,
        'location': location,
        'address': address,
        'location_description': locationDescription,
        'payment_plan': paymentPlan,
        'monthly_total': monthlyTotal,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        // Link to custom request if provided
        if (customRequestId != null) 'custom_request_id': customRequestId,
        // Denormalized data
        'student_name': userProfile['full_name'],
        'student_avatar_url': studentAvatarUrl,
        'student_type': studentType, // Validated: 'learner' or 'parent' - MUST be one of these
        'tutor_name': tutorProfileData?['full_name'] ?? 'Tutor',
        'tutor_avatar_url': effectiveTutorAvatarUrl,
        'tutor_rating':
            (tutorProfile?['admin_approved_rating'] as num?)?.toDouble() ?? 0.0,
      };

      // Log the data being inserted for debugging (use error level so it shows in console)
      LogService.error('🔍 DEBUG: About to insert booking request. student_type: "$studentType", user_type: "$rawUserType", student_id: $userId, tutor_id: $tutorUserId');
      LogService.error('🔍 DEBUG: Full requestData: $requestData');

      // Insert into booking_requests table
      try {
        final response = await SupabaseService.client
          .from('booking_requests')
          .insert(requestData)
          .select()
          .maybeSingle();
        
        if (response == null) {
          throw Exception('Failed to create booking request');
        }

        final requestId = response['id'] as String;
        final studentName = userProfile['full_name'] as String? ?? 'Student';
        final studentAvatarUrl = userProfile['avatar_url'] as String?;
        final subject =
            'Tutoring Sessions'; // Could be extracted from request if available

        LogService.success('Booking request created successfully: $requestId');

        // Send notification to tutor
        try {
          await NotificationHelperService.notifyBookingRequestCreated(
            tutorId: tutorUserId,
            studentId: userId,
            requestId: requestId,
            studentName: studentName,
            subject: subject,
            senderAvatarUrl: studentAvatarUrl,
          );
        } catch (e) {
          LogService.warning('Failed to send booking request notification: $e');
          // Don't fail the request creation if notification fails
        }
      } catch (e) {
        LogService.error('Error inserting booking request: $e');
        rethrow;
      }
    } catch (e) {
      LogService.error('Error creating booking request: $e');
      
      // Provide user-friendly error messages
      final errorString = e.toString();
      
      if (errorString.contains('booking_requests_student_type_check')) {
        // Try to get user info if available (may not be in scope if error occurred early)
        try {
          final currentUserId = SupabaseService.currentUser?.id;
          LogService.error('Constraint violation - student_type issue. User ID: $currentUserId. Error: $e');
        } catch (_) {
          LogService.error('Constraint violation - student_type issue. Error: $e');
        }
        throw Exception('There was an issue with your account type. Please contact support or try logging out and back in.');
      } else if (errorString.contains('duplicate') || errorString.contains('already exists')) {
        throw Exception('You already have a booking request with this tutor. Please check your requests or wait for the tutor to respond.');
      } else if (errorString.contains('TRIAL_SESSION_BLOCK')) {
        // Re-throw trial session block messages as-is
        rethrow;
      } else {
        rethrow;
      }
    }
  }

  /// Get all booking requests for a tutor (including Trial Sessions)
  static Future<List<BookingRequest>> getTutorBookingRequests({
    String? status,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      LogService.debug('Fetching all requests for tutor: $userId');

      // 1. Fetch Recurring Booking Requests with student profile data and payment status
      var bookingQuery = SupabaseService.client
          .from('booking_requests')
          .select(
            '''
            *,
            student_profile:profiles!student_id(full_name, avatar_url, user_type),
            payment_request:payment_requests!booking_request_id(id, status)
            '''
          )
          .eq('tutor_id', userId);

      if (status != null && status != 'all') {
        bookingQuery = bookingQuery.eq('status', status);
      }

      final bookingResponse = await bookingQuery.order('created_at', ascending: false);
      final bookingList = (bookingResponse as List).map((json) {
        try {
          // Update student_avatar_url from joined profile if not already set
          final studentProfile = json['student_profile'];
          if (studentProfile != null && studentProfile is Map) {
            final profileAvatarUrl = studentProfile['avatar_url'] as String?;
            if (profileAvatarUrl != null && profileAvatarUrl.isNotEmpty) {
              json['student_avatar_url'] = profileAvatarUrl;
            }
          }
          
          // Extract payment status from joined payment_request
          // Note: payment_requests has a foreign key to booking_requests, so it's one-to-many
          // We need to get the most recent payment request
          final paymentRequest = json['payment_request'];
          if (paymentRequest != null) {
            Map<String, dynamic>? latestPayment;
            if (paymentRequest is List && paymentRequest.isNotEmpty) {
              // Multiple payment requests - get the most recent one (first after ordering)
              latestPayment = paymentRequest[0] as Map<String, dynamic>;
            } else if (paymentRequest is Map) {
              // Single payment request
              latestPayment = paymentRequest as Map<String, dynamic>;
            }
            
            if (latestPayment != null) {
              json['payment_status'] = latestPayment['status'] as String?;
              json['payment_request_id'] = latestPayment['id'] as String?;
              LogService.debug('📋 Payment status for ${json['id']}: ${latestPayment['status']}, payment_request_id: ${latestPayment['id']}');
            }
          }
          
          return BookingRequest.fromJson(json);
        } catch (e) {
          LogService.error('Error parsing booking request', e);
          return null;
        }
      }).whereType<BookingRequest>().toList();

      // 2. Fetch Trial Sessions
      List<BookingRequest> trialList = [];
      try {
        var trialQuery = SupabaseService.client
            .from('trial_sessions')
            // Fetch learner, requester (who made the request), and parent profiles
            // The requester is the one who made the request (could be parent or learner)
            .select(
              '''
              *,
              learner:profiles!learner_id(full_name, avatar_url, user_type, email),
              requester:profiles!requester_id(full_name, avatar_url, user_type, email),
              parent:profiles!parent_id(full_name, avatar_url, user_type, email)
              ''',
            )
            .eq('tutor_id', userId);

          if (status != null && status != 'all') {
          // If filtering for pending, we should also include 'pending_payment' if that's a valid status for tutor action
          // But sticking to 'pending' for now as that's likely what the tutor needs to approve
          trialQuery = trialQuery.eq('status', status);
        }

        final trialResponse = await trialQuery.order('created_at', ascending: false);
        trialList = (trialResponse as List).map((json) {
          try {
            // Prefer requester profile (the one who made the request - most accurate)
            // Then fall back to learner, then parent
            final requesterProfileRaw = json['requester'];
            final learnerProfileRaw = json['learner'];
            final parentProfileRaw = json['parent'];
            
            // Convert to Map, handling null and empty cases
            Map<String, dynamic>? requesterProfile;
            Map<String, dynamic>? learnerProfile;
            Map<String, dynamic>? parentProfile;
            
            if (requesterProfileRaw != null && requesterProfileRaw is Map) {
              requesterProfile = Map<String, dynamic>.from(requesterProfileRaw);
              // Check if it has meaningful data (not just empty/null values)
              if (requesterProfile.isEmpty || 
                  (requesterProfile['full_name'] == null && requesterProfile['email'] == null)) {
                requesterProfile = null;
              }
            }
            
            if (learnerProfileRaw != null && learnerProfileRaw is Map) {
              learnerProfile = Map<String, dynamic>.from(learnerProfileRaw);
              // Check if profile has meaningful data (not empty, null, or just whitespace)
              final hasName = learnerProfile['full_name'] != null && 
                             learnerProfile['full_name'].toString().trim().isNotEmpty &&
                             learnerProfile['full_name'].toString().toLowerCase() != 'null';
              final hasEmail = learnerProfile['email'] != null && 
                              learnerProfile['email'].toString().trim().isNotEmpty &&
                              learnerProfile['email'].toString().toLowerCase() != 'null';
              if (learnerProfile.isEmpty || (!hasName && !hasEmail)) {
                learnerProfile = null;
              } else {
                LogService.debug('✅ Learner profile found: ${learnerProfile['full_name']} (ID: ${json['learner_id']})');
              }
            }
            
            if (parentProfileRaw != null && parentProfileRaw is Map) {
              parentProfile = Map<String, dynamic>.from(parentProfileRaw);
              final hasName = parentProfile['full_name'] != null && 
                             parentProfile['full_name'].toString().trim().isNotEmpty &&
                             parentProfile['full_name'].toString().toLowerCase() != 'null';
              final hasEmail = parentProfile['email'] != null && 
                              parentProfile['email'].toString().trim().isNotEmpty &&
                              parentProfile['email'].toString().toLowerCase() != 'null';
              if (parentProfile.isEmpty || (!hasName && !hasEmail)) {
                parentProfile = null;
              }
            }
            
            // CRITICAL FIX: For display purposes, show the REQUESTER (who made the booking)
            // The requester is the one who actually created the request (could be parent or student)
            // The learner is who will attend, but for the tutor's view, we want to see who made the request
            Map<String, dynamic> requesterDisplayProfile;
            if (requesterProfile != null && requesterProfile.isNotEmpty) {
              // Use requester profile (who made the booking) - this is what tutors should see
              requesterDisplayProfile = requesterProfile;
              LogService.debug('✅ Using requester profile for display: ${requesterProfile['full_name']} (user_type: ${requesterProfile['user_type']})');
            } else if (learnerProfile != null && learnerProfile.isNotEmpty) {
              // Fallback to learner if requester not available
              requesterDisplayProfile = learnerProfile;
              LogService.debug('Using learner profile as fallback for display');
            } else if (parentProfile != null && parentProfile.isNotEmpty) {
              // Fallback to parent if available
              requesterDisplayProfile = parentProfile;
              LogService.debug('Using parent profile as fallback for display');
            } else {
              // If no profile found, use defaults
              LogService.warning('⚠️ No valid profile found for trial session ${json['id']}, requester_id: ${json['requester_id']}');
              requesterDisplayProfile = {
                'user_type': 'learner', // Default to learner
              };
            }
            
            // Pass requester profile for display (who made the booking)
            return BookingRequest.fromTrialSession(json, requesterDisplayProfile, null);
          } catch (e) {
            LogService.error('Error parsing trial session: $e');
            return null;
          }
        }).whereType<BookingRequest>().toList();
      } catch (e) {
        LogService.error('Error fetching trial sessions: $e');
        // Continue with just booking list if trials fail
      }

      // 3. Merge and Sort
      final allRequests = [...bookingList, ...trialList];
      allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first

      LogService.success('Found ${allRequests.length} total requests (${bookingList.length} recurring, ${trialList.length} trials)');
      return allRequests;

    } catch (e) {
      LogService.error('Error fetching tutor requests: $e');
      return []; 
    }
  }

  /// Get all booking requests for a student/parent
  static Future<List<BookingRequest>> getStudentBookingRequests(
    String studentId,
  ) async {
    try {
      LogService.error('🔍 [BOOKING_REQUESTS] Fetching booking requests for student: $studentId');
      
      // First, check if ANY booking requests exist in the table (for debugging)
      try {
        final allRequestsCheck = await SupabaseService.client
            .from('booking_requests')
            .select('id, student_id, tutor_id, status, created_at')
            .limit(10);
        
        LogService.error('📊 [BOOKING_REQUESTS] Total booking requests in table: ${(allRequestsCheck as List).length}');
        if ((allRequestsCheck as List).isNotEmpty) {
          LogService.error('📋 [BOOKING_REQUESTS] Sample requests:');
          for (var req in (allRequestsCheck as List).take(3)) {
            LogService.error('   - id: ${req['id']}, student_id: ${req['student_id']}, status: ${req['status']}');
          }
        }
      } catch (e) {
        LogService.error('❌ [BOOKING_REQUESTS] Error checking all requests: $e');
      }
      
      // First, try a simple query without joins to test RLS
      try {
        LogService.error('🔍 [BOOKING_REQUESTS] Running simple query for student_id: $studentId');
        final simpleResponse = await SupabaseService.client
            .from('booking_requests')
            .select('id, student_id, status, created_at')
            .eq('student_id', studentId)
            .order('created_at', ascending: false);
        
        LogService.error('📊 [BOOKING_REQUESTS] Simple query result: ${(simpleResponse as List).length} rows');
        if ((simpleResponse as List).isNotEmpty) {
          LogService.error('📋 [BOOKING_REQUESTS] Simple query sample: ${simpleResponse[0]}');
        } else {
          LogService.error('⚠️ [BOOKING_REQUESTS] No booking requests found with student_id: $studentId');
        }
      } catch (e, stackTrace) {
        LogService.error('❌ [BOOKING_REQUESTS] Simple query failed: $e');
        LogService.error('📚 [BOOKING_REQUESTS] Stack trace: $stackTrace');
      }
      
      // Fix: tutor_id references profiles.id, not tutor_profiles.user_id
      // We can't directly join tutor_profiles from booking_requests
      // So we'll join profiles and fetch tutor_profiles data separately if needed
      // Also join payment_requests to get payment status upfront (prevents UI flickering)
      var query = SupabaseService.client
          .from('booking_requests')
          .select(
            '''
            *,
            tutor_profile:profiles!tutor_id(full_name, avatar_url),
            payment_request:payment_requests!booking_request_id(id, status)
            '''
          )
          .eq('student_id', studentId);

      LogService.error('🔍 [BOOKING_REQUESTS] Running full query with joins for student_id: $studentId');
      final response = await query.order('created_at', ascending: false);
      
      LogService.error('📊 [BOOKING_REQUESTS] Full query response type: ${response.runtimeType}, length: ${(response as List).length}');

      final bookingRequests = (response as List).map((json) {
        try {
          // Update tutor_avatar_url from joined profiles
          final tutorProfile = json['tutor_profile'];
          
          if (tutorProfile != null && tutorProfile is Map) {
            // Use avatar_url from profiles (tutor_profiles join removed due to FK constraint)
            final avatarUrl = tutorProfile['avatar_url'] as String?;
            
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              json['tutor_avatar_url'] = avatarUrl;
            } else {
              // If avatar_url is not available, try to fetch from tutor_profiles separately
              // This is a fallback - the join should work in most cases
              json['tutor_avatar_url'] = null; // Will show initials in UI
            }
          } else {
            // No tutor profile found - will show initials in UI
            json['tutor_avatar_url'] = null;
          }
          
          // Extract payment status from joined payment_request
          final paymentRequest = json['payment_request'];
          if (paymentRequest != null && paymentRequest is List && paymentRequest.isNotEmpty) {
            // payment_requests is a one-to-many relationship, get the most recent one
            final latestPayment = paymentRequest[0] as Map<String, dynamic>;
            json['payment_status'] = latestPayment['status'] as String?;
            json['payment_request_id'] = latestPayment['id'] as String?;
          } else if (paymentRequest != null && paymentRequest is Map) {
            // Single payment request
            json['payment_status'] = paymentRequest['status'] as String?;
            json['payment_request_id'] = paymentRequest['id'] as String?;
          }
          
          // Note: tutor_profiles data would need to be fetched separately if needed
          // For now, we use avatar_url from profiles which should be sufficient
          
          return BookingRequest.fromJson(json);
        } catch (e, stackTrace) {
          LogService.error('❌ Error parsing booking request JSON: $e');
          LogService.error('📚 Stack trace: $stackTrace');
          LogService.error('📋 JSON data: $json');
          rethrow;
        }
      }).toList();
      
      LogService.error('✅ [BOOKING_REQUESTS] Successfully fetched ${bookingRequests.length} booking requests for student: $studentId');
      if (bookingRequests.isNotEmpty) {
        LogService.error('📋 [BOOKING_REQUESTS] Request IDs: ${bookingRequests.map((r) => r.id).join(", ")}');
        LogService.error('📋 [BOOKING_REQUESTS] Request statuses: ${bookingRequests.map((r) => r.status).join(", ")}');
      } else {
        LogService.error('⚠️ [BOOKING_REQUESTS] No booking requests returned for student: $studentId');
      }
      
      return bookingRequests;
    } catch (e, stackTrace) {
      LogService.error('❌ Error fetching student booking requests: $e');
      LogService.error('📚 Stack trace: $stackTrace');
      LogService.error('👤 Student ID: $studentId');
      throw Exception('Failed to fetch booking requests: $e');
    }
  }

  /// Get single booking request by ID
  static Future<BookingRequest> getBookingRequestById(String requestId) async {
    try {
      final response = await SupabaseService.client
          .from('booking_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Booking request not found: $requestId');
      }

      return BookingRequest.fromJson(response);
    } catch (e) {
      LogService.error('Error fetching booking request: $e');
      throw Exception('Failed to fetch booking request: $e');
    }
  }

  /// Approve a booking request (tutor)
  static Future<BookingRequest> approveBookingRequest(
    String requestId, {
    String? responseNotes,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify the request belongs to this tutor
      final request = await getBookingRequestById(requestId);
      if (request.tutorId != userId) {
        throw Exception('Unauthorized: This request is not for you');
      }

      if (request.status != 'pending') {
        throw Exception('Request is not pending');
      }

      // Check for conflicts
      final hasConflict = await _checkScheduleConflicts(request);

      final updateData = {
        'status': 'approved',
        'responded_at': DateTime.now().toIso8601String(),
        'tutor_response': responseNotes,
        'has_conflict': hasConflict,
      };

      final updated = await SupabaseService.client
          .from('booking_requests')
          .update(updateData)
          .eq('id', requestId)
          .select()
          .maybeSingle();

      if (updated == null) {
        throw Exception('Failed to update booking request: $requestId');
      }

      final bookingRequest = BookingRequest.fromJson(updated);

      LogService.success('✅ Booking request approved: $requestId');
      LogService.info('📋 Approval Details:', 'studentId=${request.studentId}, tutorId=${request.tutorId}, location=${request.location}');

      // Create payment request when tutor approves (CRITICAL - must succeed)
      String? paymentRequestId;
      try {
        LogService.info('💳 Creating payment request for approved booking...');
        paymentRequestId =
            await PaymentRequestService.createPaymentRequestOnApproval(
              bookingRequest,
            );
        LogService.success('✅ Payment request created successfully: $paymentRequestId');
      } catch (e, stackTrace) {
        LogService.error('❌ CRITICAL: Failed to create payment request: $e');
        LogService.error('📚 Stack trace: $stackTrace');
        // Don't fail the approval, but log as error for monitoring
        // The booking is already approved, payment can be created manually if needed
        // However, this should be rare and indicates a system issue
      }

      // Create recurring session from approved booking
      try {
        LogService.info('📅 Creating recurring session from approved booking...');
        await RecurringSessionService.createRecurringSessionFromBooking(
          bookingRequest,
          paymentRequestId: paymentRequestId,
        );
        LogService.success('✅ Recurring session created successfully');
        LogService.info('📝 Note: Individual sessions will be generated after first payment');
      } catch (e, stackTrace) {
        LogService.error('❌ Failed to create recurring session: $e');
        LogService.error('📚 Stack trace: $stackTrace');
        // Don't fail the approval if session creation fails
        // The request is already approved, session can be created manually later
      }

      // Create conversation for approved booking
      try {
        LogService.info('💬 Creating conversation for approved booking...');
        await ConversationLifecycleService.createConversationForBooking(
          bookingRequestId: requestId,
          studentId: request.studentId,
          tutorId: request.tutorId,
        );
        LogService.success('✅ Conversation created for booking');
      } catch (e) {
        LogService.warning('⚠️ Failed to create conversation for booking: $e');
        // Don't fail approval if conversation creation fails
      }

      // Send notification to student
      try {
        LogService.info('📧 Sending approval notification to student...');
        final tutorName = request.tutorName;
        final subject = 'Tutoring Sessions';
        await NotificationHelperService.notifyBookingRequestAccepted(
          studentId: request.studentId,
          tutorId: request.tutorId,
          requestId: requestId,
          tutorName: tutorName,
          subject: subject,
          paymentRequestId: paymentRequestId,
          senderAvatarUrl: request.tutorAvatarUrl,
        );
        LogService.success('✅ Approval notification sent to student');
      } catch (e, stackTrace) {
        LogService.error('❌ Failed to send booking acceptance notification: $e');
        LogService.error('📚 Stack trace: $stackTrace');
      }

      return bookingRequest;
    } catch (e) {
      LogService.error('Error approving booking request: $e');
      rethrow;
    }
  }

  /// Reject a booking request (tutor)
  static Future<BookingRequest> rejectBookingRequest(
    String requestId, {
    required String reason,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify the request belongs to this tutor
      final request = await getBookingRequestById(requestId);
      if (request.tutorId != userId) {
        throw Exception('Unauthorized: This request is not for you');
      }

      if (request.status != 'pending') {
        throw Exception('Request is not pending');
      }

      final updateData = {
        'status': 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      };

      final updated = await SupabaseService.client
          .from('booking_requests')
          .update(updateData)
          .eq('id', requestId)
          .select()
          .maybeSingle();

      if (updated == null) {
        throw Exception('Failed to update booking request: $requestId');
      }

      final bookingRequest = BookingRequest.fromJson(updated);

      LogService.success('✅ Booking request rejected: $requestId');
      LogService.info('📋 Rejection Details:', 'studentId=${request.studentId}, tutorId=${request.tutorId}, reason=$reason');

      // Send notification to student
      try {
        LogService.info('📧 Sending rejection notification to student...');
        final tutorName = request.tutorName;
        await NotificationHelperService.notifyBookingRequestRejected(
          studentId: request.studentId,
          tutorId: request.tutorId,
          requestId: requestId,
          tutorName: tutorName,
          rejectionReason: reason,
          senderAvatarUrl: request.tutorAvatarUrl,
        );
        LogService.success('✅ Rejection notification sent to student');
      } catch (e, stackTrace) {
        LogService.error('❌ Failed to send booking rejection notification: $e');
        LogService.error('📚 Stack trace: $stackTrace');
      }

      return bookingRequest;
    } catch (e) {
      LogService.error('Error rejecting booking request: $e');
      rethrow;
    }
  }

  /// Approve a Trial Session
  static Future<void> approveTrialRequest(String sessionId, {String? responseNotes}) async {
    try {
      LogService.info('Approving trial session: $sessionId');
      
      // 1. Update status
      // NOTE: Column name in DB is `tutor_response_notes` (not `tutor_response`)
      final updateData = {
        'status': 'approved',
        'responded_at': DateTime.now().toIso8601String(),
        'tutor_response_notes': responseNotes,
      };

      // Update trial session without join (no FK relationship in DB)
      final updatedSession = await SupabaseService.client
          .from('trial_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .maybeSingle();

      if (updatedSession == null) {
        throw Exception('Failed to update trial session: $sessionId');
      }

      LogService.success('Trial session status updated to approved');

      // Fetch student profile separately using learner_id
      final learnerId = updatedSession['learner_id'] as String;
      final studentProfile = await SupabaseService.client
              .from('profiles')
              .select('full_name, avatar_url, user_type')
              .eq('id', learnerId)
              .maybeSingle() as Map<String, dynamic>? ??
          <String, dynamic>{};

      // 2. Build a BookingRequest representation of this trial
      final bookingRequest =
          BookingRequest.fromTrialSession(updatedSession, studentProfile, null);

      // 3. Create Payment Request (non‑blocking for notifications)
      String? paymentRequestId;
      try {
        paymentRequestId =
            await PaymentRequestService.createPaymentRequestOnApproval(
          bookingRequest,
        );
        LogService.success('Payment request created for trial: $paymentRequestId');
      } catch (e) {
        LogService.warning('Error creating payment request for trial: $e');
        // We still want to notify the learner that the trial was approved
      }

      // 4. Notify Student (always attempt, even if payment request failed)
      try {
        // Fetch tutor profile for avatar + display name
        final tutorId = SupabaseService.currentUser!.id;
        final tutorProfile = await SupabaseService.client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', tutorId)
            .maybeSingle();

        final tutorName = tutorProfile?['full_name'] as String? ?? 'Your Tutor';
        final tutorAvatarUrl = tutorProfile?['avatar_url'] as String?;

        // Reuse booking accepted notification so student can jump straight to payment
        await NotificationHelperService.notifyBookingRequestAccepted(
          studentId: bookingRequest.studentId,
          tutorId: bookingRequest.tutorId,
          requestId: sessionId,
          tutorName: tutorName,
          subject: 'Trial Session: ${bookingRequest.subject ?? "Tutoring"}',
          paymentRequestId: paymentRequestId,
          senderAvatarUrl: tutorAvatarUrl,
        );
      } catch (e) {
        LogService.warning('Error sending approval notification for trial: $e');
      }
    } catch (e) {
      LogService.error('Error approving trial request: $e');
      rethrow;
    }
  }

  /// Reject a Trial Session
  static Future<void> rejectTrialRequest(String sessionId, {required String reason}) async {
    try {
      LogService.debug('Rejecting trial session: $sessionId');
      
      final updateData = {
        'status': 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      };

      // Update trial session without join (no FK relationship in DB)
      final updatedSession = await SupabaseService.client
          .from('trial_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .maybeSingle();

      if (updatedSession == null) {
        throw Exception('Failed to update trial session: $sessionId');
      }

      LogService.success('Trial session rejected');

      // Fetch student profile separately using learner_id
      final learnerId = updatedSession['learner_id'] as String;
      final studentProfile = await SupabaseService.client
          .from('profiles')
          .select('full_name, avatar_url, user_type')
          .eq('id', learnerId)
          .maybeSingle() as Map<String, dynamic>? ??
          <String, dynamic>{};

      // Notify Student
      try {
        final bookingRequest = BookingRequest.fromTrialSession(
          updatedSession, 
          studentProfile, 
          null
        );
        
        // Fetch tutor profile for avatar
        final tutorId = SupabaseService.currentUser!.id;
        final tutorProfile = await SupabaseService.client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', tutorId)
            .maybeSingle();
        
        final tutorName = tutorProfile?['full_name'] as String? ?? 'Your Tutor';
        final tutorAvatarUrl = tutorProfile?['avatar_url'] as String?;
        
        await NotificationHelperService.notifyBookingRequestRejected(
          studentId: bookingRequest.studentId,
          tutorId: bookingRequest.tutorId,
          requestId: sessionId,
          tutorName: tutorName,
          rejectionReason: reason,
          senderAvatarUrl: tutorAvatarUrl,
        );
      } catch (e) {
        LogService.warning('Error sending rejection notification: $e');
      }
    } catch (e) {
      LogService.error('Error rejecting trial request: $e');
      rethrow;
    }
  }

  /// Check for schedule conflicts with existing sessions
  static Future<bool> _checkScheduleConflicts(BookingRequest request) async {
    try {
      // Check conflicts with existing recurring sessions for this tutor
      final existingSessions = await SupabaseService.client
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', request.tutorId)
          .eq('status', 'active');

      for (final session in existingSessions) {
        final sessionDays = List<String>.from(session['days'] as List);
        final sessionTimes = Map<String, String>.from(session['times'] as Map);

        // Check if any day/time overlaps
        for (final day in request.days) {
          if (sessionDays.contains(day)) {
            final requestTime = request.times[day];
            final sessionTime = sessionTimes[day];
            if (requestTime == sessionTime) {
              return true; // Conflict found
            }
          }
        }
      }

      return false; // No conflicts
    } catch (e) {
      LogService.warning('Error checking conflicts: $e');
      return false; // Assume no conflict on error
    }
  }

  /// Check for schedule conflicts on student/parent side
  /// 
  /// Checks if the student/parent already has sessions scheduled at the requested times
  /// with other tutors (recurring sessions, individual sessions, or trial sessions)
  static Future<ConflictResult> checkStudentScheduleConflicts({
    required String studentId,
    required List<String> requestedDays,
    required Map<String, String> requestedTimes,
  }) async {
    try {
      final List<String> conflictingDays = [];
      final Map<String, String> conflictDetails = {};
      
      // 1. Check recurring sessions (active sessions with other tutors)
      // Note: recurring_sessions uses learner_id, not student_id
      final recurringSessions = await SupabaseService.client
          .from('recurring_sessions')
          .select('id, days, times, tutor_name, status')
          .eq('learner_id', studentId)
          .eq('status', 'active');
      
      for (final session in recurringSessions as List) {
        final sessionDays = List<String>.from(session['days'] ?? []);
        final sessionTimes = Map<String, String>.from(session['times'] ?? {});
        final tutorName = session['tutor_name'] as String? ?? 'another tutor';
        
        for (final requestedDay in requestedDays) {
          final requestedTime = requestedTimes[requestedDay];
          if (requestedTime == null) continue;
          
          if (sessionDays.contains(requestedDay)) {
            final existingTime = sessionTimes[requestedDay];
            if (existingTime != null && _normalizeTime(existingTime) == _normalizeTime(requestedTime)) {
              if (!conflictingDays.contains(requestedDay)) {
                conflictingDays.add(requestedDay);
                conflictDetails[requestedDay] = 
                    'You have a session with $tutorName on $requestedDay at $existingTime';
              }
            }
          }
        }
      }
      
      // 2. Check individual sessions (upcoming scheduled sessions)
      // Get next 30 days of individual sessions
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 30));
      
      final individualSessionsResponse = await SupabaseService.client
          .from('individual_sessions')
          .select('scheduled_date, scheduled_time, tutor_id, status, tutor:profiles!tutor_id(full_name)')
          .or('learner_id.eq.$studentId,parent_id.eq.$studentId')
          .inFilter('status', ['scheduled', 'in_progress'])
          .gte('scheduled_date', now.toIso8601String().split('T')[0])
          .lte('scheduled_date', futureDate.toIso8601String().split('T')[0]);
      
      final individualSessions = individualSessionsResponse as List;
      
      for (final session in individualSessions) {
        final scheduledDate = session['scheduled_date'] as String?;
        final scheduledTime = session['scheduled_time'] as String?;
        final tutorProfile = session['tutor'] as Map<String, dynamic>?;
        final tutorName = tutorProfile?['full_name'] as String? ?? 'another tutor';
        
        if (scheduledDate == null || scheduledTime == null) continue;
        
        // Convert date to day name
        final sessionDate = DateTime.parse(scheduledDate);
        final dayName = _getDayName(sessionDate);
        
        // Check if this day/time conflicts with requested schedule
        if (requestedDays.contains(dayName)) {
          final requestedTime = requestedTimes[dayName];
          if (requestedTime != null && _normalizeTime(scheduledTime) == _normalizeTime(requestedTime)) {
            if (!conflictingDays.contains(dayName)) {
              conflictingDays.add(dayName);
              conflictDetails[dayName] = 
                  'You have a session with $tutorName on $dayName at ${_formatTime(scheduledTime)}';
            }
          }
        }
      }
      
      // 3. Check trial sessions (upcoming scheduled trials)
      final trialSessionsResponse = await SupabaseService.client
          .from('trial_sessions')
          .select('scheduled_date, scheduled_time, tutor_id, status, tutor:profiles!tutor_id(full_name)')
          .or('requester_id.eq.$studentId,learner_id.eq.$studentId,parent_id.eq.$studentId')
          .inFilter('status', ['pending', 'approved', 'scheduled'])
          .gte('scheduled_date', now.toIso8601String().split('T')[0])
          .lte('scheduled_date', futureDate.toIso8601String().split('T')[0]);
      
      final trialSessions = trialSessionsResponse as List;
      
      for (final session in trialSessions) {
        final scheduledDate = session['scheduled_date'] as String?;
        final scheduledTime = session['scheduled_time'] as String?;
        final tutorProfile = session['tutor'] as Map<String, dynamic>?;
        final tutorName = tutorProfile?['full_name'] as String? ?? 'another tutor';
        
        if (scheduledDate == null || scheduledTime == null) continue;
        
        // Convert date to day name
        final sessionDate = DateTime.parse(scheduledDate);
        final dayName = _getDayName(sessionDate);
        
        // Check if this day/time conflicts with requested schedule
        if (requestedDays.contains(dayName)) {
          final requestedTime = requestedTimes[dayName];
          if (requestedTime != null && _normalizeTime(scheduledTime) == _normalizeTime(requestedTime)) {
            if (!conflictingDays.contains(dayName)) {
              conflictingDays.add(dayName);
              conflictDetails[dayName] = 
                  'You have a trial session with $tutorName on $dayName at ${_formatTime(scheduledTime)}';
            }
          }
        }
      }
      
      return ConflictResult(
        hasConflict: conflictingDays.isNotEmpty,
        conflictingDays: conflictingDays,
        conflictDetails: conflictDetails,
      );
    } catch (e) {
      LogService.warning('Error checking student schedule conflicts: $e');
      // Don't block booking if conflict check fails - just log the error
      return ConflictResult(
        hasConflict: false,
        conflictingDays: [],
        conflictDetails: {},
      );
    }
  }
  
  /// Normalize time strings for comparison (handles different formats)
  static String _normalizeTime(String time) {
    // Remove spaces and convert to uppercase
    final cleaned = time.trim().toUpperCase();
    // Handle formats like "4:00 PM", "16:00", "4:00PM", etc.
    // For now, simple comparison - can be enhanced
    return cleaned.replaceAll(' ', '').replaceAll(':', '');
  }
  
  /// Format time for display
  static String _formatTime(String time) {
    // Try to parse and format nicely
    try {
      // If it's in HH:MM:SS format, extract HH:MM
      if (time.contains(':')) {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final isPM = hour >= 12;
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:$minute ${isPM ? 'PM' : 'AM'}';
      }
    } catch (e) {
      // If parsing fails, return as is
    }
    return time;
  }
  
  /// Get day name from date
  static String _getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }
}