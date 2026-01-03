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
            // Fetch student name from profile
            String studentName = 'Student';
            String? studentAvatar;
            try {
              final learnerId = trial.learnerId;
              final requesterId = trial.requesterId;
              final studentId = requesterId.isNotEmpty ? requesterId : learnerId;
              
              final studentProfile = await SupabaseService.client
                  .from('profiles')
                  .select('full_name, avatar_url')
                  .eq('id', studentId)
                  .maybeSingle();
              if (studentProfile != null) {
                studentName = studentProfile['full_name'] as String? ?? 'Student';
                studentAvatar = studentProfile['avatar_url'] as String?;
              }
            } catch (e) {
              LogService.warning('Could not fetch student name for trial session: $e');
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
              'student_name': studentName, // Pre-fetched student name
              'student_avatar_url': studentAvatar, // Pre-fetched student avatar
            };
            allSessions.add(sessionMap);
          }
        }
      } catch (e) {
        LogService.debug('⚠️ Could not load trial sessions: $e');
      }

      // 3. Filter and sort all sessions
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

      // If no sessions found, fall back to recurring sessions
      if (filtered.isEmpty) {
      // Fallback to recurring sessions
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
      studentName = recurringData?['student_name']?.toString() ?? 'Student';
      studentAvatar = recurringData?['student_avatar_url']?.toString();
      location = session['location'] as String? ?? 'online';
      address = session['onsite_address'] as String?;
      subject = session['subject'] as String?;
      sessionDate = DateTime.parse(session['scheduled_date'] as String);
      sessionTime = session['scheduled_time'] as String?;

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showSessionDetails(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Student info + Status
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: studentAvatar != null
                        ? CachedNetworkImageProvider(studentAvatar)
                        : null,
                    child: studentAvatar == null
                        ? Text(
                            studentName[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          isIndividualSession
                              ? (subject ?? 'Session') +
                                    (sessionDate != null
                                        ? ' • ${_formatDate(sessionDate)}'
                                        : '')
                              : '${frequency ?? 0}x per week • $totalSessions sessions completed',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Schedule Info - Different for individual vs recurring
              if (isIndividualSession) ...[
                // Individual session info
                if (sessionDate != null)
                  _buildInfoRow(Icons.calendar_today, _formatDate(sessionDate)),
                if (sessionTime != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, sessionTime),
                ],
                if (subject != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.book_outlined, subject),
                ],
              ] else ...[
                // Recurring session info
                if (days.isNotEmpty)
                  _buildInfoRow(Icons.calendar_today, days.join(', ')),
                if (times.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, times.values.join(', ')),
                ],
                if (startDate != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.trending_up,
                    'Started ${_formatDate(startDate)}',
                  ),
                ],
              ],
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.location_on,
                _formatLocation(location, address),
              ),
              // Countdown timer for upcoming scheduled sessions (individual or trial)
              if ((isIndividualSession || isTrialSession) && 
                  (status == 'scheduled' || status == 'approved') && 
                  sessionDate != null && 
                  sessionTime != null &&
                  !isExpired &&
                  !isCancelled) ...[
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
              // Action buttons for trial and individual sessions
              if ((isTrialSession || isIndividualSession) &&
                  (status == 'scheduled' || status == 'in_progress' || status == 'approved') &&
                  !isExpired &&
                  !isCancelled) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Join Meeting button (if online and has meet link)
                    if (location == 'online' && 
                        ((isTrialSession && meetLink != null && meetLink!.isNotEmpty) ||
                         (isIndividualSession && session['meeting_link'] != null && 
                          (session['meeting_link'] as String).isNotEmpty))) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openMeetLink(
                            isTrialSession ? meetLink! : session['meeting_link'] as String,
                          ),
                          icon: const Icon(Icons.video_call, size: 18),
                          label: Text(
                            'Join Meeting',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Start/End Session button
                    if (status == 'scheduled') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_sessionLoadingStates[session['id'] as String] ?? false)
                              ? null
                              : () => _handleStartSession(session['id'] as String),
                          icon: (_sessionLoadingStates[session['id'] as String] ?? false)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.play_arrow, size: 18),
                          label: Text(
                            (_sessionLoadingStates[session['id'] as String] ?? false)
                                ? 'Starting...'
                                : 'Start Session',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ] else if (status == 'in_progress') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_sessionLoadingStates[session['id'] as String] ?? false)
                              ? null
                              : () => _handleEndSession(session['id'] as String),
                          icon: (_sessionLoadingStates[session['id'] as String] ?? false)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.stop, size: 18),
                          label: Text(
                            (_sessionLoadingStates[session['id'] as String] ?? false)
                                ? 'Ending...'
                                : 'End Session',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                    // Add to Calendar button (if no calendar event exists)
                    if ((isIndividualSession || isTrialSession) && 
                        (status == 'scheduled' || status == 'approved') &&
                        !isExpired &&
                        !isCancelled &&
                        (session['calendar_event_id'] == null || 
                         (session['calendar_event_id'] as String? ?? '').isEmpty)) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
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
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                    // Reschedule/Cancel options (for scheduled sessions)
                    if ((isIndividualSession || isTrialSession) &&
                        (status == 'scheduled' || status == 'approved') &&
                        !isExpired &&
                        !isCancelled) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (value) {
                          if (value == 'reschedule') {
                            _handleRescheduleSession(session['id'] as String, isIndividualSession);
                          } else if (value == 'cancel') {
                            _handleCancelSession(session['id'] as String, isIndividualSession);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'reschedule',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_calendar, size: 18),
                                const SizedBox(width: 8),
                                Text('Reschedule', style: GoogleFonts.poppins(fontSize: 14)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'cancel',
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                                const SizedBox(width: 8),
                                Text('Cancel Session', style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
              // Show expired/cancelled status for trial sessions
              if (isTrialSession && (isExpired || isCancelled)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isExpired ? Colors.orange : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isExpired ? Colors.orange : Colors.red).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpired ? Icons.access_time : Icons.cancel,
                        size: 18,
                        color: isExpired ? Colors.orange : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isExpired 
                              ? 'Session expired - payment not completed'
                              : 'Session cancelled',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isExpired ? Colors.orange : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Next Session (if active recurring session)
              if (!isIndividualSession &&
                  status == 'active' &&
                  days.isNotEmpty &&
                  times.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Next session: ${_getNextSessionDate(days, times)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
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
          studentName = recurringData?['student_name']?.toString() ?? 'Student';
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'in_progress':
        return AppTheme.accentGreen;
      case 'scheduled':
      case 'approved':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'paused':
        return Colors.orange;
      case 'expired':
        return Colors.orange;
      case 'completed':
        return AppTheme.textMedium;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.textMedium;
    }
  }

      Future<void> _handleStartSession(String sessionId) async {
    // Get session details to check if it's hybrid
    try {
      final session = await SupabaseService.client
          .from('individual_sessions')
          .select('location, onsite_address, meeting_link')
          .eq('id', sessionId)
          .maybeSingle();
      
      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      final location = session['location'] as String? ?? 'online';
      // Location should only be 'online' or 'onsite' (hybrid is a preference only)
      // If somehow 'hybrid' exists, default to online
      final sessionLocation = location == 'hybrid' ? 'online' : location;
      final isOnline = sessionLocation == 'online';

      safeSetState(() {
        _sessionLoadingStates[sessionId] = true;
      });

      // Use SessionLifecycleService with mode selection
      await SessionLifecycleService.startSession(
        sessionId,
        isOnline: isOnline ?? false,
      );

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SessionDetailsSheet(session: session),
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
          // TODO: Implement trial session cancellation if needed
          throw Exception('Trial session cancellation not yet implemented');
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
      studentName = recurringData?['student_name']?.toString() ?? 'Student';
      location = session['location'] as String? ?? 'online';
      address = session['onsite_address'] as String?;
      locationDescription = session['location_description'] as String?;
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
              if (isIndividualSession &&
                  session['meeting_link'] != null &&
                  location == 'online')
                _buildDetailSection(
                  'Meeting Link',
                  session['meeting_link'] as String,
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
