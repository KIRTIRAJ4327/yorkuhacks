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
import '../widgets/navigation/sos_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedOrigin;
  String? _selectedOriginName;

  @override
  void initState() {
    super.initState();
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

          // Search bars (top)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SafePathSearchBar(
                    hint: _selectedOriginName ?? 'From: Current Location',
                    onSearch: (query) {
                      return ref
                          .read(routeProvider.notifier)
                          .searchDestination(query);
                    },
                    onSelect: (name, location) {
                      setState(() {
                        _selectedOrigin = location;
                        _selectedOriginName = name;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SafePathSearchBar(
                    hint: 'To: Where are you going?',
                    onSearch: (query) {
                      return ref
                          .read(routeProvider.notifier)
                          .searchDestination(query);
                    },
                    onSelect: (name, location) {
                      final origin = _selectedOrigin ?? center;
                      _onDestinationSelected(name, location, origin);
                    },
                  ),
                  if (_selectedOrigin != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedOrigin = null;
                            _selectedOriginName = null;
                          });
                        },
                        icon: const Icon(Icons.my_location,
                            size: 16, color: AppColors.brand),
                        label: const Text(
                          'Use Current Location',
                          style:
                              TextStyle(color: AppColors.brand, fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor:
                              AppColors.surface.withValues(alpha: 0.9),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (routeState.isLoading)
            Container(
              color: AppColors.background.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child:
                          CircularProgressIndicator(color: AppColors.brand, strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Analyzing safety data...',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scoring routes with AI',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
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
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerAccent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          routeState.error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            ref.read(routeProvider.notifier).clear(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom-left: SOS Button (always visible)
          const Positioned(
            bottom: 32,
            left: 16,
            child: SOSButton(),
          ),

          // Bottom-right: FABs
          Positioned(
            bottom: 32,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'chat',
                  onPressed: () => context.push('/chat'),
                  backgroundColor: AppColors.brand,
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(height: 10),
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

    // Auto-navigate to route selection after routes are generated
    if (mounted && ref.read(routeProvider).routes.isNotEmpty) {
      context.push('/routes');
    }
  }
}
