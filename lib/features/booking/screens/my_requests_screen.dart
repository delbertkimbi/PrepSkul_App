import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:prepskul/features/booking/services/tutor_request_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/models/tutor_request_model.dart';

/// MyRequestsScreen
///
/// Shows all booking requests made by student/parent
/// Status: pending, approved, rejected, modified
/// Beautiful cards with status indicators
/// Tap to view full details
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({Key? key}) : super(key: key);

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<BookingRequest> _regularRequests = [];
  List<TrialSession> _trialRequests = [];
  List<TutorRequest> _tutorRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // 5 tabs now
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      // Load regular, trial, and tutor requests
      final regularReqs = await BookingService.getStudentRequests();
      final trialReqs = await TrialSessionService.getStudentTrialSessions();
      final tutorReqs = await TutorRequestService.getUserRequests();

      setState(() {
        _regularRequests = regularReqs;
        _trialRequests = trialReqs;
        _tutorRequests = tutorReqs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getFilteredRequests(String status) {
    List<dynamic> combined = [];

    if (status == 'all') {
      combined.addAll(_regularRequests);
      combined.addAll(_trialRequests);
      combined.addAll(_tutorRequests);
    } else if (status == 'trial') {
      combined.addAll(_trialRequests);
    } else if (status == 'custom') {
      combined.addAll(_tutorRequests);
    } else {
      // Filter regular requests by status
      combined.addAll(_regularRequests.where((req) => req.status == status));
      // Also filter trial requests by status
      combined.addAll(_trialRequests.where((trial) => trial.status == status));
      // Also filter tutor requests by status
      combined.addAll(_tutorRequests.where((req) => req.status == status));
    }

    // Sort by creation date (newest first)
    combined.sort((a, b) {
      final aDate = a is BookingRequest
          ? a.createdAt
          : a is TrialSession
          ? (a as TrialSession).createdAt
          : (a as TutorRequest).createdAt;
      final bDate = b is BookingRequest
          ? b.createdAt
          : b is TrialSession
          ? (b as TrialSession).createdAt
          : (b as TutorRequest).createdAt;
      return bDate.compareTo(aDate);
    });

    return combined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false, // No back button in bottom nav
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Requests',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Trial'),
            Tab(text: 'Custom'),
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList('all'),
                _buildRequestsList('trial'),
                _buildRequestsList('custom'),
                _buildRequestsList('pending'),
                _buildRequestsList('approved'),
              ],
            ),
    );
  }

  Widget _buildRequestsList(String status) {
    final requests = _getFilteredRequests(status);

    if (requests.isEmpty) {
      return _buildEmptyState(status);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return _buildRequestCard(requests[index]);
      },
    );
  }

  Widget _buildEmptyState(String status) {
    String message;
    IconData icon;

    switch (status) {
      case 'trial':
        message = 'No trial sessions yet';
        icon = Icons.science_outlined;
        break;
      case 'pending':
        message = 'No pending requests';
        icon = Icons.access_time;
        break;
      case 'approved':
        message = 'No approved requests yet';
        icon = Icons.check_circle_outline;
        break;
      default:
        message = 'No requests yet';
        icon = Icons.inbox_outlined;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == 'all' || status == 'custom') ...[
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
                      'Looking for a tutor?',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Request a custom tutor and we\'ll find the perfect match for you',
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
                          // Navigate to Find Tutors tab (index 1)
                          Navigator.pushReplacementNamed(
                            context,
                            '/student-nav',
                            arguments: {'initialTab': 1},
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
            ] else ...[
              Icon(icon, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    // Handle BookingRequest, TrialSession, and TutorRequest
    final bool isTrial = request is TrialSession;
    final bool isCustom = request is TutorRequest;

    final String status;
    if (isTrial) {
      status = (request as TrialSession).status;
    } else if (isCustom) {
      status = (request as TutorRequest).status;
    } else {
      status = (request as BookingRequest).status;
    }

    final String tutorName = isTrial
        ? 'Demo Tutor' // Trial sessions use user ID as tutor in demo mode
        : isCustom
        ? 'Tutor Request'
        : (request as BookingRequest).tutorName;

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Session type badge + status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isTrial
                      ? Colors.purple.withOpacity(0.1)
                      : isCustom
                      ? Colors.orange.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTrial
                          ? Icons.science_outlined
                          : isCustom
                          ? Icons.person_search_rounded
                          : Icons.repeat,
                      size: 16,
                      color: isTrial
                          ? Colors.purple
                          : isCustom
                          ? Colors.orange
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTrial
                          ? 'Trial Session'
                          : isCustom
                          ? 'Custom Tutor'
                          : 'Regular Booking',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isTrial
                            ? Colors.purple
                            : isCustom
                            ? Colors.orange
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tutor info with avatar
          Row(
            children: [
              // Tutor Avatar
              if (!isCustom) ...[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isTrial
                      ? Colors.purple.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  backgroundImage: isTrial
                      ? null
                      : (request as BookingRequest).tutorAvatarUrl != null
                          ? NetworkImage((request as BookingRequest).tutorAvatarUrl!)
                          : null,
                  child: isTrial
                      ? Icon(Icons.science, color: Colors.purple, size: 24)
                      : (request as BookingRequest).tutorAvatarUrl == null
                          ? Icon(Icons.person, color: AppTheme.primaryColor, size: 24)
                          : null,
                ),
                const SizedBox(width: 12),
              ],
              // Tutor Name
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
                    if (isTrial)
                      Text(
                        'Try before you commit!',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.purple,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details based on type
          if (isTrial) ...{
            _buildDetailRow(
              Icons.calendar_today_outlined,
              'Date',
              (request as TrialSession).formattedDate,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.access_time_outlined,
              'Time',
              (request as TrialSession).formattedTime,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.hourglass_empty_outlined,
              'Duration',
              (request as TrialSession).formattedDuration,
            ),
            if ((request as TrialSession).subject != null) ...{
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.book_outlined,
                'Subject',
                (request as TrialSession).subject!,
              ),
            },
          } else if (isCustom) ...{
            _buildDetailRow(
              Icons.book_outlined,
              'Subjects',
              (request as TutorRequest).formattedSubjects,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.school_outlined,
              'Level',
              (request as TutorRequest).educationLevel,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.payments_outlined,
              'Budget',
              (request as TutorRequest).formattedBudget,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.location_on_outlined,
              'Location',
              (request as TutorRequest).location,
            ),
            if ((request as TutorRequest).urgency != 'normal') ...{
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.priority_high_outlined,
                'Urgency',
                (request as TutorRequest).urgencyLabel,
              ),
            },
          } else ...{
            _buildDetailRow(
              Icons.repeat,
              'Frequency',
              '${(request as BookingRequest).frequency}x per week',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.calendar_month_outlined,
              'Days',
              (request as BookingRequest).days.join(', '),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.location_on_outlined,
              'Location',
              (request as BookingRequest).location.toUpperCase(),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.payments_outlined,
              'Payment',
              '${(request as BookingRequest).monthlyTotal.toStringAsFixed(0)} XAF/${(request as BookingRequest).paymentPlan}',
            ),
          },
          const SizedBox(height: 12),

          // Created date
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                'Created ${_formatDate(isTrial
                    ? (request as TrialSession).createdAt
                    : isCustom
                    ? (request as TutorRequest).createdAt
                    : (request as BookingRequest).createdAt)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'matched':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.block;
      case 'in_progress':
        return Icons.pending_actions;
      case 'matched':
        return Icons.check_circle;
      case 'closed':
        return Icons.block;
      default:
        return Icons.info;
    }
  }
}
