import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HazardAnalysisResult {
  final String category; // e.g. "Flood", "Road damage", etc.
  final String detected; // e.g. "Flooded Road"
  final int confidence; // e.g. 91
  final String severity; // "Low", "Medium", "High", "Critical"
  final String description;

  HazardAnalysisResult({
    required this.category,
    required this.detected,
    required this.confidence,
    required this.severity,
    required this.description,
  });
}

class GeminiHazardService {
  static const List<String> categories = [
    'Flood',
    'Road damage',
    'Accident',
    'Fallen tree',
    'Fire',
    'Broken streetlight',
    'Blocked road',
    'Other',
  ];

  static const Map<String, String> categoryEmojis = {
    'Flood': '🌊',
    'Road damage': '🚧',
    'Accident': '🚗',
    'Fallen tree': '🌳',
    'Fire': '🔥',
    'Broken streetlight': '💡',
    'Blocked road': '🚫',
    'Other': '⚠️',
  };

  static String getCategoryWithEmoji(String category) {
    final emoji = categoryEmojis[category] ?? '⚠️';
    return '$emoji $category';
  }

  static Future<HazardAnalysisResult> analyzeHazardImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final apiKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();

    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Gemini API key is not configured in .env');
    }

    // High availability models supported on free tier with multimodal input
    final modelsToTry = [
      'gemini-3.5-flash',
      'gemini-3.5-flash-lite',
      'gemini-3.1-flash-lite-preview',
      'gemini-flash-latest',
    ];

    String lastError = '';

    for (final model in modelsToTry) {
      try {
        final base64Image = base64Encode(imageBytes);
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        const prompt = '''
You are an expert civic road safety and hazard inspector.
Examine this image and detect the primary physical hazard shown.

Select EXACTLY ONE of these categories:
- Flood
- Road damage
- Accident
- Fallen tree
- Fire
- Broken streetlight
- Blocked road
- Other

Rules:
- If there is a tree or branch on or blocking the road, choose "Fallen tree".
- If the road has potholes, cracks, or asphalt damage, choose "Road damage".
- If there is standing water or flooding, choose "Flood".
- If vehicles have collided, choose "Accident".
- If a fire is visible, choose "Fire".
- If streetlights are dark or broken, choose "Broken streetlight".
- If the route is physically barricaded or impassable without falling tree, choose "Blocked road".
- Otherwise choose "Other".

Provide:
1. "category": EXACTLY one of the 8 category names listed above.
2. "detected": A brief specific title (2-4 words) describing what is visible (e.g. "Fallen Tree on Road", "Severe Road Pothole", "Vehicle Collision", "Flooded Street").
3. "confidence": Realistic integer between 70 and 98 representing confidence in this identification.
4. "severity": "Low", "Medium", "High", or "Critical" based on threat to traffic or human safety.
5. "description": 1 concise sentence describing the hazard and impact.

Output ONLY valid raw JSON:
{
  "category": "Fallen tree",
  "detected": "Fallen Tree on Road",
  "confidence": 92,
  "severity": "High",
  "description": "A fallen tree trunk is blocking traffic on the road."
}
''';

        final cleanMime = (mimeType.isNotEmpty && mimeType.contains('/'))
            ? mimeType
            : 'image/jpeg';

        final requestBody = jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
                {
                  "inline_data": {
                    "mime_type": cleanMime,
                    "data": base64Image,
                  }
                }
              ]
            }
          ],
          "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.1,
          }
        });

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final candidates = decoded['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final rawText = parts[0]['text'] as String;
              final cleanText = rawText
                  .replaceAll('```json', '')
                  .replaceAll('```', '')
                  .trim();
              final jsonResult = jsonDecode(cleanText);

              String cat = jsonResult['category']?.toString().trim() ?? 'Other';
              final matchedCat = categories.firstWhere(
                (c) => c.toLowerCase() == cat.toLowerCase(),
                orElse: () => 'Other',
              );

              String detected = jsonResult['detected']?.toString().trim() ?? 'Hazard Detected';
              int confidence = (jsonResult['confidence'] as num?)?.toInt() ?? 88;
              if (confidence < 50) confidence = 75;
              if (confidence > 99) confidence = 98;

              String severity = jsonResult['severity']?.toString().trim() ?? 'Medium';
              final validSeverities = ['Low', 'Medium', 'High', 'Critical'];
              final matchedSeverity = validSeverities.firstWhere(
                (s) => s.toLowerCase() == severity.toLowerCase(),
                orElse: () => 'Medium',
              );

              return HazardAnalysisResult(
                category: matchedCat,
                detected: detected,
                confidence: confidence,
                severity: matchedSeverity,
                description: jsonResult['description']?.toString() ?? '',
              );
            }
          }
        } else {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
          debugPrint('Gemini model $model returned error: $lastError');
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('Gemini request error on model $model: $e');
      }
    }

    throw Exception('Gemini analysis failed: $lastError');
  }
}
