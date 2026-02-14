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
    _engine.startNavigation(route);
    _subscription?.cancel();
    _subscription = _engine.stateStream.listen((navState) {
      state = navState;
    });
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
