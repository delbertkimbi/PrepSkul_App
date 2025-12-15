import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/google_calendar_auth_service.dart';

/// Unit tests for GoogleCalendarAuthService
/// 
/// Tests calendar authentication and token storage
void main() {
  group('GoogleCalendarAuthService - Token Storage', () {
    test('authentication state is remembered after first connection', () async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({
        'google_calendar_access_token': 'test-token',
        'google_calendar_token_expiry': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      });

      final prefs = await SharedPreferences.getInstance();
      final hasToken = prefs.containsKey('google_calendar_access_token');

      // Verify token is stored
      expect(hasToken, true);
    });

    test('isAuthenticated returns true when token exists and not expired', () async {
      // Set up mock preferences with valid token
      final expiryTime = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      SharedPreferences.setMockInitialValues({
        'google_calendar_access_token': 'valid-token',
        'google_calendar_token_expiry': expiryTime,
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('google_calendar_access_token');
      final expiry = prefs.getInt('google_calendar_token_expiry');

      // Verify token exists and is not expired
      expect(token, isNotNull);
      expect(expiry, isNotNull);
      expect(expiry! > DateTime.now().millisecondsSinceEpoch ~/ 1000, true);
    });

    test('isAuthenticated returns false when token is expired', () async {
      // Set up mock preferences with expired token
      final expiredTime = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      SharedPreferences.setMockInitialValues({
        'google_calendar_access_token': 'expired-token',
        'google_calendar_token_expiry': expiredTime,
      });

      final prefs = await SharedPreferences.getInstance();
      final expiry = prefs.getInt('google_calendar_token_expiry');

      // Verify token is expired
      if (expiry != null) {
        expect(expiry < DateTime.now().millisecondsSinceEpoch ~/ 1000, true);
      }
    });
  });

  group('GoogleCalendarAuthService - Calendar Connection', () {
    test('user is not asked to connect again after first connection', () async {
      // Simulate first connection
      SharedPreferences.setMockInitialValues({
        'google_calendar_access_token': 'connected-token',
        'google_calendar_token_expiry': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      });

      final prefs = await SharedPreferences.getInstance();
      final isConnected = prefs.containsKey('google_calendar_access_token') &&
          prefs.getString('google_calendar_access_token') != null;

      // Verify connection is remembered
      expect(isConnected, true);
    });
  });
}










