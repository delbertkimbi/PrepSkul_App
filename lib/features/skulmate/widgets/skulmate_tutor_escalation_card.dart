import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/discovery/screens/find_tutors_screen.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../services/tutor_escalation_service.dart';
import 'skulmate_surface_styles.dart';

/// Optional tutor card on results — only when [TutorEscalationService] allows.
class SkulMateTutorEscalationCard extends StatefulWidget {
  final GameModel game;
  final int score;
  final int totalQuestions;

  const SkulMateTutorEscalationCard({
    super.key,
    required this.game,
    required this.score,
    required this.totalQuestions,
  });

  @override
  State<SkulMateTutorEscalationCard> createState() =>
      _SkulMateTutorEscalationCardState();
}

class _SkulMateTutorEscalationCardState extends State<SkulMateTutorEscalationCard> {
  bool? _shouldShow;
  bool _hidden = false;
  bool _markedOffer = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    final offer = await TutorEscalationService.shouldOfferForSession(
      gameId: widget.game.id,
      correctAnswers: widget.score,
      totalQuestions: widget.totalQuestions,
      childId: widget.game.childId,
    );
    if (mounted) setState(() => _shouldShow = offer);
  }

  Future<void> _dismiss() async {
    await TutorEscalationService.dismissForGame(widget.game.id);
    if (mounted) setState(() => _hidden = true);
  }

  void _openFindTutors() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FindTutorsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden || _shouldShow != true) return const SizedBox.shrink();

    if (!_markedOffer) {
      _markedOffer = true;
      TutorEscalationService.markOffered(widget.game.id);
    }

    final copy = SkulMateCopy.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.support_agent_outlined,
                size: 20,
                color: AppTheme.primaryColor.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.tutorEscalationTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.tutorEscalationBody(widget.game.title),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.textMedium,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: copy.tutorEscalationDismiss,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openFindTutors,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                copy.tutorEscalationAction,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
