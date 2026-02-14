import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants.dart';
import '../data/local/cache_service.dart';
import '../data/models/route_data.dart';

/// AI service using Google Gemini for safety insights
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  final CacheService _cache;
  bool _initialized = false;

  GeminiService({required CacheService cache}) : _cache = cache;

  bool get isAvailable =>
      AppConstants.geminiApiKey.isNotEmpty && _initialized;

  /// Initialize Gemini with API key
  void init() {
    if (AppConstants.geminiApiKey.isEmpty) return;

    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: AppConstants.geminiApiKey,
      systemInstruction: Content.text(AppConstants.geminiSystemPrompt),
    );
    _initialized = true;
  }

  /// Generate a safety summary for a route
  Future<String> generateRouteSummary(RouteData route) async {
    final prompt = '''
Analyze this walking route in York Region, Ontario and give a 1-2 sentence safety summary:
- Route type: ${route.type.label}
- Distance: ${route.distanceMeters.round()}m
- ETA: ${(route.durationSeconds / 60).round()} min
- Crime incidents nearby: ${route.crimesInBuffer}
- Street lighting coverage: ${route.lightingCoverage.round()}%
- Safe spaces nearby: ${route.safeSpacesCount}
- Safety score: ${route.safetyScore.round()}/100

Be reassuring but honest. Format: "[Safety assessment]. [One specific tip]"
''';

    return _generateWithCache(prompt);
  }

  /// Ask a safety question (conversational)
  Future<String> askSafetyQuestion(String question) async {
    if (!isAvailable) {
      return 'AI assistant unavailable. Please set GEMINI_API_KEY.';
    }

    try {
      // Use chat session for context retention
      _chatSession ??= _model!.startChat();

      final response = await _chatSession!.sendMessage(
        Content.text(question),
      );

      return response.text ?? 'I could not generate a response.';
    } catch (e) {
      return 'Sorry, I encountered an error. Please try again.';
    }
  }

  /// Humanize a safety alert
  Future<String> humanizeAlert({
    required String alertType,
    required Map<String, dynamic> data,
  }) async {
    final prompt = '''
Convert this raw safety data into a brief, friendly walking alert (1 sentence):
Type: $alertType
Data: $data
Be reassuring, not scary. Offer an actionable tip.
''';

    return _generateWithCache(prompt);
  }

  /// Reset chat session
  void resetChat() {
    _chatSession = null;
  }

  Future<String> _generateWithCache(String prompt) async {
    // Check cache first
    final cached = _cache.getCachedGeminiResponse(prompt);
    if (cached != null) return cached;

    if (!isAvailable) {
      return _fallbackResponse(prompt);
    }

    try {
      final response = await _model!.generateContent([
        Content.text(prompt),
      ]);

      final text = response.text ?? 'Analysis unavailable.';

      // Cache the response
      await _cache.cacheGeminiResponse(prompt, text);

      return text;
    } catch (_) {
      return _fallbackResponse(prompt);
    }
  }

  /// Fallback responses when Gemini is unavailable
  String _fallbackResponse(String prompt) {
    if (prompt.contains('Safety score')) {
      return 'This route has been analyzed for safety. Check the score breakdown for details.';
    }
    return 'AI analysis is currently unavailable. Safety scores are calculated from real data.';
  }
}
