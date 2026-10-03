import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Gizmo-soft chat bubble for the AI tutor thread.
class TutorChatBubble extends StatelessWidget {
  final bool isUser;
  final Widget child;
  final double maxWidthFactor;
  final bool flatMateResponse;

  const TutorChatBubble({
    super.key,
    required this.isUser,
    required this.child,
    this.maxWidthFactor = 0.82,
    this.flatMateResponse = false,
  });

  factory TutorChatBubble.text({
    required bool isUser,
    required String text,
    double maxWidthFactor = 0.82,
    bool flatMateResponse = true,
  }) {
    return TutorChatBubble(
      isUser: isUser,
      maxWidthFactor: maxWidthFactor,
      flatMateResponse: flatMateResponse,
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          height: 1.45,
          color: isUser ? AppTheme.primaryColor : AppTheme.textDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: isUser ? 16 : 12),
        padding: isUser && flatMateResponse
            ? const EdgeInsets.symmetric(horizontal: 15, vertical: 12)
            : flatMateResponse
                ? const EdgeInsets.symmetric(vertical: 3)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * maxWidthFactor,
        ),
        decoration: flatMateResponse
            ? (isUser
                ? BoxDecoration(
                    color: AppTheme.skyBlueLight,
                    borderRadius: BorderRadius.circular(18).copyWith(
                      bottomRight: const Radius.circular(5),
                    ),
                  )
                : null)
            : BoxDecoration(
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
