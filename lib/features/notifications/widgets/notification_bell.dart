import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/notifications/screens/notification_list_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Notification Bell Widget
/// 
/// Displays a bell icon with unread notification badge
/// Tappable to open notification list
class NotificationBell extends StatefulWidget {
  final Color? iconColor;
  
  const NotificationBell({super.key, this.iconColor});

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Use root navigator to avoid nested navigation issues
        final rootNavigator = Navigator.of(context, rootNavigator: false);
        rootNavigator.push(
          MaterialPageRoute(
            builder: (context) => const NotificationListScreen(),
          ),
        ).then((_) {
          // Reload count when returning from notification list
          _loadUnreadCount();
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconColor != null 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: PhosphorIcon(
              PhosphorIcons.bell(),
              color: widget.iconColor ?? AppTheme.textDark,
              size: 24,
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

