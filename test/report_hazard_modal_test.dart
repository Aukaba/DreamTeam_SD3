import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';
import 'package:dreamteam_sd3/widgets/report_hazard_modal.dart';

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

class FakeHazardReportService extends HazardReportService {
  Map<String, dynamic>? lastSubmittedPayload;

  @override
  Future<Map<String, dynamic>> submitReport({
    required String category,
    required String securityLevel,
    required String title,
    required String description,
    required String locationAddress,
    LatLng? location,
    Uint8List? imageBytes,
    int confidence = 98,
    String? mimeType,
  }) async {
    lastSubmittedPayload = {
      'reportID': 'fake-uuid-1234',
      'hazard_category': HazardReportService.cleanCategory(category),
      'detected_hazard': title,
      'severity_level': securityLevel,
      'confidence': confidence,
      'location_address': locationAddress,
      'image_url': 'https://wupbsnrtrsontoajxkir.supabase.co/storage/v1/object/public/hazard-reports/fake-uuid-1234.jpg',
    };
    return lastSubmittedPayload!;
  }
}

void main() {
  testWidgets('ReportHazardContentWidget renders initial screen matching screenshots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportHazardContentWidget(
            onClose: () {},
          ),
        ),
      ),
    );

    // Verify Header
    expect(find.text('COMMUNITY REPORT'), findsOneWidget);
    expect(find.text('Report a hazard'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Verify "Add a photo" card
    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Help our community understand the issue'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // Verify "Current Location" card
    expect(find.text('Current Location'), findsOneWidget);
    expect(find.text('Tap to choose location on map'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    // Verify "Submit Report" button
    expect(find.text('Submit Report'), findsOneWidget);
  });

  testWidgets('Submitting without photo prompts user with snackbar warning', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportHazardContentWidget(
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Submit Report'));
    await tester.pump();

    expect(find.text('Please add and analyze a hazard photo before submitting.'), findsOneWidget);
  });
}
