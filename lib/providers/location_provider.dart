import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

/// Current user location state
class LocationState {
  final LatLng? position;
  final bool isLoading;
  final String? error;
  final bool permissionGranted;

  const LocationState({
    this.position,
    this.isLoading = false,
    this.error,
    this.permissionGranted = false,
  });

  LocationState copyWith({
    LatLng? position,
    bool? isLoading,
    String? error,
    bool? permissionGranted,
  }) {
    return LocationState(
      position: position ?? this.position,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }
}

class LocationNotifier extends Notifier<LocationState> {
  StreamSubscription<Position>? _positionStream;

  @override
  LocationState build() => const LocationState();

  /// Request location permission and start tracking
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          error: 'Location services are disabled.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            error: 'Location permission denied.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          error: 'Location permission permanently denied.',
        );
        return;
      }

      state = state.copyWith(permissionGranted: true);

      // Get initial position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      state = state.copyWith(
        position: LatLng(position.latitude, position.longitude),
        isLoading: false,
      );

      // Start continuous tracking
      _startTracking();
    } catch (e) {
      // Fallback to York Region default
      state = state.copyWith(
        position: const LatLng(
          AppConstants.defaultLat,
          AppConstants.defaultLng,
        ),
        isLoading: false,
        error: 'Using default location (York Region)',
        permissionGranted: false,
      );
    }
  }

  void _startTracking() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((position) {
      state = state.copyWith(
        position: LatLng(position.latitude, position.longitude),
      );
    });
  }
}

final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);
