import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../providers/location_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/route_provider.dart';
import '../widgets/map/safety_map.dart';
import '../widgets/route/route_card.dart';
import '../widgets/common/loading_shimmer.dart';

class RouteSelectionScreen extends ConsumerStatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  ConsumerState<RouteSelectionScreen> createState() =>
      _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends ConsumerState<RouteSelectionScreen> {
  final MapController _mapController = MapController();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(routeProvider).selectedIndex;
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final locationState = ref.watch(locationProvider);
    final routes = routeState.routes;

    if (routes.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Routes')),
        body: const Center(
          child: Text(
            'No routes found',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final selectedRoute = routes[routeState.selectedIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map (top half)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: SafetyMap(
              controller: _mapController,
              center: selectedRoute.points.isNotEmpty
                  ? selectedRoute.points[selectedRoute.points.length ~/ 2]
                  : locationState.position!,
              zoom: 14,
              routes: routes,
              selectedRouteIndex: routeState.selectedIndex,
              userLocation: locationState.position,
              isDark: true,
            ),
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: AppColors.surface.withValues(alpha: 0.9),
                radius: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary, size: 20),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),

          // Destination label
          if (routeState.destinationName != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 60,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place, color: AppColors.brand, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        routeState.destinationName!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Route type tabs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 - 28,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: routes.asMap().entries.map((entry) {
                    final isActive =
                        entry.key == routeState.selectedIndex;
                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(routeProvider.notifier)
                            .selectRoute(entry.key);
                        _pageController.animateToPage(
                          entry.key,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? entry.value.type.color
                                  .withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.value.type.emoji} ${entry.value.type.label}',
                          style: TextStyle(
                            color: isActive
                                ? entry.value.type.color
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Swipeable route cards (bottom half)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 + 12,
            left: 0,
            right: 0,
            bottom: 0,
            child: routeState.isLoading
                ? const RouteCardSkeleton()
                : PageView.builder(
                    controller: _pageController,
                    itemCount: routes.length,
                    onPageChanged: (index) {
                      ref.read(routeProvider.notifier).selectRoute(index);
                    },
                    itemBuilder: (context, index) {
                      return RouteCard(
                        route: routes[index],
                        isSelected: index == routeState.selectedIndex,
                        onStartNavigation: () {
                          ref
                              .read(navigationProvider.notifier)
                              .startNavigation(routes[index]);
                          context.push('/navigate');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
