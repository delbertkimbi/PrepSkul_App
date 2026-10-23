import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// The same server-selected voice as Mate's recorded onboarding prompts.
class MateCloudVoice {
  AudioPlayer? _player;
  http.Client? _request;
  Completer<void>? _done;
  int _generation = 0;

  Future<bool> speak(
    String text,
    String language,
    void Function(bool) onSpeaking,
  ) async {
    final generation = ++_generation;
    StreamSubscription<void>? subscription;
    final client = http.Client();
    _request = client;
    try {
      final token = SupabaseService.client.auth.currentSession?.accessToken;
      if (token == null) return false;
      final response = await client
          .post(
            Uri.parse('${AppConfig.skulMateHttpApiBase}/skulmate/speech'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'text': text, 'language': language}),
          )
          .timeout(const Duration(seconds: 23));
      if (generation != _generation) return true;
      if (response.statusCode != 200 || response.bodyBytes.isEmpty)
        return false;
      _player ??= AudioPlayer();
      final done = Completer<void>();
      _done = done;
      subscription = _player!.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      });
      await _player!.play(
        BytesSource(
          response.bodyBytes,
          mimeType: response.headers['content-type'],
        ),
      );
      if (generation != _generation) {
        await _player!.stop();
        return true;
      }
      onSpeaking(true);
      await done.future.timeout(const Duration(minutes: 3));
      return true;
    } catch (_) {
      if (generation == _generation) await _player?.stop();
      return generation != _generation;
    } finally {
      client.close();
      await subscription?.cancel();
      if (generation == _generation) {
        _request = null;
        _done = null;
        onSpeaking(false);
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    _request?.close();
    _request = null;
    if (_done != null && !_done!.isCompleted) _done!.complete();
    _done = null;
    await _player?.stop();
  }
}
