import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart' hide LogService;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/services/log_service.dart';
import '../services/individual_session_service.dart';
import '../services/session_feedback_service.dart';
import 'session_feedback_screen.dart';
// TODO: Fix import path
// import 'package:prepskul/features/sessions/services/session_transcript_service.dart';
// TODO: Fix import path
// import 'package:prepskul/features/sessions/screens/session_summary_screen.dart';
import 'package:prepskul/features/sessions/widgets/session_location_map.dart';
import 'package:prepskul/features/sessions/widgets/location_tracking_widget.dart';
import 'package:prepskul/features/sessions/widgets/session_mode_statistics_widget.dart';
import 'package:prepskul/core/services/auth_service.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:prepskul/core/services/google_calendar_service.dart';
import 'package:prepskul/core/services/google_calendar_auth_service.dart';
import 'package:prepskul/features/sessions/services/meet_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import 'package:prepskul/core/services/offline_cache_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
import 'package:prepskul/features/payment/widgets/credits_balance_widget.dart';
import 'package:prepskul/features/payment/services/user_credits_service.dart';
import 'package:prepskul/features/payment/screens/credits_balance_screen.dart';
import 'package:prepskul/features/sessions/screens/attendance_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/features/messaging/services/conversation_lifecycle_service.dart';
import 'package:prepskul/features/messaging/screens/chat_screen.dart';
import 'package:prepskul/features/messaging/models/conversation_model.dart';

/// My Sessions Screen
///
/// Allows students/parents to view their upcoming and completed sessions
/// Shows feedback prompts for completed sessions
class MySessionsScreen extends StatefulWidget {
  final int? initialTab; // 0 = Upcoming, 1 = Past
  final String? sessionId; // Session ID to scroll to
  
  const MySessionsScreen({
    Key? key,
    this.initialTab,
    this.sessionId,
  }) : super(key: key);

  @override
  State<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends State<MySessionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _upcomingScrollController = ScrollController();
  final ScrollController _pastScrollController = ScrollController();
  List<Map<String, dynamic>> _upcomingSessions = [];
  List<Map<String, dynamic>> _pastSessions = [];
  bool _isLoading = true;
  final Map<String, bool> _feedbackSubmitted = {}; // Cache feedback status
  final Map<String, bool> _hasTranscript = {}; // Cache transcript availability
  bool? _isCalendarConnected; // Cache calendar connection status (null = not checked yet)
  bool _isOffline = false;
  DateTime? _cacheTimestamp;
  final ConnectivityService _connectivity = ConnectivityService();
  // Cache tutor info for trial sessions (tutorId -> {full_name, avatar_url})
  final Map<String, Map<String, dynamic>> _tutorInfoCache = {};
  
  // Timer for countdown updates
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Use initialTab from arguments if provided, otherwise default to 0
    final initialTabIndex = widget.initialTab ?? 0;
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: initialTabIndex.clamp(0, 1), // Ensure valid index
    );
    _initializeConnectivity();
    _loadSessions();
    _checkCalendarConnection();
    _startCountdownTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload sessions when screen becomes visible (e.g., after payment)
    // This ensures newly created sessions appear immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSessions();
      }
    });
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    await _connectivity.initialize();
    _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivity.connectivityStream.listen((isOnline) {
      if (mounted) {
        final wasOffline = _isOffline;
        setState(() {
          _isOffline = !isOnline;
        });
        
        // If came back online, reload sessions
        if (isOnline && wasOffline) {
          LogService.info('🌐 Connection restored - reloading sessions');
          _loadSessions();
        }
      }
    });
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.checkConnectivity();
    if (mounted) {
      final wasOffline = _isOffline;
      setState(() {
        _isOffline = !isOnline;
      });
      
      // If we just came back online, reload data
      if (isOnline && wasOffline) {
        LogService.info('🌐 Connection detected - reloading sessions');
        _loadSessions();
      }
    }
  }

  /// Check if Google Calendar is connected (cache the result)
  /// This prevents showing the dialog multiple times
  Future<void> _checkCalendarConnection() async {
    try {
      final isConnected = await GoogleCalendarAuthService.isAuthenticated();
      if (mounted) {
        setState(() {
          _isCalendarConnected = isConnected;
        });
      }
    } catch (e) {
      LogService.warning('Error checking calendar connection: $e');
      if (mounted) {
        setState(() {
          _isCalendarConnected = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _upcomingScrollController.dispose();
    _pastScrollController.dispose();
    _connectivity.dispose();
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
  
  /// Scroll to a specific session after sessions are loaded
  void _scrollToSession(String sessionId) {
    if (!mounted) return;
    
    // Wait for the next frame to ensure list is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Determine which list contains the session
      final upcomingIndex = _upcomingSessions.indexWhere((s) => s['id'] == sessionId);
      final pastIndex = _pastSessions.indexWhere((s) => s['id'] == sessionId);
      
      if (upcomingIndex >= 0) {
        // Switch to upcoming tab if not already there
        if (_tabController.index != 0) {
          _tabController.animateTo(0);
        }
        // Scroll to the session (each card is approximately 200px tall)
        final scrollPosition = upcomingIndex * 220.0; // Approximate card height + margin
        _upcomingScrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else if (pastIndex >= 0) {
        // Switch to past tab if not already there
        if (_tabController.index != 1) {
          _tabController.animateTo(1);
        }
        // Scroll to the session
        final scrollPosition = pastIndex * 220.0; // Approximate card height + margin
        _pastScrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadSessions() async {
    safeSetState(() => _isLoading = true);
    try {
      // Check connectivity first
      final isOnline = await _connectivity.checkConnectivity();
      safeSetState(() => _isOffline = !isOnline);
      
      final userId = SupabaseService.currentUser?.id;
      
      // If offline, try to load from cache
      if (_isOffline && userId != null) {
        LogService.info('MySessionsScreen: Offline - loading from cache...');
        
        // Try to load cached individual sessions
        final cachedUpcoming = await OfflineCacheService.getCachedIndividualSessions('${userId}_upcoming');
        final cachedPast = await OfflineCacheService.getCachedIndividualSessions('${userId}_past');
        
        if ((cachedUpcoming != null && cachedUpcoming.isNotEmpty) || 
            (cachedPast != null && cachedPast.isNotEmpty)) {
          final timestamp = await SharedPreferences.getInstance().then(
            (prefs) => prefs.getInt('cached_individual_sessions_${userId}_upcoming_cache_timestamp') ?? 0,
          );
          
          if (mounted) {
            safeSetState(() {
              _upcomingSessions = cachedUpcoming ?? [];
              _pastSessions = cachedPast ?? [];
              _isLoading = false;
              _cacheTimestamp = timestamp > 0 
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                  : null;
            });
          }
          LogService.success('MySessionsScreen: Loaded ${_upcomingSessions.length} upcoming and ${_pastSessions.length} past sessions from cache');
          return;
        } else {
          // No cache available
          if (mounted) {
            safeSetState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No internet connection. Showing cached data when available.'),
                backgroundColor: Colors.orange[700],
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
      
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      // 1. Fetch Individual Sessions (Normal recurring sessions)
      try {
        final indUpcoming = await IndividualSessionService.getStudentUpcomingSessions(limit: 50);
        final indPast = await IndividualSessionService.getStudentPastSessions(limit: 50);
        upcoming.addAll(indUpcoming);
        past.addAll(indPast);
        
        // Cache individual sessions
        if (userId != null) {
          await OfflineCacheService.cacheIndividualSessions('${userId}_upcoming', indUpcoming);
          await OfflineCacheService.cacheIndividualSessions('${userId}_past', indPast);
        }
      } catch (e) {
        // Gracefully handle missing table or other errors
        LogService.info('Could not load individual sessions (table might not exist yet): $e');
      }

      // 2. Auto-detect and mark expired sessions before loading
      try {
        // Only auto-mark expired sessions once per app session, not every time screen loads
        // This prevents aggressive auto-cancelling of sessions
        // await TrialSessionService.autoMarkExpiredAttendedSessions(); // Disabled - too aggressive
      } catch (e) {
        LogService.warning('Error auto-marking expired sessions: $e');
      }

      // 3. Fetch Trial Sessions (only those not yet converted to full sessions)
      try {
        final trialSessions = await TrialSessionService.getStudentTrialSessions();
        
        // Load tutor info for all trial sessions
        await _loadTutorInfoForTrials(trialSessions);

        for (final trial in trialSessions) {
          final sessionMap = _convertTrialToSessionMap(trial);
          if (sessionMap != null) {
            // Classify as upcoming or past using SessionDateUtils
            final status = sessionMap['status'];
            final isCompleted = status == 'completed' || status == 'cancelled' || status == 'rejected' || status == 'expired';
            
            // Use SessionDateUtils for time-based classification
            if (isCompleted) {
              past.add(sessionMap);
            } else {
              // Check if session is expired or upcoming using SessionDateUtils
              final isExpired = SessionDateUtils.isSessionExpired(trial);
              final isUpcoming = SessionDateUtils.isSessionUpcoming(trial);
              
              // If expired but not yet marked, mark it now
              if (isExpired && status != 'expired') {
                // Update status to expired in the map
                sessionMap['status'] = 'expired';
              }
              
              if (isExpired || !isUpcoming || status == 'expired') {
                past.add(sessionMap);
              } else {
                upcoming.add(sessionMap);
              }
            }
          }
        }
      } catch (e) {
        LogService.warning('Error loading trial sessions: $e');
      }

      // Sort combined lists
      upcoming.sort((a, b) {
        final dateA = DateTime.parse(a['scheduled_date']);
        final dateB = DateTime.parse(b['scheduled_date']);
        return dateA.compareTo(dateB);
      });
      
      past.sort((a, b) {
        final dateA = DateTime.parse(a['scheduled_date']);
        final dateB = DateTime.parse(b['scheduled_date']);
        return dateB.compareTo(dateA); // Descending for past
      });

      // Check feedback status and transcript availability for completed sessions
      for (final session in past) {
        if (session['status'] == 'completed') {
          final sessionId = session['id'] as String;
          final sessionType = session['type'] as String? ?? 'individual';
          
          // Check feedback status
          if (sessionType == 'individual') {
            final canSubmit = await SessionFeedbackService.canSubmitFeedback(
              sessionId,
            );
            _feedbackSubmitted[sessionId] = !canSubmit;
          }
          
          // Check transcript availability
          bool hasTranscript = false;
          if (sessionType == 'individual') {
            // hasTranscript = await SessionTranscriptService.hasIndividualSessionTranscript(sessionId);
          } else if (sessionType == 'trial') {
            // hasTranscript = await SessionTranscriptService.hasTranscript(sessionId, 'trial');
          }
          _hasTranscript[sessionId] = hasTranscript;
        }
      }

      safeSetState(() {
        _upcomingSessions = upcoming;
        _pastSessions = past;
        _isLoading = false;
      });
      
      // Scroll to session if sessionId was provided
      if (widget.sessionId != null) {
        _scrollToSession(widget.sessionId!);
      }
    } catch (e) {
      LogService.error('Error loading sessions: $e');
      safeSetState(() => _isLoading = false);
      // Only show error if we have absolutely nothing to show
      if (_upcomingSessions.isEmpty && _pastSessions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load sessions. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    }
  }

  /// Load tutor information for trial sessions
  Future<void> _loadTutorInfoForTrials(List<TrialSession> trials) async {
    try {
      final supabase = SupabaseService.client;
      final tutorIds = trials.map((t) => t.tutorId).toSet().toList();

      if (tutorIds.isEmpty) return;

      // Fetch tutor profiles with profile data using relationship join
      try {
        final tutorProfiles = await supabase
            .from('tutor_profiles')
            .select(
              'user_id, profile_photo_url, profiles!tutor_profiles_user_id_fkey(full_name, avatar_url)',
            )
            .inFilter('user_id', tutorIds);

        LogService.debug('Loaded ${tutorProfiles.length} tutor profiles for trial sessions');

        // Cache tutor info
        for (var tutor in tutorProfiles) {
          final userId = tutor['user_id'] as String;

          // Safely extract profile data - handle both Map and List responses
          Map<String, dynamic>? profile;
          final profilesData = tutor['profiles'];
          if (profilesData is Map) {
            profile = Map<String, dynamic>.from(profilesData);
          } else if (profilesData is List && profilesData.isNotEmpty) {
            profile = Map<String, dynamic>.from(profilesData[0]);
          }

          // Get avatar URL - prioritize profile_photo_url from tutor_profiles, then avatar_url from profiles
          final profilePhotoUrl = tutor['profile_photo_url'] as String?;
          final avatarUrl = profile?['avatar_url'] as String?;
          final effectiveAvatarUrl =
              (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
              ? profilePhotoUrl
              : (avatarUrl != null && avatarUrl.isNotEmpty)
              ? avatarUrl
              : null;

          final tutorName = profile?['full_name'] as String?;
          _tutorInfoCache[userId] = {
            'full_name':
                (tutorName != null &&
                    tutorName.isNotEmpty &&
                    tutorName != 'User' &&
                    tutorName != 'Tutor')
                ? tutorName
                : 'Tutor',
            'avatar_url': effectiveAvatarUrl,
          };
        }
      } catch (e) {
        LogService.warning('Error loading tutor profiles with join, trying fallback: $e');
        
        // Fallback: fetch separately
        for (final tutorId in tutorIds) {
          try {
            // Fetch tutor profile
            final tutorProfile = await supabase
                .from('tutor_profiles')
                .select('user_id, profile_photo_url')
                .eq('user_id', tutorId)
                .maybeSingle();

            if (tutorProfile == null) continue;

            // Fetch profile separately
            final profile = await supabase
                .from('profiles')
                .select('full_name, avatar_url')
                .eq('id', tutorId)
                .maybeSingle();

            final profilePhotoUrl =
                tutorProfile['profile_photo_url'] as String?;
            final avatarUrl = profile?['avatar_url'] as String?;
            final effectiveAvatarUrl =
                (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
                ? profilePhotoUrl
                : (avatarUrl != null && avatarUrl.isNotEmpty)
                ? avatarUrl
                : null;

            final tutorName = profile?['full_name'] as String?;
            _tutorInfoCache[tutorId] = {
              'full_name':
                  (tutorName != null &&
                      tutorName.isNotEmpty &&
                      tutorName != 'User' &&
                      tutorName != 'Tutor')
                  ? tutorName
                  : 'Tutor',
              'avatar_url': effectiveAvatarUrl,
            };
          } catch (e) {
            LogService.warning('Error loading tutor info for $tutorId: $e');
          }
        }
      }
    } catch (e) {
      LogService.error('Error loading tutor info for trials: $e');
    }
  }

  Map<String, dynamic>? _convertTrialToSessionMap(TrialSession trial) {
    // Convert TrialSession object to the Map format used by _buildSessionCard
    // Returns null if the trial shouldn't be shown (e.g., rejected/cancelled might be hidden if old?)
    // For now, we show everything.
    
    // Get tutor info from cache
    final tutorInfo = _tutorInfoCache[trial.tutorId];
    final tutorName = tutorInfo?['full_name'] as String? ?? 'Tutor';
    final tutorAvatarUrl = tutorInfo?['avatar_url'] as String?;
    
    return {
      'id': trial.id,
      'status': trial.status,
      'scheduled_date': trial.scheduledDate.toIso8601String(),
      'scheduled_time': trial.scheduledTime,
      'location': trial.location,
      'duration_minutes': trial.durationMinutes,
      'type': 'trial', // Mark as trial
      'subject': trial.subject, // Add subject at top level too
      // Simulate the nested structure expected by UI
      'recurring_sessions': {
        'tutor_name': tutorName,
        'tutor_avatar_url': tutorAvatarUrl,
        'subject': trial.subject,
      },
      // Add meeting link if available (generated after payment)
      'meeting_link': trial.meetLink,
    };
  }

  DateTime? _parseSessionDateTime(String date, String time) {
    try {
      final dateTime = DateTime.parse(date);
      // Parse time (format: "HH:MM" or "HH:MM:SS")
      final timeParts = time.split(':');
      if (timeParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        return DateTime(dateTime.year, dateTime.month, dateTime.day, hour, minute);
      }
      return dateTime;
    } catch (e) {
      LogService.warning('Error parsing session date/time: $e');
      return null;
    }
  }

  String _formatDateTime(String date, String time) {
    try {
      final dateTime = DateTime.parse(date);
      final formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
      return '$formattedDate at $time';
    } catch (e) {
      return '$date at $time';
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

  Future<void> _openFeedbackScreen(String sessionId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFeedbackScreen(sessionId: sessionId),
      ),
    );

    // Reload sessions if feedback was submitted
    if (result == true) {
      _loadSessions();
    }
  }

  Future<void> _openSessionSummary(Map<String, dynamic> session) async {
    final sessionId = session['id'] as String;
    final sessionType = session['type'] as String? ?? 'individual';
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDialog(
          title: Text('Session Summary'),
          content: Text('Feature coming soon'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinMeeting(String? meetLink) async {
    if (meetLink == null || meetLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meeting link not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(meetLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch meeting link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Add session to Google Calendar
  /// Creates calendar event and Meet link (if online) for the session
  /// Once user connects calendar, we remember it and NEVER ask again
  Future<void> _addSessionToCalendar(Map<String, dynamic> session) async {
    try {
      // Check if Google Calendar is authenticated
      // Use cached value if available, otherwise check
      bool isAuthenticated = _isCalendarConnected ?? false;
      if (!isAuthenticated) {
        // Check again to be sure
        isAuthenticated = await GoogleCalendarAuthService.isAuthenticated();
        if (!isAuthenticated) {
          // Show dialog to authenticate (ONLY FIRST TIME - never shown again after connection)
          final shouldAuth = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Connect Google Calendar',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                'To add sessions to your calendar, please connect your Google account.\n\nOnce connected, we will remember your preference and you will never be asked again.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Connect',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
          );

          if (shouldAuth != true) return;

          // Authenticate - this stores tokens in SharedPreferences
          // Once stored, isAuthenticated() will always return true
          final authSuccess = await GoogleCalendarAuthService.signIn();
          if (!authSuccess) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to connect Google Calendar. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          // Update cached connection status
          // This ensures we never show the dialog again
          if (mounted) {
            setState(() {
              _isCalendarConnected = true;
            });
          }
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google Calendar connected! Adding session...',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.accentGreen,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Update cache if we got a different result
          if (mounted) {
            setState(() {
              _isCalendarConnected = true;
            });
          }
        }
      }

      // Get session details
      final sessionId = session['id'] as String;
      final scheduledDate = DateTime.parse(session['scheduled_date'] as String);
      final scheduledTime = session['scheduled_time'] as String;
      final duration = session['duration_minutes'] as int? ?? 60;
      final location = session['location'] as String? ?? 'online';
      final subject = session['subject'] as String? ?? 'Tutoring Session';
      final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
      final tutorName = recurringData?['tutor_name'] as String? ?? 'Tutor';
      final studentName = recurringData?['student_name'] as String? ?? 'Student';

      // Parse time
      final timeParts = scheduledTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1].split(' ')[0]);
      final isPM = scheduledTime.toUpperCase().contains('PM');
      final hour24 = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour);

      final startTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour24,
        minute,
      );

      // Get user emails
      final userProfile = await AuthService.getUserProfile();
      final userEmail = userProfile?['email'] as String?;
      
      // Get tutor/student emails
      final tutorId = session['tutor_id'] as String? ?? recurringData?['tutor_id'] as String?;
      final studentId = session['learner_id'] as String? ?? recurringData?['student_id'] as String?;
      
      final attendeeEmails = <String>[];
      if (userEmail != null) attendeeEmails.add(userEmail);
      
      // Try to get tutor and student emails
      try {
        if (tutorId != null) {
          final tutorProfile = await SupabaseService.client
              .from('profiles')
              .select('email')
              .eq('id', tutorId)
              .maybeSingle();
          final tutorEmail = tutorProfile?['email'] as String?;
          if (tutorEmail != null && !attendeeEmails.contains(tutorEmail)) {
            attendeeEmails.add(tutorEmail);
          }
        }
        if (studentId != null) {
          final studentProfile = await SupabaseService.client
              .from('profiles')
              .select('email')
              .eq('id', studentId)
              .maybeSingle();
          final studentEmail = studentProfile?['email'] as String?;
          if (studentEmail != null && !attendeeEmails.contains(studentEmail)) {
            attendeeEmails.add(studentEmail);
          }
        }
      } catch (e) {
        LogService.warning('Could not fetch attendee emails: $e');
      }

      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Create calendar event
      final calendarEvent = await GoogleCalendarService.createSessionEvent(
        title: 'PrepSkul Session: $subject',
        startTime: startTime,
        durationMinutes: duration,
        attendeeEmails: attendeeEmails,
        description: 'Tutoring session with $tutorName',
      );

      // Update session with calendar event ID and Meet link
      await SupabaseService.client
          .from('individual_sessions')
          .update({
            'calendar_event_id': calendarEvent.id,
            if (location == 'online' && calendarEvent.meetLink.isNotEmpty)
              'meeting_link': calendarEvent.meetLink,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success
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
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Reload sessions to show updated calendar status
      _loadSessions();
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to calendar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      LogService.error('Error adding session to calendar: $e');
    }
  }

  /// Build countdown text widget
  Widget _buildCountdownText(String scheduledDate, String scheduledTime) {
    try {
      final dateParts = scheduledDate.split('T')[0].split('-');
      final timeParts = scheduledTime.split(':');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = timeParts.length > 1 
          ? (int.tryParse(timeParts[1].split(' ')[0]) ?? 0) 
          : 0;
      
      final sessionDateTime = DateTime(year, month, day, hour, minute);
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

  Widget _buildCreditsHeader() {
    return FutureBuilder<int>(
      future: _getUserBalance(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credits Balance',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$balance',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'credits',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$balance sessions',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreditsBalanceScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int> _getUserBalance() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return 0;
      return await UserCreditsService.getUserBalance(userId);
    } catch (e) {
      LogService.error('Error getting user balance: $e');
      return 0;
    }
  }

  Widget _buildSessionCard(Map<String, dynamic> session, bool isUpcoming) {
    final isTrial = session['type'] == 'trial';
    final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
    
    // Get tutor name and avatar - prioritize recurring_sessions data, fallback to session data
    final tutorName = recurringData?['tutor_name'] as String? 
        ?? session['tutor_name'] as String? 
        ?? (isTrial ? 'Tutor' : 'Tutor');
    final tutorAvatar = recurringData?['tutor_avatar_url'] as String? 
        ?? session['tutor_avatar_url'] as String?;
    final subject = recurringData?['subject'] as String? 
        ?? session['subject'] as String? 
        ?? 'Session';
    final status = session['status'] as String;
    final scheduledDate = session['scheduled_date'] as String;
    final scheduledTime = session['scheduled_time'] as String;
    final location = session['location'] as String? ?? 'online';
    final meetLink = session['meeting_link'] as String?;
    final sessionId = session['id'] as String;
    final isCompleted = status == 'completed';
    final hasFeedback = _feedbackSubmitted[sessionId] ?? false;
    final isExpired = status == 'expired';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
        onTap: () {
          // Show session details
          _showSessionDetails(session);
        },
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
                  // Trial Badge (smaller, more subtle)
              if (isTrial)
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
                  // Status badge (more compact)
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
              const SizedBox(height: 10),
              // Tutor info row
              Row(
                children: [
                  // Tutor avatar (slightly larger)
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: tutorAvatar != null && tutorAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(tutorAvatar)
                        : null,
                    child: tutorAvatar == null || tutorAvatar.isEmpty
                        ? Text(
                            tutorName.isNotEmpty ? tutorName[0].toUpperCase() : 'T',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Tutor name and subject
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutorName,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chat button - show if session is valid (scheduled, in_progress, or completed)
                  Builder(
                    builder: (context) {
                      final status = session['status'] as String?;
                      final isSessionValid = status != null && 
                          status != 'cancelled' && 
                          status != 'expired';
                      
                      if (!isSessionValid) {
                        return const SizedBox.shrink();
                      }
                      
                      return IconButton(
                        icon: const Icon(Icons.message, size: 22),
                        color: AppTheme.primaryColor,
                        tooltip: 'Message Tutor',
                        onPressed: () => _navigateToChatFromSession(context, session),
                      );
                    },
                  ),
                ],
              ),
              // Session in Progress indicator (only show if session time has actually arrived)
              // Don't show if session was started early but scheduled time hasn't arrived yet
              if (status == 'in_progress') ...[
                Builder(
                  builder: (context) {
                    // Check if session time has actually arrived
                    try {
                      final dateParts = scheduledDate.split('T')[0].split('-');
                      final timeParts = scheduledTime.split(':');
                      final year = int.parse(dateParts[0]);
                      final month = int.parse(dateParts[1]);
                      final day = int.parse(dateParts[2]);
                      final hour = int.tryParse(timeParts[0]) ?? 0;
                      final minute = timeParts.length > 1 
                          ? (int.tryParse(timeParts[1].split(' ')[0]) ?? 0) 
                          : 0;
                      
                      final sessionDateTime = DateTime(year, month, day, hour, minute);
                      final now = DateTime.now();
                      final hasStarted = now.isAfter(sessionDateTime) || now.isAtSameMomentAs(sessionDateTime);
                      
                      // Only show "in progress" if the scheduled time has actually arrived
                      if (!hasStarted) {
                        return const SizedBox.shrink();
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
              const SizedBox(height: 12),
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
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                    _formatDateTime(scheduledDate, scheduledTime),
                    style: GoogleFonts.poppins(
                              fontSize: 13,
                      color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
                    if (isUpcoming && (status == 'scheduled' || status == 'in_progress')) ...[
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
                              child: _buildCountdownText(scheduledDate, scheduledTime),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Expired session indicator (more subtle, below details)
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (location == 'online' && meetLink != null && meetLink.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _joinMeeting(meetLink),
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
                    // Show ONLY if:
                    // 1. Session doesn't have calendar_event_id yet, AND
                    // 2. User hasn't connected calendar (so they can connect), OR
                    // 3. User has connected calendar (so they can add this session)
                    if ((session['calendar_event_id'] == null || 
                         (session['calendar_event_id'] as String? ?? '').isEmpty))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton.icon(
                          onPressed: _isOffline
                              ? () => OfflineDialog.show(
                                    context,
                                    message: 'Adding to calendar requires an internet connection. Please check your connection and try again.',
                                  )
                              : () => _addSessionToCalendar(session),
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
              // Feedback prompt for completed sessions
              if (isCompleted) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasFeedback
                        ? Colors.green[50]
                        : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasFeedback
                          ? Colors.green[200]!
                          : AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasFeedback ? Icons.check_circle : Icons.feedback,
                        color: hasFeedback ? Colors.green[700] : AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasFeedback ? 'Feedback Submitted' : 'Share Your Feedback',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: hasFeedback ? Colors.green[900] : Colors.black87,
                              ),
                            ),
                            if (!hasFeedback)
                              Text(
                                'Help us improve by rating your session',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!hasFeedback)
                        TextButton(
                          onPressed: _isOffline
                              ? () => OfflineDialog.show(
                                    context,
                                    message: 'Submitting feedback requires an internet connection. Please check your connection and try again.',
                                  )
                              : () => _openFeedbackScreen(sessionId),
                          child: Text(
                            'Submit',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Session Summary button for completed online sessions
                if (isCompleted && _hasTranscript[sessionId] == true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openSessionSummary(session),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('View Session Summary'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDetails(Map<String, dynamic> session) async {
    final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
    final tutorName = recurringData?['tutor_name'] as String? ?? 'Tutor';
    final subject = recurringData?['subject'] as String? ?? 'Session';
    final scheduledDate = session['scheduled_date'] as String;
    final scheduledTime = session['scheduled_time'] as String;
    final duration = session['duration_minutes'] as int? ?? 60;
    final location = session['location'] as String? ?? 'online';
    final meetLink = session['meeting_link'] as String?;
    final status = session['status'] as String;
    final sessionId = session['id'] as String;
    final onsiteAddress = session['onsite_address'] as String?;
    final locationDescription = session['location_description'] as String?;
    
    // Get current user info for check-in
    String? currentUserId;
    String? userType;
    try {
      final userProfile = await AuthService.getUserProfile();
      currentUserId = userProfile?['id'] as String?;
      userType = userProfile?['user_type'] as String?;
    } catch (e) {
      LogService.warning('Error getting user profile: \$e');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Session Details',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Tutor', tutorName),
              _buildDetailRow('Subject', subject),
              _buildDetailRow('Date & Time', _formatDateTime(scheduledDate, scheduledTime)),
              _buildDetailRow('Duration', '$duration minutes'),
              _buildDetailRow('Location', location == 'online' ? 'Online' : 'On-site'),
              _buildDetailRow('Status', _getStatusLabel(status)),
              // Mode statistics for flexible sessions
              if (recurringData != null && recurringData['id'] != null)
                SessionModeStatisticsWidget(
                  recurringSessionId: recurringData['id'] as String,
                  currentSessionLocation: location,
                ),
              // Location map for onsite sessions (hybrid is a preference only, not a location)
              if (location == 'onsite' && 
                  onsiteAddress != null && onsiteAddress.isNotEmpty) ...[
                const SizedBox(height: 16),
                SessionLocationMap(
                  address: onsiteAddress,
                  coordinates: null, // Could be extracted from address if available
                  locationDescription: locationDescription,
                  sessionId: sessionId,
                  currentUserId: currentUserId,
                  userType: userType,
                  showCheckIn: status == 'scheduled' || status == 'in_progress',
                  scheduledDateTime: _parseSessionDateTime(scheduledDate, scheduledTime),
                  locationType: location, // Pass location type for safety features
                ),
                // Real-time location tracking for parents during active sessions
                if (status == 'in_progress' && 
                    (userType == 'parent' || userType == 'student')) ...[
                  const SizedBox(height: 16),
                  LocationTrackingWidget(
                    sessionId: sessionId,
                    sessionAddress: onsiteAddress,
                    sessionCoordinates: null,
                  ),
                ],
              ],
              
                            // Action buttons in details dialog
              if (status == 'scheduled' || status == 'in_progress') ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (location == 'online' && meetLink != null && meetLink.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _joinMeeting(meetLink);
                  },
                  icon: const Icon(Icons.video_call, size: 18),
                  label: Text('Join Meeting', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                      ),
                    // Add to Calendar button (if no calendar event exists)
                    if (session['calendar_event_id'] == null || 
                        (session['calendar_event_id'] as String? ?? '').isEmpty)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _addSessionToCalendar(session);
                        },
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
                          style: GoogleFonts.poppins(),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            // Check if we can pop - if not, navigate to dashboard instead
            if (Navigator.of(context).canPop()) {
              return IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () {
                  // Simply pop - don't trigger any auth checks
                  Navigator.of(context).pop();
                },
              );
            } else {
              // Can't pop - navigate to appropriate dashboard
              return IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () async {
                  try {
                    final userProfile = await AuthService.getUserProfile();
                    final userType = userProfile?['user_type'] as String?;
                    final route = userType == 'parent' ? '/parent-nav' : '/student-nav';
                    Navigator.pushReplacementNamed(context, route);
                  } catch (e) {
                    // Fallback to parent nav
                    Navigator.pushReplacementNamed(context, '/parent-nav');
                  }
                },
              );
            }
          },
        ),
        automaticallyImplyLeading: false,
        title: Text(
          t.mySessionsTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Attendance History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceHistoryScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Upcoming Sessions
                _upcomingSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Upcoming Sessions',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Book a session to get started',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSessions,
                        child: ListView.builder(
                          controller: _upcomingScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _upcomingSessions.length + 1, // +1 for credits widget
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // Credits balance widget at top
                              return _buildCreditsHeader();
                            }
                            return _buildSessionCard(
                              _upcomingSessions[index - 1],
                              true,
                            );
                          },
                        ),
                      ),
                // Completed Sessions
                _pastSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Completed Sessions',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your completed sessions will appear here',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSessions,
                        child: ListView.builder(
                          controller: _pastScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _pastSessions.length,
                          itemBuilder: (context, index) {
                            return _buildSessionCard(
                              _pastSessions[index],
                              false,
                            );
                          },
                        ),
                      ),
              ],
            ),
    );
  }

  /// Get conversation ID for a session
  Future<String?> _getConversationIdForSession(Map<String, dynamic> session) async {
    try {
      // Check if session is paid/approved (only show chat for valid sessions)
      final status = session['status'] as String?;
      if (status == null || status == 'cancelled' || status == 'expired') {
        return null;
      }

      // Try individual session ID first
      final individualSessionId = session['id'] as String?;
      if (individualSessionId != null) {
        final conversationId = await ConversationLifecycleService.getConversationIdForIndividual(individualSessionId);
        if (conversationId != null) {
          return conversationId;
        }
      }

      // Try recurring session ID
      final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
      if (recurringData != null) {
        final recurringSessionId = recurringData['id'] as String?;
        if (recurringSessionId != null) {
          final conversationId = await ConversationLifecycleService.getConversationIdForRecurring(recurringSessionId);
          if (conversationId != null) {
            return conversationId;
          }
        }
      }

      // Try trial session ID (if this is a trial)
      final trialData = session['trial_sessions'] as Map<String, dynamic>?;
      if (trialData != null) {
        final trialSessionId = trialData['id'] as String?;
        if (trialSessionId != null) {
          final conversationId = await ConversationLifecycleService.getConversationIdForTrial(trialSessionId);
          if (conversationId != null) {
            return conversationId;
          }
        }
      }

      return null;
    } catch (e) {
      LogService.error('Error getting conversation ID for session: $e');
      return null;
    }
  }

  /// Navigate to chat from session card
  Future<void> _navigateToChatFromSession(BuildContext context, Map<String, dynamic> session) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get or create conversation
      final supabase = SupabaseService.client;
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) {
        if (mounted) {
          Navigator.pop(context); // Dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You must be logged in to message.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get tutor ID from session
      String? tutorId;
      String? studentId = currentUserId;
      
      final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
      if (recurringData != null) {
        tutorId = recurringData['tutor_id'] as String?;
        studentId = recurringData['learner_id'] as String? ?? currentUserId;
      }

      if (tutorId == null) {
        if (mounted) {
          Navigator.pop(context); // Dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to find tutor information.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get or create conversation
      final conversationData = await ConversationLifecycleService.getOrCreateConversation(
        recurringSessionId: recurringData?['id'] as String?,
        individualSessionId: session['id'] as String?,
        tutorId: tutorId,
        studentId: studentId,
      );

      // Dismiss loading
      if (mounted) Navigator.pop(context);

      if (conversationData == null || conversationData['id'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to start conversation. Please try again.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get full conversation data
      final conversationResponse = await supabase
          .from('conversations')
          .select('*')
          .eq('id', conversationData['id'] as String)
          .maybeSingle();

      if (conversationResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Conversation not found. Please try again.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get other user's profile info
      final otherUserId = conversationResponse['student_id'] == currentUserId
          ? conversationResponse['tutor_id']
          : conversationResponse['student_id'];

      final otherUserProfile = await supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', otherUserId)
          .maybeSingle();

      // Create Conversation object
      final conversation = Conversation(
        id: conversationResponse['id'] as String,
        studentId: conversationResponse['student_id'] as String,
        tutorId: conversationResponse['tutor_id'] as String,
        bookingRequestId: conversationResponse['booking_request_id'] as String?,
        recurringSessionId: conversationResponse['recurring_session_id'] as String?,
        individualSessionId: conversationResponse['individual_session_id'] as String?,
        trialSessionId: conversationResponse['trial_session_id'] as String?,
        status: conversationResponse['status'] as String? ?? 'active',
        expiresAt: conversationResponse['expires_at'] != null
            ? DateTime.parse(conversationResponse['expires_at'] as String)
            : null,
        lastMessageAt: conversationResponse['last_message_at'] != null
            ? DateTime.parse(conversationResponse['last_message_at'] as String)
            : null,
        createdAt: DateTime.parse(conversationResponse['created_at'] as String),
        otherUserName: otherUserProfile?['full_name'] as String?,
        otherUserAvatarUrl: otherUserProfile?['avatar_url'] as String?,
      );

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      LogService.error('Error navigating to chat from session: $e');
      if (mounted) {
        // Dismiss loading if still showing
        Navigator.of(context, rootNavigator: true).popUntil((route) => !route.navigator!.canPop() || route.settings.name != null);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to start conversation. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}