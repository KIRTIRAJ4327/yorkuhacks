import 'package:latlong2/latlong.dart';
import '../core/utils/geo_utils.dart';
import '../data/models/collision.dart';
import '../data/models/crime_incident.dart';
import '../data/models/route_data.dart';
import '../data/models/safe_space.dart';
import '../data/models/street_light.dart';
import '../data/repositories/collision_repository.dart';
import '../data/repositories/crime_repository.dart';
import '../data/repositories/google_places_repository.dart';
import '../data/repositories/infrastructure_repository.dart';
import '../data/repositories/route_repository.dart';
import 'gemini_service.dart';
import 'safety_scorer.dart';

/// Orchestrates route generation, scoring, and AI summaries.
///
/// Strategy:
/// 1. Get direct route from OSRM (fastest)
/// 2. Generate PERPENDICULAR offset waypoints (not on the direct line)
/// 3. Route through brightest area, safe haven area, and pure offsets
/// 4. Score all candidates with safety data
/// 5. Rank using cost-penalty formulas:
///    - Fastest: pure minimum time
///    - Balanced (well-lit): min distance × (1 + darkness_penalty)
///    - Safest (safe haven): highest overall safety score
class RouteService {
  final RouteRepository _routeRepo;
  final CrimeRepository _crimeRepo;
  final dynamic _lightingRepo;
  final CollisionRepository _collisionRepo;
  final InfrastructureRepository _infraRepo;
  final dynamic _safeSpacesRepo;
  final SafetyScorer _scorer;
  final GeminiService _gemini;

  RouteService({
    required RouteRepository routeRepo,
    required CrimeRepository crimeRepo,
    required dynamic lightingRepo,
    required CollisionRepository collisionRepo,
    required InfrastructureRepository infraRepo,
    required dynamic safeSpacesRepo,
    required SafetyScorer scorer,
    required GeminiService gemini,
  })  : _routeRepo = routeRepo,
        _crimeRepo = crimeRepo,
        _lightingRepo = lightingRepo,
        _collisionRepo = collisionRepo,
        _infraRepo = infraRepo,
        _safeSpacesRepo = safeSpacesRepo,
        _scorer = scorer,
        _gemini = gemini;

  /// Generate 3 genuinely different routes: fastest, balanced (lit), safest
  Future<List<RouteData>> generateRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    print('RouteService: Starting diversified route generation...');

    // ===== PHASE 1: Direct route + safety data in parallel =====
    final initialBbox = GeoUtils.boundingBox(
      [origin, destination],
      paddingDegrees: 0.015,
    );

    final Future<List<SafeSpace>> safeSpacesFuture =
        _safeSpacesRepo is GooglePlacesSafeSpacesRepository
            ? _safeSpacesRepo.getSafeSpaces(
                center: LatLng(
                  (initialBbox.sw.latitude + initialBbox.ne.latitude) / 2,
                  (initialBbox.sw.longitude + initialBbox.ne.longitude) / 2,
                ),
                radiusMeters: 2000,
              )
            : _safeSpacesRepo.getSafeSpaces(
                southWest: initialBbox.sw,
                northEast: initialBbox.ne,
              );

    final phase1 = await Future.wait<dynamic>([
      _routeRepo.getRoutes(origin, destination),
      _lightingRepo.getLightsInArea(
          southWest: initialBbox.sw, northEast: initialBbox.ne),
      safeSpacesFuture,
    ]);

    final directRoutes = phase1[0] as List<RouteData>;
    final lights = phase1[1] as List<StreetLight>;
    final safeSpaces = phase1[2] as List<SafeSpace>;

    if (directRoutes.isEmpty) return [];

    final fastest = directRoutes.first;
    print('RouteService: Direct route: ${fastest.distanceMeters.round()}m, '
        '${lights.length} lights, ${safeSpaces.length} safe spaces');

    // ===== PHASE 2: Generate diverse waypoints =====
    // Strategy A: Brightest area (offset perpendicular)
    final brightWP = GeoUtils.selectBrightestWaypoint(
      origin: origin,
      destination: destination,
      lights: lights,
    );

    // Strategy B: Safe haven (police/hospital/transit)
    final havenWP = GeoUtils.selectSafeHavenWaypoint(
      origin: origin,
      destination: destination,
      safeSpaces: safeSpaces,
    );

    // Strategy C: Pure perpendicular offsets (guaranteed different)
    final directDist = GeoUtils.distanceInMeters(origin, destination);
    // Scale offset with distance: 15-20% of direct distance, min 200m, max 600m
    final offsetDist = (directDist * 0.18).clamp(200.0, 600.0);

    final leftOffsetWP = GeoUtils.offsetMidpoint(
      origin: origin,
      destination: destination,
      offsetMeters: offsetDist,
      left: true,
    );

    final rightOffsetWP = GeoUtils.offsetMidpoint(
      origin: origin,
      destination: destination,
      offsetMeters: offsetDist,
      left: false,
    );

    print('RouteService: Waypoints — bright: ${brightWP != null}, '
        'haven: ${havenWP != null}, offsets: L+R at ${offsetDist.round()}m');

    // ===== PHASE 3: Get all waypoint routes in parallel =====
    final waypointSpecs = <_WaypointSpec>[];

    if (brightWP != null) {
      waypointSpecs.add(_WaypointSpec('route_bright', brightWP));
    }
    if (havenWP != null) {
      waypointSpecs.add(_WaypointSpec('route_haven', havenWP));
    }
    // Always add perpendicular offsets as backup
    waypointSpecs.add(_WaypointSpec('route_left', leftOffsetWP));
    waypointSpecs.add(_WaypointSpec('route_right', rightOffsetWP));

    final waypointFutures = waypointSpecs.map((spec) {
      return _routeRepo.getRouteViaWaypoint(
        origin: origin,
        waypoint: spec.waypoint,
        destination: destination,
        routeId: spec.id,
      );
    }).toList();

    final waypointResults = await Future.wait(waypointFutures);

    // ===== PHASE 4: Collect all unique candidate routes =====
    final allCandidates = <RouteData>[fastest];

    // Add OSRM alternatives (if any)
    for (final alt in directRoutes.skip(1)) {
      if (_isRouteDifferent(alt, allCandidates)) {
        allCandidates.add(alt);
      }
    }

    // Add waypoint routes
    for (final wr in waypointResults) {
      if (wr != null && _isRouteDifferent(wr, allCandidates)) {
        allCandidates.add(wr);
      }
    }

    print('RouteService: ${allCandidates.length} unique candidates collected');

    // ===== PHASE 5: Fetch crime + collision data =====
    final allPoints =
        allCandidates.expand((r) => r.points).toList()
          ..addAll([origin, destination]);
    final bbox = GeoUtils.boundingBox(allPoints, paddingDegrees: 0.01);

    final phase5 = await Future.wait<dynamic>([
      _crimeRepo.getCrimesInArea(southWest: bbox.sw, northEast: bbox.ne),
      _collisionRepo.getCollisionsInArea(
          southWest: bbox.sw, northEast: bbox.ne),
    ]);

    final crimes = phase5[0] as List<CrimeIncident>;
    final collisions = phase5[1] as List<Collision>;

    print('RouteService: ${crimes.length} crimes, ${collisions.length} collisions');

    // ===== PHASE 6: Score all candidates =====
    final scored = <RouteData>[];
    for (final route in allCandidates) {
      final infraScore = await _infraRepo.calculateSidewalkScore(
        routePoints: route.points,
        southWest: bbox.sw,
        northEast: bbox.ne,
      );

      final score = _scorer.calculateScore(
        routePoints: route.points,
        crimes: crimes,
        lights: lights,
        collisions: collisions,
        safeSpaces: safeSpaces,
        infrastructureScore: infraScore,
      );

      final segments = _scorer.generateSegments(
        routePoints: route.points,
        crimes: crimes,
        lights: lights,
      );

      scored.add(route.copyWith(
        safetyScore: score.overall,
        segments: segments,
        crimesInBuffer: crimes
            .where((c) =>
                GeoUtils.isPointNearRoute(c.location, route.points, 100))
            .length,
        lightingCoverage: score.lightingScore,
        collisionsNearby: collisions
            .where((c) =>
                GeoUtils.isPointNearRoute(c.location, route.points, 100))
            .length,
        safeSpacesCount: safeSpaces
            .where((s) =>
                GeoUtils.isPointNearRoute(s.location, route.points, 200))
            .length,
      ));
    }

    // ===== PHASE 7: Cost-penalty ranking =====
    final classified = _rankWithCostPenalty(scored);

    print('RouteService: Ranked routes — '
        'fastest: ${classified[0].distanceMeters.round()}m, '
        'balanced: ${classified[1].distanceMeters.round()}m, '
        'safest: ${classified[2].distanceMeters.round()}m');

    // ===== PHASE 8: AI summaries =====
    final withSummaries = await Future.wait(
      classified.map((route) async {
        final summary = await _gemini.generateRouteSummary(route);
        return route.copyWith(aiSummary: summary);
      }),
    );

    return withSummaries;
  }

  /// Geocode a search query
  Future<List<({String displayName, LatLng location})>> searchDestination(
      String query) {
    return _routeRepo.geocode(query);
  }

  /// Cost-penalty ranking to select 3 genuinely different routes.
  ///
  /// - **Fastest** = lowest duration (pure speed)
  /// - **Balanced** = lowest "darkness cost" = distance × (1 + darkness_penalty)
  ///   Where darkness_penalty = (1 - lightingCoverage/100).
  ///   A 2.5km well-lit route beats a 2.0km dark route.
  /// - **Safest** = highest overall safety score (considers crime, lights,
  ///   collisions, safe spaces, infrastructure)
  List<RouteData> _rankWithCostPenalty(List<RouteData> scored) {
    if (scored.isEmpty) return [];
    if (scored.length == 1) {
      return [
        scored[0].copyWith(type: RouteType.fastest),
        scored[0].copyWith(type: RouteType.balanced),
        scored[0].copyWith(type: RouteType.safest),
      ];
    }

    // STEP 1: SAFEST — highest safety score (non-negotiable, must be the top scorer)
    final bySafety = List<RouteData>.from(scored)
      ..sort((a, b) => b.safetyScore.compareTo(a.safetyScore));
    final safestRoute = bySafety.first.copyWith(type: RouteType.safest);

    // STEP 2: FASTEST — lowest duration (from remaining routes)
    final remaining = scored.where((r) => r.id != safestRoute.id).toList();
    remaining.sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    final fastestRoute = remaining.isNotEmpty
        ? remaining.first.copyWith(type: RouteType.fastest)
        : bySafety.last.copyWith(type: RouteType.fastest);

    // STEP 3: BALANCED — best "brightness cost" from whatever is left
    // Cost = distance × (1 + 0.6 × darkness_penalty)
    // A dark route (0% lit) → cost = distance × 1.6
    // A bright route (100% lit) → cost = distance × 1.0
    final balancedCandidates = scored
        .where((r) => r.id != safestRoute.id && r.id != fastestRoute.id)
        .toList();

    RouteData balancedRoute;
    if (balancedCandidates.isNotEmpty) {
      balancedCandidates.sort((a, b) {
        final darkA = 0.6 * (1.0 - a.lightingCoverage / 100.0);
        final darkB = 0.6 * (1.0 - b.lightingCoverage / 100.0);
        final costA = a.distanceMeters * (1.0 + darkA);
        final costB = b.distanceMeters * (1.0 + darkB);
        return costA.compareTo(costB);
      });
      balancedRoute = balancedCandidates.first.copyWith(type: RouteType.balanced);
    } else {
      // Only 2 routes: use the one that's not safest
      balancedRoute = remaining.isNotEmpty
          ? remaining.last.copyWith(type: RouteType.balanced)
          : bySafety.last.copyWith(type: RouteType.balanced);
    }

    return [fastestRoute, balancedRoute, safestRoute];
  }

  /// Check if a new route is meaningfully different from ALL existing routes.
  bool _isRouteDifferent(RouteData newRoute, List<RouteData> existing) {
    for (final e in existing) {
      if (!_twoRoutesDiffer(newRoute, e)) return false;
    }
    return true;
  }

  /// Returns true if two routes are meaningfully different.
  /// Distance differs by >5% OR geometric overlap is <80%.
  bool _twoRoutesDiffer(RouteData a, RouteData b) {
    final avgDist = (a.distanceMeters + b.distanceMeters) / 2;
    if (avgDist > 0) {
      final distDiff = (a.distanceMeters - b.distanceMeters).abs();
      if (distDiff / avgDist > 0.05) return true;
    }

    final sampleCount = 10;
    if (b.points.length < sampleCount) return true;

    final step = b.points.length ~/ sampleCount;
    int nearCount = 0;
    for (int i = 0; i < sampleCount; i++) {
      final samplePoint = b.points[i * step];
      if (GeoUtils.isPointNearRoute(samplePoint, a.points, 50)) {
        nearCount++;
      }
    }

    return nearCount / sampleCount < 0.80;
  }
}

/// Internal helper to pair waypoint id + location
class _WaypointSpec {
  final String id;
  final LatLng waypoint;
  const _WaypointSpec(this.id, this.waypoint);
}
