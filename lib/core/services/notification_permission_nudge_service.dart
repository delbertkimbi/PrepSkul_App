import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/push_notification_service.dart';
import 'package:prepskul/core/widgets/notification_permission_sheet.dart';

/// LinkedIn-style notification permission prompt:
/// - Detects system permission status
/// - Shows an in-app explainer with benefits
/// - Requests OS permission only when it can show
/// - If denied, deep-links to Settings
/// - Uses cooldown + dismiss tracking to avoid being annoying
class NotificationPermissionNudgeService {
  static const _keyAppOpenCount = 'notif_nudge_app_open_count';
  static const _keyLastShownAtMs = 'notif_nudge_last_shown_at_ms';
  static const _keyDismissCount = 'notif_nudge_dismiss_count';
  static const _keyAccepted = 'notif_nudge_accepted';

  static bool _shownThisSession = false;

  /// Call once per app start.
  static Future<void> recordAppOpen() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyAppOpenCount) ?? 0;
    await prefs.setInt(_keyAppOpenCount, current + 1);
  }

  static Duration _cooldownForDismissCount(int dismissCount) {
    if (dismissCount <= 0) return const Duration(days: 3);
    if (dismissCount == 1) return const Duration(days: 14);
    return const Duration(days: 30);
  }

  static Future<bool> _shouldShow(String trigger) async {
    if (kIsWeb) return false;
    if (_shownThisSession) return false;

    final prefs = await SharedPreferences.getInstance();

    // If user already enabled at some point, never nudge again.
    final accepted = prefs.getBool(_keyAccepted) ?? false;
    if (accepted) return false;

    // Don’t show too early in the lifecycle.
    final openCount = prefs.getInt(_keyAppOpenCount) ?? 0;
    if (openCount < 1) return false;

    // Only show when permission isn't already granted.
    final status = await PushNotificationService().getPermissionStatus();
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      await prefs.setBool(_keyAccepted, true);
      return false;
    }

    // Cooldown between prompts.
    final dismissCount = prefs.getInt(_keyDismissCount) ?? 0;
    final lastShownMs = prefs.getInt(_keyLastShownAtMs);
    if (lastShownMs != null) {
      final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
      final cooldown = _cooldownForDismissCount(dismissCount);
      final nextAllowed = lastShown.add(cooldown);
      if (DateTime.now().isBefore(nextAllowed)) {
        return false;
      }
    }

    // If triggered from messaging, we allow it even if recently shown
    // (but still respect per-session guard).
    if (trigger == 'messaging') return true;

    return true;
  }

  /// Call from high-intent moments (home screen, messaging, bookings).
  static Future<void> maybeShow(
    BuildContext context, {
    required String trigger,
  }) async {
    try {
      if (!await _shouldShow(trigger)) return;
      _shownThisSession = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastShownAtMs, DateTime.now().millisecondsSinceEpoch);

      final status = await PushNotificationService().getPermissionStatus();
      final isDenied = status == AuthorizationStatus.denied;

      if (!context.mounted) return;

      bool isRequesting = false;
      final result = await showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setState) {
              return NotificationPermissionSheet(
                isDeniedPermanently: isDenied,
                isRequestInProgress: isRequesting,
                onPrimaryAction: () async {
                  if (isRequesting) return;
                  setState(() => isRequesting = true);
                  try {
                    if (isDenied) {
                      await PushNotificationService().openSystemNotificationSettings();
                      if (ctx.mounted) Navigator.of(ctx).pop('settings');
                      return;
                    }

                    final newStatus = await PushNotificationService().requestPermission();
                    if (newStatus == AuthorizationStatus.authorized ||
                        newStatus == AuthorizationStatus.provisional) {
                      await prefs.setBool(_keyAccepted, true);
                      if (ctx.mounted) Navigator.of(ctx).pop('enabled');
                    } else {
                      if (ctx.mounted) Navigator.of(ctx).pop('dismissed');
                    }
                  } finally {
                    if (ctx.mounted) setState(() => isRequesting = false);
                  }
                },
                onNotNow: () {
                  Navigator.of(ctx).pop('dismissed');
                },
              );
            },
          );
        },
      );

      if (result == 'enabled') {
        await prefs.setBool(_keyAccepted, true);
        await prefs.remove(_keyDismissCount);
        return;
      }

      if (result == 'settings') {
        // We don’t mark accepted; user may still cancel in settings.
        return;
      }

      // Count dismiss (including swipe-down).
      final currentDismiss = prefs.getInt(_keyDismissCount) ?? 0;
      await prefs.setInt(_keyDismissCount, currentDismiss + 1);
    } catch (e) {
      LogService.debug('Notification permission nudge failed: $e');
    }
  }
}

