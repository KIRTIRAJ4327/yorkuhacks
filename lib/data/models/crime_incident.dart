import 'package:latlong2/latlong.dart';

class CrimeIncident {
  final String id;
  final LatLng location;
  final String type; // e.g. "Theft", "Assault", "Break & Enter"
  final DateTime date;
  final String? description;

  const CrimeIncident({
    required this.id,
    required this.location,
    required this.type,
    required this.date,
    this.description,
  });

  factory CrimeIncident.fromArcGis(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};

    return CrimeIncident(
      id: (attrs['OBJECTID'] ?? attrs['FID'] ?? '').toString(),
      location: LatLng(
        (geometry['y'] as num?)?.toDouble() ?? 0,
        (geometry['x'] as num?)?.toDouble() ?? 0,
      ),
      type: (attrs['offence'] ?? attrs['OFFENCE'] ?? attrs['crime_type'] ?? 'Unknown')
          .toString(),
      date: DateTime.fromMillisecondsSinceEpoch(
        (attrs['reported_date'] ?? attrs['REPORTED_DATE'] ?? 0) as int,
      ),
      description: attrs['neighbourhood']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': location.latitude,
        'lng': location.longitude,
        'type': type,
        'date': date.toIso8601String(),
        'description': description,
      };

  factory CrimeIncident.fromJson(Map<String, dynamic> json) {
    return CrimeIncident(
      id: json['id'] as String,
      location: LatLng(json['lat'] as double, json['lng'] as double),
      type: json['type'] as String,
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
    );
  }
}
