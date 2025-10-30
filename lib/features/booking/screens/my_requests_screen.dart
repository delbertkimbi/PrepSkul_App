import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/screens/request_detail_screen.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      // Load both regular and trial requests
      final regularReqs = await BookingService.getStudentRequests();
      final trialReqs = await TrialSessionService.getStudentTrialSessions();

      setState(() {
        _regularRequests = regularReqs;
        _trialRequests = trialReqs;
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
    } else if (status == 'trial') {
      combined.addAll(_trialRequests);
    } else {
      // Filter regular requests by status
      combined.addAll(
        _regularRequests.where((req) => req.status == status),
      );
      // Also filter trial requests by status
      combined.addAll(
        _trialRequests.where((trial) => trial.status == status),
      );
    }

    // Sort by creation date (newest first)
    combined.sort((a, b) {
      final aDate = a is BookingRequest ? a.createdAt : (a as TrialSession).createdAt;
      final bDate = b is BookingRequest ? b.createdAt : (b as TrialSession).createdAt;
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    // Handle both BookingRequest and TrialSession
    final bool isTrial = request is TrialSession;
    final String status = isTrial ? request.status : (request as BookingRequest).status;
    final String tutorName = isTrial
        ? 'Demo Tutor' // Trial sessions use user ID as tutor in demo mode
        : request.tutorName;
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isTrial
                      ? Colors.purple.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTrial ? Icons.science_outlined : Icons.repeat,
                      size: 16,
                      color: isTrial ? Colors.purple : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTrial ? 'Trial Session' : 'Regular Booking',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isTrial ? Colors.purple : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

          // Tutor name
          Row(
            children: [
              const Icon(Icons.person_outline, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tutorName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details based on type
          if (isTrial) ...[
            _buildDetailRow(
              Icons.calendar_today_outlined,
              'Date',
              request.formattedDate,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.access_time_outlined,
              'Time',
              request.formattedTime,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.hourglass_empty_outlined,
              'Duration',
              request.formattedDuration,
            ),
            if (request.subject != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.book_outlined,
                'Subject',
                request.subject!,
              ),
            ],
          ] else ...[
            final bookingReq = request as BookingRequest;
            _buildDetailRow(
              Icons.repeat,
              'Frequency',
              '${bookingReq.frequency}x per week',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.calendar_month_outlined,
              'Days',
              bookingReq.days.join(', '),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.location_on_outlined,
              'Location',
              bookingReq.location.toUpperCase(),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.payments_outlined,
              'Payment',
              '${bookingReq.monthlyTotal.toStringAsFixed(0)} XAF/${bookingReq.paymentPlan}',
            ),
          ],
          const SizedBox(height: 12),

          // Created date
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                'Created ${_formatDate(isTrial ? request.createdAt : (request as BookingRequest).createdAt)}',
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
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[600],
          ),
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
      default:
        return Icons.info;
    }
  }
}
