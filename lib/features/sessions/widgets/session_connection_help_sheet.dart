import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';

/// User-facing labels for the connection help sheet (testable mapping).
String connectionHelpRtcStateLabel(ConnectionStateType? state) {
  if (state == null) return 'Checking…';
  switch (state) {
    case ConnectionStateType.connectionStateDisconnected:
      return 'Disconnected';
    case ConnectionStateType.connectionStateConnecting:
      return 'Connecting';
    case ConnectionStateType.connectionStateConnected:
      return 'Connected';
    case ConnectionStateType.connectionStateReconnecting:
      return 'Reconnecting';
    case ConnectionStateType.connectionStateFailed:
      return 'Connection failed';
  }
}

/// Short label for uplink [QualityType] from the RTC callback.
String connectionHelpUplinkLabel(QualityType? q) {
  if (q == null) return 'Not measured yet';
  switch (q) {
    case QualityType.qualityExcellent:
    case QualityType.qualityGood:
      return 'Good';
    case QualityType.qualityPoor:
    case QualityType.qualityBad:
      return 'Fair to weak';
    case QualityType.qualityDown:
    case QualityType.qualityVbad:
      return 'Poor';
    case QualityType.qualityUnknown:
    case QualityType.qualityUnsupported:
      return 'Unknown';
    default:
      return 'Unknown';
  }
}

/// Non-blocking bottom sheet with connection snapshot and practical tips.
void showSessionConnectionHelpSheet({
  required BuildContext context,
  required AgoraService agoraService,
  int? remoteParticipantUid,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.48,
      minChildSize: 0.32,
      maxChildSize: 0.88,
      builder: (ctx, scrollController) {
        return SessionConnectionHelpPanel(
          scrollController: scrollController,
          agoraService: agoraService,
          remoteParticipantUid: remoteParticipantUid,
        );
      },
    ),
  );
}

class SessionConnectionHelpPanel extends StatefulWidget {
  const SessionConnectionHelpPanel({
    super.key,
    required this.scrollController,
    required this.agoraService,
    this.remoteParticipantUid,
  });

  final ScrollController scrollController;
  final AgoraService agoraService;
  final int? remoteParticipantUid;

  @override
  State<SessionConnectionHelpPanel> createState() =>
      _SessionConnectionHelpPanelState();
}

class _SessionConnectionHelpPanelState
    extends State<SessionConnectionHelpPanel> {
  ConnectionStateType? _rtcState;
  StreamSubscription<ConnectionStateType>? _connSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _connSub = widget.agoraService.connectionStateStream.listen((s) {
      if (mounted) setState(() => _rtcState = s);
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agora = widget.agoraService;
    final uplink = agora.lastObservedUplinkQuality;
    final remoteUid = widget.remoteParticipantUid;
    QualityType? remoteQ;
    if (remoteUid != null) {
      final map = agora.snapshotRemoteNetworkQuality;
      remoteQ = map[remoteUid];
    }

    return Material(
      color: AppTheme.primaryDark,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connection help',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  'Status',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow(
                  'Room connection',
                  connectionHelpRtcStateLabel(_rtcState),
                ),
                _infoRow(
                  'Your video uplink',
                  connectionHelpUplinkLabel(uplink),
                ),
                if (remoteUid != null)
                  _infoRow(
                    'Other participant',
                    connectionHelpUplinkLabel(remoteQ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Tips',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                _tip(
                  Icons.wifi,
                  'Move closer to your Wi‑Fi router, or use wired internet if you can.',
                ),
                _tip(
                  Icons.downloading,
                  'Pause large downloads or streaming on your network during the lesson.',
                ),
                _tip(
                  Icons.vpn_key_outlined,
                  'A VPN can add delay—try turning it off briefly if video or audio freezes.',
                ),
                _tip(
                  Icons.tab_unselected,
                  'Close other apps or browser tabs that use the camera or microphone.',
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.white24),
                    child: ExpansionTile(
                      collapsedIconColor: Colors.white54,
                      iconColor: Colors.white54,
                      title: Text(
                        'Diagnostics (team)',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SelectableText(
                            [
                              'channel: ${agora.currentChannelName}',
                              'localUid: ${agora.currentUID}',
                              'rtcState: ${_rtcState ?? 'null'}',
                              'uplinkQuality: ${agora.lastObservedUplinkQuality}',
                              'remoteQualities: ${agora.snapshotRemoteNetworkQuality}',
                            ].join('\n'),
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: Colors.white60,
                              height: 1.35,
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.softYellow.withOpacity(0.95)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.88),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
