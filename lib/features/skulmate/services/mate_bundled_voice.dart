import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// One consistent generated speaker for common prompts, available offline.
class MateBundledVoice {
  AudioPlayer? _player;
  Map<String, dynamic>? _clips;
  int _generation = 0;
  Completer<void>? _done;

  Future<bool> speak(String text, void Function(bool) onSpeaking) async {
    final generation = ++_generation;
    StreamSubscription<void>? subscription;
    try {
      _clips ??=
          jsonDecode(
                await rootBundle.loadString('assets/audio/mate/manifest.json'),
              )
              as Map<String, dynamic>;
      final clip = _clips![text];
      if (generation != _generation) return true;
      if (clip is! String) return false;
      _player ??= AudioPlayer();
      final done = Completer<void>();
      _done = done;
      subscription = _player!.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      });
      onSpeaking(true);
      await _player!.play(AssetSource(clip));
      await done.future.timeout(const Duration(seconds: 40));
      return true;
    } catch (_) {
      return generation != _generation;
    } finally {
      await subscription?.cancel();
      if (generation == _generation) onSpeaking(false);
    }
  }

  Future<void> stop() async {
    _generation++;
    if (_done != null && !_done!.isCompleted) _done!.complete();
    _done = null;
    await _player?.stop();
  }
}
