import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/route_provider.dart';
import '../widgets/route/safety_score_gauge.dart';

class ArrivalScreen extends ConsumerWidget {
  const ArrivalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(routeProvider);
    final route = routeState.selectedRoute;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.safeAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.safeAccent,
                    size: 48,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'You arrived safely!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              // Safety gauge
              if (route != null) ...[
                SafetyScoreGauge(
                  score: route.safetyScore,
                  size: 120,
                ),

                const SizedBox(height: 30),

                // Journey stats
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      _StatRow(
                        icon: Icons.straighten,
                        label: 'Distance',
                        value: FormatUtils.formatDistance(
                            route.distanceMeters),
                      ),
                      const SizedBox(height: 12),
                      _StatRow(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: FormatUtils.formatDuration(
                            route.durationSeconds),
                      ),
                      const SizedBox(height: 12),
                      _StatRow(
                        icon: Icons.lightbulb_outline,
                        label: 'Well-lit',
                        value: '${route.lightingCoverage.round()}%',
                        color: AppColors.alertAccent,
                      ),
                      const SizedBox(height: 12),
                      _StatRow(
                        icon: Icons.local_hospital_outlined,
                        label: 'Safe spaces passed',
                        value: route.safeSpacesCount.toString(),
                        color: AppColors.safeAccent,
                      ),
                    ],
                  ),
                ),

                // AI summary
                if (route.aiSummary != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('\u{1F4AC}',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Great choice! ${route.aiSummary}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const Spacer(),

              // Return home button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(navigationProvider.notifier).stopNavigation();
                    ref.read(routeProvider.notifier).clear();
                    context.go('/');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back to Home'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color ?? AppColors.textSecondary, size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
