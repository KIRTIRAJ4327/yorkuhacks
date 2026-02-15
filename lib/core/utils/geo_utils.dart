import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../data/models/street_light.dart';
import '../../data/models/safe_space.dart';

/// Geospatial utility functions
class GeoUtils {
  GeoUtils._();

  static const Distance _distance = Distance();

  /// Calculate distance between two points in meters
  static double distanceInMeters(LatLng a, LatLng b) {
    return _distance.as(LengthUnit.Meter, a, b);
  }

  /// Check if a point is within a buffer distance of a route segment
  static bool isPointNearRoute(
    LatLng point,
    List<LatLng> routePoints,
    double bufferMeters,
  ) {
    for (int i = 0; i < routePoints.length - 1; i++) {
      final dist =
          distanceToSegment(point, routePoints[i], routePoints[i + 1]);
      if (dist <= bufferMeters) return true;
    }
    return false;
  }

  /// Perpendicular distance from a point to a line segment
  static double distanceToSegment(
      LatLng point, LatLng segStart, LatLng segEnd) {
    final dx = segEnd.longitude - segStart.longitude;
    final dy = segEnd.latitude - segStart.latitude;

    if (dx == 0 && dy == 0) {
      return distanceInMeters(point, segStart);
    }

    var t = ((point.longitude - segStart.longitude) * dx +
            (point.latitude - segStart.latitude) * dy) /
        (dx * dx + dy * dy);

    t = t.clamp(0.0, 1.0);

    final nearest = LatLng(
      segStart.latitude + t * dy,
      segStart.longitude + t * dx,
    );

    return distanceInMeters(point, nearest);
  }

  /// Calculate bounding box around a list of points with padding
  static ({LatLng sw, LatLng ne}) boundingBox(
    List<LatLng> points, {
    double paddingDegrees = 0.005,
  }) {
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLng = double.infinity;
    var maxLng = double.negativeInfinity;

    for (final p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    return (
      sw: LatLng(minLat - paddingDegrees, minLng - paddingDegrees),
      ne: LatLng(maxLat + paddingDegrees, maxLng + paddingDegrees),
    );
  }

  /// Calculate bearing between two points (degrees, 0-360)
  static double bearing(LatLng from, LatLng to) {
    final dLng = _toRadians(to.longitude - from.longitude);
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    return (_toDegrees(atan2(y, x)) + 360) % 360;
  }

  /// Total route distance in meters
  static double totalRouteDistance(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distanceInMeters(points[i], points[i + 1]);
    }
    return total;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
  static double _toDegrees(double radians) => radians * 180 / pi;

  /// Midpoint between two coordinates
  static LatLng midpoint(LatLng a, LatLng b) {
    return LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
  }

  // ==================================================================
  // PERPENDICULAR OFFSET WAYPOINT GENERATION
  // ==================================================================

  /// Move a point by [distMeters] along a [bearingDeg] (degrees).
  /// Uses Vincenty-like forward formula on a sphere.
  static LatLng movePoint(LatLng point, double bearingDeg, double distMeters) {
    const R = 6371000.0; // Earth radius in meters
    final lat1 = _toRadians(point.latitude);
    final lng1 = _toRadians(point.longitude);
    final brng = _toRadians(bearingDeg);
    final d = distMeters / R;

    final lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng));
    final lng2 = lng1 +
        atan2(
            sin(brng) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2));

    return LatLng(_toDegrees(lat2), _toDegrees(lng2));
  }

  /// Generate perpendicular offset waypoints for route diversification.
  ///
  /// Creates a grid of candidate waypoints OFFSET from the direct line
  /// between origin and destination, at perpendicular distances left and right.
  ///
  /// Example with fractions=[0.3, 0.5, 0.7] and offsets=[300, 500]:
  /// ```
  ///        O (origin)
  ///        |
  ///   L2 L1 + R1 R2   ← 30% along corridor
  ///        |
  ///   L2 L1 + R1 R2   ← 50% (midpoint)
  ///        |
  ///   L2 L1 + R1 R2   ← 70% along corridor
  ///        |
  ///        D (destination)
  /// ```
  ///
  /// Returns a list of candidate waypoints (NOT on the direct line).
  static List<LatLng> generatePerpendicularWaypoints({
    required LatLng origin,
    required LatLng destination,
    List<double> fractions = const [0.30, 0.50, 0.70],
    List<double> offsetMeters = const [300, 500],
  }) {
    final corridorBearing = bearing(origin, destination);
    final leftBearing = (corridorBearing - 90 + 360) % 360;
    final rightBearing = (corridorBearing + 90) % 360;

    final waypoints = <LatLng>[];

    for (final fraction in fractions) {
      // Point on the direct line at this fraction
      final onLine = LatLng(
        origin.latitude +
            (destination.latitude - origin.latitude) * fraction,
        origin.longitude +
            (destination.longitude - origin.longitude) * fraction,
      );

      // Offset left and right at each distance
      for (final offset in offsetMeters) {
        waypoints.add(movePoint(onLine, leftBearing, offset));
        waypoints.add(movePoint(onLine, rightBearing, offset));
      }
    }

    return waypoints;
  }

  /// Select the BRIGHTEST waypoint — the one nearest to the densest
  /// cluster of street lights, OFFSET perpendicular from direct path.
  ///
  /// Returns null only if there are zero lights.
  static LatLng? selectBrightestWaypoint({
    required LatLng origin,
    required LatLng destination,
    required List<StreetLight> lights,
    double searchRadiusMeters = 500,
    double maxDetourFraction = 0.40,
  }) {
    if (lights.isEmpty) return null;

    final directDist = distanceInMeters(origin, destination);
    // Generate offset candidates (NOT on the direct line)
    final candidates = generatePerpendicularWaypoints(
      origin: origin,
      destination: destination,
      fractions: const [0.25, 0.40, 0.55, 0.70],
      offsetMeters: const [250, 450],
    );

    LatLng? bestPoint;
    int bestCount = 0; // Accept any lights (was 2 before → too strict)

    for (final candidate in candidates) {
      // Check detour budget
      final detour = distanceInMeters(origin, candidate) +
          distanceInMeters(candidate, destination);
      if (detour > directDist * (1 + maxDetourFraction)) continue;

      // Count lights near this candidate
      int count = 0;
      for (final light in lights) {
        if (distanceInMeters(candidate, light.location) <=
            searchRadiusMeters) {
          count++;
        }
      }

      if (count > bestCount) {
        bestCount = count;
        bestPoint = candidate;
      }
    }

    // Fallback: if no lights found near offsets, use the offset closest to
    // the densest light cluster anywhere
    if (bestPoint == null && lights.length >= 3) {
      // Find centroid of lights
      double latSum = 0, lngSum = 0;
      for (final l in lights) {
        latSum += l.location.latitude;
        lngSum += l.location.longitude;
      }
      final centroid =
          LatLng(latSum / lights.length, lngSum / lights.length);

      // Use centroid if within detour budget
      final detour = distanceInMeters(origin, centroid) +
          distanceInMeters(centroid, destination);
      if (detour <= directDist * (1 + maxDetourFraction)) {
        bestPoint = centroid;
      }
    }

    return bestPoint;
  }

  /// Select the best SAFE HAVEN waypoint — OFFSET toward police stations,
  /// hospitals, transit stops, 24/7 stores.
  ///
  /// Returns null only if there are zero safe spaces within budget.
  static LatLng? selectSafeHavenWaypoint({
    required LatLng origin,
    required LatLng destination,
    required List<SafeSpace> safeSpaces,
    double maxDetourFraction = 0.40,
  }) {
    if (safeSpaces.isEmpty) return null;

    final directDist = distanceInMeters(origin, destination);
    final mid = midpoint(origin, destination);

    int typeScore(SafeSpaceType type) {
      switch (type) {
        case SafeSpaceType.police:
          return 5;
        case SafeSpaceType.hospital:
          return 4;
        case SafeSpaceType.fireStation:
          return 3;
        case SafeSpaceType.pharmacy:
          return 2;
        case SafeSpaceType.transitStop:
          return 1;
        case SafeSpaceType.other:
          return 1;
      }
    }

    SafeSpace? bestSpace;
    double bestScore = -1;

    for (final space in safeSpaces) {
      final detour = distanceInMeters(origin, space.location) +
          distanceInMeters(space.location, destination);
      if (detour > directDist * (1 + maxDetourFraction)) continue;

      final distToMid = distanceInMeters(space.location, mid);
      final maxMidDist = directDist / 2;
      final proximityBonus =
          maxMidDist > 0 ? (1 - (distToMid / maxMidDist).clamp(0, 1)) : 0.5;

      double score = typeScore(space.type).toDouble();
      if (space.isOpen24h) score += 2;
      score += proximityBonus * 2;

      if (score > bestScore) {
        bestScore = score;
        bestSpace = space;
      }
    }

    return bestSpace?.location;
  }

  /// Generate a pure perpendicular offset waypoint at the midpoint.
  /// This is a guaranteed "different" waypoint — useful as a last-resort
  /// alternative when brightness/haven waypoints fail.
  static LatLng offsetMidpoint({
    required LatLng origin,
    required LatLng destination,
    required double offsetMeters,
    bool left = true,
  }) {
    final corridorBearing = bearing(origin, destination);
    final perpBearing = left
        ? (corridorBearing - 90 + 360) % 360
        : (corridorBearing + 90) % 360;

    final mid = midpoint(origin, destination);
    return movePoint(mid, perpBearing, offsetMeters);
  }
}
