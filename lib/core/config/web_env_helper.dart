import 'dart:html' as html;

/// Web-specific helper to read environment variables from window.env
/// This is used when dotenv is not available (production web builds)
/// 
/// Usage: getWindowEnv('SUPABASE_URL_PROD')
String? getWindowEnv(String key) {
  try {
    // Access window.env[key] using dart:html
    final window = html.window;
    final env = window['env'];
    if (env == null) return null;
    
    // Access the property using dynamic typing
    final value = (env as dynamic)[key];
    if (value == null) return null;
    
    // Convert JS value to Dart String
    return value.toString();
  } catch (_) {
    // window.env not available or key not found - this is normal for local dev
    return null;
  }
}

