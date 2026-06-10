import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/domain/onsite_session_phase.dart';

/// Compact one-line onsite status for session list cards (progressive disclosure).
class OnsitePresenceSummary extends StatelessWidget {
  final OnsiteSessionPhase phase;
  final String message;
  final VoidCallback? onTap;

  const OnsitePresenceSummary({
    super.key,
    required this.phase,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (phase) {
      OnsiteSessionPhase.upcoming => (
          Colors.grey.shade100,
          Colors.grey.shade700,
          Icons.schedule,
        ),
      OnsiteSessionPhase.readyToCheckIn => (
          AppTheme.primaryColor.withOpacity(0.1),
          AppTheme.primaryColor,
          Icons.location_searching,
        ),
      OnsiteSessionPhase.onSite => (
          AppTheme.accentGreen.withOpacity(0.12),
          AppTheme.accentGreen,
          Icons.check_circle_outline,
        ),
      OnsiteSessionPhase.done => (
          Colors.grey.shade100,
          Colors.grey.shade600,
          Icons.flag_outlined,
        ),
    };

    final child = Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, size: 20, color: fg),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}
