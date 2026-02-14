import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../models/route_data.dart';

/// Fetches walking routes from OSRM
class RouteRepository {
  final Dio _dio;

  RouteRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConstants.apiTimeout,
              receiveTimeout: AppConstants.apiTimeout,
            ));

  /// Get walking routes between two points
  /// Returns up to 3 alternative routes
  Future<List<RouteData>> getRoutes(LatLng origin, LatLng destination) async {
    final url =
        '${AppConstants.osrmBaseUrl}/route/v1/foot/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?alternatives=3&overview=full&geometries=geojson&steps=true';

    final response = await _dio.get(url);
    final data = response.data as Map<String, dynamic>;

    if (data['code'] != 'Ok') {
      throw Exception('OSRM routing failed: ${data['code']}');
    }

    final routes = data['routes'] as List;

    return routes.asMap().entries.map((entry) {
      final route = entry.value as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;

      final points = coordinates.map<LatLng>((coord) {
        final c = coord as List;
        return LatLng(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        );
      }).toList();

      return RouteData(
        id: 'route_${entry.key}',
        points: points,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toInt(),
        safetyScore: 0, // Will be calculated by SafetyScorer
        type: RouteType.fastest, // Will be assigned by RouteService
      );
    }).toList();
  }

  /// Geocode an address to coordinates using Nominatim
  Future<List<({String displayName, LatLng location})>> geocode(
      String query) async {
    final response = await _dio.get(
      '${AppConstants.nominatimBaseUrl}/search',
      queryParameters: {
        'q': query,
        'format': 'json',
        'countrycodes': 'ca',
        'limit': '5',
        'viewbox': '-79.6,-79.1,43.7,44.1', // York Region bounding box
        'bounded': '0',
      },
      options: Options(headers: {
        'User-Agent': AppConstants.nominatimUserAgent,
      }),
    );

    final results = response.data as List;

    return results.map((r) {
      final item = r as Map<String, dynamic>;
      return (
        displayName: item['display_name'] as String,
        location: LatLng(
          double.parse(item['lat'] as String),
          double.parse(item['lon'] as String),
        ),
      );
    }).toList();
  }

  /// Reverse geocode coordinates to address
  Future<String?> reverseGeocode(LatLng location) async {
    final response = await _dio.get(
      '${AppConstants.nominatimBaseUrl}/reverse',
      queryParameters: {
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'format': 'json',
      },
      options: Options(headers: {
        'User-Agent': AppConstants.nominatimUserAgent,
      }),
    );

    final data = response.data as Map<String, dynamic>;
    return data['display_name'] as String?;
  }
}
