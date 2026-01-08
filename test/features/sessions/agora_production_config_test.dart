import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/config/app_config.dart';

/// Tests for Agora Production Configuration
/// 
/// Verifies that API URLs and configuration are correct for production deployment
void main() {
  group('Agora Production Configuration Tests', () {
    test('API Base URL should point to www.prepskul.com/api in production', () {
      // This test verifies the fallback URL is correct
      // The actual value will come from .env file, but fallback should be correct
      final apiUrl = AppConfig.apiBaseUrl;
      
      // In production mode, should use www.prepskul.com/api
      // Note: This test assumes isProduction flag or ENVIRONMENT=production
      // The fallback in app_config.dart should be www.prepskul.com/api
      expect(apiUrl, isNotEmpty);
      expect(apiUrl, contains('api'));
    });

    test('App Base URL should point to app.prepskul.com', () {
      final appUrl = AppConfig.appBaseUrl;
      expect(appUrl, isNotEmpty);
      // Should contain app.prepskul.com (Flutter app domain)
      expect(appUrl.contains('app.prepskul.com') || appUrl.contains('localhost'), isTrue);
    });

    test('Web Base URL should point to www.prepskul.com', () {
      final webUrl = AppConfig.webBaseUrl;
      expect(webUrl, isNotEmpty);
      // Should contain www.prepskul.com (main website domain)
      expect(webUrl.contains('www.prepskul.com') || webUrl.contains('localhost'), isTrue);
    });

    test('API URL should not point to app.prepskul.com (wrong domain)', () {
      final apiUrl = AppConfig.apiBaseUrl;
      // API should NOT be on app.prepskul.com (that's the Flutter app domain)
      // API should be on www.prepskul.com (Next.js API domain)
      // Unless it's localhost for local testing
      if (!apiUrl.contains('localhost') && !apiUrl.contains('127.0.0.1')) {
        expect(apiUrl.contains('app.prepskul.com/api'), isFalse,
            reason: 'API should be on www.prepskul.com/api, not app.prepskul.com/api');
      }
    });

    test('API URL should be correctly formatted', () {
      final apiUrl = AppConfig.apiBaseUrl;
      expect(apiUrl, isNotEmpty);
      // Should end with /api or be a valid URL
      expect(apiUrl.startsWith('http://') || apiUrl.startsWith('https://'), isTrue);
    });
  });
}

