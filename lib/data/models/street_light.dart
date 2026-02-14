import 'package:latlong2/latlong.dart';

class StreetLight {
  final String id;
  final LatLng location;
  final String? type; // e.g. "LED", "HPS"
  final bool isOperational;

  const StreetLight({
    required this.id,
    required this.location,
    this.type,
    this.isOperational = true,
  });

  factory StreetLight.fromGeoJson(Map<String, dynamic> json) {
    final props = json['properties'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final coords = geometry['coordinates'] as List? ?? [0, 0];

    return StreetLight(
      id: (props['OBJECTID'] ?? props['id'] ?? '').toString(),
      location: LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
      type: props['LIGHT_TYPE']?.toString(),
      isOperational: props['STATUS'] != 'INACTIVE',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': location.latitude,
        'lng': location.longitude,
        'type': type,
        'isOperational': isOperational,
      };

  factory StreetLight.fromJson(Map<String, dynamic> json) {
    return StreetLight(
      id: json['id'] as String,
      location: LatLng(json['lat'] as double, json['lng'] as double),
      type: json['type'] as String?,
      isOperational: json['isOperational'] as bool? ?? true,
    );
  }
}
