import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../services/game_rules_service.dart';
import '../models/game_model.dart';
import 'game_standard_widgets.dart';

/// Overlay widget showing game rules for first-time players
class GameRulesOverlay extends StatefulWidget {
  final GameType gameType;
  final VoidCallback onGotIt;

  const GameRulesOverlay({
    Key? key,
    required this.gameType,
    required this.onGotIt,
  }) : super(key: key);

  /// Show rules overlay if user hasn't seen them before
  /// Returns `true` when the dialog was shown (first time), otherwise `false`.
  static Future<bool> showIfNeeded(
    BuildContext context,
    GameType gameType,
    Future<void> Function(bool isFirstTime) onContinue, {
    Future<void> Function()? onAfterFirstTimeDialogClosed,
  }) async {
    final hasSeen = await GameRulesService.hasSeenRules(gameType);
    if (!hasSeen) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => GameRulesOverlay(
          gameType: gameType,
          onGotIt: () async {
            await GameRulesService.markRulesSeen(gameType);
            Navigator.pop(context);

            // Ensure the dialog is fully dismissed before showing any bottom sheet.
            await Future.delayed(Duration.zero);

            if (onAfterFirstTimeDialogClosed != null) {
              await onAfterFirstTimeDialogClosed();
            }

            await onContinue(true);
          },
        ),
      );
      return true;
    } else {
      await onContinue(false);
      return false;
    }
  }

  @override
  State<GameRulesOverlay> createState() => _GameRulesOverlayState();
}

class _GameRulesOverlayState extends State<GameRulesOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rules = GameRulesService.getRulesForGameType(widget.gameType);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.softBackground.withOpacity(0.72),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            rules.title,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Description
                    Text(
                      rules.description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Steps
                    Text(
                      'How to play:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...rules.steps.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppTheme.textDark,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    // Got it button
                    SizedBox(
                      width: double.infinity,
                      child: GameStandardsPrimaryButton(
                        label: 'Got it!',
                        onPressed: widget.onGotIt,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
