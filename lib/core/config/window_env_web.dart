// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:prepskul/core/services/log_service.dart';

/// Web implementation for reading window.env
/// Uses direct JavaScript evaluation for maximum reliability
class WindowEnvHelper {
  static String? getEnv(String key) {
    try {
      // Method 1: Direct JavaScript evaluation (most reliable)
      // This directly evaluates JavaScript code to access window.env
      String? directValue;
      
      if (key == 'SUPABASE_URL_PROD' || key == 'SUPABASE_URL_DEV') {
        try {
          // Directly evaluate: window.env?.NEXT_PUBLIC_SUPABASE_URL
          directValue = js.context.callMethod('eval', [
            '(typeof window !== "undefined" && window.env && window.env.NEXT_PUBLIC_SUPABASE_URL) || null'
          ])?.toString();
          
          if (directValue != null && directValue != 'null' && directValue.isNotEmpty) {
            LogService.info('✅ [WINDOW_ENV] Found $key via direct eval = ${directValue.length > 30 ? directValue.substring(0, 30) + "..." : directValue}');
            return directValue;
          }
        } catch (e) {
          LogService.debug('🔍 [WINDOW_ENV] Direct eval failed for URL: $e');
        }
      }
      
      if (key == 'SUPABASE_ANON_KEY_PROD' || key == 'SUPABASE_ANON_KEY_DEV') {
        try {
          // Directly evaluate: window.env?.NEXT_PUBLIC_SUPABASE_ANON_KEY
          directValue = js.context.callMethod('eval', [
            '(typeof window !== "undefined" && window.env && window.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) || null'
          ])?.toString();
          
          if (directValue != null && directValue != 'null' && directValue.isNotEmpty) {
            LogService.info('✅ [WINDOW_ENV] Found $key via direct eval = ${directValue.length > 20 ? directValue.substring(0, 20) + "..." : "SET"}');
            return directValue;
          }
        } catch (e) {
          LogService.debug('🔍 [WINDOW_ENV] Direct eval failed for KEY: $e');
        }
      }
      
      // Method 2: Object access (fallback)
      final context = js.context;
      if (context == null) {
        LogService.warning('⚠️ [WINDOW_ENV] js.context is null');
        return null;
      }
      
      final window = context['window'];
      if (window == null) {
        LogService.warning('⚠️ [WINDOW_ENV] window object is null');
        return null;
      }
      
      final windowEnv = window['env'];
      if (windowEnv == null) {
        LogService.warning('⚠️ [WINDOW_ENV] window.env is null - check index.html');
        return null;
      }
      
      // Try accessing as JsObject
      try {
        final envObj = windowEnv as js.JsObject;
        
        // Log available keys
        try {
          final keys = js.context.callMethod('Object.keys', [envObj]);
          LogService.info('🔍 [WINDOW_ENV] Available keys: $keys');
        } catch (_) {}
        
        // Try Next.js naming
        if (key == 'SUPABASE_URL_PROD' || key == 'SUPABASE_URL_DEV') {
          final value = envObj['NEXT_PUBLIC_SUPABASE_URL']?.toString();
          if (value != null && value.isNotEmpty && value != 'null') {
            LogService.info('✅ [WINDOW_ENV] Found $key via JsObject = ${value.length > 30 ? value.substring(0, 30) + "..." : value}');
            return value;
          }
        }
        
        if (key == 'SUPABASE_ANON_KEY_PROD' || key == 'SUPABASE_ANON_KEY_DEV') {
          final value = envObj['NEXT_PUBLIC_SUPABASE_ANON_KEY']?.toString();
          if (value != null && value.isNotEmpty && value != 'null') {
            LogService.info('✅ [WINDOW_ENV] Found $key via JsObject = ${value.length > 20 ? value.substring(0, 20) + "..." : "SET"}');
            return value;
          }
        }
      } catch (e) {
        LogService.warning('⚠️ [WINDOW_ENV] JsObject access failed: $e');
      }
      
      LogService.warning('⚠️ [WINDOW_ENV] Key $key not found in window.env');
    } catch (e, stackTrace) {
      LogService.error('❌ [WINDOW_ENV] Error reading window.env.$key: $e');
      LogService.error('❌ [WINDOW_ENV] Stack: $stackTrace');
    }
    return null;
  }
}