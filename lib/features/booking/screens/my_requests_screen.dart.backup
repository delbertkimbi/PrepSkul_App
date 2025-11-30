import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/booking/models/tutor_request_model.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/screens/request_tutor_flow_screen.dart';
import 'package:prepskul/features/booking/screens/request_detail_screen.dart';
import 'package:prepskul/features/booking/widgets/post_trial_dialog.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:prepskul/features/booking/screens/post_trial_conversion_screen.dart';
import 'package:prepskul/features/booking/screens/trial_payment_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/services/tutor_request_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../../../core/localization/app_localizations.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Cache tutor info for trial sessions
  final Map<String, Map<String, dynamic>> _tutorInfoCache = {};

  Future<void> _loadRequests() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Load booking requests
      final userId = SupabaseService.currentUser?.id;
      List<BookingRequest> bookingRequests = [];
      if (userId != null) {
        try {
          bookingRequests = await BookingService.getStudentBookingRequests(userId);
          print('✅ Loaded ${bookingRequests.length} booking requests');
        } catch (e) {
          print('❌ Error loading booking requests: $e');
        }
      }

      // Load tutor custom requests
      List<TutorRequest> customRequests = [];
      try {
        customRequests = await TutorRequestService.getUserRequests();
        print('✅ Loaded ${customRequests.length} custom requests');
      } catch (e) {
        print('❌ Error loading custom requests: $e');
      }

      // Load trial sessions - force fresh fetch
      // Add timestamp to cache bust and ensure fresh data
      final trials = await TrialSessionService.getStudentTrialSessions();
      print('✅ Loaded ${trials.length} trial sessions');
      // Debug: Log payment statuses
      for (var trial in trials) {
        print('🔍 Trial ${trial.id}: status=${trial.status}, paymentStatus=${trial.paymentStatus}');
      }

      // Load tutor info for all trials
      await _loadTutorInfoForTrials(trials);

      if (!mounted) return;

      setState(() {
        _trialSessions = trials;
        _bookingRequests = bookingRequests;
        _customRequests = customRequests;
        _isLoading = false;
      });

      // Check for completed trials that haven't been converted
      // Show dialog for the first one found
      if (mounted) {
        _checkForCompletedTrials();
      }
    } catch (e) {
      print('❌ Error loading requests: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Force refresh a specific trial session after payment
  Future<void> _refreshTrialSession(String sessionId) async {
    try {
      print('🔄 Starting refresh for trial session: $sessionId');
      
      // Directly fetch the trial session from DB to get latest payment_status
      final response = await SupabaseService.client
          .from('trial_sessions')
          .select('*, payment_status, fapshi_trans_id, status')
          .eq('id', sessionId)
          .single();
      
      if (response != null) {
        // Log raw DB values for debugging
        final rawPaymentStatus = response['payment_status']?.toString() ?? 'null';
        final rawStatus = response['status']?.toString() ?? 'null';
        print('🔍 DB raw values - payment_status: $rawPaymentStatus, status: $rawStatus');
        
        final updatedTrial = TrialSession.fromJson(response);
        print('🔄 Refreshed trial $sessionId: paymentStatus=${updatedTrial.paymentStatus}, status=${updatedTrial.status}');
        
        // Update in the list
        final index = _trialSessions.indexWhere((t) => t.id == sessionId);
        if (index != -1 && mounted) {
          final oldPaymentStatus = _trialSessions[index].paymentStatus;
          setState(() {
            _trialSessions[index] = updatedTrial;
          });
          print('✅ Updated trial in UI: $oldPaymentStatus → ${updatedTrial.paymentStatus}');
        } else if (index == -1) {
          print('⚠️ Trial session not found in list, reloading all requests...');
          if (mounted) await _loadRequests();
        }
      } else {
        print('⚠️ No response from DB for trial session: $sessionId');
        if (mounted) await _loadRequests();
      }
    } catch (e, stackTrace) {
      print('❌ Error refreshing trial session: $e');
      print('❌ Stack trace: $stackTrace');
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
          .single();

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
      print('❌ Error fetching tutor data: $e');
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

        print('🔍 Loaded ${tutorProfiles.length} tutor profiles for trials');

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
        print('⚠️ Error loading tutor info with relationship join: $e');
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

            print(
              '✅ Cached tutor info (fallback) for $tutorId: ${_tutorInfoCache[tutorId]?['full_name']}',
            );
          } catch (e2) {
            print('⚠️ Error loading tutor info for $tutorId: $e2');
          }
        }
      }

      // Trigger rebuild to show loaded tutor info
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('⚠️ Error loading tutor info for trials: $e');
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

    // FAB only shows in Custom Request tab (index 2) AND only when there's a pending custom request
    final showFAB = _selectedFilter == 'custom' && pendingCustomCount > 0;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button in bottom nav
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          t.myRequestsTitle,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildFilterChip(context, 'all', t.myRequestsFilterAll),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'pending', t.myRequestsFilterPending),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'custom', t.myRequestsFilterCustom),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'trial', t.myRequestsFilterTrial),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'booking', t.myRequestsFilterBooking),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSelectedTabContent(context, _selectedFilter),
      floatingActionButton: showFAB
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RequestTutorFlowScreen(),
                  ),
                ).then((_) => _loadRequests()); // Refresh after returning
              },
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Request Another Tutor',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAllRequestsTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final allRequests = [
      ..._bookingRequests.map((r) => _RequestItem(type: 'booking', booking: r)),
      ..._customRequests.map((r) => _RequestItem(type: 'custom', custom: r)),
      ..._trialSessions.map((r) => _RequestItem(type: 'trial', trial: r)),
    ];

    if (allRequests.isEmpty) {
      return _buildRequestTutorCard(context, 
        title: t.myRequestsEmptyTitle,
        subtitle:
            'Tell us what you\'re looking for and we\'ll find the perfect match for you',
        showButton: true,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: allRequests.length,
      itemBuilder: (ctx, index) {
        final item = allRequests[index];
        if (item.type == 'booking') {
          return _buildBookingRequestCard(context, item.booking!);
        } else if (item.type == 'custom') {
          return _buildCustomRequestCard(context, item.custom!);
        } else {
          return _buildTrialSessionCard(context, item.trial!);
        }
      },
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
        if (item.type == 'booking') {
          return _buildBookingRequestCard(context, item.booking!);
        } else if (item.type == 'custom') {
          return _buildCustomRequestCard(context, item.custom!);
        } else {
          return _buildTrialSessionCard(context, item.trial!);
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
        return _buildCustomRequestCard(context, _customRequests[index]);
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
        return _buildTrialSessionCard(context, _trialSessions[index]);
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
        return _buildBookingRequestCard(context, _bookingRequests[index]);
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
                      ).then((_) => _loadRequests());
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(
                      'Request a Tutor',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
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

  Widget _buildBookingRequestCard(BuildContext context, BookingRequest request) {
    return _buildNeomorphicCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
    final t = AppLocalizations.of(context)!;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RequestDetailScreen(request: request.toJson()),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage:
                        request.tutorAvatarUrl != null &&
                            request.tutorAvatarUrl!.isNotEmpty
                        ? NetworkImage(request.tutorAvatarUrl!)
                        : null,
                    onBackgroundImageError:
                        request.tutorAvatarUrl != null &&
                            request.tutorAvatarUrl!.isNotEmpty
                        ? (exception, stackTrace) {
                            // Image failed to load, will show fallback
                          }
                        : null,
                    child:
                        request.tutorAvatarUrl == null ||
                            request.tutorAvatarUrl!.isEmpty
                        ? Text(
                            request.tutorName.isNotEmpty
                                ? request.tutorName[0].toUpperCase()
                                : 'T',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
                          request.tutorName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          request.tutorRating.toStringAsFixed(1) + ' ⭐',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(context, request.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.school, request.getDaysSummary()),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.access_time, request.getTimeRange()),
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.location_on,
                request.location == 'online'
                    ? 'Online'
                    : request.address ?? 'On-site',
              ),
              const SizedBox(height: 8),
              Text(
                '${request.monthlyTotal.toStringAsFixed(0)} XAF/month',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomRequestCard(BuildContext context, TutorRequest request) {
    final t = AppLocalizations.of(context)!;
    return _buildNeomorphicCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.myRequestsFilterCustom,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(context, request.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.formattedSubjects,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.school, request.educationLevel),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.access_time, request.formattedDays),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.location_on, request.location),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.attach_money, request.formattedBudget),
              if (request.urgency != 'normal') ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      request.urgency == 'urgent'
                          ? Icons.priority_high
                          : Icons.schedule,
                      size: 16,
                      color: request.urgency == 'urgent'
                          ? Colors.red
                          : Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request.urgencyLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: request.urgency == 'urgent'
                            ? Colors.red
                            : Colors.blue,
                        fontWeight: FontWeight.w600,
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

  Widget _buildTrialSessionCard(BuildContext context, TrialSession session) {
    // Get tutor info from cache
    final tutorInfo = _tutorInfoCache[session.tutorId] ?? {};
    final t = AppLocalizations.of(context)!;
    final tutorName = tutorInfo['full_name'] ?? 'Tutor';
    final tutorAvatarUrl = tutorInfo['avatar_url'];
    final tutorRating = (tutorInfo['rating'] ?? 0.0) as double;

    return _buildNeomorphicCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to detailed trial session view if needed
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: badge + status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.myRequestsTrialSession,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(context, session.status),
                ],
              ),
              const SizedBox(height: 12),

              // Tutor info
              Row(
                children: [
                  ClipOval(
                    child: tutorAvatarUrl != null && tutorAvatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: tutorAvatarUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 48,
                              height: 48,
                              color: AppTheme.primaryColor,
                              child: Center(
                                child: Text(
                                  tutorName.isNotEmpty
                                      ? tutorName[0].toUpperCase()
                                      : 'T',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 48,
                              height: 48,
                              color: AppTheme.primaryColor,
                              child: Center(
                                child: Text(
                                  tutorName.isNotEmpty
                                      ? tutorName[0].toUpperCase()
                                      : 'T',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: AppTheme.primaryColor,
                            child: Center(
                              child: Text(
                                tutorName.isNotEmpty
                                    ? tutorName[0].toUpperCase()
                                    : 'T',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutorName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tutorRating > 0
                                  ? tutorRating.toStringAsFixed(1)
                                  : 'N/A',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Session details
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildInlineInfo(
                    Icons.calendar_today,
                    session.formattedDate,
                  ),
                  _buildInlineInfo(
                    Icons.access_time,
                    session.formattedTime,
                  ),
                  _buildInlineInfo(
                    Icons.timer,
                    session.formattedDuration,
                  ),
                  _buildInlineInfo(
                    Icons.location_on,
                    session.location == 'online' ? 'Online' : 'On-site',
                  ),
                ],
              ),

              if (session.trialGoal != null &&
                  session.trialGoal!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  session.trialGoal!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textDark,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${session.trialFee.toStringAsFixed(0)} XAF',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  _buildPaymentStatusBadge(context, session),
                ],
              ),

              // Simple Pay Now button (only when approved/scheduled, not paid, and session hasn't passed)
              // Check if session date/time has passed - calculate inline to avoid variable declaration in widget tree
              if ((session.status == 'approved' ||
                      session.status == 'scheduled') &&
                  session.paymentStatus.toLowerCase() != 'paid' &&
                  session.paymentStatus.toLowerCase() != 'completed' &&
                  !_getSessionDateTime(session).isBefore(DateTime.now())) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TrialPaymentScreen(trialSession: session),
                        ),
                      );

                      // Always refresh after returning from payment screen
                      // Increase delay to ensure DB update propagates
                      await Future.delayed(
                        const Duration(milliseconds: 3000),
                      );

                      if (!mounted) return;
                      
                      // Force refresh the specific session first
                      await _refreshTrialSession(session.id);
                      
                      // Then reload all requests to ensure consistency
                      await _loadRequests();
                      
                      // Force UI rebuild
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      t.myRequestsPayNow,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
        await TrialSessionService.deleteTrialSession(sessionId);

        if (!mounted) return;

        // Remove from local list immediately for instant UI update
        // Find the session first to get tutorId for cache cleanup
        final sessionToDelete = _trialSessions.firstWhere(
          (s) => s.id == sessionId,
        );
        final tutorId = sessionToDelete.tutorId;

        setState(() {
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
        setState(() {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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

  Widget _buildStatusChip(BuildContext context, String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
            ),
          ),
        ),
      ],
    );
  }


  /// Neomorphic card container with soft shadows
  Widget _buildNeomorphicCard({required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Light shadow (top-left)
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            offset: const Offset(-6, -6),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          // Dark shadow (bottom-right)
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(6, 6),
            blurRadius: 12,
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
        setState(() {
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
