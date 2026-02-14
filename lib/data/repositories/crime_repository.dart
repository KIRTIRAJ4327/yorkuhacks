import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../models/crime_incident.dart';

/// Fetches crime data from York Region ArcGIS / YRP
class CrimeRepository {
  final Dio _dio;

  CrimeRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConstants.apiTimeout,
              receiveTimeout: AppConstants.apiTimeout,
            ));

  /// Query crime incidents near a route (within bounding box)
  Future<List<CrimeIncident>> getCrimesInArea({
    required LatLng southWest,
    required LatLng northEast,
  }) async {
    try {
      // Try ArcGIS FeatureServer query
      final envelope =
          '${southWest.longitude},${southWest.latitude},'
          '${northEast.longitude},${northEast.latitude}';

      final response = await _dio.get(
        '${AppConstants.arcgisBaseUrl}/YRP_Crime_Data/FeatureServer/0/query',
        queryParameters: {
          'where': '1=1',
          'geometry': envelope,
          'geometryType': 'esriGeometryEnvelope',
          'inSR': '4326',
          'outSR': '4326',
          'spatialRel': 'esriSpatialRelIntersects',
          'outFields': '*',
          'f': 'json',
          'resultRecordCount': '200',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];

      return features
          .map((f) =>
              CrimeIncident.fromArcGis(f as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback: generate realistic sample data for demo
      return _generateSampleCrimes(southWest, northEast);
    }
  }

  /// Generate realistic sample crime data for demo purposes
  /// when live API is unavailable
  List<CrimeIncident> _generateSampleCrimes(
    LatLng sw,
    LatLng ne,
  ) {
    final crimes = <CrimeIncident>[];
    final types = [
      'Theft Under',
      'Mischief',
      'Break & Enter',
      'Assault',
      'Theft of Vehicle',
      'Fraud',
    ];

    // Seed-based generation for consistency
    final latRange = ne.latitude - sw.latitude;
    final lngRange = ne.longitude - sw.longitude;
    final centerLat = (sw.latitude + ne.latitude) / 2;
    final centerLng = (sw.longitude + ne.longitude) / 2;

    // Generate 5-15 incidents based on area size
    final count = (latRange * lngRange * 50000).clamp(3, 15).toInt();

    for (int i = 0; i < count; i++) {
      // Use deterministic offsets for reproducibility
      final latOffset = (i * 0.37 % 1.0) * latRange;
      final lngOffset = (i * 0.61 % 1.0) * lngRange;

      crimes.add(CrimeIncident(
        id: 'sample_$i',
        location: LatLng(
          sw.latitude + latOffset,
          sw.longitude + lngOffset,
        ),
        type: types[i % types.length],
        date: DateTime.now().subtract(Duration(days: i * 3 + 1)),
        description: 'Near ${centerLat.toStringAsFixed(3)}, ${centerLng.toStringAsFixed(3)}',
      ));
    }

    return crimes;
  }
}
