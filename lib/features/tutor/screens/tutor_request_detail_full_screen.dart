import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/services/log_service.dart';
import '../../../core/widgets/branded_snackbar.dart';
import '../../../features/booking/models/booking_request_model.dart';
import '../../../features/booking/services/booking_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/messaging/services/conversation_lifecycle_service.dart';
import 'package:prepskul/features/messaging/models/conversation_model.dart';
import 'package:prepskul/features/messaging/screens/chat_screen.dart';
import 'tutor_requests_screen.dart';

/// Full-screen detail view for tutor booking requests
/// Profile-like UI with all request details and action buttons at the bottom
class TutorRequestDetailFullScreen extends StatefulWidget {
  final BookingRequest request;

  const TutorRequestDetailFullScreen({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  State<TutorRequestDetailFullScreen> createState() =>
      _TutorRequestDetailFullScreenState();
}

class _TutorRequestDetailFullScreenState
    extends State<TutorRequestDetailFullScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final typeLower = request.studentType.toLowerCase();
    final isStudent = typeLower == 'learner' || typeLower == 'student';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Profile Section
                  _buildProfileSection(request, isStudent),
                  const SizedBox(height: 32),

                  // Session Details Section
                  _buildSectionTitle('Session Details'),
                  const SizedBox(height: 16),
                  _buildSessionDetailsCard(request),
                  const SizedBox(height: 24),

                  // Schedule Section
                  _buildSectionTitle('Schedule'),
                  const SizedBox(height: 16),
                  _buildScheduleCard(request),
                  const SizedBox(height: 24),

                  // Location Section
                  _buildSectionTitle('Location'),
                  const SizedBox(height: 16),
                  _buildLocationCard(request),
                  const SizedBox(height: 24),

                  // Payment Section
                  _buildSectionTitle('Payment'),
                  const SizedBox(height: 16),
                  _buildPaymentCard(request),
                  // Your response (approval message or rejection reason) when set
                  if ((request.tutorResponse != null && request.tutorResponse!.trim().isNotEmpty) ||
                      (request.rejectionReason != null && request.rejectionReason!.trim().isNotEmpty)) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle(request.status == 'rejected' ? 'Your rejection reason' : 'Your message to student'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: request.status == 'rejected'
                            ? Colors.red.withOpacity(0.06)
                            : AppTheme.primaryColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: request.status == 'rejected'
                              ? Colors.red.withOpacity(0.25)
                              : AppTheme.primaryColor.withOpacity(0.22),
                        ),
                      ),
                      child: Text(
                        request.rejectionReason?.trim().isNotEmpty == true
                            ? request.rejectionReason!
                            : request.tutorResponse ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  // Learners Section (show whenever we have learner names: trial or recurring)
                  if (request.learnerLabels != null && request.learnerLabels!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle(request.learnerLabels!.length == 1 ? 'Learner' : 'Learners'),
                    const SizedBox(height: 16),
                    _buildLearnersSection(request),
                  ],
                  // Message student (white, deep blue border) when approved/scheduled
                  if (!request.isPending) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToChat(context, request),
                        icon: Icon(Icons.message, size: 20, color: AppTheme.primaryColor),
                        label: Text(
                          'Message student',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons (only for pending requests)
          if (request.isPending) _buildActionButtons(request),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BookingRequest request, bool isStudent) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          backgroundImage: request.studentAvatarUrl != null
              ? CachedNetworkImageProvider(request.studentAvatarUrl!)
              : null,
          child: request.studentAvatarUrl == null
              ? Text(
                  request.studentName.isNotEmpty
                      ? request.studentName[0].toUpperCase()
                      : 'S',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 20),
        Text(
          request.studentName,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isStudent ? 'Student' : 'Parent',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Check payment status for approved requests
            FutureBuilder<Map<String, dynamic>?>(
              future: request.status == 'approved'
                  ? PaymentRequestService.getPaymentRequestByBookingRequestId(request.id)
                  : Future.value(null),
              builder: (context, snapshot) {
                String displayStatus = request.status;
                Color statusColor;
                Color statusBgColor;
                
                if (request.status == 'approved' && snapshot.hasData) {
                  final paymentStatus = snapshot.data?['status'] as String?;
                  if (paymentStatus == 'paid') {
                    displayStatus = 'scheduled';
                    statusColor = Colors.blue[700]!;
                    statusBgColor = Colors.blue[50]!;
                  } else {
                    displayStatus = 'approved';
                    statusColor = AppTheme.accentGreen;
                    statusBgColor = AppTheme.accentGreen.withOpacity(0.1);
                  }
                } else {
                  statusColor = request.status == 'pending'
                      ? AppTheme.primaryColor
                      : request.status == 'approved'
                          ? AppTheme.accentGreen
                          : AppTheme.textMedium;
                  statusBgColor = request.status == 'pending'
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : request.status == 'approved'
                          ? AppTheme.accentGreen.withOpacity(0.1)
                          : AppTheme.textMedium.withOpacity(0.1);
                }
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayStatus.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        // Multi-learner summary: show learner names in profile section
        if (request.isMultiLearner && request.learnerLabels != null && request.learnerLabels!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Learners: ${request.learnerLabels!.join(', ')}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _navigateToChat(BuildContext context, BookingRequest request) async {
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final conversationData = await ConversationLifecycleService.getOrCreateConversation(
        bookingRequestId: request.id,
        tutorId: currentUserId,
        studentId: request.studentId,
      );
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading
      if (conversationData == null || conversationData['id'] == null) {
        BrandedSnackBar.showError(context, 'Unable to start conversation.');
        return;
      }
      final supabase = SupabaseService.client;
      final conv = await supabase
          .from('conversations')
          .select('*')
          .eq('id', conversationData['id'] as String)
          .maybeSingle();
      if (conv == null || !context.mounted) return;
      final studentProfile = await supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', request.studentId)
          .maybeSingle();
      final conversation = Conversation(
        id: conv['id'] as String,
        studentId: conv['student_id'] as String,
        tutorId: conv['tutor_id'] as String,
        bookingRequestId: conv['booking_request_id'] as String?,
        recurringSessionId: conv['recurring_session_id'] as String?,
        individualSessionId: conv['individual_session_id'] as String?,
        trialSessionId: conv['trial_session_id'] as String?,
        status: conv['status'] as String? ?? 'active',
        expiresAt: conv['expires_at'] != null ? DateTime.parse(conv['expires_at'] as String) : null,
        lastMessageAt: conv['last_message_at'] != null ? DateTime.parse(conv['last_message_at'] as String) : null,
        createdAt: DateTime.parse(conv['created_at'] as String),
        otherUserName: studentProfile?['full_name'] as String? ?? request.studentName,
        otherUserAvatarUrl: studentProfile?['avatar_url'] as String?,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      LogService.error('Error opening chat: $e');
      if (context.mounted) {
        Navigator.pop(context); // dismiss loading if still showing
        BrandedSnackBar.showError(context, 'Unable to open chat.');
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildSessionDetailsCard(BookingRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always show type of booking first (Trial Session vs Recurring sessions)
          _buildDetailRow(
            request.isTrial ? Icons.science_outlined : Icons.repeat,
            'Type of booking',
            request.isTrial ? 'Trial Session' : 'Recurring sessions',
          ),
          if (request.isTrial) ...[
            if (request.subject != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(Icons.menu_book, 'Subject', request.subject!),
            ],
            if (request.durationMinutes != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.timer,
                'Duration',
                '${request.durationMinutes} minutes',
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.repeat,
              'Frequency',
              '${request.frequency}x per week',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.calendar_today,
              'Days',
              request.getDaysSummary(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleCard(BookingRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          if (request.isTrial && request.scheduledDate != null) ...[
            _buildDetailRow(
              Icons.calendar_today,
              'Date',
              '${request.scheduledDate!.day}/${request.scheduledDate!.month}/${request.scheduledDate!.year}',
            ),
            const SizedBox(height: 12),
          ],
          _buildDetailRow(Icons.access_time, 'Time', request.getTimeRange()),
        ],
      ),
    );
  }

  Widget _buildLocationCard(BookingRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            Icons.location_on,
            'Location',
            _formatLocation(request.location, request.address),
          ),
          // Show location description if provided by learner
          if (request.locationDescription != null && 
              request.locationDescription!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.description,
              'Location Details',
              request.locationDescription!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BookingRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            Icons.payment,
            'Plan',
            _formatPaymentPlan(request.paymentPlan),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.attach_money,
            'Amount',
            _formatCurrency(request.monthlyTotal),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearnersSection(BookingRequest request) {
    final labels = request.learnerLabels!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Learners for this booking (${labels.length})',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...labels.asMap().entries.map((entry) {
            final learnerName = entry.value;
            final status = request.getLearnerStatus(learnerName);
            final rejectionReason = request.getLearnerRejectionReason(learnerName);
            final isAccepted = status == 'accepted';
            final isDeclined = status == 'declined';
            final isPendingStatus = status == null || status == 'pending';
            return InkWell(
              onTap: () => _showLearnerDetailBottomSheet(context, request, learnerName),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: EdgeInsets.only(bottom: entry.key < labels.length - 1 ? 12 : 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isAccepted
                      ? Colors.green[300]!
                      : isDeclined
                          ? Colors.red[300]!
                          : Colors.grey[300]!,
                  width: isAccepted || isDeclined ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAccepted
                              ? Colors.green
                              : isDeclined
                                  ? Colors.red
                                  : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              learnerName,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            if (isAccepted || isDeclined) ...[
                              const SizedBox(height: 4),
                              Text(
                                isAccepted ? 'Accepted' : 'Declined',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isAccepted ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.touch_app, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to view details & subjects',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      if (isPendingStatus && request.isPending)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: _isProcessing ? null : () => _acceptLearner(learnerName),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.green[300]!),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Accept', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green[700])),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _isProcessing ? null : () => _declineLearner(learnerName),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red[300]!),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Decline', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red[700])),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (isDeclined && rejectionReason != null && rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reason: $rejectionReason',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[900]),
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
          }),
        ],
      ),
    );
  }

  void _showLearnerDetailBottomSheet(BuildContext context, BookingRequest request, String learnerName) {
    final subjects = request.getLearnerSubjects(learnerName);
    final goal = request.trialGoal?.trim();
    final challenges = request.learnerChallenges?.trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              learnerName,
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark),
            ),
            const SizedBox(height: 16),
            if (subjects.isNotEmpty) ...[
              Text(
                'Subjects',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 6),
              Text(
                subjects.join(', '),
                style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textDark),
              ),
              const SizedBox(height: 16),
            ],
            if (goal != null && goal.isNotEmpty) ...[
              Text(
                'What they want to improve',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 6),
              Text(
                goal,
                style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textDark),
              ),
              const SizedBox(height: 16),
            ],
            if (challenges != null && challenges.isNotEmpty) ...[
              Text(
                'Challenges / notes',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 6),
              Text(
                challenges,
                style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textDark),
              ),
            ],
            if (subjects.isEmpty && (goal == null || goal.isEmpty) && (challenges == null || challenges.isEmpty))
              Text(
                'No subject or goal details for this learner yet.',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptLearner(String learnerName) async {
    final request = widget.request;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ApproveDialog(),
    );
    if (result == null) return;
    safeSetState(() => _isProcessing = true);
    try {
      await BookingService.acceptLearner(
        request.id,
        learnerName,
        responseNotes: result.isEmpty ? null : result,
      );
      if (!mounted) return;
      BrandedSnackBar.showSuccess(context, 'Learner accepted');
      Navigator.pop(context, true);
    } catch (e) {
      LogService.error('Error accepting learner: $e');
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to accept learner');
        safeSetState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _declineLearner(String learnerName) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Decline $learnerName', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                const SizedBox(height: 16),
                Text('Reason (required):', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'E.g., Schedule conflict',
                    filled: true,
                    fillColor: AppTheme.softBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, controller.text.trim()),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                        child: const Text('Decline'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    safeSetState(() => _isProcessing = true);
    try {
      await BookingService.declineLearner(widget.request.id, learnerName, reason: reason);
      if (!mounted) return;
      BrandedSnackBar.showSuccess(context, 'Learner declined');
      Navigator.pop(context, true);
    } catch (e) {
      LogService.error('Error declining learner: $e');
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to decline learner');
        safeSetState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _acceptAllLearners(BookingRequest request) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ApproveDialog(),
    );
    if (result == null) return;
    safeSetState(() => _isProcessing = true);
    try {
      final notes = result.isEmpty ? null : result;
      for (final learnerName in request.learnerLabels!) {
        final status = request.getLearnerStatus(learnerName);
        if (status != 'accepted' && status != 'declined') {
          await BookingService.acceptLearner(request.id, learnerName, responseNotes: notes);
        }
      }
      if (!mounted) return;
      BrandedSnackBar.showSuccess(context, 'All learners accepted');
      Navigator.pop(context, true);
    } catch (e) {
      LogService.error('Error accepting all learners: $e');
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to accept all learners');
        safeSetState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildActionButtons(BookingRequest request) {
    final isMultiLearnerPending = request.isPending && request.isMultiLearner;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.softBorder, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMultiLearnerPending) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _acceptAllLearners(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text('Accept all learners', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _handleApprove(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text('Approve', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => _handleReject(request, suggestTime: false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.textMedium),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Reject', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textMedium)),
                  ),
                ),
                if (request.isTrial && !isMultiLearnerPending) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => _handleReject(request, suggestTime: true),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Reschedule', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatLocation(String location, String? address) {
    switch (location) {
      case 'online':
        return 'Online';
      case 'onsite':
        return address ?? 'Onsite';
      case 'hybrid':
        return 'Hybrid ${address != null ? '($address)' : ''}';
      default:
        return location;
    }
  }

  String _formatPaymentPlan(String plan) {
    switch (plan) {
      case 'monthly':
        return 'Monthly';
      case 'biweekly':
        return 'Bi-weekly';
      case 'weekly':
        return 'Weekly';
      default:
        return plan;
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} XAF';
  }

  Future<void> _handleApprove(BookingRequest request) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ApproveDialog(),
    );

    if (result != null) {
      safeSetState(() => _isProcessing = true);
      try {
        if (request.isTrial) {
          await BookingService.approveTrialRequest(
            request.id,
            responseNotes: result.isEmpty ? null : result,
          );
          if (mounted) {
            BrandedSnackBar.showSuccess(
              context,
              'Trial session approved!',
            );
          }
        } else {
          await BookingService.approveBookingRequest(
            request.id,
            responseNotes: result.isEmpty ? null : result,
          );
          if (mounted) {
            BrandedSnackBar.showSuccess(
              context,
              'Booking request approved!',
            );
          }
        }
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        LogService.error('Error approving request: $e');
        if (mounted) {
          BrandedSnackBar.showError(context, 'Failed to approve request: $e');
          safeSetState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _handleReject(BookingRequest request, {required bool suggestTime}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RejectDialog(
        request: request,
        suggestTime: suggestTime,
      ),
    );

    if (result != null && result['reason'] != null) {
      safeSetState(() => _isProcessing = true);
      try {
        final reason = result['reason'] as String;
        final suggestedDate = result['date'] as DateTime?;
        final suggestedTime = result['time'] as String?;

        String rejectionReason = reason;
        if (suggestedDate != null && suggestedTime != null) {
          final dateStr =
              '${suggestedDate.day}/${suggestedDate.month}/${suggestedDate.year}';
          rejectionReason =
              '$reason\n\nSuggested alternative time: $dateStr at $suggestedTime';
        }

        if (request.isTrial) {
          await BookingService.rejectTrialRequest(
            request.id,
            reason: rejectionReason,
          );
        } else {
          await BookingService.rejectBookingRequest(
            request.id,
            reason: rejectionReason,
          );
        }

        if (mounted) {
          BrandedSnackBar.showSuccess(
            context,
            suggestTime && suggestedDate != null
                ? 'Request rejected with reschedule suggestion'
                : 'Request rejected',
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        LogService.error('Error rejecting request: $e');
        if (mounted) {
          BrandedSnackBar.showError(context, 'Failed to reject request: $e');
          safeSetState(() => _isProcessing = false);
        }
      }
    }
  }
}

// Approve Dialog
class _ApproveDialog extends StatefulWidget {
  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve Request',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add an optional message to the student:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'E.g., "Looking forward to working with you!"',
                filled: true,
                fillColor: AppTheme.softBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.softBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.softBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.softBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, _notesController.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Approve',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Reject Dialog
class _RejectDialog extends StatefulWidget {
  final BookingRequest request;
  final bool suggestTime;

  const _RejectDialog({
    required this.request,
    required this.suggestTime,
  });

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reasonController = TextEditingController();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _hasText = false;
  DateTime? _suggestedDate;
  String? _suggestedTime;
  final List<String> _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'
  ];

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() {
      if (mounted) {
        setState(() {
          _hasText = _reasonController.text.trim().isNotEmpty;
        });
      }
    });
    if (widget.suggestTime) {
      _currentPage = 1; // Start on time selection page if rescheduling
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.suggestTime ? 'Reschedule Request' : 'Reject Request',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Page 1: Reason
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please provide a reason (required):',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'E.g., "Schedule conflict"',
                          filled: true,
                          fillColor: AppTheme.softBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.softBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                        ),
                        autofocus: true,
                      ),
                    ],
                  ),
                  // Page 2: Time selection
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select a better date and time:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _suggestedDate ?? DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() => _suggestedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.softBackground,
                            border: Border.all(color: AppTheme.softBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 20, color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Text(
                                _suggestedDate != null
                                    ? '${_suggestedDate!.day}/${_suggestedDate!.month}/${_suggestedDate!.year}'
                                    : 'Select date',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Time:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _timeSlots.map((time) {
                          final isSelected = _suggestedTime == time;
                          return ChoiceChip(
                            label: Text(time),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _suggestedTime = selected ? time : null);
                            },
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected ? Colors.white : AppTheme.textDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_currentPage == 0) {
                        Navigator.pop(context);
                      } else {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        setState(() => _currentPage = 0);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.softBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage == 0 ? 'Cancel' : 'Back',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _currentPage == 0
                        ? (_hasText
                            ? () {
                                if (widget.suggestTime) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  setState(() => _currentPage = 1);
                                } else {
                                  Navigator.pop(context, {
                                    'reason': _reasonController.text.trim(),
                                    'date': null,
                                    'time': null,
                                  });
                                }
                              }
                            : null)
                        : ((_suggestedDate != null && _suggestedTime != null)
                            ? () {
                                Navigator.pop(context, {
                                  'reason': _reasonController.text.trim(),
                                  'date': _suggestedDate,
                                  'time': _suggestedTime,
                                });
                              }
                            : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == 0
                          ? (widget.suggestTime ? 'Next' : 'Reject')
                          : 'Confirm',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

