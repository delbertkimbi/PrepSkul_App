import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';

class AdminRecurringQuitQueueScreen extends StatefulWidget {
  const AdminRecurringQuitQueueScreen({super.key});

  @override
  State<AdminRecurringQuitQueueScreen> createState() =>
      _AdminRecurringQuitQueueScreenState();
}

class _AdminRecurringQuitQueueScreenState
    extends State<AdminRecurringQuitQueueScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.client
          .from('notifications')
          .select('id, title, message, metadata, created_at, read')
          .eq('notification_type', 'recurring_quit_admin_review')
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      setState(() {
        _rows = (rows as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading recurring quit queue: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'read': true})
          .eq('id', id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not mark as read: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _applyDecision({
    required Map<String, dynamic> row,
    required String decision,
  }) async {
    final metadata =
        (row['metadata'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final actorUserId = metadata['actor_user_id'] as String?;
    final recurringId = metadata['recurring_session_id'] as String?;
    if (actorUserId == null || recurringId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Case metadata is incomplete; cannot apply decision.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final noteController = TextEditingController();
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Confirm decision',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Decision: $decision',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Admin note (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Apply', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      final updatedMetadata = <String, dynamic>{
        ...metadata,
        'admin_decision': decision,
        'admin_decision_at': DateTime.now().toIso8601String(),
        if (noteController.text.trim().isNotEmpty)
          'admin_decision_note': noteController.text.trim(),
      };

      await SupabaseService.client
          .from('notifications')
          .update({
            'metadata': updatedMetadata,
            'read': true,
          })
          .eq('id', row['id']);

      await NotificationHelperService.notifyRecurringQuitDecision(
        recipientUserId: actorUserId,
        recurringSessionId: recurringId,
        decision: decision,
        note: noteController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Decision applied and user notified.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to apply decision: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      noteController.dispose();
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recurring Quit Review Queue',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F8FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: GoogleFonts.poppins(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _rows.isEmpty
                  ? Center(
                      child: Text(
                        'No recurring quit cases waiting for review.',
                        style: GoogleFonts.poppins(color: AppTheme.textMedium),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final metadata = (row['metadata'] as Map?)
                                ?.cast<String, dynamic>() ??
                            const <String, dynamic>{};
                        final read = row['read'] as bool? ?? false;
                        final actor = metadata['actor_name']?.toString() ?? 'Unknown';
                        final role = metadata['actor_role']?.toString() ?? 'unknown';
                        final outcome =
                            metadata['requested_outcome']?.toString() ?? 'unknown';
                        final paidRemaining =
                            metadata['paid_sessions_remaining']?.toString() ?? '0';
                        final recurringId =
                            metadata['recurring_session_id']?.toString() ?? '-';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: read ? AppTheme.softBorder : AppTheme.primaryColor,
                              width: read ? 1 : 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row['title']?.toString() ?? 'Quit review',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (!read)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'NEW',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.orange[900],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                row['message']?.toString() ?? '',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Actor: $actor ($role) • Outcome: $outcome • Paid remaining: $paidRemaining',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              Text(
                                'Recurring ID: $recurringId',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              Text(
                                _fmtDate(row['created_at']?.toString()),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: read
                                        ? null
                                        : () => _markRead(row['id'].toString()),
                                    child: Text(
                                      'Mark reviewed',
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    tooltip: 'Apply decision',
                                    onSelected: (value) =>
                                        _applyDecision(row: row, decision: value),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'approve_refund_review',
                                        child: Text('Approve refund review'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'continue_paid_only',
                                        child: Text('Continue paid sessions only'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'decline_refund_request',
                                        child: Text('Decline refund request'),
                                      ),
                                    ],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppTheme.softBorder),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Decide',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
