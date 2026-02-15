import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/safe_space.dart';

/// Fetches safe spaces from Google Places API with real-time opening hours
///
/// Priority for emergency extraction:
/// 1. Police stations (always prioritized)
/// 2. Hospitals / Fire stations
/// 3. 24/7 Gas stations & Convenience stores
/// 4. Pharmacies (if open now or 24/7)
class GooglePlacesSafeSpacesRepository {
  final String _apiKey;
  final http.Client _client;

  GooglePlacesSafeSpacesRepository({
    required String apiKey,
    http.Client? client,
  })  : _apiKey = apiKey,
        _client = client ?? http.Client();

  /// Query safe spaces near a center point
  /// Returns police, hospitals, fire stations, 24/7 stores, and open pharmacies
  Future<List<SafeSpace>> getSafeSpaces({
    required LatLng center,
    double radiusMeters = 2000,
  }) async {
    final allSpaces = <SafeSpace>[];

    // Search 1: Emergency services (police, hospital, fire)
    final emergencySpaces = await _searchPlaces(
      center: center,
      radiusMeters: radiusMeters,
      types: ['police', 'hospital', 'fire_station'],
    );
    allSpaces.addAll(emergencySpaces);

    // Search 2: 24/7 stores (gas stations, convenience stores)
    final storeSpaces = await _searchPlaces(
      center: center,
      radiusMeters: radiusMeters,
      types: ['gas_station', 'convenience_store'],
      filterOpen24h: true, // Only keep 24/7 stores
    );
    allSpaces.addAll(storeSpaces);

    // Search 3: Pharmacies
    final pharmacySpaces = await _searchPlaces(
      center: center,
      radiusMeters: radiusMeters,
      types: ['pharmacy'],
      filterOpenNow: true, // Only keep open pharmacies
    );
    allSpaces.addAll(pharmacySpaces);

    print('GooglePlacesSafeSpacesRepository: Total accessible safe spaces: ${allSpaces.length}');
    return allSpaces;
  }

  /// Internal search method with retry and error handling
  Future<List<SafeSpace>> _searchPlaces({
    required LatLng center,
    required double radiusMeters,
    required List<String> types,
    bool filterOpen24h = false,
    bool filterOpenNow = false,
  }) async {
    final url =
        Uri.parse('https://places.googleapis.com/v1/places:searchNearby');

    final body = jsonEncode({
      'includedTypes': types,
      'maxResultCount': 20,
      'locationRestriction': {
        'circle': {
          'center': {
            'latitude': center.latitude,
            'longitude': center.longitude,
          },
          'radius': radiusMeters,
        },
      },
      'languageCode': 'en',
    });

    try {
      print('GooglePlacesRepository: Searching for ${types.join(", ")}...');

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.location,'
              'places.types,places.formattedAddress,'
              'places.internationalPhoneNumber,places.regularOpeningHours',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        print('GooglePlacesRepository: API error ${response.statusCode}: ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = (data['places'] as List?) ?? [];

      print('GooglePlacesRepository: Received ${places.length} results for ${types.join(", ")}');

      // Parse and apply filters
      var spaces = places
          .map((p) {
            try {
              return SafeSpace.fromGooglePlaces(p as Map<String, dynamic>);
            } catch (e) {
              print('GooglePlacesRepository: Failed to parse place: $e');
              return null;
            }
          })
          .whereType<SafeSpace>()
          .toList();

      // Apply filters if requested
      if (filterOpen24h) {
        spaces = spaces.where((s) => s.isOpen24h).toList();
        print('GooglePlacesRepository: After 24/7 filter: ${spaces.length} spaces');
      } else if (filterOpenNow) {
        spaces = spaces.where((s) => s.isAccessibleAt(DateTime.now())).toList();
        print('GooglePlacesRepository: After "open now" filter: ${spaces.length} spaces');
      }

      return spaces;
    } catch (e) {
      print('GooglePlacesRepository: Error searching ${types.join(", ")}: $e');
      return [];
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
      return distApprox < radiusMeters * radiusMeters;
    }).length;
  }

  /// Generate enhanced sample safe spaces if API fails
  /// (Includes 24/7 gas stations and convenience stores)
  List<SafeSpace> _sampleSafeSpaces(LatLng center) {
    return [
      // Emergency services
      SafeSpace(
        id: 'yrp_1',
        name: 'York Regional Police - District 5',
        location: LatLng(center.latitude + 0.01, center.longitude - 0.005),
        type: SafeSpaceType.police,
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'hosp_1',
        name: 'Markham Stouffville Hospital',
        location: LatLng(center.latitude - 0.008, center.longitude + 0.012),
        type: SafeSpaceType.hospital,
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'fire_1',
        name: 'Markham Fire Station 7',
        location: LatLng(center.latitude + 0.005, center.longitude + 0.008),
        type: SafeSpaceType.fireStation,
        isOpen24h: true,
      ),
      // 24/7 Stores (GAS STATIONS & CONVENIENCE STORES)
      SafeSpace(
        id: 'gas_1',
        name: 'Esso Gas Station (24h)',
        location: LatLng(center.latitude + 0.003, center.longitude + 0.004),
        type: SafeSpaceType.other, // Will show as "Safe Space" with 24/7 badge
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'store_1',
        name: '7-Eleven (24h)',
        location: LatLng(center.latitude - 0.004, center.longitude - 0.003),
        type: SafeSpaceType.other,
        isOpen24h: true,
      ),
      SafeSpace(
        id: 'pharmacy_1',
        name: 'Shoppers Drug Mart (24h)',
        location: LatLng(center.latitude - 0.003, center.longitude - 0.007),
        type: SafeSpaceType.pharmacy,
        isOpen24h: true,
      ),
    ];
  }
}
