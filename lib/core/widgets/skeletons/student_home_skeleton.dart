import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/status_bar_utils.dart';
import '../../../core/utils/responsive_helper.dart';

class StudentHomeSkeleton extends StatelessWidget {
  const StudentHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusBarUtils.withLightStatusBar(
      Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          title: Shimmer.fromColors(
            baseColor: AppTheme.neutral200,
            highlightColor: Colors.white,
            child: Container(
              width: 160,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          actions: [
            Shimmer.fromColors(
              baseColor: AppTheme.neutral200,
              highlightColor: Colors.white,
              child: Container(
                width: 72,
                height: 24,
                margin: EdgeInsets.only(
                  right: ResponsiveHelper.responsiveHorizontalPadding(context),
                ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  ),
                                ),
                              ],
                            ),
        body: SingleChildScrollView(
          child: Padding(
            padding: ResponsiveHelper.responsivePadding(context),
                            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                Shimmer.fromColors(
                  baseColor: AppTheme.neutral200,
                  highlightColor: Colors.white,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                const SizedBox(height: 20),
                Shimmer.fromColors(
                  baseColor: AppTheme.neutral200,
                  highlightColor: Colors.white,
                  child: Container(
                      width: 120,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _statSkeletonTile()),
                    const SizedBox(width: 12),
                    Expanded(child: _statSkeletonTile()),
                  ],
                ),
                const SizedBox(height: 24),
                Shimmer.fromColors(
                  baseColor: AppTheme.neutral200,
                  highlightColor: Colors.white,
                  child: Container(
                    width: 120,
                    height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                ),
                const SizedBox(height: 16),
                _actionSkeletonTile(),
                const SizedBox(height: 12),
                _actionSkeletonTile(),
                                  ],
                                ),
                              ),
        ),
      ),
    );
  }

  Widget _statSkeletonTile() {
    return Shimmer.fromColors(
      baseColor: AppTheme.neutral200,
      highlightColor: Colors.white,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
  }

  Widget _actionSkeletonTile() {
    return Shimmer.fromColors(
      baseColor: AppTheme.neutral200,
      highlightColor: Colors.white,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
