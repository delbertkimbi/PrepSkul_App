import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/transportation_cost_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';


/// RecurringSessionService
///
/// Handles creation and management of recurring sessions
/// from approved booking requests
class RecurringSessionService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Create a recurring session from an approved booking request
  /// Create a recurring session from an approved booking request
  /// 
  /// [paymentRequestId] - Optional payment request ID to link after creation
  static Future<Map<String, dynamic>> createRecurringSessionFromBooking(
    BookingRequest bookingRequest, {
    String? paymentRequestId,
  }) async {
    try {
      // Calculate start date (next available session date)
      final startDate = _calculateStartDate(bookingRequest);

      // Create recurring session data
      // Note: request_id is set to NULL because the FK constraint references session_requests,
      // but we're using booking_requests. The payment_request.recurring_session_id link is used instead.
      final sessionData = <String, dynamic>{
        'request_id': null, // Cannot use bookingRequest.id due to FK constraint to session_requests
        'learner_id': bookingRequest.studentId, // Database uses learner_id, not student_id
        'tutor_id': bookingRequest.tutorId,
        'frequency': bookingRequest.frequency,
        'days': bookingRequest.days,
        'times': bookingRequest.times,
        'location': bookingRequest.location,
        'address': bookingRequest.address,
        'payment_plan': bookingRequest.paymentPlan,
        'monthly_total': bookingRequest.monthlyTotal,
        'start_date': startDate.toIso8601String(),
        'end_date': null, // Ongoing
        'status': 'active',
        'total_sessions_completed': 0,
        'total_revenue': 0.0,
        // Denormalized data (use learner_* columns as per database schema)
        'learner_name': bookingRequest.studentName,
        'learner_avatar_url': bookingRequest.studentAvatarUrl,
        'learner_type': bookingRequest.studentType,
        'tutor_name': bookingRequest.tutorName,
        'tutor_avatar_url': bookingRequest.tutorAvatarUrl,
        'tutor_rating': bookingRequest.tutorRating,
        'subject': bookingRequest.subject ?? 'Tutoring Session', // Store subject in recurring_sessions
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add multi-learner support (for parent bookings)
      if (bookingRequest.learnerLabels != null && bookingRequest.learnerLabels!.isNotEmpty) {
        sessionData['learner_labels'] = bookingRequest.learnerLabels;
      }

      // Add transportation cost (for onsite/hybrid sessions)
      if (bookingRequest.estimatedTransportationCost != null && bookingRequest.estimatedTransportationCost! > 0) {
        sessionData['transportation_cost_per_session'] = bookingRequest.estimatedTransportationCost;
      }

      // Add location_description if available
      if (bookingRequest.locationDescription != null) {
        sessionData['location_description'] = bookingRequest.locationDescription;
      }

      // Insert into recurring_sessions table
      final response = await _supabase
          .from('recurring_sessions')
          .insert(sessionData)
          .select()
          .maybeSingle();
      
      if (response == null) {
        throw Exception('Failed to create recurring session');
      }

      LogService.success('Recurring session created: ${response['id']}');

      // Link payment request to recurring session if provided
      if (paymentRequestId != null) {
        try {
          await PaymentRequestService.linkPaymentRequestToRecurringSession(
            paymentRequestId,
            response['id'] as String,
          );
          LogService.success('Payment request linked to recurring session');
        } catch (e) {
          LogService.warning('Failed to link payment request to recurring session: $e');
          // Don't fail the recurring session creation if linking fails
        }
      }

      // NOTE: Individual sessions are NOT generated here on approval
      // They will be generated AFTER the first payment is completed
      // This ensures sessions only appear in the sessions tab after payment
      // See: fapshi_webhook_service.dart _handlePaymentRequestPayment()
      LogService.info('📝 Recurring session created - individual sessions will be generated after first payment');
      
      // Schedule session reminder notifications (24h, 1h, 15min before)
      // Note: Reminders will be scheduled for individual sessions once they are generated after payment
      try {
        final tutorProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', bookingRequest.tutorId)
            .maybeSingle();
        final studentProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', bookingRequest.studentId)
            .maybeSingle();
        
        final tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor';
        final studentName = studentProfile?['full_name'] as String? ?? 'Student';
        
        // Calculate first session start time
        final firstSessionStart = _calculateStartDate(bookingRequest);
        final firstDay = bookingRequest.days.first;
        final firstTime = bookingRequest.times[firstDay] ?? '10:00 AM';
        final timeParts = firstTime.replaceAll(' ', '').split(':');
        final hour = int.tryParse(timeParts[0]) ?? 10;
        final minute = int.tryParse(timeParts[1].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final isPM = firstTime.toUpperCase().contains('PM');
        final hour24 = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour);
        
        final sessionStart = DateTime(
          firstSessionStart.year,
          firstSessionStart.month,
          firstSessionStart.day,
          hour24,
          minute,
        );
        
        // Schedule reminders for recurring session (will be updated when individual sessions are generated)
        await NotificationHelperService.scheduleSessionReminders(
          tutorId: bookingRequest.tutorId,
          studentId: bookingRequest.studentId,
          sessionId: response['id'] as String, // Use recurring session ID for now
          sessionType: 'recurring',
          tutorName: tutorName,
          studentName: studentName,
          sessionStart: sessionStart,
          subject: bookingRequest.subject ?? 'Tutoring Session',
        );
      } catch (e) {
        LogService.warning('Failed to schedule session reminders: $e');
        // Don't fail session creation if reminder scheduling fails
      }

      return response;
    } catch (e) {
      LogService.error('Error creating recurring session: $e');
      rethrow;
    }
  }

  /// Calculate the start date for the recurring session
  /// Returns the next occurrence of the first requested day
  static DateTime _calculateStartDate(BookingRequest request) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get the first day from the request
    final firstDay = request.days.first;
    final dayIndex = _getDayIndex(firstDay);
    
    // Calculate days until next occurrence
    int daysUntil = (dayIndex - now.weekday) % 7;
    if (daysUntil == 0) {
      // If today is the day, check the time
      final timeStr = request.times[firstDay];
      if (timeStr != null) {
        final timeParts = timeStr.replaceAll(' ', '').split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final sessionTime = DateTime(now.year, now.month, now.day, hour, minute);
        
        // If session time has passed today, schedule for next week
        if (now.isAfter(sessionTime)) {
          daysUntil = 7;
        }
      }
    }
    
    return today.add(Duration(days: daysUntil));
  }

  /// Get day index (Monday = 1, Sunday = 7)
  static int _getDayIndex(String day) {
    const days = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };
    return days[day] ?? 1;
  }

  /// Get all recurring sessions for a tutor
  static Future<List<Map<String, dynamic>>> getTutorRecurringSessions({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query = _supabase
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('start_date', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching tutor recurring sessions: $e');
      throw Exception('Failed to fetch recurring sessions: $e');
    }
  }

  /// Get all recurring sessions for a student/parent
  static Future<List<Map<String, dynamic>>> getStudentRecurringSessions(
    String studentId, {
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('recurring_sessions')
          .select()
          .eq('student_id', studentId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('start_date', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching student recurring sessions: $e');
      throw Exception('Failed to fetch recurring sessions: $e');
    }
  }

  /// Update session status
  static Future<void> updateSessionStatus(
    String sessionId,
    String status, {
    String? pauseReason,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (pauseReason != null) {
        updateData['pause_reason'] = pauseReason;
      }

      await _supabase
          .from('recurring_sessions')
          .update(updateData)
          .eq('id', sessionId);

      LogService.success('Session status updated: $sessionId -> $status');
    } catch (e) {
      LogService.error('Error updating session status: $e');
      rethrow;
    }
  }

  /// Generate individual session instances from a recurring session
  ///
  /// Creates individual sessions for the next [weeksAhead] weeks
  /// based on the recurring session's schedule (days, times, frequency)
  /// Returns the number of sessions created
  static Future<int> generateIndividualSessions({
    required String recurringSessionId,
    int weeksAhead = 8,
  }) async {
    try {
      LogService.info('🚀 Starting session generation for recurring_session_id: $recurringSessionId, weeksAhead: $weeksAhead');
      
      // Get recurring session details
      final recurringSession = await _supabase
          .from('recurring_sessions')
          .select()
          .eq('id', recurringSessionId)
          .maybeSingle();
      
      if (recurringSession == null) {
        LogService.error('❌ Recurring session not found: $recurringSessionId');
        throw Exception('Recurring session not found: $recurringSessionId');
      }

      LogService.info('✅ Found recurring session: ${recurringSession['id']}');
      
      final startDate = DateTime.parse(recurringSession['start_date'] as String);
      final days = (recurringSession['days'] as List).cast<String>();
      final times = recurringSession['times'] as Map<String, dynamic>;
      final location = recurringSession['location'] as String;
      final address = recurringSession['address'] as String?;
      final tutorId = recurringSession['tutor_id'] as String;
      // Database uses learner_id, not student_id
      final studentId = recurringSession['learner_id'] as String? ?? recurringSession['student_id'] as String?;
      
      LogService.info('📅 Start date: $startDate');
      LogService.info('📆 Days: $days');
      LogService.info('⏰ Times: $times');
      LogService.info('📍 Location: $location');
      LogService.info('👤 Tutor ID: $tutorId');
      LogService.info('👤 Student ID: $studentId');
      
      if (studentId == null) {
        LogService.error('❌ Recurring session missing learner_id/student_id: $recurringSessionId');
        throw Exception('Recurring session missing learner_id/student_id: $recurringSessionId');
      }

      // Get subject from booking request or use default
      String subject = 'Tutoring Session';
      if (recurringSession['request_id'] != null) {
        final request = await _supabase
            .from('booking_requests')
            .select('subject')
            .eq('id', recurringSession['request_id'])
            .maybeSingle();
        subject = request?['subject'] as String? ?? subject;
      }

      // Default duration (can be made configurable)
      const durationMinutes = 60;

      // Calculate end date (weeksAhead weeks from start)
      final endDate = startDate.add(Duration(days: weeksAhead * 7));

      // Generate sessions for each day in the schedule
      final sessionsToCreate = <Map<String, dynamic>>[];
      final currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final targetDate = DateTime(endDate.year, endDate.month, endDate.day);

      LogService.info('📊 Generation parameters: weeksAhead=$weeksAhead, currentDate=$currentDate, targetDate=$targetDate');
      LogService.info('📊 Days to process: $days');

      // Iterate through each week
      for (var week = 0; week < weeksAhead; week++) {
        // For each day in the schedule
        for (final day in days) {
          final dayIndex = _getDayIndex(day);
          final timeStr = times[day] as String?;
          
          if (timeStr == null || timeStr.isEmpty) {
            LogService.warning('⚠️ No time found for day: $day, skipping...');
            continue;
          }
          
          LogService.debug('📅 Processing: week=$week, day=$day, time=$timeStr, dayIndex=$dayIndex');

          // Calculate date for this day in the current week
          final weekStart = currentDate.add(Duration(days: week * 7));
          // Calculate days to add to get to the target day
          // dayIndex: Monday=1, Tuesday=2, ..., Sunday=7
          // weekStart.weekday: Monday=1, Tuesday=2, ..., Sunday=7
          int daysOffset = (dayIndex - weekStart.weekday) % 7;
          if (daysOffset < 0) {
            daysOffset += 7; // Ensure positive
          }
          final sessionDate = weekStart.add(Duration(days: daysOffset));

          // Skip if before start date or after end date
          if (sessionDate.isBefore(currentDate) || sessionDate.isAfter(targetDate)) {
            LogService.debug('⏭️ Skipping session: $sessionDate (before start=$currentDate or after end=$targetDate)');
            continue;
          }
          
          // Only generate sessions from today forward (don't generate past sessions)
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          if (sessionDate.isBefore(todayDate)) {
            LogService.debug('⏭️ Skipping past session: $sessionDate (today=$todayDate)');
            continue;
          }

          // Parse time
          final timeParts = timeStr.replaceAll(' ', '').split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minuteStr = timeParts.length > 1 
              ? timeParts[1].replaceAll(RegExp(r'[^\d]'), '')
              : '0';
          final minute = int.tryParse(minuteStr) ?? 0;
          final isPM = timeStr.toUpperCase().contains('PM');
          final hour24 = isPM && hour != 12 
              ? hour + 12 
              : (hour == 12 && !isPM ? 0 : hour);

          // Format time as HH:MM:SS
          final timeFormatted = '${hour24.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
          final dateFormatted = sessionDate.toIso8601String().split('T')[0];

          // Check if session already exists
          final existingSession = await _supabase
              .from('individual_sessions')
              .select('id')
              .eq('recurring_session_id', recurringSessionId)
              .eq('scheduled_date', dateFormatted)
              .eq('scheduled_time', timeFormatted)
              .maybeSingle();

          if (existingSession != null) {
            continue; // Session already exists, skip
          }

          // Determine session location (for hybrid sessions, check per-session location)
          String sessionLocation = location;
          bool isOnsiteSession = false;
          String? sessionAddress = address;
          double transportationCostPerSession = 0.0;
          
          // For hybrid sessions, check session_locations to determine if this session is onsite
          if (location == 'hybrid') {
            // Try to get session_locations from booking_requests via recurring_sessions
            // Note: session_locations is stored in booking_requests, not recurring_sessions
            // For now, we'll use the stored transportation_cost_per_session as estimate
            // Per-session location checking will be implemented when we link booking_requests properly
            final transportationCostPerSessionFromDB = (recurringSession['transportation_cost_per_session'] as num?)?.toDouble() ?? 0.0;
            
            // For hybrid, we need to check if this specific session is onsite
            // Since we don't have direct access to session_locations here, we'll use a fallback:
            // If transportation_cost_per_session > 0, assume some sessions are onsite
            // For now, default to online (transportation will be calculated per session when needed)
            sessionLocation = 'online'; // Default for hybrid (will be updated per session)
            isOnsiteSession = false;
            sessionAddress = null;
            transportationCostPerSession = 0.0; // Will be calculated per session
          } else {
            // For non-hybrid sessions, use the main location
            isOnsiteSession = location == 'onsite';
            sessionAddress = isOnsiteSession ? address : null;
            
            // Get transportation cost per session (from recurring_sessions)
            final transportationCostPerSessionFromDB = (recurringSession['transportation_cost_per_session'] as num?)?.toDouble() ?? 0.0;
            
            if (isOnsiteSession) {
              // Use stored transportation cost if available, otherwise use 0 (will be calculated when session completes)
              transportationCostPerSession = transportationCostPerSessionFromDB;
            } else {
              transportationCostPerSession = 0.0; // No transportation for online sessions
            }
          }
          
          // Set learner_id and parent_id correctly based on learner_type
          // If learner_type is 'learner': learner_id = studentId, parent_id = null
          // If learner_type is 'parent': learner_id = null, parent_id = studentId
          // Note: When a parent books, studentId is the parent's ID
          // Database uses learner_type, not student_type (schema was migrated)
          final learnerType = recurringSession['learner_type'] as String? ?? recurringSession['student_type'] as String?;
          final learnerId = (learnerType == 'learner') ? studentId : null;
          final parentId = (learnerType == 'parent') ? studentId : null;
          
          final sessionData = <String, dynamic>{
            'recurring_session_id': recurringSessionId,
            'tutor_id': tutorId,
            'learner_id': learnerId,
            'parent_id': parentId,
            'subject': subject,
            'scheduled_date': dateFormatted,
            'scheduled_time': timeFormatted,
            'duration_minutes': durationMinutes,
            'location': sessionLocation, // Only 'online' or 'onsite'
            'address': sessionAddress, // Column is 'address', not 'onsite_address'
            'transportation_cost': transportationCostPerSession, // Transportation cost for onsite sessions only (0 for online)
            'status': 'scheduled',
            'created_at': DateTime.now().toIso8601String(),
          };

          sessionsToCreate.add(sessionData);
          LogService.debug('✅ Added session: $dateFormatted $timeFormatted');
        }
      }

      LogService.info('📊 Total sessions to create: ${sessionsToCreate.length}');

      // Batch insert sessions (in chunks of 100 to avoid payload limits)
      if (sessionsToCreate.isNotEmpty) {
        const chunkSize = 100;
        int totalInserted = 0;
        for (var i = 0; i < sessionsToCreate.length; i += chunkSize) {
          final chunk = sessionsToCreate.skip(i).take(chunkSize).toList();
          try {
            LogService.info('💾 Inserting chunk ${i ~/ chunkSize + 1} (${chunk.length} sessions)...');
            LogService.debug('📋 Sample session data: ${chunk.first}');
            
            // Log current user context for RLS debugging
            final currentUserId = _supabase.auth.currentUser?.id;
            LogService.info('👤 Current user (auth.uid()): $currentUserId');
            LogService.info('📋 Sample session tutor_id: ${chunk.first['tutor_id']}');
            LogService.info('📋 Sample session learner_id: ${chunk.first['learner_id']}');
            LogService.info('📋 Sample session parent_id: ${chunk.first['parent_id']}');
            LogService.info('🔍 RLS Check: auth.uid() should match tutor_id, learner_id, or parent_id');
            
            // Validate user context matches before insert
            if (currentUserId == null) {
              throw Exception('No authenticated user found. Cannot insert sessions without user context.');
            }
            
            // Check if current user matches any of the IDs in the session
            final sampleSession = chunk.first;
            final tutorId = sampleSession['tutor_id'] as String?;
            final learnerId = sampleSession['learner_id'] as String?;
            final parentId = sampleSession['parent_id'] as String?;
            
            final userMatches = currentUserId == tutorId || 
                               currentUserId == learnerId || 
                               currentUserId == parentId;
            
            if (!userMatches) {
              LogService.warning('⚠️ User context mismatch detected:');
              LogService.warning('   auth.uid(): $currentUserId');
              LogService.warning('   tutor_id: $tutorId');
              LogService.warning('   learner_id: $learnerId');
              LogService.warning('   parent_id: $parentId');
              LogService.warning('   RLS policy requires auth.uid() to match one of these IDs');
              LogService.warning('   This insert may fail due to RLS policy violation');
            } else {
              LogService.info('✅ User context validated: auth.uid() matches session participant');
            }
            
            final insertResponse = await _supabase.from('individual_sessions').insert(chunk).select('id');
            totalInserted += chunk.length;
            
            LogService.success('✅ Inserted ${chunk.length} individual sessions (${totalInserted}/${sessionsToCreate.length})');
            if (insertResponse.isNotEmpty) {
              LogService.debug('✅ Sample inserted IDs: ${insertResponse.take(3).map((s) => s['id']).join(', ')}');
            }
          } catch (e, stackTrace) {
            LogService.error('❌ Error inserting chunk ${i ~/ chunkSize + 1}: $e');
            LogService.error('📚 Stack trace: $stackTrace');
            LogService.error('❌ Failed to insert ${chunk.length} sessions. Sample dates: ${chunk.take(3).map((s) => '${s['scheduled_date']} ${s['scheduled_time']}').join(', ')}');
            LogService.error('❌ Sample session data that failed: ${chunk.first}');
            
            // Enhanced RLS debugging
            final currentUserId = _supabase.auth.currentUser?.id;
            final sampleSession = chunk.first;
            LogService.error('🔍 RLS Debug Info:');
            LogService.error('   Current user (auth.uid()): $currentUserId');
            LogService.error('   Session tutor_id: ${sampleSession['tutor_id']}');
            LogService.error('   Session learner_id: ${sampleSession['learner_id']}');
            LogService.error('   Session parent_id: ${sampleSession['parent_id']}');
            LogService.error('   Match check: tutor_id=${currentUserId == sampleSession['tutor_id']}, learner_id=${currentUserId == sampleSession['learner_id']}, parent_id=${currentUserId == sampleSession['parent_id']}');
            
            if (e.toString().contains('row-level security')) {
              LogService.error('⚠️ RLS Policy Violation Detected!');
              LogService.error('   The INSERT policy requires: auth.uid() = tutor_id OR auth.uid() = learner_id OR auth.uid() = parent_id');
              LogService.error('   Verify the INSERT policy exists: Run FIX_INDIVIDUAL_SESSIONS_RLS_COMPLETE.sql');
            }
            
            rethrow; // Re-throw to be caught by outer catch
          }
        }
        LogService.success('🎉 Successfully generated ${totalInserted} individual sessions for recurring session: $recurringSessionId');
        return totalInserted;
      } else {
        LogService.warning('⚠️ No new individual sessions to generate for recurring session: $recurringSessionId. This might indicate an issue with date calculation or schedule.');
        LogService.warning('⚠️ Check: startDate=$startDate, days=$days, times=$times, weeksAhead=$weeksAhead');
        return 0;
      }
    } catch (e, stackTrace) {
      LogService.error('❌ Error generating individual sessions: $e');
      LogService.error('📚 Stack trace: $stackTrace');
      rethrow;
    }
  }
}