/// Stub implementation for non-web platforms
/// Always returns false for isIosWeb / isMobileWeb since we're not on web
class PlatformUtils {
  static bool get isIosWeb => false;
  static bool get isMobileWeb => false;
}
