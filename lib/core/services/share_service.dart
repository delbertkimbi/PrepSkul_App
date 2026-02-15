import 'package:share_plus/share_plus.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Share Service
///
/// Tutor profile sharing uses the "SEO proxy" approach: shared links point to
/// https://www.prepskul.com/tutor/[id] (Next.js). Scrapers get server-rendered
/// OG meta tags for rich previews; click-through is redirected to the app or Flutter Web.
class ShareService {
  /// Share tutor profile with rich preview (Next.js URL for scrapers).
  ///
  /// Shares https://www.prepskul.com/tutor/[id]. Platforms fetch og:* from that page.
  static Future<void> shareTutorProfile({
    required Map<String, dynamic> tutorData,
    required String tutorId,
    String? tutorName,
    String? tutorAvatarUrl,
    List<String>? subjects,
  }) async {
    try {
      final webUrl = _getWebUrl(tutorId);
      // Share only the URL. WhatsApp etc. fetch the link and show rich preview
      // (tutor photo, name, description) from Open Graph metadata on www.prepskul.com.
      await Share.share(
        webUrl,
        subject: 'PrepSkul Tutor',
      );
      LogService.success('Tutor profile shared (rich preview from link metadata)');
    } catch (e) {
      LogService.error('Error sharing tutor profile: $e');
      rethrow;
    }
  }

  /// Generate web URL for tutor profile (SEO proxy on Next.js).
  /// Shared links point to www.prepskul.com so WhatsApp/Facebook/Twitter scrapers
  /// get server-rendered HTML with og:image, og:title, og:description. Click-through
  /// is then redirected: mobile app opens via deep link, desktop goes to app.prepskul.com.
  static String _getWebUrl(String tutorId) {
    return 'https://www.prepskul.com/tutor/$tutorId';
  }
}

