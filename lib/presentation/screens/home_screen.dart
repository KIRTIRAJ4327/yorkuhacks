import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../core/theme/colors.dart';
import '../../providers/location_provider.dart';
import '../../providers/route_provider.dart';
import '../widgets/common/search_bar.dart';
import '../widgets/map/safety_map.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Initialize location on first load
    Future.microtask(() {
      ref.read(locationProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final routeState = ref.watch(routeProvider);
    final center = locationState.position ??
        const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen dark map
          SafetyMap(
            controller: _mapController,
            center: center,
            userLocation: locationState.position,
            isDark: true,
          ),

          // Search bar (top)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SafePathSearchBar(
                hint: 'Where are you going?',
                onSearch: (query) {
                  return ref.read(routeProvider.notifier).searchDestination(query);
                },
                onSelect: (name, location) {
                  _onDestinationSelected(name, location, center);
                },
              ),
            ),
          ),

          // Loading overlay
          if (routeState.isLoading)
            Container(
              color: AppColors.background.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.brand),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing safety...',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scoring routes with AI',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error snackbar
          if (routeState.error != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  routeState.error!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Bottom FABs
          Positioned(
            bottom: 32,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AI Chat FAB
                FloatingActionButton.small(
                  heroTag: 'chat',
                  onPressed: () => context.push('/chat'),
                  backgroundColor: AppColors.brand,
                  child: const Text('\u{1F4AC}',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 10),
                // Recenter FAB
                FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: () {
                    if (locationState.position != null) {
                      _mapController.move(
                        locationState.position!,
                        AppConstants.defaultZoom,
                      );
                    }
                  },
                  backgroundColor: AppColors.surface,
                  child: const Icon(Icons.my_location,
                      color: AppColors.textPrimary, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDestinationSelected(
    String name,
    LatLng destination,
    LatLng origin,
  ) async {
    await ref.read(routeProvider.notifier).searchRoutes(
          origin: origin,
          destination: destination,
          destinationName: name,
        );

    if (mounted) {
      final routes = ref.read(routeProvider).routes;
      if (routes.isNotEmpty) {
        context.push('/routes');
      }
    }
  }
}
