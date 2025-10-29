import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/screens/tutor_request_detail_screen.dart';

/// TutorPendingRequestsScreen
///
/// Shows all booking requests received by a tutor
/// Highlights conflicts with existing schedule
/// Filter by: pending, all, approved, rejected
/// Tap to approve/reject/modify
class TutorPendingRequestsScreen extends StatefulWidget {
  const TutorPendingRequestsScreen({Key? key}) : super(key: key);

  @override
  State<TutorPendingRequestsScreen> createState() =>
      _TutorPendingRequestsScreenState();
}

class _TutorPendingRequestsScreenState
    extends State<TutorPendingRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    // TODO: Replace with real Supabase data
    await Future.delayed(const Duration(seconds: 1));

    // Demo data
    setState(() {
      _allRequests = [
        {
          'id': 'req_001',
          'student': {
            'full_name': 'Sarah Mbah',
            'avatar_url': 'assets/images/prepskul_profile.png',
            'user_type': 'student',
          },
          'frequency': 2,
          'days': ['Monday', 'Wednesday'],
          'times': {'Monday': '4:00 PM', 'Wednesday': '4:00 PM'},
          'location': 'online',
          'address': null,
          'payment_plan': 'monthly',
          'monthly_total': 40000.0,
          'status': 'pending',
          'created_at': '2025-10-25T10:30:00',
          'has_conflict': true,
          'conflict_details':
              'You have another student (John Doe) at Monday 4:00 PM',
        },
        {
          'id': 'req_002',
          'student': {
            'full_name': 'Mr. Kameni (Parent)',
            'avatar_url': 'assets/images/prepskul_profile.png',
            'user_type': 'parent',
          },
          'frequency': 3,
          'days': ['Tuesday', 'Thursday', 'Saturday'],
          'times': {
            'Tuesday': '5:00 PM',
            'Thursday': '5:00 PM',
            'Saturday': '10:00 AM'
          },
          'location': 'hybrid',
          'address': 'Douala, Akwa, Rue de la Joie',
          'payment_plan': 'biweekly',
          'monthly_total': 55000.0,
          'status': 'pending',
          'created_at': '2025-10-26T14:20:00',
          'has_conflict': false,
        },
        {
          'id': 'req_003',
          'student': {
            'full_name': 'Grace Fon',
            'avatar_url': 'assets/images/prepskul_profile.png',
            'user_type': 'student',
          },
          'frequency': 1,
          'days': ['Friday'],
          'times': {'Friday': '3:00 PM'},
          'location': 'onsite',
          'address': 'Yaoundé, Bastos',
          'payment_plan': 'monthly',
          'monthly_total': 25000.0,
          'status': 'approved',
          'created_at': '2025-10-20T09:15:00',
          'has_conflict': false,
        },
      ];
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getFilteredRequests(String status) {
    if (status == 'all') return _allRequests;
    return _allRequests.where((req) => req['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _allRequests.where((r) => r['status'] == 'pending').length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Requests',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            if (pendingCount > 0)
              Text(
                '$pendingCount pending',
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
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: AppTheme.primaryColor,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'All'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList('pending'),
                _buildRequestsList('all'),
                _buildRequestsList('approved'),
                _buildRequestsList('rejected'),
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
        icon = Icons.inbox_outlined;
        break;
      case 'approved':
        message = 'No approved requests yet';
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        message = 'No rejected requests';
        icon = Icons.cancel_outlined;
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
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final student = request['student'] as Map<String, dynamic>;
    final status = request['status'] as String;
    final hasConflict = request['has_conflict'] == true;
    final isPending = status == 'pending';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TutorRequestDetailScreen(request: request),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasConflict && isPending
                ? Colors.orange[300]!
                : Colors.grey[200]!,
            width: hasConflict && isPending ? 2 : 1,
          ),
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
            // Conflict warning banner (if applicable)
            if (hasConflict && isPending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Schedule Conflict Detected',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student info + status
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: AssetImage(
                          student['avatar_url'] ??
                              'assets/images/prepskul_profile.png',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['full_name'] ?? 'Student',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: student['user_type'] == 'parent'
                                    ? Colors.purple[50]
                                    : Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                student['user_type'] == 'parent'
                                    ? 'PARENT'
                                    : 'STUDENT',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: student['user_type'] == 'parent'
                                      ? Colors.purple[700]
                                      : Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[200], height: 1),
                  const SizedBox(height: 16),

                  // Request details
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          Icons.calendar_today,
                          '${request['frequency']}x/week',
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          Icons.access_time,
                          '${request['days'].length} days',
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          Icons.place,
                          (request['location'] as String).toUpperCase(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Monthly total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Revenue',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${request['monthly_total'].toStringAsFixed(0)} XAF',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),

                  // Quick action buttons (for pending only)
                  if (isPending) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TutorRequestDetailScreen(
                                    request: request,
                                    autoOpenReject: true,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red[300]!),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Decline',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TutorRequestDetailScreen(request: request),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              hasConflict ? 'Review' : 'Accept',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

