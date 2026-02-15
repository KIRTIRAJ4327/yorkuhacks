import 'package:latlong2/latlong.dart';

/// Represents a traffic collision from York Region's Collisions MapServer
class Collision {
  /// Unique identifier from the data source
  final String id;

  /// Geographic location of the collision
  final LatLng location;

  /// When the collision occurred
  final DateTime? dateTime;

  /// Year of the collision
  final int? year;

  /// Classification: "Minimal Injury", "Major Injury", "Fatal"
  final String? classification;

  /// Human-readable location description
  final String? locationDescription;

  /// Whether a pedestrian was involved
  final bool pedestrianInvolved;

  /// Whether a cyclist was involved
  final bool cyclistInvolved;

  /// Whether a motorcyclist was involved
  final bool motorcyclistInvolved;

  /// Lighting condition: "Daylight", "Dark, artificial", "Dark, no light", etc.
  final String? lightCondition;

  /// Municipality where collision occurred
  final String? municipality;

  Collision({
    required this.id,
    required this.location,
    this.dateTime,
    this.year,
    this.classification,
    this.locationDescription,
    this.pedestrianInvolved = false,
    this.cyclistInvolved = false,
    this.motorcyclistInvolved = false,
    this.lightCondition,
    this.municipality,
  });

  /// Creates a Collision from ArcGIS REST API feature JSON
  factory Collision.fromArcGIS(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>;
    final geometry = json['geometry'] as Map<String, dynamic>?;

    // Parse datetime (Unix timestamp in milliseconds)
    DateTime? collisionDateTime;
    if (attributes['collisionDateTime'] != null) {
      try {
        collisionDateTime = DateTime.fromMillisecondsSinceEpoch(
          attributes['collisionDateTime'] as int,
        );
      } catch (_) {
        // Invalid timestamp, leave as null
      }
    }

    return Collision(
      id: '${attributes['OBJECTID'] ?? attributes['objectid'] ?? DateTime.now().millisecondsSinceEpoch}',
      location: LatLng(
        (geometry?['y'] as num?)?.toDouble() ?? 0.0,
        (geometry?['x'] as num?)?.toDouble() ?? 0.0,
      ),
      dateTime: collisionDateTime,
      year: attributes['collisionYear'] as int?,
      classification: attributes['classificationOfCollision'] as String?,
      locationDescription: attributes['locationDescription'] as String?,
      pedestrianInvolved: attributes['pedestrianInvolved'] == 'Yes',
      cyclistInvolved: attributes['cyclistInvolved'] == 'Yes',
      motorcyclistInvolved: attributes['motorcycleInvolved'] == 'Yes',
      lightCondition: attributes['light'] as String?,
      municipality: attributes['Municipality'] as String?,
    );
  }

  /// Whether this collision involved a vulnerable road user
  bool get involvesVulnerableUser =>
      pedestrianInvolved || cyclistInvolved || motorcyclistInvolved;

  /// Whether this collision occurred in poor lighting conditions
  bool get hadPoorLighting =>
      lightCondition?.toLowerCase().contains('dark') ?? false;

  /// Whether this was a severe collision (major injury or fatal)
  bool get isSevere {
    if (classification == null) return false;
    final lower = classification!.toLowerCase();
    return lower.contains('major') || lower.contains('fatal');
  }

  @override
  String toString() {
    return 'Collision(id: $id, classification: $classification, location: $municipality, vulnerableUser: $involvesVulnerableUser)';
  }
}
