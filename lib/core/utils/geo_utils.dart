import 'dart:math';
import 'package:latlong2/latlong.dart';

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
      final dist = distanceToSegment(point, routePoints[i], routePoints[i + 1]);
      if (dist <= bufferMeters) return true;
    }
    return false;
  }

  /// Perpendicular distance from a point to a line segment
  static double distanceToSegment(LatLng point, LatLng segStart, LatLng segEnd) {
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

  /// Calculate bearing between two points (degrees)
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
}
