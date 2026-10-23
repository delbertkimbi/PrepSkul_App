import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:prepskul/core/utils/tutor_search.dart';
import 'package:flutter/material.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'package:prepskul/core/design/prepskul_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/core/utils/tutor_display_name_utils.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/features/discovery/screens/tutor_detail_screen.dart';
import 'package:prepskul/features/group_classes/screens/group_classes_discovery_screen.dart';
import 'package:prepskul/features/booking/screens/request_tutor_flow_screen.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/tutor_matching_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import 'package:prepskul/core/services/offline_cache_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/data/app_data.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/utils/debouncer.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:prepskul/core/services/notification_permission_nudge_service.dart';
import 'package:prepskul/core/config/app_config.dart';

String _prepSkulSubjectGlyph(String subject) {
  final value = subject.toLowerCase();
  if (value.contains('math')) return 'maths';
  if (value.contains('french')) return 'french';
  if (value.contains('english')) return 'english';
  if (value.contains('computer') ||
      value.contains('informatics') ||
      value == 'ict') {
    return 'cs';
  }
  if (value.contains('physics') ||
      value.contains('chemistry') ||
      value == 'pct') {
    return 'pct';
  }
  if (value.contains('biology') ||
      value.contains('life') ||
      value.contains('earth') ||
      value == 'svt') {
    return 'svt';
  }
  if (value.contains('geography')) return 'geography';
  if (value.contains('history')) return 'histgeo';
  if (value.contains('philosophy')) return 'philo';
  if (value.contains('literature')) return 'literature';
  if (value.contains('economics')) return 'economics';
  return 'english';
}

class FindTutorsScreen extends StatefulWidget {
  const FindTutorsScreen({Key? key}) : super(key: key);

  @override
  State<FindTutorsScreen> createState() => _FindTutorsScreenState();
}

class _FindTutorsScreenState extends State<FindTutorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _tutors = [];
  List<Map<String, dynamic>> _filteredTutors = [];
  bool _isLoading = true;
  bool _isLoadingMore = false; // For pagination
  bool _hasMoreTutors = true; // Track if more tutors available
  int _currentOffset = 0; // Current pagination offset
  static const int _tutorsPerPage = 50; // Tutors per page
  List<MatchedTutor> _matchedTutors = []; // Store matched tutors with scores
  Map<String, MatchScore> _matchScores = {}; // Cache match scores by tutor ID
  String _sortBy = 'match'; // 'match', 'rating', 'price'
  String? _selectedSubject;
  String? _selectedPriceRange;
  double _minRating = 0.0;
  String? _userIdForSort;
  bool _isOffline = false;
  DateTime? _cacheTimestamp;
  final ConnectivityService _connectivity = ConnectivityService();

  // Smart subject list based on user preferences
  List<String> _subjects = [];
  List<String> _userPreferredSubjects = []; // User's subjects from survey
  bool _subjectsLoaded = false;

  // Default fallback subjects
  final List<String> _defaultSubjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'French',
    'History',
    'Geography',
    'Accounting',
    'Business Studies',
    'Agricultural Science',
    'Arts and Crafts',
    'Civic Education',
    'Computer Science',
    'Economics',
    'Environmental Studies',
    'Further Mathematics',
    'General Science',
    'German',
    'Home Economics',
    'ICT',
    'Literature',
    'Music',
    'Reading and Phonics',
    'Religious Studies',
    'Spanish',
    'Technical Drawing',
  ];

  // Tutor discovery compares a single session; frequency belongs to booking.
  List<Map<String, dynamic>> _getPriceRanges(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return [
      {
        'label': fr ? 'Moins de 3 000 XAF' : 'Under 3,000 XAF',
        'min': 0,
        'max': 2999,
      },
      {'label': '3,000–5,000 XAF', 'min': 3000, 'max': 4999},
      {'label': '5,000–8,000 XAF', 'min': 5000, 'max': 7999},
      {'label': '8,000–12,000 XAF', 'min': 8000, 'max': 11999},
      {
        'label': fr ? '12 000 XAF et plus' : '12,000 XAF and above',
        'min': 12000,
        'max': double.infinity,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _loadUserSubjects(); // Load user's preferred subjects first
    _loadTutors();

    // LinkedIn-style nudge: show on Find Tutors (common first screen for new installs).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        NotificationPermissionNudgeService.maybeShow(
          context,
          trigger: 'discovery',
        );
      });
    });

    // Listen to search text changes with debouncing
    _searchController.addListener(() {
      _searchDebouncer.run(() {
        if (mounted) {
          _filterTutors();
        }
      });
    });

    // Listen to scroll for lazy loading
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_filterTutors);
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  /// Handle scroll events for lazy loading
  void _onScroll() {
    // Load more tutors when user scrolls near the bottom
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreTutors &&
        !_isLoading &&
        !_isOffline) {
      _loadMoreTutors();
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
        safeSetState(() {
          _isOffline = !isOnline;
        });

        // If came back online, reload tutors and clear offline state
        if (isOnline && wasOffline) {
          LogService.info('🌐 Connection restored - reloading tutors');
          _loadTutors();
        }
      }
    });
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.checkConnectivity();
    if (mounted) {
      final wasOffline = _isOffline;
      safeSetState(() {
        _isOffline = !isOnline;
      });

      // If we just came back online, reload data
      if (isOnline && wasOffline) {
        LogService.info('🌐 Connection detected - reloading tutors');
        _loadTutors();
      }
    }
  }

  /// Load user's subjects from survey and build smart subject list
  Future<void> _loadUserSubjects() async {
    try {
      final userProfile = await AuthService.getUserProfile();
      if (userProfile == null) {
        // No user profile - use default subjects
        safeSetState(() {
          _subjects = _defaultSubjects;
          _subjectsLoaded = true;
        });
        return;
      }

      final userType = userProfile['user_type']?.toString();
      if (userType != 'student' && userType != 'parent') {
        // Not a student/parent - use default subjects
        safeSetState(() {
          _subjects = _defaultSubjects;
          _subjectsLoaded = true;
        });
        return;
      }

      // Load survey data
      Map<String, dynamic>? surveyData;
      if (userType == 'student') {
        surveyData = await SurveyRepository.getStudentSurvey(userProfile['id']);
      } else if (userType == 'parent') {
        surveyData = await SurveyRepository.getParentSurvey(userProfile['id']);
      }

      if (surveyData != null && mounted) {
        // Get user's preferred subjects from survey
        final userSubjects = List<String>.from(surveyData['subjects'] ?? []);

        // Get education level, system, and stream for dynamic subject loading
        final system =
            surveyData['school_system']?.toString() ??
            surveyData['system']?.toString() ??
            'anglophone';
        final onboarding = surveyData['onboarding_context'];
        final stream =
            surveyData['stream']?.toString() ??
            (onboarding is Map ? onboarding['streamId']?.toString() : null);
        final eduLevel = surveyData['education_level']?.toString();

        // Load available subjects based on user's niche
        List<String> availableSubjects = [];
        if (eduLevel != null) {
          String levelKey = _mapEducationLevelToKey(eduLevel);
          availableSubjects = AppData.getSubjectsForLevel(
            levelKey,
            system,
            stream: stream,
          );
        }

        // Combine user's subjects with available subjects
        // Priority: User's subjects first, then other available subjects, then default
        final Set<String> allSubjectsSet = {};

        // Add user's preferred subjects first (these will be highlighted)
        for (var subject in userSubjects) {
          allSubjectsSet.add(subject);
        }

        // Add available subjects based on education level/stream
        for (var subject in availableSubjects) {
          allSubjectsSet.add(subject);
        }

        // If still empty or very few, add default subjects
        if (allSubjectsSet.isEmpty) {
          for (var subject in _defaultSubjects) {
            allSubjectsSet.add(subject);
          }
        }

        // Convert to list and sort: user's subjects first, then alphabetically
        final List<String> sortedSubjects = [];

        // Add user's preferred subjects first
        for (var subject in userSubjects) {
          if (allSubjectsSet.contains(subject) &&
              !sortedSubjects.contains(subject)) {
            sortedSubjects.add(subject);
          }
        }

        // Add other available subjects (alphabetically)
        final otherSubjects =
            allSubjectsSet.where((s) => !userSubjects.contains(s)).toList()
              ..sort();
        sortedSubjects.addAll(otherSubjects);

        if (mounted) {
          safeSetState(() {
            _userPreferredSubjects = userSubjects;
            _subjects = sortedSubjects.isNotEmpty
                ? sortedSubjects
                : _defaultSubjects;
            _subjectsLoaded = true;
          });
        }
      } else {
        // No survey data - use default subjects
        if (mounted) {
          safeSetState(() {
            _subjects = _defaultSubjects;
            _subjectsLoaded = true;
          });
        }
      }
    } catch (e) {
      LogService.warning('Error loading user subjects: $e');
      // Fallback to default subjects
      if (mounted) {
        safeSetState(() {
          _subjects = _defaultSubjects;
          _subjectsLoaded = true;
        });
      }
    }
  }

  /// Map education level from survey to AppData key format
  String _mapEducationLevelToKey(String eduLevel) {
    final level = eduLevel.toLowerCase();
    if (level.contains('primary')) return 'primary';
    if (level.contains('secondary') || level.contains('high school')) {
      if (level.contains('lower') ||
          level.contains('form 1') ||
          level.contains('form 2') ||
          level.contains('form 3') ||
          level.contains('grade 7') ||
          level.contains('grade 8') ||
          level.contains('grade 9')) {
        return 'lower_secondary';
      }
      if (level.contains('upper') ||
          level.contains('form 4') ||
          level.contains('form 5') ||
          level.contains('form 6') ||
          level.contains('grade 10') ||
          level.contains('grade 11') ||
          level.contains('grade 12')) {
        return 'upper_secondary';
      }
      return 'upper_secondary'; // Default to upper secondary
    }
    if (level.contains('university') ||
        level.contains('college') ||
        level.contains('undergraduate')) {
      return 'university';
    }
    return 'upper_secondary'; // Default fallback
  }

  Future<void> _loadTutors() async {
    safeSetState(() {
      _isLoading = true;
      _currentOffset = 0;
      _hasMoreTutors = true;
    });

    try {
      // Check connectivity first - always get fresh status
      final isOnline = await _connectivity.checkConnectivity();
      if (mounted) {
        safeSetState(() {
          _isOffline = !isOnline;
        });
      }

      // If offline, try cache first — but still attempt network if cache is empty
      // (connectivity checks can be wrong on web while Supabase still works).
      if (_isOffline) {
        LogService.info(
          'FindTutorsScreen: Offline signal — trying cache first...',
        );
        final cachedTutors = await OfflineCacheService.getCachedTutors();
        if (cachedTutors != null && cachedTutors.isNotEmpty) {
          final currentUserData = await AuthService.getCurrentUser();
          final cachedUserId = currentUserData?['id']?.toString();
          final orderedCachedTutors = _applyUserSpecificOrder(
            cachedTutors,
            cachedUserId,
          );
          final timestamp = await SharedPreferences.getInstance().then(
            (prefs) => prefs.getInt('cached_tutors_timestamp') ?? 0,
          );
          if (mounted) {
            safeSetState(() {
              _userIdForSort = cachedUserId;
              _tutors = orderedCachedTutors;
              _filteredTutors = orderedCachedTutors;
              _isLoading = false;
              _hasMoreTutors = false;
              _cacheTimestamp = timestamp > 0
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                  : null;
            });
          }
          LogService.success(
            'FindTutorsScreen: Loaded ${cachedTutors.length} tutors from cache',
          );
          return;
        }
        LogService.warning(
          'FindTutorsScreen: Cache empty — attempting network fetch anyway',
        );
      }

      LogService.debug('FindTutorsScreen: Starting to load tutors...');

      // Get current user info
      final currentUserData = await AuthService.getCurrentUser();
      if (currentUserData == null) {
        // Fallback to regular tutor loading if no user
        final tutors = await TutorService.fetchTutors(
          limit: _tutorsPerPage,
          offset: _currentOffset,
        );
        final orderedTutors = _applyUserSpecificOrder(tutors, null);
        // Cache the tutors
        await OfflineCacheService.cacheTutors(tutors);
        if (mounted) {
          safeSetState(() {
            _userIdForSort = null;
            _tutors = orderedTutors;
            _filteredTutors = orderedTutors;
            _isLoading = false;
            _currentOffset = orderedTutors.length;
            _hasMoreTutors = orderedTutors.length >= _tutorsPerPage;
            _cacheTimestamp = DateTime.now();
          });
        }
        return;
      }

      // Determine user type - only if we have a valid user ID
      final userId = currentUserData['id']?.toString();
      final userType = userId != null && userId.isNotEmpty
          ? await _getUserType(userId)
          : 'student'; // Default to student if no valid ID
      _userIdForSort = userId;

      // Use matching algorithm if user has preferences
      try {
        final matchedTutors = await TutorMatchingService.matchTutorsForUser(
          userId: userId ?? '',
          userType: userType,
          filters: {
            if (_selectedSubject != null) 'subject': _selectedSubject,
            if (_selectedPriceRange != null) ..._getPriceRangeFilters(),
            if (_minRating > 0) 'minRating': _minRating,
          },
        );

        if (matchedTutors.isNotEmpty) {
          // Use matched tutors (matching service handles pagination internally)
          final tutorList = matchedTutors.map((mt) => mt.tutor).toList();
          // Cache the tutors
          await OfflineCacheService.cacheTutors(tutorList);
          safeSetState(() {
            _matchedTutors = matchedTutors;
            _tutors = tutorList;
            _matchScores = {
              for (var mt in matchedTutors)
                mt.tutor['id'] as String: mt.matchScore,
            };
            _filteredTutors = _tutors;
            _isLoading = false;
            _currentOffset = tutorList.length;
            _hasMoreTutors = false; // Matching service returns all matches
            _cacheTimestamp = DateTime.now();
          });
          LogService.success(
            'FindTutorsScreen: Loaded ${matchedTutors.length} matched tutors',
          );
        } else {
          // Fallback to regular loading if no matches
          final tutors = await TutorService.fetchTutors(
            limit: _tutorsPerPage,
            offset: _currentOffset,
          );
          final orderedTutors = _applyUserSpecificOrder(tutors, userId);
          // Cache the tutors
          await OfflineCacheService.cacheTutors(tutors);
          if (mounted) {
            safeSetState(() {
              _tutors = orderedTutors;
              _filteredTutors = orderedTutors;
              _isLoading = false;
              _currentOffset = orderedTutors.length;
              _hasMoreTutors = orderedTutors.length >= _tutorsPerPage;
              _cacheTimestamp = DateTime.now();
            });
          }
          LogService.warning(
            'FindTutorsScreen: No matches found, using regular tutor list',
          );
        }
      } catch (e) {
        // Fallback to regular loading on error
        LogService.warning(
          'FindTutorsScreen: Matching error, using regular loading: $e',
        );
        final tutors = await TutorService.fetchTutors(
          limit: _tutorsPerPage,
          offset: _currentOffset,
        );
        final orderedTutors = _applyUserSpecificOrder(tutors, userId);
        // Cache the tutors
        await OfflineCacheService.cacheTutors(tutors);
        if (mounted) {
          safeSetState(() {
            _tutors = orderedTutors;
            _filteredTutors = orderedTutors;
            _isLoading = false;
            _currentOffset = orderedTutors.length;
            _hasMoreTutors = orderedTutors.length >= _tutorsPerPage;
            _cacheTimestamp = DateTime.now();
          });
        }
      }
      if (mounted && _tutors.isEmpty) {
        final cachedTutors = await OfflineCacheService.getCachedTutors();
        if (cachedTutors != null && cachedTutors.isNotEmpty) {
          final ordered = _applyUserSpecificOrder(cachedTutors, _userIdForSort);
          safeSetState(() {
            _tutors = ordered;
            _filteredTutors = ordered;
            _isLoading = false;
          });
          LogService.info(
            'FindTutorsScreen: Restored ${ordered.length} tutors from cache after empty fetch',
          );
        }
      }
    } catch (e, stackTrace) {
      LogService.error('FindTutorsScreen: Error loading tutors: $e');
      LogService.error('Error type: ${e.runtimeType}');
      LogService.error('Stack trace: $stackTrace');

      // Log specific error details for null type errors
      if (e.toString().contains('null') || e.toString().contains('Null')) {
        LogService.warning(
          'Null type error detected - checking tutor data transformation',
        );
        LogService.warning(
          'This may indicate a field is null when String is expected',
        );
      }

      if (mounted) {
        safeSetState(() => _isLoading = false);
        ErrorHandlerService.showErrorSnackbar(
          context,
          e,
          'Failed to load tutors. Please try again.',
        );
      }
    }
  }

  /// Load more tutors when scrolling down (lazy loading)
  Future<void> _loadMoreTutors() async {
    if (_isLoadingMore || !_hasMoreTutors || _isOffline) return;

    try {
      safeSetState(() {
        _isLoadingMore = true;
      });

      final newTutors = await TutorService.fetchTutors(
        limit: _tutorsPerPage,
        offset: _currentOffset,
      );

      if (mounted && newTutors.isNotEmpty) {
        safeSetState(() {
          // Append and reorder to keep a stable, user-specific ordering
          _tutors = _applyUserSpecificOrder([
            ..._tutors,
            ...newTutors,
          ], _userIdForSort);
          _filteredTutors = _tutors; // Re-apply filters if needed
          _currentOffset = _tutors.length;
          _hasMoreTutors = newTutors.length >= _tutorsPerPage;
          _isLoadingMore = false;
        });
      } else {
        safeSetState(() {
          _hasMoreTutors = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      LogService.error('Error loading more tutors: $e');
      if (mounted) {
        safeSetState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<String> _getUserType(String userId) async {
    try {
      // Validate userId - must not be empty for UUID queries
      if (userId.isEmpty || userId.trim().isEmpty) {
        LogService.warning(
          'Empty userId provided to _getUserType, defaulting to student',
        );
        return 'student';
      }

      // Check if user is a parent
      final parentProfile = await SupabaseService.client
          .from('parent_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (parentProfile != null) return 'parent';

      // Check if user is a student
      final learnerProfile = await SupabaseService.client
          .from('learner_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (learnerProfile != null) return 'student';

      return 'student'; // Default
    } catch (e) {
      LogService.warning('Error determining user type: $e');
      return 'student';
    }
  }

  Map<String, dynamic> _getPriceRangeFilters() {
    if (_selectedPriceRange == null) return {};
    final ranges = _getPriceRanges(context);
    final range = ranges.firstWhere(
      (r) => r['label'] == _selectedPriceRange,
      orElse: () => {'min': 0, 'max': 200000},
    );
    return {'minRate': range['min'] as int, 'maxRate': range['max'] as int};
  }

  void _filterTutors() {
    safeSetState(() {
      _filteredTutors = _tutors.where((tutor) {
        if (!TutorSearch.matches(tutor, _searchController.text)) return false;

        if (_selectedSubject != null) {
          final subjects = tutor['subjects'] as List?;
          if (subjects == null || !subjects.contains(_selectedSubject)) {
            return false;
          }
        }

        if (_selectedPriceRange != null) {
          final priceRange = _getPriceRanges(
            context,
          ).firstWhere((range) => range['label'] == _selectedPriceRange);
          // Compare the actual per-session rate
          final pricing = PricingService.calculateFromTutorData(tutor);
          final sessionPrice = (pricing['perSession'] ?? 0.0) as double;
          if (sessionPrice < priceRange['min'] ||
              sessionPrice > priceRange['max']) {
            return false;
          }
        }

        final rating = (tutor['rating'] ?? 0.0).toDouble();
        if (rating < _minRating) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    safeSetState(() {
      _searchController.clear();
      _selectedSubject = null;
      _selectedPriceRange = null;
      _minRating = 0.0;
    });
    _filterTutors(); // Apply cleared filters
  }

  // Check if any filter is active
  bool get _isFilterActive =>
      _searchController.text.isNotEmpty ||
      _selectedSubject != null ||
      _selectedPriceRange != null ||
      _minRating > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardPalette.cream,
      appBar: AppBar(
        toolbarHeight: 48,
        automaticallyImplyLeading: false, // Remove back button
        elevation: 0,
        backgroundColor: OnboardPalette.cream,
        surfaceTintColor: OnboardPalette.cream,
        title: Text(
          Localizations.localeOf(context).languageCode == 'fr'
              ? 'Trouve ton tuteur'
              : 'Find your tutor',
          style: LearnerDesign.title(22),
        ),
        actions: [
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'fr'
                ? 'Demander un tuteur'
                : 'Request a tutor',
            icon: const PrepSkulIcon(PrepSkulGlyph.tutorRequest),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RequestTutorFlowScreen()),
            ),
          ),
          if (AppConfig.enableGroupClasses)
            IconButton(
              icon: Icon(
                Icons.groups_outlined,
                color: _isOffline ? Colors.grey[400] : Colors.black,
              ),
              onPressed: _isOffline
                  ? () => OfflineDialog.show(
                      context,
                      message:
                          'Group classes require an internet connection. Please check your connection and try again.',
                    )
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const GroupClassesDiscoveryScreen(),
                        ),
                      );
                    },
              tooltip: _isOffline
                  ? 'Group classes unavailable offline'
                  : 'Group classes',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Section - Responsive
          Container(
            padding: EdgeInsets.fromLTRB(
              ResponsiveHelper.responsiveHorizontalPadding(context),
              ResponsiveHelper.responsiveSpacing(
                context,
                mobile: 0,
                tablet: 0,
                desktop: 0,
              ),
              ResponsiveHelper.responsiveHorizontalPadding(context),
              ResponsiveHelper.responsiveSpacing(
                context,
                mobile: 8,
                tablet: 8,
                desktop: 8,
              ),
            ),
            child: Column(
              children: [
                // Search Bar - Responsive
                Container(
                  height: ResponsiveHelper.responsiveSpacing(
                    context,
                    mobile: 44,
                    tablet: 44,
                    desktop: 44,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LearnerDesign.line),
                  ),
                  child: TextField(
                    controller: _searchController,
                    enabled:
                        true, // Filter already loaded tutors without a network request
                    onChanged: (_) {
                      safeSetState(() {});
                      _filterTutors();
                    },
                    style: GoogleFonts.nunito(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          Localizations.localeOf(context).languageCode == 'fr'
                          ? 'Matière, examen ou tuteur'
                          : 'Subject, exam or tutor',
                      hintStyle: GoogleFonts.nunito(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[600],
                        size: ResponsiveHelper.responsiveIconSize(
                          context,
                          mobile: 20,
                          tablet: 22,
                          desktop: 24,
                        ),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.grey[600],
                                size: ResponsiveHelper.responsiveIconSize(
                                  context,
                                  mobile: 18,
                                  tablet: 20,
                                  desktop: 22,
                                ),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                safeSetState(() {});
                                _filterTutors();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveHelper.responsiveHorizontalPadding(
                              context,
                            ),
                        vertical: ResponsiveHelper.responsiveSpacing(
                          context,
                          mobile: 12,
                          tablet: 14,
                          desktop: 16,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _quickFilter(0)),
                    const SizedBox(width: 8),
                    Expanded(child: _quickFilter(1)),
                    const SizedBox(width: 8),
                    Expanded(child: _quickFilter(2)),
                  ],
                ),
                // Active Filters - Responsive
                if (_selectedSubject != null ||
                    _selectedPriceRange != null ||
                    _minRating > 0)
                  Padding(
                    padding: EdgeInsets.only(
                      top: ResponsiveHelper.responsiveSpacing(
                        context,
                        mobile: 10,
                        tablet: 12,
                        desktop: 14,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (_selectedSubject != null)
                                  _buildFilterChip(_selectedSubject!, () {
                                    safeSetState(() => _selectedSubject = null);
                                    _filterTutors();
                                  }),
                                if (_selectedPriceRange != null) ...[
                                  SizedBox(
                                    width: ResponsiveHelper.responsiveSpacing(
                                      context,
                                      mobile: 8,
                                      tablet: 10,
                                      desktop: 12,
                                    ),
                                  ),
                                  _buildFilterChip(_selectedPriceRange!, () {
                                    safeSetState(
                                      () => _selectedPriceRange = null,
                                    );
                                    _filterTutors();
                                  }),
                                ],
                                if (_minRating > 0) ...[
                                  SizedBox(
                                    width: ResponsiveHelper.responsiveSpacing(
                                      context,
                                      mobile: 8,
                                      tablet: 10,
                                      desktop: 12,
                                    ),
                                  ),
                                  _buildFilterChip(
                                    '${_minRating.toInt()}+ ⭐',
                                    () {
                                      safeSetState(() => _minRating = 0.0);
                                      _filterTutors();
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: Text(
                            'Clear',
                            style: GoogleFonts.nunito(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: ResponsiveHelper.responsiveBodySize(
                                context,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Results Count and Cache Info - Responsive
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.responsiveHorizontalPadding(context),
              vertical: ResponsiveHelper.responsiveSpacing(
                context,
                mobile: 6,
                tablet: 8,
                desktop: 10,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isFilterActive)
                  Text(
                    'Found ${_filteredTutors.length} tutor${_filteredTutors.length != 1 ? 's' : ''}',
                    style: GoogleFonts.nunito(
                      fontSize: ResponsiveHelper.responsiveBodySize(context),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
              ],
            ),
          ),

          // Tutors List
          Expanded(
            child: _isLoading
                ? ShimmerLoading.tutorList(
                    count: 5,
                  ) // ✨ Beautiful shimmer loading
                : _filteredTutors.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _isOffline
                        ? () => OfflineDialog.show(
                            context,
                            message:
                                'Refresh requires an internet connection. Please check your connection and try again.',
                          )
                        : _loadTutors,
                    child: ResponsiveHelper.isMobile(context)
                        ? ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              ResponsiveHelper.responsiveHorizontalPadding(
                                context,
                              ),
                              0,
                              ResponsiveHelper.responsiveHorizontalPadding(
                                context,
                              ),
                              ResponsiveHelper.responsiveVerticalPadding(
                                context,
                              ),
                            ),
                            itemCount:
                                _filteredTutors.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator at bottom when loading more
                              if (_isLoadingMore &&
                                  index == _filteredTutors.length) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical:
                                        ResponsiveHelper.responsiveSpacing(
                                          context,
                                          mobile: 12,
                                          tablet: 16,
                                          desktop: 20,
                                        ),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (index >= _filteredTutors.length) {
                                return const SizedBox.shrink();
                              }

                              return _buildTutorCard(_filteredTutors[index]);
                            },
                          )
                        : GridView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              ResponsiveHelper.responsiveHorizontalPadding(
                                context,
                              ),
                              0,
                              ResponsiveHelper.responsiveHorizontalPadding(
                                context,
                              ),
                              ResponsiveHelper.responsiveVerticalPadding(
                                context,
                              ),
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      ResponsiveHelper.responsiveGridColumns(
                                        context,
                                      ),
                                  crossAxisSpacing:
                                      ResponsiveHelper.responsiveSpacing(
                                        context,
                                        mobile: 12,
                                        tablet: 16,
                                        desktop: 20,
                                      ),
                                  mainAxisSpacing:
                                      ResponsiveHelper.responsiveSpacing(
                                        context,
                                        mobile: 12,
                                        tablet: 16,
                                        desktop: 20,
                                      ),
                                  childAspectRatio:
                                      ResponsiveHelper.isTablet(context)
                                      ? 0.75
                                      : 0.7,
                                ),
                            itemCount:
                                _filteredTutors.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator at bottom when loading more
                              if (_isLoadingMore &&
                                  index == _filteredTutors.length) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (index >= _filteredTutors.length) {
                                return const SizedBox.shrink();
                              }

                              return _buildTutorCard(_filteredTutors[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingIndicator(
    int rating,
    String label, {
    StateSetter? modalSetState,
  }) {
    // Show as selected if this exact rating value is closest to current minRating
    // Round to nearest integer for selection
    final currentRating = _minRating.round();
    final isSelected = currentRating == rating;
    return GestureDetector(
      onTap: () {
        // Update parent state first
        safeSetState(() {
          _minRating = rating.toDouble();
        });
        // Then update modal state to reflect the change in the popup
        // This ensures the blue active state updates in the modal
        if (modalSetState != null) {
          // Schedule modal state update after current frame to ensure parent state is committed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            modalSetState(() {});
          });
        }
        _filterTutors(); // Apply filter when rating indicator is tapped
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[200],
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close, size: 14, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorCard(Map<String, dynamic> tutor) {
    final rawProfile = tutor['profiles'];
    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : <String, dynamic>{};
    final name = TutorDisplayNameUtils.cardLabel(tutor, profile);
    final rating = (tutor['rating'] as num?)?.toDouble() ?? 0;
    final subjects = (tutor['subjects'] as List? ?? [])
        .map((s) => s.toString())
        .take(3)
        .toList();
    final price =
        PricingService.calculateFromTutorData(tutor)['perSession'] as double;
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final photo =
        tutor['avatar_url'] ??
        tutor['profile_photo_url'] ??
        profile['avatar_url'];
    final bio = (tutor['personal_statement'] ?? tutor['bio'] ?? '')
        .toString()
        .trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x181B2C4F),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFC9D6E4), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _isOffline
                ? () => OfflineDialog.show(
                    context,
                    message: fr
                        ? 'Reconnecte-toi pour voir ce profil.'
                        : 'Reconnect to view this tutor.',
                  )
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TutorDetailScreen(tutor: tutor),
                    ),
                  ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 72,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _buildAvatarImage(photo, name),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: LearnerDesign.title(19),
                            ),
                            const SizedBox(height: 6),
                            if (rating > 0)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFB800),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: LearnerDesign.body(
                                      13,
                                    ).copyWith(color: LearnerDesign.ink),
                                  ),
                                ],
                              )
                            else
                              Text(
                                fr ? 'Découvre son profil' : 'Get to know them',
                                style: LearnerDesign.body(12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (subjects.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: subjects
                          .map(
                            (subject) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: LearnerDesign.sky,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                subject,
                                style: LearnerDesign.body(
                                  12,
                                ).copyWith(color: LearnerDesign.ink),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LearnerDesign.body(13),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: LearnerDesign.line),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              PricingService.formatPrice(price),
                              style: LearnerDesign.title(19),
                            ),
                            Text(
                              fr ? 'par séance' : 'per session',
                              style: LearnerDesign.body(12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: LearnerDesign.ink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fr ? 'Voir le profil' : 'View profile',
                              style: LearnerDesign.text(
                                size: 13,
                                weight: FontWeight.w700,
                              ).copyWith(color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getMatchScoreColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        safeSetState(() {
          _sortBy = value;
          _applySorting();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applySorting() {
    safeSetState(() {
      _filteredTutors.sort((a, b) {
        switch (_sortBy) {
          case 'match':
            final scoreA = _matchScores[a['id'] as String?]?.totalScore ?? 0.0;
            final scoreB = _matchScores[b['id'] as String?]?.totalScore ?? 0.0;
            return scoreB.compareTo(scoreA);
          case 'rating':
            final ratingA = (a['rating'] ?? 0.0) as double;
            final ratingB = (b['rating'] ?? 0.0) as double;
            return ratingB.compareTo(ratingA);
          case 'price':
            final pricingA = PricingService.calculateFromTutorData(a);
            final pricingB = PricingService.calculateFromTutorData(b);
            final priceA = (pricingA['perSession'] ?? 0.0) as double;
            final priceB = (pricingB['perSession'] ?? 0.0) as double;
            return priceA.compareTo(priceB);
          default:
            return 0;
        }
      });
    });
  }

  int _stableHash(String input) {
    return input.codeUnits.fold(
      0,
      (hash, code) => (hash * 31 + code) & 0x7fffffff,
    );
  }

  List<Map<String, dynamic>> _applyUserSpecificOrder(
    List<Map<String, dynamic>> tutors,
    String? userId,
  ) {
    if (tutors.isEmpty) return tutors;
    final ordered = List<Map<String, dynamic>>.from(tutors);
    if (userId == null || userId.trim().isEmpty) {
      ordered.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
      return ordered;
    }

    ordered.sort((a, b) {
      final idA = (a['id'] ?? a['user_id'] ?? a['full_name'] ?? '').toString();
      final idB = (b['id'] ?? b['user_id'] ?? b['full_name'] ?? '').toString();
      final keyA = _stableHash('$userId-$idA');
      final keyB = _stableHash('$userId-$idB');
      return keyA.compareTo(keyB);
    });

    return ordered;
  }

  Widget _buildSessionPrice(Map<String, dynamic> tutor) {
    final amount =
        PricingService.calculateFromTutorData(tutor)['perSession'] as double;
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return Flexible(
      child: Text(
        '${PricingService.formatPrice(amount)} / ${fr ? 'séance' : 'session'}',
        textAlign: TextAlign.end,
        style: LearnerDesign.body(
          13,
        ).copyWith(color: LearnerDesign.ink, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Regular empty state
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),

          // Clear filters button
          TextButton(
            onPressed: _clearFilters,
            child: Text(
              'Clear all filters/search',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Request Tutor CTA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: LearnerDesign.surface(),
            child: Column(
              children: [
                prepMate(mood: Mood.point, size: 72),
                const SizedBox(height: 16),
                Text(
                  'Need help finding a tutor?',
                  style: onboardDisplay(size: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Find a tutor, or request one. Live online, or onsite.',
                  style: onboardFont(
                    size: 14,
                    weight: FontWeight.w700,
                    color: AppTheme.textMedium,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OnboardPrimaryButton(
                  label: 'Request a tutor',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RequestTutorFlowScreen(
                          prefillData: {
                            'subjects': _selectedSubject != null
                                ? [_selectedSubject]
                                : [],
                            'teaching_mode': null,
                            'location': null,
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get human-readable cache age text
  String _getCacheAgeText(DateTime cacheTime) {
    final now = DateTime.now();
    final difference = now.difference(cacheTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  Widget _quickFilter(int kind) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final labels = fr
        ? ['Matière', 'Prix', 'Avis']
        : ['Subject', 'Price', 'Rating'];
    final value = switch (kind) {
      0 => _selectedSubject,
      1 => _selectedPriceRange,
      _ => _minRating > 0 ? '${_minRating.toInt()}+' : null,
    };
    return Material(
      color: value == null ? Colors.white : LearnerDesign.sky,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: LearnerDesign.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickQuickFilter(kind),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? labels[kind],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LearnerDesign.text(size: 13, weight: FontWeight.w700),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: LearnerDesign.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickQuickFilter(int kind) async {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final options = switch (kind) {
      0 =>
        (_subjects.toList()..sort((a, b) {
          final ap = _userPreferredSubjects.contains(a);
          final bp = _userPreferredSubjects.contains(b);
          if (ap != bp) return ap ? -1 : 1;
          return a.toLowerCase().compareTo(b.toLowerCase());
        })),
      1 => _getPriceRanges(context).map((r) => r['label'].toString()).toList(),
      _ => ['3+', '4+', '5'],
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: LearnerDesign.canvas,
      constraints: const BoxConstraints(maxWidth: 560),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            children: [
              Text(
                (fr
                    ? ['Matière', 'Prix par séance', 'Note minimale']
                    : ['Subject', 'Price per session', 'Minimum rating'])[kind],
                style: LearnerDesign.title(22),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    ListTile(
                      leading: const PrepSkulIcon(PrepSkulGlyph.learn),
                      title: Text(fr ? 'Tous' : 'Any'),
                      onTap: () => Navigator.pop(sheetContext, ''),
                    ),
                    for (final option in options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          tileColor: Colors.white,
                          leading: PrepSkulIcon(
                            kind == 0
                                ? PrepSkulGlyph.learn
                                : kind == 1
                                ? PrepSkulGlyph.price
                                : PrepSkulGlyph.rating,
                          ),
                          title: Text(
                            option,
                            style: LearnerDesign.text(size: 15),
                          ),
                          subtitle:
                              kind == 0 &&
                                  _userPreferredSubjects.contains(option)
                              ? Text(
                                  fr
                                      ? 'Pour ton parcours'
                                      : 'From your learning preferences',
                                  style: LearnerDesign.body(12),
                                )
                              : null,
                          selected: kind == 0
                              ? option == _selectedSubject
                              : kind == 1
                              ? option == _selectedPriceRange
                              : option ==
                                    (_minRating == 5
                                        ? '5'
                                        : '${_minRating.toInt()}+'),
                          selectedTileColor: const Color(0xFFE0F2FC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onTap: () => Navigator.pop(sheetContext, option),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    safeSetState(() {
      if (kind == 0) _selectedSubject = selected.isEmpty ? null : selected;
      if (kind == 1) _selectedPriceRange = selected.isEmpty ? null : selected;
      if (kind == 2)
        _minRating = selected.isEmpty
            ? 0
            : double.parse(selected.replaceAll('+', ''));
    });
    _filterTutors();
  }

  Widget _buildAvatarImage(
    String? avatarUrl,
    String name, {
    bool isLarge = false,
  }) {
    // Check if avatarUrl is a network URL or asset path
    final isNetworkUrl =
        avatarUrl != null &&
        (avatarUrl.startsWith('http://') ||
            avatarUrl.startsWith('https://') ||
            avatarUrl.startsWith('//'));

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (isNetworkUrl) {
        // Use CachedNetworkImage for URLs from Supabase storage
        // Show letter placeholder immediately, then image when loaded (no loading indicator)
        return CachedNetworkImage(
          imageUrl: avatarUrl,
          // Always fill parent constraints (ClipOval / ClipRRect) to avoid odd sizing on mobile.
          // Use `contain` for the large popup to avoid over-cropping faces.
          fit: isLarge ? BoxFit.contain : BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheKey: 'tutor_avatar_${avatarUrl.hashCode}',
          memCacheWidth: isLarge ? 600 : 140, // Optimize memory usage
          memCacheHeight: isLarge ? 600 : 140,
          maxWidthDiskCache: isLarge ? 1200 : 280, // Cache at reasonable size
          maxHeightDiskCache: isLarge ? 1200 : 280,
          imageBuilder: (context, provider) {
            return Container(
              color: isLarge ? Colors.black : Colors.transparent,
              alignment: Alignment.center,
              child: Image(
                image: provider,
                fit: isLarge ? BoxFit.contain : BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
          placeholder: (context, url) => _buildAvatarPlaceholder(
            name,
            isLarge: isLarge,
          ), // Show letter immediately instead of loading indicator
          errorWidget: (context, url, error) {
            // Log error for debugging (but don't crash on cache errors)
            if (error.toString().contains('readonly database') ||
                error.toString().contains('DatabaseException')) {
              // Cache permission issue - try direct network load as fallback
              LogService.debug(
                'Cache database permission issue, falling back to network image',
              );
              return Image.network(
                url,
                fit: isLarge ? BoxFit.contain : BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return _buildAvatarPlaceholder(name, isLarge: isLarge);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  // Show letter placeholder while loading, then image when ready
                  if (loadingProgress == null) return child;
                  return _buildAvatarPlaceholder(name, isLarge: isLarge);
                },
              );
            }
            LogService.warning(
              'Failed to load avatar image: $url, error: $error',
            );
            return _buildAvatarPlaceholder(name, isLarge: isLarge);
          },
        );
      } else {
        // Use Image.asset for local asset paths
        return Image.asset(
          avatarUrl,
          fit: isLarge ? BoxFit.contain : BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarPlaceholder(name, isLarge: isLarge);
          },
        );
      }
    }

    // Fallback to placeholder
    return _buildAvatarPlaceholder(name, isLarge: isLarge);
  }

  Widget _buildAvatarPlaceholder(String name, {bool isLarge = false}) {
    if (isLarge) {
      // For large popup - fill container and maintain aspect ratio
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.primaryColor.withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                style: GoogleFonts.nunito(
                  fontSize: 80,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // For card avatars - ensure it fills the circular container
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'T',
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  void _showProfileImage(BuildContext context, Map<String, dynamic> tutor) {
    final name = tutor['full_name'] ?? 'Tutor';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Profile Image - maintain aspect ratio like detail screen
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: AspectRatio(
                    aspectRatio:
                        1.0, // Square aspect ratio to prevent stretching
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildAvatarImage(
                          tutor['avatar_url'] ?? tutor['profile_photo_url'],
                          name,
                          isLarge: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
