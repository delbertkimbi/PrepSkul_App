import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:prepskul/core/widgets/app_logo_header.dart';
import 'package:prepskul/features/discovery/screens/tutor_detail_screen.dart';
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
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    'Python',
    'JavaScript',
  ];

  // Monthly price ranges (in XAF per month)
  // Based on typical monthly pricing: 2-3 sessions/week × 4 weeks
  // Example: 3k/session × 2 sessions/week × 4 weeks = 24k/month



  // Get localized price ranges
  List<Map<String, dynamic>> _getPriceRanges(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      {'label': t.filterUnder20k, 'min': 0, 'max': 20000},
      {'label': t.filter20kTo30k, 'min': 20000, 'max': 30000},
      {'label': t.filter30kTo40k, 'min': 30000, 'max': 40000},
      {'label': t.filter40kTo50k, 'min': 40000, 'max': 50000},
      {'label': t.filterAbove50k, 'min': 50000, 'max': 200000},
    ];
  }


    // Get localized price ranges

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _loadUserSubjects(); // Load user's preferred subjects first
    _loadTutors();
    
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
        final system = surveyData['system']?.toString() ?? 'anglophone';
        final stream = surveyData['stream']?.toString();
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
        if (allSubjectsSet.length < 5) {
          for (var subject in _defaultSubjects) {
            allSubjectsSet.add(subject);
          }
        }

        // Convert to list and sort: user's subjects first, then alphabetically
        final List<String> sortedSubjects = [];
        
        // Add user's preferred subjects first
        for (var subject in userSubjects) {
          if (allSubjectsSet.contains(subject) && !sortedSubjects.contains(subject)) {
            sortedSubjects.add(subject);
          }
        }
        
        // Add other available subjects (alphabetically)
        final otherSubjects = allSubjectsSet
            .where((s) => !userSubjects.contains(s))
            .toList()
          ..sort();
        sortedSubjects.addAll(otherSubjects);

        if (mounted) {
          safeSetState(() {
            _userPreferredSubjects = userSubjects;
            _subjects = sortedSubjects.isNotEmpty ? sortedSubjects : _defaultSubjects;
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
      if (level.contains('lower') || level.contains('form 1') || level.contains('form 2') || 
          level.contains('form 3') || level.contains('grade 7') || level.contains('grade 8') || 
          level.contains('grade 9')) {
        return 'lower_secondary';
      }
      if (level.contains('upper') || level.contains('form 4') || level.contains('form 5') || 
          level.contains('form 6') || level.contains('grade 10') || level.contains('grade 11') || 
          level.contains('grade 12')) {
        return 'upper_secondary';
      }
      return 'upper_secondary'; // Default to upper secondary
    }
    if (level.contains('university') || level.contains('college') || level.contains('undergraduate')) {
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
      
      // If offline, try to load from cache
      if (_isOffline) {
        LogService.info('FindTutorsScreen: Offline - loading from cache...');
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
              _hasMoreTutors = false; // No more when using cache
              _cacheTimestamp = timestamp > 0 
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                  : null;
            });
          }
          LogService.success('FindTutorsScreen: Loaded ${cachedTutors.length} tutors from cache');
          return;
        } else {
          // No cache available - just show empty state
          if (mounted) {
            safeSetState(() => _isLoading = false);
          }
          return;
        }
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
                mt.tutor['id'] as String: mt.matchScore
            };
            _filteredTutors = _tutors;
            _isLoading = false;
            _currentOffset = tutorList.length;
            _hasMoreTutors = false; // Matching service returns all matches
            _cacheTimestamp = DateTime.now();
          });
          LogService.success('FindTutorsScreen: Loaded ${matchedTutors.length} matched tutors');
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
          LogService.warning('FindTutorsScreen: No matches found, using regular tutor list');
        }
      } catch (e) {
        // Fallback to regular loading on error
        LogService.warning('FindTutorsScreen: Matching error, using regular loading: $e');
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
    } catch (e, stackTrace) {
      LogService.error('FindTutorsScreen: Error loading tutors: $e');
      LogService.error('Error type: ${e.runtimeType}');
      LogService.error('Stack trace: $stackTrace');
      
      // Log specific error details for null type errors
      if (e.toString().contains('null') || e.toString().contains('Null')) {
        LogService.warning('Null type error detected - checking tutor data transformation');
        LogService.warning('This may indicate a field is null when String is expected');
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
          _tutors = _applyUserSpecificOrder(
            [..._tutors, ...newTutors],
            _userIdForSort,
          );
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
        LogService.warning('Empty userId provided to _getUserType, defaulting to student');
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
    return {
      'minRate': range['min'] as int,
      'maxRate': range['max'] as int,
    };
  }


  void _filterTutors() {
    safeSetState(() {
      _filteredTutors = _tutors.where((tutor) {
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          final name = (tutor['full_name'] ?? '').toString().toLowerCase();
          final subjects =
              (tutor['subjects'] as List?)?.join(' ').toLowerCase() ?? '';
          if (!name.contains(searchQuery) && !subjects.contains(searchQuery)) {
            return false;
          }
        }

        if (_selectedSubject != null) {
          final subjects = tutor['subjects'] as List?;
          if (subjects == null || !subjects.contains(_selectedSubject)) {
            return false;
          }
        }

        if (_selectedPriceRange != null) {
          final priceRange = _getPriceRanges(context).firstWhere(
            (range) => range['label'] == _selectedPriceRange,
          );
          // Calculate monthly price for this tutor
          final pricing = PricingService.calculateFromTutorData(tutor);
          final monthlyPrice = (pricing['perMonth'] ?? 0.0) as double;
          if (monthlyPrice < priceRange['min'] || monthlyPrice > priceRange['max']) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove back button
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const AppLogoHeader(),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune, 
              color: _isOffline ? Colors.grey[400] : Colors.black,
            ),
            onPressed: _isOffline 
                ? () => OfflineDialog.show(
                      context,
                      message: 'Filters require an internet connection. Please check your connection and try again.',
                    )
                : _showFilterBottomSheet,
            tooltip: _isOffline ? 'Filters unavailable offline' : 'Filter tutors',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Section - Responsive
          Container(
            padding: EdgeInsets.fromLTRB(
              ResponsiveHelper.responsiveHorizontalPadding(context),
              ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12),
              ResponsiveHelper.responsiveHorizontalPadding(context),
              ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20),
            ),
            child: Column(
              children: [
                // Search Bar - Responsive
                Container(
                  height: ResponsiveHelper.responsiveSpacing(context, mobile: 46, tablet: 50, desktop: 54),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    enabled: !_isOffline, // Disable search when offline
                    onChanged: (value) {
                      if (!_isOffline) {
                        safeSetState(() {});
                        _filterTutors();
                      } else {
                        // Show offline dialog if user tries to search while offline
                        OfflineDialog.show(
                          context,
                          message: 'Search requires an internet connection. Please check your connection and try again.',
                        );
                      }
                    },
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: ResponsiveHelper.responsiveBodySize(context) + 1,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name or subject',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: ResponsiveHelper.responsiveBodySize(context) + 1,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[600],
                        size: ResponsiveHelper.responsiveIconSize(context, mobile: 20, tablet: 22, desktop: 24),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.grey[600],
                                size: ResponsiveHelper.responsiveIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                safeSetState(() {});
                                _filterTutors();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.responsiveHorizontalPadding(context),
                        vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16),
                      ),
                    ),
                  ),
                ),

                // Active Filters - Responsive
                if (_selectedSubject != null ||
                    _selectedPriceRange != null ||
                    _minRating > 0)
                  Padding(
                    padding: EdgeInsets.only(top: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
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
                                  SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                                  _buildFilterChip(_selectedPriceRange!, () {
                                    safeSetState(() => _selectedPriceRange = null);
                                    _filterTutors();
                                  }),
                                ],
                                if (_minRating > 0) ...[
                                  SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
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
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: ResponsiveHelper.responsiveBodySize(context),
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
                vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 6, tablet: 8, desktop: 10),
              ),
              child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                if (_isFilterActive)
                  Text(
                    'Found ${_filteredTutors.length} tutor${_filteredTutors.length != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
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
                          message: 'Refresh requires an internet connection. Please check your connection and try again.',
                        )
                    : _loadTutors,
                    child: ResponsiveHelper.isMobile(context)
                        ? ListView.builder(
                      controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              ResponsiveHelper.responsiveHorizontalPadding(context),
                              0,
                              ResponsiveHelper.responsiveHorizontalPadding(context),
                              ResponsiveHelper.responsiveVerticalPadding(context),
                            ),
                      itemCount: _filteredTutors.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at bottom when loading more
                        if (_isLoadingMore && index == _filteredTutors.length) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
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
                              ResponsiveHelper.responsiveHorizontalPadding(context),
                              0,
                              ResponsiveHelper.responsiveHorizontalPadding(context),
                              ResponsiveHelper.responsiveVerticalPadding(context),
                            ),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: ResponsiveHelper.responsiveGridColumns(context),
                              crossAxisSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20),
                              mainAxisSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20),
                              childAspectRatio: ResponsiveHelper.isTablet(context) ? 0.75 : 0.7,
                            ),
                            itemCount: _filteredTutors.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator at bottom when loading more
                              if (_isLoadingMore && index == _filteredTutors.length) {
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

  Widget _buildRatingIndicator(int rating, String label, {StateSetter? modalSetState}) {
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
            style: GoogleFonts.poppins(
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
            style: GoogleFonts.poppins(
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
    final fullName = tutor['full_name'] ?? 'Unknown';
    // Show only first 2 names in outer card
    final nameParts = fullName.trim().split(' ');
    final displayName = nameParts.length > 2 
        ? '${nameParts[0]} ${nameParts[1]}'
        : fullName;
    
    // Use pre-calculated values from tutor_service (no duplicate calculation)
    final rating = (tutor['rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (tutor['total_reviews'] as num?)?.toInt() ?? 0;
    
    // DEBUG: Log values being used (debug mode only)
    LogService.debug('Find Tutors - Tutor: $fullName', {
      'rating': rating,
      'total_reviews': totalReviews,
    });
    final bio = tutor['bio'] ?? '';
    final completedSessions = tutor['completed_sessions'] ?? 0;
    final isVerified = tutor['is_verified'] == true;
    
    // Remove "Hello!" from bio if it starts with it (for cards)
    String displayBio = bio;
    if (displayBio.toLowerCase().startsWith('hello!')) {
      displayBio = displayBio.substring(6).trim();
      // Remove "I am" if it follows
      if (displayBio.toLowerCase().startsWith('i am')) {
        displayBio = displayBio.substring(4).trim();
      }
    }

    final cardPadding = ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16);
    final avatarSize = ResponsiveHelper.responsiveSpacing(context, mobile: 58, tablet: 68, desktop: 78);
    final cardMargin = ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14);

    return Container(
      margin: EdgeInsets.only(bottom: cardMargin),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1.2,
        ),
        // Very soft shadow just to lift from background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isOffline
                  ? () => OfflineDialog.show(
                        context,
                        message: 'Viewing tutor details requires an internet connection. Please check your connection and try again.',
                      )
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TutorDetailScreen(tutor: tutor),
                        ),
                      );
                    },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar (Larger & clickable) - Responsive
                        GestureDetector(
                          onTap: () => _showProfileImage(context, tutor),
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withOpacity(0.1), // Background for fallback
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _buildAvatarImage(
                                tutor['avatar_url'] ?? tutor['profile_photo_url'],
                                displayName,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                        // Info - Responsive
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: ResponsiveHelper.responsiveSubheadingSize(context) - 2,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 2 : 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: ResponsiveHelper.responsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18),
                                    color: Colors.amber[700],
                                  ),
                                  SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 5, desktop: 6)),
                                  Text(
                                    rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                                    style: GoogleFonts.poppins(
                                      fontSize: ResponsiveHelper.responsiveBodySize(context),
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  if (rating > 0 && totalReviews >= 3)
                                  Text(
                                    ' ($totalReviews)',
                                    style: GoogleFonts.poppins(
                                      fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                    // Subjects - Responsive
                    Wrap(
                      spacing: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 6, desktop: 8),
                      runSpacing: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 6, desktop: 8),
                      children:
                          (tutor['subjects'] as List?)
                              ?.take(3)
                              .map(
                                (subject) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12),
                                    vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 3, tablet: 4, desktop: 5),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    subject.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: ResponsiveHelper.responsiveBodySize(context) - 2,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              )
                              .toList() ??
                          [],
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                    // Bio (personal statement, with "Hello!" removed for cards) - Responsive
                    if (displayBio.isNotEmpty)
                    Text(
                        displayBio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.responsiveBodySize(context) - 3,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                    // Bottom Info Row - Focus on value, not pricing - Responsive
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Sessions completed (bold as requested) - Responsive
                        Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: ResponsiveHelper.responsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18),
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 5, desktop: 6)),
                            Text(
                              '$completedSessions',
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveHelper.responsiveBodySize(context) - 2,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w700, // Bold as requested
                              ),
                            ),
                            Text(
                              ' lessons',
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveHelper.responsiveBodySize(context) - 2,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Subtle monthly estimate (not emphasized)
                        _buildSubtleMonthlyEstimate(tutor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isVerified)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  PhosphorIcons.check(PhosphorIconsStyle.fill),
                  size: ResponsiveHelper.responsiveIconSize(context, mobile: 12, tablet: 14, desktop: 16),
                  color: Colors.white,
                ),
              ),
            ),
        ],
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
              style: GoogleFonts.poppins(
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
            final priceA = (pricingA['perMonth'] ?? 0.0) as double;
            final priceB = (pricingB['perMonth'] ?? 0.0) as double;
            return priceA.compareTo(priceB);
          default:
            return 0;
        }
      });
    });
  }

  int _stableHash(String input) {
    return input.codeUnits.fold(0, (hash, code) => (hash * 31 + code) & 0x7fffffff);
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


  Widget _buildSubtleMonthlyEstimate(Map<String, dynamic> tutor) {
    // Calculate monthly pricing but display it subtly
    final pricing = PricingService.calculateFromTutorData(tutor);
    final monthlyAmount = pricing['perMonth'] as double;
    final hasDiscount = pricing['hasDiscount'] as bool? ?? false;

    // On cards, show only discount price if available
    if (hasDiscount) {
      return Text(
        'From ${PricingService.formatPrice(monthlyAmount)}/mo',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Text(
      'From ${PricingService.formatPrice(monthlyAmount)}/mo',
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: Colors.grey[700],
        fontWeight: FontWeight.w700, // Bold as requested
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
              style: GoogleFonts.poppins(
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Can\'t find the right tutor?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Let us know what you\'re looking for and we\'ll find the perfect match for you',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Request a Tutor',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

  void _showFilterBottomSheet() {
    // #region agent log
    try {
      final logData = {
        'sessionId': 'debug-session',
        'runId': 'run1',
        'hypothesisId': 'C',
        'location': 'find_tutors_screen.dart:1304',
        'message': 'Filter bottom sheet opening',
        'data': {'isOffline': _isOffline},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      File('/Users/user/Desktop/PrepSkul/.cursor/debug.log').writeAsStringSync('${jsonEncode(logData)}\n', mode: FileMode.append);
    } catch (_) {}
    // #endregion
    
    if (_isOffline) {
      OfflineDialog.show(
        context,
        message: 'Filters require an internet connection. Please check your connection and try again.',
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _clearFilters();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear all',
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[200]),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    Text(
                      'Subject',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                        ),
                        if (_userPreferredSubjects.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(⭐ = Your preferences)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Show loading indicator if subjects haven't loaded yet
                    _subjectsLoaded
                        ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _subjects.map((subject) {
                        final isSelected = _selectedSubject == subject;
                              final isUserPreferred = _userPreferredSubjects.contains(subject);
                        return GestureDetector(
                          onTap: () {
                            safeSetState(() {
                              _selectedSubject = isSelected ? null : subject;
                            });
                            // Update modal state to reflect the change
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setModalState(() {});
                            });
                            _filterTutors(); // Apply filter when subject changes
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                        : isUserPreferred
                                            ? AppTheme.primaryColor.withOpacity(0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                          : isUserPreferred
                                              ? AppTheme.primaryColor.withOpacity(0.5)
                                    : Colors.grey[300]!,
                                      width: isUserPreferred && !isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isUserPreferred && !isSelected) ...[
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                              subject,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                          fontWeight: isUserPreferred
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                              : isUserPreferred
                                                  ? AppTheme.primaryColor
                                    : Colors.grey[700],
                              ),
                                      ),
                                    ],
                            ),
                          ),
                        );
                      }).toList(),
                          )
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context)!.filterMonthlyPriceRange,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _getPriceRanges(context).map((range) {
                        final label = range['label'] as String;
                        final isSelected = _selectedPriceRange == label;
                        return GestureDetector(
                          onTap: () {
                            safeSetState(() {
                              _selectedPriceRange = isSelected ? null : label;
                            });
                            // Update modal state to reflect the change
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setModalState(() {});
                            });
                            _filterTutors(); // Apply filter when price range changes
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context)!.filterMinimumRating,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            child: Slider(
                            value: _minRating,
                            min: 0,
                            max: 5,
                            divisions: 5,
                                label: _minRating == 0 ? AppLocalizations.of(context)!.filterAny : '${_minRating.toStringAsFixed(1)} ⭐',
                            activeColor: AppTheme.primaryColor,
                                inactiveColor: Colors.grey[300],
                            onChanged: (value) {
                              // Update parent state first
                              safeSetState(() {
                                // Round to nearest integer for proper snapping
                                _minRating = value.round().toDouble();
                              });
                              // Then update modal state to reflect the change
                              // Schedule modal state update after current frame to ensure parent state is committed
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setModalState(() {});
                              });
                              _filterTutors(); // Apply filter when rating changes
                            },
                          ),
                        ),
                          ),
                        const SizedBox(width: 12),
                        Container(
                          width: 60,
                          alignment: Alignment.center,
                          child: Text(
                                _minRating == 0 ? AppLocalizations.of(context)!.filterAny : '${_minRating.toStringAsFixed(1)}+',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                        const SizedBox(height: 8),
                        // Rating value indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRatingIndicator(0, AppLocalizations.of(context)!.filterAny, modalSetState: setModalState),
                            _buildRatingIndicator(1, '1', modalSetState: setModalState),
                            _buildRatingIndicator(2, '2', modalSetState: setModalState),
                            _buildRatingIndicator(3, '3', modalSetState: setModalState),
                            _buildRatingIndicator(4, '4', modalSetState: setModalState),
                            _buildRatingIndicator(5, '5', modalSetState: setModalState),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: () {
                    _filterTutors();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
        },
      ),
    );
  }

  Widget _buildAvatarImage(String? avatarUrl, String name, {bool isLarge = false}) {
    // Check if avatarUrl is a network URL or asset path
    final isNetworkUrl = avatarUrl != null &&
        (avatarUrl.startsWith('http://') ||
            avatarUrl.startsWith('https://') ||
            avatarUrl.startsWith('//'));
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (isNetworkUrl) {
        // Use CachedNetworkImage for URLs from Supabase storage
        // Show letter placeholder immediately, then image when loaded (no loading indicator)
        return CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          width: isLarge ? double.infinity : null, // Fill width when large
          height: isLarge ? double.infinity : null, // Fill height when large
          cacheKey: 'tutor_avatar_${avatarUrl.hashCode}',
          memCacheWidth: isLarge ? 600 : 140, // Optimize memory usage
          memCacheHeight: isLarge ? 600 : 140,
          maxWidthDiskCache: isLarge ? 1200 : 280, // Cache at reasonable size
          maxHeightDiskCache: isLarge ? 1200 : 280,
          placeholder: (context, url) => _buildAvatarPlaceholder(name, isLarge: isLarge), // Show letter immediately instead of loading indicator
          errorWidget: (context, url, error) {
            // Log error for debugging (but don't crash on cache errors)
            if (error.toString().contains('readonly database') || 
                error.toString().contains('DatabaseException')) {
              // Cache permission issue - try direct network load as fallback
              LogService.debug('Cache database permission issue, falling back to network image');
              return Image.network(
                url,
                fit: BoxFit.cover,
                width: isLarge ? double.infinity : null, // Fill width when large
                height: isLarge ? double.infinity : null, // Fill height when large
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
            LogService.warning('Failed to load avatar image: $url, error: $error');
            return _buildAvatarPlaceholder(name, isLarge: isLarge);
          },
        );
      } else {
        // Use Image.asset for local asset paths
        return Image.asset(
          avatarUrl,
          fit: BoxFit.cover,
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
                style: GoogleFonts.poppins(
                  fontSize: 80,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: GoogleFonts.poppins(
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
          style: GoogleFonts.poppins(
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
                    aspectRatio: 1.0, // Square aspect ratio to prevent stretching
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