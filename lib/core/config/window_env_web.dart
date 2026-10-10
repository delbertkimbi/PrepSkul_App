import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window.env')
external JSObject? get _windowEnv;

/// Reads only public browser configuration, without evaluating JavaScript.
class WindowEnvHelper {
  static const _publicKeys = {
    'SUPABASE_URL_PROD', 'SUPABASE_URL_DEV',
    'SUPABASE_ANON_KEY_PROD', 'SUPABASE_ANON_KEY_DEV',
    'ENVIRONMENT', 'API_BASE_URL_PROD', 'API_BASE_URL_DEV',
    'SKULMATE_HTTP_API_BASE', 'ENABLE_FAPSHI_PAYMENTS',
  };

  static String? getEnv(String key) {
    if (!_publicKeys.contains(key)) return null;
    try {
      final env = _windowEnv;
      if (env == null) return null;
      final alias = key.startsWith('SUPABASE_URL_')
          ? 'NEXT_PUBLIC_SUPABASE_URL'
          : key.startsWith('SUPABASE_ANON_KEY_')
              ? 'NEXT_PUBLIC_SUPABASE_ANON_KEY'
              : key;
      final raw = env.getProperty<JSAny?>(key.toJS) ??
          env.getProperty<JSAny?>(alias.toJS);
      final value = raw?.dartify();
      return value is String && value.isNotEmpty ? value : null;
    } catch (_) {
      return null;
    }
  }
}
