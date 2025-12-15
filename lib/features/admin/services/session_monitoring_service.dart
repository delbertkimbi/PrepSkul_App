import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_service.dart';

/// Session Monitoring Service
///
/// ⚠️ DEPRECATED: This service has been moved to Next.js admin dashboard
///
/// This file is kept for reference only. All admin services should be in:
/// - Next.js: /PrepSkul_Web/lib/services/session-monitoring.ts
/// - Admin Dashboard: /PrepSkul_Web/app/admin/sessions/flags/
///
/// The analysis now runs automatically via Fathom webhook handler.
/// Flag review is done in the Next.js admin dashboard.
///
/// Documentation: docs/ADMIN_SERVICES_ARCHITECTURE.md

@Deprecated(
  'Moved to Next.js admin dashboard. See docs/ADMIN_SERVICES_ARCHITECTURE.md',
)
class SessionMonitoringService {
  static final _supabase = SupabaseService.client;

  /// Analyze session for admin flags
  ///
  /// Scans transcript and summary for irregular behavior patterns
  ///
  /// Parameters:
  /// - [sessionId]: Session ID
  /// - [sessionType]: 'trial' or 'recurring'
  /// - [transcript]: Full transcript text
  /// - [summary]: Session summary text
  ///
  /// Returns: List of detected flags
  static Future<List<Map<String, dynamic>>> analyzeSessionForFlags({
    required String sessionId,
    required String sessionType,
    required String transcript,
    required String summary,
  }) async {
    try {
      final flags = <Map<String, dynamic>>[];

      // Check for payment bypass attempts
      if (_detectsPaymentBypass(transcript, summary)) {
        flags.add(
          _createFlag(
            sessionId: sessionId,
            sessionType: sessionType,
            flagType: 'payment_bypass_attempt',
            severity: 'critical',
            description:
                'Possible attempt to bypass payment system or discuss off-platform payments',
            transcriptExcerpt: _extractRelevantExcerpt(transcript, [
              'pay',
              'money',
              'cash',
              'direct',
              'outside',
              'bypass',
            ]),
          ),
        );
      }

      // Check for inappropriate language
      if (_detectsInappropriateLanguage(transcript)) {
        flags.add(
          _createFlag(
            sessionId: sessionId,
            sessionType: sessionType,
            flagType: 'inappropriate_language',
            severity: 'high',
            description: 'Inappropriate or unprofessional language detected',
            transcriptExcerpt: _extractRelevantExcerpt(transcript, [
              'curse',
              'profanity',
              'inappropriate',
            ]),
          ),
        );
      }

      // Check for contact information sharing
      if (_detectsContactSharing(transcript)) {
        flags.add(
          _createFlag(
            sessionId: sessionId,
            sessionType: sessionType,
            flagType: 'contact_information_shared',
            severity: 'medium',
            description:
                'Phone numbers, email, or social media shared outside platform',
            transcriptExcerpt: _extractRelevantExcerpt(transcript, [
              'phone',
              'email',
              'whatsapp',
              'instagram',
              'facebook',
              'contact',
            ]),
          ),
        );
      }

      // Check for session quality issues
      if (_detectsQualityIssues(transcript, summary)) {
        flags.add(
          _createFlag(
            sessionId: sessionId,
            sessionType: sessionType,
            flagType: 'session_quality_issue',
            severity: 'low',
            description:
                'Session quality concerns detected (short duration, lack of engagement)',
            transcriptExcerpt: _extractRelevantExcerpt(transcript, []),
          ),
        );
      }

      // Store flags in database
      if (flags.isNotEmpty) {
        for (final flag in flags) {
          await _supabase.from('admin_flags').insert(flag);
        }

        // Notify admins if critical flags
        final criticalFlags = flags
            .where((f) => f['severity'] == 'critical')
            .toList();
        if (criticalFlags.isNotEmpty) {
          await _notifyAdmins(sessionId, criticalFlags);
        }

        LogService.success('Created ${flags.length} admin flags for session: $sessionId');
      }

      return flags;
    } catch (e) {
      LogService.error('Error analyzing session for flags: $e');
      return [];
    }
  }

  /// Detect payment bypass attempts
  static bool _detectsPaymentBypass(String transcript, String summary) {
    final lowerTranscript = transcript.toLowerCase();
    final lowerSummary = summary.toLowerCase();

    final bypassKeywords = [
      'pay outside',
      'pay directly',
      'bypass payment',
      'skip payment',
      'pay cash',
      'pay offline',
      'pay later',
      'no need to pay',
      'free session',
      'direct payment',
    ];

    return bypassKeywords.any(
      (keyword) =>
          lowerTranscript.contains(keyword) || lowerSummary.contains(keyword),
    );
  }

  /// Detect inappropriate language
  static bool _detectsInappropriateLanguage(String transcript) {
    // Basic profanity detection (expand as needed)
    // This is a placeholder - implement proper detection
    // For now, return false - implement proper detection
    return false;
  }

  /// Detect contact information sharing
  static bool _detectsContactSharing(String transcript) {
    final lowerTranscript = transcript.toLowerCase();

    // Check for phone number patterns
    final phonePattern = RegExp(r'\b\d{8,15}\b');
    if (phonePattern.hasMatch(transcript)) {
      return true;
    }

    // Check for email patterns
    final emailPattern = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    );
    if (emailPattern.hasMatch(transcript)) {
      // Exclude PrepSkul emails
      if (!lowerTranscript.contains('@prepskul.com')) {
        return true;
      }
    }

    // Check for social media mentions
    final socialKeywords = [
      'whatsapp',
      'instagram',
      'facebook',
      'telegram',
      'snapchat',
    ];

    return socialKeywords.any((keyword) => lowerTranscript.contains(keyword));
  }

  /// Detect session quality issues
  static bool _detectsQualityIssues(String transcript, String summary) {
    // Check for very short sessions (less than 10 minutes of content)
    final wordCount = transcript.split(' ').length;
    if (wordCount < 100) {
      return true; // Very short session
    }

    // Check for lack of engagement indicators
    final lowerTranscript = transcript.toLowerCase();
    final engagementKeywords = [
      'question',
      'answer',
      'explain',
      'understand',
      'practice',
    ];

    final engagementCount = engagementKeywords
        .where((keyword) => lowerTranscript.contains(keyword))
        .length;

    // If very few engagement indicators, flag as quality issue
    return engagementCount < 3;
  }

  /// Create admin flag object
  static Map<String, dynamic> _createFlag({
    required String sessionId,
    required String sessionType,
    required String flagType,
    required String severity,
    required String description,
    String? transcriptExcerpt,
  }) {
    return {
      'session_id': sessionId,
      'session_type': sessionType,
      'flag_type': flagType,
      'severity': severity,
      'description': description,
      'transcript_excerpt': transcriptExcerpt,
      'resolved': false,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Extract relevant excerpt from transcript
  static String? _extractRelevantExcerpt(
    String transcript,
    List<String> keywords,
  ) {
    if (keywords.isEmpty) {
      // Return first 200 characters
      return transcript.length > 200
          ? '${transcript.substring(0, 200)}...'
          : transcript;
    }

    // Find first occurrence of any keyword
    final lowerTranscript = transcript.toLowerCase();
    for (final keyword in keywords) {
      final index = lowerTranscript.indexOf(keyword.toLowerCase());
      if (index != -1) {
        final start = (index - 50).clamp(0, transcript.length);
        final end = (index + 200).clamp(0, transcript.length);
        return transcript.substring(start, end);
      }
    }

    return null;
  }

  /// Notify admins about critical flags
  static Future<void> _notifyAdmins(
    String sessionId,
    List<Map<String, dynamic>> flags,
  ) async {
    try {
      // Get all admin users
      final admins = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_admin', true);

      for (final admin in admins as List) {
        await NotificationService.createNotification(
          userId: admin['id'] as String,
          type: 'critical_session_flag',
          title: 'Critical Flag Detected',
          message:
              '${flags.length} critical flag(s) detected in session $sessionId',
          data: {
            'session_id': sessionId,
            'flag_count': flags.length,
            'flags': flags,
          },
        );
      }

      LogService.success('Notified admins about critical flags');
    } catch (e) {
      LogService.error('Error notifying admins: $e');
    }
  }

  /// Get all flags for admin review
  ///
  /// Retrieves all admin flags, optionally filtered
  ///
  /// Parameters:
  /// - [severity]: Optional filter by severity
  /// - [resolved]: Optional filter by resolved status
  static Future<List<Map<String, dynamic>>> getAdminFlags({
    String? severity,
    bool? resolved,
  }) async {
    try {
      var query = _supabase.from('admin_flags').select();

      if (severity != null) {
        query = query.eq('severity', severity);
      }

      if (resolved != null) {
        query = query.eq('resolved', resolved);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error getting admin flags: $e');
      return [];
    }
  }

  /// Resolve an admin flag
  ///
  /// Marks a flag as resolved with optional notes
  ///
  /// Parameters:
  /// - [flagId]: Flag ID
  /// - [resolutionNotes]: Optional resolution notes
  static Future<void> resolveFlag({
    required String flagId,
    String? resolutionNotes,
  }) async {
    try {
      await _supabase
          .from('admin_flags')
          .update({
            'resolved': true,
            'resolved_at': DateTime.now().toIso8601String(),
            'resolution_notes': resolutionNotes,
          })
          .eq('id', flagId);

      LogService.success('Flag resolved: $flagId');
    } catch (e) {
      LogService.error('Error resolving flag: $e');
      rethrow;
    }
  }
}
