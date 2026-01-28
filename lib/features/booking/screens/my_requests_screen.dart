import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/booking/models/tutor_request_model.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/screens/request_tutor_flow_screen.dart';
import 'package:prepskul/features/booking/screens/request_detail_screen.dart';
import 'package:prepskul/features/booking/widgets/post_trial_dialog.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart' hide LogService;
import 'package:prepskul/features/booking/screens/post_trial_conversion_screen.dart';
import 'package:prepskul/features/booking/screens/trial_payment_screen.dart';
import 'package:prepskul/features/booking/screens/book_trial_session_screen.dart';
import 'package:prepskul/features/payment/screens/booking_payment_screen.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/services/tutor_request_service.dart';
import 'package:prepskul/features/booking/services/recurring_session_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import 'package:prepskul/core/services/offline_cache_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/app_localizations.dart';
import '../utils/session_date_utils.dart';

class MyRequestsScreen extends StatefulWidget {
  final String? highlightRequestId; // Request ID to highlight when screen loads
  
  const MyRequestsScreen({Key? key, this.highlightRequestId}) : super(key: key);

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<BookingRequest> _bookingRequests = [];
  List<TutorRequest> _customRequests = [];
  List<TrialSession> _trialSessions = [];
  String _selectedFilter = 'all'; // all, pending, custom, trial, booking
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isOffline = false;
  DateTime? _cacheTimestamp;
  final ConnectivityService _connectivity = ConnectivityService();

  final ScrollController _scrollController = ScrollController();
  String? _highlightRequestId;
  bool _isNavigating = false; // Flag to prevent refresh during navigation
  String? _cachedUserType; // Cache user type to avoid repeated fetches

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _highlightRequestId = widget.highlightRequestId;
    _initializeConnectivity();
    _loadUserType(); // Load user type early
    _loadRequests();
  }

  @override
  void didUpdateWidget(MyRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh if highlightRequestId changed (e.g., navigated here with a new request to highlight)
    if (oldWidget.highlightRequestId != widget.highlightRequestId) {
      _highlightRequestId = widget.highlightRequestId;
      _loadRequests();
    }
  }

  bool _hasLoadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when screen becomes visible (e.g., after creating a booking request or receiving approval notification)
    // Only refresh if we've already loaded once (to avoid double-loading on first build)
    // This ensures new requests and status updates are immediately visible when returning to the screen
    // Skip refresh if we're navigating away (to prevent refresh when View Session is clicked)
    if (_hasLoadedOnce && 
        ModalRoute.of(context)?.isCurrent == true && 
        !_isNavigating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && 
            ModalRoute.of(context)?.isCurrent == true && 
            !_isNavigating) {
          _loadRequests();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _connectivity.dispose();
    super.dispose();
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
        
        
        // If came back online, reload requests
        if (isOnline && wasOffline) {
          LogService.info('🌐 Connection restored - reloading requests');
          _loadRequests();
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
        LogService.info('🌐 Connection detected - reloading requests');
        _loadRequests();
      }
    }
  }

  /// Clean trial goal text by removing internal reschedule request notes
  String _cleanTrialGoal(String goal) {
    // Remove reschedule request notes that were accidentally added to trial goals
    // Pattern: [RESCHEDULE REQUEST: ...]
    final reschedulePattern = RegExp(r'\n?\n?\[RESCHEDULE REQUEST:.*?\]', dotAll: true);
    return goal.replaceAll(reschedulePattern, '').trim();
  }

  /// Get current user type (student, parent, tutor)
  /// Uses cached value if available, otherwise defaults to 'student'
  String _getUserType() {
    if (_cachedUserType != null) return _cachedUserType!;
    
    // Try to fetch from profile (async, but we return cached/default for now)
    _loadUserType();
    return 'student'; // Default to student until loaded
  }

  /// Load user type from profile and cache it
  Future<void> _loadUserType() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        _cachedUserType = 'student';
        return;
      }
      
      final profile = await SupabaseService.client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();
      
      if (profile != null && mounted) {
        _cachedUserType = profile['user_type']?.toString() ?? 'student';
      } else {
        _cachedUserType = 'student';
      }
    } catch (e) {
      LogService.warning('Error loading user type: $e');
      _cachedUserType = 'student';
    }
  }

  // Cache tutor info for trial sessions
  final Map<String, Map<String, dynamic>> _tutorInfoCache = {};

  Future<void> _loadRequests() async {
    if (mounted) {
      safeSetState(() {
        _isLoading = true;
      });
    }

    try {
      // Check connectivity first
      final isOnline = await _connectivity.checkConnectivity();
      safeSetState(() => _isOffline = !isOnline);
      
      final userId = SupabaseService.currentUser?.id;
      
      // If offline, try to load from cache
      if (_isOffline && userId != null) {
        LogService.info('MyRequestsScreen: Offline - loading from cache...');
        
        // Try to load cached booking requests
        final cachedRequests = await OfflineCacheService.getCachedBookingRequests(userId);
        if (cachedRequests != null && cachedRequests.isNotEmpty) {
          try {
            final bookingRequests = <BookingRequest>[];
            for (var r in cachedRequests) {
              try {
                bookingRequests.add(BookingRequest.fromJson(r));
              } catch (e) {
                LogService.warning('Error parsing cached booking request: $e');
              }
            }
            
            final timestamp = await SharedPreferences.getInstance().then(
              (prefs) => prefs.getInt('cached_booking_requests_${userId}_cache_timestamp') ?? 0,
            );
            
            if (mounted) {
              safeSetState(() {
                _bookingRequests = bookingRequests;
                _cacheTimestamp = timestamp > 0 
                    ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                    : null;
              });
            }
            LogService.success('MyRequestsScreen: Loaded ${bookingRequests.length} booking requests from cache');
          } catch (e) {
            LogService.warning('Error parsing cached booking requests: $e');
          }
        }
        
        // Try to load cached trial sessions
        final cachedTrials = await OfflineCacheService.getCachedTrialSessions(userId);
        if (cachedTrials != null && cachedTrials.isNotEmpty) {
          try {
            final trials = <TrialSession>[];
            for (var t in cachedTrials) {
              try {
                trials.add(TrialSession.fromJson(t));
              } catch (e) {
                LogService.warning('Error parsing cached trial session: $e');
              }
            }
            
            await _loadTutorInfoForTrials(trials);
            
            if (mounted) {
              safeSetState(() {
                _trialSessions = trials;
                _isLoading = false;
              });
            }
            LogService.success('MyRequestsScreen: Loaded ${trials.length} trial sessions from cache');
          } catch (e) {
            LogService.warning('Error parsing cached trial sessions: $e');
          }
        }
        
        if (mounted) {
          safeSetState(() => _isLoading = false);
        }
        return;
      }
      
      // Online - fetch fresh data
      // Load booking requests
      List<BookingRequest> bookingRequests = [];
      if (userId != null) {
        try {
          LogService.info('🔄 Loading booking requests for user: $userId');
          bookingRequests = await BookingService.getStudentBookingRequests(userId);
          LogService.success('✅ Loaded ${bookingRequests.length} booking requests');
          
          // Log each request for debugging
          for (var request in bookingRequests) {
            LogService.info('📋 Request: id=${request.id}, status=${request.status}, tutor=${request.tutorName}');
          }
          
          // Cache booking requests
          if (bookingRequests.isNotEmpty) {
            final requestsJson = bookingRequests.map((r) => r.toJson()).toList();
            await OfflineCacheService.cacheBookingRequests(userId, requestsJson);
            LogService.info('💾 Cached ${bookingRequests.length} booking requests');
          }
        } catch (e, stackTrace) {
          LogService.error('❌ Error loading booking requests: $e');
          LogService.error('📚 Stack trace: $stackTrace');
          LogService.error('👤 User ID: $userId');
        }
      } else {
        LogService.warning('⚠️ Cannot load booking requests: userId is null');
      }

      // Load tutor custom requests
      List<TutorRequest> customRequests = [];
      try {
        customRequests = await TutorRequestService.getUserRequests();
        LogService.success('Loaded ${customRequests.length} custom requests');
      } catch (e) {
        LogService.error('Error loading custom requests: $e');
      }

      // Load trial sessions
      final trials = await TrialSessionService.getStudentTrialSessions();
      LogService.success('Loaded ${trials.length} trial sessions');
      
      // Cache trial sessions
      if (trials.isNotEmpty && userId != null) {
        final trialsJson = trials.map((t) => t.toJson()).toList();
        await OfflineCacheService.cacheTrialSessions(userId, trialsJson);
      }
      
      // Debug: Log payment statuses
      for (var trial in trials) {
        LogService.debug('Trial ${trial.id}: status=${trial.status}, paymentStatus=${trial.paymentStatus}');
      }

      // Load tutor info for all trials
      await _loadTutorInfoForTrials(trials);

      if (!mounted) return;

      safeSetState(() {
        _trialSessions = trials;
        _bookingRequests = bookingRequests;
        _customRequests = customRequests;
        _isLoading = false;
        _cacheTimestamp = DateTime.now();
        _hasLoadedOnce = true; // Mark that we've loaded at least once
      });
      
      // Debug logging
      LogService.info('📊 MyRequestsScreen state updated:');
      LogService.info('   - Booking requests: ${bookingRequests.length}');
      LogService.info('   - Custom requests: ${customRequests.length}');
      LogService.info('   - Trial sessions: ${trials.length}');
      if (bookingRequests.isNotEmpty) {
        LogService.info('   - Booking request IDs: ${bookingRequests.map((r) => r.id).join(", ")}');
        LogService.info('   - Booking request statuses: ${bookingRequests.map((r) => r.status).join(", ")}');
      } else {
        LogService.warning('⚠️ No booking requests found for user: $userId');
      }

      // Check for completed trials that haven't been converted
      // Show dialog for the first one found
      if (mounted) {
        _checkForCompletedTrials();
      }
    } catch (e) {
      LogService.error('Error loading requests: $e');
      if (!mounted) return;

      safeSetState(() {
        _isLoading = false;
      });
    }
  }

  /// Force refresh a specific trial session after payment
  Future<void> _refreshTrialSession(String sessionId) async {
    try {
      LogService.info('Starting refresh for trial session: $sessionId');
      
      // Directly fetch the trial session from DB to get latest payment_status
      final response = await SupabaseService.client
          .from('trial_sessions')
          .select('*, payment_status, fapshi_trans_id, status')
          .eq('id', sessionId)
          .maybeSingle();
      
      if (response == null) {
        throw Exception('Trial session not found: $sessionId');
      }
      
      if (response != null) {
        // Log raw DB values for debugging
        final rawPaymentStatus = response['payment_status']?.toString() ?? 'null';
        final rawStatus = response['status']?.toString() ?? 'null';
        LogService.debug('DB raw values - payment_status: $rawPaymentStatus, status: $rawStatus');
        
        final updatedTrial = TrialSession.fromJson(response);
        LogService.info('Refreshed trial $sessionId', 'paymentStatus=${updatedTrial.paymentStatus}, status=${updatedTrial.status}');
        
        // Update in the list
        final index = _trialSessions.indexWhere((t) => t.id == sessionId);
        if (index != -1 && mounted) {
          final oldPaymentStatus = _trialSessions[index].paymentStatus;
          safeSetState(() {
            _trialSessions[index] = updatedTrial;
          });
          LogService.success('Updated trial in UI: $oldPaymentStatus → ${updatedTrial.paymentStatus}');
        } else if (index == -1) {
          LogService.warning('Trial session not found in list, reloading all requests...');
          if (mounted) await _loadRequests();
        }
      } else {
        LogService.warning('No response from DB for trial session: $sessionId');
        if (mounted) await _loadRequests();
      }
    } catch (e, stackTrace) {
      LogService.error('Error refreshing trial session: $e');
      LogService.error('Stack trace: $stackTrace');
      // Fallback: reload all requests
      if (mounted) await _loadRequests();
    }
  }

  /// Check for completed trials and show dialog
  Future<void> _checkForCompletedTrials() async {
    // Find completed trials that haven't been converted
    final completedTrials = _trialSessions
        .where(
          (trial) => trial.status == 'completed' && !trial.convertedToRecurring,
        )
        .toList();

    if (completedTrials.isEmpty) return;

    // Show dialog for the first completed trial
    final trial = completedTrials.first;

    // Fetch tutor data
    try {
      final supabase = Supabase.instance.client;
      final tutorData = await supabase
          .from('tutor_profiles')
          .select(
            '*, profiles!tutor_profiles_user_id_fkey(full_name, avatar_url)',
          )
          .eq('user_id', trial.tutorId)
          .maybeSingle();
      
      if (tutorData == null) {
        throw Exception('Tutor profile not found: ${trial.tutorId}');
      }

      // Wait a bit for the screen to be fully built
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Show dialog
      await PostTrialDialog.show(
        context,
        trialSession: trial,
        tutor: {
          ...tutorData,
          'user_id': trial.tutorId,
          'id': trial.tutorId,
          'full_name': tutorData['profiles']?['full_name'] ?? 'Tutor',
        },
        onDismiss: () {
          // Mark as dismissed (could store in local storage)
          // For now, just remove from list temporarily
        },
      );
    } catch (e) {
      LogService.error('Error fetching tutor data: $e');
    }
  }

  /// Load tutor information for trial sessions
  Future<void> _loadTutorInfoForTrials(List<TrialSession> trials) async {
    try {
      final supabase = Supabase.instance.client;
      final tutorIds = trials.map((t) => t.tutorId).toSet().toList();

      if (tutorIds.isEmpty) return;

      // Fetch tutor profiles with profile data
      // Try using the relationship join first
      try {
        final tutorProfiles = await supabase
            .from('tutor_profiles')
            .select(
              'user_id, rating, admin_approved_rating, total_reviews, profile_photo_url, profiles!tutor_profiles_user_id_fkey(full_name, avatar_url)',
            )
            .inFilter('user_id', tutorIds);

        LogService.debug('Loaded ${tutorProfiles.length} tutor profiles for trials');

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

          // Calculate effective rating (same logic as tutor_service.dart)
          final totalReviews = (tutor['total_reviews'] ?? 0) as int;
          final adminApprovedRating = tutor['admin_approved_rating'] as double?;
          final calculatedRating = (tutor['rating'] ?? 0.0) as double;

          // Use admin rating until we have at least 3 real reviews
          final effectiveRating =
              (totalReviews < 3 && adminApprovedRating != null)
              ? adminApprovedRating
              : (calculatedRating > 0
                    ? calculatedRating
                    : (adminApprovedRating ?? 0.0));

          _tutorInfoCache[userId] = {
            'full_name': profile?['full_name'] ?? 'Tutor',
            'avatar_url': effectiveAvatarUrl,
            'rating': effectiveRating,
          };
        }
      } catch (e) {
        LogService.warning('Error loading tutor info with relationship join: $e');
        // Fallback: fetch profiles separately
        for (final tutorId in tutorIds) {
          try {
            // Fetch tutor profile
            final tutorProfile = await supabase
                .from('tutor_profiles')
                .select(
                  'user_id, rating, admin_approved_rating, total_reviews, profile_photo_url',
                )
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

            final totalReviews = (tutorProfile['total_reviews'] ?? 0) as int;
            final adminApprovedRating =
                tutorProfile['admin_approved_rating'] as double?;
            final calculatedRating = (tutorProfile['rating'] ?? 0.0) as double;

            final effectiveRating =
                (totalReviews < 3 && adminApprovedRating != null)
                ? adminApprovedRating
                : (calculatedRating > 0
                      ? calculatedRating
                      : (adminApprovedRating ?? 0.0));

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
              'rating': effectiveRating,
            };

            LogService.success('Cached tutor info (fallback) for $tutorId', _tutorInfoCache[tutorId]?['full_name']);
          } catch (e2) {
            LogService.warning('Error loading tutor info for $tutorId: $e2');
          }
        }
      }

      // Trigger rebuild to show loaded tutor info
      if (mounted) {
        safeSetState(() {});
      }
    } catch (e) {
      LogService.warning('Error loading tutor info for trials: $e');
      // Silently fail - tutor info will show defaults
    }
  }

  List<BookingRequest> _getPendingBookingRequests() {
    return _bookingRequests.where((req) => req.isPending).toList();
  }

  List<TutorRequest> _getPendingCustomRequests() {
    return _customRequests.where((req) => req.isPending).toList();
  }

  List<TrialSession> _getPendingTrialSessions() {
    if (_trialSessions.isEmpty) return [];
    return _trialSessions.where((req) => req.isPending).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final pendingBookingCount = _getPendingBookingRequests().length;
    final pendingCustomCount = _getPendingCustomRequests().length;
    final pendingTrialCount = _getPendingTrialSessions().length;
    final totalPending =
        pendingBookingCount + pendingCustomCount + pendingTrialCount;

    // FAB shows in Custom Request tab only if:
    // 1. Selected filter is 'custom'
    // 2. At least one custom request exists
    // 3. User is not a student (students have button on card already)
    final showFAB = _selectedFilter == 'custom' && 
                    _customRequests.isNotEmpty &&
                    _getUserType() != 'student';

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button in bottom nav
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          t.myRequestsTitle,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildFilterChip(context, 'all', t.myRequestsFilterAll),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, 'pending', t.myRequestsFilterPending),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, 'custom', t.myRequestsFilterCustom),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, 'trial', t.myRequestsFilterTrial),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, 'booking', t.myRequestsFilterBooking),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ShimmerLoading.requestList(count: 5),
            )
          : _buildSelectedTabContent(context, _selectedFilter),
      floatingActionButton: showFAB
          ? FloatingActionButton.extended(
              onPressed: _isOffline
                  ? () => OfflineDialog.show(
                        context,
                        message: 'Creating a request requires an internet connection. Please check your connection and try again.',
                      )
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RequestTutorFlowScreen(),
                  ),
                ).then((_) => _loadRequests()); // Refresh after returning
              },
              backgroundColor: _isOffline 
                  ? Colors.grey[400] 
                  : AppTheme.primaryColor,
              icon: Icon(
                Icons.add, 
                color: Colors.white,
              ),
              label: Text(
                'Request Another Tutor',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAllRequestsTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // Filter out only cancelled unpaid sessions (keep cancelled paid sessions)
    final activeTrialSessions = _trialSessions.where((session) {
      // Exclude deleted sessions
      if (session.status == 'deleted') {
        return false;
      }
      // Exclude cancelled sessions ONLY if they are unpaid
      if (session.status == 'cancelled') {
        final paymentStatus = session.paymentStatus.toLowerCase();
        // Only exclude if unpaid - keep cancelled paid sessions
        if (paymentStatus != 'paid' && paymentStatus != 'completed') {
          return false;
        }
      }
      // Also exclude rejected sessions that were deleted
      if (session.status == 'rejected' && 
          (session.rejectionReason?.toLowerCase().contains('deleted') == true ||
           session.rejectionReason?.toLowerCase().contains('cancelled by user') == true)) {
        return false;
      }
      return true;
    }).toList();
    
    final allRequests = [
      ..._bookingRequests.map((r) => _RequestItem(type: 'booking', booking: r)),
      ..._customRequests.map((r) => _RequestItem(type: 'custom', custom: r)),
      ...activeTrialSessions.map((r) => _RequestItem(type: 'trial', trial: r)),
    ];

    // Filter by search query
    final filteredRequests = _searchQuery.isEmpty
        ? allRequests
        : allRequests.where((item) {
            final query = _searchQuery.toLowerCase();
            if (item.type == 'booking') {
              final booking = item.booking!;
              return booking.tutorName.toLowerCase().contains(query) ||
                     (booking.subject?.toLowerCase().contains(query) ?? false);
            } else if (item.type == 'custom') {
              final custom = item.custom!;
              return custom.formattedSubjects.toLowerCase().contains(query);
            } else {
              final trial = item.trial!;
              final tutorName = _tutorInfoCache[trial.tutorId]?['full_name']?.toString().toLowerCase() ?? '';
              return tutorName.contains(query) ||
                     trial.subject.toLowerCase().contains(query);
            }
          }).toList();

    return Column(
      children: [
        // Search bar (disabled for "all" section)
        if (_selectedFilter != 'all')
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  enabled: !_isOffline, // Disable search when offline
                decoration: InputDecoration(
                  hintText: _isOffline 
                      ? 'Search unavailable offline' 
                      : 'Search by tutor name or subject...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: _isOffline 
                      ? Colors.grey[200] 
                      : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                  onChanged: _isOffline 
                    ? null 
                    : (value) {
                        setState(() => _searchQuery = value);
                      },
                ),
              ],
            ),
          ),
        // Results count
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filteredRequests.length} result${filteredRequests.length != 1 ? 's' : ''} found',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        // List
        Expanded(
          child: filteredRequests.isEmpty
              ? _searchQuery.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No results found',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildRequestTutorCard(context, 
        title: t.myRequestsEmptyTitle,
        subtitle:
            'Tell us what you\'re looking for and we\'ll find the perfect match for you',
        showButton: true,
                    )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: filteredRequests.length,
      itemBuilder: (ctx, index) {
                    final item = filteredRequests[index];
        final isHighlighted = _highlightRequestId != null && 
            ((item.type == 'booking' && item.booking?.id == _highlightRequestId) ||
             (item.type == 'trial' && item.trial?.id == _highlightRequestId) ||
             (item.type == 'custom' && item.custom?.id == _highlightRequestId));
        
        if (item.type == 'booking') {
          return _buildBookingRequestCard(context, item.booking!, isHighlighted: isHighlighted);
        } else if (item.type == 'custom') {
          return _buildCustomRequestCard(context, item.custom!, isHighlighted: isHighlighted);
        } else {
          return _buildTrialSessionCard(context, item.trial!, isHighlighted: isHighlighted);
        }
      },
                ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestsTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final pendingBookings = _getPendingBookingRequests();
    final pendingCustom = _getPendingCustomRequests();
    final pendingTrials = _getPendingTrialSessions();
    final allPending = [
      ...pendingBookings.map((r) => _RequestItem(type: 'booking', booking: r)),
      ...pendingCustom.map((r) => _RequestItem(type: 'custom', custom: r)),
      ...pendingTrials.map((r) => _RequestItem(type: 'trial', trial: r)),
    ];

    if (allPending.isEmpty) {
      return _buildEmptyState(context, 
        icon: Icons.pending_outlined,
        title: t.myRequestsNoPendingTitle,
        subtitle: t.myRequestsNoPendingSubtitle,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: allPending.length,
      itemBuilder: (ctx, index) {
        final item = allPending[index];
        final isHighlighted = _highlightRequestId != null && 
            ((item.type == 'booking' && item.booking?.id == _highlightRequestId) ||
             (item.type == 'trial' && item.trial?.id == _highlightRequestId) ||
             (item.type == 'custom' && item.custom?.id == _highlightRequestId));
        if (item.type == 'booking') {
          return _buildBookingRequestCard(context, item.booking!, isHighlighted: isHighlighted);
        } else if (item.type == 'custom') {
          return _buildCustomRequestCard(context, item.custom!, isHighlighted: isHighlighted);
        } else {
          return _buildTrialSessionCard(context, item.trial!, isHighlighted: isHighlighted);
        }
      },
    );
  }

  Widget _buildCustomRequestsTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (_customRequests.isEmpty) {
      return _buildRequestTutorCard(context, 
        title: t.myRequestsEmptyTitle,
        subtitle:
            'Tell us what you\'re looking for and we\'ll find the perfect match for you',
        showButton: true,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _customRequests.length,
      itemBuilder: (ctx, index) {
        final isHighlighted = _highlightRequestId != null && _customRequests[index].id == _highlightRequestId;
        return _buildCustomRequestCard(context, _customRequests[index], isHighlighted: isHighlighted);
      },
    );
  }

  Widget _buildTrialSessionsTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (_trialSessions.isEmpty) {
      return _buildEmptyState(context, 
        icon: Icons.quiz_outlined,
        title: t.myRequestsNoTrialsTitle,
        subtitle:
            'Request a trial session from a tutor\'s profile to get started',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _trialSessions.length,
      itemBuilder: (ctx, index) {
        final isHighlighted = _highlightRequestId != null && _trialSessions[index].id == _highlightRequestId;
        return _buildTrialSessionCard(context, _trialSessions[index], isHighlighted: isHighlighted);
      },
    );
  }

  Widget _buildBookingsTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (_bookingRequests.isEmpty) {
      return _buildEmptyState(context, 
        icon: Icons.book_outlined,
        title: t.myRequestsNoBookingsTitle,
        subtitle: t.myRequestsNoBookingsSubtitle,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _bookingRequests.length,
      itemBuilder: (ctx, index) {
        final isHighlighted = _highlightRequestId != null && _bookingRequests[index].id == _highlightRequestId;
        return _buildBookingRequestCard(context, _bookingRequests[index], isHighlighted: isHighlighted);
      },
    );
  }

  Widget _buildRequestTutorCard(BuildContext context, {
    required String title,
    required String subtitle,
    required bool showButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_search,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (showButton) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RequestTutorFlowScreen(),
                        ),
                      ).then((result) {
                        // Refresh if request was submitted successfully
                        if (result == true) {
                          _loadRequests();
                          // Switch to custom requests tab to show the new request
                          _tabController.animateTo(2);
                        }
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      'Request a Tutor',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToHighlightedRequest() {
    if (_highlightRequestId == null) return;
    
    // Find the index of the highlighted request
    final allRequests = [
      ..._bookingRequests.map((r) => _RequestItem(type: 'booking', booking: r)),
      ..._customRequests.map((r) => _RequestItem(type: 'custom', custom: r)),
      ..._trialSessions.map((r) => _RequestItem(type: 'trial', trial: r)),
    ];
    
    final index = allRequests.indexWhere((item) {
      if (item.type == 'booking' && item.booking?.id == _highlightRequestId) return true;
      if (item.type == 'trial' && item.trial?.id == _highlightRequestId) return true;
      if (item.type == 'custom' && item.custom?.id == _highlightRequestId) return true;
      return false;
    });
    
    if (index >= 0 && _scrollController.hasClients) {
      // Scroll to the item (approximate position: 200 pixels per item)
      final targetOffset = (index * 200.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      
      // Clear highlight after scrolling
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _highlightRequestId = null;
          });
        }
      });
    }
  }

  /// Get payment request status for a booking request
  Future<Map<String, dynamic>?> _getPaymentRequestStatus(String bookingRequestId) async {
    try {
      final response = await PaymentRequestService.getPaymentRequestByBookingRequestId(bookingRequestId);
      return response;
    } catch (e) {
      LogService.error('Error fetching payment request status: $e');
      return null;
    }
  }

  Widget _buildBookingRequestCard(BuildContext context, BookingRequest request, {bool isHighlighted = false}) {
    final t = AppLocalizations.of(context)!;
    
    // Determine status for display
    String displayStatus = request.status;
    if (request.status == 'approved' && 
        (request.paymentStatus == null || 
         request.paymentStatus == 'pending' || 
         request.paymentStatus == 'unpaid')) {
      displayStatus = 'awaiting_payment';
    } else if (request.paymentStatus == 'paid') {
      displayStatus = 'paid';
    }
    
    // Card is always clickable to show details
    return _buildNeomorphicCard(
      margin: const EdgeInsets.only(bottom: 14),
      border: isHighlighted ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RequestDetailScreen(request: request.toJson()),
            ),
          ).then((_) {
            _loadRequests();
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: _buildBookingCardContent(context, request, displayStatus),
      ),
    );
  }

  Widget _buildBookingCardContent(BuildContext context, BookingRequest request, String displayStatus) {
    final t = AppLocalizations.of(context)!;
    final subject = request.subject ?? 'Regular Session';
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: displayStatus == 'paid' || displayStatus == 'scheduled'
            ? LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.03),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern header: Tutor info with integrated status
            Row(
              children: [
                // Avatar with status indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      backgroundImage: request.tutorAvatarUrl != null && request.tutorAvatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(request.tutorAvatarUrl!)
                          : null,
                      child: request.tutorAvatarUrl == null || request.tutorAvatarUrl!.isEmpty
                          ? Text(
                                    request.tutorName.isNotEmpty
                                        ? request.tutorName[0].toUpperCase()
                                        : 'T',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                              ),
                            )
                          : null,
                    ),
                    // Status indicator dot
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(displayStatus),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                // Tutor name and rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.tutorName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status badge (compact, modern)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(displayStatus).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getStatusColor(displayStatus).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getStatusLabel(displayStatus),
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(displayStatus),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.amber[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.tutorRating > 0
                                ? request.tutorRating.toStringAsFixed(1)
                                : 'New',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subject,
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            
            // Session details - flat horizontal layout (no elevation)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernInfoItem(
                      Icons.calendar_today_outlined,
                      request.getDaysSummary(),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Expanded(
                    child: _buildModernInfoItem(
                      Icons.access_time_outlined,
                      request.getTimeRange(),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Expanded(
                    child: _buildModernInfoItem(
                      request.location == 'online' 
                          ? Icons.video_call_outlined 
                          : Icons.location_on_outlined,
                      request.location == 'online' ? 'Online' : (request.address ?? 'On-site'),
                    ),
                  ),
                ],
              ),
            ),

            // Price and Action button in a row
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Price section (left side, 40% of row)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Fee',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.monthlyTotal.toStringAsFixed(0)} XAF',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Action button (right side, 60% of row)
                Expanded(
                  flex: 3,
                  child: Builder(
                    builder: (context) {
                      // Show Pay Now for approved, unpaid sessions
                      if (request.status == 'approved' && 
                          request.paymentRequestId != null && 
                          request.paymentStatus != 'paid') {
                        return ElevatedButton(
                          onPressed: () async {
                            LogService.info('💰 Pay Now button clicked for booking: ${request.id}');
                            // Navigate directly to payment screen
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingPaymentScreen(
                                  paymentRequestId: request.paymentRequestId!,
                                  bookingRequestId: request.id,
                                ),
                              ),
                            );

                            if (result == true && mounted) {
                              await Future.delayed(const Duration(milliseconds: 2000));
                              if (!mounted) return;
                              await _loadRequests();
                              if (mounted) {
                                safeSetState(() {});
                                // Navigate to sessions tab to show the newly created sessions
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/student-nav',
                                  (route) => route.isFirst,
                                  arguments: {'initialTab': 2}, // Sessions tab
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            t.myRequestsPayNow,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }
                      
                      // Show View Details for pending sessions
                      if (request.status == 'pending') {
                        return OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RequestDetailScreen(
                                  request: request.toJson(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: Text(
                            'View Details',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                      
                      // Show View Session for paid sessions - navigate to sessions screen
                      if (request.paymentStatus == 'paid') {
                        return ElevatedButton.icon(
                          onPressed: () async {
                            LogService.info('🔵 [VIEW_SESSION] Button clicked for booking request: ${request.id}');
                            LogService.info('🔵 [VIEW_SESSION] Request details: status=${request.status}, paymentStatus=${request.paymentStatus}');
                            LogService.info('🔵 [VIEW_SESSION] Widget mounted: ${mounted}');
                            LogService.info('🔵 [VIEW_SESSION] Context valid: ${context.mounted}');
                            
                            try {
                              // Check if sessions exist before navigating
                              LogService.info('🔵 [VIEW_SESSION] Calling _checkAndNavigateToSessions...');
                              await _checkAndNavigateToSessions(context, bookingRequestId: request.id, isTrial: false);
                              LogService.info('🔵 [VIEW_SESSION] _checkAndNavigateToSessions completed');
                            } catch (e, stackTrace) {
                              LogService.error('🔴 [VIEW_SESSION] ERROR in button onPressed: $e');
                              LogService.error('🔴 [VIEW_SESSION] Stack trace: $stackTrace');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Navigation error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            'View Session',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        );
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomRequestCard(BuildContext context, TutorRequest request, {bool isHighlighted = false}) {
    final t = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(request.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted 
            ? Border.all(color: AppTheme.primaryColor, width: 2) 
            : null,
        boxShadow: [
          // Reduced elevation - lighter shadows
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            offset: const Offset(-1, -1),
            blurRadius: 2,
            spreadRadius: 0,
          ),
          // Dark shadow (bottom-right) - reduced
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(1, 1),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RequestDetailScreen(
                tutorRequest: request,
              ),
            ),
          ).then((_) {
            // Refresh after returning from detail page
            _loadRequests();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with PrepSkul logo and badges
              Row(
                children: [
                  // PrepSkul logo with status dot
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/app_logo(blue).png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.school,
                              size: 32,
                              color: AppTheme.primaryColor,
                            );
                          },
                        ),
                      ),
                      // Status indicator dot
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                    decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Custom Request text (plain black, no badge)
                  Text(
                      t.myRequestsFilterCustom,
                      style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const Spacer(),
                  // Status badge - smaller for custom requests
                  _buildStatusChip(context, request.status, isCompact: true),
                ],
              ),
              const SizedBox(height: 16),
              // Subject title - reduced size
              Text(
                request.formattedSubjects,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              // Info rows in 2 columns
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              _buildInfoRow(Icons.school, request.educationLevel),
                        const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, request.formattedDays),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              _buildInfoRow(Icons.location_on, request.location),
                        const SizedBox(height: 8),
              _buildInfoRow(Icons.attach_money, request.formattedBudget),
                      ],
                    ),
                  ),
                ],
              ),
              // Urgency indicator if applicable
              if (request.urgency != 'normal') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: request.urgency == 'urgent'
                        ? Colors.red[50]
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: request.urgency == 'urgent'
                          ? Colors.red[200]!
                          : Colors.blue[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      request.urgency == 'urgent'
                          ? Icons.priority_high
                          : Icons.schedule,
                        size: 14,
                      color: request.urgency == 'urgent'
                            ? Colors.red[700]
                            : Colors.blue[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request.urgencyLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                        color: request.urgency == 'urgent'
                              ? Colors.red[700]
                              : Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                ),
              ],
              // View Details button
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RequestDetailScreen(
                        tutorRequest: request,
                      ),
                    ),
                  ).then((_) {
                    _loadRequests();
                  });
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: AppTheme.primaryColor, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View Details',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
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
  }

  Widget _buildTrialSessionCard(BuildContext context, TrialSession session, {bool isHighlighted = false}) {
    // Get tutor info from cache
    final tutorInfo = _tutorInfoCache[session.tutorId] ?? {};
    final t = AppLocalizations.of(context)!;
    final tutorName = tutorInfo['full_name'] ?? 'Tutor';
    final tutorAvatarUrl = tutorInfo['avatar_url'];
    final tutorRating = (tutorInfo['rating'] ?? 0.0) as double;

    // Determine status for display (combine payment and session status)
    String displayStatus = session.status;
    if (session.status == 'approved' && session.paymentStatus == 'unpaid') {
      displayStatus = 'awaiting_payment';
    } else if (session.paymentStatus == 'paid') {
      displayStatus = 'paid';
    }
    
    // Get rejection reason for expired/cancelled distinction
    final rejectionReason = session.rejectionReason;

    // Determine if card should be clickable
    // For approved unpaid sessions, disable card tap - let Pay Now button handle navigation
    final isApprovedUnpaid = session.status == 'approved' && 
        (session.paymentStatus.toLowerCase() == 'unpaid' || 
         session.paymentStatus.toLowerCase() == 'pending');
    final shouldAllowCardTap = !isApprovedUnpaid;

    return _buildNeomorphicCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: shouldAllowCardTap
          ? InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequestDetailScreen(
                      trialSession: session,
                    ),
                  ),
                ).then((_) {
                  // Refresh after returning from detail page
                  _loadRequests();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: _buildTrialCardContent(context, session, tutorName, tutorAvatarUrl, tutorRating, displayStatus, rejectionReason),
            )
          : IgnorePointer(
              // Ignore pointer events on the card itself, but allow buttons inside to work
              ignoring: false, // Don't ignore - allow child widgets to receive events
              child: Material(
                // Use Material instead of InkWell when card tap is disabled (for approved unpaid sessions)
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: _buildTrialCardContent(context, session, tutorName, tutorAvatarUrl, tutorRating, displayStatus, rejectionReason),
              ),
            ),
    );
  }

  Widget _buildTrialCardContent(
    BuildContext context,
    TrialSession session,
    String tutorName,
    String? tutorAvatarUrl,
    double tutorRating,
    String displayStatus,
    String? rejectionReason,
  ) {
    final t = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: displayStatus == 'paid' || displayStatus == 'scheduled'
            ? LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.03),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern header: Tutor info with integrated status
              Row(
                children: [
                    // Avatar with status indicator
                    Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: tutorAvatarUrl != null && tutorAvatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(tutorAvatarUrl)
                        : null,
                    child: tutorAvatarUrl == null || tutorAvatarUrl.isEmpty
                        ? Text(
                                  tutorName.isNotEmpty
                                      ? tutorName[0].toUpperCase()
                                      : 'T',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : null,
                        ),
                        // Status indicator dot
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _getStatusColor(displayStatus, rejectionReason: rejectionReason),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                  ),
                  const SizedBox(width: 12),
                    // Tutor name and rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                          tutorName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                                    fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Single status badge (compact, modern)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(displayStatus, rejectionReason: rejectionReason).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getStatusColor(displayStatus, rejectionReason: rejectionReason).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getStatusLabel(displayStatus, rejectionReason: rejectionReason),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(displayStatus, rejectionReason: rejectionReason),
                              ),
                            ),
                              ),
                            ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Colors.amber[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tutorRating > 0
                                  ? tutorRating.toStringAsFixed(1)
                                    : 'New',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  session.subject,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

                const SizedBox(height: 16),
              
                // Session details - flat horizontal layout (no elevation)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                      _buildModernInfoItem(
                        Icons.calendar_today_outlined,
                    session.formattedDate,
                  ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey[300],
                      ),
                      _buildModernInfoItem(
                        Icons.access_time_outlined,
                    session.formattedTime,
                  ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey[300],
                      ),
                      _buildModernInfoItem(
                        session.location == 'online' 
                            ? Icons.video_call_outlined 
                            : Icons.location_on_outlined,
                    session.location == 'online' ? 'Online' : 'On-site',
                  ),
                ],
                  ),
                ),

                // Trial goal/reason - full width text above price (no icon)
                if (session.trialGoal != null && session.trialGoal!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    _cleanTrialGoal(session.trialGoal!),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Price and Action button in a row
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Price section (left side, 40% of row)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trial Fee',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${session.trialFee.toStringAsFixed(0)} XAF',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action button (right side, 60% of row)
                    Expanded(
                      flex: 3,
                      child: Builder(
                        builder: (context) {
                          // Check if session time has passed
                          final hasPassed = SessionDateUtils.isSessionExpired(session);
                          
                          // Check if session is cancelled with expiration reason
                          final isCancelledExpired = session.status == 'cancelled' && 
                                                     (session.rejectionReason?.contains('expired') == true ||
                                                      session.rejectionReason?.contains('not completed') == true);
                          
                          // Show Reschedule for:
                          // 1. Sessions that have passed (expired) - includes paid sessions that passed
                          // 2. Cancelled sessions with expiration reason
                          if (hasPassed || isCancelledExpired) {
                            return OutlinedButton.icon(
                              onPressed: () async {
                                LogService.info('📅 Reschedule button clicked for trial session: ${session.id}');
                                // Navigate to reschedule screen
                                final tutorData = await _loadTutorInfoForReschedule(session.tutorId);
                                if (tutorData != null && mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookTrialSessionScreen(
                                        tutor: tutorData,
                                        rescheduleSessionId: session.id,
                                        isReschedule: true,
                                      ),
                                    ),
                                  ).then((_) {
                                    if (mounted) _loadRequests();
                                  });
                                }
                              },
                              icon: const Icon(Icons.edit_calendar, size: 18),
                              label: Text(
                                'Reschedule',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                          
                          // For pending trial sessions: Show "View Details" (NOT Pay Now)
                          // Payment is only allowed after tutor approval
                          // Use "View Details" instead of "View Session" to avoid confusion
                          // with paid sessions that also have "View Session" button
                          if (session.status == 'pending') {
                            return OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RequestDetailScreen(
                                      trialSession: session,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.info_outline, size: 18),
                              label: Text(
                                'View Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                          
                          // Show Pay Now for approved/scheduled, unpaid, non-expired sessions
                          if (SessionDateUtils.shouldShowPayNowButton(session)) {
                            return ElevatedButton(
                              onPressed: () async {
                                LogService.info('💰 Pay Now button clicked for trial session: ${session.id}');
                                // Navigate directly to payment screen (not detail screen)
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TrialPaymentScreen(trialSession: session),
                                  ),
                                );

                                if (result == true) {
                                  // Payment successful - refresh and navigate to sessions
                                  await Future.delayed(const Duration(milliseconds: 2000));
                                  if (!mounted) return;
                                  await _refreshTrialSession(session.id);
                                  await _loadRequests();
                                  if (mounted) {
                                    safeSetState(() {});
                                    // Navigate to sessions tab to show the newly created session
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      '/student-nav',
                                      (route) => route.isFirst,
                                      arguments: {'initialTab': 2}, // Sessions tab
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                t.myRequestsPayNow,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                          
                          // Show View Session for paid, non-expired sessions - navigate to sessions screen
                          if (session.paymentStatus.toLowerCase() == 'paid' || 
                              session.paymentStatus.toLowerCase() == 'completed') {
                            return ElevatedButton.icon(
                              onPressed: () async {
                                LogService.info('🔵 [VIEW_SESSION_TRIAL] Button clicked for trial session: ${session.id}');
                                LogService.info('🔵 [VIEW_SESSION_TRIAL] Session details: status=${session.status}, paymentStatus=${session.paymentStatus}');
                                LogService.info('🔵 [VIEW_SESSION_TRIAL] Widget mounted: ${mounted}');
                                LogService.info('🔵 [VIEW_SESSION_TRIAL] Context valid: ${context.mounted}');
                                
                                try {
                                  // Check if session exists in individual_sessions before navigating
                                  LogService.info('🔵 [VIEW_SESSION_TRIAL] Calling _checkAndNavigateToSessions...');
                                  await _checkAndNavigateToSessions(context, sessionId: session.id, isTrial: true);
                                  LogService.info('🔵 [VIEW_SESSION_TRIAL] _checkAndNavigateToSessions completed');
                                } catch (e, stackTrace) {
                                  LogService.error('🔴 [VIEW_SESSION_TRIAL] ERROR in button onPressed: $e');
                                  LogService.error('🔴 [VIEW_SESSION_TRIAL] Stack trace: $stackTrace');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Navigation error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                'View Session',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            );
                          }
                          
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
  
  /// Load tutor info for reschedule (simplified version without join)
  Future<Map<String, dynamic>?> _loadTutorInfoForReschedule(String tutorId) async {
    try {
      final supabase = SupabaseService.client;
      
      // Fetch tutor profile and profile separately to avoid relationship ambiguity
      final tutorProfile = await supabase
          .from('tutor_profiles')
          .select('user_id, rating, admin_approved_rating, total_reviews, profile_photo_url')
          .eq('user_id', tutorId)
          .maybeSingle();

      if (tutorProfile == null) return null;

      final profile = await supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', tutorId)
          .maybeSingle();

      return {
        'id': tutorId,
        'user_id': tutorId,
        'full_name': profile?['full_name'] as String? ?? 'Tutor',
        'avatar_url': tutorProfile['profile_photo_url'] as String? ?? 
                     profile?['avatar_url'] as String?,
        'rating': tutorProfile['rating'] ?? 0.0,
        'admin_approved_rating': tutorProfile['admin_approved_rating'],
        'total_reviews': tutorProfile['total_reviews'] ?? 0,
      };
    } catch (e) {
      LogService.error('Error loading tutor for reschedule: $e');
      return null;
    }
  }


  /// Get the full DateTime for a trial session (date + time)
  DateTime _getSessionDateTime(TrialSession session) {
    final date = session.scheduledDate;
    final timeParts = session.scheduledTime.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> _deleteTrialSession(String sessionId) async {
    // First check the session status
    final session = _trialSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => _trialSessions.first,
    );

    final isApproved =
        session.status == 'approved' || session.status == 'scheduled';

    if (isApproved) {
      // For approved sessions, require cancellation reason
      await _cancelApprovedTrialWithReason(sessionId, session);
      return;
    }

    // For pending sessions, allow direct deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red[300], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Trial Session',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this trial session request? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppTheme.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Deleting...', style: GoogleFonts.poppins()),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Actually delete the session (not just cancel)
        // For pending sessions, reason is optional
        await TrialSessionService.deleteTrialSession(
          sessionId: sessionId,
          reason: null, // Optional for pending sessions
        );

        if (!mounted) return;

        // Remove from local list immediately for instant UI update
        // Find the session first to get tutorId for cache cleanup
        final sessionToDelete = _trialSessions.firstWhere(
          (s) => s.id == sessionId,
        );
        final tutorId = sessionToDelete.tutorId;

        safeSetState(() {
          _trialSessions.removeWhere((session) => session.id == sessionId);
          // Clean up cache if no other sessions for this tutor
          final hasOtherSessions = _trialSessions.any(
            (s) => s.tutorId == tutorId,
          );
          if (!hasOtherSessions) {
            _tutorInfoCache.remove(tutorId);
          }
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trial session deleted successfully',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Reload to ensure consistency
        _loadRequests();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.toString().contains('Only pending sessions') ||
                            e.toString().contains('cancel instead')
                        ? 'This session has been approved. Please use the cancel button to cancel it with a reason.'
                        : 'Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Delete a custom tutor request (only for pending requests)
  Future<void> _deleteCustomRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red[300], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Custom Request',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this custom tutor request? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppTheme.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Deleting...', style: GoogleFonts.poppins()),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Cancel the request (sets status to 'closed')
        await TutorRequestService.cancelRequest(requestId);

        if (!mounted) return;

        // Remove from local list
        safeSetState(() {
          _customRequests.removeWhere((req) => req.id == requestId);
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Custom request deleted successfully',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Reload to ensure consistency
        _loadRequests();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Cancel an approved trial session with reason (for parent/student)
  /// This prioritizes parent/student choice and notifies tutor
  Future<void> _cancelApprovedTrialWithReason(
    String sessionId,
    TrialSession session,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.orange[300], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cancel Trial Session',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
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
              'The tutor has already approved this session. Please provide a reason for cancellation. The tutor will be notified.',
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g., Schedule conflict, found another tutor, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                labelText: 'Cancellation Reason',
                labelStyle: GoogleFonts.poppins(fontSize: 12),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
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
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The tutor will be notified immediately with your reason.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.blue[900],
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Session',
              style: GoogleFonts.poppins(
                color: AppTheme.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancel Session',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Cancelling...', style: GoogleFonts.poppins()),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Cancel the approved session with reason
        await TrialSessionService.cancelApprovedTrialSession(
          sessionId: sessionId,
          cancellationReason: reasonController.text.trim(),
        );

        if (!mounted) return;

        // Update local state to show cancelled status
        safeSetState(() {
          final index = _trialSessions.indexWhere((s) => s.id == sessionId);
          if (index != -1) {
            _trialSessions[index] = session.copyWith(status: 'cancelled');
          }
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trial session cancelled. Tutor has been notified.',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        // Reload to ensure consistency
        _loadRequests();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        reasonController.dispose();
      }
    }
  }

  /// Reject an approved trial session (before payment)
  Future<void> _rejectApprovedTrial(TrialSession session) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Approved Session',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejecting this approved session:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text('Reject', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        // Update session status to rejected with reason
        final supabase = Supabase.instance.client;
        await supabase
            .from('trial_sessions')
            .update({
              'status': 'rejected',
              'rejection_reason': reasonController.text.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', session.id);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session rejected successfully')),
        );
        _loadRequests();
      } catch (e) {
        if (!mounted) return;
        ErrorHandlerService.showErrorSnackbar(context, e, 'Failed to reject session');
      }
    }
  }

  /// Show reschedule dialog for paid sessions
  Future<void> _showRescheduleDialog(TrialSession session) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reschedule feature coming soon. Please contact support if you need to reschedule.',
          style: GoogleFonts.poppins(),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  /// Build payment status chip using cached payment status (no FutureBuilder flickering)
  Widget _buildPaymentStatusChip(BookingRequest request) {
    // If approved, check payment status
    if (request.status == 'approved') {
      if (request.paymentStatus == 'paid') {
        // Show "Paid" status
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Text(
            'Paid',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
        );
      } else if (request.paymentStatus == 'pending' && request.paymentRequestId != null) {
        // Show "Pay Now" status
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Text(
            'Pay Now',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        );
      }
    }
    // Default status chip
    return _buildStatusChip(context, request.status);
  }

  Widget _buildStatusChip(BuildContext context, String status, {bool isCompact = false}) {
    Color chipColor;
    final t = AppLocalizations.of(context)!;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        chipColor = Colors.orange;
        label = t.myRequestsStatusPending;
        break;
      case 'approved':
      case 'matched':
      case 'scheduled':
        chipColor = Colors.green;
        label = status == 'matched'
            ? 'Matched'
            : status == 'scheduled'
            ? 'Scheduled'
            : 'Approved';
        break;
      case 'rejected':
      case 'closed':
      case 'cancelled':
        chipColor = Colors.grey;
        label = status == 'closed'
            ? 'Closed'
            : status == 'cancelled'
            ? 'Cancelled'
            : 'Rejected';
        break;
      case 'in_progress':
      case 'completed':
        chipColor = Colors.blue;
        label = status == 'completed' ? 'Completed' : 'In Progress';
        break;
      default:
        chipColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: isCompact ? 9 : 10,
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.textMedium,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }


  /// Neomorphic card container with soft shadows
  Widget _buildNeomorphicCard({required Widget child, EdgeInsets? margin, Border? border}) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: [
          // Reduced elevation - lighter shadows
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            offset: const Offset(-2, -2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
          // Dark shadow (bottom-right) - reduced
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(2, 2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInlineInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMedium),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
        ),
      ],
    );
  }

  Widget _buildCompactInfo(IconData icon, String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textDark,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildModernInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Check if sessions exist and navigate to sessions screen, or show error dialog
  Future<void> _checkAndNavigateToSessions(
    BuildContext context, {
    String? sessionId,
    String? bookingRequestId,
    required bool isTrial,
  }) async {
    final startTime = DateTime.now();
    LogService.info('🔵 [CHECK_SESSIONS] ========== START ==========');
    LogService.info('🔵 [CHECK_SESSIONS] Method called at ${startTime.toIso8601String()}');
    LogService.info('🔵 [CHECK_SESSIONS] Parameters:');
    LogService.info('   - sessionId: $sessionId');
    LogService.info('   - bookingRequestId: $bookingRequestId');
    LogService.info('   - isTrial: $isTrial');
    LogService.info('🔵 [CHECK_SESSIONS] Context mounted: ${context.mounted}');
    LogService.info('🔵 [CHECK_SESSIONS] Widget mounted: $mounted');
    
    try {
      LogService.info('🔍 [CHECK_SESSIONS] Checking sessions before navigation...');
      LogService.info('📋 [CHECK_SESSIONS] Parameters: sessionId=$sessionId, bookingRequestId=$bookingRequestId, isTrial=$isTrial');
      
      final supabase = SupabaseService.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) {
        _showSessionErrorDialog(
          context,
          'Authentication Error',
          'You are not logged in. Please log in and try again.',
        );
        return;
      }

      List<Map<String, dynamic>> sessions = [];
      String errorDetails = '';

      if (isTrial && sessionId != null) {
        // Check for trial session in individual_sessions
        try {
          final trialSessions = await supabase
              .from('individual_sessions')
              .select('id, status, scheduled_date, scheduled_time')
              .or('learner_id.eq.$userId,parent_id.eq.$userId')
              .eq('id', sessionId)
              .limit(1);
          
          sessions = (trialSessions as List).cast<Map<String, dynamic>>();
          LogService.info('✅ Found ${sessions.length} trial session(s)');
          
          if (sessions.isEmpty) {
            errorDetails = 'Trial session not found in individual_sessions table.\n'
                'Session ID: $sessionId\n'
                'User ID: $userId\n'
                'This may indicate the session was not created after payment.';
          }
        } catch (e) {
          errorDetails = 'Error checking trial session: $e';
          LogService.error('❌ Error checking trial session: $e');
        }
      } else if (!isTrial && bookingRequestId != null) {
        // Check for recurring session and individual sessions
        try {
          // First, check booking request status and payment request
          final bookingRequest = await supabase
              .from('booking_requests')
              .select('id, status, tutor_id, student_id')
              .eq('id', bookingRequestId)
              .maybeSingle();
          
          LogService.info('📋 Booking request check: ${bookingRequest != null ? "Found" : "Not found"}');
          
          if (bookingRequest == null) {
            errorDetails = 'Booking request not found.\n'
                'Booking Request ID: $bookingRequestId\n'
                'User ID: $userId';
          } else {
            final bookingStatus = bookingRequest['status'] as String?;
            LogService.info('📋 Booking request status: $bookingStatus');
            
            // Check if payment request exists
            final paymentRequest = await supabase
                .from('payment_requests')
                .select('id, status, recurring_session_id')
                .eq('booking_request_id', bookingRequestId)
                .maybeSingle();
            
            LogService.info('📋 Payment request check: ${paymentRequest != null ? "Found" : "Not found"}');
            final paymentStatus = paymentRequest?['status'] as String?;
            final paymentRequestRecurringSessionId = paymentRequest?['recurring_session_id'] as String?;
            
            // If payment is paid, navigate directly without checking sessions
            // The sessions screen will handle RLS and show what's available
            if (paymentStatus == 'paid') {
              LogService.info('💰 Payment is paid - navigating directly to sessions screen');
              LogService.info('🔵 [NAVIGATION] Skipping session check, navigating directly...');
              sessions = [{'id': 'placeholder'}]; // Set a placeholder to trigger navigation
              // Don't return - let the navigation code below handle it
            }
            
            // Try to find recurring session by payment_request.recurring_session_id FIRST
            // (This is the primary link since request_id FK constraint references session_requests, not booking_requests)
            Map<String, dynamic>? recurringSession;
            
            if (paymentRequestRecurringSessionId != null) {
              LogService.info('📋 Looking up recurring session by payment_request.recurring_session_id: $paymentRequestRecurringSessionId');
              recurringSession = await supabase
                  .from('recurring_sessions')
                  .select('id, status, learner_id')
                  .eq('id', paymentRequestRecurringSessionId)
                  .maybeSingle();
              
              if (recurringSession != null) {
                LogService.info('✅ Found recurring session via payment_request.recurring_session_id');
              } else {
                LogService.warning('⚠️ Recurring session not found by payment_request.recurring_session_id');
              }
            }
            
            // Fallback: Try to find by request_id (may be NULL due to FK constraint)
            if (recurringSession == null) {
              LogService.info('📋 Fallback: Trying to find recurring session by request_id: $bookingRequestId');
              recurringSession = await supabase
                  .from('recurring_sessions')
                  .select('id, status, learner_id')
                  .eq('request_id', bookingRequestId)
                  .maybeSingle();
              
              if (recurringSession != null) {
                LogService.info('✅ Found recurring session via request_id');
              }
            }
            
            // If still not found, check if there's a recurring session that should be linked
            // This handles cases where recurring session was created but not linked to payment request
            if (recurringSession == null && paymentRequest != null) {
              LogService.info('📋 Recurring session not found - checking if one should exist...');
              // The fix function will handle creating it if needed
            }
            
            LogService.info('📋 Recurring session check: ${recurringSession != null ? "Found" : "Not found"}');
            
            if (recurringSession == null) {
              String statusInfo = '';
              if (bookingStatus != 'approved') {
                statusInfo = '\n\n⚠️ Booking request status is "$bookingStatus" (expected "approved").\n'
                    'Recurring sessions are only created after approval.';
              } else if (paymentRequest == null) {
                statusInfo = '\n\n⚠️ No payment request found for this booking.\n'
                    'Payment request should be created when tutor approves the booking.';
              } else {
                final paymentStatus = paymentRequest['status'] as String?;
                statusInfo = '\n\n⚠️ Payment request exists but recurring session was not created.\n'
                    'Payment Request Status: $paymentStatus\n'
                    'This may indicate:\n'
                    '1. Recurring session creation failed during approval\n'
                    '2. Database error during recurring session creation\n'
                    '3. Approval process did not complete successfully';
              }
              
              errorDetails = 'Recurring session not found for booking request.\n'
                  'Booking Request ID: $bookingRequestId\n'
                  'Booking Status: $bookingStatus\n'
                  'User ID: $userId\n'
                  'Payment Request: ${paymentRequest != null ? "Found (ID: ${paymentRequest['id']})" : "Not found"}\n'
                  'Payment Request Recurring Session ID: ${paymentRequestRecurringSessionId ?? "null"}$statusInfo';
              
              // Show error dialog
              if (mounted) {
                _showSessionErrorDialog(
                  context,
                  'Sessions Not Found',
                  errorDetails,
                );
                return; // Exit early since we showed the dialog
              }
            } else {
              final recurringSessionId = recurringSession['id'] as String;
              final learnerId = recurringSession['learner_id'] as String?;
              
              LogService.info('📋 Recurring session ID: $recurringSessionId');
              LogService.info('📋 Learner ID: $learnerId, User ID: $userId');
              
              // Check if individual sessions exist
              LogService.info('🔍 [CHECK_SESSIONS] Querying individual_sessions for recurring_session_id: $recurringSessionId');
              final individualSessions = await supabase
                  .from('individual_sessions')
                  .select('id, status, scheduled_date, scheduled_time, recurring_session_id, learner_id, parent_id')
                  .eq('recurring_session_id', recurringSessionId)
                  .limit(10);
              
              sessions = (individualSessions as List).cast<Map<String, dynamic>>();
              LogService.info('✅ [CHECK_SESSIONS] Found ${sessions.length} individual session(s) for recurring session: $recurringSessionId');
              if (sessions.isNotEmpty) {
                LogService.info('📋 [CHECK_SESSIONS] First session IDs: ${sessions.take(3).map((s) => s['id']).join(", ")}');
              }
              
              if (sessions.isEmpty) {
                // Check if payment is paid - if so, we can generate sessions
                final paymentStatus = paymentRequest?['status'] as String?;
                final canGenerateSessions = paymentStatus == 'paid';
                
                errorDetails = 'No individual sessions found for this booking.\n'
                    'Recurring Session ID: $recurringSessionId\n'
                    'Booking Request ID: $bookingRequestId\n'
                    'User ID: $userId\n'
                    'Learner ID: $learnerId\n'
                    'Payment Status: ${paymentStatus ?? "unknown"}\n\n'
                    'Possible causes:\n'
                    '1. Sessions were not generated after payment\n'
                    '2. Payment webhook did not trigger session generation\n'
                    '3. Session generation failed silently\n'
                    '4. Date calculation issue (sessions may be scheduled in the past)';
                
                // If payment is paid, try to generate sessions automatically
                if (canGenerateSessions) {
                  LogService.info('💰 Payment is paid but sessions missing - attempting to generate sessions...');
                  try {
                    final sessionsGenerated = await RecurringSessionService.generateIndividualSessions(
                      recurringSessionId: recurringSessionId,
                      weeksAhead: 8,
                    );
                    
                    if (sessionsGenerated > 0) {
                      LogService.success('✅ Generated $sessionsGenerated individual sessions');
                      // Re-check for sessions
                      final newSessions = await supabase
                          .from('individual_sessions')
                          .select('id, status, scheduled_date, scheduled_time, recurring_session_id')
                          .eq('recurring_session_id', recurringSessionId)
                          .limit(10);
                      
                      sessions = (newSessions as List).cast<Map<String, dynamic>>();
                      LogService.info('✅ Found ${sessions.length} individual session(s) after generation');
                    } else {
                      LogService.warning('⚠️ Session generation returned 0 sessions');
                      // Check if start_date might be the issue
                      try {
                        final rsDetails = await supabase
                            .from('recurring_sessions')
                            .select('start_date, days, times')
                            .eq('id', recurringSessionId)
                            .maybeSingle();
                        if (rsDetails != null) {
                          final startDate = DateTime.parse(rsDetails['start_date'] as String);
                          final today = DateTime.now();
                          if (startDate.isBefore(today)) {
                            errorDetails += '\n\n⚠️ ISSUE DETECTED: Recurring session start_date ($startDate) is in the past. '
                                'Sessions cannot be generated for past dates. The start_date needs to be updated to a future date.';
                          }
                        }
                      } catch (e) {
                        LogService.warning('Could not check start_date: $e');
                      }
                    }
                  } catch (e, stackTrace) {
                    LogService.error('❌ Failed to generate individual sessions: $e');
                    LogService.error('📚 Stack trace: $stackTrace');
                    
                    // Enhanced RLS error detection and messaging
                    final errorString = e.toString();
                    if (errorString.contains('row-level security') || errorString.contains('RLS') || errorString.contains('42501')) {
                      errorDetails += '\n\n❌ **RLS Policy Violation Detected**\n';
                      errorDetails += 'The database security policy is blocking session creation.\n\n';
                      errorDetails += '**Possible causes:**\n';
                      errorDetails += '1. Your user ID does not match the tutor, learner, or parent ID in the session\n';
                      errorDetails += '2. The RLS INSERT policy may be missing or incorrectly configured\n';
                      errorDetails += '3. You may need to run the RLS fix script in Supabase\n\n';
                      errorDetails += '**Error details:** $e\n\n';
                      errorDetails += '**To fix:**\n';
                      errorDetails += '1. Check terminal logs for user ID mismatch details\n';
                      errorDetails += '2. Run DIAGNOSE_RLS_INSERT_FAILURE.sql in Supabase SQL Editor\n';
                      errorDetails += '3. Run FIX_INDIVIDUAL_SESSIONS_RLS_SIMPLE.sql to fix the policy';
                    } else {
                      errorDetails += '\n\n❌ Session Generation Error: $e';
                    }
                    // Continue to show error dialog
                  }
                }
              } else {
                // Verify user has access to these sessions by checking learner_id or parent_id in individual_sessions
                LogService.info('🔍 [CHECK_SESSIONS] Verifying user access to ${sessions.length} session(s)');
                LogService.info('🔍 [CHECK_SESSIONS] User ID: $userId');
                final userSessions = sessions.where((s) {
                  final sessionLearnerId = s['learner_id'] as String?;
                  final sessionParentId = s['parent_id'] as String?;
                  final hasAccess = sessionLearnerId == userId || sessionParentId == userId;
                  if (!hasAccess) {
                    LogService.warning('⚠️ [CHECK_SESSIONS] Session ${s['id']} - learner_id: $sessionLearnerId, parent_id: $sessionParentId (no match)');
                  }
                  return hasAccess;
                }).toList();
                
                LogService.info('✅ [CHECK_SESSIONS] User has access to ${userSessions.length} out of ${sessions.length} session(s)');
                
                if (userSessions.isEmpty && sessions.isNotEmpty) {
                  // If sessions exist but user doesn't have access, still navigate
                  // The sessions screen will handle RLS and show what the user can see
                  LogService.warning('⚠️ [CHECK_SESSIONS] Sessions exist but user access check failed - navigating anyway (RLS will filter)');
                  // Don't set errorDetails - we'll navigate anyway since sessions exist
                } else if (userSessions.isNotEmpty) {
                  // Use the filtered sessions for logging
                  sessions = userSessions;
                  LogService.info('✅ [CHECK_SESSIONS] Using ${sessions.length} accessible session(s)');
                }
              }
            }
          }
        } catch (e, stackTrace) {
          errorDetails = 'Error checking sessions: $e\n\nStack trace:\n$stackTrace';
          LogService.error('❌ Error checking sessions: $e');
          LogService.error('📚 Stack trace: $stackTrace');
        }
      }

      // Log final state before navigation decision
      LogService.info('🔵 [CHECK_SESSIONS] Final state check:');
      LogService.info('   - Sessions count: ${sessions.length}');
      LogService.info('   - Error details empty: ${errorDetails.isEmpty}');
      LogService.info('   - Widget mounted: $mounted');
      LogService.info('   - Context mounted: ${context.mounted}');
      
      // If sessions found, navigate to sessions screen
      if (sessions.isNotEmpty) {
        LogService.success('✅ [NAVIGATION] Sessions found (${sessions.length}), preparing to navigate...');
        LogService.info('🔵 [NAVIGATION] Session IDs: ${sessions.take(5).map((s) => s['id']).join(", ")}${sessions.length > 5 ? "..." : ""}');
        
        if (!mounted) {
          LogService.error('🔴 [NAVIGATION] Widget not mounted, cannot navigate');
          return;
        }
        
        LogService.info('🔵 [NAVIGATION] Widget is mounted, proceeding with navigation');
        LogService.info('🔵 [NAVIGATION] Context mounted: ${context.mounted}');
        LogService.info('🔵 [NAVIGATION] Navigator canPop: ${Navigator.of(context).canPop()}');
        
        try {
          // Check if route exists
          final routeSettings = ModalRoute.of(context)?.settings;
          LogService.info('🔵 [NAVIGATION] Current route: ${routeSettings?.name}');
          LogService.info('🔵 [NAVIGATION] Current route arguments: ${routeSettings?.arguments}');
          
          // Log navigation stack before navigation
          final navigator = Navigator.of(context);
          LogService.info('🔵 [NAVIGATION] Navigator state: ${navigator.toString()}');
          
          LogService.info('🔵 [NAVIGATION] Attempting pushNamedAndRemoveUntil to /my-sessions');
          LogService.info('🔵 [NAVIGATION] Arguments: {\'initialTab\': 0}');
          
          // Set navigation flag to prevent refresh during navigation
          _isNavigating = true;
          LogService.info('🔵 [NAVIGATION] Set _isNavigating = true to prevent refresh');
          
          // Navigate to MySessionsScreen directly (not through bottom nav)
          // This is the correct route for viewing sessions as a student
          final navigationResult = Navigator.of(context).pushNamedAndRemoveUntil(
            '/my-sessions',
            (route) {
              final isFirst = route.isFirst;
              LogService.info('🔵 [NAVIGATION] Route predicate check: ${route.settings.name} isFirst=$isFirst');
              // Keep the first route and /student-nav if it exists
              return isFirst || route.settings.name == '/student-nav';
            },
            arguments: {'initialTab': 0}, // Upcoming sessions tab
          );
          
          LogService.success('✅ [NAVIGATION] Navigation command executed successfully');
          LogService.info('🔵 [NAVIGATION] Navigation result: $navigationResult');
          
          // Wait a moment to see if navigation actually happens
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (mounted) {
            final newRoute = ModalRoute.of(context)?.settings;
            LogService.info('🔵 [NAVIGATION] Route after navigation: ${newRoute?.name}');
            LogService.info('🔵 [NAVIGATION] Route arguments after navigation: ${newRoute?.arguments}');
            
            if (newRoute?.name == '/my-sessions') {
              LogService.success('✅ [NAVIGATION] Successfully navigated to /my-sessions');
            } else {
              LogService.warning('⚠️ [NAVIGATION] Navigation may have failed - route is still: ${newRoute?.name}');
              // Reset flag if navigation failed
              _isNavigating = false;
            }
          } else {
            LogService.info('🔵 [NAVIGATION] Widget unmounted after navigation (expected)');
            // Navigation succeeded, widget unmounted - flag will remain true (screen is gone)
          }
        } catch (e, stackTrace) {
          LogService.error('🔴 [NAVIGATION] ERROR during navigation: $e');
          LogService.error('🔴 [NAVIGATION] Error type: ${e.runtimeType}');
          LogService.error('🔴 [NAVIGATION] Stack trace: $stackTrace');
          // Reset flag on error
          _isNavigating = false;
          
          // Check for specific error types
          if (e.toString().contains('route')) {
            LogService.error('🔴 [NAVIGATION] Route-related error detected');
          }
          if (e.toString().contains('context')) {
            LogService.error('🔴 [NAVIGATION] Context-related error detected');
          }
          if (e.toString().contains('navigator')) {
            LogService.error('🔴 [NAVIGATION] Navigator-related error detected');
          }
          
          // Re-throw to be caught by outer try-catch
          rethrow;
        }
        
        return; // Exit early to prevent showing error dialog
      } else {
        // Show error dialog with details
        LogService.warning('⚠️ [CHECK_SESSIONS] No sessions found, showing error dialog');
        LogService.info('🔵 [CHECK_SESSIONS] Error details length: ${errorDetails.length}');
        LogService.info('🔵 [CHECK_SESSIONS] Widget mounted: $mounted');
        LogService.info('🔵 [CHECK_SESSIONS] Context mounted: ${context.mounted}');
        
        if (mounted && context.mounted) {
          _showSessionErrorDialog(
            context,
            'Sessions Not Found',
            errorDetails.isNotEmpty 
                ? errorDetails 
                : 'No sessions were found for this request. Please contact support if this issue persists.',
          );
        } else {
          LogService.error('🔴 [CHECK_SESSIONS] Cannot show error dialog - widget or context not mounted');
        }
      }
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      LogService.info('🔵 [CHECK_SESSIONS] ========== END ==========');
      LogService.info('🔵 [CHECK_SESSIONS] Total duration: ${duration.inMilliseconds}ms');
    } catch (e, stackTrace) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      LogService.error('🔴 [CHECK_SESSIONS] ========== ERROR ==========');
      LogService.error('🔴 [CHECK_SESSIONS] Unexpected error in _checkAndNavigateToSessions: $e');
      LogService.error('🔴 [CHECK_SESSIONS] Error type: ${e.runtimeType}');
      LogService.error('🔴 [CHECK_SESSIONS] Stack trace: $stackTrace');
      LogService.error('🔴 [CHECK_SESSIONS] Duration before error: ${duration.inMilliseconds}ms');
      LogService.error('🔴 [CHECK_SESSIONS] Widget mounted: $mounted');
      LogService.error('🔴 [CHECK_SESSIONS] Context mounted: ${context.mounted}');
      
      if (mounted && context.mounted) {
        _showSessionErrorDialog(
          context,
          'Unexpected Error',
          'An unexpected error occurred: $e\n\nPlease check the terminal logs for more details.',
        );
      } else {
        LogService.error('🔴 [CHECK_SESSIONS] Cannot show error dialog - widget or context not mounted');
      }
      LogService.error('🔴 [CHECK_SESSIONS] ========== ERROR END ==========');
    }
  }

  /// Fix missing recurring session and generate individual sessions
  /// This is called when payment is paid but recurring session is missing
  Future<void> _fixMissingRecurringSession(
    BuildContext context, {
    required String bookingRequestId,
    String? paymentRequestId,
  }) async {
    try {
      LogService.info('🔧 Starting fix for missing recurring session...');
      LogService.info('📋 Booking Request ID: $bookingRequestId');
      LogService.info('📋 Payment Request ID: $paymentRequestId');

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Fixing session issue...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

      final supabase = SupabaseService.client;

      // Get booking request
      final bookingRequestData = await supabase
          .from('booking_requests')
          .select()
          .eq('id', bookingRequestId)
          .maybeSingle();

      if (bookingRequestData == null) {
        throw Exception('Booking request not found: $bookingRequestId');
      }

      final bookingRequest = BookingRequest.fromJson(bookingRequestData);
      LogService.info('✅ Found booking request: ${bookingRequest.id}');

      // Get payment request if not provided
      if (paymentRequestId == null) {
        LogService.info('📋 Payment request ID not provided, fetching from booking request...');
        try {
          final paymentRequestData = await supabase
              .from('payment_requests')
              .select('id, status, recurring_session_id')
              .eq('booking_request_id', bookingRequestId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          
          if (paymentRequestData != null) {
            paymentRequestId = paymentRequestData['id'] as String?;
            LogService.info('✅ Found payment request ID: $paymentRequestId');
          }
        } catch (e) {
          LogService.warning('⚠️ Failed to fetch payment request: $e');
        }
      }

      // Check if recurring session already exists
      // Priority: payment_request.recurring_session_id FIRST (since request_id FK references session_requests, not booking_requests)
      Map<String, dynamic>? recurringSession;
      
      if (paymentRequestId != null) {
        try {
          final paymentRequest = await supabase
              .from('payment_requests')
              .select('recurring_session_id')
              .eq('id', paymentRequestId)
              .maybeSingle();
          
          final recurringSessionIdFromPayment = paymentRequest?['recurring_session_id'] as String?;
          if (recurringSessionIdFromPayment != null) {
            recurringSession = await supabase
                .from('recurring_sessions')
                .select('id')
                .eq('id', recurringSessionIdFromPayment)
                .maybeSingle();
            if (recurringSession != null) {
              LogService.info('✅ Found recurring session via payment_request.recurring_session_id');
            }
          }
        } catch (e) {
          LogService.warning('⚠️ Error checking payment_request for recurring_session_id: $e');
        }
      }
      
      // Fallback: Try by request_id (may be NULL due to FK constraint)
      if (recurringSession == null) {
        recurringSession = await supabase
            .from('recurring_sessions')
            .select('id')
            .eq('request_id', bookingRequestId)
            .maybeSingle();
        if (recurringSession != null) {
          LogService.info('✅ Found recurring session via request_id');
        }
      }

      String recurringSessionId;
      
      if (recurringSession != null) {
        // Recurring session already exists
        recurringSessionId = recurringSession['id'] as String;
        LogService.info('✅ Recurring session already exists: $recurringSessionId');
        
        // Ensure payment request is linked
        if (paymentRequestId != null) {
          try {
            final paymentRequest = await supabase
                .from('payment_requests')
                .select('recurring_session_id')
                .eq('id', paymentRequestId)
                .maybeSingle();
            
            if (paymentRequest?['recurring_session_id'] != recurringSessionId) {
              LogService.info('🔗 Linking payment request to recurring session...');
              await PaymentRequestService.linkPaymentRequestToRecurringSession(
                paymentRequestId,
                recurringSessionId,
              );
              LogService.success('✅ Payment request linked to recurring session');
            }
          } catch (e) {
            LogService.warning('⚠️ Failed to link payment request: $e');
          }
        }
      } else {
        // Create recurring session
        LogService.info('📅 Creating recurring session...');
        try {
          final recurringSessionData = await RecurringSessionService.createRecurringSessionFromBooking(
            bookingRequest,
            paymentRequestId: paymentRequestId,
          );

          recurringSessionId = recurringSessionData['id'] as String;
          LogService.success('✅ Recurring session created: $recurringSessionId');
          
          // Link payment request if not already linked
          if (paymentRequestId != null) {
            try {
              await PaymentRequestService.linkPaymentRequestToRecurringSession(
                paymentRequestId,
                recurringSessionId,
              );
              LogService.success('✅ Payment request linked to recurring session');
            } catch (e) {
              LogService.warning('⚠️ Failed to link payment request: $e');
              // Continue even if linking fails
            }
          }
        } catch (e, stackTrace) {
          LogService.error('❌ Failed to create recurring session: $e');
          LogService.error('📚 Stack trace: $stackTrace');
          throw Exception('Failed to create recurring session: $e');
        }
      }

      // Check if payment is paid - if so, generate individual sessions
      bool shouldGenerateSessions = false;
      if (paymentRequestId != null) {
        try {
          final paymentRequest = await supabase
              .from('payment_requests')
              .select('status')
              .eq('id', paymentRequestId)
              .maybeSingle();

          final paymentStatus = paymentRequest?['status'] as String?;
          LogService.info('💰 Payment status: $paymentStatus');

          if (paymentStatus == 'paid') {
            shouldGenerateSessions = true;
          }
        } catch (e) {
          LogService.warning('⚠️ Error checking payment status: $e');
        }
      }

      // Generate individual sessions if payment is paid
      if (shouldGenerateSessions) {
        LogService.info('💰 Payment is paid - generating individual sessions...');
        try {
          // Check if sessions already exist
          final existingSessions = await supabase
              .from('individual_sessions')
              .select('id')
              .eq('recurring_session_id', recurringSessionId)
              .limit(1);
          
          if (existingSessions.isEmpty) {
            final sessionsGenerated = await RecurringSessionService.generateIndividualSessions(
              recurringSessionId: recurringSessionId,
              weeksAhead: 8,
            );
            LogService.success('✅ Generated $sessionsGenerated individual sessions');
          } else {
            LogService.info('✅ Individual sessions already exist, skipping generation');
          }
        } catch (e, stackTrace) {
          LogService.error('❌ Failed to generate individual sessions: $e');
          LogService.error('📚 Stack trace: $stackTrace');
          // Continue even if generation fails - user can try again
        }
      } else {
        LogService.info('💰 Payment not paid yet - individual sessions will be generated after payment');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sessions fixed successfully! Navigating to sessions...',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Wait a moment for the snackbar to show
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to sessions tab
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/student-nav',
          (route) => route.isFirst,
          arguments: {'initialTab': 2}, // Sessions tab
        );
      }
    } catch (e, stackTrace) {
      LogService.error('❌ Error fixing missing recurring session: $e');
      LogService.error('📚 Stack trace: $stackTrace');

      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fix sessions: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Show error dialog with session generation details
  void _showSessionErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
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
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Check terminal logs for detailed error information.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Color _getStatusColor(String status, {String? rejectionReason}) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
      case 'scheduled':
        return AppTheme.primaryColor; // Changed from green to blue
      case 'awaiting_payment':
        return AppTheme.primaryColor;
      case 'paid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        // Use orange for expired sessions, red for user-initiated cancellations
        if (rejectionReason != null && 
            (rejectionReason.toLowerCase().contains('expired') || 
             rejectionReason.toLowerCase().contains('session expired') ||
             rejectionReason.toLowerCase().contains('time passed'))) {
          return Colors.orange; // Orange for expired
        }
        return Colors.red; // Red for cancelled
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status, {String? rejectionReason}) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'scheduled':
        return 'Scheduled';
      case 'awaiting_payment':
        return 'Pay Now';
      case 'paid':
        return 'Paid';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        // Show "Expired" if it's an expired session, "Cancelled" if user-initiated
        if (rejectionReason != null && 
            (rejectionReason.toLowerCase().contains('expired') || 
             rejectionReason.toLowerCase().contains('session expired') ||
             rejectionReason.toLowerCase().contains('time passed'))) {
          return 'Expired';
        }
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Widget _buildPaymentStatusBadge(BuildContext context, TrialSession session) {
    String statusText;
    final t = AppLocalizations.of(context)!;
    Color backgroundColor;
    Color textColor;
    IconData icon;

    if (session.paymentStatus == 'paid') {
      statusText = 'Paid';
      backgroundColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      icon = Icons.check_circle;
    } else if (session.status == 'pending') {
      statusText = t.myRequestsStatusPending;
      backgroundColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
      icon = Icons.pending;
    } else if (session.status == 'approved' || session.status == 'scheduled') {
      statusText = 'Awaiting Payment';
      backgroundColor = Colors.blue[50]!;
      textColor = Colors.blue[700]!;
      icon = Icons.payment;
    } else if (session.status == 'rejected') {
      statusText = 'Rejected';
      backgroundColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
      icon = Icons.cancel;
    } else if (session.status == 'completed') {
      statusText = 'Completed';
      backgroundColor = Colors.grey[100]!;
      textColor = Colors.grey[700]!;
      icon = Icons.check_circle_outline;
    } else {
      statusText = session.status.toUpperCase();
      backgroundColor = Colors.grey[100]!;
      textColor = Colors.grey[700]!;
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppTheme.textLight),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String filter, String label) {
    final t = AppLocalizations.of(context)!;
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        safeSetState(() {
          _selectedFilter = filter;
        });
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

  Widget _buildSelectedTabContent(BuildContext context, String filter) {
    switch (_selectedFilter) {
      case 'all':
        return _buildAllRequestsTab(context);
      case 'pending':
        return _buildPendingRequestsTab(context);
      case 'custom':
        return _buildCustomRequestsTab(context);
      case 'trial':
        return _buildTrialSessionsTab(context);
      case 'booking':
        return _buildBookingsTab(context);
      default:
        return _buildAllRequestsTab(context);
    }
  }

  /// Get human-readable cache age text
  String _getCacheAgeText(DateTime cacheTime) {
    final now = DateTime.now();
    final difference = now.difference(cacheTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
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

}

// Helper class to combine different request types
class _RequestItem {
  final String type; // 'booking', 'custom', 'trial'
  final BookingRequest? booking;
  final TutorRequest? custom;
  final TrialSession? trial;

  _RequestItem({
    required this.type,
    this.booking,
    this.custom,
    this.trial,
  });
}

