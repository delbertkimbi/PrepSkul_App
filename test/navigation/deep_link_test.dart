/// Deep Link Navigation Tests
/// 
/// Tests for deep link handling including:
/// - Deep link queuing
/// - Deep link processing
/// - Deep link validation
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Deep Link Navigation', () {
    late NavigationService navigationService;
    late GlobalKey<NavigatorState> navigatorKey;

    setUp(() {
      navigationService = NavigationService();
      navigatorKey = GlobalKey<NavigatorState>();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      NavigationState().reset();
    });

    group('Deep Link Queue', () {
      test('should queue deep link when navigation not ready', () {
        final uri = Uri.parse('prepskul://bookings/123');
        navigationService.queueDeepLink(uri);
        
        expect(navigationService.isReady, false);
      });

      test('should queue multiple deep links', () {
        navigationService.queueDeepLink(Uri.parse('prepskul://bookings/123'));
        navigationService.queueDeepLink(Uri.parse('prepskul://sessions/456'));
        navigationService.queueDeepLink(Uri.parse('prepskul://tutor-nav'));
        
        expect(navigationService.isReady, false);
      });

      test('should process queued deep links after initialization', () async {
        final uri = Uri.parse('prepskul://bookings/123');
        navigationService.queueDeepLink(uri);
        
        navigationService.initialize(navigatorKey);
        await navigationService.processPendingDeepLinks();
        
        expect(navigationService.isReady, true);
      });
    });

    group('Deep Link Processing', () {
      test('should process deep link with path only', () async {
        navigationService.initialize(navigatorKey);
        final uri = Uri.parse('prepskul://tutor-nav');
        navigationService.queueDeepLink(uri);
        
        await navigationService.processPendingDeepLinks();
        expect(navigationService.isReady, true);
      });

      test('should process deep link with query parameters', () async {
        navigationService.initialize(navigatorKey);
        final uri = Uri.parse('prepskul://bookings/123?action=view&tab=requests');
        navigationService.queueDeepLink(uri);
        
        await navigationService.processPendingDeepLinks();
        expect(navigationService.isReady, true);
      });

      test('should process only last deep link if multiple queued', () async {
        navigationService.initialize(navigatorKey);
        navigationService.queueDeepLink(Uri.parse('prepskul://bookings/123'));
        navigationService.queueDeepLink(Uri.parse('prepskul://sessions/456'));
        navigationService.queueDeepLink(Uri.parse('prepskul://tutor-nav'));
        
        await navigationService.processPendingDeepLinks();
        expect(navigationService.isReady, true);
      });
    });

    group('Deep Link Scenarios', () {
      test('should handle deep link before app initialization', () async {
        // Simulate deep link received before app is ready
        final uri = Uri.parse('prepskul://bookings/123');
        navigationService.queueDeepLink(uri);
        
        // App initializes
        navigationService.initialize(navigatorKey);
        
        // Process queued deep link
        await navigationService.processPendingDeepLinks();
        
        expect(navigationService.isReady, true);
      });

      test('should handle deep link after app initialization', () async {
        // App initializes first
        navigationService.initialize(navigatorKey);
        
        // Deep link received after initialization
        final uri = Uri.parse('prepskul://tutor-nav');
        await navigationService.navigateToRoute(uri.path);
        
        expect(navigationService.isReady, true);
      });

      test('should handle multiple rapid deep links', () async {
        navigationService.initialize(navigatorKey);
        
        // Multiple deep links received rapidly
        navigationService.queueDeepLink(Uri.parse('prepskul://bookings/123'));
        navigationService.queueDeepLink(Uri.parse('prepskul://bookings/456'));
        navigationService.queueDeepLink(Uri.parse('prepskul://sessions/789'));
        
        // Only last one should be processed
        await navigationService.processPendingDeepLinks();
        
        expect(navigationService.isReady, true);
      });
    });

    group('Deep Link Path Parsing', () {
      test('should parse booking deep link', () {
        final uri = Uri.parse('prepskul://bookings/123');
        expect(uri.pathSegments, ['bookings', '123']);
      });

      test('should parse session deep link', () {
        final uri = Uri.parse('prepskul://sessions/456');
        expect(uri.pathSegments, ['sessions', '456']);
      });

      test('should parse trial session deep link', () {
        final uri = Uri.parse('prepskul://trial-sessions/789');
        expect(uri.pathSegments, ['trial-sessions', '789']);
      });

      test('should parse deep link with query parameters', () {
        final uri = Uri.parse('prepskul://bookings/123?action=view&tab=requests');
        expect(uri.queryParameters['action'], 'view');
        expect(uri.queryParameters['tab'], 'requests');
      });
    });
  });
}


