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
      
      // Fapshi API credentials
      if (key == 'FAPSHI_SANDBOX_API_USER' || key == 'FAPSHI_COLLECTION_API_USER_LIVE') {
        try {
          directValue = js.context.callMethod('eval', [
            '(typeof window !== "undefined" && window.env && window.env.$key) || null'
          ])?.toString();
          
          if (directValue != null && directValue != 'null' && directValue.isNotEmpty) {
            LogService.info('✅ [WINDOW_ENV] Found $key via direct eval');
            return directValue;
          }
        } catch (e) {
          LogService.debug('🔍 [WINDOW_ENV] Direct eval failed for Fapshi User: $e');
        }
      }
      
      if (key == 'FAPSHI_SANDBOX_API_KEY' || key == 'FAPSHI_COLLECTION_API_KEY_LIVE') {
        try {
          directValue = js.context.callMethod('eval', [
            '(typeof window !== "undefined" && window.env && window.env.$key) || null'
          ])?.toString();
          
          if (directValue != null && directValue != 'null' && directValue.isNotEmpty) {
            LogService.info('✅ [WINDOW_ENV] Found $key via direct eval');
            return directValue;
          }
        } catch (e) {
          LogService.debug('🔍 [WINDOW_ENV] Direct eval failed for Fapshi Key: $e');
        }
      }
      
      // Method 2 removed: direct object-index access can throw on some web runtimes.
      // Direct `eval` path above is the canonical/fail-safe lookup.
      LogService.warning('⚠️ [WINDOW_ENV] Key $key not found in window.env');
    } catch (e, stackTrace) {
      LogService.error('❌ [WINDOW_ENV] Error reading window.env.$key: $e');
      LogService.error('❌ [WINDOW_ENV] Stack: $stackTrace');
    }
    return null;
  }
}