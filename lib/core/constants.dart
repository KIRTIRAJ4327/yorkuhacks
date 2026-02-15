/// API endpoints and app constants
class AppConstants {
  AppConstants._();

  // === API Endpoints ===
  static const String osrmBaseUrl = 'https://router.project-osrm.org';
  static const String nominatimBaseUrl =
      'https://nominatim.openstreetmap.org';
  static const String overpassBaseUrl =
      'https://overpass-api.de/api/interpreter';
  static const String arcgisBaseUrl =
      'https://services1.arcgis.com/GzvOwaQBbX7KLiuG/ArcGIS/rest/services';
  static const String yorkOpenDataUrl =
      'https://data.yorkopendata.org';

  // === Map Defaults (York Region center — Markham) ===
  static const double defaultLat = 43.8561;
  static const double defaultLng = -79.3371;
  static const double defaultZoom = 13.0;

  // === Dark Map Tile URL (CartoDB Dark Matter) ===
  static const String darkTileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const String lightTileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

  // === Safety Scoring Weights ===
  static const double weightCrime = 0.40;
  static const double weightLighting = 0.25;
  static const double weightCollision = 0.15;
  static const double weightSafeSpaces = 0.10;
  static const double weightInfrastructure = 0.10;

  // === Route Buffer Distance (meters) ===
  static const double routeBufferMeters = 100.0;

  // === Safe Space Search Radius (meters) ===
  static const double safeSpaceRadiusMeters = 200.0;

  // === Max Expected Values (for score normalization) ===
  static const int maxExpectedCrimes = 10;
  static const int maxExpectedCollisions = 5;

  // === Gemini ===
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static const String geminiSystemPrompt = '''
You are SafePath, a walking safety AI assistant for York Region, Ontario.
You analyze walking route safety using crime data, street lighting, and safe spaces.
Be reassuring but honest. Prioritize actionable safety tips.
Keep responses concise (2-3 sentences max for route summaries).
For chat questions, provide helpful neighborhood safety insights.
''';

  // === Google Places API ===
  static const String googlePlacesApiKey =
      String.fromEnvironment('GOOGLE_PLACES_API_KEY', defaultValue: '');

  // === Nominatim ===
  static const String nominatimUserAgent = 'SafePathYork/1.0';

  // === Timeouts ===
  static const Duration apiTimeout = Duration(seconds: 15);
  static const Duration cacheExpiry = Duration(hours: 1);
}
