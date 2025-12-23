import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_model.dart';

/// Card widget for displaying a game in the library
class GameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const GameCard({
    Key? key,
    required this.game,
    required this.onTap,
    this.onDelete,
  }) : super(key: key);

  IconData get _gameIcon {
    switch (game.gameType) {
      case GameType.quiz:
        return Icons.quiz;
      case GameType.flashcards:
        return Icons.style;
      case GameType.matching:
        return Icons.compare_arrows;
      case GameType.fillBlank:
        return Icons.edit;
    }
  }

  String get _gameTypeLabel {
    switch (game.gameType) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards';
      case GameType.matching:
        return 'Matching';
      case GameType.fillBlank:
        return 'Fill in Blank';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Game icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _gameIcon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _gameTypeLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${game.items.length} items',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(game.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

