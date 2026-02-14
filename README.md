# SafePath York

Walking safety app for York Region. Get three route options with safety scores based on real crime data, street lighting, and nearby safe spaces.

Built for YorkUHacks.

## Quick Start

```bash
git clone https://github.com/KIRTIRAJ4327/yorkuhacks.git
cd yorkuhacks
flutter pub get
flutter run -d chrome
```

Optional: Add `--dart-define=GEMINI_API_KEY=your_key` to enable AI features. Get a free key at https://aistudio.google.com/apikey

## Features

- Three route options: fastest, balanced, and safest
- Safety scores (0-100) based on crime data, lighting, and safe spaces
- Turn-by-turn navigation with safety alerts
- Chat with AI about area safety
- SOS emergency button
- Dark theme optimized for night use

## Tech Stack

Flutter, Riverpod, flutter_map (OpenStreetMap), OSRM routing, Gemini AI, York Region ArcGIS data, Hive for caching.

## Project Structure (For Developers)

```
lib/
├── main.dart                     # App entry point
├── app.dart                      # Routing config (go_router)
│
├── core/
│   ├── theme/                    # Colors, dark/light themes
│   ├── constants.dart            # API URLs, scoring weights
│   └── utils/                    # Geo calculations, formatting
│
├── data/
│   ├── models/                   # Data classes (routes, crime, etc)
│   ├── repositories/             # API clients (OSRM, Nominatim, ArcGIS)
│   └── local/cache_service.dart  # Hive offline cache
│
├── domain/
│   ├── safety_scorer.dart        # Core algorithm: calculates 0-100 score
│   ├── route_service.dart        # Orchestrates 3-route generation
│   ├── gemini_service.dart       # AI summaries + chat
│   ├── navigation_engine.dart    # Turn-by-turn logic
│   └── alert_engine.dart         # Safety warnings
│
├── providers/                    # Riverpod state (location, routes, nav, chat)
│
└── presentation/
    ├── screens/
    │   ├── home_screen.dart           # Map + search
    │   ├── route_selection_screen.dart # 3 swipeable route cards
    │   ├── navigation_screen.dart      # Active turn-by-turn
    │   ├── safety_chat_screen.dart     # AI assistant chat
    │   └── arrival_screen.dart         # Journey stats
    │
    └── widgets/
        ├── map/safety_map.dart              # Dark map with colored routes
        ├── route/route_card.dart            # Swipeable card + safety gauge
        ├── navigation/sos_button.dart       # Emergency button
        └── ai/chat_bubble.dart              # Chat messages
```

## Key Files to Understand

### 1. Safety Scoring (`lib/domain/safety_scorer.dart`)
The brain of the app. Takes a route and calculates a 0-100 score using:
- **40%** Crime density (counts crimes within 100m of route)
- **25%** Street lighting coverage
- **15%** Traffic collisions
- **10%** Distance to safe spaces (police, hospitals)
- **10%** Sidewalk infrastructure

### 2. Route Generation (`lib/domain/route_service.dart`)
Workflow:
1. Gets 3+ routes from OSRM
2. Fetches safety data (crime, lights, safe spaces) for the area
3. Scores each route with `SafetyScorer`
4. Classifies routes as fastest/balanced/safest
5. Sends each route to Gemini for AI summary
6. Returns 3 routes to UI

### 3. Providers (`lib/providers/`)
Riverpod state management:
- `location_provider.dart` — GPS tracking
- `route_provider.dart` — Route search + selection
- `navigation_provider.dart` — Active navigation state
- `gemini_provider.dart` — AI chat messages
- `theme_provider.dart` — Dark/light mode

### 4. UI Flow
```
Splash → Home (map + search)
         ↓
         User enters destination
         ↓
         Route Selection (3 cards)
         ↓
         User taps "Start Navigation"
         ↓
         Navigation (turn-by-turn)
         ↓
         Arrival (stats + AI feedback)
```

Can also go to: AI Chat (safety questions) from Home screen.

## Data Sources

- **Routes**: OSRM public server (walking mode)
- **Geocoding**: Nominatim (OpenStreetMap)
- **Crime Data**: York Region ArcGIS + sample data (API endpoints need discovery)
- **Street Lighting**: York Region Open Data + sample data
- **Safe Spaces**: OpenStreetMap Overpass API (police, hospitals, fire stations)

## Safety Scoring Breakdown

Routes get a 0-100 score:
- **80-100** = Very Safe (green)
- **60-79** = Moderate (yellow)
- **40-59** = Caution (orange)
- **0-39** = Higher Risk (red)

Route segments on the map are color-coded by their individual safety scores.

## Team

- Kirti ([@KIRTIRAJ4327](https://github.com/KIRTIRAJ4327))
- DJ
- Yeshi
- Tarun

## License

MIT

---

Made with ❤️ for York Region
