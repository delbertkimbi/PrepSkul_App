import 'package:share_plus/share_plus.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Share Service
/// 
/// Handles rich sharing of tutor profiles with images and deep links
/// Similar to how Facebook, LinkedIn, and YouTube handle shared content
class ShareService {
  /// Share tutor profile with rich preview
  /// 
  /// Shares the tutor profile URL which will automatically generate rich link previews
  /// (like Preply) using Open Graph meta tags from the web page.
  /// Platforms (WhatsApp, Facebook, etc.) will fetch og:image, og:title, and og:description
  static Future<void> shareTutorProfile({
    required Map<String, dynamic> tutorData,
    required String tutorId,
    String? tutorName,
    String? tutorAvatarUrl,
    List<String>? subjects,
  }) async {
    try {
      // Get tutor information
      final name = tutorName ?? 
                   tutorData['full_name'] ?? 
                   tutorData['profiles']?['full_name'] ?? 
                   'Tutor';
      
      final tutorSubjects = subjects ?? 
                           (tutorData['subjects'] is List 
                             ? List<String>.from(tutorData['subjects'] as List)
                             : (tutorData['subjects'] is String 
                                 ? [tutorData['subjects'] as String]
                                 : []));
      
      // Generate web URL (not deep link) - this will show rich previews
      final webUrl = _getWebUrl(tutorId);
      
      // Create share message with URL
      // The URL alone will trigger rich previews via Open Graph meta tags
      final subjectsText = tutorSubjects.isNotEmpty 
          ? tutorSubjects.join(', ')
          : 'Tutor';
      
      final shareMessage = 'Check out $name on PrepSkul!\n'
                          '$subjectsText tutor\n\n'
                          '$webUrl';
      
      // Share just the URL - platforms will automatically fetch Open Graph metadata
      // This creates rich link previews with tutor's profile picture, name, and bio
      await Share.share(
        shareMessage,
        subject: '$name - $subjectsText Tutor on PrepSkul',
      );
      LogService.success('Tutor profile shared with rich link preview');
    } catch (e) {
      LogService.error('Error sharing tutor profile: $e');
      rethrow;
    }
  }

  /// Generate web URL for tutor profile
  /// This URL will show rich link previews via Open Graph meta tags
  static String _getWebUrl(String tutorId) {
    // Use app.prepskul.com which has proper Open Graph meta tags
    // Platforms will automatically fetch og:image (tutor avatar), og:title (tutor name), 
    // and og:description (tutor bio) from the web page
    return 'https://app.prepskul.com/tutor/$tutorId';
  }
}

