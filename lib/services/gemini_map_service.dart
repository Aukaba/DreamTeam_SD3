import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/place_recommendation.dart';

class GeminiMapService {
  String? _customApiKey;

  GeminiMapService({String? customApiKey}) : _customApiKey = customApiKey;

  String? get currentApiKey =>
      _customApiKey ?? dotenv.env['GEMINI_API_KEY'];

  bool get isConfigured {
    final key = currentApiKey;
    return key != null && key.trim().isNotEmpty && !key.contains('YOUR_');
  }

  void setCustomApiKey(String key) {
    _customApiKey = key;
  }

  GenerativeModel _getModel(String modelName) {
    final key = currentApiKey;
    if (key == null || key.trim().isEmpty) {
      throw Exception('Gemini API Key is not configured. Please add GEMINI_API_KEY in .env or provide it in the app.');
    }

    return GenerativeModel(
      model: modelName,
      apiKey: key.trim(),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<List<PlaceRecommendation>> searchPlaces({
    required String query,
    required double referenceLat,
    required double referenceLng,
  }) async {
    final prompt = '''
You are an intelligent geospatial assistant and local travel expert.
The user is searching for places with this natural language query: "$query".
Their reference coordinates are latitude: $referenceLat, longitude: $referenceLng.

Search for realistic, specific places matching the user's intent located in or around this location (or the specific city or region mentioned in the query).
Respond ONLY with a JSON array conforming to this exact schema:
[
  {
    "title": "Exact name of place/venue",
    "description": "Engaging 1-2 sentence description explaining what it is and why it fits the query",
    "category": "cafe|park|restaurant|landmark|nature|shopping|culture|other",
    "latitude": 0.000000,
    "longitude": 0.000000
  }
]
Return between 3 to 6 top recommendations. Ensure coordinates are geographically realistic and accurate.
''';

    // Active models for this API key
    final candidateModels = ['gemini-3.5-flash', 'gemini-3.7-flash', 'gemini-3.8-flash'];
    GenerateContentResponse? response;
    Object? lastError;

    for (final modelName in candidateModels) {
      try {
        final model = _getModel(modelName);
        response = await model.generateContent([Content.text(prompt)]);
        break; // Successfully got response
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    if (response == null) {
      throw Exception('Failed to communicate with Gemini API: $lastError');
    }

    var text = response.text;
    if (text == null || text.trim().isEmpty) {
      return [];
    }

    text = text.trim();
    if (text.startsWith('```json')) {
      text = text.replaceFirst('```json', '');
    }
    if (text.startsWith('```')) {
      text = text.replaceFirst('```', '');
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
    text = text.trim();

    try {
      final dynamic decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((item) => PlaceRecommendation.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (decoded is Map<String, dynamic> && decoded.containsKey('places')) {
        final list = decoded['places'] as List;
        return list
            .map((item) => PlaceRecommendation.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to parse AI recommendations: $e');
    }
  }
}
