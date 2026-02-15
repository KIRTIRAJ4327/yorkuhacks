import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/utils/geo_utils.dart';

/// Repository for fetching pedestrian infrastructure data from OpenStreetMap
/// Uses OSM's `sidewalk` tags to assess route walkability
class InfrastructureRepository {
  final Dio _dio;

  InfrastructureRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConstants.apiTimeout,
              receiveTimeout: AppConstants.apiTimeout,
            ));

  /// Calculates sidewalk score (0-100) for a route based on OSM sidewalk tags
  /// Returns percentage of route covered by roads with sidewalks
  Future<double> calculateSidewalkScore({
    required List<LatLng> routePoints,
    required LatLng southWest,
    required LatLng northEast,
  }) async {
    try {
      // Query OSM for roads with sidewalk tags in the area
      final bbox =
          '${southWest.latitude},${southWest.longitude},${northEast.latitude},${northEast.longitude}';
      final query = '''
[out:json][timeout:15];
way["highway"]["sidewalk"]($bbox);
out geom;
''';

      print('InfrastructureRepository: Fetching data from ${AppConstants.overpassBaseUrl}');

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

        // Calculate what percentage of route points are near roads with good sidewalks
        final score = _calculateRouteInfraScore(routePoints, elements);
        print('InfrastructureRepository: Success - calculated sidewalk score ${score.round()}/100 from ${elements.length} OSM ways');
        return score;
      }

      // API failed, return default moderate score
      return 70.0; // Assume sidewalks exist (conservative estimate)
    } catch (e) {
      print('InfrastructureRepository: Failed to fetch OSM data: $e');
      return 70.0; // Default to moderate sidewalk presence
    }
  }

  /// Calculates infrastructure score based on OSM sidewalk data
  /// Returns 0-100 score representing sidewalk quality along route
  double _calculateRouteInfraScore(
    List<LatLng> routePoints,
    List<dynamic> osmWays,
  ) {
    if (routePoints.isEmpty) return 50.0;

    int pointsWithGoodInfra = 0;

    for (final point in routePoints) {
      // Find nearest OSM way with sidewalk info
      final nearbyWay = _findNearestWay(point, osmWays, maxDistanceMeters: 30);

      if (nearbyWay != null) {
        final score = _scoreSidewalk(nearbyWay['tags'] as Map<String, dynamic>?);
        if (score >= 70) pointsWithGoodInfra++;
      }
      // Note: If no sidewalk data nearby, we don't count it as good infrastructure
      // This is conservative - only count confirmed sidewalks
    }

    return (pointsWithGoodInfra / routePoints.length * 100).clamp(0.0, 100.0);
  }

  /// Finds the nearest OSM way to a point
  Map<String, dynamic>? _findNearestWay(
    LatLng point,
    List<dynamic> ways, {
    double maxDistanceMeters = 30,
  }) {
    Map<String, dynamic>? nearest;
    double minDistance = maxDistanceMeters;

    for (final way in ways) {
      final geometry = way['geometry'] as List<dynamic>? ?? [];

      for (final geom in geometry) {
        final lat = (geom['lat'] as num).toDouble();
        final lon = (geom['lon'] as num).toDouble();
        final wayPoint = LatLng(lat, lon);

        final distance = GeoUtils.distanceInMeters(point, wayPoint);
        if (distance < minDistance) {
          minDistance = distance;
          nearest = way as Map<String, dynamic>;
        }
      }
    }

    return nearest;
  }

  /// Scores sidewalk quality based on OSM tags
  /// Returns 0-100 score
  double _scoreSidewalk(Map<String, dynamic>? tags) {
    if (tags == null) return 50.0;

    final sidewalk = tags['sidewalk'] as String? ?? '';

    // OSM sidewalk tag values and their scores
    switch (sidewalk.toLowerCase()) {
      case 'separate':
      case 'both':
        return 100.0; // Dedicated sidewalks on both sides
      case 'left':
      case 'right':
        return 75.0; // Sidewalk on one side
      case 'yes':
        return 85.0; // Sidewalk present (unspecified side)
      case 'no':
      case 'none':
        return 30.0; // No sidewalk
      default:
        return 60.0; // Unknown, assume moderate
    }
  }
}
