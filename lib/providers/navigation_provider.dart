import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/models/route_data.dart';
import '../domain/navigation_engine.dart';

class NavigationNotifier extends Notifier<NavigationState?> {
  final NavigationEngine _engine = NavigationEngine();
  StreamSubscription<NavigationState>? _subscription;

  @override
  NavigationState? build() => null;

  NavigationEngine get engine => _engine;

  void startNavigation(RouteData route) {
    _subscription?.cancel();
    // Subscribe BEFORE starting so we don't miss the first emission
    _subscription = _engine.stateStream.listen((navState) {
      state = navState;
    });
    _engine.startNavigation(route);

    // Also set initial state directly (broadcast stream may lose first event)
    if (route.points.isNotEmpty) {
      state = NavigationState(
        currentPosition: route.points.first,
        remainingDistance: route.distanceMeters,
        remainingSeconds: route.durationSeconds,
        currentSegmentSafety: route.safetyScore,
      );
    }
  }

  void updatePosition(LatLng position) {
    _engine.updatePosition(position);
  }

  void stopNavigation() {
    _subscription?.cancel();
    _engine.stopNavigation();
    state = null;
  }
}

final navigationProvider =
    NotifierProvider<NavigationNotifier, NavigationState?>(
  NavigationNotifier.new,
);
