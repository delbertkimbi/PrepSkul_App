import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';
import 'package:prepskul/features/messaging/widgets/message_icon_badge.dart';
import 'package:prepskul/features/notifications/widgets/notification_bell.dart';

/// Time-based greeting row for parent/learner home (Preply-style top bar).
class HomeGreetingHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final int refreshKey;

  const HomeGreetingHeader({
    super.key,
    required this.greeting,
    required this.userName,
    this.refreshKey = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.responsiveBodySize(context),
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: ResponsiveHelper.isSmallHeight(context) ? 2 : 4),
              Text(
                userName,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.responsiveHeadingSize(context) + 6,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const MessageIconBadge(iconColor: Colors.white),
        SizedBox(width: ResponsiveHelper.responsiveSpacing(context, mobile: 8, tablet: 12, desktop: 16)),
        NotificationBell(key: ValueKey('bell_$refreshKey'), iconColor: Colors.white),
      ],
    );
  }
}
