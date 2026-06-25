import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Expandable session details section (Preply progressive disclosure).
class CollapsibleSessionDetails extends StatefulWidget {
  final List<Widget> children;

  const CollapsibleSessionDetails({
    super.key,
    required this.children,
  });

  @override
  State<CollapsibleSessionDetails> createState() => _CollapsibleSessionDetailsState();
}

class _CollapsibleSessionDetailsState extends State<CollapsibleSessionDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    'Session details',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? PhosphorIcons.caretUp : PhosphorIcons.caretDown,
                    size: 18,
                    color: AppTheme.textMedium,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: AppTheme.softBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
