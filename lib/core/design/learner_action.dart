import 'package:flutter/material.dart';
import 'learner_design.dart';

/// Keyboard-accessible paper-depth action shared by learner flows.
class LearnerAction extends StatelessWidget {
  const LearnerAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool compact;
  final bool secondary;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: secondary
                ? const Color(0xFFCCD5E2)
                : const Color(0xFF101D36),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? Colors.white : LearnerDesign.ink,
          foregroundColor: secondary ? LearnerDesign.ink : Colors.white,
          minimumSize: const Size(52, 52),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 18,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: secondary
                ? const BorderSide(color: LearnerDesign.line, width: 1.5)
                : BorderSide.none,
          ),
          textStyle: LearnerDesign.text(size: 16, weight: FontWeight.w800),
        ),
        child: compact
            ? Semantics(label: label, child: icon)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 9)],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    ),
  );
}
