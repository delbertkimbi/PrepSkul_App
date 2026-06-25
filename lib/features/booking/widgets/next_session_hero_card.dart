import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/models/upcoming_session_item.dart';
import 'package:prepskul/features/booking/utils/session_live_utils.dart';

enum NextSessionHeroVariant { home, detail }

/// Preply-style hero for the next upcoming lesson.
class NextSessionHeroCard extends StatelessWidget {
  final UpcomingSessionItem? session;
  final NextSessionHeroVariant variant;
  final VoidCallback? onPrimaryAction;
  final String? primaryActionLabel;
  final VoidCallback? onFindTutors;
  final Widget? footerSlot;

  const NextSessionHeroCard({
    super.key,
    required this.session,
    this.variant = NextSessionHeroVariant.home,
    this.onPrimaryAction,
    this.primaryActionLabel,
    this.onFindTutors,
    this.footerSlot,
  });

  String _formatDateTime(DateTime dt) {
    return DateFormat('EEEE, MMM d \'at\' HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No upcoming sessions',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Book a tutor to get your next lesson on the calendar.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textMedium, height: 1.4),
            ),
            if (onFindTutors != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onFindTutors,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Find tutors',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final s = session!;
    final isLive = SessionLiveUtils.showsLiveUi(s.sessionMap);
    final isOnsite = s.location != 'online';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.92),
            AppTheme.primaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: variant == NextSessionHeroVariant.detail ? 32 : 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: s.tutorAvatarUrl != null && s.tutorAvatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(s.tutorAvatarUrl!)
                    : null,
                child: s.tutorAvatarUrl == null || s.tutorAvatarUrl!.isEmpty
                    ? Text(
                        s.tutorName.isNotEmpty ? s.tutorName[0].toUpperCase() : 'T',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (variant == NextSessionHeroVariant.home)
                      Text(
                        s.isTrial ? 'Next trial' : 'Next lesson',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    Text(
                      _formatDateTime(s.scheduledStart),
                      style: GoogleFonts.poppins(
                        fontSize: variant == NextSessionHeroVariant.detail ? 18 : 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.subject} with ${s.tutorName}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip(
                          SessionLiveUtils.displayStatusBadge(s.sessionMap),
                          highlight: isLive,
                        ),
                        if (isOnsite)
                          _chip('On-site')
                        else
                          _chip('Online'),
                        if (s.isTrial) _chip('Trial'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (footerSlot != null) ...[
            const SizedBox(height: 14),
            footerSlot!,
          ] else if (onPrimaryAction != null && primaryActionLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOnsite ? PhosphorIcons.mapPin : PhosphorIcons.videoCamera,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      primaryActionLabel!,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.accentGreen.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
