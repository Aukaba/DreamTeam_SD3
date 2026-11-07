import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';

final bool _runLiveGeminiTests =
    const bool.fromEnvironment('RUN_LIVE_GEMINI_TESTS') ||
        Platform.environment['RUN_LIVE_GEMINI_TESTS'] == 'true' ||
        Platform.environment['RUN_LIVE_GEMINI_TESTS'] == '1';

void main() {
  test(
    'Gemini 3 live integration test rejects LogoSR.png as non-hazard',
    () async {
      await dotenv.load(fileName: '.env');
      final service = GeminiHazardService();
      final bytes = await File('assets/image/LogoSR.png').readAsBytes();

      final result = await service.analyzeHazardImage(
        imageBytes: bytes,
        mimeType: 'image/png',
      );
      debugPrint('Live AI result isHazard: ${result.isHazard}');
      debugPrint('Live AI error message: ${result.errorMessage}');
      debugPrint('Model used: ${result.modelUsed}');

      expect(result.isHazard, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, isNotEmpty);
    },
    skip: _runLiveGeminiTests
        ? false
        : 'Opt-in live integration test. Set RUN_LIVE_GEMINI_TESTS=true (or --dart-define=RUN_LIVE_GEMINI_TESTS=true) to execute against live Gemini API.',
  );
}
