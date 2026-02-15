# Development Guide

Quick reference for the SafePath York development team.

## Running the App

### Quick Start (Recommended)

**Windows:**
```bash
run.bat
```

**Mac/Linux:**
```bash
chmod +x run.sh  # First time only
./run.sh
```

These scripts automatically include the API keys, so you don't need to type the long command.

### Manual Run

If you need to run manually:
```bash
flutter run -d chrome \
  --dart-define=GEMINI_API_KEY=AIzaSyCX_tJ6SFxgNjHhAA4uBEHRwK03f3r8ieU \
  --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyDkZDNCHN_uOoJDp1G1NYVMPBwVgwTqYIY
```

### Without API Keys (Demo Mode)

To test the fallback sample data:
```bash
flutter run -d chrome
```

## API Keys in Use

- **Gemini AI** (`AIzaSyCX_tJ6SFxgNjHhAA4uBEHRwK03f3r8ieU`)
  - Used for: AI route summaries, safety chat assistant
  - Free tier: ~20 requests/day
  - Docs: https://ai.google.dev/gemini-api/docs

- **Google Places API** (`AIzaSyDkZDNCHN_uOoJDp1G1NYVMPBwVgwTqYIY`)
  - Used for: Real-time safe spaces with opening hours (police, hospitals, fire stations, pharmacies)
  - Free tier: $200/month credit (~28K requests)
  - Docs: https://developers.google.com/maps/documentation/places/web-service/overview

- **Maps API** (`AIzaSyAl4iNehue73in1Pim5RR7vs6LvT_BgBz0`) - Not currently used
- **Geocoding API** (`AIzaSyBqdcNmMQyt40GVBfSeKcYy0zOAQZ9ihKA`) - Not currently used (using Nominatim instead)

## Important Security Notes

⚠️ **NEVER commit `run.bat` or `run.sh` to GitHub** - they contain API keys!

These files are in `.gitignore` to prevent accidental commits. If you need to share API keys with teammates:
1. Share via secure channel (encrypted message, password manager)
2. Or have each teammate create their own `run.bat`/`run.sh` locally

## Testing Google Places Integration

To verify Google Places is working:

1. Run the app with API keys (use `run.bat` or `run.sh`)
2. Open browser DevTools console (F12)
3. Enter a destination and generate routes
4. Check console for Google Places API calls
5. Safe spaces should show:
   - Police stations (👮)
   - Hospitals (🏥)
   - Fire stations (🚒)
   - 24/7 Pharmacies (💊)
   - Only places that are currently open or open 24/7

## Hot Reload

While the app is running, press:
- **R** = Hot restart (full restart)
- **r** = Hot reload (faster, preserves state)
- **q** = Quit

## Build for Production

```bash
flutter build web --release \
  --dart-define=GEMINI_API_KEY=AIzaSyCX_tJ6SFxgNjHhAA4uBEHRwK03f3r8ieU \
  --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyDkZDNCHN_uOoJDp1G1NYVMPBwVgwTqYIY
```

Output will be in `build/web/`

## Troubleshooting

### "API key invalid" errors
- Check that the API is enabled in Google Cloud Console
- Verify billing is enabled (required for Places API)
- Check API key restrictions (should allow web requests)

### Safe spaces not showing
- Open DevTools console (F12) and check for errors
- Verify `GOOGLE_PLACES_API_KEY` is set correctly
- Check that Places API (New) is enabled in console
- If no API key, app will use fallback sample data

### App crashes on startup
- Run `flutter clean` then `flutter pub get`
- Check that all dependencies are installed
- Verify Flutter version: `flutter --version`

## Team

- Kirti ([@KIRTIRAJ4327](https://github.com/KIRTIRAJ4327))
- DJ
- Yeshi
- Tarun
