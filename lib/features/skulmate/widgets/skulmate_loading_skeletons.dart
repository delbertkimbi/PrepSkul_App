import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import 'package:shimmer/shimmer.dart';

import 'skulmate_surface_styles.dart';

/// Shimmer placeholders for SkulMate list screens.
class SkulMateLoadingSkeletons {
  SkulMateLoadingSkeletons._();

  /// Horizontal game card on home carousel.
  static Widget homeGameCard({double? width}) {
    return Container(
      width: width,
      height: 86,
      decoration: SkulMateSurfaceStyles.homeCard(compact: true),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerLine(width: double.infinity, height: 13),
                    const SizedBox(height: 6),
                    _shimmerLine(width: 100, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deck library row on home.
  static Widget homeDeckTile() {
    return Container(
      height: 64,
      decoration: SkulMateSurfaceStyles.homeCard(compact: true),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerLine(width: double.infinity, height: 13),
                    const SizedBox(height: 6),
                    _shimmerLine(width: 72, height: 10),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget gamesScreen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _filterChipsRow(),
        const SizedBox(height: 12),
        ...List.generate(6, (_) => ShimmerLoading.gameCard()),
      ],
    );
  }

  static Widget progressScreen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _shimmerBlock(height: 108, radius: 18),
        const SizedBox(height: 14),
        _shimmerBlock(height: 88, radius: 14),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _shimmerBlock(height: 76, radius: 14)),
            const SizedBox(width: 10),
            Expanded(child: _shimmerBlock(height: 76, radius: 14)),
          ],
        ),
        const SizedBox(height: 20),
        _shimmerLine(width: 140, height: 14),
        const SizedBox(height: 10),
        _shimmerBlock(height: 320, radius: 16),
        const SizedBox(height: 20),
        _shimmerLine(width: 120, height: 14),
        const SizedBox(height: 8),
        ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _shimmerBlock(height: 72, radius: 12),
            )),
      ],
    );
  }

  static Widget _filterChipsRow() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            5,
            (index) => Container(
              margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
              width: index == 0 ? 52 : 88,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.softBorder),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _shimmerBlock({required double height, required double radius}) {
    return Container(
      height: height,
      decoration: SkulMateSurfaceStyles.homeCard(radius: radius),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerLine(width: 120, height: 12),
              const SizedBox(height: 10),
              _shimmerLine(width: double.infinity, height: 10),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _shimmerLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
