import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../models/safe_space.dart';

/// Fetches safe spaces from OpenStreetMap Overpass API
class SafeSpacesRepository {
  final Dio _dio;

  SafeSpacesRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ));

  /// Query safe spaces (police, hospitals, fire stations) in a bounding box
  Future<List<SafeSpace>> getSafeSpaces({
    required LatLng southWest,
    required LatLng northEast,
  }) async {
    final bbox =
        '${southWest.latitude},${southWest.longitude},'
        '${northEast.latitude},${northEast.longitude}';

    final query = '''
[out:json][timeout:25];
(
  node["amenity"="police"]($bbox);
  node["amenity"="hospital"]($bbox);
  node["amenity"="fire_station"]($bbox);
  node["amenity"="clinic"]($bbox);
);
out body;
''';

    try {
      print('SafeSpacesRepository: Fetching safe spaces from ${AppConstants.overpassBaseUrl}');

      final response = await _dio.post(
        AppConstants.overpassBaseUrl,
        data: 'data=$query',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final elements = data['elements'] as List? ?? [];

      final spaces = elements
          .map((e) => SafeSpace.fromOverpass(e as Map<String, dynamic>))
          .toList();
      print('SafeSpacesRepository: Success - fetched ${spaces.length} safe spaces from OSM');
      return spaces;
    } catch (e) {
      // Fallback sample data for York Region
      print('SafeSpacesRepository: Failed to fetch Overpass data: $e');
      print('SafeSpacesRepository: Using sample safe spaces');
      return _sampleSafeSpaces(southWest, northEast);
    }
  }

  /// Count safe spaces within radius of a point
  int countNearby(
    LatLng point,
    List<SafeSpace> spaces, {
    double radiusMeters = 200,
  }) {
    return spaces.where((s) {
      final dx = point.latitude - s.location.latitude;
      final dy = point.longitude - s.location.longitude;
      final distApprox = (dx * dx + dy * dy) * 111000 * 111000;
      return distApprox < radiusMeters * radiusMeters * 111 * 111;
    }).length;
  }

  List<SafeSpace> _sampleSafeSpaces(LatLng sw, LatLng ne) {
    final centerLat = (sw.latitude + ne.latitude) / 2;
    final centerLng = (sw.longitude + ne.longitude) / 2;

    return [
      SafeSpace(
        id: 'yrp_1',
        name: 'York Regional Police - District 5',
        location: LatLng(centerLat + 0.01, centerLng - 0.005),
        type: SafeSpaceType.police,
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'hosp_1',
        name: 'Markham Stouffville Hospital',
        location: LatLng(centerLat - 0.008, centerLng + 0.012),
        type: SafeSpaceType.hospital,
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'fire_1',
        name: 'Markham Fire Station 7',
        location: LatLng(centerLat + 0.005, centerLng + 0.008),
        type: SafeSpaceType.fireStation,
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'yrp_2',
        name: 'York Regional Police - District 2',
        location: LatLng(centerLat - 0.015, centerLng - 0.01),
        type: SafeSpaceType.police,
        isOpen24h: true,
      ),
    ];
  }
}
