import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/location_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/route_provider.dart';
import '../widgets/map/safety_map.dart';
import '../widgets/navigation/sos_button.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final locationState = ref.watch(locationProvider);
    final routeState = ref.watch(routeProvider);
    final activeRoute = routeState.selectedRoute;

    if (activeRoute == null || navState == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('No active navigation',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    // Check if arrived
    if (navState.hasArrived) {
      Future.microtask(() {
        if (mounted) context.go('/arrived');
      });
    }

    // Update navigation with user position
    if (locationState.position != null) {
      Future.microtask(() {
        ref
            .read(navigationProvider.notifier)
            .updatePosition(locationState.position!);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full-screen map (follow mode)
          SafetyMap(
            controller: _mapController,
            center: navState.currentPosition,
            zoom: 16,
            routes: [activeRoute],
            selectedRouteIndex: 0,
            userLocation: locationState.position,
            isDark: true,
          ),

          // Top: Turn instruction card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (navState.nextTurn != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.turn_left_rounded,
                              color: AppColors.safeAccent, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              navState.nextTurn!.text,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (navState.nextTurn!.landmark != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '  at ${navState.nextTurn!.landmark}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ] else
                      const Text(
                        'Follow the route',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          FormatUtils.formatDuration(
                              navState.remainingSeconds),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const Text(' \u00B7 ',
                            style: TextStyle(color: AppColors.textSecondary)),
                        Text(
                          FormatUtils.formatDistance(
                              navState.remainingDistance),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        // Safety indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.forScore(
                                    navState.currentSegmentSafety)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield,
                                color: AppColors.forScore(
                                    navState.currentSegmentSafety),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                navState.currentSegmentSafety
                                    .round()
                                    .toString(),
                                style: TextStyle(
                                  color: AppColors.forScore(
                                      navState.currentSegmentSafety),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom: Action buttons
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Stop navigation
                  FloatingActionButton(
                    heroTag: 'stop',
                    backgroundColor: AppColors.surface,
                    onPressed: () {
                      ref
                          .read(navigationProvider.notifier)
                          .stopNavigation();
                      context.pop();
                    },
                    child: const Icon(Icons.close,
                        color: AppColors.textPrimary),
                  ),
                  // SOS
                  const SOSButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
