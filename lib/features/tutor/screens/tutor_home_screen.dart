import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/status_bar_utils.dart';
import '../../../core/services/log_service.dart';
import '../../../core/widgets/app_logo_header.dart';
import '../../../core/services/auth_service.dart' hide LogService;
import '../../../core/services/supabase_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/profile_completion_service.dart';
import '../../../core/services/tutor_onboarding_progress_service.dart';
import '../../../core/services/notification_helper_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/models/profile_completion.dart';
import '../../../core/widgets/profile_completion_widget.dart';
import '../../../features/notifications/widgets/notification_bell.dart';
import '../../../features/booking/services/session_payment_service.dart';
import '../widgets/onboarding_progress_tracker.dart';
import 'tutor_admin_feedback_screen.dart';
import '../../group_classes/screens/tutor_group_classes_screen.dart';
import 'tutor_onboarding_screen.dart';
import 'tutor_earnings_screen.dart';
import '../../../core/widgets/skeletons/tutor_home_skeleton.dart';
import '../../../features/messaging/screens/conversations_list_screen.dart';
import '../../../features/messaging/widgets/message_icon_badge.dart';
import '../../../core/services/notification_permission_nudge_service.dart';
import '../../../core/config/app_config.dart';
import '../../skulmate/widgets/skulmate_surface_styles.dart';
import '../widgets/tutor_dashboard_layout.dart';
import '../../payment/widgets/prepskul_wallet_card.dart';

class TutorHomeScreen extends StatefulWidget {
  const TutorHomeScreen({Key? key}) : super(key: key);

  @override
  State<TutorHomeScreen> createState() => _TutorHomeScreenState();
}

class _TutorHomeScreenState extends State<TutorHomeScreen> {
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _tutorProfile;
  ProfileCompletionStatus? _completionStatus;
  bool _isLoading = true;
  String? _approvalStatus; // 'pending', 'approved', 'rejected'
  String? _adminNotes; // Admin review notes (rejection reason, etc.)
  bool _hasDismissedApprovalCard = false; // Track if user dismissed approval card
  bool _hasPendingUpdate = false; // Track if approved tutor has pending update
  bool _onboardingSkipped = false;
  bool _onboardingComplete = false;
  bool _hasSavedProgress = false; // Track if user has any saved progress
  double _activeBalance = 0.0;
  double _pendingBalance = 0.0;
  int _studentCount = 0;
  int _sessionCount = 0;
  bool _isOffline = false;
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isLoadingUserInfoRequestInFlight = false;
  bool _isCheckingOnboardingInFlight = false;
  DateTime? _lastUserInfoLoadAt;
  DateTime? _lastOnboardingCheckAt;
  static const Duration _homeRefreshCooldown = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _loadUserInfo();
    _checkDismissedApprovalCard();
    _checkOnboardingStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies can fire often due to inherited updates.
    // Throttle expensive refreshes to avoid repeated API churn/log spam.
    final now = DateTime.now();
    final recentlyRefreshed = _lastUserInfoLoadAt != null &&
        now.difference(_lastUserInfoLoadAt!) < _homeRefreshCooldown;
    if (recentlyRefreshed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkOnboardingStatus();
      _loadUserInfo();
    });
  }

  Future<void> _initializeConnectivity() async {
    await _connectivity.initialize();
    _checkConnectivity();
    _connectivity.connectivityStream.listen((isOnline) {
      if (mounted) {
        safeSetState(() {
          _isOffline = !isOnline;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.checkConnectivity();
    if (mounted) {
      safeSetState(() {
        _isOffline = !isOnline;
      });
    }
  }

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }

  Future<void> _checkOnboardingStatus() async {
    final now = DateTime.now();
    if (_isCheckingOnboardingInFlight) return;
    if (_lastOnboardingCheckAt != null &&
        now.difference(_lastOnboardingCheckAt!) < _homeRefreshCooldown) {
      return;
    }
    _isCheckingOnboardingInFlight = true;
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;
      
      final skipped = await TutorOnboardingProgressService.isOnboardingSkipped(userId);
      final complete = await TutorOnboardingProgressService.isOnboardingComplete(userId);
      
      safeSetState(() {
        _onboardingSkipped = skipped;
        _onboardingComplete = complete;
      });
      _lastOnboardingCheckAt = DateTime.now();
    } catch (e) {
      LogService.warning('Error checking onboarding status: $e');
    } finally {
      _isCheckingOnboardingInFlight = false;
    }
  }

  Future<void> _checkDismissedApprovalCard() async {
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;
      
      // Check database first (cross-device persistence)
      final tutorProfile = await SupabaseService.client
          .from('tutor_profiles')
          .select('approval_banner_dismissed')
          .eq('user_id', userId)
          .maybeSingle();
      
      final dismissedInDb = tutorProfile?['approval_banner_dismissed'] as bool? ?? false;
      
      // Also check SharedPreferences for immediate UI updates
      final prefs = await SharedPreferences.getInstance();
      final dismissedInPrefs = prefs.getBool('tutor_approval_card_dismissed') ?? false;
      
      // Use database value (more reliable, cross-device)
      // But if SharedPreferences says dismissed and DB doesn't, sync to DB
      final isDismissed = dismissedInDb || dismissedInPrefs;
      
      if (dismissedInPrefs && !dismissedInDb) {
        // Sync SharedPreferences to database
        await _syncDismissalToDatabase(userId, true);
      }
      
      safeSetState(() {
        _hasDismissedApprovalCard = isDismissed;
      });
    } catch (e) {
      LogService.warning('Error checking dismissed approval card: $e');
      // Fallback to SharedPreferences only
      final prefs = await SharedPreferences.getInstance();
      safeSetState(() {
        _hasDismissedApprovalCard = prefs.getBool('tutor_approval_card_dismissed') ?? false;
      });
    }
  }

  Future<void> _syncDismissalToDatabase(String userId, bool dismissed) async {
    try {
      await SupabaseService.client
          .from('tutor_profiles')
          .update({'approval_banner_dismissed': dismissed})
          .eq('user_id', userId);
    } catch (e) {
      LogService.warning('Error syncing dismissal to database: $e');
      // Don't fail if database update fails
    }
  }

  Future<void> _dismissApprovalCard() async {
    // Optimistically update UI first for immediate feedback
    safeSetState(() {
      _hasDismissedApprovalCard = true;
    });

    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;
      
      // Save to SharedPreferences (immediate UI)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutor_approval_card_dismissed', true);
      
      // Sync to database for cross-device persistence (fire and forget)
      _syncDismissalToDatabase(userId, true);
    } catch (e) {
      LogService.warning('Error dismissing approval card: $e');
      // UI is already updated, so user experience is preserved
    }
  }

  Future<void> _loadUserInfo() async {
    final now = DateTime.now();
    if (_isLoadingUserInfoRequestInFlight) return;
    if (_lastUserInfoLoadAt != null &&
        now.difference(_lastUserInfoLoadAt!) < _homeRefreshCooldown) {
      return;
    }
    _isLoadingUserInfoRequestInFlight = true;
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Load fresh profile data from database to get updated name
      final profileResponse = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      // Get updated name from database (most up-to-date)
      final fullName = profileResponse?['full_name']?.toString() ?? 
          user['fullName']?.toString() ?? 'Tutor';

      // Load tutor profile data (this includes saved onboarding progress)
      final tutorData = await SurveyRepository.getTutorSurvey(userId);
      
      // Also load onboarding progress to check status
      final onboardingProgress = await TutorOnboardingProgressService.loadProgress(userId);
      final onboardingSkipped = await TutorOnboardingProgressService.isOnboardingSkipped(userId);
      final onboardingComplete = await TutorOnboardingProgressService.isOnboardingComplete(userId);
      
      // Check if user has any saved progress (has step_data or completed_steps)
      final hasProgress = onboardingProgress != null && 
          ((onboardingProgress['step_data'] as Map? ?? {}).isNotEmpty ||
           (onboardingProgress['completed_steps'] as List? ?? []).isNotEmpty);

      // Calculate completion status
      ProfileCompletionStatus? status;
      if (tutorData != null) {
        status = ProfileCompletionService.calculateTutorCompletion(tutorData);
      }

      // Check if approval status changed (reset dismissal ONLY if status actually changed from non-approved to approved)
      final newApprovalStatus = tutorData?['status'] as String?;
      final adminNotes = tutorData?['admin_review_notes'] as String?;
      final hasPendingUpdate = tutorData?['has_pending_update'] as bool? ?? false;
      
      // Check dismissal status from database (cross-device)
      final tutorProfileCheck = await SupabaseService.client
          .from('tutor_profiles')
          .select('approval_banner_dismissed')
          .eq('user_id', userId)
          .maybeSingle();
      final wasDismissedInDb = tutorProfileCheck?['approval_banner_dismissed'] as bool? ?? false;
      
      // Also check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final wasDismissedInPrefs = prefs.getBool('tutor_approval_card_dismissed') ?? false;
      // Respect local state if it's already true (e.g. user just dismissed it in this session)
      final wasDismissed = wasDismissedInDb || wasDismissedInPrefs || _hasDismissedApprovalCard;
      
      // Only reset dismissal if:
      // 1. Status is now 'approved' AND
      // 2. Previous status was NOT 'approved' (actual status change) AND
      // 3. User had previously dismissed it
      if (newApprovalStatus == 'approved' && 
          _approvalStatus != null && 
          _approvalStatus != 'approved' && 
          wasDismissed) {
        // Status changed from non-approved to approved - reset dismissal in both places
        await prefs.setBool('tutor_approval_card_dismissed', false);
        await _syncDismissalToDatabase(userId, false);
        _hasDismissedApprovalCard = false;
      } else if (newApprovalStatus == 'approved' && wasDismissed) {
        // Status is approved and was dismissed - keep it dismissed
        _hasDismissedApprovalCard = true;
      }

      // Load wallet balances if tutor is approved
      double activeBalance = 0.0;
      double pendingBalance = 0.0;
      if (newApprovalStatus == 'approved') {
        try {
          final balances = await SessionPaymentService.getTutorWalletBalances(userId);
          activeBalance = (balances['active_balance'] as num).toDouble();
          pendingBalance = (balances['pending_balance'] as num).toDouble();
          final offlineEarnings =
              (balances['offline_earnings_xaf'] as num?)?.toDouble() ?? 0.0;
          activeBalance += offlineEarnings;
        } catch (e) {
          LogService.warning('Error loading wallet balances: $e');
          // Don't fail user info loading if wallet fails
        }
      }

      // Load Quick Stats (students and sessions) for approved tutors
      int studentCount = 0;
      int sessionCount = 0;
      if (newApprovalStatus == 'approved') {
        try {
          final stats = await _loadTutorQuickStats(userId);
          studentCount = stats['students'] as int;
          sessionCount = stats['sessions'] as int;
        } catch (e) {
          LogService.warning('Error loading tutor quick stats: $e');
        }
      }

      safeSetState(() {
        _userInfo = {
          ...user,
          'fullName': fullName, // Use updated name from database
        };
        _tutorProfile = tutorData;
        _completionStatus = status;
        _approvalStatus = newApprovalStatus;
        _adminNotes = adminNotes;
        _hasPendingUpdate = hasPendingUpdate;
        _onboardingSkipped = onboardingSkipped;
        _onboardingComplete = onboardingComplete;
        _hasSavedProgress = hasProgress;
        _activeBalance = activeBalance;
        _pendingBalance = pendingBalance;
        _studentCount = studentCount;
        _sessionCount = sessionCount;
        _isLoading = false;
      });
      _lastUserInfoLoadAt = DateTime.now();

      // LinkedIn-style nudge: ask on home once user lands (avoid onboarding screens).
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            NotificationPermissionNudgeService.maybeShow(
              context,
              trigger: 'home',
            );
          });
        });
      }
      
      // Send notification if onboarding is incomplete (only once per day)
      if (onboardingSkipped || !onboardingComplete) {
        _checkAndSendOnboardingNotification();
      }
    } catch (e) {
      LogService.debug('Error loading user info: $e');
      safeSetState(() {
        _isLoading = false;
      });
    } finally {
      _isLoadingUserInfoRequestInFlight = false;
    }
  }

  /// Check and send onboarding notification if needed
  Future<void> _checkAndSendOnboardingNotification() async {
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;
      
      // Verify user is actually a tutor before sending notification
      final userRole = await AuthService.getUserRole();
      if (userRole != 'tutor') {
        LogService.debug('Skipping onboarding notification for non-tutor user: $userId (role: $userRole)');
        return;
      }
      
      // Check if onboarding is incomplete or skipped
      final onboardingSkipped = await TutorOnboardingProgressService.isOnboardingSkipped(userId);
      final onboardingComplete = await TutorOnboardingProgressService.isOnboardingComplete(userId);
      
      if (onboardingSkipped || !onboardingComplete) {
        // Check if we've already sent this notification today (avoid spam)
        final prefs = await SharedPreferences.getInstance();
        final lastNotificationDate = prefs.getString('onboarding_notification_date');
        final today = DateTime.now().toIso8601String().split('T')[0];
        
        if (lastNotificationDate != today) {
          // Get next missing stage for stage-specific messaging (optional)
          final stage = await TutorOnboardingProgressService.getNextMissingStage(userId);
          final title = 'Complete Your Profile to Get Verified';
          final message = onboardingSkipped
              ? 'Your profile isn\'t visible to students yet. Complete your onboarding to get verified and start connecting with students who match your expertise.'
              : 'Finish your profile setup to get verified and start connecting with students who need your expertise. Complete your onboarding to become visible and start teaching.';
          await NotificationHelperService.sendOnboardingReminder(
            userId: userId,
            title: title,
            message: message,
            actionUrl: '/tutor-onboarding',
            metadata: {
              'onboarding_skipped': onboardingSkipped,
              'onboarding_complete': onboardingComplete,
              if (stage != null) 'reminder_stage': stage,
            },
          );
          await prefs.setString('onboarding_notification_date', today);
          LogService.success('Onboarding notification sent to tutor: $userId');
        }
      }
    } catch (e) {
      LogService.warning('Error sending onboarding notification: $e');
      // Don't block the UI if notification fails
    }
  }

  /// Extract first name from full name
  String _getFirstName(String fullName) {
    if (fullName.isEmpty || fullName == 'Tutor') return fullName;
    // Split by space and take the first part
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : fullName;
  }

  /// Load combined on + off platform student and session counts from tutor_profiles.
  Future<Map<String, int>> _loadTutorQuickStats(String userId) async {
    final supabase = SupabaseService.client;

    try {
      final profile = await supabase
          .from('tutor_profiles')
          .select('total_sessions_completed, total_students')
          .eq('user_id', userId)
          .maybeSingle();

      return {
        'students': (profile?['total_students'] as num?)?.toInt() ?? 0,
        'sessions': (profile?['total_sessions_completed'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      LogService.warning('Tutor quick stats: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _userInfo?['fullName'] != null
                ? 'Hi, ${_getFirstName(_userInfo!['fullName'] as String)}'
                : 'PrepSkul',
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
              child: const NotificationBell(),
            ),
          ],
        ),
        body: _isLoading
          ? const TutorHomeSkeleton()
          : RefreshIndicator(
              onRefresh: _loadUserInfo,
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                ResponsiveHelper.responsiveHorizontalPadding(context),
                ResponsiveHelper.responsiveVerticalPadding(context),
                ResponsiveHelper.responsiveHorizontalPadding(context),
                ResponsiveHelper.responsiveVerticalPadding(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Onboarding Progress Tracker
                  // Show ONLY if: (skipped OR has saved progress) AND not yet submitted
                  // Hide after submission - only show Profile Completion widget then
                  if ((_onboardingSkipped || _hasSavedProgress) && !_onboardingComplete && !_isOffline)
                    OnboardingProgressTracker(
                      userId: _userInfo?['userId'] as String? ?? '',
                      key: ValueKey('onboarding_tracker_${_onboardingSkipped}_${_onboardingComplete}_${_hasSavedProgress}_${DateTime.now().millisecondsSinceEpoch}'),
                    ),

                  if ((_onboardingSkipped || _hasSavedProgress) && !_onboardingComplete && !_isOffline)
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                    
                  // Review & Submit Button (only when all steps complete but not yet submitted)
                  // Hide this button after submission - user should see Profile Completion widget instead
                  // If _approvalStatus is not null, it means profile has been submitted (pending/approved/rejected/etc)
                  if (_onboardingComplete && !_onboardingSkipped && _approvalStatus == null)
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/tutor-onboarding',
                              arguments: {
                                'userId': _userInfo?['userId'],
                                'existingData': _tutorProfile,
                              },
                            ).then((_) {
                              // Reload after returning
                              _loadUserInfo();
                              _checkOnboardingStatus();
                            });
                          },
                          icon: Icon(Icons.arrow_forward, size: ResponsiveHelper.responsiveIconSize(context, mobile: 18, tablet: 20, desktop: 22)),
                          label: Text(
                            'Review & Submit Application',
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 14, tablet: 16, desktop: 18)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                    ),

                  if (_onboardingComplete && !_onboardingSkipped)
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),

                  // Profile Completion Banner (if not complete)
                  // Hide when: 100% complete AND approved
                  // Show when: Not complete OR (complete but not approved)
                  Builder(
                    builder: (context) {
                      final shouldShowCompletionCard =
                          _completionStatus != null &&
                          (!_completionStatus!.isComplete ||
                              (_completionStatus!.isComplete &&
                                  _approvalStatus != 'approved'));

                      if (!shouldShowCompletionCard) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          ProfileCompletionBanner(
                            status: _completionStatus!,
                            onTap: () {
                              // Navigate back to onboarding to complete profile
                              Navigator.of(context)
                                  .pushNamed(
                                    '/tutor-onboarding',
                                    arguments: {
                                      'userId': _userInfo?['userId'],
                                      'existingData': _tutorProfile,
                                    },
                                  )
                                  .then(
                                    (_) => _loadUserInfo(),
                                  ); // Reload after returning
                            },
                          ),
                          SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                          // Profile Completion Details
                          ProfileCompletionWidget(
                            status: _completionStatus!,
                            showDetails: true,
                            onEditSection: () {
                              // Navigate to onboarding to edit
                              Navigator.of(context)
                                  .pushNamed(
                                    '/tutor-onboarding',
                                    arguments: {
                                      'userId': _userInfo?['userId'],
                                      'existingData': _tutorProfile,
                                    },
                                  )
                                  .then((_) => _loadUserInfo());
                            },
                          ),
                          SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                        ],
                      );
                    },
                  ),

                  // Approval Status Card
                  // Show if:
                  // 1. Status is 'approved' AND not dismissed (don't show if pending update - notification sent instead), OR
                  // 2. Profile is complete AND status exists (and not approved), OR
                  // 3. Status is 'needs_improvement', 'rejected', 'blocked', or 'suspended'
                  if ((_approvalStatus == 'approved' && !_hasDismissedApprovalCard && !_hasPendingUpdate) ||
                      (_completionStatus?.isComplete == true &&
                          _approvalStatus != null &&
                          _approvalStatus != 'approved') ||
                      (_approvalStatus == 'needs_improvement' ||
                          _approvalStatus == 'rejected' ||
                          _approvalStatus == 'blocked' ||
                          _approvalStatus == 'suspended'))
                    _buildApprovalStatusCard(),

                  if ((_approvalStatus == 'approved' && !_hasDismissedApprovalCard && !_hasPendingUpdate) ||
                      (_completionStatus?.isComplete == true &&
                          _approvalStatus != null &&
                          _approvalStatus != 'approved') ||
                      (_approvalStatus == 'needs_improvement' ||
                          _approvalStatus == 'rejected' ||
                          _approvalStatus == 'blocked' ||
                          _approvalStatus == 'suspended'))
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),

                  // PrepSkul Wallet Section
                  // Show wallet for approved tutors (even with pending update)
                  if (_approvalStatus == 'approved' && _hasDismissedApprovalCard) ...[
                    _buildWalletSection(),
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                  ],

                  const TutorZSection(title: 'Quick Stats'),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Students',
                          '$_studentCount',
                          Icons.people,
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
                          'Sessions',
                          '$_sessionCount',
                          Icons.event,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),

                  const TutorZSection(title: 'Quick Actions'),
                  SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
                  if (ResponsiveHelper.isDesktop(context)) ...[
                    TutorZRow(
                      rowIndex: 0,
                      primary: _buildActionCard(
                        icon: Icons.inbox_outlined,
                        title: 'My Requests',
                        subtitle: 'View your booking requests',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/tutor-nav',
                            arguments: {'initialTab': 1},
                          );
                        },
                      ),
                      secondary: _buildActionCard(
                        icon: Icons.school_outlined,
                        title: 'My Sessions',
                        subtitle: 'View your tutoring sessions',
                        color: AppTheme.primaryColor,
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/tutor-nav',
                            arguments: {'initialTab': 2},
                          );
                        },
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                    TutorZRow(
                      rowIndex: 1,
                      primary: _buildActionCard(
                        icon: Icons.payment,
                        title: 'Payment History',
                        subtitle: 'View and manage your payments',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TutorEarningsScreen(),
                            ),
                          );
                        },
                      ),
                      secondary: AppConfig.enableGroupClasses
                          ? _buildActionCard(
                              icon: Icons.groups_outlined,
                              title: 'Group Classes',
                              subtitle: 'Create and publish group sessions',
                              color: Colors.deepPurple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TutorGroupClassesScreen(),
                                  ),
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ] else ...[
                    _buildActionCard(
                      icon: Icons.inbox_outlined,
                      title: 'My Requests',
                      subtitle: 'View your booking requests',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/tutor-nav',
                          arguments: {'initialTab': 1},
                        );
                      },
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
                    _buildActionCard(
                      icon: Icons.school_outlined,
                      title: 'My Sessions',
                      subtitle: 'View your tutoring sessions',
                      color: AppTheme.primaryColor,
                      onTap: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/tutor-nav',
                          arguments: {'initialTab': 2},
                        );
                      },
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
                    _buildActionCard(
                      icon: Icons.payment,
                      title: 'Payment History',
                      subtitle: 'View and manage your payments',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TutorEarningsScreen(),
                          ),
                        );
                      },
                    ),
                    if (AppConfig.enableGroupClasses) ...[
                      SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
                      _buildActionCard(
                        icon: Icons.groups_outlined,
                        title: 'Group Classes',
                        subtitle: 'Create and publish group sessions',
                        color: Colors.deepPurple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TutorGroupClassesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
            ),
      ),
    );
  }


  Widget _buildApprovalStatusCard() {
    final cardPadding = ResponsiveHelper.responsiveSpacing(context, mobile: 14, tablet: 16, desktop: 18);
    final iconSize = ResponsiveHelper.responsiveIconSize(context, mobile: 24, tablet: 28, desktop: 32);
    
    // Handle blocked/suspended status
    if (_approvalStatus == 'blocked' || _approvalStatus == 'suspended') {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.block, size: iconSize, color: Colors.red[700]),
                SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                Expanded(
                  child: Text(
                    _approvalStatus == 'blocked'
                        ? 'Account Blocked'
                        : 'Account Suspended',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveSubheadingSize(context) + 2,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
            Text(
              'Your account has been ${_approvalStatus == 'blocked' ? 'blocked' : 'suspended'}. View details for more information and to request a review.',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _viewAdminFeedback(),
                icon: Icon(Icons.visibility, size: ResponsiveHelper.responsiveIconSize(context, mobile: 18, tablet: 20, desktop: 22)),
                label: Text(
                  'View Details',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.responsiveBodySize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.responsiveHorizontalPadding(context),
                    vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Don't show pending update card - notification will be sent instead
    if (_approvalStatus == 'approved') {
      // Approved - show compact success card with dismiss button
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accentGreen,
              AppTheme.accentGreen.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: iconSize, color: Colors.white),
            SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approved!',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 1 : 2),
                  Text(
                    'Your profile is live and students can now book sessions with you.',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveBodySize(context) - 2,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: ResponsiveHelper.responsiveIconSize(context, mobile: 18, tablet: 20, desktop: 22), color: Colors.white),
              onPressed: _dismissApprovalCard,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      );
    } else if (_approvalStatus == 'needs_improvement') {
      // Needs Improvement - show compact warning card with "View Details" button
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: ResponsiveHelper.responsiveIconSize(context, mobile: 24, tablet: 26, desktop: 28), color: Colors.orange[700]),
                SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                Expanded(
                  child: Text(
                    'Profile Needs Improvement',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveSubheadingSize(context) - 1,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 6, tablet: 8, desktop: 10)),
            Text(
              'Admin has requested changes to your profile. View details to see what needs to be updated.',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.responsiveBodySize(context) - 2,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
            SizedBox(height: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _viewAdminFeedback(),
                icon: Icon(Icons.visibility, size: ResponsiveHelper.responsiveIconSize(context, mobile: 16, tablet: 18, desktop: 20)),
                label: Text(
                  'View Details',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.responsiveHorizontalPadding(context),
                    vertical: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_approvalStatus == 'rejected') {
      // Rejected - show compact error card with "View Details" button
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel, size: ResponsiveHelper.responsiveIconSize(context, mobile: 24, tablet: 26, desktop: 28), color: AppTheme.primaryColor),
                SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                Expanded(
                  child: Text(
                    'Application Rejected',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your application was not approved.${_adminNotes != null && _adminNotes!.isNotEmpty ? '\n\nReason: ${_adminNotes!.length > 100 ? "${_adminNotes!.substring(0, 100)}..." : _adminNotes}' : ''}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _viewAdminFeedback(),
                icon: const Icon(Icons.visibility, size: 16),
                label: Text(
                  'View Details',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Pending - show compact waiting card
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty, size: 32, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Approval',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your profile is being reviewed. You\'ll be notified once approved!',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _viewAdminFeedback() async {
    if (_tutorProfile == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            TutorAdminFeedbackScreen(tutorProfile: _tutorProfile!),
      ),
    );

    // Reload profile if feedback screen returned true (indicating update)
    if (result == true) {
      await _loadUserInfo();
    }
  }

  Widget _buildWalletSection() {
    return PrepSkulWalletCard(
      activeBalance: _activeBalance,
      pendingBalance: _pendingBalance,
      onViewEarnings: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TutorEarningsScreen()),
        );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cardPadding = ResponsiveHelper.responsiveSpacing(context, mobile: 14, tablet: 16, desktop: 18);
    final iconSize = ResponsiveHelper.responsiveIconSize(context, mobile: 21, tablet: 24, desktop: 26);
    final iconPadding = ResponsiveHelper.responsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(cardPadding),
        decoration: SkulMateSurfaceStyles.neumorphicCard(
          color: AppTheme.surfaceColor,
          radius: 14,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveSubheadingSize(context) - 1,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 1 : 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveBodySize(context) - 1,
                      color: AppTheme.textMedium,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios, 
              size: ResponsiveHelper.responsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18), 
              color: AppTheme.textMedium.withOpacity(0.5),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    final iconSize = ResponsiveHelper.responsiveIconSize(context, mobile: 24, tablet: 28, desktop: 32);
    final padding = ResponsiveHelper.responsiveSpacing(context, mobile: 12, tablet: 14, desktop: 16);
    final valueSize = ResponsiveHelper.isSmallHeight(context) 
        ? ResponsiveHelper.responsiveSubheadingSize(context) + 2
        : ResponsiveHelper.responsiveSubheadingSize(context) + 4;
    
    return Container(
        padding: EdgeInsets.all(padding),
        decoration: SkulMateSurfaceStyles.neumorphicCard(
          color: AppTheme.surfaceColor,
          radius: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: iconSize),
            SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 4 : 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: valueSize,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 1 : 2),
            Text(
              title,
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
}
