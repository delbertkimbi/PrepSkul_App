import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/screens/trial_payment_screen.dart';

import 'package:prepskul/features/booking/models/tutor_request_model.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';

import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

/// RequestDetailScreen
///
/// Full detail view of a booking request
/// Shows complete schedule, pricing, status timeline
/// Actions: Cancel request (if pending), Contact tutor
class RequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? request;
  final TrialSession? trialSession;
  final TutorRequest? tutorRequest;

  const RequestDetailScreen({
    Key? key,
    this.request,
    this.trialSession,
    this.tutorRequest,
  }) : super(key: key);

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _isCanceling = false;

  Future<void> _cancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel Request?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to cancel this booking request?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Yes, Cancel',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      safeSetState(() => _isCanceling = true);
      // TODO: Call API to cancel
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      Navigator.pop(context); // Go back to list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request canceled successfully',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle different request types
    if (widget.trialSession != null) {
      return _buildTrialSessionDetail(context, widget.trialSession!);
    } else if (widget.tutorRequest != null) {
      return _buildTutorRequestDetail(context, widget.tutorRequest!);
    } else if (widget.request != null) {
      return _buildBookingRequestDetail(context, widget.request!);
    } else {
      return Scaffold(
        appBar: AppBar(title: Text('Request Details')),
        body: Center(child: Text('No request data available')),
      );
    }
  }

  Widget _buildTrialSessionDetail(BuildContext context, TrialSession session) {
    final statusColor = _getStatusColor(session.status);
    
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
          'Trial Session Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _buildTrialStatusBanner(session, statusColor),
            const SizedBox(height: 24),
            
            // Tutor Info Card (will be loaded asynchronously)
            FutureBuilder<Map<String, dynamic>?>(
              future: _loadTutorInfo(session.tutorId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return _buildTrialTutorCard(snapshot.data!);
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
            
            // Session Details Card
            _buildTrialSessionDetailsCard(session),
            const SizedBox(height: 24),
            
            // Schedule Card
            _buildTrialScheduleCard(session),
            const SizedBox(height: 24),
            
            // Payment Card
            _buildTrialPaymentCard(session),
            const SizedBox(height: 24),
            
            // Trial Goals Card (if available)
            if (session.trialGoal != null || session.learnerChallenges != null)
              _buildTrialGoalsCard(session),
            if (session.trialGoal != null || session.learnerChallenges != null)
              const SizedBox(height: 24),
            
            // Action buttons at bottom
            _buildTrialActions(context, session),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrialStatusBanner(TrialSession session, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(session.status), color: statusColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                Text(
                  _getTrialStatusMessage(session.status),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Waiting for tutor\'s response';
      case 'approved':
        return 'Tutor has accepted your request!';
      case 'rejected':
        return 'Tutor declined this request';
      default:
        return '';
    }
  }
  
  Widget _buildTrialTutorCard(Map<String, dynamic> tutorData) {
    final tutorName = tutorData['full_name']?.toString() ?? 'Tutor';
    final tutorAvatarUrl = tutorData['avatar_url']?.toString();
    final tutorRating = (tutorData['rating'] ?? 0.0) as double;
    final tutorIsVerified = tutorData['is_verified'] as bool? ?? false;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: tutorAvatarUrl != null && tutorAvatarUrl.isNotEmpty
                  ? NetworkImage(tutorAvatarUrl)
                  : null,
              child: tutorAvatarUrl == null || tutorAvatarUrl.isEmpty
                  ? Text(
                      tutorName.isNotEmpty ? tutorName[0].toUpperCase() : 'T',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tutorName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (tutorIsVerified) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.verified, color: AppTheme.primaryColor, size: 18),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (tutorRating > 0)
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          tutorRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrialSessionDetailsCard(TrialSession session) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Subject', session.subject),
            _buildInfoRow('Duration', '${session.durationMinutes} minutes'),
            _buildInfoRow('Location', session.location.toUpperCase()),
            if (session.learnerLevel != null)
              _buildInfoRow('Learner Level', session.learnerLevel!),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrialScheduleCard(TrialSession session) {
    final dateStr = '${session.scheduledDate.day}/${session.scheduledDate.month}/${session.scheduledDate.year}';
    final timeStr = session.scheduledTime;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            if (session.meetLink != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // Open Google Meet link
                },
                icon: const Icon(Icons.video_call, size: 18),
                label: Text('Join Session', style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrialPaymentCard(TrialSession session) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Trial Fee', '${session.trialFee.toStringAsFixed(0)} XAF'),
            _buildInfoRow('Payment Status', session.paymentStatus.toUpperCase()),
            if (SessionDateUtils.shouldShowPayNowButton(session))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrialPaymentScreen(trialSession: session),
                      ),
                    ).then((success) {
                      if (success == true) {
                        // Refresh the screen
                        safeSetState(() {});
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Pay Now', style: GoogleFonts.poppins()),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrialGoalsCard(TrialSession session) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trial Goals',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            if (session.trialGoal != null) ...[
              Text(
                'Goal',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.trialGoal!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (session.learnerChallenges != null) ...[
              Text(
                'Challenges',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.learnerChallenges!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrialActions(BuildContext context, TrialSession session) {
    // If not approved, show no action button
    if (session.status != 'approved' && session.status != 'scheduled') {
      return const SizedBox.shrink();
    }
    
    // If approved but not paid, show Pay Now button
    if (session.status == 'approved' && session.paymentStatus == 'unpaid') {
      if (SessionDateUtils.shouldShowPayNowButton(session)) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrialPaymentScreen(trialSession: session),
                ),
              ).then((success) {
                if (success == true) {
                  // Refresh the screen
                  safeSetState(() {});
                }
              });
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
              'Pay Now',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }
    
    // If paid, show View Session button
    if (session.paymentStatus == 'paid' || session.status == 'scheduled') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: ElevatedButton.icon(
          onPressed: () {
            // Navigate to My Sessions screen (tab 1 in student nav)
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/student-nav',
              (route) => false,
              arguments: {'initialTab': 1}, // Sessions tab (0=Home, 1=Sessions, 2=Requests, 3=Profile)
            );
          },
          icon: const Icon(Icons.calendar_today, size: 20),
          label: Text(
            'View Session',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
  
        Future<Map<String, dynamic>?> _loadTutorInfo(String tutorId) async {
    try {
      // Use TutorService to fetch tutor by ID
      return await TutorService.fetchTutorById(tutorId);
    } catch (e) {
      LogService.debug('Error loading tutor info: $e');
      return null;
    }
  }
  
  String _getTrialStatusMessage(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting for tutor approval';
      case 'approved':
        return 'Tutor has approved your trial session';
      case 'rejected':
        return 'Tutor has rejected your request';
      case 'scheduled':
        return 'Session is scheduled';
      case 'completed':
        return 'Trial session completed';
      case 'cancelled':
        return 'Trial session cancelled';
      case 'no_show':
        return 'No show detected';
      default:
        return 'Unknown status';
    }
  }

  Widget _buildTutorRequestDetail(BuildContext context, TutorRequest request) {
    // TODO: Build tutor request detail view
    return Scaffold(
      appBar: AppBar(
        title: Text('Custom Request Details'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Text('Custom request detail view coming soon'),
      ),
    );
  }

  Widget _buildBookingRequestDetail(BuildContext context, Map<String, dynamic> request) {
    // Get tutor data from individual fields (toJson() doesn't include tutor map)
    final tutorName = request['tutor_name'] as String? ?? 'Tutor';
    final tutorAvatarUrl = request['tutor_avatar_url'] as String?;
    final tutorRating = request['tutor_rating'] as double?;
    final tutorIsVerified = request['tutor_is_verified'] as bool? ?? false;
    final status = request['status'] as String;
    final statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(status), color: statusColor, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          _getStatusMessage(status),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tutor Card
            _buildTutorCard(tutorName, tutorAvatarUrl, tutorRating, tutorIsVerified),
            const SizedBox(height: 24),

            // Schedule Section
            _buildSectionTitle('Session Schedule'),
            const SizedBox(height: 16),
            _buildScheduleCard(request),
            const SizedBox(height: 24),

            // Location Section
            _buildSectionTitle('Location'),
            const SizedBox(height: 16),
            _buildLocationCard(request),
            const SizedBox(height: 24),

            // Pricing Section
            _buildSectionTitle('Pricing Details'),
            const SizedBox(height: 16),
            _buildPricingCard(request),

            // Status-specific content
            if (status == 'approved' &&
                request['tutor_response'] != null) ...[
              const SizedBox(height: 24),
              _buildSectionTitle('Tutor\'s Message'),
              const SizedBox(height: 16),
              _buildMessageCard(
                request['tutor_response'] as String,
                Colors.green,
              ),
            ],
            if (status == 'rejected' &&
                request['rejection_reason'] != null) ...[
              const SizedBox(height: 24),
              _buildSectionTitle('Rejection Reason'),
              const SizedBox(height: 16),
              _buildMessageCard(
                request['rejection_reason'] as String,
                Colors.red,
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            if (status == 'pending') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCanceling ? null : _cancelRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCanceling
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Cancel Request',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
            if (status == 'approved') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to messaging
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Messaging coming soon!',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: Text(
                    'Message Tutor',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildTutorCard(String tutorName, String? tutorAvatarUrl, double? tutorRating, bool tutorIsVerified) {
    final avatarUrl = tutorAvatarUrl;
    final name = tutorName;
    final rating = tutorRating ?? 4.8;
    final isVerified = tutorIsVerified;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[300],
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[700],
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> request) {
    final frequency = request['frequency'] as int;
    final days = request['days'] as List;
    final times = request['times'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Frequency', '$frequency times per week'),
          const SizedBox(height: 16),
          _buildDetailRow('Days', days.join(', ')),
          const SizedBox(height: 16),
          Text(
            'Session Times:',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          ...days.map((day) {
            final time = times[day] ?? 'Not set';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$day: ',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    time,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> request) {
    final location = request['location'] as String;
    final address = request['address'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Format', location.toUpperCase()),
          if (address != null) ...[
            const SizedBox(height: 16),
            _buildDetailRow('Address', address),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingCard(Map<String, dynamic> request) {
    final monthlyTotal = request['monthly_total'] as double;
    final paymentPlan = request['payment_plan'] as String;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.05),
            AppTheme.primaryColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Total',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '${monthlyTotal.toStringAsFixed(0)} XAF',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Plan',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                paymentPlan.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: color == Colors.green ? Colors.green[900] : Colors.red[900],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
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
  switch (status.toLowerCase()) {

      case 'pending':
        return Icons.access_time;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
          return Icons.info;
    }
  }

}

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMedium,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  

