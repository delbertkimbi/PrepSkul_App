import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/screens/trial_payment_screen.dart';
import 'package:prepskul/features/booking/screens/book_trial_session_screen.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';

import 'package:prepskul/features/booking/models/tutor_request_model.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
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
  bool _hasCheckedExpired = false; // Prevent infinite loop

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
    
    // Reset the expired check flag when building a new session
    _hasCheckedExpired = false;
    
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
    // Determine if this is an expired session (not user-initiated cancellation)
    final isExpired = session.status == 'cancelled' && 
                     session.rejectionReason != null &&
                     (session.rejectionReason!.toLowerCase().contains('expired') || 
                      session.rejectionReason!.toLowerCase().contains('time passed'));
    
    // For pending sessions, make it VERY clear
    final isPending = session.status == 'pending';
    
    final displayStatus = isExpired 
        ? 'EXPIRED' 
        : isPending 
            ? 'PENDING TUTOR APPROVAL' 
            : session.status.toUpperCase();
    final statusMessage = _getTrialStatusMessage(session.status, rejectionReason: session.rejectionReason);
    final displayColor = isExpired 
        ? Colors.orange 
        : isPending 
            ? Colors.orange 
            : statusColor;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: displayColor.withOpacity(isPending ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: displayColor.withOpacity(isPending ? 0.5 : 0.3),
          width: isPending ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(session.status), 
            color: displayColor, 
            size: isPending ? 32 : 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayStatus,
                  style: GoogleFonts.poppins(
                    fontSize: isPending ? 18 : 16,
                    fontWeight: FontWeight.w800,
                    color: displayColor,
                    letterSpacing: isPending ? 0.5 : 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusMessage,
                  style: GoogleFonts.poppins(
                    fontSize: isPending ? 14 : 13,
                    fontWeight: isPending ? FontWeight.w600 : FontWeight.normal,
                    color: displayColor,
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
                _cleanTrialGoal(session.trialGoal!),
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
  
  /// Clean trial goal text by removing internal reschedule request notes
  String _cleanTrialGoal(String goal) {
    // Remove reschedule request notes that were accidentally added to trial goals
    // Pattern: [RESCHEDULE REQUEST: ...]
    final reschedulePattern = RegExp(r'\n?\n?\[RESCHEDULE REQUEST:.*?\]', dotAll: true);
    return goal.replaceAll(reschedulePattern, '').trim();
  }

  Widget _buildTrialActions(BuildContext context, TrialSession session) {
    final paymentStatus = session.paymentStatus.toLowerCase();
    final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed';
    final isApproved = session.status == 'approved' || session.status == 'scheduled';
    final isPending = session.status == 'pending';
    
    // PENDING SESSIONS: Show Modify and Delete buttons
    if (isPending) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            // Modify button (no reason required)
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final tutorData = await _loadTutorInfo(session.tutorId);
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
                      if (mounted) {
                        safeSetState(() {});
                        Navigator.pop(context, true); // Refresh parent screen
                      }
                    });
                  }
                } catch (e) {
                  LogService.error('Error loading tutor for modification: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error loading tutor information'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.edit, size: 20),
              label: Text(
                'Modify Request',
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
            const SizedBox(height: 12),
            // Delete button (optional reason)
            OutlinedButton.icon(
              onPressed: () => _showDeleteDialog(context, session, requireReason: false),
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text(
                'Delete Request',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red, width: 1.5),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Check if session should be marked as missed/expired (only once, and only for unpaid sessions)
    if (!_hasCheckedExpired) {
      _hasCheckedExpired = true;
      if (!isPaid) {
        _checkAndMarkMissedSession(session);
      }
    }
    
    // Check if session is expired
    final isExpired = SessionDateUtils.isSessionExpired(session) || 
                     (session.status == 'cancelled' && 
                      (session.rejectionReason?.contains('expired') == true ||
                       session.rejectionReason?.contains('not completed') == true));
    
    // PAID SESSIONS: Show Modify only (with reason), NO delete
    if (isPaid && isApproved && !isExpired) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            // Request Date Change button (modify with reason)
            ElevatedButton.icon(
              onPressed: () async {
                final reasonController = TextEditingController();
                final confirmed = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      'Request Date Change',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Please provide a reason for requesting a date change:',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: reasonController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Schedule conflict, personal emergency...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          maxLines: 3,
                          autofocus: true,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.poppins()),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (reasonController.text.trim().isNotEmpty) {
                            Navigator.pop(context, reasonController.text.trim());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child: Text('Request', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                );
                
                if (confirmed != null && confirmed.isNotEmpty) {
                  try {
                    final tutorData = await _loadTutorInfo(session.tutorId);
                    if (tutorData != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookTrialSessionScreen(
                            tutor: tutorData,
                            rescheduleSessionId: session.id,
                            isReschedule: true,
                            rescheduleReason: confirmed,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) {
                          safeSetState(() {});
                        }
                      });
                    }
                  } catch (e) {
                    LogService.error('Error loading tutor for date change: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error loading tutor information'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.edit_calendar, size: 20),
              label: Text(
                'Request Date Change',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // View Session button
            ElevatedButton.icon(
              onPressed: () => _navigateToSession(context, session),
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
          ],
        ),
      );
    }
    
    // APPROVED (UNPAID) SESSIONS: Show Pay Now button (primary), then Modify/Delete as secondary options
    if (isApproved && !isPaid && !isExpired) {
      // Check if session is upcoming (not expired) - only show Pay Now if upcoming
      final isUpcoming = SessionDateUtils.isSessionUpcoming(session);
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            // Pay Now button (primary action for approved unpaid sessions) - ALWAYS show for approved unpaid
            ElevatedButton(
              onPressed: isUpcoming ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrialPaymentScreen(trialSession: session),
                  ),
                ).then((success) {
                  if (success == true && mounted) {
                    safeSetState(() {});
                  }
                });
              } : null, // Disable if expired
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
              ),
              child: Text(
                'Pay Now',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Modify button (requires reason) - secondary action
            ElevatedButton.icon(
              onPressed: () => _showModifyDialog(context, session, requireReason: true),
              icon: const Icon(Icons.edit, size: 20),
              label: Text(
                'Modify Session',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.grey[700],
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Delete button (requires reason) - secondary action
            OutlinedButton.icon(
              onPressed: () => _showDeleteDialog(context, session, requireReason: true),
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text(
                'Delete Session',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red, width: 1.5),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // EXPIRED SESSIONS: Show Edit Date button
    if (isExpired) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: ElevatedButton.icon(
          onPressed: () async {
            try {
              final tutorData = await _loadTutorInfo(session.tutorId);
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
                  if (mounted) {
                    safeSetState(() {});
                  }
                });
              }
            } catch (e) {
              LogService.error('Error loading tutor for reschedule: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading tutor information'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.edit_calendar, size: 20),
          label: Text(
            'Edit Date',
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
  
  /// Show modify dialog
  Future<void> _showModifyDialog(BuildContext context, TrialSession session, {required bool requireReason}) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Modify Session',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (requireReason) ...[
              Text(
                'Please provide a reason for modifying this session:',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'e.g., Schedule conflict, need different time...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ] else ...[
              Text(
                'You can modify the session details. The tutor will be notified of the changes.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (!requireReason || reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text('Continue', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    
    if (confirmed != null) {
      try {
        final tutorData = await _loadTutorInfo(session.tutorId);
        if (tutorData != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookTrialSessionScreen(
                tutor: tutorData,
                rescheduleSessionId: session.id,
                isReschedule: true,
                rescheduleReason: requireReason ? confirmed : null,
              ),
            ),
          ).then((_) {
            if (mounted) {
              safeSetState(() {});
              Navigator.pop(context, true); // Refresh parent screen
            }
          });
        }
      } catch (e) {
        LogService.error('Error loading tutor for modification: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading tutor information'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  /// Show delete dialog
  Future<void> _showDeleteDialog(BuildContext context, TrialSession session, {required bool requireReason}) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red[300], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                requireReason ? 'Delete Session' : 'Delete Request',
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
              requireReason
                  ? 'Please provide a reason for deleting this session. The tutor will be notified.'
                  : 'You can optionally provide a reason for deleting this request. The tutor will be notified.',
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: requireReason
                    ? 'e.g., Schedule conflict, found another tutor, etc.'
                    : 'Optional: Reason for deletion...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                labelText: requireReason ? 'Deletion Reason (Required)' : 'Deletion Reason (Optional)',
                labelStyle: GoogleFonts.poppins(fontSize: 12),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep ${requireReason ? 'Session' : 'Request'}', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (!requireReason || reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim().isEmpty ? null : reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirmed != null) {
      try {
        await TrialSessionService.deleteTrialSession(
          sessionId: session.id,
          reason: confirmed.isEmpty ? null : confirmed,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${requireReason ? 'Session' : 'Request'} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return to previous screen
        }
      } catch (e) {
        LogService.error('Error deleting session: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  /// Navigate to session in My Sessions screen
  void _navigateToSession(BuildContext context, TrialSession session) {
    final now = DateTime.now();
    final sessionDateTime = DateTime(
      session.scheduledDate.year,
      session.scheduledDate.month,
      session.scheduledDate.day,
      int.tryParse(session.scheduledTime.split(':')[0]) ?? 0,
      int.tryParse(session.scheduledTime.split(':').length > 1 ? session.scheduledTime.split(':')[1] : '0') ?? 0,
    );
    
    final sessionEndTime = sessionDateTime.add(Duration(minutes: session.durationMinutes));
    final isPast = sessionEndTime.isBefore(now) || 
                   session.status == 'completed' || 
                   session.status == 'cancelled';
    
    Navigator.pushNamed(
      context,
      '/my-sessions',
      arguments: {
        'initialTab': isPast ? 1 : 0,
        'sessionId': session.id,
      },
    );
  }
  
  /// Check and mark session as missed if time has passed
  Future<void> _checkAndMarkMissedSession(TrialSession session) async {
    try {
      // Only check if session is pending, approved, or scheduled
      // Don't update if already completed, cancelled, or rejected
      if (session.status == 'completed' || 
          session.status == 'cancelled' || 
          session.status == 'rejected') {
        return;
      }
      
      // Check if session time has passed
      if (!SessionDateUtils.isSessionExpired(session)) {
        return; // Session hasn't expired yet
      }
      
      // Session has expired - but be conservative about auto-cancelling
      final sessionDateTime = SessionDateUtils.getSessionDateTime(session);
      final now = DateTime.now();
      final timeSinceSession = now.difference(sessionDateTime);
      
      // Only auto-cancel if:
      // 1. At least 24 hours have passed since the session time (grace period)
      // 2. AND the session is unpaid (we don't auto-cancel paid sessions - those need manual review)
      final paymentStatus = session.paymentStatus.toLowerCase();
      final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed';
      
      // For unpaid sessions: auto-cancel after 24 hours
      // For paid sessions: NEVER auto-cancel - they should be marked as "no_show" or "missed" manually
      if (!isPaid && timeSinceSession.inHours >= 24) {
        // Only auto-cancel unpaid sessions that expired more than 24 hours ago
        try {
          await SupabaseService.client
              .from('trial_sessions')
              .update({
                'status': 'cancelled',
                'rejection_reason': 'Session expired - time passed',
                'updated_at': now.toIso8601String(),
              })
              .eq('id', session.id);
          
          LogService.info('Auto-cancelled unpaid expired trial session: ${session.id} (expired ${timeSinceSession.inHours} hours ago)');
          
          // Refresh the screen to show updated status
          if (mounted) {
            safeSetState(() {});
          }
        } catch (e) {
          LogService.warning('Error marking unpaid session as cancelled: $e');
        }
      } else if (isPaid && timeSinceSession.inHours >= 24) {
        // For paid sessions that expired, we should mark as "no_show" instead of cancelled
        // But only if it's been more than 24 hours and still not completed
        // Actually, let's not auto-update paid sessions at all - they need manual review
        LogService.debug('Paid session ${session.id} expired ${timeSinceSession.inHours} hours ago - requires manual review');
      }
      // If less than 24 hours have passed, don't do anything - give users time
    } catch (e) {
      LogService.warning('Error checking missed session: $e');
    }
  }
  
  Future<Map<String, dynamic>?> _loadTutorInfo(String tutorId) async {
    try {
      // Fetch tutor profile with profile data
      final supabase = SupabaseService.client;
      
      // Try to fetch tutor profile with joined profile data
      try {
        final tutorProfile = await supabase
            .from('tutor_profiles')
            .select(
              'user_id, rating, admin_approved_rating, total_reviews, profile_photo_url, profiles!tutor_profiles_user_id_fkey(full_name, avatar_url)',
            )
            .eq('user_id', tutorId)
            .maybeSingle();

        if (tutorProfile == null) return null;

        // Extract profile data
        Map<String, dynamic>? profile;
        final profilesData = tutorProfile['profiles'];
        if (profilesData is Map) {
          profile = Map<String, dynamic>.from(profilesData);
        } else if (profilesData is List && profilesData.isNotEmpty) {
          profile = Map<String, dynamic>.from(profilesData[0]);
        }

        // Build tutor data map for BookTrialSessionScreen
        final tutorName = profile?['full_name'] as String? ?? 'Tutor';
        final avatarUrl = tutorProfile['profile_photo_url'] as String? ?? 
                         profile?['avatar_url'] as String?;
        
        return {
          'id': tutorId,
          'user_id': tutorId,
          'full_name': tutorName,
          'avatar_url': avatarUrl,
          'rating': tutorProfile['rating'] ?? 0.0,
          'admin_approved_rating': tutorProfile['admin_approved_rating'],
          'total_reviews': tutorProfile['total_reviews'] ?? 0,
        };
      } catch (e) {
        LogService.warning('Error loading tutor with join, trying fallback: $e');
        
        // Fallback: fetch separately
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
      }
    } catch (e) {
      LogService.error('Error loading tutor info: $e');
      return null;
    }
  }
  
  String _getTrialStatusMessage(String status, {String? rejectionReason}) {
    switch (status) {
      case 'pending':
        return 'Your tutor needs to approve this trial before you can pay.';
      case 'approved':
        return 'Tutor has approved your trial session';
      case 'rejected':
        return 'Tutor has rejected your request';
      case 'scheduled':
        return 'Session is scheduled';
      case 'completed':
        return 'Trial session completed';
      case 'cancelled':
        // Check if it was cancelled due to expiration
        if (rejectionReason != null && 
            (rejectionReason.toLowerCase().contains('expired') || 
             rejectionReason.toLowerCase().contains('time passed') ||
             rejectionReason.toLowerCase().contains('session expired'))) {
          return 'Session expired - you can reschedule';
        }
        return 'Trial session cancelled by user';
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
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      // 'expired' is not a valid status - use 'cancelled' instead
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.grey;
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
  
  

