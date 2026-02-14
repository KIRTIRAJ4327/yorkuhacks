import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/colors.dart';

/// Loading shimmer placeholder
class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.card,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Route card skeleton for loading state
class RouteCardSkeleton extends StatelessWidget {
  const RouteCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingShimmer(width: 120, height: 24),
          SizedBox(height: 16),
          Row(
            children: [
              LoadingShimmer(width: 80, height: 80, borderRadius: 40),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    LoadingShimmer(height: 16),
                    SizedBox(height: 8),
                    LoadingShimmer(height: 16),
                    SizedBox(height: 8),
                    LoadingShimmer(height: 16),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          LoadingShimmer(height: 48),
        ],
      ),
    );
  }
}
