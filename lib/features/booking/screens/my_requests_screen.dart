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
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load trial sessions
      final trials = await TrialSessionService.getStudentTrialSessions();

      setState(() {
        _trialSessions = trials;
        _bookingRequests = [];
        _customRequests = [];
        _isLoading = false;
      });

      // Check for completed trials that haven't been converted
      // Show dialog for the first one found
      if (mounted) {
        _checkForCompletedTrials();
      }
    } catch (e) {
      print('❌ Error loading requests: $e');
      setState(() {
        _isLoading = false;
      });
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
          .select('*, profiles!inner(full_name, avatar_url)')
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
    final pendingBookingCount = _getPendingBookingRequests().length;
    final pendingCustomCount = _getPendingCustomRequests().length;
    final pendingTrialCount = _getPendingTrialSessions().length;
    final totalPending =
        pendingBookingCount + pendingCustomCount + pendingTrialCount;

    // FAB only shows in Custom Request tab (index 2) AND only when there's a pending custom request
    final showFAB = _tabController.index == 2 && pendingCustomCount > 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button in bottom nav
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Requests',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            if (totalPending > 0)
              Text(
                '$totalPending pending',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() {}), // Rebuild to show/hide FAB
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: AppTheme.primaryColor,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending Approval Request'),
            Tab(text: 'Custom Request'),
            Tab(text: 'Trial Sessions'),
            Tab(text: 'Bookings'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllRequestsTab(),
                _buildPendingRequestsTab(),
                _buildCustomRequestsTab(),
                _buildTrialSessionsTab(),
                _buildBookingsTab(),
              ],
            ),
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

  Widget _buildAllRequestsTab() {
    final allRequests = [
      ..._bookingRequests.map((r) => _RequestItem(type: 'booking', booking: r)),
      ..._customRequests.map((r) => _RequestItem(type: 'custom', custom: r)),
      ..._trialSessions.map((r) => _RequestItem(type: 'trial', trial: r)),
    ];

    if (allRequests.isEmpty) {
      return _buildRequestTutorCard(
        title: 'Request a tutor of your choice',
        subtitle:
            'Tell us what you\'re looking for and we\'ll find the perfect match for you',
        showButton: true,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: allRequests.length,
      itemBuilder: (context, index) {
        final item = allRequests[index];
        if (item.type == 'booking') {
          return _buildBookingRequestCard(item.booking!);
        } else if (item.type == 'custom') {
          return _buildCustomRequestCard(item.custom!);
        } else {
          return _buildTrialSessionCard(item.trial!);
        }
      },
    );
  }

  Widget _buildPendingRequestsTab() {
    final pendingBookings = _getPendingBookingRequests();
    final pendingCustom = _getPendingCustomRequests();
    final pendingTrials = _getPendingTrialSessions();
    final allPending = [
      ...pendingBookings.map((r) => _RequestItem(type: 'booking', booking: r)),
      ...pendingCustom.map((r) => _RequestItem(type: 'custom', custom: r)),
      ...pendingTrials.map((r) => _RequestItem(type: 'trial', trial: r)),
    ];

    if (allPending.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pending_outlined,
        title: 'No pending requests',
        subtitle: 'You\'re all caught up!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: allPending.length,
      itemBuilder: (context, index) {
        final item = allPending[index];
        if (item.type == 'booking') {
          return _buildBookingRequestCard(item.booking!);
        } else if (item.type == 'custom') {
          return _buildCustomRequestCard(item.custom!);
        } else {
          return _buildTrialSessionCard(item.trial!);
        }
      },
    );
  }

  Widget _buildCustomRequestsTab() {
    if (_customRequests.isEmpty) {
      return _buildRequestTutorCard(
        title: 'Request a tutor of your choice',
        subtitle:
            'Tell us what you\'re looking for and we\'ll find the perfect match for you',
        showButton: true,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _customRequests.length,
      itemBuilder: (context, index) {
        return _buildCustomRequestCard(_customRequests[index]);
      },
    );
  }

  Widget _buildTrialSessionsTab() {
    if (_trialSessions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.quiz_outlined,
        title: 'No trial sessions yet',
        subtitle:
            'Request a trial session from a tutor\'s profile to get started',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _trialSessions.length,
      itemBuilder: (context, index) {
        return _buildTrialSessionCard(_trialSessions[index]);
      },
    );
  }

  Widget _buildBookingsTab() {
    if (_bookingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.book_outlined,
        title: 'No booking requests yet',
        subtitle: 'Book a tutor from their profile to start regular sessions',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _bookingRequests.length,
      itemBuilder: (context, index) {
        return _buildBookingRequestCard(_bookingRequests[index]);
      },
    );
  }

  Widget _buildRequestTutorCard({
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
                padding: const EdgeInsets.all(16),
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
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildBookingRequestCard(BookingRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RequestDetailScreen(request: request.toJson()),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: request.tutorAvatarUrl != null
                        ? NetworkImage(request.tutorAvatarUrl!)
                        : null,
                    child: request.tutorAvatarUrl == null
                        ? Text(request.tutorName[0].toUpperCase())
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
                  _buildStatusChip(request.status),
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

  Widget _buildCustomRequestCard(TutorRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      'Custom Request',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(request.status),
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

  Widget _buildTrialSessionCard(TrialSession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Trial Session',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
                const Spacer(),
                _buildStatusChip(session.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              session.subject,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, session.formattedDate),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.access_time, session.formattedTime),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.timer, session.formattedDuration),
            const SizedBox(height: 4),
            _buildInfoRow(
              Icons.location_on,
              session.location == 'online' ? 'Online' : 'On-site',
            ),
            if (session.trialGoal != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.softCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goal:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.trialGoal!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${session.trialFee.toStringAsFixed(0)} XAF',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            // Show "Continue with Tutor" button for completed trials
            if (session.status == 'completed' &&
                !session.convertedToRecurring) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Fetch tutor data and show conversion screen
                    try {
                      final supabase = Supabase.instance.client;
                      final tutorData = await supabase
                          .from('tutor_profiles')
                          .select('*, profiles!inner(full_name, avatar_url)')
                          .eq('user_id', session.tutorId)
                          .single();

                      if (!mounted) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostTrialConversionScreen(
                            trialSession: session,
                            tutor: {
                              ...tutorData,
                              'user_id': session.tutorId,
                              'id': session.tutorId,
                              'full_name':
                                  tutorData['profiles']?['full_name'] ??
                                  'Tutor',
                            },
                          ),
                        ),
                      ).then((_) {
                        // Refresh after conversion
                        _loadRequests();
                      });
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Continue with Tutor',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
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
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        chipColor = Colors.orange;
        label = 'Pending';
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

  Widget _buildEmptyState({
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
}
// Helper class to combine different request types
class _RequestItem {
  final String type; // 'booking', 'custom', 'trial'
  final BookingRequest? booking;
  final TutorRequest? custom;
  final TrialSession? trial;

  _RequestItem({required this.type, this.booking, this.custom, this.trial});
}

