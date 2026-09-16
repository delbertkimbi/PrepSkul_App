import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prepskul/core/theme/app_theme.dart';
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
import '../widgets/skulmate_home_top_bar.dart';
import '../widgets/skulmate_in_thread_surface.dart';
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
  bool _busy = false;
  bool _attachOpen = false;
  bool _recording = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SkulMateHomeRefreshBus.tick.addListener(_onRefresh);
    SkulMateTutorIntakeBus.pending.addListener(_onIntake);
    _applyStatusBarStyle();
    unawaited(_voice.prepare());
    unawaited(_bootstrap());
    SkulMateStreakReminderService.recordActivityAndReschedule();
  }

  @override
  void dispose() {
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
      if (mounted) safeSetState(() => _error = e.toString());
    }
  }

  Future<void> _startNew() async {
    try {
      safeSetState(() {
        _busy = true;
        _error = null;
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
          _error = e.toString().replaceFirst('Exception: ', '');
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
          _error = e.toString().replaceFirst('Exception: ', '');
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
      _busy = false;
      _turns
        ..clear()
        ..addAll(parsedRemote.isNotEmpty ? parsedRemote : cached);
    });
    await SkulMateSessionCache.saveTurns(sessionId: id, turns: _turns);
    _scrollSoon();
  }

  Future<void> _sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    final sessionId = _sessionId;
    if (sessionId == null) await _bootstrap();
    final id = _sessionId;
    if (id == null) return;

    _composer.clear();
    final userTurn = TutorTurn(isUser: true, text: text);
    safeSetState(() {
      _turns.add(userTurn);
      _busy = true;
      _error = null;
      _attachOpen = false;
    });
    await SkulMateSessionCache.appendTurn(sessionId: id, turn: userTurn);
    _voice.setThinking();
    _scrollSoon();

    try {
      final result = await SkulMateTutorSessionService.sendTurn(
        sessionId: id,
        message: text,
        childId: widget.childId,
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
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      await _voice.interrupt();
    }
  }

  Future<void> _ingest(SkulMateIntakePayload payload) async {
    final sessionId = _sessionId;
    if (sessionId == null) await _bootstrap();
    final id = _sessionId;
    if (id == null) return;
    safeSetState(() => _busy = true);
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
              text: payload.title ?? payload.topicHint ?? payload.text ?? 'Notes',
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
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _speakThenListen(String text) async {
    await _voice.speakTutor(text);
    if (!mounted) return;
    final ok = await _voice.startListening();
    if (mounted) safeSetState(() => _recording = ok);
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

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SkulMateSurfaceStyles.lightStatusBarOverlay,
      child: Scaffold(
        backgroundColor: AppTheme.softBackground,
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.heroQuestion,
                        style: SkulMateTypography.heroTitle(),
                      ),
                    ),
                    ValueListenableBuilder<TutorVoiceState>(
                      valueListenable: _voice.state,
                      builder: (_, state, __) =>
                          SkulMateVoicePill(state: state),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (_turns.isEmpty)
                      TutorChatBubble.text(
                        isUser: false,
                        text: copy.tutorEmptyPrompt,
                      ),
                    for (final turn in _turns) ...[
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
                    ],
                    if (_busy)
                      TutorChatBubble.text(
                        isUser: false,
                        text: copy.tutorThinking,
                      ),
                    if (_error != null)
                      TutorChatBubble.text(isUser: false, text: _error!),
                  ],
                ),
              ),
              SkulMateTutorComposer(
                controller: _composer,
                onSend: () => _sendText(_composer.text),
                onHoldStart: () => unawaited(_holdStart()),
                onHoldEnd: () => unawaited(_holdEnd()),
                busy: _busy,
                recording: _recording,
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
}
