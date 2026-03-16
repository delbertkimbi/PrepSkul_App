import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/push_notification_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';

class AdminNotificationDiagnosticsScreen extends StatefulWidget {
  const AdminNotificationDiagnosticsScreen({super.key});

  @override
  State<AdminNotificationDiagnosticsScreen> createState() =>
      _AdminNotificationDiagnosticsScreenState();
}

class _AdminNotificationDiagnosticsScreenState
    extends State<AdminNotificationDiagnosticsScreen> {
  bool _isLoading = true;
  String _permission = 'unknown';
  String _fcmTokenPreview = 'not available';
  String? _error;

  List<Map<String, dynamic>> _activeTokens = const [];
  List<Map<String, dynamic>> _scheduledRows = const [];
  List<Map<String, dynamic>> _recentRows = const [];
  List<Map<String, dynamic>> _cronHeartbeats = const [];
  List<PendingNotificationRequest> _pendingLocal = const [];

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      final push = PushNotificationService();
      final status = await push.getPermissionStatus();
      final currentToken =
          push.currentToken ?? await FirebaseMessaging.instance.getToken();
      final pendingLocal = await push.getPendingLocalNotifications();

      final activeTokensRaw = await SupabaseService.client
          .from('fcm_tokens')
          .select('id, token, platform, device_name, updated_at, is_active')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(10);

      final scheduledRaw = await SupabaseService.client
          .from('scheduled_notifications')
          .select(
            'id, notification_type, title, scheduled_for, status, metadata',
          )
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'processing'])
          .gte('scheduled_for', DateTime.now().toIso8601String())
          .order('scheduled_for', ascending: true)
          .limit(20);

      final recentRaw = await SupabaseService.client
          .from('notifications')
          .select('id, notification_type, title, created_at, read')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      dynamic heartbeatsRaw = const [];
      try {
        heartbeatsRaw = await SupabaseService.client
            .from('cron_job_heartbeats')
            .select(
              'job_name, last_status, last_run_at, last_success_at, last_error, processed_count, failed_count',
            )
            .inFilter('job_name', [
              'process-scheduled-notifications',
              'daily-challenge-reminder',
            ])
            .order('job_name', ascending: true);
      } catch (_) {
        // Migration may not be applied yet in some environments.
      }

      if (!mounted) return;
      setState(() {
        _permission = status.name;
        _fcmTokenPreview = _shortenToken(currentToken);
        _pendingLocal = pendingLocal;
        _activeTokens = _toMapList(activeTokensRaw);
        _scheduledRows = _toMapList(scheduledRaw);
        _recentRows = _toMapList(recentRaw);
        _cronHeartbeats = _toMapList(heartbeatsRaw);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _toMapList(dynamic rows) {
    final raw = (rows as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  String _shortenToken(String? token) {
    if (token == null || token.isEmpty) return 'not available';
    if (token.length <= 20) return token;
    return '${token.substring(0, 10)}...${token.substring(token.length - 8)}';
  }

  String _formatLocalPayload(PendingNotificationRequest req) {
    final payload = req.payload;
    if (payload == null || payload.isEmpty) return 'no payload';
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['type'] != null) {
        return '${decoded['type']}';
      }
      return 'payload set';
    } catch (_) {
      return 'payload set';
    }
  }

  Map<String, dynamic>? _heartbeatFor(String jobName) {
    for (final row in _cronHeartbeats) {
      if ((row['job_name'] as String?) == jobName) return row;
    }
    return null;
  }

  Widget _buildHeartbeatTile(String jobName, String label) {
    final row = _heartbeatFor(jobName);
    if (row == null) {
      return _buildStatTile(
        label,
        'No heartbeat yet',
        valueColor: Colors.orange[800],
      );
    }

    final status = (row['last_status'] as String?) ?? 'unknown';
    final lastRun = (row['last_run_at'] as String?) ?? '-';
    final processed = row['processed_count']?.toString() ?? '0';
    final failed = row['failed_count']?.toString() ?? '0';
    final hasError = (row['last_error'] as String?)?.trim().isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: $status',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: status == 'success' ? Colors.green[700] : Colors.red[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Last run: $lastRun',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
            ),
          ),
          Text(
            'Processed: $processed, Failed: $failed',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textMedium,
            ),
          ),
          if (hasError)
            Text(
              'Error: ${row['last_error']}',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.red[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: valueColor ?? AppTheme.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notification Diagnostics',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDiagnostics,
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
                  'Failed to load diagnostics:\n$_error',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.red[700],
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildSectionTitle('Device Status'),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatTile(
                        'Permission',
                        _permission,
                        valueColor: _permission == 'authorized'
                            ? Colors.green[700]
                            : Colors.orange[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatTile(
                        'Pending Local',
                        '${_pendingLocal.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStatTile('FCM Token', _fcmTokenPreview),

                _buildSectionTitle('External Cron Health'),
                _buildHeartbeatTile(
                  'process-scheduled-notifications',
                  'Process Scheduled Notifications',
                ),
                const SizedBox(height: 8),
                _buildHeartbeatTile(
                  'daily-challenge-reminder',
                  'Daily Challenge Reminder',
                ),

                _buildSectionTitle('Server Token Health'),
                _buildStatTile('Active FCM rows', '${_activeTokens.length}'),
                const SizedBox(height: 8),
                ..._activeTokens.take(5).map((row) {
                  final token = (row['token'] as String?) ?? '';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${row['platform'] ?? 'unknown'} - ${row['device_name'] ?? 'device'}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _shortenToken(token),
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    trailing: Text(
                      '${row['updated_at'] ?? ''}'.toString().substring(0, 10),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  );
                }),

                _buildSectionTitle('Queued Notifications (Server)'),
                _buildStatTile(
                  'Pending/processing',
                  '${_scheduledRows.length}',
                ),
                const SizedBox(height: 8),
                ..._scheduledRows
                    .take(8)
                    .map(
                      (row) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${row['notification_type'] ?? 'unknown'} - ${row['title'] ?? ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${row['scheduled_for'] ?? ''}',
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                      ),
                    ),

                _buildSectionTitle('Recent Delivered (In-app Table)'),
                _buildStatTile('Recent rows', '${_recentRows.length}'),
                const SizedBox(height: 8),
                ..._recentRows
                    .take(8)
                    .map(
                      (row) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${row['notification_type'] ?? 'unknown'} - ${row['title'] ?? ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${row['created_at'] ?? ''}',
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                        trailing: Icon(
                          (row['read'] as bool?) == true
                              ? Icons.mark_email_read_rounded
                              : Icons.mark_email_unread_rounded,
                          size: 16,
                          color: (row['read'] as bool?) == true
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),

                _buildSectionTitle('Pending Local Notifications'),
                if (kIsWeb)
                  Text(
                    'Local notification diagnostics are unavailable on web.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  )
                else if (_pendingLocal.isEmpty)
                  Text(
                    'No pending local reminders on this device.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  )
                else
                  ..._pendingLocal
                      .take(12)
                      .map(
                        (req) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${req.id} - ${req.title ?? 'Untitled'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _formatLocalPayload(req),
                            style: GoogleFonts.poppins(fontSize: 11),
                          ),
                        ),
                      ),
              ],
            ),
    );
  }
}
