import 'package:latlong2/latlong.dart';

enum SafeSpaceType {
  police,
  hospital,
  fireStation,
  transitStop,
  other;

  String get label {
    switch (this) {
      case police:
        return 'Police Station';
      case hospital:
        return 'Hospital';
      case fireStation:
        return 'Fire Station';
      case transitStop:
        return 'Transit Stop';
      case other:
        return 'Safe Space';
    }
  }

  String get emoji {
    switch (this) {
      case police:
        return '\u{1F46E}';
      case hospital:
        return '\u{1F3E5}';
      case fireStation:
        return '\u{1F692}';
      case transitStop:
        return '\u{1F68F}';
      case other:
        return '\u{1F3E0}';
    }
  }
}

class SafeSpace {
  final String id;
  final String name;
  final LatLng location;
  final SafeSpaceType type;
  final String? address;
  final String? phone;
  final bool isOpen24h;

  const SafeSpace({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
    this.address,
    this.phone,
    this.isOpen24h = false,
  });

  factory SafeSpace.fromOverpass(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    final amenity = tags['amenity']?.toString() ?? '';

    SafeSpaceType type;
    switch (amenity) {
      case 'police':
        type = SafeSpaceType.police;
      case 'hospital':
        type = SafeSpaceType.hospital;
      case 'fire_station':
        type = SafeSpaceType.fireStation;
      default:
        type = SafeSpaceType.other;
    }

    return SafeSpace(
      id: json['id'].toString(),
      name: tags['name']?.toString() ?? type.label,
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lon'] as num).toDouble(),
      ),
      type: type,
      address: tags['addr:street']?.toString(),
      phone: tags['phone']?.toString(),
      isOpen24h: tags['opening_hours'] == '24/7',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': location.latitude,
        'lng': location.longitude,
        'type': type.name,
        'address': address,
        'phone': phone,
        'isOpen24h': isOpen24h,
      };
}
