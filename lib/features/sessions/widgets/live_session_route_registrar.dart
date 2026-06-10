import 'package:flutter/material.dart';
import 'package:prepskul/features/sessions/services/live_session_overlay_controller.dart';

/// Registers an in-progress session with the global PiP while on the live detail screen.
class LiveSessionRouteRegistrar extends StatefulWidget {
  final Map<String, dynamic> session;
  final String userRole;
  final String counterpartyName;
  final String? subject;
  final String? localAvatarUrl;
  final String? counterpartyAvatarUrl;
  final bool isOnline;
  final Widget child;

  const LiveSessionRouteRegistrar({
    super.key,
    required this.session,
    required this.userRole,
    required this.counterpartyName,
    this.subject,
    this.localAvatarUrl,
    this.counterpartyAvatarUrl,
    this.isOnline = true,
    required this.child,
  });

  @override
  State<LiveSessionRouteRegistrar> createState() =>
      _LiveSessionRouteRegistrarState();
}

class _LiveSessionRouteRegistrarState extends State<LiveSessionRouteRegistrar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant LiveSessionRouteRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session['status'] != widget.session['status'] ||
        oldWidget.localAvatarUrl != widget.localAvatarUrl ||
        oldWidget.counterpartyAvatarUrl != widget.counterpartyAvatarUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!mounted) return;
    final status = widget.session['status']?.toString() ?? '';
    final sessionId = widget.session['id']?.toString();
    if (status == 'in_progress') {
      if (!LiveSessionOverlayController.instance
          .isSessionGenuinelyLive(widget.session)) {
        final sessionId = widget.session['id']?.toString();
        if (sessionId != null &&
            LiveSessionOverlayController.instance.sessionId == sessionId) {
          LiveSessionOverlayController.instance.clear();
        }
        return;
      }
      LiveSessionOverlayController.instance.registerFromSessionMap(
        session: widget.session,
        userRole: widget.userRole,
        counterpartyName: widget.counterpartyName,
        subject: widget.subject,
        localAvatarUrl: widget.localAvatarUrl,
        counterpartyAvatarUrl: widget.counterpartyAvatarUrl,
        isOnline: widget.isOnline,
      );
      LiveSessionOverlayController.instance.setRouteSuppressed(true);
    } else if (sessionId != null &&
        LiveSessionOverlayController.instance.sessionId == sessionId) {
      LiveSessionOverlayController.instance.clear();
    }
  }

  @override
  void dispose() {
    LiveSessionOverlayController.instance.setRouteSuppressed(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
