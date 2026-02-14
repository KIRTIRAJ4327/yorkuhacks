# SafePath York

Walking safety app for York Region. Get three route options with safety scores based on real crime data, street lighting, and nearby safe spaces.

Built for YorkUHacks.

## Features

- Three route options: fastest, balanced, and safest
- Safety scores (0-100) based on crime data, lighting, and safe spaces
- Turn-by-turn navigation with safety alerts
- Chat with AI about area safety
- SOS emergency button
- Dark theme optimized for night use

## Setup

```bash
git clone https://github.com/KIRTIRAJ4327/yorkuhacks.git
cd yorkuhacks
flutter pub get
flutter run -d chrome
```

Optional: Add `--dart-define=GEMINI_API_KEY=your_key` to enable AI features. Get a free key at https://aistudio.google.com/apikey

## Tech Stack

Flutter, Riverpod, flutter_map (OpenStreetMap), OSRM routing, Gemini AI, York Region ArcGIS data, Hive for caching.

## How Safety Scoring Works

Routes get a 0-100 score based on:
- Crime density (40%)
- Street lighting (25%)
- Traffic collisions (15%)
- Distance to safe spaces (10%)
- Sidewalk infrastructure (10%)

Data from York Regional Police, York Region Open Data, and OpenStreetMap.

## Team

- Kirti ([@KIRTIRAJ4327](https://github.com/KIRTIRAJ4327))
- DJ
- Yeshi
- Tarun

## License

MIT

---

Made with ❤️ for York Region
