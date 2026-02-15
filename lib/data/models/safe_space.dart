import 'package:latlong2/latlong.dart';

/// Opening hours data from Google Places API
class OpeningHours {
  final bool isOpen24h;
  final bool isOpenNow;
  final List<Period> periods;
  final List<String> weekdayText;

  const OpeningHours({
    this.isOpen24h = false,
    this.isOpenNow = false,
    this.periods = const [],
    this.weekdayText = const [],
  });

  factory OpeningHours.fromGooglePlaces(Map<String, dynamic> json) {
    // Safely parse periods - Google Places often returns malformed data
    final List<Period> periods = [];
    final periodsList = json['periods'];
    if (periodsList is List) {
      for (final p in periodsList) {
        try {
          if (p is Map<String, dynamic>) {
            periods.add(Period.fromJson(p));
          }
        } catch (e) {
          // Skip malformed periods silently
          continue;
        }
      }
    }

    final weekdayText =
        (json['weekdayDescriptions'] as List?)?.cast<String>() ?? [];

    // Check if open 24/7 (all days, 0000-2359 or no close time)
    final isOpen24h = periods.length == 7 &&
        periods.every((p) =>
            p.open.time == '0000' &&
            (p.close == null || p.close!.time == '2359'));

    return OpeningHours(
      isOpen24h: isOpen24h,
      isOpenNow: json['openNow'] as bool? ?? false,
      periods: periods,
      weekdayText: weekdayText,
    );
  }
}

/// Period representing opening/closing times for a day
class Period {
  final TimeOfDay open;
  final TimeOfDay? close;

  const Period({required this.open, this.close});

  factory Period.fromJson(Map<String, dynamic> json) {
    try {
      final openData = json['open'];
      final closeData = json['close'];

      if (openData == null) {
        throw FormatException('Missing open time in period');
      }

      return Period(
        open: TimeOfDay.fromJson(openData as Map<String, dynamic>),
        close: closeData != null
            ? TimeOfDay.fromJson(closeData as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      throw FormatException('Failed to parse Period: $e');
    }
  }
}

/// Time of day in Google Places format
class TimeOfDay {
  final int day; // 0-6 (Sunday-Saturday)
  final String time; // "0930" format

  const TimeOfDay({required this.day, required this.time});

  factory TimeOfDay.fromJson(Map<String, dynamic> json) {
    try {
      final day = json['day'];
      final time = json['time'];

      if (day == null || time == null) {
        throw FormatException('Missing day or time in TimeOfDay');
      }

      return TimeOfDay(
        day: day is int ? day : int.parse(day.toString()),
        time: time.toString(),
      );
    } catch (e) {
      throw FormatException('Failed to parse TimeOfDay: $e');
    }
  }
}

enum SafeSpaceType {
  police,
  hospital,
  fireStation,
  pharmacy,
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
      case pharmacy:
        return 'Pharmacy';
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
      case pharmacy:
        return '\u{1F48A}';
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
  final OpeningHours? openingHours;

  const SafeSpace({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
    this.address,
    this.phone,
    this.isOpen24h = false,
    this.openingHours,
  });

  /// Check if this safe space is accessible at the given time
  bool isAccessibleAt(DateTime time) {
    if (isOpen24h) return true;
    if (openingHours?.isOpenNow ?? false) return true;
    return false;
  }

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

  /// Create SafeSpace from Google Places API response
  factory SafeSpace.fromGooglePlaces(Map<String, dynamic> json) {
    final types = (json['types'] as List?)?.cast<String>() ?? [];
    final location = json['location'] as Map<String, dynamic>?;
    final openingHours = json['regularOpeningHours'] != null
        ? OpeningHours.fromGooglePlaces(
            json['regularOpeningHours'] as Map<String, dynamic>)
        : null;

    SafeSpaceType type = SafeSpaceType.other;
    if (types.contains('police')) {
      type = SafeSpaceType.police;
    } else if (types.contains('hospital')) {
      type = SafeSpaceType.hospital;
    } else if (types.contains('fire_station')) {
      type = SafeSpaceType.fireStation;
    } else if (types.contains('pharmacy')) {
      type = SafeSpaceType.pharmacy;
    }

    // Safely extract location with defaults
    final lat = location != null ? (location['latitude'] as num?)?.toDouble() : null;
    final lng = location != null ? (location['longitude'] as num?)?.toDouble() : null;

    if (lat == null || lng == null) {
      throw FormatException('Google Places API returned invalid location data');
    }

    // Safely extract display name - handle nested map or missing data
    String placeName = type.label; // Default
    final displayNameObj = json['displayName'];
    if (displayNameObj != null && displayNameObj is Map) {
      final text = displayNameObj['text'];
      if (text != null && text is String && text.isNotEmpty) {
        placeName = text;
      }
    }

    // Safely extract ID
    final placeId = json['id'];
    final safeId = (placeId != null && placeId is String && placeId.isNotEmpty)
        ? placeId
        : 'place_${placeName.hashCode}_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';

    return SafeSpace(
      id: safeId,
      name: placeName,
      location: LatLng(lat, lng),
      type: type,
      address: json['formattedAddress'] as String?,
      phone: json['internationalPhoneNumber'] as String?,
      isOpen24h: openingHours?.isOpen24h ?? false,
      openingHours: openingHours,
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
