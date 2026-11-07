import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';
import 'package:dreamteam_sd3/widgets/camera_capture_screen.dart';
import 'package:dreamteam_sd3/widgets/report_hazard_modal.dart';

final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class FakeGeminiHazardService extends GeminiHazardService {
  final GeminiHazardResult returnResult;

  FakeGeminiHazardService(this.returnResult) : super(apiKey: 'fake_key');

  @override
  Future<GeminiHazardResult> analyzeHazardImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    return returnResult;
  }
}

void main() {
  group('CameraCaptureScreen Widget Tests', () {
    testWidgets('CameraCaptureScreen shows error view when camera list is empty',
        (tester) async {
      CameraCaptureResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<CameraCaptureResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CameraCaptureScreen(cameras: []),
                    ),
                  );
                },
                child: const Text('Open Camera'),
              ),
            ),
          ),
        ),
      );

      // Open camera screen
      await tester.tap(find.text('Open Camera'));
      await tester.pumpAndSettle();

      // Verify empty cameras state UI
      expect(find.text('Camera Not Available'), findsOneWidget);
      expect(
        find.textContaining('No active camera or webcam was found on this device'),
        findsOneWidget,
      );
      expect(find.text('Choose from Gallery / Files'), findsOneWidget);

      // Tapping "Choose from Gallery / Files" should pop with openGallery = true
      await tester.tap(find.text('Choose from Gallery / Files'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.openGallery, isTrue);
      expect(result!.file, isNull);
    });

    testWidgets('CameraCaptureScreen cancel button pops screen without result',
        (tester) async {
      CameraCaptureResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<CameraCaptureResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CameraCaptureScreen(cameras: []),
                    ),
                  );
                },
                child: const Text('Open Camera'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Camera'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('ReportHazardContentWidget Camera Integration Tests', () {
    testWidgets(
        'Tapping Take a Photo uses camera launcher and processes captured photo',
        (tester) async {
      final fakePhoto = XFile.fromData(
        _validPngBytes,
        name: 'live_hazard.png',
        mimeType: 'image/png',
      );

      bool cameraLaunched = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportHazardContentWidget(
                onClose: () {},
                geminiService: FakeGeminiHazardService(
                  const GeminiHazardResult(
                    isHazard: true,
                    category: HazardCategories.roadDamage,
                    securityLevel: HazardSecurityLevels.high,
                    confidence: 96,
                    title: 'Pothole on Main Road',
                    description: 'Large pothole captured by camera.',
                    modelUsed: 'gemini-3-flash-preview',
                  ),
                ),
                cameraLauncher: (context) async {
                  cameraLaunched = true;
                  return fakePhoto;
                },
              ),
            ),
          ),
        ),
      );

      // Open upload action sheet
      await tester.tap(find.text('Add a photo'));
      await tester.pumpAndSettle();

      // Verify the sheet shows 'Take a Photo' and 'Choose from Gallery / Files'
      expect(find.text('Take a Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery / Files'), findsOneWidget);

      // Tap 'Take a Photo'
      await tester.tap(find.text('Take a Photo'));
      await tester.pumpAndSettle();

      // Verify camera was used and AI analyzed the image
      expect(cameraLaunched, isTrue);
      expect(find.text('Pothole on Main Road'), findsOneWidget);
      expect(find.text('Large pothole captured by camera.'), findsOneWidget);
      expect(find.text(HazardCategories.roadDamage), findsOneWidget);
    });
  });
}
