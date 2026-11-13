import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Represents one of the 8 allowed hazard categories.
class HazardCategories {
  static const String flood = '🌊 Flood';
  static const String roadDamage = '🚧 Road damage';
  static const String accident = '🚗 Accident';
  static const String fallenTree = '🌳 Fallen tree';
  static const String fire = '🔥 Fire';
  static const String brokenStreetlight = '💡 Broken streetlight';
  static const String blockedRoad = '🚫 Blocked road';
  static const String other = '⚠️ Other';

  static const List<String> all = [
    flood,
    roadDamage,
    accident,
    fallenTree,
    fire,
    brokenStreetlight,
    blockedRoad,
    other,
  ];

  /// Normalizes any AI category output to one of the canonical 8 categories.
  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return other;
    final trimmed = raw.trim();
    // 1. Exact match check
    for (final cat in all) {
      if (trimmed == cat) return cat;
    }
    final lower = trimmed.toLowerCase();

    // 2. Flood / Water
    if (lower.contains('flood') || lower.contains('water') || lower.contains('baha') || lower.contains('submerged')) {
      return flood;
    }

    // 3. Fire / Smoke
    if (lower.contains('fire') || lower.contains('smoke') || lower.contains('flame') || lower.contains('blaze')) {
      return fire;
    }

    // 4. Streetlight / Lighting (Check before 'tree' to avoid matching 'street' with 'tree')
    if (lower.contains('streetlight') ||
        lower.contains('street light') ||
        lower.contains('light bulb') ||
        lower.contains('lighting') ||
        lower.contains('lamp post') ||
        lower.contains('lamppost') ||
        lower.contains('dark street')) {
      return brokenStreetlight;
    }

    // 5. Road damage / Pothole
    if (lower.contains('road damage') ||
        lower.contains('pothole') ||
        lower.contains('sinkhole') ||
        lower.contains('crack') ||
        lower.contains('broken asphalt') ||
        lower.contains('asphalt')) {
      return roadDamage;
    }

    // 6. Accident / Collision
    if (lower.contains('accident') || lower.contains('crash') || lower.contains('collision') || lower.contains('wreck')) {
      return accident;
    }

    // 7. Fallen tree / Downed branch
    if (RegExp(r'\b(tree|trees|branch|branches|fallen|downed tree)\b').hasMatch(lower)) {
      return fallenTree;
    }

    // 8. Blocked road / Obstruction
    if (lower.contains('blocked') ||
        lower.contains('obstruction') ||
        lower.contains('closure') ||
        lower.contains('barricade') ||
        lower.contains('impassable')) {
      return blockedRoad;
    }
    return other;
  }
}

/// Security or severity level evaluated for a reported hazard.
class HazardSecurityLevels {
  static const String low = 'Low';
  static const String medium = 'Medium';
  static const String high = 'High';

  static const List<String> all = [low, medium, high];

  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return medium;
    final lower = raw.trim().toLowerCase();
    if (lower.contains('high') || lower.contains('critical') || lower.contains('severe') || lower.contains('danger')) {
      return high;
    }
    if (lower.contains('low') || lower.contains('minor') || lower.contains('slight')) {
      return low;
    }
    return medium;
  }
}

/// Result returned from Gemini AI hazard image processing.
class GeminiHazardResult {
  final bool isHazard;
  final String category;
  final String securityLevel;
  final bool isImpassable;
  final int confidence;
  final String title;
  final String description;
  final String? errorMessage;
  final String modelUsed;

  const GeminiHazardResult({
    required this.isHazard,
    required this.category,
    required this.securityLevel,
    this.isImpassable = false,
    this.confidence = 95,
    required this.title,
    required this.description,
    this.errorMessage,
    required this.modelUsed,
  });

  factory GeminiHazardResult.notAHazard({
    required String reason,
    required String modelUsed,
  }) {
    return GeminiHazardResult(
      isHazard: false,
      category: HazardCategories.other,
      securityLevel: HazardSecurityLevels.low,
      isImpassable: false,
      confidence: 0,
      title: 'Not a Hazard',
      description: reason,
      errorMessage: reason,
      modelUsed: modelUsed,
    );
  }

  factory GeminiHazardResult.fromAiJson(Map<String, dynamic> json, {required String model}) {
    final rawIsHazard = json['is_hazard'];
    final bool isHazard = rawIsHazard == true ||
        rawIsHazard?.toString().trim().toLowerCase() == 'true';
    final String? errorMsg = json['error_message']?.toString();

    if (!isHazard) {
      final reason = errorMsg?.isNotEmpty == true
          ? errorMsg!
          : 'The uploaded image does not appear to show a community or road hazard. Please upload a clear photo of an actual hazard.';
      return GeminiHazardResult.notAHazard(
        reason: reason,
        modelUsed: model,
      );
    }

    final rawCategory = json['hazard_category']?.toString();
    final rawSecurity = json['security_level']?.toString();
    final rawTitle = json['title']?.toString();
    final rawDesc = json['description']?.toString();
    final rawConfidence = json['confidence'];
    final rawIsImpassable = json['is_impassable'];

    final bool? isImpassable = rawIsImpassable is bool
        ? rawIsImpassable
        : (rawIsImpassable?.toString().trim().toLowerCase() == 'true'
            ? true
            : (rawIsImpassable?.toString().trim().toLowerCase() == 'false'
                ? false
                : null));

    int confidence = 95;
    if (rawConfidence is num) {
      confidence = rawConfidence.round().clamp(1, 100);
    }

    final category = HazardCategories.normalize(rawCategory);
    var securityLevel = HazardSecurityLevels.normalize(rawSecurity);

    // Enforce toned-down severity rule:
    // Only use High if the road is completely impassable.
    if (securityLevel == HazardSecurityLevels.high) {
      if (isImpassable == true) {
        // Road is explicitly impassable -> keep High
      } else if (isImpassable == false) {
        // Road is explicitly not impassable -> tone down to Medium
        securityLevel = HazardSecurityLevels.medium;
      } else {
        // If is_impassable was omitted by the AI, inspect textual cues
        final textCombined = ' ${rawTitle ?? ''} ${rawDesc ?? ''} '.toLowerCase();
        final hasImpassable = textCombined.contains('impassable');
        final indicatesPassable = !hasImpassable &&
            (textCombined.contains('driving through') ||
                textCombined.contains('drives through') ||
                textCombined.contains('passing through') ||
                textCombined.contains('passes through') ||
                RegExp(r'\bpassable\b').hasMatch(textCombined) ||
                textCombined.contains('navigable') ||
                textCombined.contains('can pass') ||
                textCombined.contains('moving through') ||
                textCombined.contains('able to pass'));

        if (indicatesPassable) {
          securityLevel = HazardSecurityLevels.medium;
        }
      }
    }

    final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : _defaultTitleForCategory(category);
    final description = (rawDesc != null && rawDesc.trim().isNotEmpty)
        ? rawDesc.trim()
        : 'Reported $category with $securityLevel security risk.';

    return GeminiHazardResult(
      isHazard: true,
      category: category,
      securityLevel: securityLevel,
      isImpassable: isImpassable ?? (securityLevel == HazardSecurityLevels.high),
      confidence: confidence,
      title: title,
      description: description,
      errorMessage: null,
      modelUsed: model,
    );
  }

  static String _defaultTitleForCategory(String category) {
    switch (category) {
      case HazardCategories.flood:
        return 'Street Flooding';
      case HazardCategories.roadDamage:
        return 'Road Surface Damage';
      case HazardCategories.accident:
        return 'Traffic Accident';
      case HazardCategories.fallenTree:
        return 'Fallen Tree Obstruction';
      case HazardCategories.fire:
        return 'Fire Hazard';
      case HazardCategories.brokenStreetlight:
        return 'Broken Streetlight';
      case HazardCategories.blockedRoad:
        return 'Blocked Roadway';
      default:
        return 'Reported Hazard';
    }
  }
}

/// Service that communicates with Gemini 3+ models to analyze hazard photos.
class GeminiHazardService {
  /// Allowed Gemini 3+ models in order of priority.
  /// gemini-3-flash-preview and gemini-3.5-flash provide high speed and multimodal reliability.
  static const List<String> _gemini3Models = [
    'gemini-3-flash-preview',
    'gemini-3.5-flash',
    'gemini-3.8-flash',
  ];

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client _client;
  final String? _apiKey;

  GeminiHazardService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey;

  /// Retrieve API key from constructor or environment (.env).
  String _getApiKey() {
    final key = _apiKey ?? dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.trim().isEmpty) {
      throw StateError(
        'GEMINI_API_KEY is not defined in the .env file. Please ensure GEMINI_API_KEY is configured.',
      );
    }
    return key.trim();
  }

  /// Analyzes an image with Gemini 3 AI to determine if it is a real hazard,
  /// its Hazard Category, and its Security Level.
  Future<GeminiHazardResult> analyzeHazardImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final apiKey = _getApiKey();
    final base64Image = base64Encode(imageBytes);

    const prompt = '''
You are an expert AI road safety, community incident, and municipal hazard inspector.
Analyze this photo and determine if it depicts a real-world community, traffic, road, pedestrian, infrastructure, or environmental HAZARD.

ALLOWED HAZARD CATEGORIES (MUST BE EXACTLY ONE OF THESE):
- 🌊 Flood
- 🚧 Road damage
- 🚗 Accident
- 🌳 Fallen tree
- 🔥 Fire
- 💡 Broken streetlight
- 🚫 Blocked road
- ⚠️ Other

SECURITY LEVEL GUIDELINES (TONE DOWN SEVERITY - CONSERVATIVE THRESHOLD):
- "High": ONLY use "High" if the road or route is completely IMPASSABLE to traffic/vehicles (e.g. road completely washed away or submerged in impassable deep floodwaters, collapsed bridge, total blockage where vehicles cannot pass, active fire engulfing the roadway, catastrophic multi-lane collision). If vehicles or pedestrians can still pass through, navigate around, or drive through (such as cars driving through floodwater/puddles, partial blockages, single-lane obstructions), DO NOT use "High".
- "Medium": Significant obstruction, warning, or slowdown where the road remains PASSABLE (e.g. vehicles are driving through or can drive through standing water/flooding with caution, potholes, partial lane obstruction, fallen branch with room to pass, malfunctioning traffic signals).
- "Low": Minor hazard with minimal impact to traffic flow (e.g. shallow puddling, minor potholes/cracks, roadside debris, burnt-out streetlight on a quiet street, damaged curb).

CRITICAL HAZARD VALIDATION RULES:
1. If the photo does NOT depict an actual road, traffic, public safety, or community hazard (e.g. selfies, portraits, pets, food, indoor furniture, normal intact cars, clean undamaged roads, logos, memes, computer screenshots, landscapes without danger):
   You MUST set "is_hazard": false.
   You MUST provide a helpful "error_message" explaining clearly what the photo shows and that it is not a hazard.
2. If the photo DOES depict a valid hazard:
   Set "is_hazard": true.
   Set "hazard_category" to one of the 8 exact emojis + labels above.
   Set "is_impassable": true ONLY if the road/route is completely closed or impassable to traffic; set false if vehicles or pedestrians can still pass through or drive across.
   Set "security_level" to "Low", "Medium", or "High" following the rule: ONLY use "High" if "is_impassable" is true. If "is_impassable" is false, you MUST choose "Medium" or "Low" (tone down severity).
   Set "confidence" to an integer between 1 and 100 (e.g. 98, 100) indicating detection certainty.
   Set "title" to a concise summary (under 45 characters, e.g. "Deep Pothole on Lane").
   Set "description" to a clear 1-2 sentence description of what is seen.
   Set "error_message": null.

Return your answer strictly as a JSON object matching this schema:
{
  "is_hazard": boolean,
  "hazard_category": string or null,
  "security_level": string or null,
  "is_impassable": boolean or null,
  "confidence": integer or null,
  "title": string or null,
  "description": string or null,
  "error_message": string or null
}
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
      }
    });

    String? lastError;

    // Try Gemini 3 models with fallback for high resilience
    for (final model in _gemini3Models) {
      try {
        final uri = Uri.parse('$_baseUrl/$model:generateContent?key=$apiKey');
        final response = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 35));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = decoded['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final firstCandidate = candidates.first as Map<String, dynamic>;
            final content = firstCandidate['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final textPart = parts.first['text'] as String?;
              if (textPart != null && textPart.trim().isNotEmpty) {
                final parsedJson = _cleanAndParseJson(textPart);
                return GeminiHazardResult.fromAiJson(parsedJson, model: model);
              }
            }
          }
          lastError = 'Invalid candidate structure from $model';
        } else if (response.statusCode == 503 || response.statusCode == 429) {
          // Model busy, try next Gemini 3 model
          debugPrint('Gemini model $model returned ${response.statusCode}, trying fallback model...');
          lastError = 'Model $model busy (${response.statusCode})';
          continue;
        } else if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          // Non-retryable client / credential / payload error: preserve root error immediately
          debugPrint('Gemini model $model returned client error ${response.statusCode}: ${response.body}');
          lastError = 'Gemini error ${response.statusCode}: ${response.body}';
          break;
        } else {
          debugPrint('Gemini model $model returned error ${response.statusCode}: ${response.body}');
          lastError ??= 'Gemini error ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        debugPrint('Failed to query Gemini model $model: $e');
        lastError = e.toString();
      }
    }

    throw Exception(
      'Gemini AI hazard analysis failed: ${lastError ?? 'Unable to connect to Gemini 3 service.'}',
    );
  }

  /// Strips markdown fences if present and parses JSON safely.
  Map<String, dynamic> _cleanAndParseJson(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }
}
