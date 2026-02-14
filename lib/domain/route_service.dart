import 'package:latlong2/latlong.dart';
import '../core/utils/geo_utils.dart';
import '../data/models/crime_incident.dart';
import '../data/models/route_data.dart';
import '../data/models/safe_space.dart';
import '../data/models/street_light.dart';
import '../data/repositories/crime_repository.dart';
import '../data/repositories/lighting_repository.dart';
import '../data/repositories/route_repository.dart';
import '../data/repositories/safe_spaces_repository.dart';
import 'gemini_service.dart';
import 'safety_scorer.dart';

/// Orchestrates route generation, scoring, and AI summaries
class RouteService {
  final RouteRepository _routeRepo;
  final CrimeRepository _crimeRepo;
  final LightingRepository _lightingRepo;
  final SafeSpacesRepository _safeSpacesRepo;
  final SafetyScorer _scorer;
  final GeminiService _gemini;

  RouteService({
    required RouteRepository routeRepo,
    required CrimeRepository crimeRepo,
    required LightingRepository lightingRepo,
    required SafeSpacesRepository safeSpacesRepo,
    required SafetyScorer scorer,
    required GeminiService gemini,
  })  : _routeRepo = routeRepo,
        _crimeRepo = crimeRepo,
        _lightingRepo = lightingRepo,
        _safeSpacesRepo = safeSpacesRepo,
        _scorer = scorer,
        _gemini = gemini;

  /// Generate 3 optimized routes: fastest, balanced, safest
  Future<List<RouteData>> generateRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // 1. Get raw routes from OSRM
    final rawRoutes = await _routeRepo.getRoutes(origin, destination);
    if (rawRoutes.isEmpty) return [];

    // 2. Get all points from all routes for bounding box
    final allPoints = rawRoutes.expand((r) => r.points).toList();
    allPoints.addAll([origin, destination]);
    final bbox = GeoUtils.boundingBox(allPoints, paddingDegrees: 0.01);

    // 3. Fetch safety data in parallel
    final results = await Future.wait([
      _crimeRepo.getCrimesInArea(southWest: bbox.sw, northEast: bbox.ne),
      _lightingRepo.getLightsInArea(southWest: bbox.sw, northEast: bbox.ne),
      _safeSpacesRepo.getSafeSpaces(southWest: bbox.sw, northEast: bbox.ne),
    ]);

    final crimes = results[0] as List<CrimeIncident>;
    final lights = results[1] as List<StreetLight>;
    final safeSpaces = results[2] as List<SafeSpace>;

    // 4. Score each route
    final scoredRoutes = <RouteData>[];

    for (final route in rawRoutes) {
      final score = _scorer.calculateScore(
        routePoints: route.points,
        crimes: crimes,
        lights: lights,
        safeSpaces: safeSpaces,
      );

      final segments = _scorer.generateSegments(
        routePoints: route.points,
        crimes: crimes,
        lights: lights,
      );

      scoredRoutes.add(route.copyWith(
        safetyScore: score.overall,
        segments: segments,
        crimesInBuffer: crimes
            .where((c) => GeoUtils.isPointNearRoute(
                  c.location,
                  route.points,
                  100,
                ))
            .length,
        lightingCoverage: score.lightingScore,
        safeSpacesCount: safeSpaces
            .where((s) => GeoUtils.isPointNearRoute(
                  s.location,
                  route.points,
                  200,
                ))
            .length,
      ));
    }

    // 5. Assign route types (fastest, balanced, safest)
    final classified = _classifyRoutes(scoredRoutes);

    // 6. Generate AI summaries (non-blocking, parallel)
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

  /// Classify routes as fastest / balanced / safest
  List<RouteData> _classifyRoutes(List<RouteData> routes) {
    if (routes.isEmpty) return [];
    if (routes.length == 1) {
      return [routes[0].copyWith(type: RouteType.balanced)];
    }

    // Sort by duration (fastest first)
    final byTime = List<RouteData>.from(routes)
      ..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));

    // Sort by safety (safest first)
    final bySafety = List<RouteData>.from(routes)
      ..sort((a, b) => b.safetyScore.compareTo(a.safetyScore));

    final fastest = byTime.first.copyWith(type: RouteType.fastest);
    final safest = bySafety.first.copyWith(type: RouteType.safest);

    // Find the balanced one (not fastest, not safest, or median)
    if (routes.length == 2) {
      return [fastest, safest];
    }

    // Balanced = the one that's neither fastest nor safest
    final balancedCandidates = routes.where((r) =>
        r.id != fastest.id && r.id != safest.id);

    final balanced = balancedCandidates.isNotEmpty
        ? balancedCandidates.first.copyWith(type: RouteType.balanced)
        : routes[1].copyWith(type: RouteType.balanced);

    return [fastest, balanced, safest];
  }
}
