import 'dart:convert';

import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'http_client_stub.dart' if (dart.library.html) 'http_client_web.dart';
import 'lecture_audio_bytes.dart';

/// Result of lecture audio transcription.
class LectureTranscriptionResult {
  final String transcriptId;
  final String text;

  const LectureTranscriptionResult({
    required this.transcriptId,
    required this.text,
  });
}

/// Uploads lecture audio, transcribes via backend, deletes temp audio.
class SkulMateLectureTranscriptionService {
  SkulMateLectureTranscriptionService._();

  static const _documentsBucket = 'documents';
  static const _endpoint = '/skulmate/transcribe-lecture';

  static Future<LectureTranscriptionResult> transcribeLocalFile({
    required String localPath,
    String? childId,
    String? title,
    int? durationSeconds,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Please log in to continue.');
    }

    final bytes = await readRecordingBytes(localPath);
    if (bytes.isEmpty) {
      throw Exception('Recording file is empty');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$userId/lecture_audio_$timestamp.m4a';

    try {
      await SupabaseService.client.storage.from(_documentsBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'audio/mp4',
              upsert: true,
            ),
          );

      final audioUrl = await SupabaseService.client.storage
          .from(_documentsBucket)
          .createSignedUrl(storagePath, 3600);

      return await _callTranscribeApi(
        audioUrl: audioUrl,
        userId: userId,
        childId: childId,
        title: title,
        durationSeconds: durationSeconds,
      );
    } finally {
      try {
        await SupabaseService.client.storage
            .from(_documentsBucket)
            .remove([storagePath]);
      } catch (e) {
        LogService.debug('Lecture audio cleanup failed: $e');
      }
    }
  }

  static Future<LectureTranscriptionResult> _callTranscribeApi({
    required String audioUrl,
    required String userId,
    String? childId,
    String? title,
    int? durationSeconds,
  }) async {
    final url = '${AppConfig.skulMateHttpApiBase}$_endpoint';
    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;

    final body = jsonEncode({
      'audioUrl': audioUrl,
      'userId': userId,
      if (childId != null) 'childId': childId,
      if (title != null && title.isNotEmpty) 'title': title,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    });

    final response = await postWeb(
      url,
      {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body,
    );

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode == 422) {
      final code = decoded?['errorCode']?.toString();
      final msg = _mapTranscribeErrorCode(code) ??
          decoded?['error']?.toString() ??
          'Not enough speech detected. Record a bit longer.';
      throw Exception(msg);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decoded?['errorCode']?.toString();
      final msg = _mapTranscribeErrorCode(code) ??
          decoded?['error']?.toString() ??
          'Transcription failed';
      throw Exception(msg);
    }

    final text = decoded?['text']?.toString().trim() ?? '';
    final transcriptId = decoded?['transcriptId']?.toString() ?? '';
    if (text.isEmpty || transcriptId.isEmpty) {
      throw Exception('Transcription returned empty text');
    }

    return LectureTranscriptionResult(transcriptId: transcriptId, text: text);
  }

  static String? _mapTranscribeErrorCode(String? code) {
    if (code == null || code.isEmpty) return null;
    switch (code) {
      case 'AUDIO_TOO_SHORT':
      case 'TRANSCRIPT_TOO_SHORT':
        return 'Recording is too short or not enough speech was detected.\n\n'
            'Record at least 15 seconds of clear speech, closer to the mic.';
      case 'AUDIO_UNREACHABLE':
        return 'Could not access the recording for transcription.\n\n'
            'Please try recording again.';
      case 'DEEPGRAM_AUTH':
        return 'Transcription is temporarily unavailable.\n\n'
            'Please try again later or paste your notes manually.';
      case 'TRANSCRIPTION_FAILED':
        return 'Transcription failed. Please try again.';
      default:
        return null;
    }
  }
}
