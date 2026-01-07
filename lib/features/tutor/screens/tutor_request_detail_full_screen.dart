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
      ],
    );
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        children: [
          if (request.isTrial) ...[
            _buildDetailRow(Icons.calendar_today, 'Type', 'Trial Session'),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
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

  Widget _buildActionButtons(BookingRequest request) {
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
            // Approve Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _handleApprove(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Approve',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // Reject and Reschedule Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _handleReject(request, suggestTime: false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.textMedium),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Reject',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
                ),
                if (request.isTrial) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _handleReject(request, suggestTime: true),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Reschedule',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
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

