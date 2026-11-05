import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';

void main() {
  test('Gemini 3 live integration test rejects LogoSR.png as non-hazard', () async {
    await dotenv.load(fileName: '.env');
    final service = GeminiHazardService();
    final bytes = await File('assets/image/LogoSR.png').readAsBytes();

    final result = await service.analyzeHazardImage(imageBytes: bytes, mimeType: 'image/png');
    print('Live AI result isHazard: ${result.isHazard}');
    print('Live AI error message: ${result.errorMessage}');
    print('Model used: ${result.modelUsed}');

    expect(result.isHazard, isFalse);
    expect(result.errorMessage, isNotNull);
    expect(result.errorMessage, isNotEmpty);
  });
}

