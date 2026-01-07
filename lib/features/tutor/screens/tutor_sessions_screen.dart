import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/booking/services/recurring_session_service.dart';
import '../../../features/booking/services/individual_session_service.dart';
import '../../../features/booking/services/session_lifecycle_service.dart';
import '../../../features/booking/services/trial_session_service.dart';
import '../../../features/booking/services/session_reschedule_service.dart';
import '../../../features/booking/models/trial_session_model.dart';
import '../../../features/booking/utils/session_date_utils.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/google_calendar_service.dart';
import '../../../core/services/google_calendar_auth_service.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/services/error_handler_service.dart';
import '../../../features/sessions/services/meet_service.dart';
import 'tutor_session_detail_full_screen.dart';

class TutorSessionsScreen extends StatefulWidget {
  const TutorSessionsScreen({Key? key}) : super(key: key);

  @override
  State<TutorSessionsScreen> createState() => _TutorSessionsScreenState();
}

class _TutorSessionsScreenState extends State<TutorSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  final Map<String, bool> _sessionLoadingStates = {};
  String _selectedFilter = 'upcoming'; // upcoming, all, past (upcoming shown first)
  bool? _isCalendarConnected;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _checkCalendarConnection();
    _startCountdownTimer();
  }
  
  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  /// Start countdown timer to update session countdowns every minute
  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        safeSetState(() {
          // Trigger rebuild to update countdowns
        });
      }
    });
  }
  
  /// Check if Google Calendar is connected
  Future<void> _checkCalendarConnection() async {
    try {
      final isConnected = await GoogleCalendarAuthService.isAuthenticated();
      if (mounted) {
        safeSetState(() {
          _isCalendarConnected = isConnected;
        });
      }
    } catch (e) {
      LogService.warning('Error checking calendar connection: $e');
    }
  }

  Future<void> _loadSessions() async {
    safeSetState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      List<Map<String, dynamic>> allSessions = [];
      
      // 1. Load individual sessions
      try {
        List<Map<String, dynamic>> individualSessions = [];
        if (_selectedFilter == 'upcoming' || _selectedFilter == 'all') {
          individualSessions =
              await IndividualSessionService.getTutorUpcomingSessions(
                limit: 50,
              );
        }
        if (_selectedFilter == 'past' || _selectedFilter == 'all') {
          final pastSessions =
              await IndividualSessionService.getTutorPastSessions(limit: 50);
          if (_selectedFilter == 'all') {
            individualSessions.addAll(pastSessions);
          } else {
            individualSessions = pastSessions;
          }
        }
        
        // Mark as individual sessions
        for (var session in individualSessions) {
          session['_sessionType'] = 'individual';
        }
        allSessions.addAll(individualSessions);
      } catch (e) {
        LogService.debug('⚠️ Could not load individual sessions: $e');
      }
      
      // 2. Load trial sessions
      try {
        final trialSessions = await TrialSessionService.getTutorTrialSessions();
        
        // Convert trial sessions to map format and determine status
        for (var trial in trialSessions) {
          // Determine if session is expired (time passed, not paid, not approved)
          // Expired = time passed AND (not paid OR not approved)
          final isTimePassed = SessionDateUtils.isSessionExpired(trial);
          final isPaid = trial.paymentStatus.toLowerCase() == 'paid';
          final isApproved = trial.status == 'approved' || trial.status == 'scheduled';
          final isExpired = isTimePassed && (!isPaid || !isApproved) && trial.status != 'cancelled';
          
          // Determine if session is cancelled (user deleted the request)
          final isCancelled = trial.status == 'cancelled';
          
          // Determine if session is upcoming (approved and time hasn't passed)
          final isUpcoming = isApproved && !isTimePassed && !isCancelled;
          
          // Determine if session is past (time passed and paid, or completed)
          final isPast = (isTimePassed && isPaid) || trial.status == 'completed' || isExpired || isCancelled;
          
          // Filter based on selected filter
          // "All" should exclude expired, cancelled, and unattended past sessions
          // "Upcoming" should only show approved sessions that haven't started
          // "Past" should show completed, expired, cancelled, or paid past sessions
          bool shouldInclude = false;
          if (_selectedFilter == 'all') {
            // Exclude expired, cancelled, and unattended past sessions from "All"
            shouldInclude = !isExpired && !isCancelled && !(isTimePassed && !isPaid);
          } else if (_selectedFilter == 'upcoming') {
            shouldInclude = isUpcoming;
          } else if (_selectedFilter == 'past') {
            shouldInclude = isPast;
          }
          
          if (shouldInclude) {
            // CRITICAL FIX: For tutor sessions, show the REQUESTER (who made the booking)
            // This is what the tutor sees - parent name if parent booked, student name if student booked
            String studentName = 'Student';
            String? studentAvatar;
            String? requesterType;
            try {
              // Priority: Use requester_id (who made the booking) for display
              final requesterId = trial.requesterId;
              final learnerId = trial.learnerId;
              
              // First, try to fetch requester profile (who made the booking)
              if (requesterId.isNotEmpty) {
                final requesterProfile = await SupabaseService.client
                    .from('profiles')
                    .select('full_name, avatar_url, user_type, email')
                    .eq('id', requesterId)
                    .limit(1)
                    .maybeSingle();
                    
                if (requesterProfile != null) {
                  requesterType = requesterProfile['user_type'] as String?;
                  
                  // Extract name with proper fallbacks
                  final fullName = requesterProfile['full_name'] as String?;
                  if (fullName != null && fullName.trim().isNotEmpty && 
                      fullName.toLowerCase() != 'user' && 
                      fullName.toLowerCase() != 'null' &&
                      fullName.toLowerCase() != 'student' &&
                      fullName.toLowerCase() != 'parent') {
                    studentName = fullName.trim();
                  } else {
                    // Try email as fallback
                    final email = requesterProfile['email'] as String?;
                    if (email != null && email.trim().isNotEmpty) {
                      final emailName = email.split('@').first.trim();
                      if (emailName.isNotEmpty && 
                          emailName.toLowerCase() != 'user' &&
                          emailName.toLowerCase() != 'student' &&
                          emailName.toLowerCase() != 'parent') {
                        studentName = emailName[0].toUpperCase() + emailName.substring(1);
                      }
                    }
                  }
                  
                  // Get avatar URL
                  studentAvatar = requesterProfile['avatar_url'] as String?;
                  
                  LogService.debug('✅ Loaded requester profile: $studentName (user_type: $requesterType, ID: $requesterId)');
                } else {
                  LogService.warning('⚠️ Requester profile not found for ID: $requesterId, falling back to learner');
                }
              }
              
              // Fallback: If requester profile not found, use learner profile
              if (studentName == 'Student' && learnerId.isNotEmpty) {
                final learnerProfile = await SupabaseService.client
                    .from('profiles')
                    .select('full_name, avatar_url, user_type, email')
                    .eq('id', learnerId)
                    .limit(1)
                    .maybeSingle();
                    
                if (learnerProfile != null) {
                  requesterType = learnerProfile['user_type'] as String?;
                  
                  final fullName = learnerProfile['full_name'] as String?;
                  if (fullName != null && fullName.trim().isNotEmpty && 
                      fullName.toLowerCase() != 'user' && 
                      fullName.toLowerCase() != 'null') {
                    studentName = fullName.trim();
                  } else {
                    final email = learnerProfile['email'] as String?;
                    if (email != null && email.trim().isNotEmpty) {
                      final emailName = email.split('@').first.trim();
                      if (emailName.isNotEmpty && emailName.toLowerCase() != 'user') {
                        studentName = emailName[0].toUpperCase() + emailName.substring(1);
                      }
                    }
                  }
                  
                  if (studentAvatar == null) {
                    studentAvatar = learnerProfile['avatar_url'] as String?;
                  }
                  
                  LogService.debug('✅ Loaded learner profile as fallback: $studentName (ID: $learnerId)');
                }
              }
            } catch (e) {
              LogService.error('Could not fetch requester/learner profile for trial session: $e');
            }
            
            // Convert TrialSession to Map for consistency
            final sessionMap = {
              '_sessionType': 'trial',
              'id': trial.id,
              'tutor_id': trial.tutorId,
              'learner_id': trial.learnerId,
              'parent_id': trial.parentId,
              'requester_id': trial.requesterId,
              'scheduled_date': trial.scheduledDate.toIso8601String().split('T')[0],
              'scheduled_time': trial.scheduledTime,
              'duration_minutes': trial.durationMinutes,
              'subject': trial.subject,
              'location': trial.location,
              'address': null, // TrialSession doesn't have address field
              'status': isExpired ? 'expired' : (isCancelled ? 'cancelled' : trial.status),
              'payment_status': trial.paymentStatus,
              'trial_fee': trial.trialFee,
              'meet_link': trial.meetLink,
              'rejection_reason': trial.rejectionReason,
              'created_at': trial.createdAt.toIso8601String(),
              'updated_at': trial.updatedAt?.toIso8601String(),
              'student_name': studentName, // Pre-fetched requester/learner name
              'student_avatar_url': studentAvatar, // Pre-fetched requester/learner avatar
              'requester_type': requesterType, // Store requester type for display
            };
            allSessions.add(sessionMap);
          }
        }
      } catch (e) {
        LogService.debug('⚠️ Could not load trial sessions: $e');
      }

      // 3. Deduplicate sessions by ID and improve student name fetching
      // Also fetch student names for individual sessions that don't have them
      final Map<String, Map<String, dynamic>> uniqueSessions = {};
      for (var session in allSessions) {
        final sessionId = session['id']?.toString();
        if (sessionId != null && sessionId.isNotEmpty) {
          // For individual sessions, fetch student name if missing
          if (session['_sessionType'] == 'individual') {
            final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
            
            // First, try to get student name from recurring_sessions.learner_name
            if (recurringData != null) {
              final learnerName = recurringData['learner_name'] as String?;
              if (learnerName != null && learnerName.trim().isNotEmpty && 
                  learnerName.toLowerCase() != 'user' &&
                  learnerName.toLowerCase() != 'student' &&
                  learnerName.toLowerCase() != 'parent') {
                session['student_name'] = learnerName.trim();
                session['student_avatar_url'] = recurringData['learner_avatar_url'] as String?;
                LogService.debug('✅ Using learner_name from recurring_sessions: ${learnerName.trim()}');
              }
            }
            
            // Fallback: If not found in recurring_sessions, fetch from profiles using learner_id/parent_id
            if (session['student_name'] == null || session['student_name'] == 'Student') {
              try {
                final learnerId = session['learner_id'] as String?;
                final parentId = session['parent_id'] as String?;
                final studentId = learnerId ?? parentId;
                
                if (studentId != null && studentId.isNotEmpty) {
                  final studentProfile = await SupabaseService.client
                      .from('profiles')
                      .select('full_name, avatar_url')
                      .eq('id', studentId)
                      .maybeSingle();
                  
                  if (studentProfile != null) {
                    final fullName = studentProfile['full_name'] as String?;
                    if (fullName != null && fullName.trim().isNotEmpty && 
                        fullName.toLowerCase() != 'user' &&
                        fullName.toLowerCase() != 'student' &&
                        fullName.toLowerCase() != 'parent') {
                      session['student_name'] = fullName.trim();
                      if (session['student_avatar_url'] == null) {
                        session['student_avatar_url'] = studentProfile['avatar_url'] as String?;
                      }
                      LogService.debug('✅ Fetched student name from profile for individual session: ${fullName.trim()}');
                    }
                  }
                }
              } catch (e) {
                LogService.warning('Could not fetch student name for individual session: $e');
              }
            }
          }
          
          // Deduplicate: prefer sessions with actual student names over "Student"
          if (!uniqueSessions.containsKey(sessionId)) {
            uniqueSessions[sessionId] = session;
          } else {
            final existing = uniqueSessions[sessionId]!;
            final existingName = existing['student_name'] as String? ?? 'Student';
            final newName = session['student_name'] as String? ?? 'Student';
            
            // Prefer the one with a real name (not "Student")
            if (existingName == 'Student' && newName != 'Student') {
              uniqueSessions[sessionId] = session;
            } else if (existingName != 'Student' && newName == 'Student') {
              // Keep existing (better one)
              continue;
            } else {
              // Both have same quality, prefer the newer one (trial over individual if same ID)
              if (session['_sessionType'] == 'trial' && existing['_sessionType'] != 'trial') {
                uniqueSessions[sessionId] = session;
              }
            }
          }
        }
      }
      
      // Remove any sessions with student_name = 'Student' if there's a better one for the same date/time
      final filteredSessions = <Map<String, dynamic>>[];
      for (var session in uniqueSessions.values) {
        final sessionDate = session['scheduled_date'] as String?;
        final sessionTime = session['scheduled_time'] as String?;
        final studentName = session['student_name'] as String? ?? 'Student';
        
        // Skip if this is a "Student" session and there's another session with same date/time and real name
        if (studentName == 'Student' && sessionDate != null && sessionTime != null) {
          final hasBetterSession = uniqueSessions.values.any((s) {
            if (s['id'] == session['id']) return false; // Same session
            final sDate = s['scheduled_date'] as String?;
            final sTime = s['scheduled_time'] as String?;
            final sName = s['student_name'] as String? ?? 'Student';
            return sDate == sessionDate && 
                   sTime == sessionTime && 
                   sName != 'Student';
          });
          
          if (hasBetterSession) {
            LogService.debug('⚠️ Skipping duplicate "Student" session: ${session['id']}');
            continue; // Skip this one
          }
        }
        
        filteredSessions.add(session);
      }
      
      allSessions = filteredSessions;

      // 4. Filter and sort all sessions
      List<Map<String, dynamic>> filtered = allSessions;

        if (_selectedFilter == 'upcoming') {
        filtered = allSessions.where((s) {
          final sessionType = s['_sessionType'] as String?;
            final status = s['status'] as String;
          
          if (sessionType == 'trial') {
            // For trial sessions: check date+time, must be approved/scheduled, not expired/cancelled
            final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
            final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
            final timeParts = scheduledTime.split(':');
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
            final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
            
            return sessionDateTime.isAfter(now) &&
                   (status == 'approved' || status == 'scheduled') &&
                   status != 'expired' &&
                   status != 'cancelled';
          } else {
            // For individual sessions: check date+time
            final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
            final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
            final timeParts = scheduledTime.split(':');
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
            final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
            
            return sessionDateTime.isAfter(now) &&
                (status == 'scheduled' || status == 'in_progress');
          }
          }).toList();
        } else if (_selectedFilter == 'past') {
        filtered = allSessions.where((s) {
          final sessionType = s['_sessionType'] as String?;
            final status = s['status'] as String;
          
          if (sessionType == 'trial') {
            // For trial sessions: expired, cancelled, completed, or time passed
            final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
            final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
            final timeParts = scheduledTime.split(':');
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
            final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
            
            return sessionDateTime.isBefore(now) ||
                   status == 'expired' ||
                   status == 'cancelled' ||
                   status == 'completed';
          } else {
            // For individual sessions
            final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
            final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
            final timeParts = scheduledTime.split(':');
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
            final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
            
            return sessionDateTime.isBefore(now) ||
                status == 'completed' ||
                status == 'cancelled';
          }
        }).toList();
      } else if (_selectedFilter == 'all') {
        // Filter out expired, cancelled, and unattended past sessions from "All"
        filtered = allSessions.where((s) {
          final sessionType = s['_sessionType'] as String?;
          final status = s['status'] as String;
          final paymentStatus = (s['payment_status'] as String? ?? '').toLowerCase();
          final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed';
          
          if (sessionType == 'trial') {
            // Exclude expired, cancelled, and unattended past sessions
            final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
            final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
            final timeParts = scheduledTime.split(':');
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
            final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
            final isTimePassed = sessionDateTime.isBefore(now);
            
            // Exclude if expired, cancelled, or time passed without payment
            if (status == 'expired' || status == 'cancelled') {
              return false;
            }
            if (isTimePassed && !isPaid) {
              return false; // Exclude unattended past sessions
            }
            return true;
          } else {
            // For individual sessions, exclude cancelled
            return status != 'cancelled';
          }
          }).toList();
        }

      // Sort by scheduled date+time
        filtered.sort((a, b) {
          final aDate = DateTime.parse(a['scheduled_date'] as String);
        final aTime = a['scheduled_time'] as String? ?? '00:00';
        final aTimeParts = aTime.split(':');
        final aHour = int.tryParse(aTimeParts[0]) ?? 0;
        final aMinute = aTimeParts.length > 1 ? (int.tryParse(aTimeParts[1]) ?? 0) : 0;
        final aDateTime = DateTime(aDate.year, aDate.month, aDate.day, aHour, aMinute);
        
          final bDate = DateTime.parse(b['scheduled_date'] as String);
        final bTime = b['scheduled_time'] as String? ?? '00:00';
        final bTimeParts = bTime.split(':');
        final bHour = int.tryParse(bTimeParts[0]) ?? 0;
        final bMinute = bTimeParts.length > 1 ? (int.tryParse(bTimeParts[1]) ?? 0) : 0;
        final bDateTime = DateTime(bDate.year, bDate.month, bDate.day, bHour, bMinute);
        
          if (_selectedFilter == 'upcoming' || _selectedFilter == 'all') {
          return aDateTime.compareTo(bDateTime); // Upcoming: earliest first
          } else {
          return bDateTime.compareTo(aDateTime); // Past: latest first
        }
      });

      // Only fall back to recurring sessions if there are NO individual or trial sessions at all
      // Don't add recurring sessions if we already have trial/individual sessions (prevents duplicates)
      if (filtered.isEmpty && allSessions.isEmpty) {
        // Fallback to recurring sessions ONLY if no other sessions exist
        final sessions = await RecurringSessionService.getTutorRecurringSessions(
          status: _selectedFilter == 'all' ? null : _selectedFilter,
        );

        // Mark as recurring sessions
        for (var session in sessions) {
          session['_sessionType'] = 'recurring';
        }
        allSessions.addAll(sessions);

      // Filter for upcoming/past if needed
        List<Map<String, dynamic>> recurringFiltered = sessions;

      if (_selectedFilter == 'upcoming') {
          recurringFiltered = sessions.where((s) {
          final startDate = DateTime.parse(s['start_date'] as String);
          return startDate.isAfter(now) && s['status'] == 'active';
        }).toList();
      } else if (_selectedFilter == 'past') {
          recurringFiltered = sessions.where((s) {
          final startDate = DateTime.parse(s['start_date'] as String);
          return startDate.isBefore(now) || s['status'] == 'completed';
        }).toList();
      } else if (_selectedFilter == 'all') {
        // Sort by priority: upcoming first, then active, then past
          recurringFiltered.sort((a, b) {
          final aDate = DateTime.parse(a['start_date'] as String);
          final bDate = DateTime.parse(b['start_date'] as String);
          final aStatus = a['status'] as String;
          final bStatus = b['status'] as String;

          // Upcoming (active and future date) first
          final aIsUpcoming = aDate.isAfter(now) && aStatus == 'active';
          final bIsUpcoming = bDate.isAfter(now) && bStatus == 'active';
          if (aIsUpcoming && !bIsUpcoming) return -1;
          if (!aIsUpcoming && bIsUpcoming) return 1;

          // Then active (current or past start but still active)
          if (aStatus == 'active' && bStatus != 'active') return -1;
          if (aStatus != 'active' && bStatus == 'active') return 1;

          // Then by date (earliest first for upcoming, latest first for past)
          if (aIsUpcoming || bIsUpcoming) {
            return aDate.compareTo(bDate); // Upcoming: earliest first
          } else {
            return bDate.compareTo(aDate); // Past: latest first
          }
        });
      }

        safeSetState(() {
          _sessions = recurringFiltered;
          _isLoading = false;
        });
      } else {
      safeSetState(() {
        _sessions = filtered;
        _isLoading = false;
      });
      }
    } catch (e) {
      LogService.error('Error loading sessions: $e');
      safeSetState(() => _isLoading = false);
      if (mounted) {
        ErrorHandlerService.showErrorSnackbar(
          context,
          e,
          'Failed to load sessions',
          () => _loadSessions(), // Retry callback
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button in bottom nav
        title: Text(
          'Sessions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips (like notification screen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Show "Upcoming" first as requested
                  _buildFilterChip(
                    'upcoming',
                    'Upcoming (${_getCountForFilter('upcoming')})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('all', 'All (${_getCountForFilter('all')})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'past',
                    'Past (${_getCountForFilter('past')})',
                  ),
                ],
              ),
            ),
          ),
          // Sessions List
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, index) => ShimmerLoading.sessionCard(),
                  )
                : _sessions.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadSessions,
                    color: AppTheme.primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        return _buildSessionCard(_sessions[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
}



  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        safeSetState(() {
          _selectedFilter = filter;
        });
        _loadSessions();
      },
      selectedColor: AppTheme.primaryColor, // Deep blue background
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected
            ? Colors.white
            : AppTheme.textDark, // White text on selected
      ),
    );
  }

  int _getCountForFilter(String filter) {
      final now = DateTime.now();
    
    if (filter == 'all') {
      // Count sessions excluding expired, cancelled, and unattended past sessions
      return _sessions.where((s) {
        final sessionType = s['_sessionType'] as String?;
        final status = s['status'] as String;
        final paymentStatus = (s['payment_status'] as String? ?? '').toLowerCase();
        final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed';
        
        if (sessionType == 'trial') {
          // Exclude expired, cancelled, and unattended past sessions
          final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
          final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
          final timeParts = scheduledTime.split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
          final isTimePassed = sessionDateTime.isBefore(now);
          
          if (status == 'expired' || status == 'cancelled') {
            return false;
          }
          if (isTimePassed && !isPaid) {
            return false; // Exclude unattended past sessions
          }
          return true;
        } else {
          // For individual sessions, exclude cancelled
          return status != 'cancelled';
        }
      }).length;
    } else if (filter == 'upcoming') {
      return _sessions.where((s) {
        final sessionType = s['_sessionType'] as String?;
          final status = s['status'] as String;
        
        if (sessionType == 'trial') {
          // Check date+time for trial sessions
          final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
          final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
          final timeParts = scheduledTime.split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
          
          return sessionDateTime.isAfter(now) &&
                 (status == 'approved' || status == 'scheduled') &&
                 status != 'expired' &&
                 status != 'cancelled';
        } else if (sessionType == 'individual' || s.containsKey('scheduled_date')) {
          // Check date+time for individual sessions
          final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
          final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
          final timeParts = scheduledTime.split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
          
          return sessionDateTime.isAfter(now) &&
              (status == 'scheduled' || status == 'in_progress');
        } else {
          // Recurring sessions
          final startDate = DateTime.parse(s['start_date'] as String);
          return startDate.isAfter(now) && s['status'] == 'active';
        }
      }).length;
    } else if (filter == 'past') {
      return _sessions.where((s) {
        final sessionType = s['_sessionType'] as String?;
          final status = s['status'] as String;
        
        if (sessionType == 'trial') {
          // Check date+time for trial sessions
          final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
          final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
          final timeParts = scheduledTime.split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
          
          return sessionDateTime.isBefore(now) ||
                 status == 'expired' ||
                 status == 'cancelled' ||
                 status == 'completed';
        } else if (sessionType == 'individual' || s.containsKey('scheduled_date')) {
          // Check date+time for individual sessions
          final scheduledDate = DateTime.parse(s['scheduled_date'] as String);
          final scheduledTime = s['scheduled_time'] as String? ?? '00:00';
          final timeParts = scheduledTime.split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
          
          return sessionDateTime.isBefore(now) ||
              status == 'completed' ||
              status == 'cancelled';
        } else {
          // Recurring sessions
          final startDate = DateTime.parse(s['start_date'] as String);
          return startDate.isBefore(now) || s['status'] == 'completed';
        }
      }).length;
    }
    return 0;
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget.noSessions();
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    // Detect session type
    final sessionType = session['_sessionType'] as String?;
    final isTrialSession = sessionType == 'trial';
    final isIndividualSession = sessionType == 'individual' ||
        (session.containsKey('scheduled_date') &&
         session.containsKey('scheduled_time') &&
         !isTrialSession);

    final status = session['status'] as String;
    String studentName = 'Student';
    String? studentAvatar;
    String location = 'online';
    String? address;
    DateTime? sessionDate;
    String? sessionTime;
    String? subject;
    int? frequency;
    int totalSessions = 0;
    List<String> days = [];
    Map<String, String> times = {};
    DateTime? startDate;
    String? paymentStatus;
    String? meetLink;
    bool isExpired = false;
    bool isCancelled = false;
    String? calendarEventId;

    if (isTrialSession) {
      // Trial session data
      try {
        final trial = TrialSession.fromJson(session);
        // Use pre-fetched student name from session map (fetched in _loadSessions)
        studentName = session['student_name'] as String? ?? 'Student';
        studentAvatar = session['student_avatar_url'] as String?;
        location = trial.location;
        address = null; // TrialSession doesn't have address field
        sessionDate = trial.scheduledDate;
        sessionTime = trial.scheduledTime;
        subject = trial.subject;
        paymentStatus = trial.paymentStatus;
        meetLink = trial.meetLink;
        calendarEventId = session['calendar_event_id'] as String?;
        
        // Determine if expired (time passed, not paid, not approved)
        final isTimePassed = SessionDateUtils.isSessionExpired(trial);
        final isPaid = trial.paymentStatus.toLowerCase() == 'paid';
        final isApproved = trial.status == 'approved' || trial.status == 'scheduled';
        isExpired = isTimePassed && (!isPaid || !isApproved) && trial.status != 'cancelled';
        
        // Determine if cancelled (user deleted)
        isCancelled = trial.status == 'cancelled';
      } catch (e) {
        LogService.error('Error parsing trial session: $e');
        return const SizedBox.shrink();
      }
    } else if (isIndividualSession) {
      // Individual session data
      final recurringData =
          session['recurring_sessions'] as Map<String, dynamic>?;
      
      // Try to get student name from recurring_sessions first (learner_name)
      if (recurringData != null) {
        final learnerName = recurringData['learner_name'] as String?;
        if (learnerName != null && learnerName.trim().isNotEmpty && 
            learnerName.toLowerCase() != 'student' &&
            learnerName.toLowerCase() != 'user') {
          studentName = learnerName.trim();
          studentAvatar = recurringData['learner_avatar_url'] as String?;
        }
      }
      
      // Use pre-fetched student name from session map (fetched in _loadSessions)
      // If still 'Student', try to get from session data
      if (studentName == 'Student') {
        final preFetchedName = session['student_name'] as String?;
        if (preFetchedName != null && preFetchedName.trim().isNotEmpty && 
            preFetchedName.toLowerCase() != 'student' &&
            preFetchedName.toLowerCase() != 'user') {
          studentName = preFetchedName.trim();
          studentAvatar = session['student_avatar_url'] as String?;
        }
      }
      location = session['location'] as String? ?? 'online';
      // Use 'address' column (matches database schema) with fallback to 'onsite_address' for compatibility
      address = session['address'] as String? ?? session['onsite_address'] as String?;
      subject = session['subject'] as String?;
      sessionDate = DateTime.parse(session['scheduled_date'] as String);
      sessionTime = session['scheduled_time'] as String?;
      calendarEventId = session['calendar_event_id'] as String?;

      // Get recurring session info if available
      if (recurringData != null) {
        frequency = recurringData['frequency'] as int?;
        totalSessions = recurringData['total_sessions_completed'] as int? ?? 0;
        days = List<String>.from(recurringData['days'] as List? ?? []);
        times = Map<String, String>.from(recurringData['times'] as Map? ?? {});
        if (recurringData['start_date'] != null) {
          startDate = DateTime.parse(recurringData['start_date'] as String);
        }
      }
    } else {
      // Recurring session data
      studentName = session['student_name'] as String? ?? 'Student';
      studentAvatar = session['student_avatar_url'] as String?;
      location = session['location'] as String? ?? 'online';
      address = session['address'] as String?;
      frequency = session['frequency'] as int?;
      totalSessions = session['total_sessions_completed'] as int? ?? 0;
      days = List<String>.from(session['days'] as List? ?? []);
      times = Map<String, String>.from(session['times'] as Map? ?? {});
      if (session['start_date'] != null) {
        startDate = DateTime.parse(session['start_date'] as String);
      }
    }

    // Determine if session is upcoming
    final isUpcoming = _selectedFilter == 'upcoming' || 
        (sessionDate != null && sessionDate!.isAfter(DateTime.now()));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isExpired 
              ? Colors.red.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showSessionDetails(session),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isExpired 
                ? Colors.red.withOpacity(0.02)
                : Colors.white,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Trial badge and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Trial Badge
                  if (isTrialSession)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'TRIAL',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (!isTrialSession) const SizedBox.shrink(),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Color(int.parse(_getStatusColor(status).replaceFirst('#', '0xFF'))).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(int.parse(_getStatusColor(status).replaceFirst('#', '0xFF'))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Student info row
              Row(
                children: [
                  // Student avatar (slightly larger)
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: studentAvatar != null && studentAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(studentAvatar)
                        : null,
                    child: studentAvatar == null || studentAvatar.isEmpty
                        ? Text(
                            studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Student name and subject
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subject ?? 'Session',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Session in Progress indicator
              if (status == 'in_progress') ...[
                Builder(
                  builder: (context) {
                    // Check if session time has actually arrived
                    try {
                      if (sessionDate != null && sessionTime != null) {
                        final timeParts = sessionTime.split(':');
                        final hour = int.tryParse(timeParts[0]) ?? 0;
                        final minute = timeParts.length > 1 
                            ? (int.tryParse(timeParts[1].split(' ')[0]) ?? 0) 
                            : 0;
                        
                        final sessionDateTime = DateTime(
                          sessionDate.year, 
                          sessionDate.month, 
                          sessionDate.day, 
                          hour, 
                          minute
                        );
                        final now = DateTime.now();
                        final hasStarted = now.isAfter(sessionDateTime) || now.isAtSameMomentAs(sessionDateTime);
                        
                        // Only show "in progress" if the scheduled time has actually arrived
                        if (!hasStarted) {
                          return const SizedBox.shrink();
                        }
                      }
                    } catch (e) {
                      // If we can't parse the date/time, show the indicator anyway
                    }
                    
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.accentGreen.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_circle_filled_rounded,
                                color: AppTheme.accentGreen,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Session is currently in progress',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.accentGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 14),
              // Session details (date, time, location) - more compact
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // Date and time
                    if (sessionDate != null && sessionTime != null)
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatDateTime(sessionDate!, sessionTime!),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (sessionDate != null && sessionTime != null)
                      const SizedBox(height: 8),
                    // Location
                    Row(
                      children: [
                        Icon(
                          location == 'online' ? Icons.video_call : Icons.location_on,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location == 'online' ? 'Online Session' : 'On-site Session',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Countdown timer for upcoming sessions
                    if (isUpcoming && (status == 'scheduled' || status == 'in_progress') && sessionDate != null && sessionTime != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCountdownText(sessionDate!, sessionTime!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Expired session indicator
              if (isExpired) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: Colors.red[600],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This session expired and was never attended',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Action buttons
              if (isUpcoming && (status == 'scheduled' || status == 'in_progress')) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (location == 'online' && meetLink != null && meetLink.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _joinMeeting(context, meetLink!),
                          icon: Icon(
                            status == 'in_progress' ? Icons.video_call : Icons.video_call,
                            size: status == 'in_progress' ? 20 : 18,
                          ),
                          label: Text(
                            status == 'in_progress' ? 'Join Session' : 'Join Meeting',
                            style: GoogleFonts.poppins(
                              fontSize: status == 'in_progress' ? 14 : 13,
                              fontWeight: status == 'in_progress' ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status == 'in_progress' 
                                ? AppTheme.accentGreen 
                                : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: status == 'in_progress' ? 14 : 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: status == 'in_progress' ? 2 : 0,
                          ),
                        ),
                      ),
                    // Add to Calendar button
                    if ((calendarEventId == null || calendarEventId.isEmpty))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _addSessionToCalendar(session),
                          icon: Icon(
                            _isCalendarConnected == true 
                                ? Icons.calendar_today 
                                : Icons.calendar_today_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _isCalendarConnected == true
                                ? 'Add to Calendar'
                                : 'Connect & Add',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build countdown text widget
  Widget _buildCountdownText(DateTime sessionDate, String sessionTime) {
    try {
      final timeParts = sessionTime.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = timeParts.length > 1 
          ? (int.tryParse(timeParts[1].split(' ')[0]) ?? 0) 
          : 0;
      
      final sessionDateTime = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        hour,
        minute,
      );
      final now = DateTime.now();
      final difference = sessionDateTime.difference(now);
      
      String countdownText;
      if (difference.isNegative) {
        countdownText = 'Session starting now';
      } else if (difference.inDays > 0) {
        countdownText = 'Starts in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        countdownText = 'Starts in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        countdownText = 'Starts in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        countdownText = 'Starting soon';
      }
      
      return Text(
        countdownText,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
  
  /// Add session to calendar
  Future<void> _addSessionToCalendar(Map<String, dynamic> session) async {
    try {
      // Check if calendar is connected
      if (_isCalendarConnected != true) {
        final connected = await GoogleCalendarAuthService.signIn();
        if (!connected) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to connect Google Calendar'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        safeSetState(() {
          _isCalendarConnected = true;
        });
      }
      
      final sessionType = session['_sessionType'] as String?;
      final isTrialSession = sessionType == 'trial';
      
      final sessionDate = DateTime.parse(session['scheduled_date'] as String);
      final sessionTime = session['scheduled_time'] as String;
      final subject = session['subject'] as String? ?? 'Session';
      final duration = session['duration_minutes'] as int? ?? 60;
      final location = session['location'] as String? ?? 'online';
      final meetLink = isTrialSession 
          ? (session['meet_link'] as String?)
          : (session['meeting_link'] as String?);
      
      // Parse time
      final timeParts = sessionTime.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = timeParts.length > 1 
          ? (int.tryParse(timeParts[1].split(' ')[0]) ?? 0) 
          : 0;
      
      final startTime = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        hour,
        minute,
      );
      
      // Get student name
      String studentName = 'Student';
      try {
        if (isTrialSession) {
          final learnerId = session['learner_id'] as String?;
          final requesterId = session['requester_id'] as String?;
          final studentId = requesterId?.isNotEmpty == true ? requesterId : learnerId;
          
          if (studentId != null) {
            final studentProfile = await SupabaseService.client
                .from('profiles')
                .select('full_name')
                .eq('id', studentId)
                .maybeSingle();
            if (studentProfile != null) {
              studentName = studentProfile['full_name'] as String? ?? 'Student';
            }
          }
        } else {
          final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
          if (recurringData != null) {
            final learnerName = recurringData['learner_name'] as String?;
            if (learnerName != null && learnerName.trim().isNotEmpty && 
                learnerName.toLowerCase() != 'student' &&
                learnerName.toLowerCase() != 'user') {
              studentName = learnerName.trim();
            }
          }
          if (studentName == 'Student') {
            // Fallback to profiles if needed
            final learnerId = session['learner_id'] as String?;
            final parentId = session['parent_id'] as String?;
            final studentId = learnerId ?? parentId;
            if (studentId != null && studentId.isNotEmpty) {
              try {
                final studentProfile = await SupabaseService.client
                    .from('profiles')
                    .select('full_name')
                    .eq('id', studentId)
                    .maybeSingle();
                if (studentProfile != null) {
                  final fullName = studentProfile['full_name'] as String?;
                  if (fullName != null && fullName.trim().isNotEmpty && 
                      fullName.toLowerCase() != 'user' &&
                      fullName.toLowerCase() != 'student') {
                    studentName = fullName.trim();
                  }
                }
              } catch (e) {
                LogService.warning('Could not fetch student name: $e');
              }
            }
          }
        }
      } catch (e) {
        LogService.warning('Could not fetch student name: $e');
      }
      
      // Create calendar event
      final calendarEvent = await GoogleCalendarService.createSessionEvent(
        title: 'PrepSkul Session: $subject',
        startTime: startTime,
        durationMinutes: duration,
        attendeeEmails: [], // Will be populated by service
        description: 'Tutoring session with $studentName',
      );
      
      // Update session with calendar event ID and Meet link
      if (isTrialSession) {
        await SupabaseService.client
            .from('trial_sessions')
            .update({
              'calendar_event_id': calendarEvent.id,
              if (location == 'online' && calendarEvent.meetLink.isNotEmpty)
                'meet_link': calendarEvent.meetLink,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', session['id'] as String);
      } else {
        await SupabaseService.client
            .from('individual_sessions')
            .update({
              'calendar_event_id': calendarEvent.id,
              if (location == 'online' && calendarEvent.meetLink.isNotEmpty)
                'meeting_link': calendarEvent.meetLink,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', session['id'] as String);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location == 'online' && calendarEvent.meetLink.isNotEmpty
                        ? 'Session added to calendar with Meet link!'
                        : 'Session added to calendar!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Reload sessions
      _loadSessions();
    } catch (e) {
      LogService.error('Error adding session to calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to calendar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime date, String time) {
    try {
      final formattedDate = DateFormat('MMM d, yyyy').format(date);
      return '$formattedDate at $time';
    } catch (e) {
      return '${date.toString().split(' ')[0]} at $time';
    }
  }

  String _getStatusColor(String status) {
    switch (status) {
      case 'expired':
        return '#F44336'; // Red for expired
      case 'scheduled':
        return '#4CAF50'; // Green
      case 'in_progress':
        return '#2196F3'; // Blue
      case 'completed':
        return '#9E9E9E'; // Gray
      case 'cancelled':
        return '#F44336'; // Red
      case 'approved':
        return '#4CAF50'; // Green
      default:
        return '#757575'; // Gray
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'Session in Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      case 'approved':
        return 'Approved';
      default:
        return status;
    }
  }

  /// Join Google Meet session
  Future<void> _joinMeeting(BuildContext context, String meetLink) async {
    try {
      final uri = Uri.parse(meetLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LogService.success('Opened Meet link: $meetLink');
      } else {
        throw Exception('Could not launch meeting link');
      }
    } catch (e) {
      LogService.error('Error opening meeting: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textDark),
          ),
        ),
      ],
    );
  }


      Future<void> _handleStartSession(String sessionId) async {
    // CRITICAL FIX: Handle both trial sessions and individual sessions
    try {
      // First, check if this is a trial session by looking in trial_sessions table
      Map<String, dynamic>? session;
      String? location;
      String? address;
      String? meetLink;
      bool isTrialSession = false;
      
      // Try trial_sessions first
      final trialSession = await SupabaseService.client
          .from('trial_sessions')
          .select('location, onsite_address, meet_link, status, tutor_id')
          .eq('id', sessionId)
          .maybeSingle();
      
      if (trialSession != null) {
        // This is a trial session
        isTrialSession = true;
        session = trialSession;
        location = trialSession['location'] as String? ?? 'online';
        address = trialSession['onsite_address'] as String? ?? '';
        meetLink = trialSession['meet_link'] as String?;
        
        // Check if trial is approved/scheduled
        final status = trialSession['status'] as String?;
        if (status != 'approved' && status != 'scheduled') {
          throw Exception('Trial session cannot be started. Current status: $status');
        }
        
        // Check authorization
        final userId = SupabaseService.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }
        if (trialSession['tutor_id'] != userId) {
          throw Exception('Unauthorized: Only the tutor can start the session');
        }
      } else {
        // Try individual_sessions
        final individualSession = await SupabaseService.client
            .from('individual_sessions')
            .select('location, address, meeting_link, status, tutor_id')
            .eq('id', sessionId)
            .maybeSingle();
        
        if (individualSession == null) {
          throw Exception('Session not found: $sessionId');
        }
        
        session = individualSession;
        location = individualSession['location'] as String? ?? 'online';
        address = individualSession['address'] as String? ?? '';
        meetLink = individualSession['meeting_link'] as String?;
      }

      // Location should only be 'online' or 'onsite' (hybrid is a preference only)
      // If somehow 'hybrid' exists, default to online
      final sessionLocation = location == 'hybrid' ? 'online' : location;
      final isOnline = sessionLocation == 'online';

      safeSetState(() {
        _sessionLoadingStates[sessionId] = true;
      });

      if (isTrialSession) {
        // Handle trial session start
        await _startTrialSession(sessionId, isOnline ?? false);
      } else {
        // Use SessionLifecycleService for individual sessions
        await SessionLifecycleService.startSession(
          sessionId,
          isOnline: isOnline ?? false,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Session started', style: GoogleFonts.poppins()),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
      _loadSessions(); // Refresh
    } catch (e) {
      LogService.error('Error starting session: $e');
      if (mounted) {
        safeSetState(() {
          _sessionLoadingStates[sessionId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Start a trial session
  Future<void> _startTrialSession(String trialSessionId, bool isOnline) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now().toIso8601String();
      
      // Get trial session details
      final trial = await SupabaseService.client
          .from('trial_sessions')
          .select('''
            tutor_id,
            learner_id,
            parent_id,
            status,
            location,
            meet_link,
            scheduled_date,
            scheduled_time,
            duration_minutes,
            subject
          ''')
          .eq('id', trialSessionId)
          .maybeSingle();

      if (trial == null) {
        throw Exception('Trial session not found: $trialSessionId');
      }

      // Authorization check
      if (trial['tutor_id'] != userId) {
        throw Exception('Unauthorized: Only the tutor can start the session');
      }

      // Status validation
      if (trial['status'] != 'approved' && trial['status'] != 'scheduled') {
        throw Exception('Trial session cannot be started. Current status: ${trial['status']}');
      }

      final sessionLocation = trial['location'] as String;
      final isSessionOnline = sessionLocation == 'online' || (sessionLocation == 'hybrid' && isOnline);

      // Initialize meetLink variable (will be set below if needed)
      String? meetLink = trial['meet_link'] as String?;

      // Update trial session status
      await SupabaseService.client
          .from('trial_sessions')
          .update({
            'tutor_joined_at': now,
            'status': 'in_progress',
            'updated_at': now,
          })
          .eq('id', trialSessionId);

      // For online sessions: ensure Meet link exists
      if (isSessionOnline) {
        if (meetLink == null || meetLink.isEmpty) {
          // Generate Meet link if it doesn't exist
          try {
            final scheduledDate = DateTime.parse(trial['scheduled_date'] as String);
            final scheduledTime = trial['scheduled_time'] as String;
            final durationMinutes = trial['duration_minutes'] as int;
            
            meetLink = await MeetService.generateTrialMeetLink(
              trialSessionId: trialSessionId,
              tutorId: trial['tutor_id'] as String,
              studentId: trial['learner_id'] as String,
              scheduledDate: scheduledDate,
              scheduledTime: scheduledTime,
              durationMinutes: durationMinutes,
            );
            
            if (meetLink != null && meetLink.isNotEmpty) {
              await SupabaseService.client
                  .from('trial_sessions')
                  .update({'meet_link': meetLink})
                  .eq('id', trialSessionId);
              LogService.success('Meet link generated for trial session: $trialSessionId');
            } else {
              LogService.warning('Meet link generation returned null or empty');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Meet link could not be generated. Please connect Google Calendar in settings.',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          } catch (e) {
            LogService.warning('Could not generate Meet link: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Failed to generate Meet link. Please connect Google Calendar.',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            // Continue - session can still proceed
          }
        }
      }

      // Create or update individual_sessions record for consistency
      try {
        // Check if individual_sessions record exists
        final existingIndividual = await SupabaseService.client
            .from('individual_sessions')
            .select('id')
            .eq('id', trialSessionId)
            .maybeSingle();
        
        if (existingIndividual == null) {
          // Create individual_sessions record
          await SupabaseService.client
              .from('individual_sessions')
              .insert({
                'id': trialSessionId, // Use same ID for consistency
                'recurring_session_id': null,
                'tutor_id': trial['tutor_id'],
                'learner_id': trial['learner_id'],
                'parent_id': trial['parent_id'],
                'status': 'in_progress',
                'scheduled_date': trial['scheduled_date'],
                'scheduled_time': trial['scheduled_time'],
                'subject': trial['subject'],
                'duration_minutes': trial['duration_minutes'],
                'location': trial['location'],
                'meeting_link': meetLink,
                'address': null,
                'location_description': null,
                'tutor_joined_at': now,
                'session_started_at': now,
              });
        } else {
          // Update existing individual_sessions record
          await SupabaseService.client
              .from('individual_sessions')
              .update({
                'status': 'in_progress',
                'tutor_joined_at': now,
                'session_started_at': now,
                'meeting_link': meetLink,
              })
              .eq('id', trialSessionId);
        }
      } catch (e) {
        LogService.warning('Could not create/update individual_sessions record: $e');
        // Continue - trial session is still started
      }

      LogService.success('Trial session started: $trialSessionId');
    } catch (e) {
      LogService.error('Error starting trial session: $e');
      rethrow;
    }
  }


  Future<void> _handleEndSession(String sessionId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EndSessionDialog(),
    );

    if (result != null) {
      safeSetState(() {
        _sessionLoadingStates[sessionId] = true;
      });
      
      try {
        // Use SessionLifecycleService for comprehensive end flow
        await SessionLifecycleService.endSession(
          sessionId,
          tutorNotes: result['notes'] as String?,
          progressNotes: result['progressNotes'] as String?,
          homeworkAssigned: result['homework'] as String?,
          nextFocusAreas: result['nextFocus'] as String?,
          studentEngagement: result['engagement'] as int?,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Session ended', style: GoogleFonts.poppins()),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
        _loadSessions(); // Refresh
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to end session: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          safeSetState(() {
            _sessionLoadingStates[sessionId] = false;
          });
        }
      }
    }
  }

  Future<void> _openMeetLink(String meetLink) async {
    try {
      final uri = Uri.parse(meetLink);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Meet link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      LogService.error('Error opening Meet link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Meet link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLocation(String location, String? address) {
    switch (location) {
      case 'online':
        return 'Online';
      case 'onsite':
        return address ?? 'Onsite';
      default:
        // Fallback for any unexpected values (including legacy 'hybrid')
        return location == 'hybrid' ? 'Online' : location;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  String _getNextSessionDate(List<String> days, Map<String, String> times) {
    // Calculate next session date based on days and times
    final now = DateTime.now();
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final dayName = dayNames[checkDate.weekday - 1];

      if (days.contains(dayName) && times.containsKey(dayName)) {
        return '${DateFormat('EEE, MMM d').format(checkDate)} at ${times[dayName]}';
      }
    }

    return 'Check schedule';
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TutorSessionDetailFullScreen(session: session),
      ),
    );
  }

  Future<void> _handleRescheduleSession(String sessionId, bool isIndividualSession) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RescheduleSessionDialog(
        sessionId: sessionId,
        isIndividualSession: isIndividualSession,
      ),
    );

    if (result != null && result['confirmed'] == true) {
      safeSetState(() {
        _sessionLoadingStates[sessionId] = true;
      });

      try {
        await SessionRescheduleService.requestReschedule(
          sessionId: sessionId,
          proposedDate: result['proposedDate'] as DateTime,
          proposedTime: result['proposedTime'] as String,
          reason: result['reason'] as String? ?? 'Reschedule requested by tutor',
          additionalNotes: result['additionalNotes'] as String?,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reschedule request sent. Waiting for student approval.',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _loadSessions(); // Refresh
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reschedule: $e', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          safeSetState(() {
            _sessionLoadingStates[sessionId] = false;
          });
        }
      }
    }
  }

  Future<void> _handleCancelSession(String sessionId, bool isIndividualSession) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CancelSessionDialog(),
    );

    if (result != null && result['confirmed'] == true) {
      safeSetState(() {
        _sessionLoadingStates[sessionId] = true;
      });

      try {
        if (isIndividualSession) {
          await IndividualSessionService.cancelSession(
            sessionId,
            reason: result['reason'] as String? ?? 'Cancelled by tutor',
          );
        } else {
          // For trial sessions, use TrialSessionService
          await TrialSessionService.cancelApprovedTrialSession(
            sessionId: sessionId,
            cancellationReason: result['reason'] as String? ?? 'Cancelled by tutor',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Session cancelled', style: GoogleFonts.poppins()),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
        _loadSessions(); // Refresh
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel session: $e', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          safeSetState(() {
            _sessionLoadingStates[sessionId] = false;
          });
        }
      }
    }
  }
}

// Reschedule Session Dialog

class _RescheduleSessionDialog extends StatefulWidget {
  final String sessionId;
  final bool isIndividualSession;

  const _RescheduleSessionDialog({
    required this.sessionId,
    required this.isIndividualSession,
  });

  @override
  State<_RescheduleSessionDialog> createState() => _RescheduleSessionDialogState();
}

class _RescheduleSessionDialogState extends State<_RescheduleSessionDialog> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessionDetails();
  }

  Future<void> _loadSessionDetails() async {
    try {
      Map<String, dynamic>? session;
      if (widget.isIndividualSession) {
        final response = await SupabaseService.client
            .from('individual_sessions')
            .select('scheduled_date, scheduled_time')
            .eq('id', widget.sessionId)
            .maybeSingle();
        session = response;
      } else {
        final response = await SupabaseService.client
            .from('trial_sessions')
            .select('scheduled_date, scheduled_time')
            .eq('id', widget.sessionId)
            .maybeSingle();
        session = response;
      }

      if (session != null && mounted) {
        final scheduledDate = DateTime.parse(session['scheduled_date'] as String);
        final scheduledTime = session['scheduled_time'] as String? ?? '00:00';
        final timeParts = scheduledTime.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;

        setState(() {
          _selectedDate = scheduledDate;
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
        });
      }
    } catch (e) {
      LogService.error('Error loading session details: $e');
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _selectedDate != null && _selectedTime != null;

    return AlertDialog(
      title: Text('Reschedule Session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a new date and time for this session. The student will need to approve the change.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Date picker
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.softBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? DateFormat('MMM d, y').format(_selectedDate!)
                            : 'Select date',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _selectedDate != null ? AppTheme.textDark : AppTheme.textLight,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textLight),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Time picker
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.softBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Select time',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _selectedTime != null ? AppTheme.textDark : AppTheme.textLight,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textLight),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reason field
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for reschedule',
                hintText: 'E.g., "Schedule conflict"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Additional notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Additional notes (optional)',
                hintText: 'Any additional information for the student',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, {'confirmed': false}),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: (_isLoading || !isValid)
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted) {
                    final timeString = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
                    Navigator.pop(context, {
                      'confirmed': true,
                      'proposedDate': _selectedDate,
                      'proposedTime': timeString,
                      'reason': _reasonController.text.trim(),
                      'additionalNotes': _notesController.text.trim(),
                    });
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : Text('Request Reschedule', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// Cancel Session Dialog

class _CancelSessionDialog extends StatefulWidget {
  @override
  State<_CancelSessionDialog> createState() => _CancelSessionDialogState();
}

class _CancelSessionDialogState extends State<_CancelSessionDialog> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cancel Session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to cancel this session? This action cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'Please provide a reason for cancellation',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, {'confirmed': false}),
          child: Text('Keep Session', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            setState(() => _isLoading = true);
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              Navigator.pop(context, {
                'confirmed': true,
                'reason': _reasonController.text.trim(),
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : Text('Cancel Session', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// End Session Dialog

class _EndSessionDialog extends StatefulWidget {
  @override
  State<_EndSessionDialog> createState() => _EndSessionDialogState();
}

class _EndSessionDialogState extends State<_EndSessionDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('End Session', style: GoogleFonts.poppins()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add optional notes about this session:',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'E.g., "Great progress on algebra today!"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'notes': _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('End Session', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// Session Details Sheet
class _SessionDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> session;

  const _SessionDetailsSheet({required this.session});

  /// Join Google Meet session
  Future<void> _joinMeeting(BuildContext context, String meetLink) async {
    try {
      final uri = Uri.parse(meetLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LogService.success('Opened Meet link: $meetLink');
      } else {
        throw Exception('Could not launch meeting link');
      }
    } catch (e) {
      LogService.error('Error opening meeting: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIndividualSession =
        session.containsKey('scheduled_date') &&
        session.containsKey('scheduled_time');

    String studentName = 'Student';
    String location = 'online';
    String? address;
    String? locationDescription;
    DateTime? sessionDate;
    String? sessionTime;
    String? subject;
    int? frequency;
    int totalSessions = 0;
    List<String> days = [];
    Map<String, String> times = {};
    DateTime? startDate;
    double? monthlyTotal;
    String? paymentPlan;

    if (isIndividualSession) {
      final recurringData =
          session['recurring_sessions'] as Map<String, dynamic>?;
      if (recurringData != null) {
        final learnerName = recurringData['learner_name'] as String?;
        if (learnerName != null && learnerName.trim().isNotEmpty && 
            learnerName.toLowerCase() != 'student' &&
            learnerName.toLowerCase() != 'user') {
          studentName = learnerName.trim();
        }
      }
      // Use pre-fetched student name from session map (fetched in _loadSessions)
      if (studentName == 'Student') {
        final preFetchedName = session['student_name'] as String?;
        if (preFetchedName != null && preFetchedName.trim().isNotEmpty && 
            preFetchedName.toLowerCase() != 'student' &&
            preFetchedName.toLowerCase() != 'user') {
          studentName = preFetchedName.trim();
        }
      }
      location = session['location'] as String? ?? 'online';
      // Use 'address' column (matches database schema) with fallback to 'onsite_address' for compatibility
      address = session['address'] as String? ?? session['onsite_address'] as String?;
      subject = session['subject'] as String?;
      sessionDate = DateTime.parse(session['scheduled_date'] as String);
      sessionTime = session['scheduled_time'] as String?;

      if (recurringData != null) {
        frequency = recurringData['frequency'] as int?;
        totalSessions = recurringData['total_sessions_completed'] as int? ?? 0;
        days = List<String>.from(recurringData['days'] as List? ?? []);
        times = Map<String, String>.from(recurringData['times'] as Map? ?? {});
        monthlyTotal = (recurringData['monthly_total'] as num?)?.toDouble();
        paymentPlan = recurringData['payment_plan'] as String?;
        if (recurringData['start_date'] != null) {
          startDate = DateTime.parse(recurringData['start_date'] as String);
        }
      }
    } else {
      studentName = session['student_name'] as String? ?? 'Student';
      location = session['location'] as String? ?? 'online';
      address = session['address'] as String?;
      frequency = session['frequency'] as int?;
      totalSessions = session['total_sessions_completed'] as int? ?? 0;
      days = List<String>.from(session['days'] as List? ?? []);
      times = Map<String, String>.from(session['times'] as Map? ?? {});
      monthlyTotal = (session['monthly_total'] as num?)?.toDouble();
      paymentPlan = session['payment_plan'] as String?;
      if (session['start_date'] != null) {
        startDate = DateTime.parse(session['start_date'] as String);
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Session Details',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              // Details
              _buildDetailSection('Student', studentName),
              if (isIndividualSession) ...[
                if (subject != null) _buildDetailSection('Subject', subject),
                if (sessionDate != null)
                  _buildDetailSection(
                    'Date',
                    DateFormat('MMM d, y').format(sessionDate),
                  ),
                if (sessionTime != null)
                  _buildDetailSection('Time', sessionTime),
              ] else ...[
                if (frequency != null)
                  _buildDetailSection(
                    'Frequency',
                    '$frequency sessions per week',
                  ),
                if (days.isNotEmpty)
                  _buildDetailSection('Days', days.join(', ')),
                if (times.isNotEmpty)
                  _buildDetailSection('Times', times.values.join(', ')),
                if (startDate != null)
                  _buildDetailSection(
                    'Started',
                    DateFormat('MMM d, y').format(startDate),
                  ),
              ],
              _buildDetailSection('Location', location),
              if (address != null) _buildDetailSection('Address', address),
              if (isIndividualSession && 
                  locationDescription != null && 
                  locationDescription.trim().isNotEmpty)
                _buildDetailSectionWithDescription(
                  'Location Details',
                  locationDescription,
                ),
              if (paymentPlan != null && monthlyTotal != null) ...[
                _buildDetailSection(
                  'Payment Plan',
                  _formatPaymentPlan(paymentPlan),
                ),
                _buildDetailSection(
                  'Monthly Total',
                  _formatCurrency(monthlyTotal),
                ),
              ],
              if (!isIndividualSession)
                _buildDetailSection(
                  'Total Sessions',
                  '$totalSessions completed',
                ),
              _buildDetailSection(
                'Status',
                (session['status'] as String).toUpperCase(),
              ),
              // Join Session Button (for in_progress sessions with meet link)
              if ((session['status'] as String) == 'in_progress') ...[
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    // Get meet link - check both trial and individual session formats
                    final sessionType = session['_sessionType'] as String?;
                    final isTrialSession = sessionType == 'trial';
                    final meetLink = isTrialSession
                        ? (session['meet_link'] as String?)
                        : (session['meeting_link'] as String?);
                    
                    // Only show join button for online sessions with meet link
                    if (location == 'online' && meetLink != null && meetLink.isNotEmpty) {
                      return ElevatedButton.icon(
                        onPressed: () => _joinMeeting(context, meetLink),
                        icon: const Icon(Icons.video_call, size: 20),
                        label: Text(
                          'Join Session',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
              // Show meet link as text if available but not in progress
              if (isIndividualSession &&
                  session['meeting_link'] != null &&
                  location == 'online' &&
                  (session['status'] as String) != 'in_progress')
                _buildDetailSection(
                  'Meeting Link',
                  session['meeting_link'] as String,
                ),
              // Show meet link for trial sessions if available but not in progress
              if (session['_sessionType'] == 'trial' &&
                  session['meet_link'] != null &&
                  location == 'online' &&
                  (session['status'] as String) != 'in_progress')
                _buildDetailSection(
                  'Meeting Link',
                  session['meet_link'] as String,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSectionWithDescription(String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.blue[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPaymentPlan(String plan) {
    switch (plan) {
      case 'monthly':
        return 'Monthly';
      case 'biweekly':
        return 'Bi-weekly';
      case 'weekly':
        return 'Weekly';
      default:
        return plan;
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} XAF';
  }
}
