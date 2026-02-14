import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/route_data.dart';
import 'safety_score_gauge.dart';

/// Swipeable route card with safety info and AI summary
class RouteCard extends StatelessWidget {
  final RouteData route;
  final bool isSelected;
  final VoidCallback? onStartNavigation;

  const RouteCard({
    super.key,
    required this.route,
    this.isSelected = false,
    this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? route.type.color.withValues(alpha: 0.6)
              : AppColors.border.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: route.type.color.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Route type header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: route.type.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${route.type.emoji} ${route.type.label.toUpperCase()}',
                    style: TextStyle(
                      color: route.type.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${FormatUtils.formatDuration(route.durationSeconds)} \u00B7 ${FormatUtils.formatDistance(route.distanceMeters)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Score gauge + stats
            Row(
              children: [
                SafetyScoreGauge(
                  score: route.safetyScore,
                  size: 80,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatRow(
                        icon: Icons.lightbulb_outline,
                        text:
                            '${route.lightingCoverage.round()}% well-lit',
                        color: AppColors.alertAccent,
                      ),
                      const SizedBox(height: 6),
                      _StatRow(
                        icon: Icons.local_hospital_outlined,
                        text: '${route.safeSpacesCount} safe spaces',
                        color: AppColors.safeAccent,
                      ),
                      const SizedBox(height: 6),
                      _StatRow(
                        icon: Icons.warning_amber_outlined,
                        text: '${route.crimesInBuffer} incidents nearby',
                        color: route.crimesInBuffer > 3
                            ? AppColors.dangerAccent
                            : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // AI Summary
            if (route.aiSummary != null && route.aiSummary!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('\u{1F4AC}', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        route.aiSummary!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Start navigation button
            if (onStartNavigation != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onStartNavigation,
                  icon: const Icon(Icons.navigation_rounded, size: 20),
                  label: const Text('Start Navigation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: route.type.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
