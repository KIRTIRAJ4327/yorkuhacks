import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/utils/geo_utils.dart';
import '../data/models/crime_incident.dart';
import '../data/models/route_data.dart';
import '../data/models/safe_space.dart';
import '../data/models/safety_score.dart';
import '../data/models/street_light.dart';

/// Calculates 0-100 safety scores for walking routes
class SafetyScorer {
  /// Calculate overall safety score for a route
  SafetyScore calculateScore({
    required List<LatLng> routePoints,
    required List<CrimeIncident> crimes,
    required List<StreetLight> lights,
    required List<SafeSpace> safeSpaces,
    int collisionsNearby = 0,
    bool hasSidewalk = true,
  }) {
    // 1. Crime score (40%) — fewer crimes = higher score
    final crimesInBuffer = _countCrimesNearRoute(
      routePoints,
      crimes,
      AppConstants.routeBufferMeters,
    );
    final crimeScore = (100 -
            (crimesInBuffer / AppConstants.maxExpectedCrimes * 100))
        .clamp(0.0, 100.0);

    // 2. Lighting score (25%) — more lights = higher score
    final lightingScore = _calculateLightingCoverage(routePoints, lights);

    // 3. Collision score (15%) — fewer = higher
    final collisionScore = (100 -
            (collisionsNearby / AppConstants.maxExpectedCollisions * 100))
        .clamp(0.0, 100.0);

    // 4. Safe spaces score (10%) — nearby safe spaces
    final safeSpaceCount = _countSafeSpacesNearRoute(
      routePoints,
      safeSpaces,
      AppConstants.safeSpaceRadiusMeters,
    );
    final safeSpaceScore = min(safeSpaceCount * 20.0, 100.0);

    // 5. Infrastructure score (10%)
    final infraScore = (hasSidewalk ? 70.0 : 30.0) + 30.0; // Simplified

    // Weighted sum
    final overall = (crimeScore * AppConstants.weightCrime) +
        (lightingScore * AppConstants.weightLighting) +
        (collisionScore * AppConstants.weightCollision) +
        (safeSpaceScore * AppConstants.weightSafeSpaces) +
        (infraScore * AppConstants.weightInfrastructure);

    return SafetyScore(
      overall: overall.clamp(0, 100),
      crimeScore: crimeScore,
      lightingScore: lightingScore,
      collisionScore: collisionScore,
      safeSpaceScore: safeSpaceScore,
      infraScore: infraScore,
    );
  }

  /// Generate color-coded segments for a route
  List<RouteSegment> generateSegments({
    required List<LatLng> routePoints,
    required List<CrimeIncident> crimes,
    required List<StreetLight> lights,
    int segmentSize = 10,
  }) {
    final segments = <RouteSegment>[];

    for (int i = 0; i < routePoints.length - 1; i += segmentSize) {
      final end = min(i + segmentSize, routePoints.length - 1);
      final segmentPoints = routePoints.sublist(i, end + 1);

      // Score this segment individually
      final segCrimes = _countCrimesNearRoute(segmentPoints, crimes, 50);
      final segLit = _isSegmentLit(segmentPoints, lights);

      // Simple segment score
      double segScore = 70; // Base
      segScore -= segCrimes * 15; // Penalty per crime
      if (segLit) segScore += 20; // Bonus for lighting
      segScore = segScore.clamp(0, 100);

      segments.add(RouteSegment(
        start: routePoints[i],
        end: routePoints[end],
        safetyScore: segScore,
      ));
    }

    return segments;
  }

  int _countCrimesNearRoute(
    List<LatLng> points,
    List<CrimeIncident> crimes,
    double bufferMeters,
  ) {
    return crimes.where((crime) {
      return GeoUtils.isPointNearRoute(
        crime.location,
        points,
        bufferMeters,
      );
    }).length;
  }

  double _calculateLightingCoverage(
    List<LatLng> points,
    List<StreetLight> lights,
  ) {
    if (points.isEmpty) return 0;
    int litPoints = 0;

    for (final point in points) {
      final isLit = lights.any((light) {
        return GeoUtils.distanceInMeters(point, light.location) < 30;
      });
      if (isLit) litPoints++;
    }

    return (litPoints / points.length * 100).clamp(0, 100);
  }

  int _countSafeSpacesNearRoute(
    List<LatLng> points,
    List<SafeSpace> spaces,
    double radiusMeters,
  ) {
    final counted = <String>{};
    for (final point in points) {
      for (final space in spaces) {
        if (!counted.contains(space.id) &&
            GeoUtils.distanceInMeters(point, space.location) < radiusMeters) {
          counted.add(space.id);
        }
      }
    }
    return counted.length;
  }

  bool _isSegmentLit(List<LatLng> points, List<StreetLight> lights) {
    if (points.isEmpty) return false;
    // Consider lit if >50% of points have a light within 30m
    int litCount = 0;
    for (final p in points) {
      if (lights.any(
          (l) => GeoUtils.distanceInMeters(p, l.location) < 30)) {
        litCount++;
      }
    }
    return litCount > points.length * 0.5;
  }
}
