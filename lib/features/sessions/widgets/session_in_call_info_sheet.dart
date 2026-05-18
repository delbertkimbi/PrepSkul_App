import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/services/session_profile_service.dart';

/// Lightweight lesson context (Preply-style header “info” cluster) without leaving the call.
Future<void> showSessionInCallInfoSheet({
  required BuildContext context,
  required String sessionId,
  required String userRole,
  Map<String, dynamic>? localProfile,
  Map<String, dynamic>? remoteProfile,
  SessionBookingSummary? booking,
  Duration? timeRemaining,
  required VoidCallback onOpenConnectionHelp,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.46,
          minChildSize: 0.32,
          maxChildSize: 0.88,
          builder: (context, scrollController) {
            final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
            final roleLabel =
                userRole == 'tutor' ? 'Tutor' : 'Learner';
            final remoteRoleLabel =
                userRole == 'tutor' ? 'Learner' : 'Tutor';
            final remoteName = (remoteProfile?['full_name'] as String?)?.trim();
            final localName = (localProfile?['full_name'] as String?)?.trim();
            final showRemoteLine = remoteName != null && remoteName.isNotEmpty;
            final pendingRemote = !showRemoteLine;

            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Material(
                color: const Color(0xFF141F36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 40),
                          Expanded(
                            child: Text(
                              'Lesson info',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () =>
                                Navigator.of(sheetCtx).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0x22FFFFFF)),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          16,
                          20,
                          20 + bottomInset,
                        ),
                        children: [
                          _InfoLine(
                            label: 'You',
                            value: roleLabel,
                            detail: localName != null && localName.isNotEmpty
                                ? localName
                                : null,
                          ),
                          _InfoLine(
                            label: remoteRoleLabel,
                            value: showRemoteLine
                                ? remoteName!
                                : (pendingRemote
                                    ? 'Not connected yet'
                                    : '—'),
                            detail: pendingRemote
                                ? 'They may still be joining.'
                                : null,
                          ),
                          if (booking?.subject != null &&
                              booking!.subject!.trim().isNotEmpty)
                            _InfoLine(
                              label: 'Subject',
                              value: booking.subject!.trim(),
                            ),
                          if (booking?.scheduledDisplay != null)
                            _InfoLine(
                              label: 'Scheduled',
                              value: booking!.scheduledDisplay!,
                            ),
                          if (booking?.durationMinutes != null)
                            _InfoLine(
                              label: 'Slot length',
                              value:
                                  '${booking!.durationMinutes} min',
                            ),
                          if (booking?.status != null)
                            _InfoLine(
                              label: 'Booking status',
                              value: _friendlyStatus(booking!.status!),
                            ),
                          if (booking?.isTrial == true)
                            const _InfoLine(
                              label: 'Type',
                              value: 'Trial lesson',
                            ),
                          if (timeRemaining != null)
                            _InfoLine(
                              label: 'Time remaining',
                              value: _formatRemaining(timeRemaining),
                            ),
                          _InfoLine(
                            label: 'Session reference',
                            value: _shortSessionRef(sessionId),
                            trailing: TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: sessionId),
                                );
                                if (!sheetCtx.mounted) return;
                                ScaffoldMessenger.maybeOf(sheetCtx)
                                    ?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Session ID copied',
                                      style: GoogleFonts.poppins(
                                          fontSize: 14),
                                    ),
                                    backgroundColor:
                                        AppTheme.primaryColor,
                                  ),
                                );
                              },
                              child: Text(
                                'Copy ID',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.skyBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Having audio, video, or network trouble? Use Connection help in the call menu (⋯) for tips and a live connection readout.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetCtx).pop();
                              onOpenConnectionHelp();
                            },
                            icon: const Icon(
                              Icons.wifi_tethering,
                              color: Colors.white70,
                              size: 20,
                            ),
                            label: Text(
                              'Connection help',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0x44FFFFFF)),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
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
          },
        ),
      );
    },
  );
}

String _shortSessionRef(String id) {
  final t = id.trim();
  if (t.length <= 14) return t;
  return '${t.substring(0, 8)}…${t.substring(t.length - 4)}';
}

String _friendlyStatus(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return raw;
  return s[0].toUpperCase() + s.substring(1);
}

String _formatRemaining(Duration d) {
  final minutes = d.inMinutes;
  final sec = d.inSeconds.remainder(60);
  return '$minutes:${sec.toString().padLeft(2, '0')}';
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.detail,
    this.trailing,
  });

  final String label;
  final String value;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.3,
                      color: Colors.white.withValues(alpha: 0.52),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
