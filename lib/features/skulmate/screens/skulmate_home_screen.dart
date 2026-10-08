import 'dart:async';

import 'package:flutter/material.dart';
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
import '../widgets/skulmate_hero_mascot.dart';
import '../widgets/skulmate_in_thread_surface.dart';
import '../widgets/skulmate_mascot_media_widget.dart';
import '../widgets/skulmate_tutor_board.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../widgets/skulmate_tutor_composer.dart';
import '../widgets/skulmate_typography.dart';
import '../widgets/skulmate_voice_pill.dart';
import '../widgets/tutor_chat_bubble.dart';

/// SkulMate tab — voice + chat tutor. Learners and parents are both students.
class SkulMateHomeScreen extends StatefulWidget {
  final String? childId;

  const SkulMateHomeScreen({super.key, this.childId});

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
  Map<String, dynamic>? _learnerContext;
  String? _failedInput;
  String? _retrySessionId;
  SkulMateIntakePayload? _failedPayload;
  bool _busy = false;
  SkulMateMascotState? _reaction;
  Timer? _reactionTimer;

  void _reactToAnswer(bool correct) {
    _reactionTimer?.cancel();
    safeSetState(() => _reaction = correct
        ? SkulMateMascotState.success
        : SkulMateMascotState.tryAgain);
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

  @override
  void initState() {
    super.initState();
    _voice.state.addListener(_onVoiceState);
    WidgetsBinding.instance.addObserver(this);
    SkulMateHomeRefreshBus.tick.addListener(_onRefresh);
    SkulMateTutorIntakeBus.pending.addListener(_onIntake);
    _applyStatusBarStyle();
    unawaited(_voice.prepare());
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
    if (_alwaysStarted) return;
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
            if (mounted) safeSetState(() => _recording = !_voice.privacyMute);
          }),
    );
  }

  @override
  void dispose() {
    _voice.state.removeListener(_onVoiceState);
    _reactionTimer?.cancel();
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

  Future<void> _bootstrap() async {
    try {
      final opened = await SkulMateTutorSessionService.openSession(
        childId: widget.childId,
      );
      await _applyOpened(opened);
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _sessionId = 'demo';
          _demo = true;
          _busy = false;
          _error = null;
        });
      }
    }
  }

  Future<void> _startNew() async {
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
    if (id == null) {
      if (mounted) safeSetState(() => _busy = false);
      return;
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
    final sessionId = _sessionId;
    if (sessionId == null) await _bootstrap();
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
      if (mounted) safeSetState(() => _recording = !_voice.privacyMute);
      return;
    }
    final next = !_voice.privacyMute;
    await _voice.setPrivacyMute(next);
    if (mounted) safeSetState(() => _recording = !next);
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
    final latestReply = _turns.where((turn) => !turn.isUser).lastOrNull;
    final visibleTurns = _showTranscript
        ? _turns
        : latestReply != null ? [latestReply] : <TutorTurn>[];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SkulMateSurfaceStyles.lightStatusBarOverlay,
      child: Scaffold(
        backgroundColor: OnboardPalette.cream,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SkulMateHomeTopBar(
                childId: widget.childId,
                activeSessionId: _sessionId,
                onSelectSession: (id) => unawaited(_openExisting(id)),
                onNewSession: () => unawaited(_startNew()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 20, 8),
                child: Row(
                  children: [
                    ValueListenableBuilder<TutorVoiceState>(
                      valueListenable: _voice.state,
                      builder: (_, state, __) => SkulMateHeroMascot(
                        state: _reaction ?? switch (state) {
                          TutorVoiceState.thinking =>
                            SkulMateMascotState.thinking,
                          TutorVoiceState.speaking =>
                            SkulMateMascotState.speaking,
                          TutorVoiceState.recording =>
                            SkulMateMascotState.listening,
                          TutorVoiceState.idle =>
                            SkulMateMascotState.neutral,
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'fr'
                            ? 'Ton espace pour apprendre' : 'Your learning desk',
                        style: SkulMateTypography.heroTitle(),
                      ),
                    ),
                    ValueListenableBuilder<TutorVoiceState>(
                      valueListenable: _voice.state,
                      builder: (_, state, __) =>
                          SkulMateVoicePill(state: state),
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
                        color: AppTheme.primaryColor,
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
                            onPressed: () => setState(() => _showTranscript = !_showTranscript),
                            icon: Icon(_showTranscript ? Icons.dashboard_outlined : Icons.history),
                            label: Text(Localizations.localeOf(context).languageCode == 'fr'
                              ? (_showTranscript ? 'Revenir à la leçon' : 'Voir la conversation')
                              : (_showTranscript ? 'Back to lesson' : 'View conversation')),
                          ),
                        ),
                      for (final turn in visibleTurns) ...[
                        TutorChatBubble.text(
                          isUser: turn.isUser,
                          text: turn.text,
                        ),
                        if (turn.board != null && turn.board!.steps.isNotEmpty)
                          SkulMateTutorBoard(board: turn.board!),
                        if (turn.surface != null)
                          SkulMateInThreadSurface(
                            surface: turn.surface!,
                            onOutcome: (correct) async {
                              _reactToAnswer(correct);
                              if (_sessionId == null) return;
                              await SkulMateTutorSessionService.recordOutcome(
                                sessionId: _sessionId!,
                                correct: correct,
                                childId: widget.childId,
                                turnId: turn.id,
                                conceptId: turn.surface?.conceptId,
                                surfaceType: turn.surface?.gameType,
                              );
                            },
                          ),
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
                        TutorChatBubble.text(
                          isUser: false,
                          text: copy.tutorThinking,
                        ),
                      if (_error != null) _buildConnectionNotice(copy),
                    ],
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.tutorStartTitle,
          style: SkulMateTypography.heroTitle().copyWith(fontSize: 25),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Text(
            copy.tutorStartBody,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textMedium,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
        if (_learningTrackLabel case final track?) ...[
          const SizedBox(height: 18),
          _LearnerContextLine(
            title: copy.tutorContextTitle,
            detail: track,
            footnote: copy.tutorContextReady,
          ),
        ],
        const SizedBox(height: 22),
        Text(
          copy.tutorStartChoices,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textDark,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 2 : 1;
            const gap = 9.0;
            final cardWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _StudyAction(
                    icon: PhosphorIcons.lightbulb,
                    title: copy.tutorActionExplainTitle,
                    subtitle: copy.tutorActionExplainBody,
                    onTap: () => unawaited(
                      _sendText(_starterMessage(copy, 'explain')),
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _StudyAction(
                    icon: PhosphorIcons.notePencil,
                    title: copy.tutorActionQuestionTitle,
                    subtitle: copy.tutorActionQuestionBody,
                    onTap: () => unawaited(
                      _sendText(_starterMessage(copy, 'question')),
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _StudyAction(
                    icon: PhosphorIcons.lightning,
                    title: copy.tutorActionPracticeTitle,
                    subtitle: copy.tutorActionPracticeBody,
                    onTap: () => unawaited(
                      _sendText(_starterMessage(copy, 'practice')),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _busy
              ? null
              : () => safeSetState(() => _attachOpen = !_attachOpen),
          icon: const Icon(PhosphorIcons.paperclip, size: 18),
          label: Text(copy.tutorActionMaterial),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            textStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
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
                  style: GoogleFonts.plusJakartaSans(
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

class _StudyAction extends StatelessWidget {
  const _StudyAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.skyBlueLight.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.09),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textMedium,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                PhosphorIcons.arrowUpRight,
                size: 17,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearnerContextLine extends StatelessWidget {
  const _LearnerContextLine({
    required this.title,
    required this.detail,
    required this.footnote,
  });

  final String title;
  final String detail;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIcons.sparkle, size: 19, color: AppTheme.skyBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  footnote,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 11,
                    height: 1.3,
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
      labelStyle: GoogleFonts.plusJakartaSans(
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
