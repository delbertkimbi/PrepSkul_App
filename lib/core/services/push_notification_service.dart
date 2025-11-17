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
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background message received: ${message.messageId}');
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
      print('⚠️ PushNotificationService already initialized');
      return;
    }

    _onNotificationTap = onNotificationTap;

    try {
      // On web, FCM requires service worker setup which may not be available
      // In-app notifications from Supabase work fine on web without FCM
      if (kIsWeb) {
        print('🌐 Initializing push notifications for web');
        
        try {
          // Try to set up message handlers (may fail if service worker not configured)
          await _setupMessageHandlers();

          // Try to get FCM token (may fail if service worker not configured)
          await _getToken();

          // Listen for token refresh
          _firebaseMessaging.onTokenRefresh.listen((newToken) {
            print('🔄 FCM token refreshed: $newToken');
            _updateTokenInDatabase(newToken);
          });

          _initialized = true;
          print('✅ PushNotificationService initialized for web');
        } catch (e) {
          // FCM may not work on web if service worker is not configured
          // This is OK - in-app notifications from Supabase still work
          print('⚠️ FCM not available on web (service worker not configured): $e');
          print('ℹ️ In-app notifications will still work via Supabase Realtime');
          _initialized = true; // Mark as initialized so app doesn't block
        }
        return;
      }

      // Initialize local notifications immediately (without requesting permission)
      // Do this first so it's ready when permission is granted
      _initializeLocalNotifications().catchError((error) {
        print('⚠️ Error initializing local notifications: $error');
      });

      // Set up message handlers immediately (doesn't require permission)
      _setupMessageHandlers().catchError((error) {
        print('⚠️ Error setting up message handlers: $error');
      });

      // Check if permission was already granted and complete initialization if so
      // This handles cases where user previously granted permission
      _checkAndCompleteInitialization();

      // Mark as initialized immediately so app doesn't block
      // The splash screen should transition without waiting for push notifications
      // Permission will be requested later when appropriate (after onboarding/login)
      _initialized = true;
      print('✅ PushNotificationService initialized (permission will be requested when appropriate)');

      return;
    } catch (e) {
      print('❌ Error initializing PushNotificationService: $e');
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
      print('📱 Current notification permission: ${settings.authorizationStatus}');
      return settings.authorizationStatus;
    } catch (e) {
      print('❌ Error checking permission status: $e');
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
        print('✅ Notification permission already granted');
        // Complete initialization if not already done
        await _completeMobileInitialization();
        return currentStatus;
      }
      
      // If denied, don't request again (user must enable in settings)
      if (currentStatus == AuthorizationStatus.denied) {
        print('⚠️ Notification permission was denied - user must enable in settings');
        return currentStatus;
      }

      // Only request if status is notDetermined
      print('📱 Requesting notification permission...');
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('📱 Notification permission result: ${settings.authorizationStatus}');
      
      // Complete initialization if permission was granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('✅ Push notification permission granted');
        await _completeMobileInitialization();
      } else {
        print('⚠️ Push notification permission not granted (status: ${settings.authorizationStatus})');
      }
      
      return settings.authorizationStatus;
    } catch (e) {
      print('❌ Error requesting permission: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Check permission status and complete initialization if granted
  Future<void> _checkAndCompleteInitialization() async {
    try {
      final status = await getPermissionStatus();
      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        print('✅ Notification permission already granted, completing initialization');
        await _completeMobileInitialization();
      }
    } catch (e) {
      print('⚠️ Error checking permission for initialization: $e');
    }
  }

  /// Initialize local notifications (for foreground notifications)
  Future<void> _initializeLocalNotifications() async {
    // Skip on web - web doesn't support local notifications the same way
    if (kIsWeb) {
      print('⚠️ Local notifications not supported on web');
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
            print('⚠️ Retry getting FCM token failed: $error');
            return null; // Return null on error
          });
        });
      }

      // Get FCM token (now that permission is granted)
      await _getToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM token refreshed: $newToken');
        _updateTokenInDatabase(newToken);
      });

      print('✅ Push notification mobile initialization completed');
    } catch (e) {
      print('⚠️ Error completing mobile initialization: $e');
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
        print('📱 Foreground message received: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Handle notification taps (when app is in background or terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 Notification tapped: ${message.messageId}');
        _handleNotificationTapFromMessage(message);
      });

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('📱 App opened from terminated state via notification');
        _handleNotificationTapFromMessage(initialMessage);
      }
    } catch (e) {
      // On web, FCM may not be available
      if (kIsWeb) {
        print('ℹ️ FCM message handlers not available on web: $e');
        // Don't throw - in-app notifications still work
      } else {
        // Don't rethrow - allow app to continue
        print('⚠️ Error setting up message handlers: $e');
      }
    }
  }

  /// Handle foreground message (show local notification)
  Future<void> _handleForegroundMessage(dynamic message) async {
    // Skip on web - web handles notifications differently via FCM
    if (kIsWeb) {
      print('📱 Web foreground notification received - handled by browser');
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
    print('📱 Local notification tapped: $payload');
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
            print('⚠️ APNS token not available yet - this is normal on simulator or before permission is granted');
            print('ℹ️ FCM token will be available once APNS token is set (usually after permission is granted)');
            // Don't throw error - this is expected behavior on iOS simulator or before permission
            return null;
          }
          print('✅ APNS token obtained: $apnsToken');
        } catch (apnsError) {
          // If APNS token fails, it might be because:
          // 1. Running on simulator (APNS not available)
          // 2. Permission not granted yet
          // 3. App not properly configured for push notifications
          print('⚠️ Could not get APNS token: $apnsError');
          print('ℹ️ This is normal on iOS simulator or before permission is granted');
          // Continue anyway - might still work on real device
        }
      }

      // Now get FCM token
      _currentToken = await _firebaseMessaging.getToken();
      if (_currentToken != null) {
        print('✅ FCM token obtained: $_currentToken');
        await _storeTokenInDatabase(_currentToken!);
      } else {
        print('⚠️ FCM token is null');
      }
      return _currentToken;
    } catch (e) {
      // Check if it's the APNS token error
      final errorString = e.toString();
      if (errorString.contains('apns-token-not-set')) {
        print('⚠️ APNS token not set yet - this is normal on iOS simulator or before permission is granted');
        print('ℹ️ Push notifications will work once APNS token is available (usually on real device after permission)');
        // Don't treat this as a critical error - it's expected behavior
        return null;
      }
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Store FCM token in database
  Future<void> _storeTokenInDatabase(String token) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ User not authenticated, cannot store FCM token');
        return;
      }

      // Get device info
      final deviceInfo = await _getDeviceInfo();
      final platform = _getPlatform();
      
      // Check if token already exists
      final existingToken = await SupabaseService.client
          .from('fcm_tokens')
          .select()
          .eq('token', token)
          .maybeSingle();

      if (existingToken != null) {
        // Update existing token
        await SupabaseService.client
            .from('fcm_tokens')
            .update({
              'is_active': true,
              'platform': platform,
              'device_id': deviceInfo['device_id'],
              'device_name': deviceInfo['device_name'],
              'app_version': deviceInfo['app_version'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingToken['id']);
        
        print('✅ FCM token updated in database');
      } else {
        // Insert new token
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
        
        print('✅ FCM token stored in database');
      }
    } catch (e) {
      print('❌ Error storing FCM token: $e');
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
      print('❌ Error getting device info: $e');
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

      print('✅ All FCM tokens deactivated for user');
    } catch (e) {
      print('❌ Error deactivating FCM tokens: $e');
    }
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;

  /// Check if initialized
  bool get isInitialized => _initialized;
}

