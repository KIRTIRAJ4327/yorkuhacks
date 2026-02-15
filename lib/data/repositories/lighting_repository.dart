import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../models/street_light.dart';

/// Fetches street lighting data from York Region Open Data
class LightingRepository {
  final Dio _dio;

  LightingRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConstants.apiTimeout,
              receiveTimeout: AppConstants.apiTimeout,
            ));

  /// Query street lights near a route
  Future<List<StreetLight>> getLightsInArea({
    required LatLng southWest,
    required LatLng northEast,
  }) async {
    try {
      final envelope =
          '${southWest.longitude},${southWest.latitude},'
          '${northEast.longitude},${northEast.latitude}';

      final url = '${AppConstants.arcgisBaseUrl}/Street_Lighting/FeatureServer/0/query';
      print('LightingRepository: Fetching lighting data from $url');

      final response = await _dio.get(
        url,
        queryParameters: {
          'where': '1=1',
          'geometry': envelope,
          'geometryType': 'esriGeometryEnvelope',
          'inSR': '4326',
          'outSR': '4326',
          'spatialRel': 'esriSpatialRelIntersects',
          'outFields': '*',
          'f': 'geojson',
          'resultRecordCount': '500',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];

      final lights = features
          .map((f) =>
              StreetLight.fromGeoJson(f as Map<String, dynamic>))
          .toList();
      print('LightingRepository: Success - fetched ${lights.length} street lights');
      return lights;
    } catch (e) {
      // Fallback: generate sample lighting data
      print('LightingRepository: Failed to fetch ArcGIS lighting data: $e');
      print('LightingRepository: Using sample lighting data');
      return _generateSampleLights(southWest, northEast);
    }
  }

  /// Calculate lighting coverage percentage for a route
  double calculateCoverage(
    List<LatLng> routePoints,
    List<StreetLight> lights, {
    double radiusMeters = 30.0,
  }) {
    if (routePoints.isEmpty) return 0;

    int litSegments = 0;
    final totalSegments = routePoints.length;

    for (final point in routePoints) {
      final isLit = lights.any((light) {
        final dx = point.latitude - light.location.latitude;
        final dy = point.longitude - light.location.longitude;
        // Rough meter conversion (1 degree ~ 111km)
        final distMeters =
            (dx * dx + dy * dy) * 111000 * 111000;
        return distMeters < radiusMeters * radiusMeters * 111 * 111;
      });

      if (isLit) litSegments++;
    }

    return (litSegments / totalSegments * 100).clamp(0, 100);
  }

  /// Generate realistic fallback lighting data when API is unavailable
  /// Uses deterministic random generation with realistic clustering patterns
  List<StreetLight> _generateSampleLights(LatLng sw, LatLng ne) {
    final lights = <StreetLight>[];
    final latRange = ne.latitude - sw.latitude;
    final lngRange = ne.longitude - sw.longitude;

    // Deterministic seed based on coordinates
    final seed = ((sw.latitude + sw.longitude) * 1000).toInt();
    final random = _DeterministicRandom(seed);

    // Generate 10-50 lights based on area size
    final count = (latRange * lngRange * 100000).clamp(10, 50).toInt();

    // Create 3-5 "major road" clusters (simulating lit streets)
    final numClusters = random.nextInt(3) + 3; // 3-5 clusters
    final clusters = List.generate(
      numClusters,
      (i) => LatLng(
        sw.latitude + random.nextDouble() * latRange,
        sw.longitude + random.nextDouble() * lngRange,
      ),
    );

    for (int i = 0; i < count; i++) {
      // 70% cluster along major roads, 30% dispersed
      final useCluster = random.nextDouble() < 0.7;
      final LatLng location;

      if (useCluster) {
        // Place near a major road cluster with spacing
        final cluster = clusters[random.nextInt(clusters.length)];
        final jitterLat = (random.nextDouble() - 0.5) * latRange * 0.15;
        final jitterLng = (random.nextDouble() - 0.5) * lngRange * 0.15;
        location = LatLng(
          (cluster.latitude + jitterLat).clamp(sw.latitude, ne.latitude),
          (cluster.longitude + jitterLng).clamp(sw.longitude, ne.longitude),
        );
      } else {
        // Random location (residential streets)
        location = LatLng(
          sw.latitude + random.nextDouble() * latRange,
          sw.longitude + random.nextDouble() * lngRange,
        );
      }

      // Modern areas tend to have LED, older areas HPS
      final lightType = random.nextDouble() < 0.65 ? 'LED' : 'HPS';

      // ~90% operational (realistic maintenance level)
      final isOperational = random.nextDouble() < 0.90;

      lights.add(StreetLight(
        id: 'fallback_light_$i',
        location: location,
        type: lightType,
        isOperational: isOperational,
      ));
    }

    return lights;
  }
}

/// Simple deterministic random number generator for consistent sample data
class _DeterministicRandom {
  int _seed;

  _DeterministicRandom(this._seed);

  int nextInt(int max) {
    if (max <= 0) return 0;
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed % max;
  }

  double nextDouble() {
    return nextInt(1000000) / 1000000.0;
  }
}
