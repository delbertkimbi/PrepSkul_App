import 'dart:convert';
import 'dart:io' show File;

import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/skulmate/models/skulmate_intake_models.dart';
import 'package:prepskul/features/skulmate/models/tutor_session_models.dart';
import 'package:prepskul/features/skulmate/services/learner_intelligence_service.dart';
import 'package:prepskul/features/skulmate/services/skulmate_service.dart';
import 'package:prepskul/features/skulmate/services/skulmate_session_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to the SkulMate tutor session API.
class SkulMateTutorSessionService {
  SkulMateTutorSessionService._();

  static String get _base => AppConfig.skulMateHttpApiBase;

  static Future<String?> _token() async {
    return SupabaseService.client.auth.currentSession?.accessToken;
  }

  static Future<String?> _userId() async {
    return SupabaseService.client.auth.currentUser?.id;
  }

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> openSession({
    String? childId,
    bool forceNew = false,
  }) async {
    final token = await _token();
    final userId = await _userId();
    final response = await SkulMateService.postJson(
      url: '$_base/skulmate/session',
      token: token ?? '',
      body: {
        if (userId != null) 'userId': userId,
        if (childId != null) 'childId': childId,
        if (forceNew) 'forceNew': true,
      },
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(json['error'] ?? 'Could not open tutor session');
    }
    return json;
  }

  static Future<Map<String, dynamic>> loadSession(String sessionId) async {
    final token = await _token();
    final userId = await _userId();
    final uri = Uri.parse('$_base/skulmate/session').replace(
      queryParameters: {
        'sessionId': sessionId,
        if (userId != null) 'userId': userId,
      },
    );
    final response = await http.get(uri, headers: _headers(token));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(json['error'] ?? 'Could not load tutor session');
    }
    return json;
  }

  static Future<List<TutorSessionSummary>> listSessions({
    String? childId,
  }) async {
    final token = await _token();
    final userId = await _userId();
    final uri = Uri.parse('$_base/skulmate/session').replace(
      queryParameters: {
        if (childId != null) 'childId': childId,
        if (userId != null) 'userId': userId,
      },
    );
    final response = await http.get(uri, headers: _headers(token));
    if (response.statusCode != 200) return [];
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = json['sessions'] as List<dynamic>? ?? [];
    return rows
        .whereType<Map>()
        .map((e) => TutorSessionSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<TutorTurnResult> sendTurn({
    required String sessionId,
    required String message,
    String? childId,
    String? notes,
    bool demo = false,
  }) async {
    final token = await _token();
    final userId = await _userId();
    final learnerContext = await LearnerIntelligenceService.build(
      childId: childId,
    );
    final useDemo = demo || sessionId == 'demo';
    final trimmedNotes = notes?.trim();
    final response = await SkulMateService.postJson(
      url: '$_base/skulmate/session/turn',
      token: token ?? '',
      body: {
        if (useDemo) 'demo': true,
        if (!useDemo) 'sessionId': sessionId,
        'message': message,
        if (userId != null) 'userId': userId,
        if (childId != null) 'childId': childId,
        if (trimmedNotes != null && trimmedNotes.isNotEmpty) 'notes': trimmedNotes,
        'language': LanguageService.languageCode,
        if (learnerContext != null) 'learnerContext': learnerContext,
      },
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(json['error'] ?? 'Tutor turn failed');
    }
    final result = TutorTurnResult.fromJson(json);
    if (!useDemo) {
      await SkulMateSessionCache.appendTurn(
        sessionId: sessionId,
        turn: TutorTurn(
          id: result.turnId,
          isUser: false,
          text: result.message,
          surface: result.surface,
          speak: result.speak,
          escalate: result.escalate,
          move: result.move,
          board: result.board,
        ),
      );
    }
    return result;
  }

  static Future<TutorTurnResult?> ingestPayload({
    required String sessionId,
    required SkulMateIntakePayload payload,
  }) async {
    final token = await _token();
    final userId = await _userId();
    final learnerContext = await LearnerIntelligenceService.build(
      childId: payload.childId,
    );

    final fileUrls = <String>[
      ...?payload.preUploadedFileUrls,
    ];
    await _uploadFiles(payload, fileUrls);

    final textParts = <String>[
      if (payload.text != null && payload.text!.trim().isNotEmpty)
        payload.text!.trim(),
      if (payload.topicHint != null && payload.topicHint!.trim().isNotEmpty)
        payload.topicHint!.trim(),
    ];

    final response = await SkulMateService.postJson(
      url: '$_base/skulmate/ingest',
      token: token ?? '',
      body: {
        'sessionId': sessionId,
        if (userId != null) 'userId': userId,
        if (payload.childId != null) 'childId': payload.childId,
        'sourceType': _sourceType(payload),
        if (textParts.isNotEmpty) 'text': textParts.join('\n'),
        if (payload.youtubeUrl != null) 'youtubeUrl': payload.youtubeUrl,
        if (fileUrls.isNotEmpty) 'fileUrls': fileUrls,
        'title': payload.title ?? payload.topicHint,
        'language': LanguageService.languageCode,
        if (learnerContext != null) 'learnerContext': learnerContext,
      },
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300) {
      throw Exception(json['error'] ?? 'Could not read that material');
    }
    final turnJson = json['turn'];
    if (turnJson is Map) {
      return TutorTurnResult.fromJson(Map<String, dynamic>.from(turnJson));
    }
    return null;
  }

  static Future<void> recordOutcome({
    required String sessionId,
    required bool correct,
    String? childId,
    String? turnId,
    String? conceptId,
    String? surfaceType,
    bool hintUsed = false,
  }) async {
    final token = await _token();
    final userId = await _userId();
    await SkulMateService.postJson(
      url: '$_base/skulmate/outcome',
      token: token ?? '',
      body: {
        'sessionId': sessionId,
        'correct': correct,
        if (userId != null) 'userId': userId,
        if (childId != null) 'childId': childId,
        if (turnId != null) 'turnId': turnId,
        if (conceptId != null) 'conceptId': conceptId,
        if (surfaceType != null) 'surfaceType': surfaceType,
        'hintUsed': hintUsed,
      },
    );
  }

  static String _sourceType(SkulMateIntakePayload payload) {
    switch (payload.source) {
      case SkulMateIntakeSource.photo:
        return 'image';
      case SkulMateIntakeSource.document:
        return 'pdf';
      case SkulMateIntakeSource.youtube:
        return 'youtube';
      case SkulMateIntakeSource.lecture:
        return 'lecture';
      case SkulMateIntakeSource.fromClass:
        return 'from_class';
      case SkulMateIntakeSource.typedTopic:
        return 'topic';
      case SkulMateIntakeSource.paste:
        return 'text';
    }
  }

  static Future<void> _uploadFiles(
    SkulMateIntakePayload payload,
    List<String> fileUrls,
  ) async {
    final userId = await _userId();
    if (userId == null) return;
    final bucket = SupabaseService.client.storage.from('documents');

    Future<void> put(List<int> bytes, String name, String contentType) async {
      final path =
          '$userId/skulmate_${DateTime.now().millisecondsSinceEpoch}_$name';
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      fileUrls.add(await bucket.createSignedUrl(path, 3600));
    }

    final files = payload.files ?? const <File>[];
    for (final file in files) {
      await put(
        await file.readAsBytes(),
        file.uri.pathSegments.isEmpty ? 'notes.bin' : file.uri.pathSegments.last,
        'application/octet-stream',
      );
    }
    for (final image in payload.images ?? const []) {
      await put(await image.readAsBytes(), image.name, 'image/jpeg');
    }
  }
}
