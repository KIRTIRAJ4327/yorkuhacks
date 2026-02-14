import 'package:latlong2/latlong.dart';
import '../core/utils/geo_utils.dart';
import '../data/models/crime_incident.dart';
import '../data/models/route_data.dart';
import 'gemini_service.dart';

/// Safety alert types
enum AlertLevel { info, warning, danger }

class SafetyAlert {
  final String message;
  final AlertLevel level;
  final LatLng? location;
  final String? aiTip;

  const SafetyAlert({
    required this.message,
    required this.level,
    this.location,
    this.aiTip,
  });
}

/// Proactive safety alert engine for navigation
class AlertEngine {
  final GeminiService _gemini;
  final Set<String> _shownAlerts = {};

  AlertEngine({required GeminiService gemini}) : _gemini = gemini;

  /// Check for alerts at current position along a route
  Future<SafetyAlert?> checkAlerts({
    required LatLng currentPosition,
    required RouteData route,
    required List<CrimeIncident> nearbyCrimes,
    required double lightingCoverage,
  }) async {
    // Check segments ahead for safety drops
    if (route.segments.isNotEmpty) {
      for (final segment in route.segments) {
        final dist = GeoUtils.distanceInMeters(
            currentPosition, segment.start);

        // Look 100-300m ahead
        if (dist > 50 && dist < 300 && segment.safetyScore < 50) {
          final alertKey = '${segment.start.latitude}_low_safety';
          if (_shownAlerts.contains(alertKey)) continue;
          _shownAlerts.add(alertKey);

          String tip = 'Stay alert in the upcoming area.';
          try {
            tip = await _gemini.humanizeAlert(
              alertType: 'low_safety_segment',
              data: {
                'score': segment.safetyScore,
                'distance_ahead': dist.round(),
              },
            );
          } catch (_) {}

          return SafetyAlert(
            message: 'Lower safety ahead',
            level: AlertLevel.warning,
            location: segment.start,
            aiTip: tip,
          );
        }
      }
    }

    // Check for recent crimes nearby (within 100m)
    for (final crime in nearbyCrimes) {
      final dist = GeoUtils.distanceInMeters(
          currentPosition, crime.location);

      if (dist < 100) {
        final alertKey = crime.id;
        if (_shownAlerts.contains(alertKey)) continue;
        _shownAlerts.add(alertKey);

        return SafetyAlert(
          message: '${crime.type} reported nearby recently',
          level: AlertLevel.info,
          location: crime.location,
          aiTip: 'Stay aware of your surroundings. Keep valuables secured.',
        );
      }
    }

    // Lighting alert
    if (lightingCoverage < 40) {
      const alertKey = 'low_lighting';
      if (!_shownAlerts.contains(alertKey)) {
        _shownAlerts.add(alertKey);
        return const SafetyAlert(
          message: 'Lower lighting in this area',
          level: AlertLevel.info,
          aiTip: 'Stay on well-traveled streets for better visibility.',
        );
      }
    }

    return null;
  }

  /// Reset shown alerts (for new navigation session)
  void reset() {
    _shownAlerts.clear();
  }
}
