import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

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
  /// IMPORTANT: For production deployment, set this to `true`
  /// This controls:
  /// - Fapshi API endpoints (live vs sandbox)
  /// - API credentials (production vs development)
  /// - All payment processing
  /// 
  /// ⚠️ Always verify environment variables are set correctly:
  /// - Production: FAPSHI_COLLECTION_API_USER_LIVE, FAPSHI_COLLECTION_API_KEY_LIVE
  /// - Sandbox: FAPSHI_SANDBOX_API_USER, FAPSHI_SANDBOX_API_KEY
  static const bool isProduction = false; // ← PRODUCTION MODE ENABLED
  
  // ============================================
  // 🔐 Authentication Feature Flags
  // ============================================
  
  /// Enable/disable Google Sign-In for user authentication
  /// 
  /// Set to `false` until Google Cloud Console verification is complete.
  /// This only affects user authentication, not Google Calendar OAuth.
  static const bool enableGoogleSignIn = false; // ← Disabled until Google verification complete
  
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
  static String _safeEnv(String key, String fallback) {
    try {
      final value = dotenv.env[key];
      if (value == null || value.isEmpty) return fallback;
      return value;
    } catch (_) {
      // dotenv not initialized
      return fallback;
    }
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
      print('Environment: ${isProd ? "🔴 PRODUCTION" : "🟢 SANDBOX"}');
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














