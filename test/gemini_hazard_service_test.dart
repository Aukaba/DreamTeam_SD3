import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';

void main() {
  group('HazardCategories Tests', () {
    test('contains all 8 required categories', () {
      expect(HazardCategories.all.length, 8);
      expect(HazardCategories.all, contains('🌊 Flood'));
      expect(HazardCategories.all, contains('🚧 Road damage'));
      expect(HazardCategories.all, contains('🚗 Accident'));
      expect(HazardCategories.all, contains('🌳 Fallen tree'));
      expect(HazardCategories.all, contains('🔥 Fire'));
      expect(HazardCategories.all, contains('💡 Broken streetlight'));
      expect(HazardCategories.all, contains('🚫 Blocked road'));
      expect(HazardCategories.all, contains('⚠️ Other'));
    });

    test('normalizes fuzzy strings correctly', () {
      expect(HazardCategories.normalize('flood in the area'), HazardCategories.flood);
      expect(HazardCategories.normalize('pothole on road'), HazardCategories.roadDamage);
      expect(HazardCategories.normalize('car crash'), HazardCategories.accident);
      expect(HazardCategories.normalize('big tree branch down'), HazardCategories.fallenTree);
      expect(HazardCategories.normalize('smoke and fire'), HazardCategories.fire);
      expect(HazardCategories.normalize('dead streetlight'), HazardCategories.brokenStreetlight);
      expect(HazardCategories.normalize('road is blocked'), HazardCategories.blockedRoad);
      expect(HazardCategories.normalize('unknown item'), HazardCategories.other);
      expect(HazardCategories.normalize(null), HazardCategories.other);
    });
  });

  group('HazardSecurityLevels Tests', () {
    test('normalizes security levels accurately', () {
      expect(HazardSecurityLevels.normalize('High'), HazardSecurityLevels.high);
      expect(HazardSecurityLevels.normalize('critical danger'), HazardSecurityLevels.high);
      expect(HazardSecurityLevels.normalize('Low'), HazardSecurityLevels.low);
      expect(HazardSecurityLevels.normalize('slight puddle'), HazardSecurityLevels.low);
      expect(HazardSecurityLevels.normalize('Medium'), HazardSecurityLevels.medium);
      expect(HazardSecurityLevels.normalize(null), HazardSecurityLevels.medium);
    });
  });

  group('GeminiHazardResult parsing', () {
    test('parses successful hazard JSON properly', () {
      final json = {
        'is_hazard': true,
        'hazard_category': '🚧 Road damage',
        'security_level': 'High',
        'title': 'Severe Pothole Cluster',
        'description': 'Deep potholes causing major traffic slowdown.',
        'error_message': null,
      };

      final result = GeminiHazardResult.fromAiJson(json, model: 'gemini-3-flash-preview');
      expect(result.isHazard, isTrue);
      expect(result.category, HazardCategories.roadDamage);
      expect(result.securityLevel, HazardSecurityLevels.high);
      expect(result.title, 'Severe Pothole Cluster');
      expect(result.description, 'Deep potholes causing major traffic slowdown.');
      expect(result.errorMessage, isNull);
      expect(result.modelUsed, 'gemini-3-flash-preview');
    });

    test('parses non-hazard image rejection properly', () {
      final json = {
        'is_hazard': false,
        'hazard_category': null,
        'security_level': null,
        'title': null,
        'description': null,
        'error_message': 'The image shows a plate of pasta, which is not a road hazard.',
      };

      final result = GeminiHazardResult.fromAiJson(json, model: 'gemini-3-flash-preview');
      expect(result.isHazard, isFalse);
      expect(result.errorMessage, contains('plate of pasta'));
    });
  });

  group('GeminiHazardService API Mock Tests', () {
    test('calls Gemini 3 endpoint and returns parsed hazard', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('gemini-3-flash-preview:generateContent'));
        expect(request.url.queryParameters['key'], 'test_fake_api_key_12345');

        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'is_hazard': true,
                      'hazard_category': '🌊 Flood',
                      'security_level': 'High',
                      'title': 'Submerged Roadway',
                      'description': 'Knee-deep floodwaters covering the entire avenue.',
                      'error_message': null,
                    })
                  }
                ]
              }
            }
          ]
        };

        return http.Response(jsonEncode(responsePayload), 200, headers: {'content-type': 'application/json'});
      });

      final service = GeminiHazardService(
        client: mockClient,
        apiKey: 'test_fake_api_key_12345',
      );
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final result = await service.analyzeHazardImage(imageBytes: fakeBytes);
      expect(result.isHazard, isTrue);
      expect(result.category, HazardCategories.flood);
      expect(result.securityLevel, HazardSecurityLevels.high);
      expect(result.title, 'Submerged Roadway');
    });

    test('returns non-hazard result when image is rejected by AI', () async {
      final mockClient = MockClient((request) async {
        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'is_hazard': false,
                      'hazard_category': null,
                      'security_level': null,
                      'title': null,
                      'description': null,
                      'error_message': 'This is a photo of a domestic cat. Please upload a real hazard.',
                    })
                  }
                ]
              }
            }
          ]
        };

        return http.Response(jsonEncode(responsePayload), 200, headers: {'content-type': 'application/json'});
      });

      final service = GeminiHazardService(
        client: mockClient,
        apiKey: 'test_fake_api_key_12345',
      );
      final fakeBytes = Uint8List.fromList([1, 2, 3]);

      final result = await service.analyzeHazardImage(imageBytes: fakeBytes);
      expect(result.isHazard, isFalse);
      expect(result.errorMessage, contains('domestic cat'));
    });

    test('rejects LogoSR.png as non-hazard deterministically with mocked Gemini client', () async {
      final logoBytes = await File('assets/image/LogoSR.png').readAsBytes();

      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('gemini-3-flash-preview:generateContent'));
        final decodedBody = jsonDecode(request.body) as Map<String, dynamic>;
        final parts = ((decodedBody['contents'] as List).first
            as Map<String, dynamic>)['parts'] as List<dynamic>;
        final inlineData = (parts[1] as Map<String, dynamic>)['inlineData']
            as Map<String, dynamic>;
        expect(inlineData['mimeType'], 'image/png');
        expect(inlineData['data'], base64Encode(logoBytes));

        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'is_hazard': false,
                      'hazard_category': null,
                      'security_level': null,
                      'title': null,
                      'description': null,
                      'error_message':
                          'The uploaded image shows an application logo rather than a road or safety hazard.',
                    })
                  }
                ]
              }
            }
          ]
        };

        return http.Response(
          jsonEncode(responsePayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeminiHazardService(
        client: mockClient,
        apiKey: 'deterministic_test_key',
      );

      final result = await service.analyzeHazardImage(
        imageBytes: logoBytes,
        mimeType: 'image/png',
      );
      expect(result.isHazard, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('application logo'));
    });
  });
}
