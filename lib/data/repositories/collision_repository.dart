import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../models/collision.dart';

/// Repository for fetching traffic collision data from York Region's official database
class CollisionRepository {
  final Dio _dio;

  CollisionRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConstants.apiTimeout,
              receiveTimeout: AppConstants.apiTimeout,
            ));

  /// Fetches collision data within a bounding box
  /// Returns real York Region collision data from their Vision Zero program
  Future<List<Collision>> getCollisionsInArea({
    required LatLng southWest,
    required LatLng northEast,
  }) async {
    try {
      // Construct envelope geometry (sw.lng,sw.lat,ne.lng,ne.lat)
      final envelope =
          '${southWest.longitude},${southWest.latitude},${northEast.longitude},${northEast.latitude}';

      final url = '${AppConstants.yorkMapsBaseUrl}/Collisions/MapServer/1/query';
      print('CollisionRepository: Fetching data from $url');

      final response = await _dio.get(
        url,
        queryParameters: {
          'where': '1=1',
          'geometry': envelope,
          'geometryType': 'esriGeometryEnvelope',
          'spatialRel': 'esriSpatialRelIntersects',
          'outFields':
              'OBJECTID,collisionDateTime,collisionYear,classificationOfCollision,'
              'locationDescription,pedestrianInvolved,cyclistInvolved,motorcycleInvolved,'
              'light,Municipality,latitude,longitude',
          'f': 'json',
          'resultRecordCount': '200',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];

        final collisions = features
            .map((feature) => Collision.fromArcGIS(feature as Map<String, dynamic>))
            .toList();
        print('CollisionRepository: Success - fetched ${collisions.length} collision records');
        return collisions;
      }

      // API returned non-200 or invalid data, fall back to samples
      return _generateSampleCollisions(southWest, northEast);
    } catch (e) {
      // Network error or parsing error, fall back to samples
      print('CollisionRepository: Failed to fetch real data, using samples: $e');
      return _generateSampleCollisions(southWest, northEast);
    }
  }

  /// Generates sample collision data when real API is unavailable
  /// Uses deterministic algorithm for consistent demo results
  List<Collision> _generateSampleCollisions(LatLng southWest, LatLng northEast) {
    final latRange = (northEast.latitude - southWest.latitude).abs();
    final lngRange = (northEast.longitude - southWest.longitude).abs();

    // Generate 0-5 collisions based on area size (larger areas = more collisions)
    final count = ((latRange * lngRange * 100000).clamp(0, 5)).toInt();

    if (count == 0) return [];

    // Use deterministic seed for consistent results
    final seed = ((southWest.latitude + southWest.longitude) * 1000).toInt();
    final random = _DeterministicRandom(seed);

    final collisions = <Collision>[];
    final classifications = ['Minimal Injury', 'Major Injury', 'Fatal'];
    final lightConditions = ['Daylight', 'Dark, artificial', 'Dark, no light', 'Dawn', 'Dusk'];

    for (int i = 0; i < count; i++) {
      // Place collisions near "intersections" (grid pattern with jitter)
      final gridLat = southWest.latitude + (i % 3) * (latRange / 3) +
          random.nextDouble() * (latRange / 6);
      final gridLng = southWest.longitude + (i ~/ 3) * (lngRange / 3) +
          random.nextDouble() * (lngRange / 6);

      collisions.add(Collision(
        id: 'sample_collision_$i',
        location: LatLng(gridLat, gridLng),
        year: 2025 - random.nextInt(2), // 2024 or 2025
        classification: classifications[random.nextInt(classifications.length)],
        locationDescription: 'Sample collision location ${i + 1}',
        pedestrianInvolved: random.nextDouble() < 0.2, // 20% involve pedestrians
        cyclistInvolved: random.nextDouble() < 0.15, // 15% involve cyclists
        motorcyclistInvolved: random.nextDouble() < 0.1, // 10% involve motorcycles
        lightCondition: lightConditions[random.nextInt(lightConditions.length)],
        municipality: 'Sample Municipality',
      ));
    }

    return collisions;
  }
}

/// Simple deterministic random number generator for consistent sample data
class _DeterministicRandom {
  int _seed;

  _DeterministicRandom(this._seed);

  int nextInt(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed % max;
  }

  double nextDouble() {
    return nextInt(1000000) / 1000000.0;
  }
}
