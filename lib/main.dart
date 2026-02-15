import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/local/cache_service.dart';
import 'providers/route_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Transparent status bar for immersive map experience
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize Hive cache
  final cache = CacheService();
  try {
    await cache.init();
  } catch (e) {
    print('Cache initialization failed: $e');
    // Continue without cache - app will work with API calls only
  }

  runApp(
    ProviderScope(
      overrides: [
        cacheServiceProvider.overrideWithValue(cache),
      ],
      child: const SafePathApp(),
    ),
  );
}
