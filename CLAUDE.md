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
- `CrimeRepository` → Tries ArcGIS, falls back to generated crimes
- `LightingRepository` → Tries ArcGIS, falls back to grid pattern
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
  (crimeScore * 0.40) +        // Crime density (40%)
  (lightingScore * 0.25) +     // Street lighting coverage (25%)
  (collisionScore * 0.15) +    // Traffic collisions (15%) - currently hardcoded 0
  (safeSpaceScore * 0.10) +    // Proximity to safe spaces (10%)
  (infraScore * 0.10);         // Sidewalk infrastructure (10%) - currently hardcoded true
```

**If modifying weights:** Update both `AppConstants` and `SafetyScorer` implementation.

### 5. Data Flow Architecture

```
User searches destination
    ↓
RouteService.generateRoutes() orchestrates:
    ├─ RouteRepository.getRoutes() [OSRM - 3 routes]
    ├─ Parallel safety data fetch:
    │   ├─ CrimeRepository.getCrimesInArea()
    │   ├─ LightingRepository.getLightsInArea()
    │   └─ SafeSpacesRepository.getSafeSpaces()  [auto-switches Google/Overpass]
    ├─ SafetyScorer.calculateScore() [weighted 0-100]
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

## Known Limitations & Sample Data

1. **Crime Data:** ArcGIS endpoint URLs are not publicly documented. Falls back to algorithmically generated sample crimes (2-8 per area).

2. **Street Lighting:** Same as crime - tries ArcGIS, generates realistic grid pattern on failure.

3. **Collision Data:** Hardcoded as `0` - not implemented yet.

4. **Sidewalk Detection:** Hardcoded as `true` - not implemented yet.

5. **Rate Limits:**
   - Nominatim: 1 request/second (enforced by user-agent)
   - OSRM: ~6 requests/second (public demo server)
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

## Testing Strategy

- Sample data is **deterministic** (same input = same output) for reproducible demos
- Google Places filtering can be tested by changing system time to 2 AM (should only show 24/7 places)
- Safety scores should be in 0-100 range, never negative or >100
- Route classification guarantees exactly 3 routes: fastest, balanced, safest
