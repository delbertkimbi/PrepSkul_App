import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_service.dart';

/// Session Feedback Service
///
/// Handles collection and processing of session feedback:
/// - Student feedback (rating, review, recommendations)
/// - Tutor feedback (already handled in SessionLifecycleService)
/// - Processing feedback to update tutor ratings
/// - Displaying reviews on tutor profiles
/// - Notifying tutors of new reviews
class SessionFeedbackService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Submit student feedback for a session
  ///
  /// Collects rating, review, and recommendations from student
  /// Also handles tutor feedback with tutor-specific fields
  static Future<void> submitStudentFeedback({
    required String sessionId,
    required int rating, // 1-5
    String? review,
    String? whatWentWell,
    String? whatCouldImprove,
    bool? wouldRecommend,
    bool? learningObjectivesMet,
    int? studentProgressRating, // 1-5
    bool? wouldContinueLessons,
    // Tutor-specific fields
    String? whatWasTaught, // For tutors: what was covered
    String? learnerProgress, // For tutors: learner progress notes
    String? homeworkAssigned, // For tutors: homework given
    String? nextFocusAreas, // For tutors: next session focus
    int? studentEngagement, // For tutors: 1-5 engagement rating
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get session details to verify authorization and determine location/session type
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            learner_id, 
            parent_id, 
            tutor_id,
            status, 
            recurring_session_id,
            location
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Authorization check - must be the student, parent, or tutor
      final isStudent = session['learner_id'] == userId;
      final isParent = session['parent_id'] == userId;
      final isTutor = session['tutor_id'] == userId;

      if (!isStudent && !isParent && !isTutor) {
        throw Exception('Unauthorized: Not a participant in this session');
      }

      // Status validation - session must be completed
      if (session['status'] != 'completed') {
        throw Exception('Feedback can only be submitted for completed sessions');
      }

      // Check if feedback already exists
      final existingFeedback = await _supabase
          .from('session_feedback')
          .select('id, student_feedback_submitted_at, tutor_feedback_submitted_at')
          .eq('session_id', sessionId)
          .maybeSingle();

      final now = DateTime.now();
      final feedbackData = <String, dynamic>{
        'updated_at': now.toIso8601String(),
      };

      // Store feedback based on user role
      if (isTutor) {
        // Tutor feedback
        feedbackData['tutor_feedback_submitted_at'] = now.toIso8601String();
        // What was taught (from whatWasTaught or review)
        if (whatWasTaught != null && whatWasTaught.isNotEmpty) {
          feedbackData['tutor_notes'] = whatWasTaught;
        } else if (review != null && review.isNotEmpty) {
          feedbackData['tutor_notes'] = review;
        }
        // Learner progress (from learnerProgress or whatWentWell)
        if (learnerProgress != null && learnerProgress.isNotEmpty) {
          feedbackData['tutor_progress_notes'] = learnerProgress;
        } else if (whatWentWell != null && whatWentWell.isNotEmpty) {
          feedbackData['tutor_progress_notes'] = whatWentWell;
        }
        // Homework assigned
        if (homeworkAssigned != null && homeworkAssigned.isNotEmpty) {
          feedbackData['tutor_homework_assigned'] = homeworkAssigned;
        }
        // Next focus areas
        if (nextFocusAreas != null && nextFocusAreas.isNotEmpty) {
          feedbackData['tutor_next_focus_areas'] = nextFocusAreas;
        }
        // Student engagement rating
        if (studentEngagement != null) {
          feedbackData['tutor_student_engagement'] = studentEngagement;
        }
      } else {
        // Student/Parent feedback
        feedbackData['student_rating'] = rating;
        feedbackData['student_feedback_submitted_at'] = now.toIso8601String();
      }

      // Only add student-specific fields if not a tutor
      if (!isTutor) {
        if (review != null && review.isNotEmpty) {
          feedbackData['student_review'] = review;
        }

        if (whatWentWell != null && whatWentWell.isNotEmpty) {
          feedbackData['student_what_went_well'] = whatWentWell;
        }

        if (whatCouldImprove != null && whatCouldImprove.isNotEmpty) {
          feedbackData['student_what_could_improve'] = whatCouldImprove;
        }

        if (wouldRecommend != null) {
          feedbackData['student_would_recommend'] = wouldRecommend;
        }
      }

      if (session['recurring_session_id'] != null) {
        feedbackData['recurring_session_id'] = session['recurring_session_id'];
      }

      // Determine location type (online or onsite)
      String? locationType;
      if (session['location'] != null) {
        final location = (session['location'] as String).toLowerCase().trim();
        if (location == 'online' || location == 'onsite') {
          locationType = location;
        }
      }
      if (locationType != null) {
        feedbackData['location_type'] = locationType;
      }

      // Determine session type (trial or recurrent)
      // If recurring_session_id exists, it's a recurrent session
      // Otherwise, check if there's a trial_session linked to this individual_session
      String? sessionType;
      if (session['recurring_session_id'] != null) {
        sessionType = 'recurrent';
      } else {
        // Check if this individual_session is linked to a trial_session
        // Trial sessions might create individual_sessions, so we check by matching IDs or other criteria
        // For now, if no recurring_session_id, assume it's a trial session
        // TODO: Add proper trial_session_id tracking if needed
        sessionType = 'trial';
      }
      if (sessionType != null) {
        feedbackData['session_type'] = sessionType;
      }

      // Add enhanced learning outcomes fields
      if (learningObjectivesMet != null) {
        feedbackData['learning_objectives_met'] = learningObjectivesMet;
      }

      if (studentProgressRating != null && studentProgressRating >= 1 && studentProgressRating <= 5) {
        feedbackData['student_progress_rating'] = studentProgressRating;
      }

      if (wouldContinueLessons != null) {
        feedbackData['would_continue_lessons'] = wouldContinueLessons;
      }

      if (existingFeedback != null) {
        // Update existing feedback
        await _supabase
            .from('session_feedback')
            .update(feedbackData)
            .eq('id', existingFeedback['id']);
      } else {
        // Create new feedback record
        feedbackData['session_id'] = sessionId;
        feedbackData['created_at'] = now.toIso8601String();
        await _supabase.from('session_feedback').insert(feedbackData);

        // Update session with feedback_id
        final newFeedback = await _supabase
            .from('session_feedback')
            .select('id')
            .eq('session_id', sessionId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (newFeedback != null) {
          await _supabase
              .from('individual_sessions')
              .update({'feedback_id': newFeedback['id']})
              .eq('id', sessionId);
        }
      }

      // Process feedback to update tutor rating (only for student/parent feedback)
      if (!isTutor) {
        await processFeedback(sessionId);
        LogService.success('Student feedback submitted for session: $sessionId');
      } else {
        // Notify student/parent when tutor gives feedback
        final learnerId = session['learner_id'] as String?;
        final parentId = session['parent_id'] as String?;
        if (learnerId != null) {
          await NotificationService.createNotification(
            userId: learnerId,
            type: 'tutor_feedback',
            title: 'Tutor Feedback Received',
            message: 'Your tutor has provided feedback on your session.',
            priority: 'normal',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Feedback',
            metadata: {'session_id': sessionId},
          );
        }
        if (parentId != null && parentId != learnerId) {
          await NotificationService.createNotification(
            userId: parentId,
            type: 'tutor_feedback',
            title: 'Tutor Feedback Received',
            message: 'Your tutor has provided feedback on your child\'s session.',
            priority: 'normal',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Feedback',
            metadata: {'session_id': sessionId},
          );
        }
        LogService.success('Tutor feedback submitted for session: $sessionId');
      }
    } catch (e) {
      LogService.error('Error submitting feedback: $e');
      rethrow;
    }
  }

  /// Process feedback to update tutor ratings and display reviews
  ///
  /// Called automatically after student feedback is submitted
  static Future<void> processFeedback(String sessionId) async {
    try {
      // Get feedback with session details
      final feedback = await _supabase
          .from('session_feedback')
          .select('''
            id,
            session_id,
            student_rating,
            student_review,
            student_would_recommend,
            feedback_processed,
            tutor_rating_updated,
            review_displayed,
            individual_sessions!inner(
              tutor_id,
              status
            )
          ''')
          .eq('session_id', sessionId)
          .maybeSingle();

      if (feedback == null) {
        throw Exception('Feedback not found for session: $sessionId');
      }

      if (feedback['feedback_processed'] == true) {
        LogService.warning('Feedback already processed for session: $sessionId');
        return;
      }

      final tutorId = feedback['individual_sessions']['tutor_id'] as String;
      final studentRating = feedback['student_rating'] as int?;

      // Update tutor rating if student provided a rating
      if (studentRating != null && feedback['tutor_rating_updated'] != true) {
        await _updateTutorRating(tutorId, studentRating);
        
        // Mark rating as updated
        await _supabase
            .from('session_feedback')
            .update({
              'tutor_rating_updated': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', feedback['id']);
      }

      // Display review on tutor profile if review text exists
      if (feedback['student_review'] != null && 
          (feedback['student_review'] as String).isNotEmpty &&
          feedback['review_displayed'] != true) {
        // Review is automatically displayed via queries
        // Just mark it as displayed
        await _supabase
            .from('session_feedback')
            .update({
              'review_displayed': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', feedback['id']);
      }

      // Mark feedback as processed
      await _supabase
          .from('session_feedback')
          .update({
            'feedback_processed': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', feedback['id']);

      // Notify tutor of new review
      if (studentRating != null || 
          (feedback['student_review'] != null && 
           (feedback['student_review'] as String).isNotEmpty)) {
        await _notifyTutorOfNewReview(
          tutorId: tutorId,
          sessionId: sessionId,
          rating: studentRating,
          hasReview: feedback['student_review'] != null && 
                    (feedback['student_review'] as String).isNotEmpty,
        );
      }

      LogService.success('Feedback processed for session: $sessionId');
    } catch (e) {
      LogService.error('Error processing feedback: $e');
      // Don't rethrow - processing can be retried
    }
  }

  /// Update tutor's average rating based on new feedback
  /// IMPORTANT: Only updates rating when total_reviews >= 3
  /// Before that, admin_approved_rating is used (set to 10 temporarily)
  static Future<void> _updateTutorRating(String tutorId, int newRating) async {
    try {
      // Get current tutor profile to check admin_approved_rating and total_reviews
      final tutorProfile = await _supabase
          .from('tutor_profiles')
          .select('admin_approved_rating, total_reviews')
          .eq('user_id', tutorId)
          .maybeSingle();

      if (tutorProfile == null) {
        LogService.warning('Tutor profile not found: $tutorId');
        return;
      }

      final adminApprovedRating = tutorProfile['admin_approved_rating'] as double?;

      // Get all completed feedback with ratings for this tutor
      final allFeedback = await _supabase
          .from('session_feedback')
          .select('student_rating, individual_sessions!inner(tutor_id)')
          .eq('individual_sessions.tutor_id', tutorId)
          .not('student_rating', 'is', null);

      if (allFeedback.isEmpty) {
        return;
      }

      // Calculate average rating from real student feedback
      int totalRating = 0;
      int count = 0;

      for (final feedback in allFeedback as List) {
        final rating = feedback['student_rating'] as int?;
        if (rating != null) {
          totalRating += rating;
          count++;
        }
      }

      if (count == 0) {
        return;
      }

      final averageRating = totalRating / count;

      // Only update rating if we have at least 3 real reviews
      // Before that, admin_approved_rating is used (displayed as 10 reviews temporarily)
      if (count >= 3) {
        // Update tutor profile rating with calculated average
        await _supabase
            .from('tutor_profiles')
            .update({
              'rating': averageRating,
              'total_reviews': count,  // Real review count
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', tutorId);

        LogService.success('Updated tutor rating: $tutorId -> ${averageRating.toStringAsFixed(2)} (from $count real reviews)');
      } else {
        // Still update total_reviews count, but keep using admin_approved_rating for display
        await _supabase
            .from('tutor_profiles')
            .update({
              'total_reviews': count,  // Track real count, but display logic uses admin rating
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', tutorId);

        LogService.info('Tutor $tutorId has $count reviews (< 3), still using admin_approved_rating: ${adminApprovedRating ?? "N/A"}');
      }
    } catch (e) {
      LogService.error('Error updating tutor rating: $e');
      // Don't rethrow - rating update can be retried
    }
  }

  /// Notify tutor of new review
  static Future<void> _notifyTutorOfNewReview({
    required String tutorId,
    required String sessionId,
    int? rating,
    required bool hasReview,
  }) async {
    try {
      String message = 'You received ';
      if (rating != null) {
        message += 'a $rating-star rating';
        if (hasReview) {
          message += ' and a review';
        }
      } else if (hasReview) {
        message += 'a review';
      }
      message += ' from a student!';

      await NotificationService.createNotification(
        userId: tutorId,
        type: 'new_review',
        title: '⭐ New Review Received',
        message: message,
        priority: 'normal',
        actionUrl: '/sessions/$sessionId/feedback',
        actionText: 'View Review',
        icon: '⭐',
        metadata: {
          'session_id': sessionId,
          'rating': rating,
          'has_review': hasReview,
        },
      );
    } catch (e) {
      LogService.warning('Error notifying tutor of new review: $e');
    }
  }

  /// Get feedback for a session
  static Future<Map<String, dynamic>?> getSessionFeedback(String sessionId) async {
    try {
      final feedback = await _supabase
          .from('session_feedback')
          .select('*')
          .eq('session_id', sessionId)
          .maybeSingle();

      return feedback;
    } catch (e) {
      LogService.error('Error fetching session feedback: $e');
      return null;
    }
  }

  /// Get all reviews for a tutor
  static Future<List<Map<String, dynamic>>> getTutorReviews(String tutorId) async {
    try {
      final reviews = await _supabase
          .from('session_feedback')
          .select('''
            id,
            session_id,
            student_rating,
            student_review,
            student_what_went_well,
            student_what_could_improve,
            student_would_recommend,
            student_feedback_submitted_at,
            tutor_response,
            tutor_response_submitted_at,
            review_displayed,
            individual_sessions!inner(
              tutor_id,
              scheduled_date,
              scheduled_time
            )
          ''')
          .eq('individual_sessions.tutor_id', tutorId)
          .not('student_rating', 'is', null)
          .order('student_feedback_submitted_at', ascending: false);

      return (reviews as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // Handle case where table doesn't exist yet (migration not run)
      final errorStr = e.toString();
      if (errorStr.contains('PGRST205') || 
          errorStr.contains('Could not find the table') || 
          errorStr.contains('session_feedback')) {
        LogService.info('session_feedback table does not exist yet. Reviews will be available after migration.');
        return [];
      }
      LogService.error('Error fetching tutor reviews: $e');
      return [];
    }
  }

  /// Get tutor's average rating and review count
  static Future<Map<String, dynamic>> getTutorRatingStats(String tutorId) async {
    try {
      final reviews = await getTutorReviews(tutorId);

      if (reviews.isEmpty) {
        return {
          'average_rating': 0.0,
          'total_reviews': 0,
          'rating_distribution': <int, int>{},
        };
      }

      double totalRating = 0;
      int count = 0;
      final ratingDistribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (final review in reviews) {
        final rating = review['student_rating'] as int?;
        if (rating != null && rating >= 1 && rating <= 5) {
          totalRating += rating;
          count++;
          ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;
        }
      }

      return {
        'average_rating': count > 0 ? totalRating / count : 0.0,
        'total_reviews': count,
        'rating_distribution': ratingDistribution,
      };
    } catch (e) {
      LogService.error('Error fetching tutor rating stats: $e');
      return {
        'average_rating': 0.0,
        'total_reviews': 0,
        'rating_distribution': <int, int>{},
      };
    }
  }

  /// Check if student can submit feedback for a session
  static Future<bool> canSubmitFeedback(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final session = await _supabase
          .from('individual_sessions')
          .select('learner_id, parent_id, tutor_id, status, session_ended_at')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Must be student, parent, or tutor
      final isStudent = session['learner_id'] == userId;
      final isParent = session['parent_id'] == userId;
      final isTutor = session['tutor_id'] == userId;
      if (!isStudent && !isParent && !isTutor) {
        return false;
      }

      // Session must be completed
      if (session['status'] != 'completed') {
        return false;
      }

      // Feedback available immediately after session ends (no delay)
      return true;
    } catch (e) {
      LogService.error('Error checking if can submit feedback: $e');
      return false;
    }
  }

  /// Get time remaining until feedback can be submitted
  /// Returns null if feedback can be submitted now (no delay)
  static Future<Duration?> getTimeUntilFeedbackAvailable(String sessionId) async {
    try {
      final session = await _supabase
          .from('individual_sessions')
          .select('status')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null || session['status'] != 'completed') {
        return null; // Session not completed
      }

      // Feedback available immediately - no wait time
      return null;
    } catch (e) {
      LogService.error('Error getting time until feedback available: $e');
      return null;
    }
  }
  /// Submit tutor response to a student review
  static Future<void> submitTutorResponse({
    required String feedbackId,
    required String response,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final feedback = await _supabase
          .from('session_feedback')
          .select('id, session_id, individual_sessions!inner(tutor_id)')
          .eq('id', feedbackId)
          .maybeSingle();

      if (feedback == null) {
        throw Exception('Feedback not found: $feedbackId');
      }

      final tutorId = feedback['individual_sessions']['tutor_id'] as String;
      if (tutorId != userId) {
        throw Exception('Unauthorized: Only the tutor can respond');
      }

      final existing = await _supabase
          .from('session_feedback')
          .select('tutor_response')
          .eq('id', feedbackId)
          .maybeSingle();

      if (existing == null) {
        throw Exception('Feedback not found: $feedbackId');
      }

      if (existing['tutor_response'] != null) {
        throw Exception('You have already responded');
      }

      await _supabase
          .from('session_feedback')
          .update({
            'tutor_response': response.trim(),
            'tutor_response_submitted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', feedbackId);

      LogService.success('Tutor response submitted: $feedbackId');
    } catch (e) {
      LogService.error('Error submitting tutor response: $e');
      rethrow;
    }
  }
}
