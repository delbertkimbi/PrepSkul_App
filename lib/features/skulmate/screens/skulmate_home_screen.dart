import '../widgets/mate_tutor_recommendations.dart';
import 'package:prepskul/core/widgets/mascot_state.dart';
import 'dart:async';
import 'package:prepskul/core/design/prepskul_icon.dart';
import '../services/learning_activity_store.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import '../widgets/mate_access_bar.dart';

import 'package:flutter/material.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/discovery/screens/find_tutors_screen.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../models/tutor_session_models.dart';
import '../services/skulmate_home_refresh_bus.dart';
import '../services/skulmate_streak_reminder_service.dart';
import '../services/skulmate_session_cache.dart';
import '../services/skulmate_tutor_intake_bus.dart';
import '../services/skulmate_tutor_session_service.dart';
import '../services/skulmate_tutor_voice_service.dart';
import '../services/learner_context_service.dart';
import '../widgets/skulmate_home_top_bar.dart';
import '../widgets/skulmate_in_thread_surface.dart';
import '../widgets/skulmate_mascot_media_widget.dart';
import '../widgets/skulmate_tutor_board.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../widgets/skulmate_tutor_composer.dart';
import '../widgets/tutor_chat_bubble.dart';

/// SkulMate tab — voice + chat tutor. Learners and parents are both students.
class SkulMateHomeScreen extends StatefulWidget {
  final VoidCallback? onExit;
  final String? childId;
  final String? initialMessage;
  final bool startFresh;
  final String? lessonId;
  final int? lessonStep;
  final Future<void> Function(String sessionId, String turnId)? onPracticeSaved;

  const SkulMateHomeScreen({
    super.key,
    this.startFresh = false,
    this.childId,
    this.onExit,
    this.initialMessage,
    this.onPracticeSaved,
    this.lessonId,
    this.lessonStep,
  });

  @override
  State<SkulMateHomeScreen> createState() => _SkulMateHomeScreenState();
}

class _SkulMateHomeScreenState extends State<SkulMateHomeScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _voice = SkulMateTutorVoiceService.instance;
  final List<TutorTurn> _turns = [];

  String? _sessionId;
  bool _pendingNewSession = false;
  Map<String, dynamic>? _learnerContext;
  String? _failedInput;
  String? _retrySessionId;
  SkulMateIntakePayload? _failedPayload;
  bool _busy = false;
  SkulMateMascotState? _reaction;
  Timer? _reactionTimer;

  void _reactToAnswer(bool correct) {
    _reactionTimer?.cancel();
    safeSetState(
      () => _reaction = correct
          ? SkulMateMascotState.success
          : SkulMateMascotState.tryAgain,
    );
    _reactionTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) safeSetState(() => _reaction = null);
    });
  }

  bool _showTranscript = false;
  bool _attachOpen = false;
  bool _recording = false;
  bool _demo = false;
  bool _voiceOut = true;
  String? _error;
  bool _alwaysStarted = false;
  bool _arrivalGreeting = true;
  Timer? _arrivalTimer;

  @override
  void initState() {
    super.initState();
    _arrivalTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) safeSetState(() => _arrivalGreeting = false);
    });
    _pendingNewSession = widget.startFresh;
    _voice.state.addListener(_onVoiceState);
    WidgetsBinding.instance.addObserver(this);
    SkulMateHomeRefreshBus.tick.addListener(_onRefresh);
    SkulMateTutorIntakeBus.pending.addListener(_onIntake);
    _applyStatusBarStyle();
    unawaited(ConnectivityService().initialize());
    unawaited(_bootstrap());
    unawaited(_loadLearnerContext());
    SkulMateStreakReminderService.recordActivityAndReschedule();
  }

  Future<void> _loadLearnerContext() async {
    final context = await LearnerContextService.build(childId: widget.childId);
    if (!mounted || context == null) return;
    safeSetState(() => _learnerContext = context);
  }

  void _onVoiceState() {
    if (mounted) {
      safeSetState(() {
        _recording = _voice.state.value == TutorVoiceState.recording;
      });
    }
  }

  String? get _learningTrackLabel {
    final context = _learnerContext;
    if (context == null) return null;

    String? valueFor(List<String> keys) {
      for (final key in keys) {
        final value = context[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.trim().isNotEmpty) return first.trim();
        }
      }
      return null;
    }

    final level = valueFor(['class_level', 'student_grade']);
    final exam = valueFor(['target_exam', 'exam_type', 'exam']);
    final subject = valueFor(['subjects', 'subject_preferences']);
    final parts = [
      if (level != null) level,
      if (exam != null) exam,
      if (subject != null) subject,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? get _learningSubject {
    final raw =
        _learnerContext?['subjects'] ?? _learnerContext?['subject_preferences'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is List) {
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) return item.trim();
      }
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Web recognition must begin from the learner’s microphone tap.
    if (kIsWeb || _alwaysStarted) return;
    _alwaysStarted = true;
    final locale = Localizations.localeOf(context).languageCode;
    unawaited(
      _voice
          .startAlwaysOn(
            locale: locale,
            onUtterance: (text) {
              if (!mounted || _busy) return;
              unawaited(_sendText(text));
            },
          )
          .then((_) {
            if (mounted) safeSetState(() => _recording = _voice.isListening);
          }),
    );
  }

  @override
  void dispose() {
    _voice.state.removeListener(_onVoiceState);
    _reactionTimer?.cancel();
    _arrivalTimer?.cancel();
    unawaited(_voice.endSession());
    SkulMateHomeRefreshBus.tick.removeListener(_onRefresh);
    SkulMateTutorIntakeBus.pending.removeListener(_onIntake);
    WidgetsBinding.instance.removeObserver(this);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onRefresh() {
    if (!mounted) return;
  }

  void _onIntake() {
    final payload = SkulMateTutorIntakeBus.take();
    if (payload == null) return;
    unawaited(_ingest(payload));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyStatusBarStyle();
    }
  }

  void _applyStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      SkulMateSurfaceStyles.lightStatusBarOverlay,
    );
  }

  Future<void>? _openingSession;
  Future<void> _bootstrap() {
    return _openingSession ??= _openSessionOnce().whenComplete(
      () => _openingSession = null,
    );
  }

  Future<void> _openSessionOnce() async {
    if (!_pendingNewSession &&
        widget.initialMessage == null &&
        widget.lessonId == null &&
        widget.childId == null) {
      final cachedId = await SkulMateSessionCache.activeSessionId();
      if (cachedId != null) {
        final cached = await SkulMateSessionCache.loadTurns(cachedId);
        if (mounted && _turns.isEmpty && cached.isNotEmpty) {
          safeSetState(() {
            _sessionId = cachedId;
            _turns.addAll(cached);
          });
        }
      }
    }
    await ConnectivityService().initialize();
    if (!mounted || !ConnectivityService().isOnline) return;
    try {
      final opened = await SkulMateTutorSessionService.openSession(
        childId: widget.childId,
        forceNew: _pendingNewSession || widget.initialMessage != null,
        lessonId: widget.lessonId,
        lessonStep: widget.lessonStep,
      );
      await _applyOpened(opened);
      if (mounted && widget.initialMessage != null) {
        await _sendText(widget.initialMessage!);
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _sessionId = null;
          _demo = false;
          _busy = false;
          _error = e is MateSessionException
              ? e.message(Localizations.localeOf(context).languageCode == 'fr')
              : (Localizations.localeOf(context).languageCode == 'fr'
                    ? 'Connexion à Mate interrompue. Réessaie quand la connexion revient.'
                    : 'Couldn’t connect to Mate. Retry when the connection is available.');
        });
      }
    }
  }

  Future<void> _startNew() async {
    _pendingNewSession = true;
    _sessionId = null;
    await _voice.endSession();
    if (!ConnectivityService().isOnline) {
      if (mounted)
        safeSetState(() {
          _sessionId = null;
          _turns.clear();
          _busy = false;
          _error = null;
          _composer.clear();
        });
      return;
    }
    try {
      safeSetState(() {
        _busy = true;
        _error = null;
        _failedInput = null;
        _failedPayload = null;
      });
      final opened = await SkulMateTutorSessionService.openSession(
        childId: widget.childId,
        forceNew: true,
      );
      await _applyOpened(opened);
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _busy = false;
          _error = SkulMateCopy.read(context).tutorSessionError;
          _retrySessionId = null;
        });
      }
    }
  }

  Future<void> _openExisting(String sessionId) async {
    _pendingNewSession = false;
    await _voice.endSession();
    final cached = await SkulMateSessionCache.loadTurns(sessionId);
    if (!mounted) return;
    if (cached.isNotEmpty)
      safeSetState(() {
        _sessionId = sessionId;
        _turns
          ..clear()
          ..addAll(cached);
        _busy = false;
        _error = null;
      });
    if (!ConnectivityService().isOnline) {
      if (cached.isEmpty) {
        safeSetState(() {
          _busy = false;
          _error = Localizations.localeOf(context).languageCode == 'fr'
              ? 'Cette séance n’est pas enregistrée sur cet appareil. Reconnecte-toi pour l’ouvrir.'
              : 'This session is not saved on this device. Reconnect to open it.';
          _retrySessionId = sessionId;
        });
      }
      return;
    }
    try {
      safeSetState(() {
        _busy = true;
        _error = null;
      });
      final opened = await SkulMateTutorSessionService.loadSession(sessionId);
      await _applyOpened(opened);
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _busy = false;
          _error = SkulMateCopy.read(context).tutorSessionError;
          _retrySessionId = sessionId;
        });
      }
    }
  }

  Future<void> _applyOpened(Map<String, dynamic> opened) async {
    final session = opened['session'] as Map<String, dynamic>?;
    final id = (session?['id'] as String?) ?? opened['sessionId'] as String?;
    if (id == null || id == 'demo') {
      throw Exception('A saved learning session could not be opened.');
    }
    final cached = await SkulMateSessionCache.loadTurns(id);
    final remoteTurns = opened['turns'] as List<dynamic>? ?? [];
    final parsedRemote = <TutorTurn>[];
    for (final row in remoteTurns) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final role = map['role'] as String? ?? '';
      final text = map['text'] as String? ?? '';
      if (text.isEmpty) continue;
      parsedRemote.add(
        TutorTurn(
          id: map['id'] as String?,
          isUser: role == 'user',
          text: text,
          surface: practiceSurfaceFromPayload(map['tool_payload']),
          board: tutorBoardFromPayload(
            map['tool_payload'],
            boardField: map['board'],
          ),
        ),
      );
    }
    if (!mounted) return;
    safeSetState(() {
      _pendingNewSession = false;
      _sessionId = id;
      _demo = false;
      _busy = false;
      _error = null;
      _failedInput = null;
      _failedPayload = null;
      _retrySessionId = null;
      _turns
        ..clear()
        ..addAll(parsedRemote.isNotEmpty ? parsedRemote : cached);
    });
    await SkulMateSessionCache.saveTurns(sessionId: id, turns: _turns);
    _scrollSoon();
  }

  Future<void> _sendText(String raw, {bool addUserTurn = true}) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    if (!ConnectivityService().isOnline) {
      safeSetState(
        () => _error = Localizations.localeOf(context).languageCode == 'fr'
            ? 'Le tutorat en direct nécessite une connexion. Ton message reste dans le champ.'
            : 'Live tutoring needs a connection. Your message is still in the composer.',
      );
      return;
    }
    final sessionId = _sessionId;
    if (sessionId == null) {
      _composer.text = text;
      safeSetState(() => _busy = true);
      _voice.setThinking();
      await _bootstrap();
      if (!mounted) return;
      safeSetState(() => _busy = false);
    }
    final id = _sessionId;
    if (id == null) return;

    _composer.clear();
    safeSetState(() {
      if (addUserTurn) {
        _turns.add(TutorTurn(isUser: true, text: text));
      }
      _busy = true;
      _error = null;
      _failedInput = null;
      _failedPayload = null;
      _attachOpen = false;
    });
    if (addUserTurn && !_demo) {
      final userTurn = _turns.last;
      await SkulMateSessionCache.appendTurn(sessionId: id, turn: userTurn);
    }
    _voice.setThinking();
    _scrollSoon();

    try {
      final result = await SkulMateTutorSessionService.sendTurn(
        sessionId: id,
        message: text,
        childId: widget.childId,
        demo: _demo,
        notes: text.contains('\n') && text.length > 40 ? text : null,
      );
      final assistant = TutorTurn(
        id: result.turnId,
        isUser: false,
        text: result.message,
        surface: result.surface,
        board: result.board,
        imageUrl: result.imageUrl,
        speak: result.speak,
        escalate: result.escalate,
        move: result.move,
      );
      if (!mounted) return;
      safeSetState(() {
        _turns.add(assistant);
        _busy = false;
        _error = null;
        _failedInput = null;
      });
      await SkulMateSessionCache.saveTurns(sessionId: id, turns: _turns);
      await LearningActivityStore.record(
        'conversation',
        concept: widget.initialMessage,
      );
      _scrollSoon();
      if (result.speak) {
        unawaited(_speakThenListen(result.message));
      } else {
        await _voice.interrupt();
      }
    } catch (e) {
      if (!mounted) return;
      safeSetState(() {
        _busy = false;
        _error = SkulMateCopy.read(context).tutorConnectionError;
        _failedInput = text;
      });
      await _voice.interrupt();
    }
  }

  Future<void> _ingest(SkulMateIntakePayload payload) async {
    final sessionId = _sessionId;
    if (sessionId == null) await _bootstrap();
    final id = _sessionId;
    if (id == null) return;
    safeSetState(() {
      _busy = true;
      _error = null;
      _failedInput = null;
      _failedPayload = null;
    });
    _voice.setThinking();
    try {
      final result = await SkulMateTutorSessionService.ingestPayload(
        sessionId: id,
        payload: payload,
      );
      if (!mounted) return;
      if (result != null) {
        safeSetState(() {
          _turns.add(
            TutorTurn(
              isUser: true,
              text:
                  payload.title ?? payload.topicHint ?? payload.text ?? 'Notes',
            ),
          );
          _turns.add(
            TutorTurn(
              id: result.turnId,
              isUser: false,
              text: result.message,
              surface: result.surface,
              board: result.board,
              imageUrl: result.imageUrl,
              speak: result.speak,
              escalate: result.escalate,
              move: result.move,
            ),
          );
          _busy = false;
          _attachOpen = false;
          _error = null;
          _failedPayload = null;
        });
        if (result.speak) unawaited(_speakThenListen(result.message));
      } else {
        safeSetState(() => _busy = false);
      }
      _scrollSoon();
    } catch (e) {
      if (!mounted) return;
      safeSetState(() {
        _busy = false;
        _error = SkulMateCopy.read(context).tutorMaterialError;
        _failedPayload = payload;
      });
    }
  }

  Future<void> _speakThenListen(String text) async {
    _voice.voiceOut = _voiceOut;
    if (mounted) safeSetState(() => _recording = false);
    await _voice.speakTutor(text);
  }

  Future<void> _toggleMic() async {
    if (_voice.state.value == TutorVoiceState.speaking) {
      await _voice.interrupt();
      if (mounted) safeSetState(() => _recording = _voice.isListening);
      return;
    }
    if (!_alwaysStarted || _voice.privacyMute || !_voice.isListening) {
      _alwaysStarted = true;
      await _voice.startAlwaysOn(
        locale: Localizations.localeOf(context).languageCode,
        onUtterance: (text) {
          if (!mounted || _busy) return;
          unawaited(_sendText(text));
        },
      );
      if (!mounted) return;
      safeSetState(() => _recording = _voice.isListening);
      return;
    }
    await _voice.setPrivacyMute(true);
    if (mounted) safeSetState(() => _recording = false);
  }

  void _toggleVoiceOut() {
    final next = !_voiceOut;
    _voice.voiceOut = next;
    if (!next) unawaited(_voice.interrupt());
    safeSetState(() => _voiceOut = next);
  }

  Future<void> _holdStart() async {
    if (_voice.state.value == TutorVoiceState.speaking) {
      await _voice.interrupt();
    }
    final ok = await _voice.startListening();
    if (mounted) safeSetState(() => _recording = ok);
  }

  Future<void> _holdEnd() async {
    final heard = await _voice.stopListening();
    if (mounted) safeSetState(() => _recording = false);
    if (heard != null && heard.isNotEmpty) {
      await _sendText(heard);
    }
  }

  void _scrollSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _retryLastAction() {
    final failedInput = _failedInput;
    if (failedInput != null) {
      unawaited(_sendText(failedInput, addUserTurn: false));
      return;
    }
    final failedPayload = _failedPayload;
    if (failedPayload != null) {
      unawaited(_ingest(failedPayload));
      return;
    }
    final sessionId = _retrySessionId;
    if (sessionId != null) {
      unawaited(_openExisting(sessionId));
    } else {
      unawaited(_bootstrap());
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final speaking = _voice.state.value == TutorVoiceState.speaking;
    final recording = _recording;
    final latestReply = _turns.where((turn) => !turn.isUser).lastOrNull;
    final visibleTurns = _showTranscript
        ? _turns
        : latestReply != null
        ? [latestReply]
        : <TutorTurn>[];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SkulMateSurfaceStyles.lightStatusBarOverlay,
      child: Scaffold(
        backgroundColor: LearnerDesign.canvas,
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              if (widget.initialMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      BackButton(color: AppTheme.primaryColor),
                      Text(
                        copy.isFrench ? 'Avec Mate' : 'With Mate',
                        style: LearnerDesign.display(size: 23),
                      ),
                    ],
                  ),
                )
              else
                SkulMateHomeTopBar(
                  onBack: widget.onExit == null
                      ? null
                      : () {
                          unawaited(_voice.endSession());
                          widget.onExit!();
                        },
                  childId: widget.childId,
                  activeSessionId: _sessionId,
                  onSelectSession: (id) => unawaited(_openExisting(id)),
                  onNewSession: () => unawaited(_startNew()),
                ),
              MateAccessBar(unavailable: _error != null),
              if (_turns.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Row(
                    children: [
                      AliveMate(
                        state: _busy
                            ? MascotState.thinking
                            : _reaction == SkulMateMascotState.success
                            ? MascotState.success
                            : _reaction == SkulMateMascotState.tryAgain
                            ? MascotState.tryAgain
                            : recording
                            ? MascotState.listening
                            : null,
                        mood: speaking
                            ? Mood.talk
                            : _busy
                            ? Mood.thinking
                            : recording
                            ? Mood.encourage
                            : _arrivalGreeting
                            ? Mood.wave
                            : Mood.happy,
                        size: 64,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          speaking
                              ? (copy.isFrench
                                    ? 'Mate explique'
                                    : 'Mate is explaining')
                              : _busy
                              ? (copy.isFrench ? 'Je réfléchis…' : 'Thinking…')
                              : recording
                              ? (copy.isFrench
                                    ? 'Je t’écoute'
                                    : 'Listening to you')
                              : (copy.isFrench ? 'À toi' : 'Your turn'),
                          style: LearnerDesign.display(size: 23),
                        ),
                      ),
                      IconButton(
                        tooltip: _voiceOut
                            ? copy.tutorMuteMate
                            : copy.tutorMateReads,
                        onPressed: _toggleVoiceOut,
                        icon: Icon(
                          _voiceOut
                              ? PhosphorIcons.speakerHigh
                              : PhosphorIcons.speakerSlash,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, viewport) => ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      if (_turns.isEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: viewport.maxHeight < 430 ? 8 : 22,
                            bottom: 24,
                          ),
                          child: _buildEmptyStart(copy),
                        ),
                      if (_turns.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _showTranscript = !_showTranscript,
                            ),
                            icon: Icon(
                              _showTranscript
                                  ? Icons.dashboard_outlined
                                  : Icons.history,
                            ),
                            label: Text(
                              Localizations.localeOf(context).languageCode ==
                                      'fr'
                                  ? (_showTranscript
                                        ? 'Revenir à la leçon'
                                        : 'Voir la conversation')
                                  : (_showTranscript
                                        ? 'Back to lesson'
                                        : 'View conversation'),
                            ),
                          ),
                        ),
                      for (final turn in visibleTurns) ...[
                        if (turn.board != null &&
                            turn.board!.steps.isNotEmpty &&
                            !turn.board!.steps.every(
                              (step) =>
                                  step.kind == 'prompt' &&
                                  turn.text
                                      .replaceAll(RegExp(r'\s+'), ' ')
                                      .trim()
                                      .startsWith(
                                        step.text
                                            .replaceAll(RegExp(r'\s+'), ' ')
                                            .trim(),
                                      ),
                            ))
                          SkulMateTutorBoard(
                            board: turn.board!,
                            imageUrl: turn.imageUrl,
                          ),
                        if (_showTranscript ||
                            turn.isUser ||
                            turn.text.length < 280)
                          TutorChatBubble.text(
                            isUser: turn.isUser,
                            text: turn.text,
                          )
                        else
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              turn.text.split(RegExp(r'(?<=[.!?])\s+')).first,
                              style: LearnerDesign.text(size: 16),
                            ),
                            subtitle: Text(
                              Localizations.localeOf(context).languageCode ==
                                      'fr'
                                  ? 'Lire l’explication complète'
                                  : 'Read the full explanation',
                              style: LearnerDesign.body(12),
                            ),
                            children: [
                              TutorChatBubble.text(
                                isUser: false,
                                text: turn.text,
                              ),
                            ],
                          ),
                        if (turn.surface != null)
                          SkulMateInThreadSurface(
                            key: ValueKey('practice-${turn.id}'),
                            surface: turn.surface!,
                            onOutcome: (_) async {},
                            onContinue: () => _sendText(
                              Localizations.localeOf(context).languageCode ==
                                      'fr'
                                  ? 'Reprenons mes réponses ensemble, puis passons au prochain défi.'
                                  : 'Let’s review my answers together, then try the next challenge.',
                            ),
                            onVerifiedOutcome: (correct, answers) async {
                              _reactToAnswer(correct);
                              if (_sessionId == null || turn.id == null) {
                                throw Exception('Session unavailable');
                              }
                              final independentSuccess =
                                  await SkulMateTutorSessionService.recordOutcome(
                                    sessionId: _sessionId!,
                                    correct: correct,
                                    answers: answers,
                                    childId: widget.childId,
                                    turnId: turn.id,
                                    conceptId: turn.surface?.conceptId,
                                    surfaceType: turn.surface?.gameType,
                                    hintUsed:
                                        turn.surface?.gameType == 'flashcards',
                                  );
                              if (independentSuccess &&
                                  widget.onPracticeSaved != null) {
                                await widget.onPracticeSaved!(
                                  _sessionId!,
                                  turn.id!,
                                );
                              }
                            },
                          ),
                        if (turn.escalate && _learningSubject != null)
                          MateTutorRecommendations(subject: _learningSubject!),
                        if (turn.escalate)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FindTutorsScreen(),
                                  ),
                                );
                              },
                              child: Text(copy.tutorEscalateLive),
                            ),
                          ),
                        if (!turn.isUser &&
                            identical(turn, _turns.last) &&
                            turn.surface == null)
                          _buildFollowUp(copy),
                      ],
                      if (_busy)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              const AliveMate(
                                mood: Mood.thinking,
                                state: MascotState.thinking,
                                size: 52,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  copy.isFrench
                                      ? 'Mate prépare ton explication…'
                                      : 'Mate is preparing your explanation…',
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null) _buildConnectionNotice(copy),
                    ],
                  ),
                ),
              ),
              if (_voice.lastError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      copy.isFrench
                          ? 'Le micro n’a pas démarré. Autorise-le dans ton navigateur, puis touche le micro pour réessayer. Tu peux aussi écrire.'
                          : 'The microphone did not start. Allow it in your browser, then tap the mic to retry. You can also type.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              SkulMateTutorComposer(
                controller: _composer,
                onSend: () => _sendText(_composer.text),
                onHoldStart: () => unawaited(_holdStart()),
                onHoldEnd: () => unawaited(_holdEnd()),
                onMicTap: () => unawaited(_toggleMic()),
                busy: _busy,
                recording: _recording && !_voice.privacyMute,
                speaking: _voice.state.value == TutorVoiceState.speaking,
                privacyMuted: _voice.privacyMute,
                childId: widget.childId,
                attachOpen: _attachOpen,
                onToggleAttach: () =>
                    safeSetState(() => _attachOpen = !_attachOpen),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStart(SkulMateCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        ExcludeSemantics(
          child: AliveMate(
            mood: _busy ? Mood.thinking : Mood.wave,
            state: _busy ? MascotState.thinking : null,
            size: 112,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          copy.isFrench
              ? 'On apprend quoi ensemble ?'
              : 'Let’s figure it out together.',
          style: LearnerDesign.title(26),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _learningTrackLabel ??
              (copy.isFrench
                  ? 'Parle-moi, ou écris ta question.'
                  : 'Talk to me, or type your question.'),
          style: LearnerDesign.body(15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _busy ? null : () => unawaited(_toggleMic()),
          icon: const PrepSkulIcon(PrepSkulGlyph.voice),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              _recording
                  ? (copy.isFrench ? 'J’écoute…' : 'Listening…')
                  : (copy.isFrench ? 'Parler à Mate' : 'Talk to Mate'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const PrepSkulIcon(PrepSkulGlyph.learn, size: 22),
              label: Text(copy.isFrench ? 'Comprendre' : 'Explain it'),
              onPressed: _busy
                  ? null
                  : () =>
                        unawaited(_sendText(_starterMessage(copy, 'explain'))),
            ),
            ActionChip(
              avatar: const PrepSkulIcon(PrepSkulGlyph.practice, size: 22),
              label: Text(copy.isFrench ? 'M’entraîner' : 'Practise'),
              onPressed: _busy
                  ? null
                  : () =>
                        unawaited(_sendText(_starterMessage(copy, 'practice'))),
            ),
          ],
        ),
      ],
    );
  }

  String _starterMessage(SkulMateCopy copy, String intent) {
    final subject = _learningSubject;
    if (copy.isFrench) {
      return switch (intent) {
        'explain' =>
          subject == null
              ? 'Aide-moi à comprendre un sujet simplement.'
              : 'Aide-moi à comprendre $subject simplement.',
        'question' =>
          subject == null
              ? 'Aide-moi à résoudre une question, étape par étape.'
              : 'Aide-moi à résoudre une question de $subject, étape par étape.',
        _ =>
          subject == null
              ? 'Pose-moi une petite question pour m’entraîner.'
              : 'Pose-moi une petite question de $subject pour m’entraîner.',
      };
    }
    return switch (intent) {
      'explain' =>
        subject == null
            ? 'Help me understand a topic in simple words.'
            : 'Help me understand $subject in simple words.',
      'question' =>
        subject == null
            ? 'Help me work through a question one step at a time.'
            : 'Help me work through a $subject question one step at a time.',
      _ =>
        subject == null
            ? 'Ask me one short practice question.'
            : 'Ask me one short $subject practice question.',
    };
  }

  Widget _buildFollowUp(SkulMateCopy copy) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StarterPrompt(
            icon: PhosphorIcons.arrowsClockwise,
            label: copy.tutorExplainAnotherWay,
            onTap: () => unawaited(
              _sendText(
                copy.isFrench
                    ? 'Explique autrement, avec un exemple simple.'
                    : 'Explain that another way, with a simple example.',
              ),
            ),
          ),
          _StarterPrompt(
            icon: PhosphorIcons.question,
            label: copy.tutorCheckUnderstanding,
            onTap: () => unawaited(
              _sendText(
                copy.isFrench
                    ? 'Pose-moi une courte question pour vérifier si j’ai compris.'
                    : 'Ask me one short question to check if I understand.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionNotice(SkulMateCopy copy) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIcons.wifiSlash, size: 19, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: GoogleFonts.nunito(
                    color: AppTheme.textDark,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _retryLastAction,
                  icon: const Icon(PhosphorIcons.arrowClockwise, size: 18),
                  label: Text(copy.tutorRetry),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarterPrompt extends StatelessWidget {
  const _StarterPrompt({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 17, color: AppTheme.primaryColor),
      label: Text(label),
      labelStyle: GoogleFonts.nunito(
        color: AppTheme.primaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
