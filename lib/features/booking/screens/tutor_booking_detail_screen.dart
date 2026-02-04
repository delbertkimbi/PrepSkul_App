import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/services/recurring_session_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';


/// Tutor Booking Detail Screen
///
/// Shows full details of a booking request
/// Allows tutor to approve/reject with notes
class TutorBookingDetailScreen extends StatefulWidget {
  final BookingRequest request;

  const TutorBookingDetailScreen({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  State<TutorBookingDetailScreen> createState() => _TutorBookingDetailScreenState();
}

class _TutorBookingDetailScreenState extends State<TutorBookingDetailScreen> {
  final TextEditingController _responseNotesController = TextEditingController();
  final TextEditingController _rejectionReasonController = TextEditingController();
  bool _isLoading = false;
  bool _showRejectDialog = false;

  @override
  void dispose() {
    _responseNotesController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _approveRequest() async {
    if (_isLoading) return;

    safeSetState(() {
      _isLoading = true;
    });

    try {
      // Approve the request
      final approvedRequest = await BookingService.approveBookingRequest(
        widget.request.id,
        responseNotes: _responseNotesController.text.trim().isNotEmpty
            ? _responseNotesController.text.trim()
            : null,
      );

      // Note: Recurring session and payment request are already created
      // in BookingService.approveBookingRequest() - no need to create again here

      // Send notification to student
      await NotificationService.createNotification(
        userId: widget.request.studentId,
        type: 'booking_approved',
        title: 'Booking Request Approved',
        message: '${widget.request.tutorName} has approved your booking request',
        data: {'request_id': widget.request.id, 'tutor_id': widget.request.tutorId},
      );

      if (!mounted) return;

      // Show success
      BrandedSnackBar.showSuccess(
        context,
        'Request approved successfully',
      );

      // Navigate back
      Navigator.pop(context, true); // Return true to indicate refresh needed
    } catch (e) {
      if (!mounted) return;
      BrandedSnackBar.showError(
        context,
        'Error: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        safeSetState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rejectRequest() async {
    if (_isLoading || _rejectionReasonController.text.trim().isEmpty) {
      if (_rejectionReasonController.text.trim().isEmpty) {
        BrandedSnackBar.show(
          context,
          message: 'Please provide a reason for rejection',
          backgroundColor: Colors.orange,
          icon: Icons.info_outline,
        );
      }
      return;
    }

    safeSetState(() {
      _isLoading = true;
      _showRejectDialog = false;
    });

    try {
      // Reject the request
      await BookingService.rejectBookingRequest(
        widget.request.id,
        reason: _rejectionReasonController.text.trim(),
      );

      // Send notification to student
      await NotificationService.createNotification(
        userId: widget.request.studentId,
        type: 'booking_rejected',
        title: 'Booking Request Rejected',
        message: '${widget.request.tutorName} has rejected your booking request',
        data: {'request_id': widget.request.id, 'reason': _rejectionReasonController.text.trim()},
      );

      if (!mounted) return;

      // Show success
      BrandedSnackBar.show(
        context,
        message: 'Request rejected',
        backgroundColor: Colors.orange,
        icon: Icons.info_outline,
      );

      // Navigate back
      Navigator.pop(context, true); // Return true to indicate refresh needed
    } catch (e) {
      if (!mounted) return;
      BrandedSnackBar.showError(
        context,
        'Error: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        safeSetState(() {
          _isLoading = false;
        });
      }
    }
  }


  Widget _buildStudentInfoCard(BookingRequest request) {
    final hasMultipleLearners = request.learnerLabels != null && request.learnerLabels!.isNotEmpty;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: request.studentAvatarUrl != null && request.studentAvatarUrl!.isNotEmpty
                      ? NetworkImage(request.studentAvatarUrl!)
                      : null,
                  onBackgroundImageError: request.studentAvatarUrl != null && request.studentAvatarUrl!.isNotEmpty
                      ? (exception, stackTrace) {
                          // Image failed to load, will show fallback
                        }
                      : null,
                  child: request.studentAvatarUrl == null || request.studentAvatarUrl!.isEmpty
                      ? Text(
                          request.studentName.isNotEmpty
                              ? request.studentName[0].toUpperCase()
                              : 'S',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.studentName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.studentType == 'parent' ? 'Parent' : 'Student',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Show multi-learner info if applicable
            if (hasMultipleLearners) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Learners for this booking:',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...request.learnerLabels!.map((name) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
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
                                const SizedBox(width: 8),
                                Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
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

  Widget _buildRequestDetailsCard(BookingRequest request) {
    final isOnsite = request.location == 'onsite' || request.location == 'hybrid';
    final estimatedTransportationCost = request.estimatedTransportationCost;
    final frequency = request.frequency;
    final sessionsPerMonth = frequency * 4;
    final monthlyTransportationTotal = (estimatedTransportationCost != null && estimatedTransportationCost > 0 && isOnsite)
        ? estimatedTransportationCost * sessionsPerMonth
        : 0.0;
    final totalMonthlyPayment = request.monthlyTotal + monthlyTransportationTotal;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Frequency', '${request.frequency} sessions/week'),
            _buildInfoRow('Location', request.location.toUpperCase()),
            if (request.address != null)
              _buildInfoRow('Address', request.address!),
            if (request.locationDescription != null)
              _buildInfoRow('Location Description', request.locationDescription!),
            _buildInfoRow('Payment Plan', request.paymentPlan.toUpperCase()),
            const SizedBox(height: 8),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            // Payment breakdown
            Text(
              'Payment Breakdown',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Session Fee (Monthly)', '${request.monthlyTotal.toStringAsFixed(0)} XAF', 
              valueColor: Colors.green[700]),
            if (isOnsite && monthlyTransportationTotal > 0) ...[
              const SizedBox(height: 4),
              _buildInfoRow('Transportation (Monthly)', '${monthlyTransportationTotal.toStringAsFixed(0)} XAF',
                valueColor: Colors.orange[700]),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Text(
                  '${estimatedTransportationCost?.toStringAsFixed(0) ?? '0'} XAF per session (round trip)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Monthly Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  '${totalMonthlyPayment.toStringAsFixed(0)} XAF',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            if (isOnsite && monthlyTransportationTotal > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Transportation cost is parent compensation. Platform fee (15%) applies only to session fee.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange[900],
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

  Widget _buildScheduleCard(BookingRequest request) {
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
            ...request.days.map((day) {
              final time = request.times[day];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      '$day: ${time ?? 'Not set'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(BookingRequest request) {
    final isOnsite = request.location == 'onsite' || request.location == 'hybrid';
    final estimatedTransportationCost = request.estimatedTransportationCost ?? 0.0;
    final frequency = request.frequency;
    final sessionsPerMonth = frequency * 4;
    final monthlyTransportationTotal = (isOnsite && estimatedTransportationCost > 0)
        ? estimatedTransportationCost * sessionsPerMonth
        : 0.0;
    final totalMonthlyPayment = request.monthlyTotal + monthlyTransportationTotal;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Payment Plan', request.paymentPlan.toUpperCase()),
            _buildInfoRow('Session Fee (Monthly)', '${request.monthlyTotal.toStringAsFixed(0)} XAF'),
            if (isOnsite && monthlyTransportationTotal > 0) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Transportation (Monthly)', '${monthlyTransportationTotal.toStringAsFixed(0)} XAF'),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${estimatedTransportationCost.toStringAsFixed(0)} XAF per session (round trip)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange[900],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Parent Pays:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.green[900],
                    ),
                  ),
                  Text(
                    '${totalMonthlyPayment.toStringAsFixed(0)} XAF',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.green[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Student will pay ${request.paymentPlan} after you approve',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictWarning(BookingRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.conflictDetails ?? 'Schedule conflict detected',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.orange[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseNotesField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Response Notes (Optional)',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _responseNotesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add a message to the student...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading
                ? null
                : () {
                    safeSetState(() {
                      _showRejectDialog = true;
                    });
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Reject',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _approveRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Approve Request',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BookingRequest request) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = request.status.toUpperCase();
        statusIcon = Icons.pending;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  if (request.rejectionReason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${request.rejectionReason}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                  if (request.tutorResponse != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Notes: ${request.tutorResponse}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textMedium,
                      ),
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

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
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
                fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
                color: valueColor ?? AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showRejectDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRejectDialogDialog(context);
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Booking Request Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Info Card
                  _buildStudentInfoCard(widget.request),
                  const SizedBox(height: 20),

                  // Request Details Card
                  _buildRequestDetailsCard(widget.request),
                  const SizedBox(height: 20),

                  // Schedule Card
                  _buildScheduleCard(widget.request),
                  const SizedBox(height: 20),

                  // Payment Card
                  _buildPaymentCard(widget.request),
                  const SizedBox(height: 20),

                  // Conflict Warning (if any)
                  if (widget.request.hasConflict) _buildConflictWarning(widget.request),
                  if (widget.request.hasConflict) const SizedBox(height: 20),

                  // Action Buttons (only if pending)
                  if (widget.request.status == 'pending') ...[
                    _buildResponseNotesField(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                  ] else ...[
                    _buildStatusCard(widget.request),
                  ],
                ],
              ),
            ),
    );
  }

  void _showRejectDialogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Request',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for rejecting this request:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              safeSetState(() {
                _showRejectDialog = false;
                _rejectionReasonController.clear();
              });
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectRequest();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }
}
