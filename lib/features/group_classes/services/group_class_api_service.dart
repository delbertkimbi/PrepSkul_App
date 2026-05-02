import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/group_classes/models/group_class_listing.dart';

class GroupClassApiService {
  GroupClassApiService._();

  static String get _apiBaseUrl {
    var base = AppConfig.effectiveApiBaseUrl;
    if (kIsWeb) {
      // Web local/dev often fails CORS when targeting app.prepskul.com.
      // Use www.prepskul.com where API routes/CORS are consistently configured.
      base = base.replaceAll('://app.prepskul.com', '://www.prepskul.com');
    }
    return base;
  }

  static Future<String> _getAccessToken() async {
    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return token;
  }

  static Map<String, dynamic> _tryDecodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Future<List<GroupClassListing>> getPublished({
    String? subject,
    String? classType,
    int limit = 20,
  }) async {
    try {
      final qs = <String, String>{
        'limit': '$limit',
        'starts_after': DateTime.now().toIso8601String(),
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
        if (classType != null && classType.trim().isNotEmpty) 'class_type': classType.trim(),
      };
      final uri = Uri.parse('$_apiBaseUrl/group-classes').replace(
        queryParameters: qs,
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load group classes (${response.statusCode})');
      }
      final body = _tryDecodeJsonMap(response.body);
      final rows = (body['listings'] as List?) ?? <dynamic>[];
      return rows
          .map((e) => GroupClassListing.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Web fetch/CORS can intermittently fail in dev; fall back to direct Supabase read.
      return _getPublishedDirect(
        subject: subject,
        classType: classType,
        limit: limit,
      );
    }
  }

  static Future<List<GroupClassListing>> _getPublishedDirect({
    String? subject,
    String? classType,
    int limit = 20,
  }) async {
    final trimmedSubject = (subject ?? '').trim();
    final trimmedClassType = (classType ?? '').trim();
    final startsAfter = DateTime.now().toIso8601String();

    final rows = trimmedSubject.isNotEmpty && trimmedClassType.isNotEmpty
        ? await SupabaseService.client
            .from('group_class_listings')
            .select(
              'id, tutor_id, title, description, flyer_image_url, subject, class_type, learning_focus, schedule_end_at, meeting_days, starts_at, duration_minutes, capacity, price_per_seat, currency_code, status, published_at, approval_status, profiles!group_class_listings_tutor_id_fkey(avatar_url)',
            )
            .eq('status', 'published')
            .gte('starts_at', startsAfter)
            .eq('subject', trimmedSubject)
            .eq('class_type', trimmedClassType)
            .order('starts_at')
            .limit(limit)
        : trimmedSubject.isNotEmpty
            ? await SupabaseService.client
                .from('group_class_listings')
                .select(
                  'id, tutor_id, title, description, flyer_image_url, subject, class_type, learning_focus, schedule_end_at, meeting_days, starts_at, duration_minutes, capacity, price_per_seat, currency_code, status, published_at, approval_status, profiles!group_class_listings_tutor_id_fkey(avatar_url)',
                )
                .eq('status', 'published')
                .gte('starts_at', startsAfter)
                .eq('subject', trimmedSubject)
                .order('starts_at')
                .limit(limit)
            : trimmedClassType.isNotEmpty
                ? await SupabaseService.client
                    .from('group_class_listings')
                    .select(
                      'id, tutor_id, title, description, flyer_image_url, subject, class_type, learning_focus, schedule_end_at, meeting_days, starts_at, duration_minutes, capacity, price_per_seat, currency_code, status, published_at, approval_status, profiles!group_class_listings_tutor_id_fkey(avatar_url)',
                    )
                    .eq('status', 'published')
                    .gte('starts_at', startsAfter)
                    .eq('class_type', trimmedClassType)
                    .order('starts_at')
                    .limit(limit)
                : await SupabaseService.client
                    .from('group_class_listings')
                    .select(
                      'id, tutor_id, title, description, flyer_image_url, subject, class_type, learning_focus, schedule_end_at, meeting_days, starts_at, duration_minutes, capacity, price_per_seat, currency_code, status, published_at, approval_status, profiles!group_class_listings_tutor_id_fkey(avatar_url)',
                    )
                    .eq('status', 'published')
                    .gte('starts_at', startsAfter)
                    .order('starts_at')
                    .limit(limit);

    return rows
        .map((e) => GroupClassListing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<GroupClassListing>> getMine({int limit = 50}) async {
    try {
      final token = await _getAccessToken();
      final uri = Uri.parse('$_apiBaseUrl/group-classes')
          .replace(queryParameters: <String, String>{'mine': 'true', 'limit': '$limit'});
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode != 200) {
        throw Exception('Failed to load your group classes (${response.statusCode})');
      }
      final body = _tryDecodeJsonMap(response.body);
      final rows = (body['listings'] as List?) ?? <dynamic>[];
      return rows
          .map((e) => GroupClassListing.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _getMineDirect(limit: limit);
    }
  }

  static Future<List<GroupClassListing>> _getMineDirect({int limit = 50}) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not authenticated');
    }
    final rows = await SupabaseService.client
        .from('group_class_listings')
        .select(
          'id, tutor_id, title, description, flyer_image_url, subject, class_type, learning_focus, schedule_end_at, meeting_days, starts_at, duration_minutes, capacity, price_per_seat, currency_code, status, published_at, approval_status, profiles!group_class_listings_tutor_id_fkey(avatar_url)',
        )
        .eq('tutor_id', userId)
        .order('starts_at')
        .limit(limit);
    return rows
        .map((e) => GroupClassListing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<GroupClassListing> create({
    required String title,
    required String description,
    required DateTime startsAt,
    required int durationMinutes,
    required int capacity,
    required double pricePerSeat,
    String? subject,
    String classType = 'one_time',
    String? learningFocus,
    DateTime? scheduleEndAt,
    List<String>? meetingDays,
    String? flyerImageUrl,
  }) async {
    try {
      final token = await _getAccessToken();
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/group-classes'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, dynamic>{
          'title': title,
          'description': description,
          'startsAt': startsAt.toIso8601String(),
          'durationMinutes': durationMinutes,
          'capacity': capacity,
          'pricePerSeat': pricePerSeat,
          'subject': subject,
          'classType': classType,
          'learningFocus': learningFocus,
          'scheduleEndAt': scheduleEndAt?.toIso8601String(),
          'meetingDays': meetingDays,
          'flyerImageUrl': flyerImageUrl,
        }),
      );
      if (response.statusCode == 201) {
        final body = _tryDecodeJsonMap(response.body);
        return GroupClassListing.fromJson(body['listing'] as Map<String, dynamic>);
      }

      // If API is unreachable/misconfigured (common on web CORS/edge mismatch),
      // fall back to direct Supabase insert so tutors can still create classes.
      final err = _tryDecodeJsonMap(response.body);
      final errorMessage =
          err['error']?.toString() ?? 'Failed to create listing (${response.statusCode})';
      throw Exception(errorMessage);
    } catch (e) {
      return _createDirect(
        title: title,
        description: description,
        startsAt: startsAt,
        durationMinutes: durationMinutes,
        capacity: capacity,
        pricePerSeat: pricePerSeat,
        subject: subject,
        classType: classType,
        learningFocus: learningFocus,
        scheduleEndAt: scheduleEndAt,
        meetingDays: meetingDays,
        flyerImageUrl: flyerImageUrl,
        fallbackReason: e.toString(),
      );
    }
  }

  static Future<GroupClassListing> _createDirect({
    required String title,
    required String description,
    required DateTime startsAt,
    required int durationMinutes,
    required int capacity,
    required double pricePerSeat,
    String? subject,
    String classType = 'one_time',
    String? learningFocus,
    DateTime? scheduleEndAt,
    List<String>? meetingDays,
    String? flyerImageUrl,
    String? fallbackReason,
  }) async {
    final currentUserId = SupabaseService.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('User not authenticated');
    }

    LogService.warning(
      'Group class create API fallback -> direct Supabase insert. Reason: $fallbackReason',
    );

    final insertData = <String, dynamic>{
      'tutor_id': currentUserId,
      'title': title,
      'description': description,
      'flyer_image_url': flyerImageUrl,
      'subject': subject,
      'starts_at': startsAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'capacity': capacity,
      'price_per_seat': pricePerSeat,
      'currency_code': 'XAF',
      'status': 'draft',
      // Optional columns (present in newer migrations); safe to provide.
      'class_type': classType,
      'learning_focus': learningFocus,
      'schedule_end_at': scheduleEndAt?.toIso8601String(),
      'meeting_days': meetingDays,
    };

    final inserted = await SupabaseService.client
        .from('group_class_listings')
        .insert(insertData)
        .select(
          'id, tutor_id, title, description, flyer_image_url, subject, class_type, learning_focus, schedule_end_at, meeting_days, starts_at, duration_minutes, capacity, price_per_seat, currency_code, status, published_at, approval_status, profiles!group_class_listings_tutor_id_fkey(avatar_url)',
        )
        .single();
    return GroupClassListing.fromJson(inserted);
  }

  static Future<GroupClassListing> publish(String listingId) async {
    final token = await _getAccessToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/group-classes/$listingId/publish'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      final err = _tryDecodeJsonMap(response.body);
      throw Exception(err['error'] ?? 'Failed to publish listing');
    }
    final body = _tryDecodeJsonMap(response.body);
    return GroupClassListing.fromJson(body['listing'] as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> enroll(String listingId) async {
    final token = await _getAccessToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/group-classes/$listingId/enroll'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      final err = _tryDecodeJsonMap(response.body);
      throw Exception(err['error'] ?? 'Failed to enroll');
    }
    return _tryDecodeJsonMap(response.body);
  }

  static Future<Map<String, dynamic>> resolveJoinToken(String token) async {
    final accessToken = await _getAccessToken();
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/group-classes/join/$token'),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      },
    );

    final body = _tryDecodeJsonMap(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['error'] ?? body['reason'] ?? 'Class link validation failed');
    }
    return body;
  }
}

