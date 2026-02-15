import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../models/street_light.dart';

/// Repository for fetching street lighting data from OpenStreetMap
/// Uses OSM's `lit` tags on roads to determine lighting coverage
class OsmLightingRepository {
  final Dio _dio;

  OsmLightingRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConstants.apiTimeout,
              receiveTimeout: AppConstants.apiTimeout,
            ));

  /// Fetches street lighting data using OpenStreetMap's `lit` tags
  /// Returns StreetLight points sampled along lit roads
  Future<List<StreetLight>> getLightsInArea({
    required LatLng southWest,
    required LatLng northEast,
  }) async {
    try {
      // Construct Overpass QL query for roads with lit tags
      final bbox =
          '${southWest.latitude},${southWest.longitude},${northEast.latitude},${northEast.longitude}';
      final query = '''
[out:json][timeout:15];
way["highway"]["lit"]($bbox);
out geom;
''';

      print('OsmLightingRepository: Fetching data from ${AppConstants.overpassBaseUrl}');

      final response = await _dio.post(
        AppConstants.overpassBaseUrl,
        data: 'data=$query',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];

        // Convert OSM ways to StreetLight points
        final lights = _convertOsmWaysToLights(elements);
        print('OsmLightingRepository: Success - fetched ${lights.length} street lights from ${elements.length} OSM ways');
        return lights;
      }

      // API returned non-200 or invalid data, fall back to samples
      return _generateSampleLights(southWest, northEast);
    } catch (e) {
      // Network error or parsing error, fall back to samples
      print('OsmLightingRepository: Failed to fetch OSM data, using samples: $e');
      return _generateSampleLights(southWest, northEast);
    }
  }

  /// Converts OSM way geometries to StreetLight points
  /// Samples lights along the road at regular intervals
  List<StreetLight> _convertOsmWaysToLights(List<dynamic> elements) {
    final lights = <StreetLight>[];
    var lightId = 0;

    for (final element in elements) {
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final geometry = element['geometry'] as List<dynamic>? ?? [];
      final litValue = tags['lit'] as String? ?? 'yes';
      final isLit = litValue == 'yes' || litValue == 'automatic';

      // Only create lights for lit roads
      if (!isLit) continue;

      // Sample lights along the road every ~3-5 points (represents ~30-50m spacing)
      for (int i = 0; i < geometry.length; i += 4) {
        final point = geometry[i] as Map<String, dynamic>;
        final lat = (point['lat'] as num).toDouble();
        final lon = (point['lon'] as num).toDouble();

        lights.add(StreetLight(
          id: 'osm_light_${lightId++}',
          location: LatLng(lat, lon),
          type: 'LED', // OSM doesn't specify type, assume modern LED
          isOperational: true, // OSM contributors mark non-working as lit=no
        ));
      }
    }

    return lights;
  }

  /// Generates sample lighting data when OSM query fails
  /// Uses same algorithm as original LightingRepository for consistency
  List<StreetLight> _generateSampleLights(LatLng southWest, LatLng northEast) {
    final latRange = (northEast.latitude - southWest.latitude).abs();
    final lngRange = (northEast.longitude - southWest.longitude).abs();

    // Generate 10-50 lights based on area size
    final count = ((latRange * lngRange * 50000).clamp(10, 50)).toInt();

    // Use deterministic seed for consistent results
    final seed = ((southWest.latitude + southWest.longitude) * 1000).toInt();
    final random = _DeterministicRandom(seed);

    final lights = <StreetLight>[];

    // Generate lights in grid pattern with jitter (simulates street layout)
    final gridSize = (count / 5).ceil();
    final latStep = latRange / gridSize;
    final lngStep = lngRange / gridSize;

    for (int i = 0; i < count; i++) {
      final gridLat = southWest.latitude + (i % gridSize) * latStep +
          random.nextDouble() * latStep * 0.3;
      final gridLng = southWest.longitude + (i ~/ gridSize) * lngStep +
          random.nextDouble() * lngStep * 0.3;

      lights.add(StreetLight(
        id: 'sample_light_$i',
        location: LatLng(gridLat, gridLng),
        type: random.nextDouble() < 0.33 ? 'LED' : 'HPS',
        isOperational: i % 7 != 0, // ~85% operational
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
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed % max;
  }

  double nextDouble() {
    return nextInt(1000000) / 1000000.0;
  }
}
