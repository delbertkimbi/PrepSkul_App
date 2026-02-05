import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Credits Balance Widget
///
/// Displays current points balance and session count
/// New system: 10 points per session
/// Example: 89 points = 8 sessions (80 points) + 9 extra points
/// A session requires 10 points
class CreditsBalanceWidget extends StatelessWidget {
  final int currentCredits; // Actually points in new system
  final bool isLoading;
  final int? sessionsRemaining; // Optional: if provided, will use this value. Otherwise calculates from points.

  const CreditsBalanceWidget({
    Key? key,
    required this.currentCredits,
    this.isLoading = false,
    this.sessionsRemaining,
  }) : super(key: key);

  /// Calculate sessions from points
  /// New system: 10 points per session
  /// Formula: points / 10 (rounded down)
  int _calculateSessionsFromPoints() {
    if (currentCredits <= 0) return 0;
    // 10 points per session
    return (currentCredits / 10).floor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Balance',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const SizedBox(
              height: 32,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$currentCredits',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'points',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                if (sessionsRemaining != null || currentCredits > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    sessionsRemaining != null
                        ? '$sessionsRemaining sessions available'
                        : '${_calculateSessionsFromPoints()} sessions available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}