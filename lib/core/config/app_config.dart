import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
// Conditional import for web-only WindowEnvHelper
import 'package:prepskul/core/config/window_env_stub.dart'
    if (dart.library.html) 'package:prepskul/core/config/window_env_web.dart';

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
  /// ⚠️ Always verify environment variables are Rset correctly:
  /// - Production: FAPSHI_COLLECTION_API_USER_LIVE, FAPSHI_COLLECTION_API_KEY_LIVE
  /// - Sandbox: FAPSHI_SANDBOX_API_USER, FAP.eSHI_SANDBOX_API_KEY
  static const bool isProduction = false; // ← PRODUCTION MODE ENABLED

  // ============================================
  // 🚀 v1 launch defaults (see docs/LAUNCH_SCOPE.md)
  // ============================================
  // - enableGroupClasses: false unless GROUP_CLASSES_ENABLED=true in .env / window.env
  // - enableSkulMate: true in code; set false for launch if SkulMate is out of UAT scope
  // - Group classes: online-only when enabled; deferred for v1 marketplace launch
  
  // ============================================
  // 🔐 Authentication Feature Flags
  // ============================================
  
  /// Enable/disable Google Sign-In for user authentication
  /// 
  /// Set to `false` until Google Cloud Console verification is complete.
  /// This only affects user authentication, not Google Calendar OAuth.
  static const bool enableGoogleSignIn = true; // Google Sign-In enabled (uses basic scopes only)
  
  /// Enable/disable Phone Sign-In for user authentication
  /// 
  /// Set to `false` until phone verification is fully tested and ready.
  /// Phone login requires additional backend setup for SMS verification.
  static const bool enablePhoneSignIn = true; // ← Enabled for phone OTP authentication

  /// Enable/disable Phone OTP verification flows.
  ///
  /// Initial state is OFF. Flip to `true` when OTP provider is ready.
  /// This is intentionally code-controlled to avoid accidental env overrides.
  static const bool enablePhoneOtpVerification = false;
  
  /// Enable/disable SkulMate feature (game generation and library).
  ///
  /// v1 launch: keep `true` only if SkulMate is in UAT scope; otherwise set `false`.
  /// See docs/LAUNCH_SCOPE.md §4 (SkulMate in/out).
  static const bool enableSkulMate = true;

  /// Enable/disable PrepSkul VA (session summary, analysis, notifications)
  ///
  /// Backend VA uses PREPSKUL_VA_ENABLED env (default true; set to 'false' to disable).
  /// Use this for app-level feature gating (e.g. show/hide summary UI).
  static bool get enablePrepSkulVA {
    try {
      final v = dotenv.env['PREPSKUL_VA_ENABLED']?.toLowerCase();
      if (v == 'false' || v == '0' || v == 'no') return false;
      if (v == 'true' || v == '1' || v == 'yes') return true;
    } catch (_) {}
    return true;
  }

  // ============================================
  // Session Configuration
  // ============================================
  
  /// Session duration in minutes
  /// 
  /// Default duration for all video sessions EXCEPT 30-minute trial sessions.
  /// - 30-minute trial sessions always use 30 minutes (constant, handled separately)
  /// - 1-hour trial sessions and all regular sessions use this value
  /// 
  /// Change this value to adjust session length across the entire app.
  /// Example: Set to 60 for 1-hour sessions, 20 for testing, etc.
  static const int sessionDurationMinutes = 60; // ← Total time for regular sessions
  
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
  
  /// Get effective API base URL.
  ///
  /// IMPORTANT:
  /// - In production, NEVER uses localhost, always uses the deployed API.
  /// - On web, we default to the deployed API as well, unless the developer
  ///   explicitly sets API_BASE_URL_DEV to a localhost URL in .env.
  static String get effectiveApiBaseUrl {
    // CRITICAL: If production mode is enabled, NEVER use localhost
    if (isProd) {
      final prodUrl = 'https://www.prepskul.com/api';
      if (kDebugMode) {
        print('🌐 Production mode enabled - using: $prodUrl');
      }
      return prodUrl;
    }
    
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
        }
      } catch (e) {
        // If hostname detection fails, fall through to normal logic
        if (kDebugMode) {
          print('⚠️ Could not detect hostname: $e');
        }
      }
    }
    
    // In dev, allow explicit localhost / emulator API from .env on ALL platforms.
    if (!isProd) {
      final envApiUrl = _safeEnv('API_BASE_URL_DEV', '');
      final looksLocal = envApiUrl.contains('localhost') ||
          envApiUrl.contains('127.0.0.1') ||
          envApiUrl.contains('10.0.2.2');
      if (envApiUrl.isNotEmpty && looksLocal) {
        if (kDebugMode) {
          print('🏠 Using explicit dev API from .env: $envApiUrl');
        }
        return envApiUrl;
      }
    }

    // For web builds, normalize app.prepskul.com/api -> www.prepskul.com/api
    // unless localhost is explicitly configured above.
    if (kIsWeb) {
      url = url.replaceAll('://app.prepskul.com', '://www.prepskul.com');
    }

    return url;
  }

  /// Base URL for Next.js SkulMate HTTP routes (`/api/skulmate/*`).
  ///
  /// Flutter web calls to `https://app.prepskul.com/api/...` can hit a different
  /// edge deployment than `https://www.prepskul.com/api`, where SkulMate `POST`/`OPTIONS`
  /// CORS is implemented. On web we therefore normalize `app.prepskul.com` → `www.prepskul.com`.
  ///
  /// Override with env **`SKULMATE_HTTP_API_BASE`** (e.g. `http://localhost:3000/api`) for local Next.
  static String get skulMateHttpApiBase {
    try {
      final o = _safeEnv('SKULMATE_HTTP_API_BASE', '').trim();
      if (o.isNotEmpty) {
        return o.endsWith('/') ? o.substring(0, o.length - 1) : o;
      }
    } catch (_) {}
    var base = effectiveApiBaseUrl;
    if (kIsWeb) {
      base = _normalizeSkulMateApiHostForWeb(base);
    }
    return base;
  }

  /// Flutter web on `app.prepskul.com` must call SkulMate on `www` where CORS + routes are aligned.
  static String _normalizeSkulMateApiHostForWeb(String base) {
    try {
      final uri = Uri.parse(base);
      if (uri.hasScheme && uri.host == 'app.prepskul.com') {
        return uri.replace(host: 'www.prepskul.com').toString();
      }
    } catch (_) {}
    return base.replaceAll('://app.prepskul.com', '://www.prepskul.com');
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

  /// VA documentation page (public, no login). Opens in browser so user stays in app.
  static String get vaDocumentationUrl => '$webBaseUrl/en/va-documentation';

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

  /// Enable classroom QoE telemetry events
  static bool get enableClassroomQoeTelemetry {
    return _safeEnvBool('CLASSROOM_QOE_TELEMETRY_ENABLED', true);
  }

  /// Enable classroom orchestrator-driven flow (safe rollout flag).
  static bool get enableClassroomOrchestrator {
    return _safeEnvBool('CLASSROOM_ORCHESTRATOR_ENABLED', true);
  }

  /// Enable dual-stream policy (safe rollout flag).
  static bool get enableClassroomDualStream {
    return _safeEnvBool('CLASSROOM_DUAL_STREAM_ENABLED', true);
  }

  /// Subscribe to workspace sync packets over Supabase Realtime during sessions.
  static bool get enableClassroomWorkspaceRealtime {
    return _safeEnvBool('CLASSROOM_WORKSPACE_REALTIME_ENABLED', true);
  }

  /// Tutoring audio profile strategy for Agora.
  ///
  /// Supported values:
  /// - `speech` (default): speech standard + chatroom scenario.
  /// - `balanced`: speech standard + meeting scenario.
  /// - `music`: music standard + game streaming scenario.
  /// - `ab`: deterministic A/B per session (speech vs balanced).
  static String get classroomAudioProfileMode {
    final raw = _safeEnv('CLASSROOM_AUDIO_PROFILE_MODE', 'speech')
        .trim()
        .toLowerCase();
    switch (raw) {
      case 'speech':
      case 'balanced':
      case 'music':
      case 'ab':
        return raw;
      default:
        return 'speech';
    }
  }

  /// Optional backup call URL shown in in-call recovery mode.
  /// Example: `https://meet.google.com/xxx-yyyy-zzz`.
  static String get classroomBackupCallUrl {
    return _safeEnv('CLASSROOM_BACKUP_CALL_URL', '').trim();
  }

  /// If local camera never reaches capturing/encoding within a grace period, show a
  /// one-time “Continue audio only” action (tutoring-friendly fallback).
  static bool get enableClassroomAudioOnlyFallback {
    return _safeEnvBool('CLASSROOM_AUDIO_ONLY_FALLBACK_ENABLED', true);
  }

  /// When false, live sessions stay voice-first: no camera toggle in-call, no publish
  /// from join regardless of pre-join. Default true so preview + classroom match Preply parity;
  /// set false temporarily if web/native camera regressions need a safe fallback.
  static const bool enableSessionCameraPublishing = true;

  /// When false, learners do not get Share screen affordances (dock / More); tutor presents only.
  /// Receiving a tutor's screen share is unchanged. Flip to true if product allows learner share (e.g. homework).
  static const bool enableLearnerScreenShare = true;

  /// Enable group classes flows (online group sessions; post-v1 rollout).
  ///
  /// v1 launch default: **false**. Set env `GROUP_CLASSES_ENABLED=true` to enable.
  /// UI entry points (tutor home, find tutors, deep links) must check this flag.
  static bool get enableGroupClasses {
    return _safeEnvBool('GROUP_CLASSES_ENABLED', false);
  }

  /// Dev-only QA account quick switch panel on login screen.
  static bool get enableQaQuickSwitch {
    if (!kDebugMode || isProd) return false;
    return _safeEnvBool('QA_QUICK_SWITCH_ENABLED', true);
  }

  static String get qaTutorPhone => _safeEnv('QA_TUTOR_PHONE', '');
  static String get qaTutorPassword => _safeEnv('QA_TUTOR_PASSWORD', '');
  static String get qaLearnerPhone => _safeEnv('QA_LEARNER_PHONE', '');
  static String get qaLearnerPassword => _safeEnv('QA_LEARNER_PASSWORD', '');
  static String get qaObserverPhone => _safeEnv('QA_OBSERVER_PHONE', '');
  static String get qaObserverPassword => _safeEnv('QA_OBSERVER_PASSWORD', '');

  /// Dev-only bypass for joining booked sessions from any QA account until expiry.
  ///
  /// Safety:
  /// - Always false in production mode.
  /// - Enabled only in debug/dev when explicitly toggled.
  static bool get enableQaSessionJoinBypass {
    if (isProd) return false;
    return _safeEnvBool('QA_SESSION_JOIN_BYPASS_ENABLED', false);
  }
  
  // ============================================
  // Helper Methods
  // ============================================
  
  /// Safely read environment variable with fallback.
  /// On web, checks window.env (injected at build time) when dotenv is empty.
  static String _safeEnv(String key, String fallback) {
    try {
      String? value = dotenv.env[key];
      if (value != null && value.isNotEmpty) return value;
      // On web production, dotenv may not be available; use window.env from inject-env.js
      if (kIsWeb) {
        value = WindowEnvHelper.getEnv(key);
        if (value != null && value.isNotEmpty) return value;
      }
      return fallback;
    } catch (_) {
      if (kIsWeb) {
        final value = WindowEnvHelper.getEnv(key);
        if (value != null && value.isNotEmpty) return value;
      }
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














