import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../data/models/route_data.dart' as models;
import '../../../providers/route_provider.dart';

/// Compact route dashboard that appears at bottom of home screen
class RouteDashboard extends ConsumerWidget {
  const RouteDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(routeProvider);
    
    if (routeState.routes.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check current route to determine behavior
    final currentPath = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final isOnRoutesScreen = currentPath == '/routes';

    return DraggableScrollableSheet(
      initialChildSize: 0.35, // Start at 35% of screen
      minChildSize: 0.2, // Can collapse to 20%
      maxChildSize: 0.6, // Can expand to 60%
      snap: true,
      snapSizes: const [0.2, 0.35, 0.6],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Lighter slate color - was too dark before
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important: don't expand unnecessarily
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${routeState.routes.length} Routes Found',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (routeState.destinationName != null)
                            Text(
                              'to ${routeState.destinationName}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: isOnRoutesScreen
                          ? null // Already on routes screen, disable button
                          : () => context.push('/routes'),
                      child: Text(
                        isOnRoutesScreen ? 'Viewing All' : 'View All',
                        style: TextStyle(
                          color: isOnRoutesScreen
                              ? AppColors.textSecondary
                              : AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Route cards list
              Flexible(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  shrinkWrap: true, // Important: only take needed space
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: routeState.routes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final route = routeState.routes[index];
                    return _CompactRouteCard(
                      route: route,
                      onTap: () {
                        ref.read(routeProvider.notifier).selectRoute(index);
                        context.push('/routes');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactRouteCard extends StatelessWidget {
  final models.RouteData route;
  final VoidCallback onTap;

  const _CompactRouteCard({
    required this.route,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeIcon = route.type == models.RouteType.fastest
        ? '⚡'
        : route.type == models.RouteType.safest
            ? '🛡️'
            : '⚖️';
    
    final typeColor = route.type == models.RouteType.fastest
        ? AppColors.brand
        : route.type == models.RouteType.safest
            ? AppColors.success
            : AppColors.warning;
    
    final scoreColor = route.safetyScore >= 80
        ? AppColors.success
        : route.safetyScore >= 60
            ? AppColors.warning
            : AppColors.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 100, // Ensure minimum height
          maxHeight: 120, // Prevent excessive height
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Route type badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  typeIcon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Route details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        route.type.name.toUpperCase(),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${route.safetyScore.toInt()}',
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '/100',
                              style: TextStyle(
                                color: scoreColor.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        FormatUtils.formatDuration(route.durationSeconds),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.straighten,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          FormatUtils.formatDistance(route.distanceMeters),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    children: [
                      _InfoChip(
                        icon: '💡',
                        text: '${route.lightingCoverage.toInt()}%',
                      ),
                      _InfoChip(
                        icon: '🏥',
                        text: '${route.safeSpacesCount}',
                      ),
                      _InfoChip(
                        icon: '⚠️',
                        text: '${route.crimesInBuffer}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
