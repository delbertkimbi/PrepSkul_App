import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/services/log_service.dart';
import '../../../core/widgets/branded_snackbar.dart';
import '../../../features/booking/models/booking_request_model.dart';
import '../../../features/booking/services/booking_service.dart';
import '../../../features/booking/services/recurring_session_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';


class TutorRequestsScreen extends StatefulWidget {
  const TutorRequestsScreen({Key? key}) : super(key: key);

  @override
  State<TutorRequestsScreen> createState() => _TutorRequestsScreenState();
}

class _TutorRequestsScreenState extends State<TutorRequestsScreen> {
  List<BookingRequest> _requests = [];
  List<BookingRequest> _allRequests =
      []; // Store all requests for accurate counts
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    safeSetState(() => _isLoading = true);
    try {
      final requests = await BookingService.getTutorBookingRequests(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      // Sort by priority for "all" tab: pending with conflicts first, then pending, then others
      List<BookingRequest> sortedRequests = requests;
      if (_selectedFilter == 'all') {
        sortedRequests = List.from(requests);
        sortedRequests.sort((a, b) {
          // Pending with conflicts first
          if (a.isPending && a.hasConflict && !(b.isPending && b.hasConflict))
            return -1;
          if (!(a.isPending && a.hasConflict) && b.isPending && b.hasConflict)
            return 1;

          // Then pending without conflicts
          if (a.isPending && !b.isPending) return -1;
          if (!a.isPending && b.isPending) return 1;

          // Then approved
          if (a.status == 'approved' && b.status != 'approved') return -1;
          if (a.status != 'approved' && b.status == 'approved') return 1;

          // Then by creation date (newest first)
          return b.createdAt.compareTo(a.createdAt);
        });
      }

      safeSetState(() {
        _allRequests = requests; // Store all requests
        _requests = sortedRequests; // Store filtered/sorted requests
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading requests: $e');
      safeSetState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleApprove(BookingRequest request) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ApproveDialog(),
    );

    if (result != null) {
      try {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        }

        if (request.isTrial) {
          await BookingService.approveTrialRequest(
            request.id,
            responseNotes: result.isEmpty ? null : result,
          );
          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            BrandedSnackBar.showSuccess(
              context,
              'Trial session approved! Payment request sent.',
              duration: const Duration(seconds: 3),
            );
          }
        } else {
          // Step 1: Approve the booking request
          final approvedRequest = await BookingService.approveBookingRequest(
            request.id,
            responseNotes: result.isEmpty ? null : result,
          );

          // Step 2: Get payment request ID (created during approval)
          String? paymentRequestId;
          try {
            paymentRequestId = await PaymentRequestService.getPaymentRequestIdByBookingRequestId(
              request.id,
            );
            if (paymentRequestId != null) {
              LogService.success('Found payment request ID: $paymentRequestId');
            }
          } catch (e) {
            LogService.warning('Failed to get payment request ID: $e');
          }

          // Step 3: Create recurring session from approved request
          try {
            await RecurringSessionService.createRecurringSessionFromBooking(
              approvedRequest,
              paymentRequestId: paymentRequestId,
            );
            LogService.success('Recurring session created successfully');
          } catch (sessionError) {
            LogService.warning('Error creating recurring session: $sessionError');
            // Don't fail the approval if session creation fails
            // The request is already approved, session can be created manually later
          }

          // Close loading dialog
          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            BrandedSnackBar.showSuccess(
              context,
              'Request approved! Recurring sessions created.',
              duration: const Duration(seconds: 3),
            );
          }
        }
        _loadRequests(); // Refresh list
      } catch (e) {
        LogService.error('Error approving request: $e');

        // Close loading dialog if still open
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog if open
        }

        if (mounted) {
          BrandedSnackBar.showError(
            context,
            'Failed to approve request: $e',
          );
        }
      }
    }
  }

  Future<void> _handleReject(BookingRequest request) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _RejectDialog(),
    );

    if (result != null && result.isNotEmpty) {
      try {
        if (request.isTrial) {
          await BookingService.rejectTrialRequest(request.id, reason: result);
        } else {
          await BookingService.rejectBookingRequest(request.id, reason: result);
        }

        if (mounted) {
          BrandedSnackBar.show(
            context,
            message: 'Request rejected',
            backgroundColor: Colors.orange,
            icon: Icons.info_outline,
          );
        }
        _loadRequests(); // Refresh list
      } catch (e) {
        LogService.error('Error rejecting request: $e');
        if (mounted) {
          BrandedSnackBar.showError(
            context,
            'Failed to reject request: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // No back button in bottom nav
        title: Text(
          'Requests',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips (like notification screen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildFilterChip('all', 'All (${_getCountForStatus('all')})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'pending',
                    'Pending (${_getCountForStatus('pending')})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'approved',
                    'Approved (${_getCountForStatus('approved')})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'rejected',
                    'Rejected (${_getCountForStatus('rejected')})',
                  ),
                ],
              ),
            ),
          ),
          // Requests List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadRequests,
                        color: AppTheme.primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            return _buildRequestCard(_requests[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        safeSetState(() {
          _selectedFilter = filter;
        });
        _loadRequests();
      },
      selectedColor: AppTheme.primaryColor, // Deep blue background
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected
            ? Colors.white
            : AppTheme.textDark, // White text on selected
      ),
    );
  }

  int _getCountForStatus(String status) {
    if (status == 'all') return _allRequests.length;
    return _allRequests.where((r) => r.status == status).length;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textLight),
            const SizedBox(height: 16),
            Text(
              'No requests yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Student requests will appear here',
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

  Widget _buildRequestCard(BookingRequest request) {
    final hasConflict = request.hasConflict && request.isPending;
    final typeLower = request.studentType.toLowerCase();
    final isStudent = typeLower == 'learner' || typeLower == 'student';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasConflict
              ? Colors.orange.withOpacity(0.5)
              : _getStatusColor(request.status).withOpacity(0.3),
          width: hasConflict ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conflict Warning Banner (top of card like marketing design)
              if (hasConflict) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange[300]!, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Schedule conflict detected',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // Header: Student info + Status
              Row(
                children: [
                  // Student Avatar
                  CircleAvatar(
                    radius: 24,
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
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Student Name & Type badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.studentName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (isStudent
                                    ? AppTheme.primaryColor
                                    : Colors.purple)
                                .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isStudent ? 'STUDENT' : 'PARENT',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  isStudent ? AppTheme.primaryColor : Colors.purple,
                            ),
                          ),  
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      request.status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(request.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Schedule Info
              if (request.isTrial) ...[
                _buildInfoRow(
                  Icons.calendar_today,
                  'Trial Session • ${request.scheduledDate != null ? '${request.scheduledDate!.day}/${request.scheduledDate!.month}/${request.scheduledDate!.year}' : request.getDaysSummary()}',
                ),
                if (request.subject != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.menu_book, 'Subject: ${request.subject}'),
                ],
                if (request.durationMinutes != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.timer,
                    'Duration: ${request.durationMinutes} minutes',
                  ),
                ],
              ] else ...[
                _buildInfoRow(
                  Icons.calendar_today,
                  '${request.frequency}x per week • ${request.getDaysSummary()}',
                ),
              ],
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, request.getTimeRange()),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.location_on,
                _formatLocation(request.location, request.address),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.payment,
                '${_formatPaymentPlan(request.paymentPlan)} • ${_formatCurrency(request.monthlyTotal)}',
              ),
              // Action Buttons (only for pending)
              if (request.isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleReject(request),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Reject',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _handleApprove(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Approve',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textDark),
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
        return AppTheme.accentGreen;
      case 'rejected':
        return Colors.red;
      default:
        return AppTheme.textMedium;
    }
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

  void _showRequestDetails(BookingRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RequestDetailsSheet(request: request),
    );
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
    return AlertDialog(
      title: Text('Approve Request', style: GoogleFonts.poppins()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add an optional message to the student:',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'E.g., "Looking forward to working with you!"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _notesController.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: Text('Approve', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// Reject Dialog
class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reasonController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    // Listen to text changes to update button state
    _reasonController.addListener(() {
      safeSetState(() {
        _hasText = _reasonController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reject Request', style: GoogleFonts.poppins()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please provide a reason for rejection (required):',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'E.g., "Schedule conflict with existing sessions"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            autofocus: true, // Auto-focus the text field
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _hasText
              ? () => Navigator.pop(context, _reasonController.text.trim())
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[600],
          ),
          child: Text('Reject', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// Request Details Sheet
class _RequestDetailsSheet extends StatelessWidget {
  final BookingRequest request;

  const _RequestDetailsSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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
              // Title
              Text(
                'Request Details',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 24),
              // Student Info
              _buildInfoRow(Icons.person, request.studentName),
              const SizedBox(height: 12),
              
              // Schedule Info (Trial vs Recurring)
              if (request.isTrial) ...[
                _buildInfoRow(
                  Icons.calendar_today,
                  'Trial Session • ${request.scheduledDate != null ? '${request.scheduledDate!.day}/${request.scheduledDate!.month}/${request.scheduledDate!.year}' : request.getDaysSummary()}',
                ),
                if (request.subject != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.menu_book, 'Subject: ${request.subject}'),
                ],
                if (request.durationMinutes != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.timer,
                    'Duration: ${request.durationMinutes} minutes',
                  ),
                ],
                if (request.trialGoal != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.flag, 'Goal: ${request.trialGoal}'),
                ],
              ] else ...[
                _buildInfoRow(
                  Icons.calendar_today,
                  '${request.frequency}x per week • ${request.getDaysSummary()}',
                ),
              ],
              
              const SizedBox(height: 12),
              _buildInfoRow(Icons.access_time, request.getTimeRange()),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.location_on,
                _formatLocation(request.location, request.address),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.payment,
                '${_formatPaymentPlan(request.paymentPlan)} • ${_formatCurrency(request.monthlyTotal)}',
              ),
              // Status
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: _getStatusColor(request.status),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Status: ${request.status.toUpperCase()}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(request.status),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textMedium),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
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
        return AppTheme.accentGreen;
      case 'rejected':
        return Colors.red;
      default:
        return AppTheme.textMedium;
    }
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
}
