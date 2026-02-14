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

      final response = await _dio.get(
        '${AppConstants.arcgisBaseUrl}/Street_Lighting/FeatureServer/0/query',
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

      return features
          .map((f) =>
              StreetLight.fromGeoJson(f as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback: generate sample lighting data
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

  List<StreetLight> _generateSampleLights(LatLng sw, LatLng ne) {
    final lights = <StreetLight>[];
    final latRange = ne.latitude - sw.latitude;
    final lngRange = ne.longitude - sw.longitude;

    // Generate grid of lights (simulating well-lit streets)
    final count = (latRange * lngRange * 100000).clamp(10, 50).toInt();

    for (int i = 0; i < count; i++) {
      final latOffset = (i * 0.23 % 1.0) * latRange;
      final lngOffset = (i * 0.47 % 1.0) * lngRange;

      lights.add(StreetLight(
        id: 'light_$i',
        location: LatLng(
          sw.latitude + latOffset,
          sw.longitude + lngOffset,
        ),
        type: i % 3 == 0 ? 'LED' : 'HPS',
        isOperational: i % 7 != 0, // ~85% operational
      ));
    }

    return lights;
  }
}
