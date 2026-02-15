import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';

/// Local cache service using Hive for offline data and API response caching
class CacheService {
  static const String _boxName = 'safepath_cache';
  late Box<String> _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  /// Store a value with optional expiry
  Future<void> put(String key, dynamic value) async {
    if (!_initialized) return; // Guard against uninitialized access
    final entry = {
      'data': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _box.put(key, jsonEncode(entry));
  }

  /// Get a cached value, returns null if expired or missing
  T? get<T>(String key) {
    if (!_initialized) return null; // Guard against uninitialized access
    final raw = _box.get(key);
    if (raw == null) return null;

    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final timestamp = entry['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;

    if (age > AppConstants.cacheExpiry.inMilliseconds) {
      _box.delete(key);
      return null;
    }

    return entry['data'] as T?;
  }

  /// Cache a Gemini response
  Future<void> cacheGeminiResponse(String prompt, String response) async {
    final key = 'gemini_${prompt.hashCode}';
    await put(key, response);
  }

  /// Get cached Gemini response
  String? getCachedGeminiResponse(String prompt) {
    final key = 'gemini_${prompt.hashCode}';
    return get<String>(key);
  }

  /// Clear all cached data
  Future<void> clear() async {
    await _box.clear();
  }
}
