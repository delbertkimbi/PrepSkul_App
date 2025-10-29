import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/screens/request_detail_screen.dart';

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
  List<Map<String, dynamic>> _allRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          'tutor': {
            'full_name': 'Dr. Marie Ngono',
            'avatar_url': 'assets/images/prepskul_profile.png',
            'rating': 4.9,
            'is_verified': true,
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
        },
        {
          'id': 'req_002',
          'tutor': {
            'full_name': 'Prof. Jean Kamga',
            'avatar_url': 'assets/images/prepskul_profile.png',
            'rating': 4.8,
            'is_verified': true,
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
          'status': 'approved',
          'created_at': '2025-10-20T14:20:00',
          'tutor_response': 'Looking forward to working with you!',
        },
        {
          'id': 'req_003',
          'tutor': {
            'full_name': 'Dr. Aminatou Bello',
            'avatar_url': 'assets/images/prepskul_profile.png',
            'rating': 4.7,
            'is_verified': false,
          },
          'frequency': 1,
          'days': ['Friday'],
          'times': {'Friday': '3:00 PM'},
          'location': 'onsite',
          'address': 'Yaoundé, Bastos',
          'payment_plan': 'monthly',
          'monthly_total': 25000.0,
          'status': 'rejected',
          'created_at': '2025-10-18T09:15:00',
          'rejection_reason': 'Schedule conflict with existing student',
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
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
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final tutor = request['tutor'] as Map<String, dynamic>;
    final status = request['status'] as String;
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RequestDetailScreen(request: request),
          ),
        );
      },
      child: Container(
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
            // Header: Tutor info + status
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: AssetImage(
                    tutor['avatar_url'] ?? 'assets/images/prepskul_profile.png',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tutor['full_name'] ?? 'Tutor',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (tutor['is_verified'] == true)
                            Icon(
                              Icons.verified,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${tutor['rating'] ?? 4.8}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
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
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
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
                  'Monthly Total',
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
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),

            // Status-specific message
            if (status == 'approved' && request['tutor_response'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.message, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request['tutor_response'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'rejected' &&
                request['rejection_reason'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request['rejection_reason'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.access_time;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

