import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../core/utils/geo_utils.dart';
import '../data/models/route_data.dart';

/// Turn instruction for navigation
class TurnInstruction {
  final String text;
  final double distanceMeters;
  final String? landmark;
  final LatLng location;

  const TurnInstruction({
    required this.text,
    required this.distanceMeters,
    this.landmark,
    required this.location,
  });
}

/// Navigation state
class NavigationState {
  final LatLng currentPosition;
  final int currentSegmentIndex;
  final TurnInstruction? nextTurn;
  final double remainingDistance;
  final int remainingSeconds;
  final double currentSegmentSafety;
  final bool hasArrived;

  const NavigationState({
    required this.currentPosition,
    this.currentSegmentIndex = 0,
    this.nextTurn,
    this.remainingDistance = 0,
    this.remainingSeconds = 0,
    this.currentSegmentSafety = 100,
    this.hasArrived = false,
  });
}

/// Turn-by-turn navigation engine
class NavigationEngine {
  RouteData? _activeRoute;
  final _stateController = StreamController<NavigationState>.broadcast();

  Stream<NavigationState> get stateStream => _stateController.stream;
  RouteData? get activeRoute => _activeRoute;

  /// Start navigation on a route
  void startNavigation(RouteData route) {
    _activeRoute = route;

    if (route.points.isNotEmpty) {
      _stateController.add(NavigationState(
        currentPosition: route.points.first,
        remainingDistance: route.distanceMeters,
        remainingSeconds: route.durationSeconds,
        currentSegmentSafety: route.safetyScore,
      ));
    }
  }

  /// Update position during navigation
  void updatePosition(LatLng position) {
    if (_activeRoute == null) return;

    final route = _activeRoute!;
    final points = route.points;

    // Find closest point on route
    int closestIndex = 0;
    double minDist = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final dist = GeoUtils.distanceInMeters(position, points[i]);
      if (dist < minDist) {
        minDist = dist;
        closestIndex = i;
      }
    }

    // Calculate remaining distance
    double remaining = 0;
    for (int i = closestIndex; i < points.length - 1; i++) {
      remaining += GeoUtils.distanceInMeters(points[i], points[i + 1]);
    }

    // Check if arrived (within 20m of destination)
    final hasArrived = GeoUtils.distanceInMeters(
            position, points.last) <
        20;

    // Generate next turn instruction
    final nextTurn = _getNextTurn(points, closestIndex);

    // Current segment safety
    double segSafety = route.safetyScore;
    if (route.segments.isNotEmpty) {
      final segIdx = (closestIndex / 10).floor().clamp(
          0, route.segments.length - 1);
      segSafety = route.segments[segIdx].safetyScore;
    }

    // Estimate remaining time (walking speed ~1.4 m/s)
    final remainingSec = (remaining / 1.4).round();

    _stateController.add(NavigationState(
      currentPosition: position,
      currentSegmentIndex: closestIndex,
      nextTurn: nextTurn,
      remainingDistance: remaining,
      remainingSeconds: remainingSec,
      currentSegmentSafety: segSafety,
      hasArrived: hasArrived,
    ));
  }

  /// Stop navigation
  void stopNavigation() {
    _activeRoute = null;
  }

  TurnInstruction? _getNextTurn(List<LatLng> points, int currentIndex) {
    // Look ahead for significant direction changes
    for (int i = currentIndex + 1; i < points.length - 1; i++) {
      if (i + 1 >= points.length) break;

      final bearing1 = GeoUtils.bearing(points[i - 1], points[i]);
      final bearing2 = GeoUtils.bearing(points[i], points[i + 1]);
      var diff = (bearing2 - bearing1).abs();
      if (diff > 180) diff = 360 - diff;

      // Significant turn (>30 degrees)
      if (diff > 30) {
        final dist = GeoUtils.distanceInMeters(
            points[currentIndex], points[i]);
        final direction = bearing2 > bearing1 ? 'right' : 'left';

        return TurnInstruction(
          text: 'Turn $direction in ${dist.round()}m',
          distanceMeters: dist,
          location: points[i],
        );
      }
    }

    // If no turn, show "Continue straight"
    if (currentIndex < points.length - 1) {
      final dist = GeoUtils.distanceInMeters(
          points[currentIndex], points.last);
      return TurnInstruction(
        text: 'Continue straight',
        distanceMeters: dist,
        location: points[currentIndex],
      );
    }

    return null;
  }

  void dispose() {
    _stateController.close();
  }
}
