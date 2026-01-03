/**
 * Push Notification Service
 * 
 * Handles Firebase Cloud Messaging (FCM) for push notifications
 * - Request permissions
 * - Get FCM token
 * - Store token in database
 * - Handle foreground, background, and terminated notifications
 * - Navigate on notification tap
 */

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message logged in LogService (if available in isolate)
  // Handle background message
  // Note: Don't use UI code here, this runs in a separate isolate
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _currentToken;
  Function(dynamic)? _onNotificationTap;

  /// Initialize push notifications
  Future<void> initialize({
    Function(dynamic)? onNotificationTap,
  }) async {
    if (_initialized) {
      LogService.warning('PushNotificationService already initialized');
      return;
    }

    _onNotificationTap = onNotificationTap;

    try {
      // On web, FCM requires service worker setup which may not be available
      // In-app notifications from Supabase work fine on web without FCM
      if (kIsWeb) {
        LogService.info('Initializing push notifications for web');
        
        try {
          // Try to set up message handlers (may fail if service worker not configured)
          await _setupMessageHandlers();

          // Try to get FCM token (may fail if service worker not configured)
          await _getToken();

          // Listen for token refresh
          _firebaseMessaging.onTokenRefresh.listen((newToken) {
            LogService.info('FCM token refreshed: $newToken');
            _updateTokenInDatabase(newToken);
          });

          _initialized = true;
          LogService.success('PushNotificationService initialized for web');
        } catch (e) {
          // FCM may not work on web if service worker is not configured
          // This is OK - in-app notifications from Supabase still work
          LogService.warning('FCM not available on web (service worker not configured): $e');
          LogService.info('In-app notifications will still work via Supabase Realtime');
          _initialized = true; // Mark as initialized so app doesn't block
        }
        return;
      }

      // Initialize local notifications immediately (without requesting permission)
      // Do this first so it's ready when permission is granted
      _initializeLocalNotifications().catchError((error) {
        LogService.warning('Error initializing local notifications: $error');
      });

      // Set up message handlers immediately (doesn't require permission)
      _setupMessageHandlers().catchError((error) {
        LogService.warning('Error setting up message handlers: $error');
      });

      // Check if permission was already granted and complete initialization if so
      // This handles cases where user previously granted permission
      _checkAndCompleteInitialization();

      // Mark as initialized immediately so app doesn't block
      // The splash screen should transition without waiting for push notifications
      // Permission will be requested later when appropriate (after onboarding/login)
      _initialized = true;
      LogService.success('PushNotificationService initialized (permission will be requested when appropriate)');

      return;
    } catch (e) {
      LogService.error('Error initializing PushNotificationService: $e');
      // Don't fail the app if push notifications fail to initialize
    }
  }

  /// Check current notification permission status
  Future<AuthorizationStatus> getPermissionStatus() async {
    try {
      if (kIsWeb) {
        // On web, check Notification API permission
        // For now, return authorized if available
        return AuthorizationStatus.authorized;
      }
      
      final settings = await _firebaseMessaging.getNotificationSettings();
      LogService.info('Current notification permission: ${settings.authorizationStatus}');
      return settings.authorizationStatus;
    } catch (e) {
      LogService.error('Error checking permission status: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Request notification permission
  /// Only call this when it's appropriate (e.g., after onboarding or login)
  Future<AuthorizationStatus> requestPermission() async {
    try {
      // Check current status first
      final currentStatus = await getPermissionStatus();
      
      // If already authorized or provisional, don't request again
      if (currentStatus == AuthorizationStatus.authorized ||
          currentStatus == AuthorizationStatus.provisional) {
        LogService.success('Notification permission already granted');
        // Complete initialization if not already done
        await _completeMobileInitialization();
        return currentStatus;
      }
      
      // If denied, don't request again (user must enable in settings)
      if (currentStatus == AuthorizationStatus.denied) {
        LogService.warning('Notification permission was denied - user must enable in settings');
        return currentStatus;
      }

      // Only request if status is notDetermined
      LogService.info('Requesting notification permission...');
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      LogService.info('Notification permission result: ${settings.authorizationStatus}');
      
      // Complete initialization if permission was granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        LogService.success('Push notification permission granted');
        await _completeMobileInitialization();
      } else {
        LogService.warning('Push notification permission not granted (status: ${settings.authorizationStatus})');
      }
      
      return settings.authorizationStatus;
    } catch (e) {
      LogService.error('Error requesting permission: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Check permission status and complete initialization if granted
  Future<void> _checkAndCompleteInitialization() async {
    try {
      final status = await getPermissionStatus();
      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        LogService.success('Notification permission already granted, completing initialization');
        await _completeMobileInitialization();
      }
    } catch (e) {
      LogService.warning('Error checking permission for initialization: $e');
    }
  }

  /// Initialize local notifications (for foreground notifications)
  Future<void> _initializeLocalNotifications() async {
    // Skip on web - web doesn't support local notifications the same way
    if (kIsWeb) {
      LogService.warning('Local notifications not supported on web');
      return;
    }

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization - DO NOT request permission here
    // Permission will be requested explicitly when appropriate
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        if (details.payload != null) {
          _handleNotificationTap(details.payload!);
        }
      },
    );

    // Create notification channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'prepskul_notifications', // id
        'PrepSkul Notifications', // name
        description: 'Notifications for PrepSkul app',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Complete mobile initialization after permission is granted
  Future<void> _completeMobileInitialization() async {
    try {
      // Set up message handlers
      await _setupMessageHandlers();

      // On iOS, we'll retry getting the token after a short delay
      // This handles cases where APNS token becomes available after permission is granted
      if (!kIsWeb && Platform.isIOS) {
        // Retry getting token after a delay (APNS might become available)
        Future.delayed(const Duration(seconds: 2), () {
          _getToken().catchError((error) {
            LogService.warning('Retry getting FCM token failed: $error');
            return null; // Return null on error
          });
        });
      }

      // Get FCM token (now that permission is granted)
      await _getToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        LogService.info('FCM token refreshed: $newToken');
        _updateTokenInDatabase(newToken);
      });

      LogService.success('Push notification mobile initialization completed');
    } catch (e) {
      LogService.warning('Error completing mobile initialization: $e');
      // Don't throw - app should continue
    }
  }

  /// Set up message handlers
  Future<void> _setupMessageHandlers() async {
    try {
      // Set background message handler (skip on web)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        LogService.info('Foreground message received: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Handle notification taps (when app is in background or terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        LogService.info('Notification tapped: ${message.messageId}');
        _handleNotificationTapFromMessage(message);
      });

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        LogService.info('App opened from terminated state via notification');
        _handleNotificationTapFromMessage(initialMessage);
      }
    } catch (e) {
      // On web, FCM may not be available
      if (kIsWeb) {
        LogService.info('FCM message handlers not available on web: $e');
        // Don't throw - in-app notifications still work
      } else {
        // Don't rethrow - allow app to continue
        LogService.warning('Error setting up message handlers: $e');
      }
    }
  }

  /// Handle foreground message (show local notification)
  Future<void> _handleForegroundMessage(dynamic message) async {
    // Skip on web - web handles notifications differently via FCM
    if (kIsWeb) {
      LogService.info('Web foreground notification received - handled by browser');
      return;
    }

    final notification = message.notification;
    final android = message.notification?.android;
    final data = message.data;

    if (notification == null) return;

    // Determine if we should play sound
    final shouldPlaySound = data != null && data['sound'] != 'false';
    final sound = data?['sound'] ?? 'default';

    // Show local notification
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: Platform.isAndroid ? AndroidNotificationDetails(
          'prepskul_notifications',
          'PrepSkul Notifications',
          channelDescription: 'Notifications for PrepSkul app',
          importance: Importance.high,
          priority: Priority.high,
          playSound: shouldPlaySound,
          sound: RawResourceAndroidNotificationSound(sound),
          enableVibration: data?['vibrate'] != 'false',
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        ) : null,
        iOS: Platform.isIOS ? const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ) : null,
      ),
      payload: message.data?.toString(), // Pass data as payload
    );
  }

  /// Handle notification tap from RemoteMessage
  void _handleNotificationTapFromMessage(dynamic message) {
    if (_onNotificationTap != null) {
      _onNotificationTap!(message);
    }
    // You can also navigate here directly
    // Navigator.pushNamed(context, '/notification', arguments: message.data);
  }

  /// Handle notification tap from local notification
  void _handleNotificationTap(String payload) {
    // Parse payload and navigate
    // You can decode the data and navigate accordingly
    LogService.info('Local notification tapped: $payload');
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      // On iOS, we need to get the APNS token first before getting FCM token
      if (!kIsWeb && Platform.isIOS) {
        try {
          // Request APNS token first (this is required for iOS)
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken == null) {
            LogService.warning('APNS token not available yet - this is normal on simulator or before permission is granted');
            LogService.info('FCM token will be available once APNS token is set (usually after permission is granted)');
            // Don't throw error - this is expected behavior on iOS simulator or before permission
            return null;
          }
          LogService.success('APNS token obtained: $apnsToken');
        } catch (apnsError) {
          // If APNS token fails, it might be because:
          // 1. Running on simulator (APNS not available)
          // 2. Permission not granted yet
          // 3. App not properly configured for push notifications
          LogService.warning('Could not get APNS token: $apnsError');
          LogService.info('This is normal on iOS simulator or before permission is granted');
          // Continue anyway - might still work on real device
        }
      }

      // Now get FCM token
      _currentToken = await _firebaseMessaging.getToken();
      if (_currentToken != null) {
        LogService.success('FCM token obtained: $_currentToken');
        await _storeTokenInDatabase(_currentToken!);
      } else {
        LogService.warning('FCM token is null');
      }
      return _currentToken;
    } catch (e) {
      // Check if it's the APNS token error
      final errorString = e.toString();
      if (errorString.contains('apns-token-not-set')) {
        LogService.warning('APNS token not set yet - this is normal on iOS simulator or before permission is granted');
        LogService.info('Push notifications will work once APNS token is available (usually on real device after permission)');
        // Don't treat this as a critical error - it's expected behavior
        return null;
      }
      LogService.error('Error getting FCM token: $e');
      return null;
    }
  }

  /// Store FCM token in database
  /// Uses UPSERT to handle duplicates gracefully (prevents race conditions)
  Future<void> _storeTokenInDatabase(String token) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        LogService.warning('User not authenticated, cannot store FCM token');
        return;
      }

      // Get device info
      final deviceInfo = await _getDeviceInfo();
      final platform = _getPlatform();
      
      // Try to insert the token first
      // If it's a duplicate, update the existing token instead
      try {
        await SupabaseService.client
            .from('fcm_tokens')
            .insert({
              'user_id': userId,
              'token': token,
              'platform': platform,
              'device_id': deviceInfo['device_id'],
              'device_name': deviceInfo['device_name'],
              'app_version': deviceInfo['app_version'],
              'is_active': true,
            });
        LogService.success('FCM token stored in database');
      } catch (insertError) {
        // If insert fails due to duplicate token, update the existing token
        if (insertError.toString().contains('duplicate') || 
            insertError.toString().contains('23505') ||
            insertError.toString().contains('unique constraint')) {
          // Token already exists - update it instead
          try {
            await SupabaseService.client
                .from('fcm_tokens')
                .update({
                  'user_id': userId,
                  'is_active': true,
                  'platform': platform,
                  'device_id': deviceInfo['device_id'],
                  'device_name': deviceInfo['device_name'],
                  'app_version': deviceInfo['app_version'],
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('token', token);
            LogService.success('FCM token updated in database (duplicate handled)');
          } catch (updateError) {
            // If update also fails, log but don't throw (token might be in use by another user)
            LogService.info('FCM token exists but update failed (may belong to different user): $updateError');
          }
        } else {
          // Some other error occurred
          rethrow;
        }
      }
    } catch (e) {
      // Only log error if it's not a duplicate key error (which we handle gracefully)
      if (!e.toString().contains('duplicate') && !e.toString().contains('23505')) {
        LogService.error('Error storing FCM token: $e');
      } else {
        LogService.info('FCM token duplicate detected and handled gracefully');
      }
    }
  }

  /// Update FCM token in database
  Future<void> _updateTokenInDatabase(String token) async {
    _currentToken = token;
    await _storeTokenInDatabase(token);
  }

  /// Get device info
  Future<Map<String, String?>> _getDeviceInfo() async {
    try {
      String? deviceId;
      String? deviceName;
      String? appVersion;

      if (kIsWeb) {
        // Web platform - use browser info or default values
        deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
        deviceName = 'Web Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        deviceId = androidInfo.id;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        deviceId = iosInfo.identifierForVendor;
        deviceName = '${iosInfo.name} (${iosInfo.model})';
      }

      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;

      return {
        'device_id': deviceId,
        'device_name': deviceName,
        'app_version': appVersion,
      };
    } catch (e) {
      LogService.error('Error getting device info: $e');
      return {
        'device_id': kIsWeb ? 'web-unknown' : null,
        'device_name': kIsWeb ? 'Web Browser' : null,
        'app_version': null,
      };
    }
  }

  /// Get platform string
  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Deactivate all tokens for current user (on logout)
  Future<void> deactivateAllTokens() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.client
          .from('fcm_tokens')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('is_active', true);

      LogService.success('All FCM tokens deactivated for user');
    } catch (e) {
      LogService.error('Error deactivating FCM tokens: $e');
    }
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;

  /// Check if initialized
  bool get isInitialized => _initialized;
}
