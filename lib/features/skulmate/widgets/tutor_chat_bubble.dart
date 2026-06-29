import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Gizmo-soft chat bubble for the AI tutor thread.
class TutorChatBubble extends StatelessWidget {
  final bool isUser;
  final Widget child;
  final double maxWidthFactor;

  const TutorChatBubble({
    super.key,
    required this.isUser,
    required this.child,
    this.maxWidthFactor = 0.82,
  });

  factory TutorChatBubble.text({
    required bool isUser,
    required String text,
    double maxWidthFactor = 0.82,
  }) {
    return TutorChatBubble(
      isUser: isUser,
      maxWidthFactor: maxWidthFactor,
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          height: 1.45,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * maxWidthFactor,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.accentPurple.withValues(alpha: 0.12)
              : AppTheme.neutral100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}
