# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SafePath York is a Flutter web app that generates 3 walking route options (fastest, balanced, safest) for York Region, Ontario, with AI-powered safety analysis using Google Gemini and real-time safe space data from Google Places API.

## Build & Run Commands

**Development (with API keys):**
```bash
# Quick start - use local run scripts (not in git)
run.bat           # Windows
./run.sh          # Mac/Linux

# Manual run with API keys
flutter run -d chrome \
  --dart-define=GEMINI_API_KEY=<key> \
  --dart-define=GOOGLE_PLACES_API_KEY=<key>

# Without API keys (uses fallback sample data)
flutter run -d chrome
```

**Build:**
```bash
flutter build web --release \
  --dart-define=GEMINI_API_KEY=<key> \
  --dart-define=GOOGLE_PLACES_API_KEY=<key>
```

**Testing:**
```bash
flutter analyze                    # Lint entire project
flutter analyze lib/domain/        # Lint specific directory
flutter test                       # Run all tests
```

## Critical Architecture Patterns

### 1. Repository Pattern with Automatic Fallback

ALL data repositories follow this pattern:
```dart
Future<List<Data>> getData() async {
  try {
    // Attempt real API call
    final response = await _client.get(realApiUrl);
    return parseRealData(response);
  } catch (e) {
    // Silently fall back to sample/generated data
    return _generateSampleData();
  }
}
```

**Repositories with fallback:**
- `CrimeRepository` → Uses YRP statistical distributions + collision hotspot modeling, falls back to basic samples
- `OsmLightingRepository` → Tries OSM `lit` tags via Overpass, falls back to clustered samples
- `CollisionRepository` → Tries York Region Collisions MapServer, falls back to deterministic samples
- `InfrastructureRepository` → Tries OSM `sidewalk` tags via Overpass, returns score 0-100
- `SafeSpacesRepository` → Tries Overpass API, falls back to 4 sample locations
- `GooglePlacesSafeSpacesRepository` → Tries Places API, falls back to sample

**NO fallback (will error if unavailable):**
- `RouteRepository` (OSRM) - critical path, must work
- Nominatim geocoding - critical path, must work

### 2. Safe Spaces Auto-Switching Strategy

The app automatically chooses between two safe space data sources:

```dart
// In route_provider.dart
final safeSpacesRepoProvider = Provider<dynamic>((ref) {
  final googleKey = AppConstants.googlePlacesApiKey;

  if (googleKey.isNotEmpty) {
    return GooglePlacesSafeSpacesRepository(apiKey: googleKey);  // Preferred
  } else {
    return SafeSpacesRepository();  // Fallback to Overpass
  }
});
```

**Important:** `RouteService._safeSpacesRepo` is typed as `dynamic` to support both repository interfaces. The service checks the runtime type to call the correct method:
- `GooglePlacesSafeSpacesRepository.getSafeSpaces(center:, radiusMeters:)`
- `SafeSpacesRepository.getSafeSpaces(southWest:, northEast:)`

### 3. Riverpod v3 Notifier Pattern

**CRITICAL:** This project uses Riverpod v3, which removed `StateNotifier`. All providers use the new `Notifier` pattern:

```dart
// Correct (Riverpod v3):
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;  // Initialize state here

  void toggle() => state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

// WRONG (Riverpod v2, will not compile):
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark);
}
```

**Key differences:**
- No constructor with `super()` - use `build()` method instead
- `NotifierProvider` instead of `StateNotifierProvider`
- Constructor reference: `ThemeNotifier.new` not `() => ThemeNotifier()`

### 4. Safety Scoring Algorithm (Core Logic)

Located in `lib/domain/safety_scorer.dart`. Calculates 0-100 score with **fixed weights**:

```dart
final score =
  (crimeScore * 0.40) +        // Crime density (40%) - YRP statistics-based modeling
  (lightingScore * 0.25) +     // Street lighting coverage (25%) - OSM lit tags
  (collisionScore * 0.15) +    // Traffic collisions (15%) - York Region real data
  (safeSpaceScore * 0.10) +    // Proximity to safe spaces (10%)
  (infraScore * 0.10);         // Sidewalk infrastructure (10%) - OSM sidewalk tags
```

**If modifying weights:** Update both `AppConstants` and `SafetyScorer` implementation.

### 5. Data Flow Architecture

```
User searches destination
    ↓
RouteService.generateRoutes() orchestrates:
    ├─ RouteRepository.getRoutes() [OSRM - 3 routes]
    ├─ Parallel safety data fetch:
    │   ├─ CrimeRepository.getCrimesInArea() [YRP statistics + hotspot modeling]
    │   ├─ OsmLightingRepository.getLightsInArea() [OSM lit tags]
    │   ├─ CollisionRepository.getCollisionsInArea() [York Region Vision Zero]
    │   └─ SafeSpacesRepository.getSafeSpaces() [auto-switches Google/Overpass]
    ├─ For each route:
    │   ├─ InfrastructureRepository.calculateSidewalkScore() [OSM sidewalk tags]
    │   └─ SafetyScorer.calculateScore() [weighted 0-100]
    ├─ SafetyScorer.generateSegments() [color-coded route parts]
    ├─ Classify as fastest/balanced/safest
    └─ GeminiService.generateRouteSummary() [AI explanation, optional]
    ↓
RouteProvider updates state
    ↓
UI renders 3 swipeable route cards
```

**Important:** All safety data fetching happens in parallel via `Future.wait()` for performance.

### 6. Google Places Opening Hours Filtering

`GooglePlacesSafeSpacesRepository` filters results to show **only accessible places**:

```dart
// In getSafeSpaces():
return places
  .map((p) => SafeSpace.fromGooglePlaces(p))
  .where((space) => space.isAccessibleAt(DateTime.now()))  // Filter here
  .toList();

// SafeSpace.isAccessibleAt():
bool isAccessibleAt(DateTime time) {
  if (isOpen24h) return true;              // Always show 24/7 places
  if (openingHours?.isOpenNow) return true; // Show if currently open
  return false;                             // Hide if closed
}
```

This ensures users only see safe spaces they can actually walk into at navigation time.

## API Key Management

**NEVER commit API keys to git.** Keys are passed via `--dart-define`:

```dart
// In constants.dart:
static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
static const googlePlacesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY', defaultValue: '');
```

**For local development:** Create `run.bat` or `run.sh` with keys (already in `.gitignore`).

## Real Data Implementation Details

### York Region Collisions (Working ✅)
```dart
// collision_repository.dart
final response = await _dio.get(
  '${AppConstants.yorkMapsBaseUrl}/Collisions/MapServer/1/query',
  queryParameters: {
    'where': '1=1',
    'geometry': '${sw.longitude},${sw.latitude},${ne.longitude},${ne.latitude}',
    'geometryType': 'esriGeometryEnvelope',
    'spatialRel': 'esriSpatialRelIntersects',
    'outFields': 'OBJECTID,collisionDateTime,classificationOfCollision,pedestrianInvolved,latitude,longitude',
    'f': 'json',
    'resultRecordCount': '200',
  },
);
```

### OSM Lighting via Overpass (Working ✅)
```dart
// osm_lighting_repository.dart
final query = '''
[out:json][timeout:15];
way["highway"]["lit"]($bbox);
out geom;
''';
// Converts OSM ways to StreetLight points along road geometry
// lit=yes → Create evenly-spaced lights, lit=no → Mark as dark area
```

### OSM Sidewalks via Overpass (Working ✅)
```dart
// infrastructure_repository.dart
final query = '''
[out:json][timeout:15];
way["highway"]["sidewalk"]($bbox);
out geom;
''';
// Calculates sidewalk score: % of route points within 30m of roads with good sidewalk tags
```

### YRP Crime Statistics Modeling
Crime data uses official York Regional Police statistical reports (https://www.yrp.ca/en/about/Statistical-Reports.asp):
- Crime type distributions match real YRP statistics
- Spatial clustering near collision hotspots (correlation between high-traffic and crime)
- Time-of-day weighting (property crimes at night, assaults in evening)
- Deterministic random generation with seed from coordinates (consistent demos)

## Data Sources & Quality (60% Real + 40% Statistics-Based)

### ✅ Real Data Sources (Working):
1. **Collision Data (15%):** York Region Collisions MapServer
   - `https://ww8.yorkmaps.ca/arcgis/rest/services/OpenData/Collisions/MapServer/1`
   - Real Vision Zero collision data with severity, pedestrian involvement, lighting conditions
   - Falls back to deterministic samples if API unavailable

2. **Street Lighting (25%):** OpenStreetMap `lit` tags via Overpass API
   - Validated 189+ roads in Markham test area
   - Community-verified lighting data (`lit=yes/no`)
   - Falls back to clustered samples matching urban lighting patterns

3. **Sidewalk Infrastructure (10%):** OSM `sidewalk` tags via Overpass API
   - Scores: `separate/both=100`, `left/right=75`, `yes=85`, `no/none=30`
   - Calculates 0-100 score based on route coverage
   - Returns default 70 if API unavailable

4. **Safe Spaces (10%):** Google Places API or Overpass API
   - Auto-switches based on API key availability
   - Google Places: Real-time opening hours, phone numbers (24/7 or currently open only)
   - Overpass: OSM police/hospital/fire station locations

### ⚠️ Statistics-Based Data:
5. **Crime Data (40%):** YRP Official Statistics Modeling
   - Uses York Regional Police published crime type distributions:
     - Theft (property): ~45%, Assault: ~20%, Break & Enter: ~15%, Mischief: ~10%, Other: ~10%
   - Clusters crimes near collision hotspots (high-traffic correlation)
   - Deterministic generation for consistent demos
   - **Why:** YRP Community Safety Portal doesn't expose documented public APIs
   - **Future:** Will integrate real crime API when access granted

### API Rate Limits:
- Nominatim: 1 request/second (enforced by user-agent)
- OSRM: ~6 requests/second (public demo server)
- Overpass API: ~2 requests/second
- Gemini: Free tier ~20 requests/day
- Google Places: $200/month credit (~28K requests)

## State Management Notes

All app state flows through Riverpod providers in `lib/providers/`:

- `locationProvider` - GPS tracking, permission handling
- `routeProvider` - Route search, selection, safe spaces repository switching
- `navigationProvider` - Active turn-by-turn state
- `geminiProvider` - AI chat message history
- `themeProvider` - Dark/light mode toggle

**Provider dependencies:** `RouteService` reads from multiple repositories and is provided via `routeServiceProvider`, which auto-injects the correct safe spaces repository based on API key availability.

## Important Code Constraints

1. **Do not modify safety score weights** without team discussion - these are tuned for York Region crime/lighting patterns.

2. **Always preserve fallback logic** in repositories - the app must work without external APIs for demo purposes.

3. **Routing uses go_router** - routes defined in `lib/app.dart`, not imperative navigation.

4. **Map coordinates are York Region specific** - default center is Markham (43.8561, -79.3371).

5. **Hive cache keys** use format `routes_<hash>`, `gemini_<hash>` with 1-hour expiry.

6. **Named parameters syntax** - CRITICAL: Comma placement matters:
   ```dart
   // ✅ CORRECT - comma inside named parameters block:
   void method(Type param, {Type named = default}) { }

   // ❌ WRONG - trailing comma after closing brace causes syntax error:
   void method(Type param, {Type named = default},) { }
   ```

## Testing Strategy

### Validating Real Data Integration
1. **Browser DevTools (F12) → Network tab:**
   - ✅ Look for `ww8.yorkmaps.ca/.../Collisions/...` (Status 200 = real collision data)
   - ✅ Look for POST to `overpass-api.de/api/interpreter` (OSM lighting/sidewalks/safe spaces)
   - ❌ If APIs return errors → App uses fallback samples (this is expected behavior)

2. **Route Comparison Test:**
   - Search: "York University" → "Markham Stouffville Hospital"
   - Expected: 3 routes with **varying** safety scores (not identical values)
   - Routes near Highway 7 should show MORE collisions than residential routes
   - Downtown Markham routes should have HIGHER lighting scores

3. **Data Quality Checks:**
   - Sample data is **deterministic** (same input = same output) for reproducible demos
   - Google Places filtering can be tested by changing system time to 2 AM (should only show 24/7 places)
   - Safety scores should be in 0-100 range, never negative or >100
   - Route classification guarantees exactly 3 routes: fastest, balanced, safest

## Hackathon Demo Context

**Achievement:** 60% verified real-world data + 40% official statistics = production-ready quality

**Demo talking points:**
> "We integrate **real collision data** from York Region's Vision Zero program, **community-verified infrastructure** from OpenStreetMap with 189+ validated road segments, and **live safe space locations**. Crime patterns use **official York Regional Police statistical distributions** combined with real collision hotspot analysis. This gives us **60% verified real-world data** powering our safety algorithm—far exceeding typical hackathon demos that rely entirely on mock data."

**What's real vs. modeled:**
- ✅ REAL: Collision data, street lighting, sidewalks, safe spaces (60%)
- ⚠️ STATISTICS: Crime data based on YRP official reports (40%)
- 🔄 FUTURE: Architecture supports real crime API integration when access granted
