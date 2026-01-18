import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:prepskul/core/config/window_env_web.dart' if (dart.library.io) 'package:prepskul/core/config/window_env_stub.dart';

/// Centralized App Configuration
/// 
/// Switch between production and sandbox with ONE line:
/// 
/// ```dart
/// // In app_config.dart, change this:
/// static const bool isProduction = false; // true for production, false for sandbox
/// ```
/// 
/// All services automatically use the correct environment based on this flag.
class AppConfig {
  // ============================================
  // 🔄 CHANGE THIS ONE LINE TO SWITCH ENVIRONMENTS
  // ============================================
  /// Set to `true` for production, `false` for sandbox/development
  /// 
  /// ⚠️⚠️⚠️ PAYMENT MODE WARNING ⚠️⚠️⚠️
  /// 
  /// CURRENT MODE: SANDBOX (TEST MODE) - NO REAL MONEY WILL BE CHARGED
  /// 
  /// When `isProduction = false`:
  /// - ✅ All payments are SIMULATED in sandbox mode
  /// - ✅ No real money will be charged
  /// - ✅ Safe for testing and development
  /// - ✅ Uses sandbox.fapshi.com (test environment)
  /// 
  /// When `isProduction = true`:
  /// - ⚠️ REAL payments will be processed
  /// - ⚠️ REAL money will be charged
  /// - ⚠️ Uses live.fapshi.com (production environment)
  /// 
  /// This controls:
  /// - Fapshi API endpoints (live vs sandbox)
  /// - API credentials (production vs development)
  /// - All payment processing
  /// 
  /// ⚠️ Always verify environment variables are set correctly:
  /// - Production: FAPSHI_COLLECTION_API_USER_LIVE, FAPSHI_COLLECTION_API_KEY_LIVE
  /// - Sandbox: FAPSHI_SANDBOX_API_USER, FAPSHI_SANDBOX_API_KEY
  static const bool isProduction = false; // ← SANDBOX MODE (TEST MODE - NO REAL PAYMENTS)
  
  // ============================================
  // 🔐 Authentication Feature Flags
  // ============================================
  
  /// Enable/disable Google Sign-In for user authentication
  /// 
  /// Set to `false` until Google Cloud Console verification is complete.
  /// This only affects user authentication, not Google Calendar OAuth.
  static const bool enableGoogleSignIn = false; // ← Disabled until Google verification complete
  
  /// Enable/disable SkulMate feature
  /// 
  /// Set to `true` to enable SkulMate (game generation and library).
  /// Set to `false` to disable SkulMate in production.
  static const bool enableSkulMate = false; // ← Disabled in production until RLS issues are resolved
  
  // ============================================
  // Environment Detection
  // ============================================
  
  /// Get environment from .env file or use isProduction flag
  /// Code-level flag takes precedence over env var
  static bool get _envIsProduction {
    // Code-level flag takes precedence
    if (isProduction) return true;
    
    // Then check env var as override
    try {
      final envValue = dotenv.env['ENVIRONMENT']?.toLowerCase();
      if (envValue == 'production' || envValue == 'prod') return true;
      if (envValue == 'development' || envValue == 'dev') return false;
    } catch (_) {
      // dotenv not loaded
    }
    
    return false; // Default to sandbox if nothing set
  }
  
  /// Current environment (production or sandbox)
  static bool get isProd => _envIsProduction;
  
  /// Current environment name
  static String get environment => isProd ? 'production' : 'sandbox';
  
  // ============================================
  // API URLs
  // ============================================
  
  /// Base API URL
  static String get apiBaseUrl {
    if (isProd) {
      // Production now uses the custom domain prepskul.com
      return _safeEnv('API_BASE_URL_PROD', 'https://www.prepskul.com/api');
    } else {
      return _safeEnv('API_BASE_URL_DEV', 'https://www.prepskul.com/api');
    }
  }
  
  /// Get effective API base URL (with localhost detection for local development)
  /// 
  /// Automatically detects when running locally on web and uses localhost:3000
  /// for the Next.js dev server. This ensures local development works seamlessly
  /// without requiring environment variable changes.
  /// 
  /// IMPORTANT: If running on production domains (app.prepskul.com, www.prepskul.com),
  /// always uses production API regardless of isProduction flag.
  static String get effectiveApiBaseUrl {
    String url = apiBaseUrl;
    
    // Check if we're running on a production domain (web platform only)
    if (kIsWeb) {
      try {
        // Use conditional import for web platform
        // ignore: avoid_dynamic_calls
        final hostname = (() {
          try {
            // Dynamic import for dart:html (only available on web)
            // ignore: avoid_dynamic_calls
            return (Uri.base.host);
          } catch (_) {
            return '';
          }
        })();
        
        if (hostname.isNotEmpty) {
          final isProductionDomain = hostname.contains('prepskul.com') || 
                                     hostname.contains('app.prepskul.com') ||
                                     hostname.contains('www.prepskul.com');
          
          // If on production domain, always use production API
          if (isProductionDomain) {
            if (kDebugMode) {
              print('🌐 Production domain detected: $hostname');
              print('🌐 Using production API: https://www.prepskul.com/api');
            }
            return 'https://www.prepskul.com/api';
          }
          
          // If on localhost, use localhost API
          if (hostname == 'localhost' || hostname == '127.0.0.1') {
            if (kDebugMode) {
              print('🏠 Local development detected: $hostname');
              print('🏠 Using localhost API: http://localhost:3000/api');
            }
            return 'http://localhost:3000/api';
          }
        }
      } catch (e) {
        // If hostname detection fails, fall through to normal logic
        if (kDebugMode) {
          print('⚠️ Could not detect hostname: $e');
        }
      }
    }
    
    // Fallback: If running locally on web in non-production mode, use localhost
    if (kIsWeb && !isProd) {
      // Check if API_BASE_URL_DEV is explicitly set to localhost in .env
      final envApiUrl = _safeEnv('API_BASE_URL_DEV', '');
      
      // If not explicitly set to localhost, automatically use localhost for local Next.js dev server
      if (!url.contains('localhost') && !url.contains('127.0.0.1') && 
          !envApiUrl.contains('localhost') && !envApiUrl.contains('127.0.0.1')) {
        if (kDebugMode) {
          print('🎯 Local development detected. Using localhost:3000 for Next.js API.');
          print('🎯 To override, set API_BASE_URL_DEV=http://localhost:3000/api in .env');
        }
        return 'http://localhost:3000/api';
      }
    }
    
    return url;
  }
  
  /// App Base URL
  static String get appBaseUrl {
    if (isProd) {
      return _safeEnv('APP_BASE_URL_PROD', 'https://app.prepskul.com');
    } else {
      return _safeEnv('APP_BASE_URL_DEV', 'https://app.prepskul.com');
    }
  }
  
  /// Web Base URL
  static String get webBaseUrl {
    if (isProd) {
      return _safeEnv('WEB_BASE_URL_PROD', 'https://www.prepskul.com');
    } else {
      return _safeEnv('WEB_BASE_URL_DEV', 'https://www.prepskul.com');
    }
  }
  
  // ============================================
  // Fapshi Payment Configuration
  // ============================================
  
  /// Fapshi environment (sandbox or live)
  static String get fapshiEnvironment => isProd ? 'live' : 'sandbox';
  
  /// Fapshi Base URL
  static String get fapshiBaseUrl {
    return isProd
        ? 'https://live.fapshi.com'
        : 'https://sandbox.fapshi.com';
  }
  
  /// Fapshi API User (Collection)
  static String get fapshiApiUser {
    if (isProd) {
      return _safeEnv('FAPSHI_COLLECTION_API_USER_LIVE', '');
    } else {
      return _safeEnv('FAPSHI_SANDBOX_API_USER', '');
    }
  }
  
  /// Fapshi API Key (Collection)
  static String get fapshiApiKey {
    if (isProd) {
      return _safeEnv('FAPSHI_COLLECTION_API_KEY_LIVE', '');
    } else {
      return _safeEnv('FAPSHI_SANDBOX_API_KEY', '');
    }
  }
  
  /// Fapshi Disbursement API User
  static String get fapshiDisburseApiUser {
    if (isProd) {
      return _safeEnv('FAPSHI_DISBURSE_API_USER_LIVE', '');
    } else {
      return _safeEnv('FAPSHI_SANDBOX_API_USER', ''); // Same for sandbox
    }
  }
  
  /// Fapshi Disbursement API Key
  static String get fapshiDisburseApiKey {
    if (isProd) {
      return _safeEnv('FAPSHI_DISBURSE_API_KEY_LIVE', '');
    } else {
      return _safeEnv('FAPSHI_SANDBOX_API_KEY', ''); // Same for sandbox
    }
  }
  
  // ============================================
  // Supabase Configuration
  // ============================================
  
  /// Supabase URL
  static String get supabaseUrl {
    if (isProd) {
      return _safeEnv('SUPABASE_URL_PROD', '');
    } else {
      return _safeEnv('SUPABASE_URL_DEV', '');
    }
  }
  
  /// Supabase Anon Key
  static String get supabaseAnonKey {
    if (isProd) {
      return _safeEnv('SUPABASE_ANON_KEY_PROD', '');
    } else {
      return _safeEnv('SUPABASE_ANON_KEY_DEV', '');
    }
  }
  
  /// Supabase Service Role Key
  static String get supabaseServiceRoleKey {
    if (isProd) {
      return _safeEnv('SUPABASE_SERVICE_ROLE_KEY_PROD', '');
    } else {
      return _safeEnv('SUPABASE_SERVICE_ROLE_KEY_DEV', '');
    }
  }
  
  // ============================================
  // Firebase Configuration
  // ============================================
  
  /// Firebase Project ID
  static String get firebaseProjectId {
    return _safeEnv('FIREBASE_PROJECT_ID', '');
  }
  
  /// Firebase Service Account Key (JSON string)
  static String get firebaseServiceAccountKey {
    return _safeEnv('FIREBASE_SERVICE_ACCOUNT_KEY', '');
  }
  
  // ============================================
  // Google Calendar Configuration
  // ============================================
  
  /// Google Calendar OAuth Client ID
  static String get googleCalendarClientId {
    if (isProd) {
      return _safeEnv('GOOGLE_CALENDAR_CLIENT_ID_PROD', '');
    } else {
      return _safeEnv('GOOGLE_CALENDAR_CLIENT_ID_DEV', '');
    }
  }
  
  /// Google Calendar OAuth Client Secret
  static String get googleCalendarClientSecret {
    if (isProd) {
      return _safeEnv('GOOGLE_CALENDAR_CLIENT_SECRET_PROD', '');
    } else {
      return _safeEnv('GOOGLE_CALENDAR_CLIENT_SECRET_DEV', '');
    }
  }
  
  /// Google OAuth Redirect URI
  static String get googleOAuthRedirectUri {
    if (isProd) {
      return _safeEnv('GOOGLE_OAUTH_REDIRECT_URI_PROD', 'https://app.prepskul.com/auth/google/callback');
    } else {
      return _safeEnv('GOOGLE_OAUTH_REDIRECT_URI_DEV', 'https://app.prepskul.com/auth/google/callback');
    }
  }
  
  // ============================================
  // Fathom AI Configuration
  // ============================================
  
  /// Fathom OAuth Client ID
  static String get fathomClientId {
    if (isProd) {
      return _safeEnv('FATHOM_CLIENT_ID_PROD', '');
    } else {
      return _safeEnv('FATHOM_CLIENT_ID_DEV', '');
    }
  }
  
  /// Fathom OAuth Client Secret
  static String get fathomClientSecret {
    if (isProd) {
      return _safeEnv('FATHOM_CLIENT_SECRET_PROD', '');
    } else {
      return _safeEnv('FATHOM_CLIENT_SECRET_DEV', '');
    }
  }
  
  /// Fathom Redirect URI
  static String get fathomRedirectUri {
    if (isProd) {
      return _safeEnv('FATHOM_REDIRECT_URI_PROD', 'https://app.prepskul.com/auth/fathom/callback');
    } else {
      return _safeEnv('FATHOM_REDIRECT_URI_DEV', 'https://app.prepskul.com/auth/fathom/callback');
    }
  }
  
  /// Fathom Webhook Secret
  static String get fathomWebhookSecret {
    if (isProd) {
      return _safeEnv('FATHOM_WEBHOOK_SECRET_PROD', '');
    } else {
      return _safeEnv('FATHOM_WEBHOOK_SECRET_DEV', '');
    }
  }
  
  // ============================================
  // Email Service (Resend)
  // ============================================
  
  /// Resend API Key
  static String get resendApiKey {
    return _safeEnv('RESEND_API_KEY', '');
  }
  
  /// Resend From Email
  static String get resendFromEmail {
    return _safeEnv('RESEND_FROM_EMAIL', 'PrepSkul <noreply@mail.prepskul.com>');
  }
  
  /// Resend Reply To Email
  static String get resendReplyTo {
    return _safeEnv('RESEND_REPLY_TO', 'info@prepskul.com');
  }
  
  // ============================================
  // PrepSkul VA Email (for Fathom)
  // ============================================
  
  /// PrepSkul VA Email (added to calendar events for Fathom auto-join)
  static String get prepskulVAEmail {
    return _safeEnv('PREPSKUL_VA_EMAIL', 'prepskul-va@prepskul.com');
  }
  
  // ============================================
  // Feature Flags
  // ============================================
  
  /// Enable Fapshi Payments
  static bool get enableFapshiPayments {
    return _safeEnvBool('ENABLE_FAPSHI_PAYMENTS', true);
  }
  
  /// Enable Fathom Recording
  static bool get enableFathomRecording {
    return _safeEnvBool('ENABLE_FATHOM_RECORDING', true);
  }
  
  /// Enable Google Calendar
  static bool get enableGoogleCalendar {
    return _safeEnvBool('ENABLE_GOOGLE_CALENDAR', true);
  }
  
  /// Enable Email Notifications
  static bool get enableEmailNotifications {
    return _safeEnvBool('ENABLE_EMAIL_NOTIFICATIONS', true);
  }
  
  // ============================================
  // Helper Methods
  // ============================================
  
  /// Safely read environment variable with fallback
  /// On web, also checks window.env (injected at build time)
  static String _safeEnv(String key, String fallback) {
    // First try dotenv (for local development)
    try {
      final dotenvValue = dotenv.env[key];
      if (dotenvValue != null && dotenvValue.isNotEmpty) {
        return dotenvValue;
      }
    } catch (_) {
      // dotenv not initialized - continue to window.env check
    }
    
    // On web, also check window.env (injected at build time)
    if (kIsWeb) {
      try {
        final windowValue = WindowEnvHelper.getEnv(key);
        if (windowValue != null && windowValue.isNotEmpty && windowValue != 'null') {
          return windowValue;
        }
      } catch (_) {
        // window.env not available - fall through to fallback
      }
    }
    
    return fallback;
  }
  
  /// Safely read boolean environment variable
  static bool _safeEnvBool(String key, bool fallback) {
    try {
      final value = dotenv.env[key]?.toLowerCase();
      if (value == null || value.isEmpty) return fallback;
      return value == 'true' || value == '1' || value == 'yes';
    } catch (_) {
      return fallback;
    }
  }
  
  // ============================================
  // Debug Info
  // ============================================
  
  /// Print current configuration (for debugging)
  static void printConfig() {
    if (kDebugMode) {
      print('═══════════════════════════════════════');
      print('📱 PrepSkul App Configuration');
      print('═══════════════════════════════════════');
      if (isProd) {
        print('Environment: 🔴 PRODUCTION (REAL PAYMENTS)');
        print('⚠️⚠️⚠️ WARNING: REAL MONEY WILL BE CHARGED ⚠️⚠️⚠️');
      } else {
        print('Environment: 🟢 SANDBOX (TEST MODE)');
        print('✅ Payments are SIMULATED - No real money will be charged');
      }
      print('API Base URL: $apiBaseUrl');
      print('Fapshi Environment: $fapshiEnvironment');
      print('Fapshi Base URL: $fapshiBaseUrl');
      print('Supabase URL: ${supabaseUrl.isNotEmpty ? "✅ Set" : "❌ Not Set"}');
      print('Firebase: ${firebaseProjectId.isNotEmpty ? "✅ Set" : "❌ Not Set"}');
      print('Google Calendar: ${enableGoogleCalendar ? "✅ Enabled" : "❌ Disabled"}');
      print('Fathom: ${enableFathomRecording ? "✅ Enabled" : "❌ Disabled"}');
      print('═══════════════════════════════════════');
    }
  }
}














