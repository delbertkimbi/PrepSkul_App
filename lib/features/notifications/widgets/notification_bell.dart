import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/notifications/screens/notification_list_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prepskul/core/widgets/icon_badge_pulse.dart';

/// Notification Bell Widget
/// 
/// Displays a bell icon with unread notification badge
/// Tappable to open notification list
class NotificationBell extends StatefulWidget {
  final Color? iconColor;
  final bool outlined;

  const NotificationBell({super.key, this.iconColor, this.outlined = false});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;
  StreamSubscription? _notificationStream;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToNotifications();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  void _subscribeToNotifications() {
    // Subscribe to real-time notifications
    _notificationStream = NotificationService.watchNotifications(
      unreadOnly: true,
    ).listen((notifications) {
      if (mounted) {
        setState(() {
          _unreadCount = notifications.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _notificationStream?.cancel();
    super.dispose();
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationListScreen(),
      ),
    ).then((_) => _loadUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    final icon = PhosphorIcon(
      PhosphorIcons.bell(),
      color: widget.iconColor ?? AppTheme.textDark,
      size: 22,
    );

    final useOutlined = widget.outlined || widget.iconColor == null;

    if (useOutlined) {
      return IconBadgePulse(
        count: _unreadCount,
        icon: icon,
        onTap: _openNotifications,
      );
    }

    return GestureDetector(
      onTap: _openNotifications,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconColor != null
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: widget.iconColor != null
                  ? Border.all(color: Colors.white.withValues(alpha: 0.35))
                  : null,
            ),
            child: icon,
          ),
          if (_unreadCount > 0) _legacyBadge(_unreadCount),
        ],
      ),
    );
  }

  Widget _legacyBadge(int count) {
    return Positioned(
      right: -4,
      top: -4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Center(
          child: Text(
            count > 99 ? '99+' : '$count',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

