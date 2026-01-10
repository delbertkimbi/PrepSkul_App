import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Credits Balance Widget
///
/// Displays current credits balance and estimated session count
/// Note: 1 credit = 100 XAF. Session costs vary by tutor.
/// Sessions are estimated based on average session cost (~3,500 XAF = 35 credits per session)
class CreditsBalanceWidget extends StatelessWidget {
  final int currentCredits;
  final bool isLoading;
  final int? sessionsRemaining; // Optional: if provided, will use this value. Otherwise calculates estimate.

  const CreditsBalanceWidget({
    Key? key,
    required this.currentCredits,
    this.isLoading = false,
    this.sessionsRemaining,
  }) : super(key: key);

  /// Calculate estimated sessions based on average session cost
  /// Average session cost: ~3,500 XAF = 35 credits per session
  /// Formula: credits / 35 (rounded down to show conservative estimate)
  int _calculateEstimatedSessions() {
    if (currentCredits <= 0) return 0;
    // Average session cost: 3,500 XAF = 35 credits
    // Round down to show conservative estimate
    return (currentCredits / 35).floor();
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
                      'credits',
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
                        ? '$sessionsRemaining sessions'
                        : '~${_calculateEstimatedSessions()} sessions (est.)',
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