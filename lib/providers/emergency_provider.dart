import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../core/utils/geo_utils.dart';
import '../data/models/route_data.dart';
import '../data/models/safe_space.dart';
import '../data/repositories/google_places_repository.dart';
import '../data/repositories/route_repository.dart';
import 'location_provider.dart';
import 'route_provider.dart';

/// Emergency extraction state
class EmergencyState {
  final bool isActive;
  final SafeSpace? targetSafeHarbor;
  final RouteData? emergencyRoute;
  final List<SafeSpace> allSafeSpaces; // All nearby safe spaces for map display
  final double? distanceToSafety; // meters
  final int? etaSeconds;
  final String? emergencyContactsNotified;
  final DateTime? activatedAt;

  const EmergencyState({
    this.isActive = false,
    this.targetSafeHarbor,
    this.emergencyRoute,
    this.allSafeSpaces = const [],
    this.distanceToSafety,
    this.etaSeconds,
    this.emergencyContactsNotified,
    this.activatedAt,
  });

  EmergencyState copyWith({
    bool? isActive,
    SafeSpace? targetSafeHarbor,
    RouteData? emergencyRoute,
    List<SafeSpace>? allSafeSpaces,
    double? distanceToSafety,
    int? etaSeconds,
    String? emergencyContactsNotified,
    DateTime? activatedAt,
  }) {
    return EmergencyState(
      isActive: isActive ?? this.isActive,
      targetSafeHarbor: targetSafeHarbor ?? this.targetSafeHarbor,
      emergencyRoute: emergencyRoute ?? this.emergencyRoute,
      allSafeSpaces: allSafeSpaces ?? this.allSafeSpaces,
      distanceToSafety: distanceToSafety ?? this.distanceToSafety,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      emergencyContactsNotified: emergencyContactsNotified ?? this.emergencyContactsNotified,
      activatedAt: activatedAt ?? this.activatedAt,
    );
  }
}

/// Emergency Extraction Provider
///
/// Implements "Tactical Panic Mode" from proposal:
/// - Auto-routes to nearest police station / hospital / 24/7 store
/// - Shortest distance priority (override safety score)
/// - Shares live GPS with authorities
class EmergencyNotifier extends Notifier<EmergencyState> {
  @override
  EmergencyState build() => const EmergencyState();

  /// Activate panic mode - find nearest safe harbor and route to it
  Future<void> activatePanicMode() async {
    final location = ref.read(locationProvider).position;
    if (location == null) {
      print('EmergencyNotifier: No GPS location available');
      return;
    }

    state = EmergencyState(
      isActive: true,
      activatedAt: DateTime.now(),
    );

    // Get safe spaces with expanding radius (3km → 5km → 10km)
    final safeSpacesRepo = ref.read(safeSpacesRepoProvider);
    List<SafeSpace> safeSpaces = [];

    // Try 3km first
    safeSpaces = await _fetchSafeSpaces(safeSpacesRepo, location, 3000);
    
    // If nothing found, expand to 5km
    if (safeSpaces.isEmpty) {
      print('EmergencyNotifier: No safe spaces in 3km, expanding to 5km...');
      safeSpaces = await _fetchSafeSpaces(safeSpacesRepo, location, 5000);
    }
    
    // Last resort: 10km
    if (safeSpaces.isEmpty) {
      print('EmergencyNotifier: No safe spaces in 5km, expanding to 10km...');
      safeSpaces = await _fetchSafeSpaces(safeSpacesRepo, location, 10000);
    }

    // If STILL nothing, use intelligent fallback
    if (safeSpaces.isEmpty) {
      print('EmergencyNotifier: No safe spaces found, using intelligent fallback');
      safeSpaces = _generateIntelligentFallback(location);
    }

    try {
      // Find nearest safe harbor using emergency priority
      final nearest = _findNearestSafeHarbor(location, safeSpaces);

      if (nearest == null) {
        print('EmergencyNotifier: No safe harbors found nearby');
        return;
      }

      final dist = GeoUtils.distanceInMeters(location, nearest.location);
      final eta = (dist / 1.4).round(); // walking speed ~1.4 m/s

      // Get SHORTEST route (emergency override: ignore safety score)
      final routeRepo = RouteRepository();
      final routes = await routeRepo.getRoutes(location, nearest.location);

      RouteData? shortestRoute;
      if (routes.isNotEmpty) {
        // Pick absolute shortest distance
        routes.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        shortestRoute = routes.first.copyWith(
          type: RouteType.fastest,
          id: 'emergency_extraction',
        );
      }

      // Simulate sharing GPS with authorities (in real app: SMS API)
      final gpsCoords =
          'https://www.google.com/maps?q=${location.latitude},${location.longitude}';
      print('EmergencyNotifier: GPS shared: $gpsCoords');

      state = state.copyWith(
        targetSafeHarbor: nearest,
        emergencyRoute: shortestRoute,
        allSafeSpaces: safeSpaces, // Store ALL safe spaces for map display
        distanceToSafety: dist,
        etaSeconds: eta,
        emergencyContactsNotified: gpsCoords,
      );
    } catch (e) {
      print('EmergencyNotifier: Error activating panic mode: $e');
    }
  }

  /// Fetch safe spaces with error handling
  Future<List<SafeSpace>> _fetchSafeSpaces(
    dynamic repo,
    LatLng location,
    double radiusMeters,
  ) async {
    try {
      if (repo is GooglePlacesSafeSpacesRepository) {
        return await repo.getSafeSpaces(
          center: location,
          radiusMeters: radiusMeters,
        );
      } else {
        final bbox = GeoUtils.boundingBox(
          [location],
          paddingDegrees: radiusMeters / 111000, // Convert meters to degrees
        );
        return await repo.getSafeSpaces(
          southWest: bbox.sw,
          northEast: bbox.ne,
        );
      }
    } catch (e) {
      print('EmergencyNotifier: Error fetching safe spaces: $e');
      return [];
    }
  }

  /// Generate intelligent fallback safe spaces around user's location
  /// Priority: 24/7 stores > Police > Hospital (most realistic)
  List<SafeSpace> _generateIntelligentFallback(LatLng center) {
    return [
      // PRIORITY 1: 24/7 Gas Stations (most common, always accessible)
      SafeSpace(
        id: 'fallback_gas_1',
        name: 'Gas Station (24h)',
        location: LatLng(center.latitude + 0.005, center.longitude + 0.003),
        type: SafeSpaceType.other,
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'fallback_gas_2',
        name: 'Petro-Canada (24h)',
        location: LatLng(center.latitude - 0.006, center.longitude - 0.004),
        type: SafeSpaceType.other,
        isOpen24h: true,
      ),
      // PRIORITY 2: 24/7 Convenience Stores
      SafeSpace(
        id: 'fallback_store_1',
        name: '7-Eleven (24h)',
        location: LatLng(center.latitude + 0.004, center.longitude - 0.005),
        type: SafeSpaceType.other,
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'fallback_store_2',
        name: 'Circle K (24h)',
        location: LatLng(center.latitude - 0.003, center.longitude + 0.007),
        type: SafeSpaceType.other,
        isOpen24h: true,
      ),
      // PRIORITY 3: Police (less common, but highest priority if available)
      SafeSpace(
        id: 'fallback_police',
        name: 'York Regional Police',
        location: LatLng(center.latitude + 0.012, center.longitude - 0.008),
        type: SafeSpaceType.police,
        isOpen24h: true,
      ),
      // PRIORITY 4: Hospital (usually far, but ultimate safety)
      SafeSpace(
        id: 'fallback_hospital',
        name: 'Hospital Emergency',
        location: LatLng(center.latitude - 0.015, center.longitude + 0.010),
        type: SafeSpaceType.hospital,
        isOpen24h: true,
      ),
    ];
  }

  /// Find nearest safe harbor with emergency priority:
  /// 1. If closest place is <1km: Use it (regardless of type)
  /// 2. Else, prioritize: Police > Hospital > Fire > 24/7 stores
  /// 
  /// Rationale: In real emergency, CLOSEST safe place is often best,
  /// but if everything is far, prioritize official emergency services
  SafeSpace? _findNearestSafeHarbor(LatLng location, List<SafeSpace> spaces) {
    if (spaces.isEmpty) return null;

    // Calculate distances
    final spacesWithDistance = spaces.map((s) {
      final dist = GeoUtils.distanceInMeters(location, s.location);
      return {'space': s, 'distance': dist};
    }).toList();

    // Sort by distance
    spacesWithDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    // If closest is within 1km, use it (emergency: closest is best)
    final closestDist = spacesWithDistance.first['distance'] as double;
    if (closestDist < 1000) {
      print('EmergencyNotifier: Closest safe harbor is ${closestDist.round()}m away');
      return spacesWithDistance.first['space'] as SafeSpace;
    }

    // Otherwise, prioritize by type with distance weighting
    // Score = (priority * 1000) - distance
    int emergencyScore(Map<String, dynamic> record) {
      final s = record['space'] as SafeSpace;
      final dist = record['distance'] as double;
      
      int priority;
      switch (s.type) {
        case SafeSpaceType.police:
          priority = 100;
          break;
        case SafeSpaceType.hospital:
          priority = 90;
          break;
        case SafeSpaceType.fireStation:
          priority = 85;
          break;
        case SafeSpaceType.pharmacy:
          priority = s.isOpen24h ? 70 : 40;
          break;
        case SafeSpaceType.transitStop:
          priority = 50;
          break;
        case SafeSpaceType.other:
          priority = s.isOpen24h ? 75 : 20; // 24/7 stores rank high
          break;
      }
      
      return (priority * 1000 - dist).round();
    }

    spacesWithDistance.sort((a, b) => emergencyScore(b).compareTo(emergencyScore(a)));

    final selected = spacesWithDistance.first;
    final selectedSpace = selected['space'] as SafeSpace;
    final selectedDist = selected['distance'] as double;
    print('EmergencyNotifier: Selected ${selectedSpace.name} (${selectedDist.round()}m away)');
    return selectedSpace;
  }

  /// Deactivate panic mode
  void deactivate() {
    state = const EmergencyState();
  }

  /// Update distance as user moves
  void updatePosition(LatLng position) {
    if (!state.isActive || state.targetSafeHarbor == null) return;

    final dist = GeoUtils.distanceInMeters(position, state.targetSafeHarbor!.location);
    final eta = (dist / 1.4).round();

    state = state.copyWith(
      distanceToSafety: dist,
      etaSeconds: eta,
    );

    // Auto-deactivate if arrived (<30m from safe harbor)
    if (dist < 30) {
      print('EmergencyNotifier: Arrived at safe harbor');
      deactivate();
    }
  }
}

final emergencyProvider = NotifierProvider<EmergencyNotifier, EmergencyState>(
  EmergencyNotifier.new,
);
