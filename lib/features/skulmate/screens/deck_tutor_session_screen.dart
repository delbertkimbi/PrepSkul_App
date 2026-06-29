import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../../discovery/screens/find_tutors_screen.dart';
import '../l10n/skulmate_copy.dart';
import '../models/revision_deck_model.dart';
import '../services/skulmate_session_history_service.dart';
import '../services/skulmate_study_audio_service.dart';
import '../services/skulmate_service.dart';
import '../services/tutor_escalation_service.dart';
import '../widgets/deck_term_highlight_text.dart';
import '../widgets/skulmate_study_audio_controls.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../widgets/tutor_chat_bubble.dart';
import '../widgets/tutor_speech_highlight_text.dart';

enum _TutorPhase { explanation, quiz }

enum _ExplainTone { normal, eli5, detailed }

class _TutorMessage {
  final String id;
  final bool isUser;
  final String text;

  const _TutorMessage({
    required this.id,
    required this.isUser,
    required this.text,
  });
}

/// Gizmo-style AI tutor: explain → chat → quick quiz per card.
class DeckTutorSessionScreen extends StatefulWidget {
  final RevisionDeckModel deck;
  final String gameId;
  final String? childId;
  final int initialCardIndex;

  const DeckTutorSessionScreen({
    super.key,
    required this.deck,
    required this.gameId,
    this.childId,
    this.initialCardIndex = 0,
  });

  @override
  State<DeckTutorSessionScreen> createState() => _DeckTutorSessionScreenState();
}

class _DeckTutorSessionScreenState extends State<DeckTutorSessionScreen> {
  static const _headerPurple = AppTheme.accentPurple;

  late final List<RevisionDeckCard> _cards;
  late int _cardIndex;
  _TutorPhase _phase = _TutorPhase.explanation;

  bool _loadingExplanation = true;
  String? _explainError;
  _ExplainTone _tone = _ExplainTone.normal;
  final List<_TutorMessage> _messages = [];
  int _messageSeq = 0;

  final _chatController = TextEditingController();
  final _chatFocus = FocusNode();
  bool _chatOpen = false;

  String? _speakingMessageId;
  int _highlightStart = -1;
  int _highlightEnd = -1;

  String? _selectedOption;
  bool _quizRevealed = false;
  bool _showHint = false;

  final _audio = SkulMateStudyAudioService.instance;
  int _followUpCount = 0;
  bool _showTutorEscalation = false;
  bool _escalationChecked = false;

  @override
  void initState() {
    super.initState();
    _cards = widget.deck.cards.isNotEmpty
        ? widget.deck.cards
        : _syntheticCardsFromNotes();
    _cardIndex = widget.initialCardIndex.clamp(0, _cards.isEmpty ? 0 : _cards.length - 1);
    _chatController.addListener(_onChatDraftChanged);
    _bootstrapSession();
    _loadExplanation();
  }

  void _onChatDraftChanged() {
    if (_chatOpen) safeSetState(() {});
  }

  Future<void> _bootstrapSession() async {
    final count = await SkulMateSessionHistoryService.tutorFollowUpCount(
      widget.gameId,
    );
    await _audio.acquireStudyAmbience(SkulMateStudyAudioOwner.tutorSession);
    if (!mounted) return;
    safeSetState(() => _followUpCount = count);
  }

  @override
  void dispose() {
    _chatController.removeListener(_onChatDraftChanged);
    _chatController.dispose();
    _chatFocus.dispose();
    unawaited(_audio.stopSpeaking());
    _audio.releaseStudyAmbience(SkulMateStudyAudioOwner.tutorSession);
    super.dispose();
  }

  List<RevisionDeckCard> _syntheticCardsFromNotes() {
    final notes = widget.deck.notes.trim();
    if (notes.isEmpty) return const [];
    return [
      RevisionDeckCard(
        id: 'notes-1',
        knowledgeUnitId: 'core',
        cardType: RevisionDeckCardType.termDef,
        prompt: widget.deck.topicLabel,
        answer: notes,
        sourceQuote: notes.length > 180 ? '${notes.substring(0, 180)}…' : notes,
      ),
    ];
  }

  RevisionDeckCard get _card => _cards[_cardIndex];

  double get _progress =>
      (_cardIndex + (_phase == _TutorPhase.quiz ? 0.5 : 0)) / _cards.length;

  String _nextMessageId() => 'm${_messageSeq++}';

  void _appendMessage({required bool isUser, required String text}) {
    if (text.trim().isEmpty) return;
    _messages.add(
      _TutorMessage(
        id: _nextMessageId(),
        isUser: isUser,
        text: text.trim(),
      ),
    );
  }

  Future<void> _speakMessage(String messageId, String text) async {
    if (text.trim().isEmpty) return;
    safeSetState(() {
      _speakingMessageId = messageId;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    await _audio.speakExplanation(
      text,
      onProgress: (start, end) {
        if (!mounted || _speakingMessageId != messageId) return;
        safeSetState(() {
          _highlightStart = start;
          _highlightEnd = end;
        });
      },
      onComplete: () {
        if (!mounted || _speakingMessageId != messageId) return;
        safeSetState(() {
          _speakingMessageId = null;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      },
    );
  }

  Future<void> _loadExplanation({
    _ExplainTone? tone,
    String? followUpQuestion,
  }) async {
    final useTone = tone ?? _tone;
    safeSetState(() {
      _loadingExplanation = true;
      _explainError = null;
      if (tone != null) _tone = useTone;
    });

    try {
      final definition = _definitionForTone(_card.answer, useTone, followUpQuestion);
      final result = await SkulMateService.explainFlashcard(
        term: _card.prompt,
        definition: definition,
        gameId: widget.gameId,
        childId: widget.childId,
        activeDeckTitle: widget.deck.title,
        deckStudyMode: 'tutor',
      );
      if (!mounted) return;

      final explanation = result.explanation.trim();
      _TutorMessage? assistantMessage;
      safeSetState(() {
        _loadingExplanation = false;
        if (explanation.isNotEmpty) {
          assistantMessage = _TutorMessage(
            id: _nextMessageId(),
            isUser: false,
            text: explanation,
          );
          _messages.add(assistantMessage!);
        }
      });

      if (followUpQuestion != null && followUpQuestion.trim().isNotEmpty) {
        await SkulMateSessionHistoryService.recordTutorFollowUp(
          gameId: widget.gameId,
          topicLabel: _card.prompt,
        );
        final count = await SkulMateSessionHistoryService.tutorFollowUpCount(
          widget.gameId,
        );
        if (!mounted) return;
        safeSetState(() => _followUpCount = count);
        await _maybeShowTutorEscalation();
      }

      if (assistantMessage != null) {
        await _speakMessage(assistantMessage!.id, assistantMessage!.text);
      }
    } catch (e) {
      if (!mounted) return;
      safeSetState(() {
        _explainError = e.toString().replaceFirst('Exception: ', '');
        _loadingExplanation = false;
      });
    }
  }

  Future<void> _requestTone(_ExplainTone tone, String userLabel) async {
    if (_loadingExplanation) return;
    safeSetState(() => _appendMessage(isUser: true, text: userLabel));
    await _loadExplanation(tone: tone);
  }

  Future<void> _maybeShowTutorEscalation() async {
    if (_escalationChecked || _showTutorEscalation) return;
    final shouldOffer = await TutorEscalationService.shouldOfferDuringTutorStudy(
      gameId: widget.gameId,
      followUpCount: _followUpCount,
      childId: widget.childId,
    );
    if (!mounted || !shouldOffer) return;
    await TutorEscalationService.markOffered(widget.gameId);
    safeSetState(() {
      _showTutorEscalation = true;
      _escalationChecked = true;
    });
  }

  Future<void> _onBrowseTutors() async {
    await TutorEscalationService.markOffered(widget.gameId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FindTutorsScreen()),
    );
  }

  Future<void> _dismissTutorEscalation() async {
    await TutorEscalationService.dismissForGame(widget.gameId);
    if (!mounted) return;
    safeSetState(() => _showTutorEscalation = false);
  }

  String _definitionForTone(
    String answer,
    _ExplainTone tone,
    String? followUp,
  ) {
    final buffer = StringBuffer(answer);
    switch (tone) {
      case _ExplainTone.eli5:
        buffer.write(
          '\n\nExplain like I am 5 years old. Use very simple words and a short analogy.',
        );
        break;
      case _ExplainTone.detailed:
        buffer.write(
          '\n\nGive a more detailed explanation with examples and deeper context.',
        );
        break;
      case _ExplainTone.normal:
        break;
    }
    if (followUp != null && followUp.trim().isNotEmpty) {
      buffer.write('\n\nStudent follow-up question: ${followUp.trim()}');
    }
    return buffer.toString();
  }

  List<String> get _quizOptions {
    final options = _card.mcqOptions;
    if (options.length >= 2) return options;

    final pool = <String>{_card.answer};
    for (final other in _cards) {
      if (other.id == _card.id) continue;
      if (other.answer.isNotEmpty) pool.add(other.answer);
    }
    pool.add('Not sure yet');
    pool.add('Something else');
    final list = pool.toList()..shuffle();
    return list.take(4).toList();
  }

  void _onUnderstand() {
    unawaited(_audio.stopSpeaking());
    safeSetState(() {
      _phase = _TutorPhase.quiz;
      _selectedOption = null;
      _quizRevealed = false;
      _showHint = false;
      _chatOpen = false;
    });
  }

  void _submitQuiz() {
    if (_selectedOption == null || _quizRevealed) return;
    safeSetState(() => _quizRevealed = true);
  }

  void _continueAfterQuiz() {
    if (_cardIndex + 1 >= _cards.length) {
      Navigator.pop(context, true);
      return;
    }
    unawaited(_audio.stopSpeaking());
    safeSetState(() {
      _cardIndex++;
      _phase = _TutorPhase.explanation;
      _messages.clear();
      _selectedOption = null;
      _quizRevealed = false;
      _showHint = false;
      _chatOpen = false;
      _tone = _ExplainTone.normal;
      _speakingMessageId = null;
      _highlightStart = -1;
      _highlightEnd = -1;
      _chatController.clear();
    });
    _loadExplanation();
  }

  void _backToExplanation() {
    safeSetState(() {
      _phase = _TutorPhase.explanation;
      _selectedOption = null;
      _quizRevealed = false;
      _showHint = false;
    });
  }

  void _openChat() {
    safeSetState(() => _chatOpen = true);
    _chatFocus.requestFocus();
  }

  void _closeChat() {
    _chatFocus.unfocus();
    safeSetState(() {
      _chatOpen = false;
      _chatController.clear();
    });
  }

  Future<void> _sendChat() async {
    final question = _chatController.text.trim();
    if (question.isEmpty || _loadingExplanation) return;
    safeSetState(() {
      _appendMessage(isUser: true, text: question);
      _chatController.clear();
    });
    await _loadExplanation(followUpQuestion: question);
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('This deck has no study cards yet.')),
      );
    }

    return Scaffold(
      backgroundColor: _headerPurple,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: _phase == _TutorPhase.explanation
                    ? _buildExplanationBody()
                    : _buildQuizBody(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const SkulMateStudyAudioControls(onDark: true),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.04, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  'Card ${_cardIndex + 1} / ${_cards.length}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.deck.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_TutorMessage message) {
    final isSpeaking = _speakingMessageId == message.id && !message.isUser;
    return TutorChatBubble(
      isUser: message.isUser,
      child: isSpeaking
          ? TutorSpeechHighlightText(
              text: message.text,
              highlightStart: _highlightStart,
              highlightEnd: _highlightEnd,
            )
          : Text(
              message.text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textDark,
              ),
            ),
    );
  }

  Widget _buildExplanationBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        Row(
          children: [
            Icon(Icons.layers_rounded, size: 18, color: AppTheme.textMedium),
            const SizedBox(width: 6),
            Text(
              'Card ${_cardIndex + 1} / ${_cards.length}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppTheme.textMedium,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if ((_card.sourceQuote ?? '').trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.neutral200),
            ),
            child: DeckTermHighlightText(
              text: _card.sourceQuote!.trim(),
              highlight: _card.prompt,
            ),
          ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.neutral100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _card.prompt,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  height: 1.35,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              Text(
                _card.answer,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_messages.isNotEmpty) ...[
          ..._messages.map(_buildMessageBubble),
        ],
        if (_loadingExplanation)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_explainError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _explainError!,
              style: GoogleFonts.plusJakartaSans(color: Colors.red.shade700),
            ),
          ),
        if (_showTutorEscalation) ...[
          const SizedBox(height: 8),
          _TutorEscalationBanner(
            topicLabel: _card.prompt,
            onBrowse: _onBrowseTutors,
            onDismiss: _dismissTutorEscalation,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loadingExplanation
                    ? null
                    : () => _requestTone(
                          _ExplainTone.eli5,
                          '👶 Explain like I\'m 5',
                        ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textDark,
                  side: BorderSide(color: AppTheme.neutral200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('👶 Explain like I\'m 5'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _loadingExplanation
                    ? null
                    : () => _requestTone(
                          _ExplainTone.detailed,
                          '🔭 More detail',
                        ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textDark,
                  side: BorderSide(color: AppTheme.neutral200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('🔭 More detail'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizBody() {
    final options = _quizOptions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      children: [
        OutlinedButton.icon(
          onPressed: _backToExplanation,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to explanation'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textDark,
            side: BorderSide(color: AppTheme.neutral200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _quizQuestionForCard(_card),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        ...options.map((option) {
          final isSelected = _selectedOption == option;
          final isAnswer =
              option.trim().toLowerCase() == _card.answer.trim().toLowerCase();
          Color border = AppTheme.neutral200;
          Color fill = Colors.white;
          if (_quizRevealed && isAnswer) {
            border = AppTheme.accentGreen;
            fill = AppTheme.accentGreen.withValues(alpha: 0.08);
          } else if (_quizRevealed && isSelected && !isAnswer) {
            border = Colors.red;
            fill = Colors.red.withValues(alpha: 0.08);
          } else if (isSelected) {
            border = _headerPurple;
            fill = _headerPurple.withValues(alpha: 0.06);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _quizRevealed
                  ? null
                  : () => safeSetState(() => _selectedOption = option),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ),
          );
        }),
        if (_showHint && (_card.explanation ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _card.explanation!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => safeSetState(() => _showHint = true),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('Hint'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textDark,
                  side: BorderSide(color: AppTheme.neutral200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => safeSetState(() {
                  _selectedOption = _card.answer;
                  _quizRevealed = true;
                }),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Reveal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textDark,
                  side: BorderSide(color: AppTheme.neutral200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loadingExplanation ? null : _backToExplanation,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Explain'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _headerPurple,
            side: BorderSide(color: _headerPurple.withValues(alpha: 0.35)),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final isQuiz = _phase == _TutorPhase.quiz;
    final hasDraft = _chatController.text.trim().isNotEmpty;
    final showChatInput = !isQuiz && _chatOpen;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: showChatInput
                    ? TextField(
                        key: const ValueKey('chat_field'),
                        controller: _chatController,
                        focusNode: _chatFocus,
                        onSubmitted: (_) => _sendChat(),
                        decoration: InputDecoration(
                          hintText: 'Ask a follow-up question…',
                          filled: true,
                          fillColor: AppTheme.neutral100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: _headerPurple.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        key: const ValueKey('primary_cta'),
                        onPressed: isQuiz
                            ? (_quizRevealed
                                ? _continueAfterQuiz
                                : (_selectedOption == null ? null : _submitQuiz))
                            : (_loadingExplanation && _messages.isEmpty
                                ? null
                                : _onUnderstand),
                        icon: Icon(
                          isQuiz
                              ? Icons.arrow_forward_rounded
                              : Icons.check_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          isQuiz
                              ? (_quizRevealed
                                  ? (_cardIndex + 1 >= _cards.length
                                      ? 'Finish'
                                      : 'Continue')
                                  : 'Check answer')
                              : 'Ok, I understand',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: SkulMateSurfaceStyles.deckPrimaryButton(
                          minHeight: 54,
                        ),
                      ),
              ),
            ),
            if (!isQuiz) ...[
              const SizedBox(width: 10),
              Material(
                color: AppTheme.neutral100,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: showChatInput
                      ? (hasDraft ? _sendChat : _closeChat)
                      : _openChat,
                  icon: Icon(
                    showChatInput
                        ? (hasDraft
                            ? Icons.send_rounded
                            : Icons.close_rounded)
                        : Icons.chat_bubble_outline_rounded,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _quizQuestionForCard(RevisionDeckCard card) {
    switch (card.cardType) {
      case RevisionDeckCardType.termDef:
        return 'What does this mean?\n\n${card.prompt}';
      case RevisionDeckCardType.mcq:
        return card.prompt;
      case RevisionDeckCardType.cloze:
        return card.prompt;
      default:
        return card.prompt;
    }
  }
}

class _TutorEscalationBanner extends StatelessWidget {
  final String topicLabel;
  final VoidCallback onBrowse;
  final VoidCallback onDismiss;

  const _TutorEscalationBanner({
    required this.topicLabel,
    required this.onBrowse,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentPurple.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.tutorEscalationTitle,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.tutorEscalationBody(topicLabel),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onBrowse,
                  style: SkulMateSurfaceStyles.deckPrimaryButton(minHeight: 44),
                  child: Text(
                    copy.tutorEscalationAction,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onDismiss,
                child: Text(copy.tutorEscalationDismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
