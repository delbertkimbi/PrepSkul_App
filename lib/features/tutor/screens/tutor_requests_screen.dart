import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/branded_snackbar.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../features/booking/models/booking_request_model.dart';
import '../../../features/booking/services/booking_service.dart';
import '../../../features/booking/services/recurring_session_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'tutor_request_detail_full_screen.dart';


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
      // ALWAYS load ALL requests first (for accurate counts)
      // Then filter for display based on selected filter
      final allRequests = await BookingService.getTutorBookingRequests(
        status: null, // Always get all requests regardless of filter
      );

      // Filter requests based on selected filter
      List<BookingRequest> filteredRequests;
      if (_selectedFilter == 'all') {
        filteredRequests = List.from(allRequests);
      } else {
        filteredRequests = allRequests.where((r) => r.status == _selectedFilter).toList();
      }

      // Sort by priority for "all" tab: pending with conflicts first, then pending, then others
      List<BookingRequest> sortedRequests = filteredRequests;
      if (_selectedFilter == 'all') {
        sortedRequests = List.from(filteredRequests);
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
        _allRequests = allRequests; // Store ALL requests for accurate counts
        _requests = sortedRequests; // Store filtered/sorted requests for display
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RejectDialog(request: request),
    );

    if (result != null && result['reason'] != null && (result['reason'] as String).isNotEmpty) {
      try {
        final reason = result['reason'] as String;
        final suggestTime = result['suggestTime'] as bool? ?? false;
        final suggestedDate = result['date'] as DateTime?;
        final suggestedTime = result['time'] as String?;
        
        // Build rejection reason with suggested time if provided
        String rejectionReason = reason;
        if (suggestTime && suggestedDate != null && suggestedTime != null) {
          final dateStr = '${suggestedDate.day}/${suggestedDate.month}/${suggestedDate.year}';
          rejectionReason = '$reason\n\nSuggested alternative time: $dateStr at $suggestedTime';
        }
        
        if (request.isTrial) {
          await BookingService.rejectTrialRequest(request.id, reason: rejectionReason);
        } else {
          await BookingService.rejectBookingRequest(request.id, reason: rejectionReason);
        }

        if (mounted) {
          BrandedSnackBar.show(
            context,
            message: suggestTime && suggestedDate != null 
                ? 'Request rejected with alternative time suggestion'
                : 'Request rejected',
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
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, index) => ShimmerLoading.listTile(),
                  )
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
    return EmptyStateWidget.noRequests();
  }

  Widget _buildRequestCard(BookingRequest request) {
    final typeLower = request.studentType.toLowerCase();
    final isStudent = typeLower == 'learner' || typeLower == 'student';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.softBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                            fontSize: 16,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Student Name & Type
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
                      Text(
                        isStudent ? 'Student' : 'Parent',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: request.status == 'pending'
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : request.status == 'approved'
                            ? AppTheme.accentGreen.withOpacity(0.1)
                            : AppTheme.textMedium.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: request.status == 'pending'
                          ? AppTheme.primaryColor
                          : request.status == 'approved'
                              ? AppTheme.accentGreen
                              : AppTheme.textMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Simple info display
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: AppTheme.textMedium),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.isTrial
                        ? (request.scheduledDate != null
                            ? '${request.scheduledDate!.day}/${request.scheduledDate!.month}/${request.scheduledDate!.year}'
                            : 'Trial Session')
                        : '${request.frequency}x per week',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: AppTheme.textMedium),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.getTimeRange(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // View Details Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _navigateToRequestDetail(request),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRequestDetail(BookingRequest request) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TutorRequestDetailFullScreen(request: request),
      ),
    );
    if (result == true) {
      _loadRequests();
    }
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

  Widget _buildEnhancedInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isOutlined,
    required VoidCallback onPressed,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 2),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 2,
          shadowColor: color.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.primaryColor;
      case 'approved':
        return AppTheme.accentGreen;
      case 'rejected':
        return AppTheme.textMedium;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.accentGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Approve Request',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Add an optional message to the student:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'E.g., "Looking forward to working with you!"',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _notesController.text.trim()),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      'Approve',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shadowColor: AppTheme.accentGreen.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
  
  const _RejectDialog({required this.request});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reasonController = TextEditingController();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _hasText = false;
  bool _wantsToSuggestTime = false;
  DateTime? _suggestedDate;
  String? _suggestedTime;
  final List<String> _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00'
  ];

  @override
  void initState() {
    super.initState();
    // Listen to text changes to update button state
    _reasonController.addListener(() {
      if (mounted) {
        setState(() {
          _hasText = _reasonController.text.trim().isNotEmpty;
        });
      }
    });
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _currentPage == 0 ? Icons.close_rounded : Icons.schedule_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _currentPage == 0 ? 'Reject Request' : 'Suggest Better Time',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.maxFinite,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Page 1: Reason and suggest time option
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please provide a reason for rejection (required):',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'E.g., "Schedule conflict with existing sessions"',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        autofocus: true,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      // Option to suggest better time
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue[200]!,
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: _wantsToSuggestTime,
                          onChanged: (value) {
                            setState(() {
                              _wantsToSuggestTime = value ?? false;
                            });
                          },
                          title: Text(
                            'Suggest a better time',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),
                  // Page 2: Date and time selection
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
                      // Date picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _suggestedDate ?? DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() {
                              _suggestedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.primaryColor),
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
                      // Time picker
                      Text(
                        'Time:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
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
                              setState(() {
                                _suggestedTime = selected ? time : null;
                              });
                            },
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected ? Colors.white : AppTheme.textDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
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
                        setState(() {
                          _currentPage = 0;
                        });
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      _currentPage == 0 ? 'Cancel' : 'Back',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _currentPage == 0
                        ? (_hasText
                            ? () {
                                if (_wantsToSuggestTime) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  setState(() {
                                    _currentPage = 1;
                                  });
                                } else {
                                  Navigator.pop(context, {
                                    'reason': _reasonController.text.trim(),
                                    'suggestTime': false,
                                  });
                                }
                              }
                            : null)
                        : ((_suggestedDate != null && _suggestedTime != null)
                            ? () {
                                Navigator.pop(context, {
                                  'reason': _reasonController.text.trim(),
                                  'suggestTime': true,
                                  'date': _suggestedDate,
                                  'time': _suggestedTime,
                                });
                              }
                            : null),
                    icon: Icon(
                      _currentPage == 0 ? Icons.close_rounded : Icons.check_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _currentPage == 0 ? 'Reject' : 'Confirm',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shadowColor: Colors.red.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

// Request Details Sheet
class _RequestDetailsSheet extends StatefulWidget {
  final BookingRequest request;

  const _RequestDetailsSheet({required this.request});

  @override
  State<_RequestDetailsSheet> createState() => _RequestDetailsSheetState();
}

class _RequestDetailsSheetState extends State<_RequestDetailsSheet> {
  Map<String, dynamic>? _learnerProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadLearnerProfile();
  }

  Future<void> _loadLearnerProfile() async {
    try {
      final profile = await SupabaseService.client
          .from('learner_profiles')
          .select('*')
          .eq('user_id', widget.request.studentId)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _learnerProfile = profile as Map<String, dynamic>?;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      LogService.warning('Error loading learner profile: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

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
              _buildInfoRow(Icons.person, widget.request.studentName),
              const SizedBox(height: 12),
              
              // Schedule Info (Trial vs Recurring)
              if (widget.request.isTrial) ...[
                _buildInfoRow(
                  Icons.calendar_today,
                  'Trial Session • ${widget.request.scheduledDate != null ? '${widget.request.scheduledDate!.day}/${widget.request.scheduledDate!.month}/${widget.request.scheduledDate!.year}' : widget.request.getDaysSummary()}',
                ),
                if (widget.request.subject != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.menu_book, 'Subject: ${widget.request.subject}'),
                ],
                if (widget.request.durationMinutes != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.timer,
                    'Duration: ${widget.request.durationMinutes} minutes',
                  ),
                ],
                if (widget.request.trialGoal != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.flag, 'Goal: ${_cleanTrialGoal(widget.request.trialGoal!)}'),
                ],
                if (widget.request.learnerChallenges != null && widget.request.learnerChallenges!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.help_outline, 'Challenges: ${widget.request.learnerChallenges}'),
                ],
              ] else ...[
                _buildInfoRow(
                  Icons.calendar_today,
                  '${widget.request.frequency}x per week • ${widget.request.getDaysSummary()}',
                ),
              ],
              
              const SizedBox(height: 12),
              _buildInfoRow(Icons.access_time, widget.request.getTimeRange()),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.location_on,
                _formatLocation(widget.request.location, widget.request.address),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.payment,
                '${_formatPaymentPlan(widget.request.paymentPlan)} • ${_formatCurrency(widget.request.monthlyTotal)}',
              ),
              // Student Onboarding Details (if available)
              if (_learnerProfile != null) ...[
                const SizedBox(height: 24),
                Divider(),
                const SizedBox(height: 16),
                Text(
                  'Student Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location
                if (_learnerProfile!['location'] != null && 
                    (_learnerProfile!['location'] as String).isNotEmpty) ...[
                  _buildInfoRow(
                    Icons.location_city,
                    'Location: ${_learnerProfile!['location']}',
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Subjects of Interest
                if (_learnerProfile!['subjects_of_interest'] != null) ...[
                  Builder(
                    builder: (context) {
                      final subjects = _learnerProfile!['subjects_of_interest'];
                      if (subjects is List && subjects.isNotEmpty) {
                        return Column(
                          children: [
                            _buildInfoRow(
                              Icons.menu_book,
                              'Subjects of Interest: ${subjects.join(', ')}',
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      } else if (subjects is String && subjects.isNotEmpty) {
                        return Column(
                          children: [
                            _buildInfoRow(
                              Icons.menu_book,
                              'Subjects of Interest: $subjects',
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
                
                // Learning Goals
                if (_learnerProfile!['learning_goals'] != null && 
                    (_learnerProfile!['learning_goals'] as String).isNotEmpty) ...[
                  _buildInfoRow(
                    Icons.flag,
                    'Learning Goals: ${_learnerProfile!['learning_goals']}',
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Challenges
                if (_learnerProfile!['challenges'] != null && 
                    (_learnerProfile!['challenges'] as String).isNotEmpty) ...[
                  _buildInfoRow(
                    Icons.help_outline,
                    'Challenges: ${_learnerProfile!['challenges']}',
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Education Level
                if (_learnerProfile!['education_level'] != null && 
                    (_learnerProfile!['education_level'] as String).isNotEmpty) ...[
                  _buildInfoRow(
                    Icons.school,
                    'Education Level: ${_learnerProfile!['education_level']}',
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Learning Path
                if (_learnerProfile!['learning_path'] != null && 
                    (_learnerProfile!['learning_path'] as String).isNotEmpty) ...[
                  _buildInfoRow(
                    Icons.trending_up,
                    'Learning Path: ${_learnerProfile!['learning_path']}',
                  ),
                  const SizedBox(height: 12),
                ],
              ] else if (!_isLoadingProfile) ...[
                const SizedBox(height: 24),
                Divider(),
                const SizedBox(height: 16),
                Text(
                  'Student Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No additional student information available',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              // Status
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: _getStatusColor(widget.request.status),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Status: ${widget.request.status.toUpperCase()}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(widget.request.status),
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

  /// Clean trial goal text by removing internal reschedule request notes
  String _cleanTrialGoal(String goal) {
    // Remove reschedule request notes that were accidentally added to trial goals
    // Pattern: [RESCHEDULE REQUEST: ...]
    final reschedulePattern = RegExp(r'\n?\n?\[RESCHEDULE REQUEST:.*?\]', dotAll: true);
    return goal.replaceAll(reschedulePattern, '').trim();
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
        return AppTheme.primaryColor;
      case 'approved':
        return AppTheme.accentGreen;
      case 'rejected':
        return AppTheme.textMedium;
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