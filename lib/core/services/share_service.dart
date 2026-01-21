import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';

/// Share Service
/// 
/// Handles rich sharing of tutor profiles with images and deep links
/// Similar to how Facebook, LinkedIn, and YouTube handle shared content
class ShareService {
  /// Share tutor profile with rich preview
  /// 
  /// Downloads tutor avatar, creates rich share with image attachment,
  /// and includes custom message with deep link
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
      
      final avatarUrl = tutorAvatarUrl ?? 
                       tutorData['avatar_url'] ?? 
                       tutorData['profiles']?['avatar_url'];
      
      final tutorSubjects = subjects ?? 
                           (tutorData['subjects'] is List 
                             ? List<String>.from(tutorData['subjects'] as List)
                             : (tutorData['subjects'] is String 
                                 ? [tutorData['subjects'] as String]
                                 : []));
      
      // Generate deep link
      final deepLink = _getDeepLink(tutorId);
      
      // Create share message
      final shareMessage = _createShareMessage(name, tutorSubjects, deepLink);
      
      // Try rich share with image (mobile only)
      if (!kIsWeb && avatarUrl != null && avatarUrl.isNotEmpty) {
        try {
          final imageFile = await _downloadTutorImage(avatarUrl);
          if (imageFile != null) {
            await Share.shareXFiles(
              [XFile(imageFile.path)],
              text: shareMessage,
              subject: '$name - ${tutorSubjects.isNotEmpty ? tutorSubjects.join(', ') : 'Tutor'} on PrepSkul',
            );
            LogService.success('Tutor profile shared with image');
            // Clean up temp file after a delay
            Future.delayed(const Duration(seconds: 5), () {
              try {
                imageFile.deleteSync();
              } catch (e) {
                LogService.debug('Error deleting temp image: $e');
              }
            });
            return;
          }
        } catch (e) {
          LogService.warning('Failed to share with image, falling back to text share: $e');
        }
      }
      
      // Fallback to native share with link preview
      await Share.share(
        shareMessage,
        subject: '$name - ${tutorSubjects.isNotEmpty ? tutorSubjects.join(', ') : 'Tutor'} on PrepSkul',
      );
      LogService.success('Tutor profile shared');
    } catch (e) {
      LogService.error('Error sharing tutor profile: $e');
      rethrow;
    }
  }

  /// Download tutor image to temporary file
  static Future<File?> _downloadTutorImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'tutor_share_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      LogService.warning('Error downloading tutor image: $e');
      return null;
    }
  }

  /// Create share message with tutor information
  static String _createShareMessage(
    String tutorName,
    List<String> subjects,
    String deepLink,
  ) {
    final subjectsText = subjects.isNotEmpty 
        ? subjects.join(', ')
        : 'Tutor';
    
    return 'Book $tutorName on PrepSkul!\n'
           '$subjectsText tutor\n'
           '$deepLink';
  }

  /// Generate deep link URL for tutor profile
  static String _getDeepLink(String tutorId) {
    // Use app.prepskul.com for production deep links
    // This will work for both web and mobile (mobile will redirect to app)
    return 'https://app.prepskul.com/tutor/$tutorId';
  }
}

