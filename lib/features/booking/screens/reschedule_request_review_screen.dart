import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/services/session_reschedule_service.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';

class RescheduleRequestReviewScreen extends StatefulWidget {
  final String rescheduleRequestId;
  final String? sessionId;
  final String? sessionType;

  const RescheduleRequestReviewScreen({
    Key? key,
    required this.rescheduleRequestId,
    this.sessionId,
    this.sessionType,
  }) : super(key: key);

  @override
  State<RescheduleRequestReviewScreen> createState() => _RescheduleRequestReviewScreenState();
}

class _RescheduleRequestReviewScreenState extends State<RescheduleRequestReviewScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _request;
  Map<String, dynamic>? _session;
  String? _tutorName;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('session_reschedule_requests')
          .select('*')
          .eq('id', widget.rescheduleRequestId)
          .maybeSingle();

      if (response == null) {
        if (mounted) {
        BrandedSnackBar.showError(context, 'Reschedule request not found');
          Navigator.pop(context);
        }
        return;
      }

      setState(() => _request = response);

      // Load session details
      final sessionId = response['session_id'] as String;
      final sessionType = response['session_type'] as String;
      
      final tableName = sessionType == 'recurring' ? 'individual_sessions' : 'trial_sessions';
      final sessionResponse = await SupabaseService.client
          .from(tableName)
          .select('*')
          .eq('id', sessionId)
          .maybeSingle();

      if (sessionResponse != null) {
        setState(() => _session = sessionResponse);
        
        // Load tutor name
        final tutorId = sessionResponse['tutor_id'] as String;
        final tutorProfile = await SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('id', tutorId)
            .maybeSingle();
        
        setState(() => _tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor');
      }
    } catch (e) {
      LogService.error('Error loading reschedule request: $e');
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to load reschedule request');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAccept() async {
    if (_request == null) return;

    setState(() => _isLoading = true);
    try {
      await SessionRescheduleService.approveRescheduleRequest(widget.rescheduleRequestId);
      
      if (mounted) {
        BrandedSnackBar.showSuccess(context, 'Reschedule request accepted. Session time updated.');
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      LogService.error('Error accepting reschedule request: $e');
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to accept reschedule request: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleReject() async {
    if (_request == null) return;

    // Show dialog to get rejection reason
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectReasonDialog(),
    );

    if (reason == null) return; // User cancelled

    setState(() => _isLoading = true);
    try {
      await SessionRescheduleService.rejectRescheduleRequest(
        widget.rescheduleRequestId,
        reason: reason,
      );
      
      if (mounted) {
        BrandedSnackBar.showInfo(context, 'Reschedule request rejected. Session has been cancelled.');
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      LogService.error('Error rejecting reschedule request: $e');
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to reject reschedule request: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, MMMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'N/A';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Review Reschedule Request',
          style: GoogleFonts.poppins(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading && _request == null
          ? const Center(child: CircularProgressIndicator())
          : _request == null
              ? const Center(child: Text('Request not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reschedule Request',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'From: $_tutorName',
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
                      ),
                      const SizedBox(height: 24),

                      // Current Schedule
                      Text(
                        'Current Schedule',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.softBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.softBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'Date',
                              _formatDate(_request!['original_date'] as String?),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Time',
                              _formatTime(_request!['original_time'] as String?),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Proposed Schedule
                      Text(
                        'Proposed New Schedule',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'Date',
                              _formatDate(_request!['proposed_date'] as String?),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Time',
                              _formatTime(_request!['proposed_time'] as String?),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reason
                      if (_request!['reason'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reason',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.softBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.softBorder),
                              ),
                              child: Text(
                                _request!['reason'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // Additional Notes
                      if (_request!['additional_notes'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Additional Notes',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.softBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.softBorder),
                              ),
                              child: Text(
                                _request!['additional_notes'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // Action Buttons
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _handleReject,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.red),
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleAccept,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Accept',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Note: Rejecting this request will cancel the session.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textMedium,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMedium,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Reject Reschedule Request',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please provide a reason for rejecting this reschedule request. The session will be cancelled.',
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _reasonController.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: Text('Reject', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}

