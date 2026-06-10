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
import 'package:shimmer/shimmer.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import '../../../features/skulmate/services/skulmate_service.dart';
import '../../../features/skulmate/models/game_model.dart';
import '../../../features/skulmate/utils/skulmate_game_launcher.dart';
import '../../../features/dashboard/widgets/student_home_promo_carousel.dart';
import '../../../features/dashboard/models/wallet_snapshot.dart';
import '../../../features/payment/services/session_points_service.dart';
import '../../../features/skulmate/screens/skulmate_plans_screen.dart';
import '../../../features/booking/models/upcoming_session_item.dart';
import '../../../features/booking/models/trial_session_model.dart';
import '../../../features/booking/screens/session_detail_screen.dart';
import '../../../features/dashboard/utils/home_stats_prefs.dart';
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
  List<UpcomingSessionItem> _upcomingSessions = [];
  List<GameModel> _skulMateGames = [];
  bool _skulMateGamesLoaded = false;
  bool _statsReady = false;
  bool _carouselReady = false;
  WalletSnapshot? _walletSnapshot;
  final ConnectivityService _connectivity = ConnectivityService();
  /// Incremented on pull-to-refresh so NotificationBell (and other keyed widgets) reload
  int _homeRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _loadUserData();
    _loadSkulMateGamesEarly();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_isLoading || !_carouselReady || !_statsReady) {
        safeSetState(() {
          _isLoading = false;
          _carouselReady = true;
          _statsReady = true;
        });
      }
    });
  }

  Future<void> _loadSkulMateGamesEarly() async {
    if (!AppConfig.enableSkulMate) {
      if (mounted) safeSetState(() => _skulMateGamesLoaded = true);
      return;
    }
    try {
      final result = await SkulMateService.getGamesPaginated(limit: 20)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      safeSetState(() {
        _skulMateGames = (result['games'] as List).cast<GameModel>();
        _skulMateGamesLoaded = true;
      });
    } catch (e) {
      LogService.debug('Student home early SkulMate load: $e');
      if (mounted) safeSetState(() => _skulMateGamesLoaded = true);
    }
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
      final userId = SupabaseService.client.auth.currentUser?.id;
      final cachedStats = await HomeStatsPrefs.read(prefs, userId);
      final cachedActiveTutors = cachedStats.activeTutors;
      final cachedAllTimeSessions = cachedStats.allTimeSessions;
      final cachedUpcomingSessions = cachedStats.upcomingSessions;
      WalletSnapshot? cachedWallet;
      if (userId != null && userId.isNotEmpty) {
        cachedWallet = WalletSnapshot(
          sessionCredits: prefs.getInt('home_wallet_session_credits_$userId') ?? 0,
          skulMateCredits: prefs.getInt('home_wallet_skulmate_credits_$userId') ?? 0,
          paidSessionsAhead:
              prefs.getInt('home_wallet_paid_sessions_$userId') ?? 0,
        );
      }

      List<UpcomingSessionItem> cachedUpcomingItems = const [];
      if (userId != null && userId.isNotEmpty) {
        final cachedUpcoming = await OfflineCacheService
                .getCachedIndividualSessions('${userId}_upcoming') ??
            const <Map<String, dynamic>>[];
        final cachedTrials =
            await OfflineCacheService.getCachedTrialSessions(userId) ??
                const <Map<String, dynamic>>[];
        final trialModels = cachedTrials
            .map((t) {
              try {
                return TrialSession.fromJson(t);
              } catch (_) {
                return null;
              }
            })
            .whereType<TrialSession>()
            .toList();
        cachedUpcomingItems = UpcomingSessionItem.mergeAndSort(
          individual: cachedUpcoming,
          trials: trialModels,
        );
      }

      var fastActiveTutors = cachedActiveTutors;
      var fastAllTimeSessions = cachedAllTimeSessions;
      var fastUpcomingSessions = cachedUpcomingSessions;
      if (cachedUpcomingItems.isNotEmpty) {
        fastUpcomingSessions = cachedUpcomingItems.length;
        final tutorIds = <String>{};
        for (final item in cachedUpcomingItems) {
          final recurring =
              item.sessionMap['recurring_sessions'] as Map<String, dynamic>?;
          final tid = (recurring?['tutor_id'] as String?) ??
              (item.sessionMap['tutor_id'] as String?);
          if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
        }
        if (tutorIds.isNotEmpty) fastActiveTutors = tutorIds.length;
        if (fastAllTimeSessions < fastUpcomingSessions) {
          fastAllTimeSessions = fastUpcomingSessions;
        }
      }

      final hasCachedHomeData = cachedUpcomingItems.isNotEmpty ||
          fastActiveTutors > 0 ||
          fastAllTimeSessions > 0 ||
          (cachedWallet != null &&
              (cachedWallet.sessionCredits > 0 ||
                  cachedWallet.paidSessionsAhead > 0));

      if (mounted) {
        safeSetState(() {
          _userName = cachedName;
          _userType = cachedUserRole == 'parent' ? 'parent' : 'student';
          _surveyCompleted = cachedSurveyCompleted;
          _isFirstVisit = !hasVisitedHome;
          _activeTutorsCount = fastActiveTutors;
          _allTimeSessionsCount = fastAllTimeSessions;
          _upcomingSessionsCount = fastUpcomingSessions;
          if (cachedUpcomingItems.isNotEmpty) {
            _upcomingSessions = cachedUpcomingItems;
          }
          _walletSnapshot = cachedWallet;
          _carouselReady = cachedUpcomingItems.isNotEmpty || cachedWallet != null;
          _statsReady = hasCachedHomeData;
          _isLoading = !hasCachedHomeData;
        });
      }

      // If offline, hydrate list from cache then skip remote roundtrips.
      final isOnline = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(milliseconds: 900), onTimeout: () => false);
      if (!isOnline) {
        LogService.info('🌐 [HOME] Offline startup: using cached home data');
        if (userId != null && userId.isNotEmpty) {
          final cachedUpcoming = await OfflineCacheService
                  .getCachedIndividualSessions('${userId}_upcoming') ??
              const <Map<String, dynamic>>[];
          final cachedTrials =
              await OfflineCacheService.getCachedTrialSessions(userId) ??
                  const <Map<String, dynamic>>[];
          final trialModels = cachedTrials
              .map((t) {
                try {
                  return TrialSession.fromJson(t);
                } catch (_) {
                  return null;
                }
              })
              .whereType<TrialSession>()
              .toList();
          final upcomingItems = UpcomingSessionItem.mergeAndSort(
            individual: cachedUpcoming,
            trials: trialModels,
          );
          if (mounted) {
            safeSetState(() {
              _upcomingSessions = upcomingItems;
              if (upcomingItems.isNotEmpty) {
                _upcomingSessionsCount = upcomingItems.length;
                _carouselReady = true;
                _statsReady = true;
              }
              _skulMateGamesLoaded = true;
              _isLoading = false;
            });
          }
        }
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
      List<Map<String, dynamic>>? loadedIndUpcoming;
      List<TrialSession>? loadedTrialUpcoming;
      var hasFreshStatsData = false;
      try {
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
          loadedIndUpcoming = indUpcoming;
          final userId = SupabaseService.client.auth.currentUser?.id;
          if (userId != null &&
              userId.isNotEmpty &&
              indUpcoming.isNotEmpty) {
            await OfflineCacheService.cacheIndividualSessions(
              '${userId}_upcoming',
              indUpcoming,
            );
          }
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

        List<TrialSession>? trials;
        try {
          trials = await TrialSessionService.getStudentTrialSessions()
              .timeout(const Duration(seconds: 6));
        } on TimeoutException {
          trials = null;
        }
        if (trials != null) {
          hasFreshStatsData = true;
          loadedTrialUpcoming = trials;
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
              loadedIndUpcoming = cachedUpcoming;
              loadedTrialUpcoming = cachedTrials
                  .map((t) {
                    try {
                      return TrialSession.fromJson(t);
                    } catch (_) {
                      return null;
                    }
                  })
                  .whereType<TrialSession>()
                  .toList();
              statsSource = 'offline_cache_fallback';
              LogService.info(
                'Student home stats loaded from local cache fallback: '
                'sessions=$allTimeSessions upcoming=$upcomingSessions tutors=$activeTutors',
              );
            } else {
              final scoped = await HomeStatsPrefs.read(prefs, userId);
              allTimeSessions = scoped.allTimeSessions;
              activeTutors = scoped.activeTutors;
              upcomingSessions = scoped.upcomingSessions;
              statsSource = 'scoped_prefs_fallback';
            }
          } else {
            allTimeSessions = 0;
            activeTutors = 0;
            upcomingSessions = 0;
            statsSource = 'no_user_zero';
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
      final persistUserId = SupabaseService.client.auth.currentUser?.id;
      if (persistUserId != null && persistUserId.isNotEmpty) {
        await HomeStatsPrefs.write(
          prefs,
          persistUserId,
          activeTutors: activeTutors,
          allTimeSessions: allTimeSessions,
          upcomingSessions: upcomingSessions,
        );
      }

      List<UpcomingSessionItem> upcomingItems = _upcomingSessions;
      try {
        upcomingItems = await IndividualSessionService
            .getStudentUpcomingItemsForHome(limit: 50)
            .timeout(const Duration(seconds: 8));
        upcomingSessions = upcomingItems.length;
        if (mounted && upcomingItems.isNotEmpty) {
          safeSetState(() {
            _upcomingSessions = upcomingItems;
            _upcomingSessionsCount = upcomingSessions;
            _carouselReady = true;
          });
        }
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId != null &&
            userId.isNotEmpty &&
            upcomingItems.isNotEmpty) {
          final rawMaps = upcomingItems
              .where((item) => !item.isTrial)
              .map((item) => item.sessionMap)
              .toList();
          if (rawMaps.isNotEmpty) {
            await OfflineCacheService.cacheIndividualSessions(
              '${userId}_upcoming',
              rawMaps,
            );
          }
        }
      } catch (e) {
        LogService.debug('Student home upcoming carousel load: $e');
        if (upcomingItems.isEmpty && upcomingSessions > 0) {
          final userId = SupabaseService.client.auth.currentUser?.id;
          if (userId != null && userId.isNotEmpty) {
            final cachedUpcoming = await OfflineCacheService
                    .getCachedIndividualSessions('${userId}_upcoming') ??
                const <Map<String, dynamic>>[];
            if (cachedUpcoming.isNotEmpty) {
              upcomingItems = await UpcomingSessionItem.enrichWithTutorProfiles(
                UpcomingSessionItem.mergeAndSort(
                  individual: cachedUpcoming,
                  trials: const [],
                ),
              );
              upcomingSessions = upcomingItems.length;
            }
          }
        }
      }

      WalletSnapshot? walletSnapshot = _walletSnapshot;
      try {
        final walletUserId = SupabaseService.client.auth.currentUser?.id;
        if (walletUserId != null && walletUserId.isNotEmpty) {
          final sessionCredits =
              await SessionPointsService.getAvailableSessionPoints();
          final paidSessions =
              await SessionPointsService.getPaidUpcomingSessionsCount();
          var skulMateCredits = _walletSnapshot?.skulMateCredits ?? 0;
          try {
            final row = await SupabaseService.client
                .from('user_credits')
                .select('balance')
                .eq('user_id', walletUserId)
                .maybeSingle()
                .timeout(const Duration(seconds: 4));
            skulMateCredits = (row?['balance'] as num?)?.toInt() ?? 0;
          } catch (_) {}

          walletSnapshot = WalletSnapshot(
            sessionCredits: sessionCredits,
            skulMateCredits: skulMateCredits,
            paidSessionsAhead: paidSessions,
          );
          await prefs.setInt(
            'home_wallet_session_credits_$walletUserId',
            sessionCredits,
          );
          await prefs.setInt(
            'home_wallet_skulmate_credits_$walletUserId',
            skulMateCredits,
          );
          await prefs.setInt(
            'home_wallet_paid_sessions_$walletUserId',
            paidSessions,
          );
        }
      } catch (e) {
        LogService.debug('Student home wallet load: $e');
      }

      List<GameModel> skulMateGames = _skulMateGames;
      var skulMateGamesLoaded = !AppConfig.enableSkulMate;
      if (AppConfig.enableSkulMate) {
        try {
          final result = await SkulMateService.getGamesPaginated(limit: 50)
              .timeout(const Duration(seconds: 6));
          skulMateGames = (result['games'] as List).cast<GameModel>();
        } catch (e) {
          LogService.debug('SkulMate games load for home teaser: $e');
        } finally {
          skulMateGamesLoaded = true;
        }
      }

      if (mounted) {
        safeSetState(() {
          _userName = userName;
          _activeTutorsCount = activeTutors;
          _allTimeSessionsCount = allTimeSessions;
          _upcomingSessionsCount = upcomingSessions;
          _upcomingSessions = upcomingItems;
          if (skulMateGames.isNotEmpty || _skulMateGames.isEmpty) {
            _skulMateGames = skulMateGames;
          }
          _skulMateGamesLoaded = skulMateGamesLoaded || _skulMateGamesLoaded;
          _carouselReady = true;
          _statsReady = true;
          _isLoading = false;
          if (walletSnapshot != null) {
            _walletSnapshot = walletSnapshot;
          }
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
        _carouselReady = true;
        _statsReady = true;
        _isLoading = false;
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

    // Extract city for quick actions (only actionable data)
    final city = _surveyData?['city'];

    final nextSession = _upcomingSessions.isNotEmpty ? _upcomingSessions.first : null;
    final skulMateTabIndex = AppConfig.enableSkulMate ? 2 : -1;

    return StatusBarUtils.withLightStatusBar(
      Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          centerTitle: false,
          title: Text(
            'Hi, $_userName',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.responsiveHeadingSize(context),
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            const MessageIconBadge(),
            Padding(
              padding: EdgeInsets.only(
                right: ResponsiveHelper.responsiveHorizontalPadding(context),
              ),
              child: NotificationBell(
                key: ValueKey('bell_$_homeRefreshKey'),
              ),
            ),
          ],
        ),
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
                        Navigator.pushNamed(
                          context,
                          '/profile-setup',
                          arguments: {'userRole': _userType},
                        );
                      },
                    ),

                  if (_showReminderCard && !_surveyCompleted)
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),

                  StudentHomePromoCarousel(
                    isReady: _carouselReady,
                    skulMateGames: _skulMateGames,
                    nextSession: nextSession,
                    upcomingSessionsCount: _upcomingSessionsCount,
                    wallet: _walletSnapshot,
                    userType: _userType,
                    onFindTutors: () => _switchStudentTab(1),
                    onOpenSession: _openSession,
                    onPlayGame: (game, {isDailyChallenge = false}) {
                      SkulMateGameLauncher.open(
                        context,
                        game,
                        isDailyChallenge: isDailyChallenge,
                      );
                    },
                    onOpenSkulMate: skulMateTabIndex >= 0
                        ? () => _switchStudentTab(skulMateTabIndex)
                        : null,
                    onCreateGame: skulMateTabIndex >= 0
                        ? () => _switchStudentTab(skulMateTabIndex)
                        : null,
                    onOpenWallet: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SkulmatePlansScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 14, tablet: 16, desktop: 18)),

                  _buildSectionTitle(AppLocalizations.of(context)!.yourProgress),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                  _statsReady
                      ? Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: PhosphorIcons.graduationCap(),
                                label: AppLocalizations.of(context)!.activeTutors,
                                value: '$_activeTutorsCount',
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(
                              width: ResponsiveHelper.responsiveSpacing(
                                context,
                                mobile: 12,
                                tablet: 16,
                                desktop: 20,
                              ),
                            ),
                            Expanded(
                              child: _buildStatCard(
                                icon: PhosphorIcons.calendar(),
                                label: AppLocalizations.of(context)!.sessions,
                                value: '$_allTimeSessionsCount',
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        )
                      : _buildStatsShimmer(),
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

  void _openSession(UpcomingSessionItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailScreen(session: item.sessionMap),
      ),
    );
  }

  void _switchStudentTab(int index) {
    Navigator.pushReplacementNamed(
      context,
      _userType == 'parent' ? '/parent-nav' : '/student-nav',
      arguments: {'initialTab': index},
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

  Widget _buildStatsShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.neutral200,
      highlightColor: Colors.white,
      child: Row(
        children: [
          Expanded(child: _statShimmerTile()),
          SizedBox(
            width: ResponsiveHelper.responsiveSpacing(
              context,
              mobile: 12,
              tablet: 16,
              desktop: 20,
            ),
          ),
          Expanded(child: _statShimmerTile()),
        ],
      ),
    );
  }

  Widget _statShimmerTile() {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.softBorder),
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
