import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HazardAnalysisResult {
  final bool isRoadHazard; // true if it's a genuine road/traffic/civic hazard
  final String category; // e.g. "Flood", "Road damage", etc.
  final String detected; // e.g. "Flooded Road"
  final int confidence; // e.g. 91
  final String severity; // "Low", "Medium", "High", "Critical"
  final String description;
  final String? rejectionReason; // Explanation if not a road hazard

  HazardAnalysisResult({
    required this.isRoadHazard,
    required this.category,
    required this.detected,
    required this.confidence,
    required this.severity,
    required this.description,
    this.rejectionReason,
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
You are an expert civic road safety and hazard verification system.
First, check whether this image actually depicts a legitimate real-world road, street, highway, traffic, or outdoor civic safety hazard.

CRITICAL ROAD HAZARD VALIDATION:
- If the image is unrelated to roads, streets, public pathways, traffic safety, or civic infrastructure (e.g. animals, random clipart, drawings, memes, food, selfies, indoor household objects, screenshots of random apps/illustrations):
  Set "is_road_hazard": false.
  Set "rejection_reason": A friendly explanation like "This photo does not appear to show a road or civic hazard. Please upload a clear photo of a road issue (e.g., potholes, flooding, accidents, or fallen trees)."

- If the image IS a genuine road or outdoor civic hazard:
  Set "is_road_hazard": true.
  Categorize it into EXACTLY ONE of:
  - Flood
  - Road damage
  - Accident
  - Fallen tree
  - Fire
  - Broken streetlight
  - Blocked road
  - Other

Output ONLY raw JSON with these exact fields:
{
  "is_road_hazard": true/false,
  "rejection_reason": "string or null",
  "category": "One of the 8 categories or 'Other'",
  "detected": "Concise specific hazard title (e.g. Fallen Tree on Road, Pothole, Flooded Street)",
  "confidence": integer between 70 and 99,
  "severity": "Low" | "Medium" | "High" | "Critical",
  "description": "Brief description"
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

              final bool isRoadHazard = jsonResult['is_road_hazard'] == true;
              final String? rejectionReason = jsonResult['rejection_reason']?.toString();

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
                isRoadHazard: isRoadHazard,
                category: matchedCat,
                detected: detected,
                confidence: confidence,
                severity: matchedSeverity,
                description: jsonResult['description']?.toString() ?? '',
                rejectionReason: rejectionReason,
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
