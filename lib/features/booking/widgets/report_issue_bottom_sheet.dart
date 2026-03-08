import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/booking/services/safety_incident_service.dart';

/// Bottom sheet for reporting a safety/issue for a session.
/// Only use with [sessionId] = individual_sessions.id; [role] = tutor | parent | learner.
void showReportIssueBottomSheet({
  required BuildContext context,
  required String sessionId,
  required String role,
  VoidCallback? onReported,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReportIssueSheet(
      sessionId: sessionId,
      role: role,
      onReported: onReported,
    ),
  );
}

class _ReportIssueSheet extends StatefulWidget {
  final String sessionId;
  final String role;
  final VoidCallback? onReported;

  const _ReportIssueSheet({
    required this.sessionId,
    required this.role,
    this.onReported,
  });

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  String? _selectedType;
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final type = _selectedType ?? SafetyIncidentService.incidentTypes.first['value']!;
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add a short description.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final severity = type == 'felt_unsafe' ? 'critical' : 'warning';
      await SafetyIncidentService.createIncident(
        sessionId: widget.sessionId,
        role: widget.role,
        severity: severity,
        type: type,
        message: message,
      );
      await NotificationHelperService.notifyAdminsAboutSessionSafetyAlert(
        sessionId: widget.sessionId,
        title: '⚠️ Session issue reported',
        message: '${widget.role}: $type – $message',
        severity: severity,
        type: 'safety_incident',
        metadata: {'incident_type': type, 'reporter_role': widget.role},
        sendPush: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report sent. Our team will look into it.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      widget.onReported?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Something wrong?',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Report an issue with this session. Our team will be notified.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedType ?? SafetyIncidentService.incidentTypes.first['value'],
            decoration: InputDecoration(
              labelText: 'Issue type',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: SafetyIncidentService.incidentTypes
                .map((e) => DropdownMenuItem(value: e['value'], child: Text(e['label']!)))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'What happened? (required)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textMedium)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Send report', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
