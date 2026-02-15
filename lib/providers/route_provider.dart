import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../data/local/cache_service.dart';
import '../data/models/route_data.dart';
import '../data/repositories/collision_repository.dart';
import '../data/repositories/crime_repository.dart';
import '../data/repositories/google_places_repository.dart';
import '../data/repositories/infrastructure_repository.dart';
import '../data/repositories/osm_lighting_repository.dart';
import '../data/repositories/route_repository.dart';
import '../data/repositories/safe_spaces_repository.dart';
import '../domain/gemini_service.dart';
import '../domain/route_service.dart';
import '../domain/safety_scorer.dart';

/// Route search & selection state
class RouteState {
  final List<RouteData> routes;
  final int selectedIndex;
  final bool isLoading;
  final String? error;
  final LatLng? destination;
  final String? destinationName;

  const RouteState({
    this.routes = const [],
    this.selectedIndex = 0,
    this.isLoading = false,
    this.error,
    this.destination,
    this.destinationName,
  });

  RouteData? get selectedRoute =>
      routes.isNotEmpty ? routes[selectedIndex] : null;

  RouteState copyWith({
    List<RouteData>? routes,
    int? selectedIndex,
    bool? isLoading,
    String? error,
    LatLng? destination,
    String? destinationName,
  }) {
    return RouteState(
      routes: routes ?? this.routes,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      destination: destination ?? this.destination,
      destinationName: destinationName ?? this.destinationName,
    );
  }
}

class RouteNotifier extends Notifier<RouteState> {
  @override
  RouteState build() => const RouteState();

  RouteService get _routeService => ref.read(routeServiceProvider);

  /// Search for routes to a destination
  Future<void> searchRoutes({
    required LatLng origin,
    required LatLng destination,
    String? destinationName,
  }) async {
    state = state.copyWith(
      isLoading: true,
      destination: destination,
      destinationName: destinationName,
    );

    try {
      final routes = await _routeService.generateRoutes(
        origin: origin,
        destination: destination,
      );

      state = state.copyWith(
        routes: routes,
        selectedIndex: routes.length > 2 ? 2 : routes.length - 1,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate routes: ${e.toString()}',
      );
    }
  }

  /// Geocode a destination query
  Future<List<({String displayName, LatLng location})>> searchDestination(
      String query) {
    return _routeService.searchDestination(query);
  }

  /// Select a route by index
  void selectRoute(int index) {
    if (index >= 0 && index < state.routes.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }

  /// Clear routes
  void clear() {
    state = const RouteState();
  }
}

// Service providers
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final gemini = GeminiService(cache: cache);
  gemini.init();
  return gemini;
});

// Auto-switch between Google Places (with API key) and Overpass (fallback)
final safeSpacesRepoProvider = Provider<dynamic>((ref) {
  final googleKey = AppConstants.googlePlacesApiKey;

  if (googleKey.isNotEmpty) {
    // Use Google Places for real-time opening hours
    return GooglePlacesSafeSpacesRepository(apiKey: googleKey);
  } else {
    // Fallback to Overpass for demo without API key
    return SafeSpacesRepository();
  }
});

final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService(
    routeRepo: RouteRepository(),
    crimeRepo: CrimeRepository(),
    lightingRepo: OsmLightingRepository(), // Real OSM lighting data!
    collisionRepo: CollisionRepository(),
    infraRepo: InfrastructureRepository(), // Real OSM sidewalk data!
    safeSpacesRepo: ref.watch(safeSpacesRepoProvider),
    scorer: SafetyScorer(),
    gemini: ref.watch(geminiServiceProvider),
  );
});

final routeProvider = NotifierProvider<RouteNotifier, RouteState>(
  RouteNotifier.new,
);
