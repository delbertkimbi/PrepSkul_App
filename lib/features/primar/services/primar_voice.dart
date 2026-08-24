import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/parent_phrases.dart';
import 'package:prepskul/features/primar/domain/teaching_voice.dart';
import 'package:prepskul/features/primar/domain/tutor_feedback.dart';
import 'package:prepskul/features/primar/services/parent_voice_store.dart';
import 'package:prepskul/features/primar/services/tutor_brain.dart';

/// The app's voice. Everything a child hears comes from here.
///
/// Listening lives in [SayItBack], deliberately kept in a separate file with a
/// separate rule: **speech can earn a reward, it can never cost one.** The best
/// speech models still run 30–45% word error rate on African-accented English
/// and worse on children, so a misheard child must never be marked down. This
/// class does not record anything.
///
/// ## Lines queue, they do not interrupt
///
/// The first version called stop() at the head of every say(), so each new line
/// killed the one still speaking: "How many altogether?" was cut off the moment
/// a child tapped, and the teaching line after it was cut off by the next
/// question. For a child who cannot read, a half-spoken instruction is no
/// instruction at all. Lines now wait their turn and finish.
///
/// Sound effects play on their own channel, so a chime layers over speech
/// instead of truncating it.
class PrimarVoice {
  PrimarVoice._();

  static final PrimarVoice instance = PrimarVoice._();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _speech = AudioPlayer(playerId: 'primar_speech');
  final AudioPlayer _sfx = AudioPlayer(playerId: 'primar_sfx');
  final Connectivity _connectivity = Connectivity();

  final Queue<_Pending> _queue = Queue<_Pending>();
  bool _draining = false;

  Directory? _cacheDir;
  bool _deviceReady = false;
  bool _muted = false;
  String _locale = 'en';

  /// Which voice is doing the teaching. Changing it changes the cache key, not
  /// just the request — see [_fileFor].
  TeachingVoice _voice = teachingVoices.first;

  final Set<String> _cloudUnavailable = {};

  bool get muted => _muted;

  /// Test seams. The queue and the scene are the whole contract for "does the
  /// voice belong to the screen that is showing", and it cannot be asserted
  /// from outside without seeing them.
  @visibleForTesting
  List<String> get debugQueuedLines =>
      _queue.where((p) => p.scene == _scene).map((p) => p.line.id).toList();

  @visibleForTesting
  int get debugScene => _scene;

  Future<void> init({String locale = 'en', String voiceId = 'guide'}) async {
    _locale = locale == 'fr' ? 'fr' : 'en';
    _voice = voiceById(voiceId, _locale);
    await _initDeviceVoice(_locale == 'fr' ? 'fr-FR' : 'en-NG');
    await _initCache();
    try {
      await _sfx.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
    unawaited(prewarm());
  }

  Future<void> _initDeviceVoice(String bcp47) async {
    if (_deviceReady) return;
    try {
      await _tts.setLanguage(bcp47);
      // The device voice is the *fallback*, and it had been tuned as if it
      // were the main event: 0.42 is roughly half speed on Android, which with
      // a raised pitch is exactly the draggy, robotic delivery that gets
      // described as "weird". A child learning to read wants slightly slower
      // than conversational, not half speed.
      await _tts.setSpeechRate(0.52);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      // Without this, speak() returns immediately and the queue runs straight
      // over the top of itself.
      await _tts.awaitSpeakCompletion(true);
      _deviceReady = true;
    } catch (e) {
      debugPrint('[PrimarVoice] device voice unavailable, continuing: $e');
    }
  }

  Future<void> _initCache() async {
    if (_cacheDir != null) return;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/primar_voice');
      if (!await dir.exists()) await dir.create(recursive: true);
      _cacheDir = dir;
    } catch (e) {
      debugPrint('[PrimarVoice] cache unavailable, will use device voice: $e');
    }
  }

  Future<bool> get _isOnline async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return true;
    }
  }

  File? _fileFor(String phraseId) {
    final dir = _cacheDir;
    if (dir == null) return null;
    final safe = phraseId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    // The voice is part of the key, not just part of the request.
    //
    // Without this, switching from Skul Mate to Teacher Abeo would appear to do
    // nothing: every phrase is already on disk under the old voice, so nothing
    // would be re-fetched and the child would keep hearing whoever spoke first.
    // Worse, a family who switched would have no way to switch back to a voice
    // that sounded right.
    final v = _voice.synthName ?? _voice.id;
    return File('${dir.path}/${_locale}_${v}_$safe.mp3');
  }

  /// Resolved once. Reading it per line printed a config banner three times a
  /// second for the length of the prewarm — visible in logcat on a real device
  /// as hundreds of identical lines, on a phone whose battery was already
  /// critical.
  String? _baseUrl;

  /// Fills the on-device cache for the language actually in use.
  ///
  /// This used to walk [VoiceLines.all], which is every fixed line plus every
  /// letter, letter sound, decodable word, number and counting line **for both
  /// locales** — several hundred serial HTTP requests, restarted from scratch
  /// on every launch because nothing recorded that it had finished.
  ///
  /// Now it downloads only what this locale needs, stops at the first sign the
  /// network has gone, and yields between items so a session starting at the
  /// same moment is not competing with it for the radio.
  Future<void> prewarm() async {
    if (_cacheDir == null || !await _isOnline) return;

    var consecutiveFailures = 0;
    for (final line in VoiceLines.forLocale(_locale)) {
      final file = _fileFor(line.id);
      if (file == null || await file.exists()) continue;

      final ok = await _download(line);
      consecutiveFailures = ok ? 0 : consecutiveFailures + 1;
      // Three misses in a row means the network went, not that three phrases
      // are missing. Grinding through two hundred more timeouts helps nobody.
      if (consecutiveFailures >= 3) return;

      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  Future<bool> _download(VoiceLine line) async {
    final key = '${_locale}_${_voice.id}_${line.id}';
    if (_cloudUnavailable.contains(key)) return false;
    final file = _fileFor(line.id);
    if (file == null) return false;

    try {
      _baseUrl ??= AppConfig.effectiveApiBaseUrl;
      final voice = _voice.synthName;
      final uri = Uri.parse(
        '$_baseUrl/primar/voice?${line.query}&locale=$_locale'
        '${voice == null ? '' : '&voice=$voice'}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        _cloudUnavailable.add(key);
        return false;
      }
      // Temp name first, so an interrupted download cannot leave a truncated
      // file that later reads as a valid cache hit.
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(response.bodyBytes, flush: true);
      await temp.rename(file.path);
      return true;
    } catch (e) {
      debugPrint('[PrimarVoice] download failed for ${line.id}: $e');
      _cloudUnavailable.add(key);
      return false;
    }
  }

  void setMuted(bool value) {
    _muted = value;
    if (value) {
      _queue.clear();
      stop();
    }
  }

  /// Queues a line. It is spoken in full, after anything already speaking.
  void say(VoiceLine? line) {
    if (line == null || _muted) return;
    _queue.add(_Pending(line, _scene));
    unawaited(_drain());
  }

  /// Queues several lines as one utterance — a correction followed by the
  /// teaching that explains it, with no gap for a tap to slip into.
  void sayAll(Iterable<VoiceLine?> lines) {
    for (final l in lines) {
      if (l != null && !_muted) _queue.add(_Pending(l, _scene));
    }
    unawaited(_drain());
  }

  /// Contextual tutor line via [TutorBrain] — AI when available, local otherwise.
  void sayFromBrain(TutorContext ctx, {Iterable<VoiceLine?> after = const []}) {
    if (_muted) return;
    unawaited(
      TutorBrain.instance.lineFor(ctx).then((result) {
        sayTutor(result.feedback, after: after);
      }),
    );
  }

  /// Contextual tutor line, with an optional parent-voice emotional beat.
  ///
  /// When the teaching voice is a parent recording, a short catalogue bridge
  /// whose id maps to the right clip plays first — then the item-specific line.
  /// Instructional follow-ups ([after]) stay in the teaching voice.
  ///
  /// Bridge ids are chosen so appreciation never unlocks a struggle clip and
  /// struggle never unlocks praise — see [parentMomentForLine].
  void sayTutor(
    TutorFeedback feedback, {
    Iterable<VoiceLine?> after = const [],
  }) {
    if (_muted) return;
    if (_voice.kind == VoiceKind.parent &&
        feedback.parentMoment != ParentMoment.none) {
      final bridgeId = feedback.parentBridgeId;
      if (bridgeId != null) {
        final moment = parentMomentForLine(bridgeId);
        // Refuse to queue a bridge that would play the wrong emotional clip.
        if (moment == feedback.parentMoment) {
          final bridge = VoiceLines.byId(bridgeId);
          if (bridge != null) _queue.add(_Pending(bridge, _scene));
        }
      }
    }
    _queue.add(_Pending(VoiceLine(feedback.id, feedback.text), _scene));
    for (final l in after) {
      if (l != null) _queue.add(_Pending(l, _scene));
    }
    unawaited(_drain());
  }

  /// What is on screen right now.
  ///
  /// Every queued line remembers the scene it was queued in, and a line whose
  /// scene has passed is dropped rather than spoken. See [newScene] for why
  /// clearing the queue was not enough on its own.
  int _scene = 0;

  /// The screen changed. Everything the last one had to say is now wrong.
  ///
  /// ## Why a counter and not just a clear
  ///
  /// [interrupt] emptied the queue and stopped the player, and lines from the
  /// previous screen still arrived — a child would be three questions into the
  /// onboarding and hear the question from two pages back.
  ///
  /// The queue was never the problem. A line already inside `_speakNow` has
  /// left the queue, and it sits on a chain of awaits: look for the cached
  /// file, check connectivity, *download the audio*, then play. Stopping the
  /// player does nothing to a download that has not finished yet. When it
  /// lands — a second or two later, on a slow connection much longer — it
  /// plays, on whatever screen happens to be showing by then.
  ///
  /// So the check has to be at every await boundary, against something that
  /// moves when the screen does. That is this counter.
  void newScene() {
    _scene++;
    _queue.clear();
    unawaited(stop());
  }

  /// Abandons everything queued. Only for leaving the screen — never to make
  /// room for the next line.
  Future<void> interrupt() async {
    _scene++;
    _queue.clear();
    await stop();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && !_muted) {
        final next = _queue.removeFirst();
        // Queued before the screen changed. Saying it now would be answering
        // a question the child can no longer see.
        if (next.scene != _scene) continue;
        await _speakNow(next.line, next.scene);
      }
    } finally {
      _draining = false;
    }
  }

  /// Whether the good voice has been reachable at all this run.
  ///
  /// Worth knowing, and worth saying once. The synthesis route was returning
  /// 404 in production for an entire round of device testing, so every line a
  /// child heard came from Android's built-in voice — and nothing anywhere said
  /// so. The app sounded wrong and the cause was invisible.
  bool _warnedFallback = false;

  Future<void> _speakNow(VoiceLine line, int scene) async {
    /// True once this line belongs to a screen the child has already left.
    ///
    /// Checked after every await below rather than once at the top, because
    /// the awaits are where the time goes: a download on a slow connection can
    /// outlast several screens on its own.
    bool stale() => scene != _scene || _muted;

    // The parent's own voice, where they recorded one.
    //
    // Only the emotional moments map to a recording — praise, encouragement, a
    // nudge to try again. The questions themselves always stay in the teaching
    // voice, because a parent has not recorded them and never should have to.
    //
    // Any gap falls through silently: a family who recorded two lines out of
    // six gets those two from their parent and the rest from the guide, rather
    // than all-or-nothing. In a house with one phone, most parents are
    // interrupted partway.
    if (_voice.kind == VoiceKind.parent) {
      final phraseId = parentPhraseFor(line.id);
      if (phraseId != null) {
        final recording = await ParentVoiceStore.instance.recordingFor(
          phraseId,
        );
        if (stale()) return;
        if (recording != null && await _playToEnd(recording)) return;
      }
    }

    final file = _fileFor(line.id);

    if (file != null && await file.exists()) {
      if (stale()) return;
      if (await _playToEnd(file)) return;
    }
    if (stale()) return;
    if (file != null && await _isOnline && await _download(line)) {
      // The download is the long one. On a slow connection it can finish two
      // screens later, and playing it then is the whole defect.
      if (stale()) return;
      if (await _playToEnd(file)) return;
    }
    if (stale()) return;
    if (!_warnedFallback) {
      _warnedFallback = true;
      debugPrint(
        '[PrimarVoice] the synthesis route is unreachable — every line '
        'this session will use the built-in device voice. Check that '
        '/api/primar/voice is deployed.',
      );
    }
    await _speakOnDevice(line.text);
  }

  /// Plays and waits for the end, so the next line cannot start on top of it.
  Future<bool> _playToEnd(File file) async {
    try {
      final done = Completer<void>();
      late final StreamSubscription<void> sub;
      sub = _speech.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      });

      await _speech.play(DeviceFileSource(file.path));
      // A lost completion event must not wedge the queue forever.
      await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
      await sub.cancel();
      return true;
    } catch (e) {
      debugPrint('[PrimarVoice] playback failed, falling back: $e');
      return false;
    }
  }

  Future<void> _speakOnDevice(String text) async {
    if (!_deviceReady) return;
    try {
      // awaitSpeakCompletion(true) makes this wait for the end of the sentence.
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[PrimarVoice] device speak failed: $e');
    }
  }

  /// Assets that have already failed to load once.
  ///
  /// A sound that cannot be decoded on this platform will not start working
  /// later in the same run, but the tick fires every second and the tap fires
  /// on every touch — so a single bad asset was producing hundreds of identical
  /// failures, each one a real await that a child's frame had to wait behind.
  /// The first failure is worth knowing about; the next two hundred are noise.
  final Set<String> _deadAssets = {};

  /// Plays a file straight from disk, for previewing a parent's recording.
  Future<void> playFile(String path) async {
    await interrupt();
    await _playToEnd(File(path));
  }

  /// A short sound, on its own channel so it layers over speech.
  Future<void> chime(Sfx sound) async {
    if (_muted || _deadAssets.contains(sound.asset)) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource(sound.asset), volume: sound.volume);
    } catch (e) {
      _deadAssets.add(sound.asset);
      debugPrint(
        '[PrimarVoice] sfx ${sound.asset} unavailable, silenced for this run: $e',
      );
    }
  }

  /// Ticks get their own player. Sharing the effects channel would cut off a
  /// celebration mid-note every second, and stacking them on the speech channel
  /// would talk over the question.
  final AudioPlayer _tickPlayer = AudioPlayer(playerId: 'primar_tick');

  Future<void> tick({bool urgent = false}) async {
    if (_muted) return;
    final s = urgent ? Sfx.tickLast : Sfx.tick;
    if (_deadAssets.contains(s.asset)) return;
    try {
      await _tickPlayer.stop();
      await _tickPlayer.play(AssetSource(s.asset), volume: s.volume);
    } catch (_) {
      // A missed tick is nothing. Never let it surface — but stop asking, or
      // it will be missed again every second for the rest of the session.
      _deadAssets.add(s.asset);
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _queue.clear();
    await stop();
    await _speech.dispose();
    await _sfx.dispose();
    await _tickPlayer.dispose();
  }
}

/// The sounds a child hears. Kept few — a product that pings constantly stops
/// meaning anything.
/// The sounds a child hears, and how long each one lasts.
///
/// The originals shipped in this repo were unusable: MP3 files carrying `.ogg`
/// extensions, 192 kbps stereo, roughly thirty seconds each — a "soft tap"
/// weighing 744 KB and playing half a minute of music over a child tapping a
/// tile. Several were byte-identical to one another.
///
/// These are synthesised instead, so the duration is exact and audible at the
/// size a phone speaker actually is. Every one is under a fifth of a second
/// except the end-of-session flourish.
enum Sfx {
  /// 0.205s — a rising third. Reads as "yes" without being shrill.
  correct('audio/sfx/correct.wav', 0.75),

  /// 0.290s — three rising notes, for a small climb.
  levelUp('audio/sfx/level_up.wav', 0.8),

  /// 0.545s — a short arpeggio. The only one allowed past a quarter second.
  finish('audio/sfx/finish.wav', 0.9),

  /// 0.045s — barely there. A tap should be felt, not heard.
  tap('audio/sfx/tap.wav', 0.3),

  /// 0.189s — warmer, for a second-chance win.
  streak('audio/sfx/streak.wav', 0.7),

  /// Soft "not yet" cue. A miss should feel directional, never punitive.
  wrong('sounds/incorrect.mp3', 0.42),

  /// 0.060s — a dry woodblock tick, deliberately quiet. It sits under the
  /// voice rather than competing with it. The first cut was 22ms, under two
  /// frames, and on a phone speaker outdoors it simply was not there.
  tick('audio/sfx/tick.wav', 0.5),

  /// 0.085s — lower and longer, for the last few seconds.
  tickLast('audio/sfx/tick_last.wav', 0.6),

  /// 0.24s — a soft two-note fall when the time is up. Not a buzzer: it says
  /// "let us look at this together", never "you failed".
  timesUp('audio/sfx/times_up.wav', 0.6);

  const Sfx(this.asset, this.volume);
  final String asset;
  final double volume;
}

/// One spoken line. [id] is the cache key; [query] is how the server is asked.
class VoiceLine {
  const VoiceLine(this.id, this.text, {String? query}) : _query = query;

  final String id;
  final String text;
  final String? _query;

  String get query => _query ?? 'phrase=$id';

  /// A letter's sound — /g/, not the name "gee".
  static VoiceLine sound(String s) =>
      VoiceLine('sound_$s', s, query: 'sound=$s');

  /// A whole word, spoken.
  static VoiceLine word(String w) => VoiceLine('word_$w', w, query: 'word=$w');

  /// Naming a letter while teaching.
  static VoiceLine letterName(String l) =>
      VoiceLine('letter_$l', l, query: 'letter=$l');

  /// Naming a number while teaching.
  static VoiceLine number(int n) =>
      VoiceLine('number_$n', '$n', query: 'number=$n');

  /// Counting aloud: "one, two, three, four".
  static VoiceLine countTo(int n) =>
      VoiceLine('count_$n', 'count to $n', query: 'count=$n');
}

/// Every fixed line. Short, because they are heard rather than read, often in a
/// second language. None of them names a mistake.
class VoiceLines {
  VoiceLines._();

  static const watch = VoiceLine('watch', 'Watch.');
  static const theseMakeThis = VoiceLine(
    'these_make_this',
    'These two make this one.',
  );
  static const takeAway = VoiceLine('take_away', 'Take this part away.');
  static const yourTurn = VoiceLine(
    'your_turn',
    'Now you try. Which one fits?',
  );
  static const yes = VoiceLine('yes', 'Yes!');
  static const niceOne = VoiceLine('nice_one', 'Nice one.');
  static const thatIsIt = VoiceLine('that_is_it', 'That is it.');
  static const good = VoiceLine('good', 'Good.');
  static const thisOne = VoiceLine('this_one', 'This one.');
  static const lookAgain = VoiceLine('look_again', 'Look. This one fits.');
  static const allDone = VoiceLine('all_done', 'All done. Well done.');

  static const howMany = VoiceLine('how_many', 'How many?');
  static const findThisMany = VoiceLine('find_this_many', 'Find this many.');
  static const whichIsMore = VoiceLine(
    'which_is_more',
    'Which one has the most?',
  );
  static const howManyAltogether = VoiceLine(
    'how_many_altogether',
    'How many altogether?',
  );
  static const howManyLeft = VoiceLine('how_many_left', 'How many are left?');
  static const whatIsMissing = VoiceLine('what_is_missing', 'What is missing?');
  static const findTheSame = VoiceLine('find_the_same', 'Find the same one.');
  static const matchThem = VoiceLine(
    'match_them',
    'Join each group to its number.',
  );
  static const wellMatched = VoiceLine(
    'well_matched',
    'All joined. Well done.',
  );
  // Speaking practice. Both outcomes are warm, because one of them is "the
  // recogniser did not catch it" and a child cannot tell the difference.
  static const sayItBack = VoiceLine('say_it_back', 'Now you say it.');
  static const iHeardYou = VoiceLine('i_heard_you', 'I heard you! Well done.');
  static const goodTry = VoiceLine('good_try', 'Good try. Let us keep going.');

  // The b/d hand trick. Four short lines rather than one long one, so each
  // arrives while the thing it describes is appearing on screen.
  // A different way in, when the same mistake keeps coming back.
  //
  // One line, said before the question, naming what to look at. The wording of
  // *what* to look at comes from the intervention registry, so this is only the
  // frame around it.
  static const anotherWay = VoiceLine(
    'another_way',
    'Let us try that a different way.',
  );
  static const lookAtBoth = VoiceLine(
    'look_at_both',
    'Look at both of them together.',
  );

  static const putInOrder = VoiceLine(
    'put_in_order',
    'Drag them in order. Smallest first.',
  );

  /// Spelling. Said the first time a child is asked to build a word rather
  /// than pick one — a whole new way of answering, and the only instruction a
  /// non-reader gets is this one spoken sentence.
  static const buildTheWord = VoiceLine(
    'build_the_word',
    'Tap the letters to build the word.',
  );
  static const wellOrdered = VoiceLine('well_ordered', 'In order. Well done.');

  /// Said only when a spoken answer was recognised. There is deliberately no
  /// counterpart for "not heard" — silence after a child speaks is kinder than
  /// being told the phone did not understand them.

  // Teaching. Said on a miss, so the child is told what the answer *is* and
  // why — not merely that they were wrong.
  static const itIsThisOne = VoiceLine('it_is_this_one', 'It is this one.');
  static const letsCount = VoiceLine('lets_count', "Let's count together.");
  static const soThatMakes = VoiceLine('so_that_makes', 'So that makes');
  static const thisLetterSays = VoiceLine(
    'this_letter_says',
    'This letter says',
  );
  static const listen = VoiceLine('listen', 'Listen.');
  static const nowYouTry = VoiceLine('now_you_try', 'Now you try.');

  // Said when a child has been thinking a while. Never hurrying them.
  static const takeYourTime = VoiceLine('take_your_time', 'Take your time.');
  static const haveALook = VoiceLine('have_a_look', 'Have a good look.');
  static const youCanDoIt = VoiceLine('you_can_do_it', 'You can do this.');

  // Spoken to the parent, not the child. The product assumes a parent may not
  // read either — a printed instruction is no instruction for the family this
  // is built for.
  static const welcomeParent = VoiceLine(
    'welcome_parent',
    'Welcome. I will ask you four short questions, one at a time, so we can '
        'start your child in the right place.',
  );
  static const welcomePick = VoiceLine(
    'welcome_pick',
    'Pick shapes, numbers, or letters.',
  );
  static const handoffParent = VoiceLine(
    'handoff_parent',
    'Now give the phone to your child. They do not need help.',
  );
  static const resultParent = VoiceLine(
    'result_parent',
    'Here is where your child is working now, and what comes next.',
  );

  // One line per onboarding question, read aloud as the page arrives.
  //
  // A single welcome line at the start was the same voice for five different
  // screens, which is no better than silence for a parent who cannot read the
  // question in front of them. Each page now says its own question.
  static const askLanguage = VoiceLine(
    'ask_language',
    'Which language is your child learning to read in?',
  );
  static const askVoice = VoiceLine(
    'ask_voice',
    'Who would you like to teach your child?',
  );

  /// Played when a parent taps a voice to hear it. Deliberately something a
  /// child would actually be told, so a parent is judging the real thing.
  static const voiceSample = VoiceLine(
    'voice_sample',
    'Hello! I am going to help you learn. Let us start.',
  );

  static const askName = VoiceLine(
    'ask_name',
    "What is your child's first name?",
  );
  static const askAge = VoiceLine('ask_age', 'How old are they?');
  static const askAgeWhy = VoiceLine(
    'ask_age_why',
    'This only chooses the first question. What your child does decides the rest.',
  );
  static const askSchool = VoiceLine(
    'ask_school',
    'How much school have they had this year?',
  );
  static const askSubject = VoiceLine(
    'ask_subject',
    'What should we look at first? Shapes, numbers, or letters.',
  );
  static const askSeenReading = VoiceLine(
    'ask_seen_reading',
    'Which of these have you seen them do with letters?',
  );
  static const askSeenNumbers = VoiceLine(
    'ask_seen_numbers',
    'Which of these have you seen them do with numbers?',
  );
  static const askSeenShapes = VoiceLine(
    'ask_seen_shapes',
    'Which of these have you seen them do with shapes?',
  );

  // The warm-up. Said to the child, not the parent — they are holding the
  // phone by now.
  static const warmUpChild = VoiceLine(
    'warm_up_child',
    'Let us try three quick ones first. Just have a go.',
  );
  static const warmUpDone = VoiceLine(
    'warm_up_done',
    'Good. Now the real game.',
  );

  static const List<VoiceLine> praise = [yes, niceOne, thatIsIt, good];
  static const List<VoiceLine> waiting = [takeYourTime, haveALook, youCanDoIt];

  static const List<VoiceLine> fixed = [
    watch,
    theseMakeThis,
    takeAway,
    yourTurn,
    yes,
    niceOne,
    thatIsIt,
    good,
    thisOne,
    lookAgain,
    allDone,
    howMany,
    findThisMany,
    whichIsMore,
    howManyAltogether,
    howManyLeft,
    whatIsMissing,
    findTheSame,
    matchThem,
    wellMatched,
    putInOrder,
    wellOrdered,
    buildTheWord,
    sayItBack,
    iHeardYou,
    goodTry,
    anotherWay,
    lookAtBoth,
    itIsThisOne,
    letsCount,
    soThatMakes,
    thisLetterSays,
    listen,
    nowYouTry,
    takeYourTime,
    haveALook,
    youCanDoIt,
    welcomeParent,
    welcomePick,
    handoffParent,
    resultParent,
    askLanguage,
    askName,
    askAge,
    askAgeWhy,
    askSchool,
    askSubject,
    askSeenReading,
    askSeenNumbers,
    askSeenShapes,
    warmUpChild,
    warmUpDone,
  ];

  /// Everything one language needs.
  ///
  /// [all] is both locales at once — several hundred lines. Prewarming that on
  /// launch meant an English family downloading the entire French alphabet,
  /// sound table and word list before their first question, over a connection
  /// that may be a shared 3G tether.
  static List<VoiceLine> forLocale(String locale) => [
    ...fixed,
    for (var n = 1; n <= 20; n++) VoiceLine.number(n),
    for (var n = 1; n <= 10; n++) VoiceLine.countTo(n),
    for (final l in 'abcdefghijklmnopqrstuvwxyz'.split(''))
      VoiceLine.letterName(l),
    for (final id in literacySpeechCatalogue(locale: locale))
      if (byId(id) != null) byId(id)!,
  ];

  /// Everything the voice layer can be asked for, in every language. Still a
  /// closed set — used by tests and by anything that has to reason about the
  /// whole catalogue, never by the prewarm.
  static List<VoiceLine> get all => [
    ...fixed,
    for (var n = 1; n <= 20; n++) VoiceLine.number(n),
    for (var n = 1; n <= 10; n++) VoiceLine.countTo(n),
    for (final l in 'abcdefghijklmnopqrstuvwxyz'.split(''))
      VoiceLine.letterName(l),
    // Letter sounds and the decodable word list. These were missing, so
    // every reading item above level 2 would have gone silent the moment
    // the network did — the exact opposite of the offline guarantee.
    for (final locale in ['en', 'fr'])
      for (final id in literacySpeechCatalogue(locale: locale))
        if (byId(id) != null) byId(id)!,
  ];

  /// Resolves an item's phrase id, including the parameterised forms a
  /// teaching line uses.
  static VoiceLine? byId(String? id) {
    if (id == null) return null;
    if (id.startsWith('sound:')) return VoiceLine.sound(id.substring(6));
    if (id.startsWith('word:')) return VoiceLine.word(id.substring(5));
    if (id.startsWith('letter:')) return VoiceLine.letterName(id.substring(7));
    if (id.startsWith('count:')) {
      final n = int.tryParse(id.substring(6));
      return n == null ? null : VoiceLine.countTo(n);
    }
    if (id.startsWith('number:')) {
      final n = int.tryParse(id.substring(7));
      return n == null ? null : VoiceLine.number(n);
    }
    for (final l in fixed) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// The full teaching utterance for an item, in order.
  static List<VoiceLine> teachingFor(List<String> ids) =>
      ids.map(byId).whereType<VoiceLine>().toList();
}

/// A line waiting its turn, and the screen it was queued for.
///
/// The scene travels with the line rather than being read at speaking time,
/// because by then it is already the wrong screen's number.
class _Pending {
  const _Pending(this.line, this.scene);
  final VoiceLine line;
  final int scene;
}
