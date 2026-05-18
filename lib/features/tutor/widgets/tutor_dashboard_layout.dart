import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/responsive_helper.dart';

/// Section title for tutor dashboard tabs (desktop-friendly spacing).
class TutorZSection extends StatelessWidget {
  const TutorZSection({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveHelper.responsiveSpacing(
          context,
          mobile: 8,
          tablet: 12,
          desktop: 14,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.responsiveSubheadingSize(context),
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Alternating wide/narrow row on desktop (Z reading path); stacks on phone.
class TutorZRow extends StatelessWidget {
  const TutorZRow({
    super.key,
    required this.rowIndex,
    required this.primary,
    required this.secondary,
    this.gap,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
  });

  final int rowIndex;
  final Widget primary;
  final Widget secondary;
  final double? gap;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    final spacing = gap ??
        ResponsiveHelper.responsiveSpacing(
          context,
          mobile: 12,
          tablet: 16,
          desktop: 20,
        );
    if (!ResponsiveHelper.isDesktop(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          SizedBox(height: spacing),
          secondary,
        ],
      );
    }
    final flip = rowIndex.isOdd;
    final left = flip ? secondary : primary;
    final right = flip ? primary : secondary;
    final leftFlex = flip ? secondaryFlex : primaryFlex;
    final rightFlex = flip ? primaryFlex : secondaryFlex;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: leftFlex, child: left),
          SizedBox(width: spacing),
          Expanded(flex: rightFlex, child: right),
        ],
      ),
    );
  }
}

/// Caps card width and aligns within a Z row slot.
class TutorConstrainedCard extends StatelessWidget {
  const TutorConstrainedCard({
    super.key,
    required this.child,
    this.alignRight = false,
    this.maxWidth,
  });

  final Widget child;
  final bool alignRight;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? ResponsiveHelper.responsiveCardMaxWidth(context);
    final width = MediaQuery.sizeOf(context).width;
    final effective = cap == double.infinity ? width : cap.clamp(280.0, width);
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effective),
        child: child,
      ),
    );
  }
}

/// Two-column staggered grid for list cards on wide tutor tabs.
class TutorZCardGrid extends StatelessWidget {
  const TutorZCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ??
        ResponsiveHelper.responsiveSpacing(
          context,
          mobile: 12,
          tablet: 14,
          desktop: 16,
        );
    if (!ResponsiveHelper.isDesktop(context)) {
      return Column(
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) SizedBox(height: gap),
            itemBuilder(context, i),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = ResponsiveHelper.responsiveCardMaxWidth(context);
        final columnWidth = (constraints.maxWidth - gap) / 2;
        final cardW = columnWidth.clamp(280.0, maxW);
        final pad = max(0.0, (columnWidth - cardW) / 2);
        Widget cell(int index, {required bool rightColumn}) {
          if (index >= itemCount) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: EdgeInsets.only(
              left: rightColumn ? pad : 0,
              right: rightColumn ? 0 : pad,
            ),
            child: Align(
              alignment:
                  rightColumn ? Alignment.centerRight : Alignment.centerLeft,
              child: SizedBox(
                width: cardW,
                child: itemBuilder(context, index),
              ),
            ),
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < itemCount; i += 2) {
          if (i > 0) rows.add(SizedBox(height: gap));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cell(i, rightColumn: false)),
                SizedBox(width: gap),
                Expanded(child: cell(i + 1, rightColumn: true)),
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}
