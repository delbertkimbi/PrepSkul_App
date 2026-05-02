import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/utils/status_bar_utils.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/skeletons/student_home_skeleton.dart';
import '../../../core/services/auth_service.dart' hide LogService;
import '../../../core/services/supabase_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/widgets/offline_indicator.dart';
import '../../../features/notifications/widgets/notification_bell.dart';
import '../../../features/profile/widgets/survey_reminder_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import '../../../features/skulmate/screens/game_library_screen.dart';
import '../../../features/skulmate/screens/skulmate_upload_screen.dart';
import '../../../features/skulmate/screens/skulmate_onboarding_screen.dart';
import '../../../features/skulmate/services/skulmate_service.dart';
import '../../../features/skulmate/services/skulmate_onboarding_service.dart';
import '../../../features/messaging/screens/conversations_list_screen.dart';
import '../../../features/messaging/widgets/message_icon_badge.dart';
import '../../../features/booking/services/individual_session_service.dart';
import '../../../features/booking/services/trial_session_service.dart';
import '../../../features/booking/utils/session_date_utils.dart';
import 'package:prepskul/core/services/notification_permission_nudge_service.dart';
// TODO: Fix import path
// import 'package:prepskul/features/parent/screens/parent_progress_dashboard.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({Key? key}) : super(key: key);

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String _userName = '';
  bool _isLoading = true;
  bool _isFirstVisit = false;
  Map<String, dynamic>? _surveyData;
  String _userType = 'student';
  bool _surveyCompleted = false;
  bool _showReminderCard = false;
  bool _isOffline = false;
  int _activeTutorsCount = 0;
  int _allTimeSessionsCount = 0;
  int _upcomingSessionsCount = 0;
  final ConnectivityService _connectivity = ConnectivityService();
  /// Incremented on pull-to-refresh so NotificationBell (and other keyed widgets) reload
  int _homeRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _loadUserData();
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
        
        // If came back online, refresh data
        if (isOnline && wasOffline) {
          LogService.info('🌐 Connection restored - refreshing home screen');
          _loadUserData();
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
      
      // If we just came back online, refresh data
      if (isOnline && wasOffline) {
        LogService.info('🌐 Connection detected - refreshing home screen');
        _loadUserData();
      }
    }
  }

  Future<void> _loadUserData() async {
    String? extractFirstName(String? fullName) {
      if (fullName == null || fullName.isEmpty || fullName == 'User' || fullName == 'Student') {
        return null;
      }
      final parts = fullName.trim().split(' ');
      final firstName = parts.isNotEmpty ? parts[0] : fullName;
      if (firstName.isEmpty || firstName == 'Student' || firstName == 'User') {
        return null;
      }
      return firstName;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Fast first paint from local cache so offline startup is instant.
      final cachedName = extractFirstName(prefs.getString('user_name')) ??
          extractFirstName(prefs.getString('signup_full_name')) ??
          'Student';
      final cachedUserRole = prefs.getString('user_role');
      final cachedSurveyCompleted = prefs.getBool('survey_completed') ?? false;
      final hasVisitedHome = prefs.getBool('has_visited_home') ?? false;
      final cachedActiveTutors = prefs.getInt('home_active_tutors_count') ?? 0;
      final cachedAllTimeSessions = prefs.getInt('home_all_time_sessions_count') ?? 0;
      final cachedUpcomingSessions = prefs.getInt('home_upcoming_sessions_count') ?? 0;

      if (mounted) {
        safeSetState(() {
          _userName = cachedName;
          _userType = cachedUserRole == 'parent' ? 'parent' : 'student';
          _surveyCompleted = cachedSurveyCompleted;
          _isFirstVisit = !hasVisitedHome;
          _activeTutorsCount = cachedActiveTutors;
          _allTimeSessionsCount = cachedAllTimeSessions;
          _upcomingSessionsCount = cachedUpcomingSessions;
          _isLoading = false;
        });
      }

      // If offline, keep cached UI and skip remote roundtrips.
      final isOnline = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(milliseconds: 900), onTimeout: () => false);
      if (!isOnline) {
        LogService.info('🌐 [HOME] Offline startup: using cached home data');
        return;
      }

      // Refresh in background when online.
      final userProfile = await AuthService.getUserProfile()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);

      var userName = extractFirstName(userProfile?['full_name']?.toString()) ?? cachedName;
      _userType = userProfile?['user_type'] ?? _userType;
      _surveyCompleted = userProfile?['survey_completed'] ?? _surveyCompleted;

      if (_userType == 'student') {
        _surveyData = await SurveyRepository.getStudentSurvey(userProfile?['id'])
            .timeout(const Duration(seconds: 3), onTimeout: () => _surveyData);
      } else if (_userType == 'parent') {
        _surveyData = await SurveyRepository.getParentSurvey(userProfile?['id'])
            .timeout(const Duration(seconds: 3), onTimeout: () => _surveyData);
      }

      if (!_surveyCompleted) {
        _showReminderCard = await SurveyReminderCard.shouldShow()
            .timeout(const Duration(seconds: 2), onTimeout: () => false);
      }

      int activeTutors = _activeTutorsCount;
      int allTimeSessions = _allTimeSessionsCount;
      int upcomingSessions = _upcomingSessionsCount;
      var statsSource = 'previous_cached';
      try {
        bool hasFreshStatsData = false;

        List<Map<String, dynamic>>? indUpcoming;
        try {
          indUpcoming = await IndividualSessionService
              .getStudentUpcomingSessions(limit: 50)
              .timeout(const Duration(seconds: 6));
        } on TimeoutException {
          indUpcoming = null;
        }
        final tutorIds = <String>{};
        if (indUpcoming != null) {
          hasFreshStatsData = true;
          for (final s in indUpcoming) {
            final recurring = s['recurring_sessions'] as Map<String, dynamic>?;
            final tid = (recurring?['tutor_id'] as String?) ??
                (s['tutor_id'] as String?);
            if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
          }
          upcomingSessions = indUpcoming.length;
          allTimeSessions = indUpcoming.length;
        }

        // All-time individual sessions should include past sessions, not only upcoming.
        List<Map<String, dynamic>>? indPast;
        try {
          indPast = await IndividualSessionService
              .getStudentPastSessions(limit: 200)
              .timeout(const Duration(seconds: 6));
        } on TimeoutException {
          indPast = null;
        }
        if (indPast != null) {
          hasFreshStatsData = true;
          allTimeSessions += indPast.length;
          for (final s in indPast) {
            final recurring = s['recurring_sessions'] as Map<String, dynamic>?;
            final tid = (recurring?['tutor_id'] as String?) ??
                (s['tutor_id'] as String?);
            if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
          }
        }

        List<dynamic /* TrialSession */ >? trials;
        try {
          trials = await TrialSessionService.getStudentTrialSessions()
              .timeout(const Duration(seconds: 6));
        } on TimeoutException {
          trials = null;
        }
        if (trials != null) {
          hasFreshStatsData = true;
          for (final t in trials) {
            final status = t.status.toLowerCase();
            final paymentStatus = t.paymentStatus.toLowerCase();
            final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed';
            final isCountableHistoricalTrial = isPaid &&
                status != 'rejected' &&
                status != 'cancelled';

            if (isCountableHistoricalTrial) {
              allTimeSessions += 1;
              if (t.tutorId.isNotEmpty) tutorIds.add(t.tutorId);
            }

            if ((t.status == 'approved' || t.status == 'scheduled') &&
                !SessionDateUtils.isSessionExpired(t)) {
              upcomingSessions += 1;
              if (t.tutorId.isNotEmpty) tutorIds.add(t.tutorId);
            }
          }
        }

        if (hasFreshStatsData) {
          activeTutors = tutorIds.length;
          statsSource = 'live_strict';

          // Fallback for strict paid filters: if all-time still resolves to zero,
          // run a relaxed history query so legitimate historical activity is shown.
          if (allTimeSessions == 0) {
            final relaxed = await _loadRelaxedAllTimeStats();
            if (relaxed != null && relaxed['allTimeSessions']! > 0) {
              allTimeSessions = relaxed['allTimeSessions']!;
              activeTutors = relaxed['activeTutors']!;
              statsSource = 'live_relaxed_fallback';
              LogService.info(
                'Student home stats recovered via relaxed history query: '
                'sessions=$allTimeSessions tutors=$activeTutors',
              );
            }
          }

          // Never regress to zero if this device already has known non-zero history.
          if (allTimeSessions == 0 && _allTimeSessionsCount > 0) {
            allTimeSessions = _allTimeSessionsCount;
            if (activeTutors == 0 && _activeTutorsCount > 0) {
              activeTutors = _activeTutorsCount;
            }
            statsSource = 'preserved_previous_non_zero';
            LogService.warning(
              'Student home stats would regress to zero; preserving previous known counts '
              '(sessions=$allTimeSessions tutors=$activeTutors).',
            );
          }
        } else {
          // If live queries fail (e.g. transient DNS/offline), compute from local caches.
          final userId = SupabaseService.client.auth.currentUser?.id;
          if (userId != null && userId.isNotEmpty) {
            final cachedUpcoming = await OfflineCacheService
                    .getCachedIndividualSessions('${userId}_upcoming') ??
                const <Map<String, dynamic>>[];
            final cachedPast = await OfflineCacheService
                    .getCachedIndividualSessions('${userId}_past') ??
                const <Map<String, dynamic>>[];
            final cachedTrials =
                await OfflineCacheService.getCachedTrialSessions(userId) ??
                    const <Map<String, dynamic>>[];

            final cachedTutorIds = <String>{};
            final addTutorFromSessionMap = (Map<String, dynamic> s) {
              final recurring = s['recurring_sessions'] as Map<String, dynamic>?;
              final tid = (recurring?['tutor_id'] as String?) ??
                  (s['tutor_id'] as String?);
              if (tid != null && tid.isNotEmpty) cachedTutorIds.add(tid);
            };

            for (final s in cachedUpcoming) {
              addTutorFromSessionMap(s);
            }
            for (final s in cachedPast) {
              addTutorFromSessionMap(s);
            }

            int cachedAllTime = cachedUpcoming.length + cachedPast.length;
            int cachedUpcomingCount = cachedUpcoming.length;

            for (final t in cachedTrials) {
              final status = (t['status'] as String? ?? '').toLowerCase();
              final paymentStatus =
                  (t['payment_status'] as String? ?? '').toLowerCase();
              final tutorId = t['tutor_id'] as String?;
              final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed';
              final isCountableHistoricalTrial =
                  isPaid && status != 'rejected' && status != 'cancelled';

              if (isCountableHistoricalTrial) {
                cachedAllTime += 1;
                if (tutorId != null && tutorId.isNotEmpty) {
                  cachedTutorIds.add(tutorId);
                }
              }
              if (status == 'approved' || status == 'scheduled') {
                cachedUpcomingCount += 1;
                if (tutorId != null && tutorId.isNotEmpty) {
                  cachedTutorIds.add(tutorId);
                }
              }
            }

            if (cachedAllTime > 0 || cachedTutorIds.isNotEmpty) {
              allTimeSessions = cachedAllTime;
              upcomingSessions = cachedUpcomingCount;
              activeTutors = cachedTutorIds.length;
              statsSource = 'offline_cache_fallback';
              LogService.info(
                'Student home stats loaded from local cache fallback: '
                'sessions=$allTimeSessions upcoming=$upcomingSessions tutors=$activeTutors',
              );
            } else {
              statsSource = 'cache_empty_preserve_previous';
              LogService.warning(
                'Student home stats refresh unavailable and cache empty; preserving previous counts.',
              );
            }
          } else {
            statsSource = 'no_user_cache_lookup_preserve_previous';
            LogService.warning(
              'Student home stats refresh unavailable and no user id for cache lookup.',
            );
          }
        }
      } catch (e) {
        LogService.debug('Student home stats load (background): $e');
      }

      // Persist latest good values for fast offline startup.
      if (allTimeSessions > 0 && activeTutors == 0) {
        final recoveredTutors = await _recoverActiveTutorsFromHistory();
        if (recoveredTutors > 0) {
          activeTutors = recoveredTutors;
          if (statsSource == 'previous_cached') {
            statsSource = 'previous_cached_plus_tutor_recovery';
          }
          LogService.info(
            'Student home active tutors recovered from history: $activeTutors',
          );
        }
      }

      await prefs.setString('user_name', userName);
      await prefs.setInt('home_active_tutors_count', activeTutors);
      await prefs.setInt('home_all_time_sessions_count', allTimeSessions);
      await prefs.setInt('home_upcoming_sessions_count', upcomingSessions);

      if (mounted) {
        safeSetState(() {
          _userName = userName;
          _activeTutorsCount = activeTutors;
          _allTimeSessionsCount = allTimeSessions;
          _upcomingSessionsCount = upcomingSessions;
        });
        LogService.info(
          'Student home progress counters updated: '
          'source=$statsSource activeTutors=$_activeTutorsCount '
          'allTimeSessions=$_allTimeSessionsCount upcoming=$_upcomingSessionsCount',
        );
      }

      if (mounted && !_isFirstVisit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            NotificationPermissionNudgeService.maybeShow(context, trigger: 'home');
          });
        });
      }

      if (_isFirstVisit && mounted) {
        await prefs.setBool('has_visited_home', true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            _userType == 'parent' ? '/parent-nav' : '/student-nav',
            arguments: {'initialTab': 1},
          );
        });
      }
    } catch (e) {
      LogService.debug('Error loading user data: $e');
      if (!mounted) return;
      safeSetState(() {
        _userName = _userName.isEmpty ? 'Student' : _userName;
        _isLoading = false;
      });
    }
  }

  Future<Map<String, int>?> _loadRelaxedAllTimeStats() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return null;

      final tutorIds = <String>{};
      int sessions = 0;

      final individualRows = await SupabaseService.client
          .from('individual_sessions')
          .select('tutor_id, recurring_sessions(tutor_id), status')
          .or('learner_id.eq.$userId,parent_id.eq.$userId')
          .limit(500);
      for (final row in (individualRows as List).cast<Map<String, dynamic>>()) {
        final status = (row['status'] as String? ?? '').toLowerCase();
        if (status == 'rejected') continue;
        sessions += 1;
        final recurring = row['recurring_sessions'] as Map<String, dynamic>?;
        final tid = (recurring?['tutor_id'] as String?) ??
            (row['tutor_id'] as String?);
        if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
      }

      final trialRows = await SupabaseService.client
          .from('trial_sessions')
          .select('tutor_id, status')
          .or('learner_id.eq.$userId,parent_id.eq.$userId,requester_id.eq.$userId')
          .limit(500);
      for (final row in (trialRows as List).cast<Map<String, dynamic>>()) {
        final status = (row['status'] as String? ?? '').toLowerCase();
        if (status == 'rejected' || status == 'cancelled') continue;
        sessions += 1;
        final tid = row['tutor_id'] as String?;
        if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
      }

      return {
        'allTimeSessions': sessions,
        'activeTutors': tutorIds.length,
      };
    } catch (e) {
      LogService.debug('Relaxed all-time stats query failed: $e');
      return null;
    }
  }

  Future<int> _recoverActiveTutorsFromHistory() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return 0;

      final tutorIds = <String>{};

      void addTutorFromSessionMap(Map<String, dynamic> s) {
        final recurring = s['recurring_sessions'] as Map<String, dynamic>?;
        final tid = (recurring?['tutor_id'] as String?) ??
            (s['tutor_id'] as String?);
        if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
      }

      final cachedUpcoming = await OfflineCacheService
              .getCachedIndividualSessions('${userId}_upcoming') ??
          const <Map<String, dynamic>>[];
      final cachedPast = await OfflineCacheService
              .getCachedIndividualSessions('${userId}_past') ??
          const <Map<String, dynamic>>[];
      final cachedTrials =
          await OfflineCacheService.getCachedTrialSessions(userId) ??
              const <Map<String, dynamic>>[];

      for (final s in cachedUpcoming) {
        addTutorFromSessionMap(s);
      }
      for (final s in cachedPast) {
        addTutorFromSessionMap(s);
      }
      for (final t in cachedTrials) {
        final status = (t['status'] as String? ?? '').toLowerCase();
        if (status == 'rejected' || status == 'cancelled') continue;
        final tid = t['tutor_id'] as String?;
        if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
      }

      if (tutorIds.isNotEmpty) return tutorIds.length;

      // As a final online fallback, try direct lightweight history query.
      try {
        final rows = await SupabaseService.client
            .from('individual_sessions')
            .select('tutor_id, recurring_sessions(tutor_id)')
            .or('learner_id.eq.$userId,parent_id.eq.$userId')
            .limit(200)
            .timeout(const Duration(seconds: 3));
        for (final row in (rows as List).cast<Map<String, dynamic>>()) {
          final recurring = row['recurring_sessions'] as Map<String, dynamic>?;
          final tid = (recurring?['tutor_id'] as String?) ??
              (row['tutor_id'] as String?);
          if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
        }
      } catch (_) {
        // Ignore online fallback failures; we keep existing value.
      }

      return tutorIds.length;
    } catch (e) {
      LogService.debug('Recover active tutors from history failed: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const StudentHomeSkeleton();
    }

    // Get greeting based on time
    final hour = DateTime.now().hour;
    String greeting = AppLocalizations.of(context)!.goodMorning;
    String greetingEmoji = '☀️';
    if (hour >= 12 && hour < 17) {
      greeting = AppLocalizations.of(context)!.goodAfternoon;
      greetingEmoji = '👋';
    } else if (hour >= 17) {
      greeting = AppLocalizations.of(context)!.goodEvening;
      greetingEmoji = '🌙';
    }

    // Extract city for quick actions (only actionable data)
    final city = _surveyData?['city'];

    return StatusBarUtils.withDarkStatusBar(
      Scaffold(
        backgroundColor: Colors.white,
        // SkulMate controlled by AppConfig feature flag
        floatingActionButton: AppConfig.enableSkulMate ? FloatingActionButton.extended(
        onPressed: () async {
          try {
            // Check onboarding status first
            final shouldShowOnboarding = await SkulMateOnboardingService.shouldShowOnboarding();
            
            if (shouldShowOnboarding) {
              // First time - show onboarding
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SkulMateOnboardingScreen(),
                ),
              );
              return;
            }

            final isOnline = await _connectivity.checkConnectivity();
            if (!isOnline) {
              // Offline: avoid remote game existence checks that can hang.
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GameLibraryScreen(initialTab: 1),
                ),
              );
              return;
            }

            // Check if user has any games
            final result = await SkulMateService.getGamesPaginated(limit: 1);
            final games = result['games'] as List;
            
            if (games.isEmpty) {
              // No games yet, navigate to create game screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SkulMateUploadScreen(),
                ),
              );
            } else {
              // Has games, navigate to game library (My Games tab by default)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GameLibraryScreen(initialTab: 1),
                ),
              );
            }
          } catch (e) {
            // On error, check onboarding first, then default to upload screen
            final hasCompletedOnboarding = await SkulMateOnboardingService.hasCompletedOnboarding();
            if (!hasCompletedOnboarding) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SkulMateOnboardingScreen(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SkulMateUploadScreen(),
                ),
              );
            }
          }
        },
        backgroundColor: AppTheme.primaryColor,
        label: Text(
          'skulMate',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        icon: PhosphorIcon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), color: Colors.white),
      ) : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          if (mounted) {
            setState(() => _homeRefreshKey++);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header - soft top-to-bottom gradient (matches theme-color deep blue)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
              ),
              padding: EdgeInsets.fromLTRB(
                ResponsiveHelper.responsiveHorizontalPadding(context),
                MediaQuery.of(context).padding.top + ResponsiveHelper.responsiveVerticalPadding(context),
                ResponsiveHelper.responsiveHorizontalPadding(context),
                ResponsiveHelper.responsiveVerticalPadding(context) + 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting $greetingEmoji',
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveHelper.responsiveBodySize(context),
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 2 : 4),
                            Text(
                              _userName,
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveHelper.responsiveHeadingSize(context) + 6,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const MessageIconBadge(iconColor: Colors.white),
                      SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 12, desktop: 16)),
                      NotificationBell(key: ValueKey('bell_$_homeRefreshKey'), iconColor: Colors.white),
                    ],
                  ),
                ],
              ),
            ),

            // Responsive content padding
            Padding(
              padding: ResponsiveHelper.responsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Survey Reminder Card (if survey not completed)
                  if (_showReminderCard && !_surveyCompleted)
                    SurveyReminderCard(
                      userType: _userType,
                      onTap: () {
                        // Navigate to profile-setup with userRole argument
                        Navigator.pushNamed(
                          context,
                          '/profile-setup',
                          arguments: {'userRole': _userType},
                        );
                      },
                    ),

                  // Quick Stats - Responsive
                  _buildSectionTitle(AppLocalizations.of(context)!.yourProgress),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: PhosphorIcons.graduationCap(),
                          label: AppLocalizations.of(context)!.activeTutors,
                          value: '$_activeTutorsCount',
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                      Expanded(
                        child: _buildStatCard(
                          icon: PhosphorIcons.calendar(),
                          label: AppLocalizations.of(context)!.sessions,
                          value: '$_allTimeSessionsCount',
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 24, tablet: 28, desktop: 32)),

                  // Quick Actions — one Sessions card with upcoming count; Requests has its own tab
                  _buildSectionTitle(AppLocalizations.of(context)!.quickActions),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                  _buildActionCard(
                    icon: PhosphorIcons.calendarCheck(),
                    title: AppLocalizations.of(context)!.mySessions,
                    subtitle: 'View upcoming sessions',
                    color: AppTheme.primaryColor,
                    trailingCount: _upcomingSessionsCount,
                    onTap: () {
                      Navigator.pushNamed(context, '/my-sessions');
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                  _buildActionCard(
                    icon: PhosphorIcons.creditCard(),
                    title: AppLocalizations.of(context)!.paymentHistory,
                    subtitle: 'View and manage your payments',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.pushNamed(context, '/payment-history');
                    },
                  ),
                  // Learning Progress (for parents)
                  if (_userType == 'parent') ...[
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                    _buildActionCard(
                      icon: PhosphorIcons.trendUp(),
                      title: 'Learning Progress',
                      subtitle: 'Track your child\'s learning journey and improvement',
                      color: AppTheme.primaryColor,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    PhosphorIcons.trendUp(),
                                    color: AppTheme.primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Learning Progress',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Coming Soon!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'We\'re building an amazing feature that will help you track your child\'s learning journey, view their progress across subjects, see improvement trends, and celebrate their achievements.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textMedium,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        PhosphorIcons.info(),
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'You\'ll be notified when this feature is available!',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppTheme.textDark,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // Removed "Your Goals" section - personal info belongs in profile
                  // This data is used behind the scenes for tutor matching, not for display
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 24, tablet: 32, desktop: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final iconSize = ResponsiveHelper.responsiveIconSize(context, mobile: 22, tablet: 26, desktop: 30);
    final padding = ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16);
    final valueSize = ResponsiveHelper.isSmallHeight(context)
        ? ResponsiveHelper.responsiveSubheadingSize(context)
        : ResponsiveHelper.responsiveSubheadingSize(context) + 2;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 4 : 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: valueSize,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 1 : 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
              color: AppTheme.textMedium,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    int? trailingCount,
    required VoidCallback onTap,
  }) {
    final cardPadding = ResponsiveHelper.responsiveSpacing(context, mobile: 14, tablet: 16, desktop: 18);
    final iconSize = ResponsiveHelper.responsiveIconSize(context, mobile: 20, tablet: 22, desktop: 24);
    final iconPadding = ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.softBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: iconSize),
              ),
              SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 2 : 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
                        color: AppTheme.textMedium,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailingCount != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$trailingCount',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                PhosphorIcons.caretRight(),
                size: ResponsiveHelper.responsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18),
                color: AppTheme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
