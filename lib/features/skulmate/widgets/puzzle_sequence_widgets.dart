import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

import '../l10n/skulmate_copy.dart';

/// Clean flat card for in-game surfaces (minimal lift).
class PuzzleNeoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accent;

  const PuzzleNeoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: (accent ?? AppTheme.softBorder).withValues(alpha: 0.95),
        ),
      ),
      child: child,
    );
  }
}

/// Frosted glass panel — use only on dark/colored backgrounds.
class PuzzleGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;

  const PuzzleGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.blur = 14,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tint ?? Colors.white).withValues(alpha: 0.82),
                (tint ?? Colors.white).withValues(alpha: 0.68),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Overflow-safe step progress: pill + bar (no fixed Row overflow).
class PuzzleStepProgress extends StatelessWidget {
  final int currentIndex;
  final int total;
  final int completedCount;

  const PuzzleStepProgress({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final progress = total > 0 ? (completedCount / total).clamp(0.0, 1.0) : 0.0;
    final stepNum = (currentIndex + 1).clamp(1, total > 0 ? total : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0A2A66).withValues(alpha: 0.12),
                    AppTheme.primaryColor.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.softBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_open_rounded,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    copy.puzzleChamberProgress(stepNum, total),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '$completedCount done',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppTheme.neutral200,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}

/// Horizontal quest trail: completed glow, current pulse, upcoming muted.
class PuzzleQuestTrail extends StatelessWidget {
  final int total;
  final int currentIndex;
  final int completedCount;

  const PuzzleQuestTrail({
    super.key,
    required this.total,
    required this.currentIndex,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    if (total > 8) {
      final copy = SkulMateCopy.of(context);
      final stepNum = (currentIndex + 1).clamp(1, total > 0 ? total : 1);
      final progress =
          total > 0 ? (completedCount / total).clamp(0.0, 1.0) : 0.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                copy.puzzleChamberProgress(stepNum, total),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '$completedCount done',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppTheme.neutral200,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
        final isDone = i < completedCount;
        final isCurrent = i == currentIndex && !isDone;
        final isLast = i == total - 1;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TrailNode(index: i, done: isDone, current: isCurrent),
            if (!isLast)
              Container(
                width: 18,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: isDone
                        ? [
                            AppTheme.accentGreen.withValues(alpha: 0.9),
                            AppTheme.skyBlue.withValues(alpha: 0.5),
                          ]
                        : [
                            AppTheme.neutral200,
                            AppTheme.neutral200,
                          ],
                  ),
                ),
              ),
          ],
        );
      }),
      ),
    );
  }
}

class _TrailNode extends StatelessWidget {
  final int index;
  final bool done;
  final bool current;

  const _TrailNode({
    required this.index,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final size = current ? 34.0 : 28.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done
            ? const LinearGradient(
                colors: [Color(0xFF34D399), AppTheme.accentGreen],
              )
            : current
                ? AppTheme.stitchSkyBlueGradient
                : null,
        color: done || current ? null : Colors.white.withValues(alpha: 0.7),
        border: Border.all(
          color: done
              ? AppTheme.accentGreen
              : current
                  ? AppTheme.skyBlue
                  : AppTheme.softBorder,
          width: current ? 2.5 : 1.5,
        ),
        boxShadow: current
            ? [
                BoxShadow(
                  color: AppTheme.skyBlue.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : done
                ? [
                    BoxShadow(
                      color: AppTheme.accentGreen.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ]
                : null,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text(
                '${index + 1}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: current ? 13 : 11,
                  fontWeight: FontWeight.w800,
                  color: current ? Colors.white : AppTheme.textMedium,
                ),
              ),
      ),
    );
  }
}

/// Gizmo-style step header — clear objective, no images.
class PuzzleStepFocusCard extends StatelessWidget {
  final int stepNumber;
  final int total;
  final String prompt;
  final String stepKindLabel;
  final Color accent;

  const PuzzleStepFocusCard({
    super.key,
    required this.stepNumber,
    required this.total,
    required this.prompt,
    required this.stepKindLabel,
    this.accent = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  copy.puzzleChamberProgress(stepNumber, total),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stepKindLabel.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prompt,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Text-only slot matching — tap label, then tap slot (no diagram).
class PuzzleSlotMatchBoard extends StatelessWidget {
  final List<({String id, String? hint})> slots;
  final List<({String id, String text})> labels;
  final Map<String, String> filledSlots;
  final String? selectedLabelId;
  final String? flashWrongId;
  final void Function(String labelId) onLabelTap;
  final void Function(String slotId) onSlotTap;
  final bool disabled;

  const PuzzleSlotMatchBoard({
    super.key,
    required this.slots,
    required this.labels,
    required this.filledSlots,
    this.selectedLabelId,
    this.flashWrongId,
    required this.onLabelTap,
    required this.onSlotTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final pending =
        labels.where((l) => !filledSlots.containsValue(l.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          copy.puzzleTapLabelThenSlot,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 12),
        ...slots.asMap().entries.map((entry) {
          final i = entry.key;
          final slot = entry.value;
          final filledLabelId = filledSlots[slot.id];
          String? filledText;
          if (filledLabelId != null) {
            for (final l in labels) {
              if (l.id == filledLabelId) {
                filledText = l.text;
                break;
              }
            }
          }
          final isTarget =
              selectedLabelId != null && filledLabelId == null && !disabled;
          return Padding(
            padding: EdgeInsets.only(bottom: i < slots.length - 1 ? 8 : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: disabled || filledLabelId != null
                    ? null
                    : () => onSlotTap(slot.id),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: filledText != null
                        ? AppTheme.accentGreen.withValues(alpha: 0.12)
                        : isTarget
                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: filledText != null
                          ? AppTheme.accentGreen.withValues(alpha: 0.5)
                          : isTarget
                              ? AppTheme.primaryColor
                              : AppTheme.softBorder,
                      width: isTarget ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: filledText != null
                              ? AppTheme.accentGreen
                              : AppTheme.neutral200,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: filledText != null
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          filledText ??
                              (slot.hint?.isNotEmpty == true
                                  ? slot.hint!
                                  : copy.puzzleSlotEmpty),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: filledText != null
                                ? AppTheme.textDark
                                : AppTheme.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            copy.puzzlePickFromBelow,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pending.map((l) {
              final isSelected = selectedLabelId == l.id;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 2.5,
                        ),
                      )
                    : null,
                child: PuzzleConceptTile(
                  text: l.text,
                  isWrongFlash: flashWrongId == l.id,
                  disabled: disabled,
                  onTap: () => onLabelTap(l.id),
                  fullWidth: pending.length == 1,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Large hero diagram for puzzle — vault aesthetic with shimmer fallback.
class PuzzleHeroImage extends StatelessWidget {
  final String? imageUrl;
  final bool imageLoading;
  final String placeholderTitle;

  const PuzzleHeroImage({
    super.key,
    this.imageUrl,
    this.imageLoading = false,
    this.placeholderTitle = '',
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final copy = SkulMateCopy.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF0A2A66).withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A2A66).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: hasImage || imageLoading
              ? _HeroImage(
                  url: imageUrl,
                  loading: imageLoading,
                  loadingLabel: copy.puzzleDiagramDecrypting,
                )
              : _HeroPlaceholder(
                  title: placeholderTitle,
                  vaultLabel: copy.puzzleVaultLocked,
                  decrypting: false,
                ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  final String title;
  final String vaultLabel;
  final bool decrypting;

  const _HeroPlaceholder({
    required this.title,
    required this.vaultLabel,
    this.decrypting = false,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A2A66),
            Color(0xFF1A4A9E),
            Color(0xFF2D6CDF),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            decrypting ? Icons.hourglass_top_rounded : Icons.lock_rounded,
            size: 44,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 10),
          Text(
            vaultLabel.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (decrypting) ...[
            const SizedBox(height: 8),
            Text(
              copy.puzzleDiagramDecrypting,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ] else if (title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact diagram thumbnail when illustration exists.
class PuzzleDiagramThumb extends StatelessWidget {
  final String? imageUrl;
  final bool imageLoading;

  const PuzzleDiagramThumb({
    super.key,
    this.imageUrl,
    this.imageLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PuzzleNeoCard(
      padding: const EdgeInsets.all(8),
      radius: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _HeroImage(url: imageUrl, loading: imageLoading),
        ),
      ),
    );
  }
}

/// @deprecated Use [PuzzleDiagramThumb].
class PuzzleGlassHero extends StatelessWidget {
  final String? imageUrl;
  final bool imageLoading;

  const PuzzleGlassHero({
    super.key,
    this.imageUrl,
    this.imageLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PuzzleDiagramThumb(
      imageUrl: imageUrl,
      imageLoading: imageLoading,
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String? url;
  final bool loading;
  final String? loadingLabel;

  const _HeroImage({
    this.url,
    this.loading = false,
    this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (loading || url == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Shimmer.fromColors(
            baseColor: const Color(0xFF0A2A66),
            highlightColor: const Color(0xFF3D7AE8),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A2A66), Color(0xFF1A4A9E)],
                ),
              ),
            ),
          ),
          if (loadingLabel != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  loadingLabel!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: const Color(0xFF0A2A66),
        highlightColor: const Color(0xFF3D7AE8),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A2A66), Color(0xFF1A4A9E)],
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _HeroPlaceholder(
        title: '',
        vaultLabel: SkulMateCopy.of(context).puzzleVaultLocked,
      ),
    );
  }
}

/// Vertical journey path — completed steps flow downward toward the next slot.
class PuzzleVerticalJourney extends StatelessWidget {
  static const _deepBlue = Color(0xFF0A2A66);

  final List<String> lockedLabels;
  final String prompt;
  final String emptyHint;
  final bool showEmptySlot;
  final int? highlightIndex;

  const PuzzleVerticalJourney({
    super.key,
    required this.lockedLabels,
    required this.prompt,
    required this.emptyHint,
    this.showEmptySlot = true,
    this.highlightIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _deepBlue,
            height: 1.3,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < lockedLabels.length; i++) ...[
          _PuzzleFlowNode(
            label: lockedLabels[i],
            filled: true,
            highlighted: highlightIndex == i,
          ),
          if (i < lockedLabels.length - 1 || showEmptySlot)
            const _PuzzleFlowConnector(),
        ],
        if (showEmptySlot)
          _PuzzleFlowNode(
            label: emptyHint,
            filled: false,
          ),
      ],
    );
  }
}

class _PuzzleFlowConnector extends StatelessWidget {
  const _PuzzleFlowConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Icon(
          Icons.arrow_downward_rounded,
          size: 18,
          color: const Color(0xFF0A2A66).withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _PuzzleFlowNode extends StatelessWidget {
  final String label;
  final bool filled;
  final bool highlighted;

  const _PuzzleFlowNode({
    required this.label,
    required this.filled,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: filled ? Colors.white : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: filled
              ? (highlighted
                  ? AppTheme.accentGreen.withValues(alpha: 0.65)
                  : AppTheme.softBorder)
              : const Color(0xFF0A2A66).withValues(alpha: 0.18),
          width: filled && highlighted ? 2 : 1.2,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (filled)
            Icon(
              highlighted ? Icons.auto_awesome_rounded : Icons.check_circle_rounded,
              size: 20,
              color: highlighted
                  ? AppTheme.accentGreen
                  : AppTheme.accentGreen.withValues(alpha: 0.85),
            )
          else
            Icon(
              Icons.radio_button_unchecked_rounded,
              size: 18,
              color: const Color(0xFF0A2A66).withValues(alpha: 0.35),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                color: filled ? AppTheme.textDark : AppTheme.textMedium,
                fontStyle: filled ? FontStyle.normal : FontStyle.italic,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width floating cards for answer choices.
class PuzzleFloatingTileList extends StatelessWidget {
  final List<({String id, String text})> tiles;
  final void Function(String id) onTileTap;
  final String? flashWrongId;

  const PuzzleFloatingTileList({
    super.key,
    required this.tiles,
    required this.onTileTap,
    this.flashWrongId,
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      children: tiles.map((tile) {
        final isWrong = flashWrongId == tile.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PuzzleConceptTile(
            text: tile.text,
            isWrongFlash: isWrong,
            onTap: () => onTileTap(tile.id),
            fullWidth: true,
          ),
        );
      }).toList(),
    );
  }
}

/// Single active step zone — one slot at a time.
class PuzzleCurrentStepZone extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final String prompt;
  final String emptyHint;
  final String? lockedLabel;
  final bool showSuccess;

  const PuzzleCurrentStepZone({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.prompt,
    required this.emptyHint,
    this.lockedLabel,
    this.showSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final filled = lockedLabel != null;
    return PuzzleNeoCard(
      radius: 20,
      accent: showSuccess
          ? AppTheme.accentGreen
          : filled
              ? AppTheme.skyBlue
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.stitchSkyBlueGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Step $stepNumber of $totalSteps',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (showSuccess)
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: AppTheme.accentGreen.withValues(alpha: 0.9),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            prompt,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: filled
                ? Container(
                    key: ValueKey(lockedLabel),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentGreen.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.accentGreen.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.accentGreen,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lockedLabel!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey('empty'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.skyBlue.withValues(alpha: 0.35),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emptyHint,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMedium,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Neomorphic concept tile for the answer grid.
class PuzzleConceptTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isWrongFlash;
  final bool disabled;
  final bool fullWidth;

  const PuzzleConceptTile({
    super.key,
    required this.text,
    required this.onTap,
    this.isWrongFlash = false,
    this.disabled = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: isWrongFlash
          ? (Matrix4.identity()..translateByDouble(5.0, 0, 0, 1))
          : Matrix4.identity(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isWrongFlash ? AppTheme.gameNudgeBg : Colors.white,
              border: Border.all(
                color: isWrongFlash
                    ? AppTheme.gameNudgeBorder
                    : AppTheme.softBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: fullWidth ? 18 : 14,
                vertical: fullWidth ? 18 : 16,
              ),
              child: Center(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fullWidth ? 15 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                    height: 1.25,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (fullWidth) {
      return SizedBox(width: double.infinity, child: tile);
    }
    return tile;
  }
}

/// Two-column concept tile grid.
class PuzzleConceptTileGrid extends StatelessWidget {
  final List<({String id, String text})> tiles;
  final void Function(String id) onTileTap;
  final String? flashWrongId;

  const PuzzleConceptTileGrid({
    super.key,
    required this.tiles,
    required this.onTileTap,
    this.flashWrongId,
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tiles.map((tile) {
            return SizedBox(
              width: width,
              child: PuzzleConceptTile(
                text: tile.text,
                isWrongFlash: flashWrongId == tile.id,
                onTap: () => onTileTap(tile.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Draggable concept card for the puzzle tray.
class PuzzleDraggablePiece extends StatelessWidget {
  final String id;
  final String text;
  final bool isWrongFlash;
  final bool compact;
  final VoidCallback? onDragStarted;

  const PuzzleDraggablePiece({
    super.key,
    required this.id,
    required this.text,
    this.isWrongFlash = false,
    this.compact = false,
    this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) {
    final child = PuzzleConceptTile(
      text: text,
      isWrongFlash: isWrongFlash,
      fullWidth: !compact,
      onTap: () {},
      disabled: true,
    );

    final feedbackWidth = compact ? 220.0 : MediaQuery.sizeOf(context).width - 80;

    return LongPressDraggable<String>(
      data: id,
      onDragStarted: onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        child: Transform.rotate(
          angle: 0.04,
          child: SizedBox(
            width: feedbackWidth,
            child: Opacity(
              opacity: 0.95,
              child: PuzzleConceptTile(
                text: text,
                fullWidth: !compact,
                onTap: () {},
                disabled: true,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: compact
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: child,
            )
          : child,
    );
  }
}

/// 2x2 answer grid — max 4 tappable squares per step.
class PuzzleChoiceGrid extends StatelessWidget {
  final List<({String id, String text})> choices;
  final void Function(String id) onTap;
  final String? flashWrongId;
  final bool disabled;

  const PuzzleChoiceGrid({
    super.key,
    required this.choices,
    required this.onTap,
    this.flashWrongId,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) return const SizedBox.shrink();
    final items = choices.take(4).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 10.0;
        final cellW = (constraints.maxWidth - gap) / 2;
        const cellH = 88.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((c) {
            return SizedBox(
              width: cellW,
              height: cellH,
              child: PuzzleConceptTile(
                text: c.text,
                isWrongFlash: flashWrongId == c.id,
                onTap: disabled ? () {} : () => onTap(c.id),
                disabled: disabled,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// @deprecated Use [PuzzleChoiceGrid].
class PuzzleChoiceTray extends StatelessWidget {
  final List<({String id, String text})> pieces;
  final String? flashWrongId;
  final VoidCallback? onDragStarted;

  const PuzzleChoiceTray({
    super.key,
    required this.pieces,
    this.flashWrongId,
    this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pieces.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = pieces[index];
          return PuzzleDraggablePiece(
            id: p.id,
            text: p.text,
            isWrongFlash: flashWrongId == p.id,
            onDragStarted: onDragStarted,
            compact: true,
          );
        },
      ),
    );
  }
}

/// Tray of draggable puzzle pieces (vertical fallback).
class PuzzleDragTray extends StatelessWidget {
  final List<({String id, String text})> pieces;
  final String? flashWrongId;
  final VoidCallback? onDragStarted;

  const PuzzleDragTray({
    super.key,
    required this.pieces,
    this.flashWrongId,
    this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) return const SizedBox.shrink();
    return Column(
      children: pieces.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PuzzleDraggablePiece(
            id: p.id,
            text: p.text,
            isWrongFlash: flashWrongId == p.id,
            onDragStarted: onDragStarted,
          ),
        );
      }).toList(),
    );
  }
}

/// Drop target for the next sequence slot.
class PuzzleDropSlot extends StatelessWidget {
  final String hint;
  final bool accepting;
  final void Function(String pieceId) onAccept;

  const PuzzleDropSlot({
    super.key,
    required this.hint,
    required this.accepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => accepting,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, rejected) {
        final hover = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: hover
                ? AppTheme.skyBlueLight.withValues(alpha: 0.5)
                : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hover
                  ? AppTheme.skyBlue
                  : const Color(0xFF0A2A66).withValues(alpha: 0.22),
              width: hover ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 20,
                color: const Color(0xFF0A2A66).withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hover ? 'Release to place' : hint,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Brief learning reinforcement after a correct step.
class PuzzleWhyChip extends StatelessWidget {
  final String label;
  final String text;

  const PuzzleWhyChip({
    super.key,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentLightGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.accentGreen,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated connector drawn across completed sequence nodes.
class PuzzleCompletionPathAnimation extends StatefulWidget {
  final int nodeCount;

  const PuzzleCompletionPathAnimation({super.key, required this.nodeCount});

  @override
  State<PuzzleCompletionPathAnimation> createState() =>
      _PuzzleCompletionPathAnimationState();
}

class _PuzzleCompletionPathAnimationState
    extends State<PuzzleCompletionPathAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = (widget.nodeCount * 56).clamp(80, 280).toDouble();
    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _SequencePathPainter(
              progress: _controller.value,
              nodeCount: widget.nodeCount,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _SequencePathPainter extends CustomPainter {
  final double progress;
  final int nodeCount;

  _SequencePathPainter({required this.progress, required this.nodeCount});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodeCount < 2) return;
    final paint = Paint()
      ..color = AppTheme.accentGreen.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final step = size.height / (nodeCount - 1);
    path.moveTo(size.width / 2, 12);
    for (var i = 1; i < nodeCount; i++) {
      path.lineTo(size.width / 2, 12 + step * i);
    }

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SequencePathPainter old) =>
      old.progress != progress || old.nodeCount != nodeCount;
}

/// Hero image with normalized hotspot drop zones + draggable labels below.
class PuzzleHotspotBoard extends StatelessWidget {
  final String? imageUrl;
  final bool imageLoading;
  final String placeholderTitle;
  final List<({String id, double x, double y, double w, double h, String accepts, String? label})>
      hotspots;
  final List<({String id, String text})> dragLabels;
  final Map<String, String> filledHotspots;
  final void Function(String labelId, String hotspotId) onLabelDropped;
  final String? flashWrongId;
  final VoidCallback? onDragStarted;

  const PuzzleHotspotBoard({
    super.key,
    this.imageUrl,
    this.imageLoading = false,
    this.placeholderTitle = '',
    required this.hotspots,
    required this.dragLabels,
    required this.filledHotspots,
    required this.onLabelDropped,
    this.flashWrongId,
    this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) {
    final pendingLabels =
        dragLabels.where((l) => !filledHotspots.containsValue(l.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bw = constraints.maxWidth;
                final bh = constraints.maxHeight;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _HeroImage(url: imageUrl, loading: imageLoading),
                    ...hotspots.map((h) {
                      final filled = filledHotspots[h.id];
                      String? labelText;
                      if (filled != null) {
                        for (final l in dragLabels) {
                          if (l.id == filled) {
                            labelText = l.text;
                            break;
                          }
                        }
                      } else {
                        labelText = h.label;
                      }
                      return Positioned(
                        left: h.x * bw,
                        top: h.y * bh,
                        width: h.w * bw,
                        height: h.h * bh,
                        child: DragTarget<String>(
                          onWillAcceptWithDetails: (d) =>
                              filled == null && d.data == h.accepts,
                          onAcceptWithDetails: (d) =>
                              onLabelDropped(d.data, h.id),
                          builder: (context, candidate, _) {
                            final hover = candidate.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              decoration: BoxDecoration(
                                color: filled != null
                                    ? AppTheme.accentGreen
                                        .withValues(alpha: 0.35)
                                    : hover
                                        ? AppTheme.skyBlueLight
                                            .withValues(alpha: 0.55)
                                        : AppTheme.primaryColor
                                            .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: filled != null
                                      ? AppTheme.accentGreen
                                      : hover
                                          ? AppTheme.skyBlue
                                          : AppTheme.primaryColor
                                              .withValues(alpha: 0.45),
                                  width: hover || filled != null ? 2 : 1.2,
                                ),
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(4),
                              child: labelText != null && labelText.isNotEmpty
                                  ? Text(
                                      labelText,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textDark,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
        if (pendingLabels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pendingLabels.map((l) {
              return PuzzleDraggablePiece(
                id: l.id,
                text: l.text,
                compact: true,
                isWrongFlash: flashWrongId == l.id,
                onDragStarted: onDragStarted,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Tap choices in the correct order (order_check steps).
class PuzzleOrderTapBoard extends StatelessWidget {
  final List<({String id, String text})> choices;
  final List<String> orderSequence;
  final List<String> tappedOrder;
  final void Function(String id) onTap;
  final String? flashWrongId;
  final bool disabled;

  const PuzzleOrderTapBoard({
    super.key,
    required this.choices,
    required this.orderSequence,
    required this.tappedOrder,
    required this.onTap,
    this.flashWrongId,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return PuzzleChoiceGrid(
      choices: choices,
      disabled: disabled,
      flashWrongId: flashWrongId,
      onTap: (id) {
        if (disabled) return;
        onTap(id);
      },
    );
  }
}
