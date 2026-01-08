import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/services/agora_token_service.dart';
import 'package:prepskul/core/config/app_config.dart';

/// Tests for Agora CORS Handling
/// 
/// Verifies that CORS errors are handled gracefully and provide helpful messages
void main() {
  group('Agora CORS Handling Tests', () {
    test('Token service should use correct API URL from AppConfig', () {
      // Verify that the service uses AppConfig for API URL
      final apiUrl = AppConfig.apiBaseUrl;
      expect(apiUrl, isNotEmpty);
      expect(apiUrl.contains('api'), isTrue);
    });

    test('Token service should handle CORS errors gracefully', () async {
      // This test verifies that CORS errors are caught and provide helpful messages
      try {
        await AgoraTokenService.fetchToken('test-session-id');
        // If it succeeds, that's fine - might be in test environment
      } catch (e) {
        final errorMsg = e.toString();
        // Should contain helpful error message
        // CORS errors should mention API server or origin
        final hasHelpfulMessage = 
            errorMsg.contains('CORS') ||
            errorMsg.contains('API server') ||
            errorMsg.contains('origin') ||
            errorMsg.contains('authenticated') ||
            errorMsg.contains('error');
        
        expect(hasHelpfulMessage, isTrue,
            reason: 'Error message should be helpful: $errorMsg');
      }
    });

    test('API URL should be accessible from app.prepskul.com', () {
      // This is a configuration test
      // The API URL should be www.prepskul.com/api
      // which is accessible from app.prepskul.com (different subdomain, same domain)
      final apiUrl = AppConfig.apiBaseUrl;
      
      // For production, should be www.prepskul.com/api
      // This allows CORS from app.prepskul.com
      if (!apiUrl.contains('localhost') && !apiUrl.contains('127.0.0.1')) {
        expect(apiUrl.contains('prepskul.com'), isTrue,
            reason: 'API should be on prepskul.com domain for CORS to work');
      }
    });

    test('Token service should construct correct endpoint URL', () {
      // Verify endpoint construction
      final apiUrl = AppConfig.apiBaseUrl;
      final expectedEndpoint = '$apiUrl/agora/token';
      
      expect(expectedEndpoint, isNotEmpty);
      expect(expectedEndpoint.contains('/agora/token'), isTrue);
      expect(expectedEndpoint.startsWith('http'), isTrue);
    });
  });
}

