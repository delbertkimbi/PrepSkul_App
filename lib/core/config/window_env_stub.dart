/// Stub implementation of WindowEnvHelper for non-web platforms
/// On mobile/desktop, window.env doesn't exist, so always returns null
class WindowEnvHelper {
  static String? getEnv(String key) {
    // Not available on non-web platforms
    return null;
  }
}

