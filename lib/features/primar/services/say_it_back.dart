import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speaking practice — "say it back".
///
/// ## The rule this whole file is built around
///
/// **Speech can earn a reward. It can never cost one.**
///
/// The best speech models still run 30–45% word error rate on African-accented
/// English, and children are harder again: higher pitch, unstable
/// pronunciation, disfluency. If a misheard word marked a child wrong, the
/// product would spend a third of its time telling correct children they had
/// failed — which is the exact experience it exists to undo.
///
/// So recognition is used one-directionally. A match is celebrated. A non-match
/// is not a wrong answer, it is simply an un-awarded bonus, and the child hears
/// warmth either way. Nothing in the session is gated on speaking: a child can
/// finish every level having never said a word, and a mute child, a shy child,
/// or a child in a noisy room is never blocked.
///
/// Matching is deliberately generous for the same reason — near-misses count.
/// The cost of being too lenient is a celebration a child did not quite earn.
/// The cost of being too strict is teaching them their voice is wrong.
///
/// Runs on the device's own recogniser, so audio never leaves the phone and the
/// feature survives an internet shutdown.
class SayItBack {
  SayItBack._();

  static final SayItBack instance = SayItBack._();

  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  bool _initialised = false;

  /// True only once the platform has confirmed a recogniser and permission.
  /// When false, every speaking prompt is simply skipped.
  bool get available => _available;

  Future<bool> init() async {
    if (_initialised) return _available;
    _initialised = true;
    try {
      _available = await _speech.initialize(
        onError: (e) => debugPrint('[SayItBack] ${e.errorMsg}'),
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('[SayItBack] unavailable, speaking practice will be skipped: $e');
      _available = false;
    }
    return _available;
  }

  /// Listens for [target] and reports what was heard.
  ///
  /// Outcomes:
  /// - [SpeechResult.matched] — celebrate (never grades the session).
  /// - [SpeechResult.heardOther] — something was recognised that is not the
  ///   target; the caller may name heard→correct, still without marking wrong.
  /// - [SpeechResult.notHeard] — silence, noise, timeout, or no recogniser.
  ///
  /// Nothing here ever costs a reward. Mismatch is coaching, not assessment.
  Future<SpeechResult> listenFor(
    String target, {
    Duration limit = const Duration(seconds: 5),
    String locale = 'en',
  }) async {
    if (!await init()) return SpeechResult.notHeard;

    final completer = Completer<SpeechResult>();
    var settled = false;
    String? lastHeard;

    void settle(SpeechResult r) {
      if (settled) return;
      settled = true;
      if (!completer.isCompleted) completer.complete(r);
    }

    try {
      await _speech.listen(
        onResult: (result) {
          final heard = result.recognizedWords;
          if (heard.trim().isEmpty) return;
          lastHeard = heard;
          if (matches(heard, target)) {
            settle(SpeechResult.matched(heard));
          }
          // A non-match is not settled early: the child may still be mid-word,
          // and cutting them off to say "no" is the behaviour this avoids.
        },
        listenOptions: SpeechListenOptions(
          localeId: locale == 'fr' ? 'fr_FR' : 'en_US',
          listenFor: limit,
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );

      // Whatever happens, stop listening and resolve. If we heard something
      // that never matched, surface it so the tutor can name heard→correct.
      Timer(limit + const Duration(milliseconds: 600), () async {
        await stop();
        final heard = lastHeard?.trim();
        if (heard != null && heard.isNotEmpty) {
          settle(SpeechResult.heardOther(heard));
        } else {
          settle(SpeechResult.notHeard);
        }
      });
    } catch (e) {
      debugPrint('[SayItBack] listen failed: $e');
      settle(SpeechResult.notHeard);
    }

    return completer.future;
  }

  Future<void> stop() async {
    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {}
  }

  /// Generous matching, on purpose.
  ///
  /// A recogniser hearing a Cameroonian six-year-old will mangle plenty. Any
  /// spoken word containing the target, or close enough by edit distance, is
  /// accepted — because the cost of over-accepting is an unearned "well done",
  /// and the cost of under-accepting is a child learning their voice is wrong.
  static bool matches(String heard, String target) {
    final h = _normalise(heard);
    final t = _normalise(target);
    if (h.isEmpty || t.isEmpty) return false;

    for (final word in h.split(' ')) {
      if (word == t) return true;
      if (t.length >= 3 && word.contains(t)) return true;
      // Single letters are the hardest case. Accept the letter itself, its
      // spoken name, or a first-letter match.
      if (t.length == 1) {
        if (word == t) return true;
        if (word.isNotEmpty && word[0] == t) return true;
        if (_letterNames[t]?.contains(word) ?? false) return true;
      }
      if (t.length >= 3 && _within(word, t, 1)) return true;
    }

    // Multi-word letter names such as "double u" survive the word split only
    // if the whole utterance is checked too.
    if (t.length == 1 && (_letterNames[t]?.contains(h) ?? false)) return true;

    return false;
  }

  /// How a recogniser actually writes down a spoken letter.
  ///
  /// A first-letter rule is not enough: several English letter names do not
  /// begin with their own letter — m is "em", n is "en", f is "ef", s is
  /// "ess", r is "ar". Without this table a child who said "m" perfectly is
  /// told they were not heard.
  static const Map<String, List<String>> _letterNames = {
    'a': ['ay', 'eh', 'aye'],
    'b': ['bee', 'be'],
    'c': ['see', 'sea', 'cee'],
    'd': ['dee', 'de'],
    'e': ['ee', 'eee'],
    'f': ['ef', 'eff'],
    'g': ['gee', 'jee'],
    'h': ['aitch', 'haitch', 'hetch'],
    'i': ['eye', 'aye', 'ai'],
    'j': ['jay', 'jai'],
    'k': ['kay', 'ka'],
    'l': ['el', 'ell'],
    'm': ['em', 'emm'],
    'n': ['en', 'enn'],
    'o': ['oh', 'owe', 'o'],
    'p': ['pee', 'pe'],
    'q': ['cue', 'queue', 'kyu'],
    'r': ['ar', 'are', 'arr'],
    's': ['es', 'ess'],
    't': ['tee', 'tea'],
    'u': ['you', 'yoo', 'ew'],
    'v': ['vee', 've'],
    'w': ['double u', 'doubleyou', 'dubya'],
    'x': ['ex', 'eks'],
    'y': ['why', 'wye'],
    'z': ['zed', 'zee'],
  };

  static String _normalise(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9àâçéèêëîïôûùüÿœæ ]'), '')
      .trim();

  /// True when [a] and [b] differ by at most [max] edits.
  static bool _within(String a, String b, int max) {
    if ((a.length - b.length).abs() > max) return false;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final row = <int>[i];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        row.add([
          prev[j] + 1,
          row[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y));
      }
      prev = row;
      if (prev.reduce((x, y) => x < y ? x : y) > max) return false;
    }
    return prev[b.length] <= max;
  }
}

/// Outcome of one speak-back listen. Never a session score.
class SpeechResult {
  const SpeechResult._({
    required this.matched,
    this.heard,
  });

  /// Close enough to the target. Celebrate.
  factory SpeechResult.matched(String heard) => SpeechResult._(
        matched: true,
        heard: heard.trim(),
      );

  /// Recogniser returned words that are not the target. Coaching only.
  factory SpeechResult.heardOther(String heard) => SpeechResult._(
        matched: false,
        heard: heard.trim(),
      );

  /// Silence, noise, timeout, or no recogniser — shrug and move on.
  static const notHeard = SpeechResult._(matched: false);

  final bool matched;

  /// Raw recogniser text when anything was captured.
  final String? heard;

  bool get hasHeard => heard != null && heard!.trim().isNotEmpty;
}
