import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Non-interactive step chips: Check in, Check out, Admin approved.
class OnsitePresenceIndicators extends StatelessWidget {
  final bool checkInDone;
  final bool checkOutDone;
  final bool adminApproved;

  const OnsitePresenceIndicators({
    super.key,
    required this.checkInDone,
    required this.checkOutDone,
    required this.adminApproved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _step('Check in', checkInDone)),
            const SizedBox(width: 8),
            Expanded(child: _step('Check out', checkOutDone)),
          ],
        ),
        const SizedBox(height: 8),
        _step('Admin approved', adminApproved, fullWidth: true),
      ],
    );
  }

  Widget _step(String label, bool done, {bool fullWidth = false}) {
    final color = done ? AppTheme.primaryColor : AppTheme.neutral400;
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: done ? AppTheme.primaryColor.withOpacity(0.06) : AppTheme.neutral50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done ? AppTheme.primaryColor.withOpacity(0.25) : AppTheme.softBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.verified : Icons.radio_button_unchecked,
            size: 18,
            color: done ? Colors.blue : color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: done ? AppTheme.textDark : AppTheme.textMedium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
