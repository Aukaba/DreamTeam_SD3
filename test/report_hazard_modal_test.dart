import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/map_screen.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';
import 'package:dreamteam_sd3/widgets/report_hazard_modal.dart';

/// Valid 1x1 transparent PNG so Image.memory decodes cleanly in widget tests.
final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class FakeImagePicker extends ImagePicker {
  final Uint8List bytes;
  final String fileName;

  FakeImagePicker(this.bytes, {this.fileName = 'hazard.png'});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return XFile.fromData(bytes, name: fileName, mimeType: 'image/png');
  }
}

class SequenceGeminiHazardService extends GeminiHazardService {
  final List<GeminiHazardResult> results;
  int _index = 0;

  SequenceGeminiHazardService(this.results) : super(apiKey: 'fake_key');

  @override
  Future<GeminiHazardResult> analyzeHazardImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final current = results[_index < results.length ? _index : results.length - 1];
    _index++;
    return current;
  }
}

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
  Completer<Map<String, dynamic>>? pendingSubmitCompleter;
  final List<HazardReportData> storedDbReports;

  FakeHazardReportService({List<HazardReportData>? initialDbReports})
      : storedDbReports = List<HazardReportData>.from(initialDbReports ?? []);

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
      'description': description,
      'severity_level': securityLevel,
      'confidence': confidence,
      'location_address': locationAddress,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'image_url':
          'https://wupbsnrtrsontoajxkir.supabase.co/storage/v1/object/public/hazard-reports/fake-uuid-1234.jpg',
      'status': 'active',
      'created_at': '2026-11-06T00:00:00Z',
    };

    if (pendingSubmitCompleter != null) {
      return pendingSubmitCompleter!.future;
    }
    return lastSubmittedPayload!;
  }

  @override
  Future<List<HazardReportData>> fetchReports({
    int limit = 100,
    bool activeOnly = true,
  }) async {
    final byId = <String, HazardReportData>{};
    for (final s in HazardReportService.sessionReports) {
      if (activeOnly && s.status != 'active') continue;
      if (s.reportId != null) byId[s.reportId!] = s;
    }
    for (final db in storedDbReports) {
      if (activeOnly && db.status != 'active') continue;
      if (db.reportId != null) {
        byId.putIfAbsent(db.reportId!, () => db);
      }
    }
    return byId.values.take(limit).toList();
  }
}

void main() {
  setUp(() {
    HazardReportService.clearSessionReports();
  });

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

  testWidgets('Submitting with default Current Location resolves coordinates so lat/lng are never null', (tester) async {
    const resolvedGps = LatLng(10.3215, 123.9052);
    final fakeReportService = FakeHazardReportService();
    HazardReportData? submittedData;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportHazardContentWidget(
              onClose: () {},
              imagePicker: FakeImagePicker(_validPngBytes),
              geminiService: FakeGeminiHazardService(
                const GeminiHazardResult(
                  isHazard: true,
                  category: HazardCategories.roadDamage,
                  securityLevel: HazardSecurityLevels.high,
                  confidence: 97,
                  title: 'Collapsed Manhole Cover',
                  description: 'Open utility hole in right lane.',
                  modelUsed: 'gemini-3-flash-preview',
                ),
              ),
              hazardReportService: fakeReportService,
              currentLocationResolver: () async => resolvedGps,
              onReportSubmitted: (report) => submittedData = report,
            ),
          ),
        ),
      ),
    );

    // Pick & analyze photo
    await tester.tap(find.text('Add a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery / Files'));
    await tester.pumpAndSettle();

    // Submit WITHOUT opening or confirming location picker
    await tester.ensureVisible(find.text('Submit Report'));
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(fakeReportService.lastSubmittedPayload, isNotNull);
    expect(fakeReportService.lastSubmittedPayload!['latitude'], 10.3215);
    expect(fakeReportService.lastSubmittedPayload!['longitude'], 123.9052);
    expect(submittedData, isNotNull);
    expect(submittedData!.location, resolvedGps);
    expect(submittedData!.address, 'Current Location');
  });

  testWidgets('Report snapshot is frozen before awaiting DB so pending mutations do not alter emitted HazardReportData', (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final fakeReportService = FakeHazardReportService()
      ..pendingSubmitCompleter = completer;
    HazardReportData? emittedReport;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportHazardContentWidget(
              onClose: () {},
              initialLocation: const LatLng(10.3150, 123.8900),
              imagePicker: FakeImagePicker(_validPngBytes),
              geminiService: FakeGeminiHazardService(
                const GeminiHazardResult(
                  isHazard: true,
                  category: HazardCategories.brokenStreetlight,
                  securityLevel: HazardSecurityLevels.medium,
                  confidence: 94,
                  title: 'Original Streetlight Outage',
                  description: 'Streetlight dark along crosswalk.',
                  modelUsed: 'gemini-3-flash-preview',
                ),
              ),
              hazardReportService: fakeReportService,
              onReportSubmitted: (report) => emittedReport = report,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery / Files'));
    await tester.pumpAndSettle();

    // Start DB submission (remains pending on completer)
    await tester.ensureVisible(find.text('Submit Report'));
    await tester.tap(find.text('Submit Report'));
    await tester.pump();

    expect(find.text('Submitting to Supabase...'), findsOneWidget);

    // Attempt to tap Low security chip & mutate controller text while DB call is pending
    await tester.tap(find.text('Low'), warnIfMissed: false);
    final titleField = tester.widget<TextField>(find.byType(TextField).first);
    titleField.controller!.text = 'Mutated Title While Pending';
    await tester.pump();

    // Complete pending DB call with the saved row
    completer.complete(fakeReportService.lastSubmittedPayload!);
    await tester.pumpAndSettle();

    expect(emittedReport, isNotNull);
    expect(emittedReport!.title, 'Original Streetlight Outage');
    expect(emittedReport!.securityLevel, HazardSecurityLevels.medium);
    expect(emittedReport!.category, HazardCategories.brokenStreetlight);
  });

  testWidgets('MapScreen loads persisted ReportTable hazards, includes home-modal reports, and filters Broken streetlight under Safety', (tester) async {
    // 1. Simulate a report submitted earlier via home modal before MapScreen opens
    HazardReportService.recordSubmittedReport(
      HazardReportData(
        reportId: 'home-report-101',
        category: HazardCategories.brokenStreetlight,
        securityLevel: HazardSecurityLevels.high,
        title: 'Dark Streetlight Near Fuente',
        description: 'Busted lamp post near rotunda.',
        address: 'Fuente Osmena, Cebu City',
        location: const LatLng(10.3160, 123.8922),
        timestamp: DateTime.now(),
      ),
    );

    // 2. Simulate another user's report stored in Supabase ReportTable
    final fakeReportService = FakeHazardReportService(
      initialDbReports: [
        HazardReportData(
          reportId: 'db-report-202',
          category: HazardCategories.fallenTree,
          securityLevel: HazardSecurityLevels.high,
          title: 'Fallen Acacia Blocking Lane',
          description: 'Large tree across Gorordo Ave.',
          address: 'Gorordo Ave, Cebu City',
          location: const LatLng(10.3154, 123.8918),
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          initialLocation: const LatLng(10.3157, 123.8920),
          hazardReportService: fakeReportService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Expand bottom sheet so both map markers and list cards are visible (pure DB/session count = 2)
    await tester.tap(find.text('2 nearby hazards'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.textContaining('Dark Streetlight Near Fuente', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('Fallen Acacia Blocking Lane', findRichText: true),
      findsWidgets,
    );

    // Tap "Roadwork" filter chip -> Fallen tree stays visible, Broken streetlight is hidden
    await tester.tap(find.text('Roadwork'));
    await tester.pump();
    expect(
      find.textContaining('Fallen Acacia Blocking Lane', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('Dark Streetlight Near Fuente', findRichText: true),
      findsNothing,
    );

    // Tap "Safety" filter chip -> Broken streetlight is visible under Safety, Fallen tree is hidden
    await tester.tap(find.text('Safety'));
    await tester.pump();
    expect(
      find.textContaining('Dark Streetlight Near Fuente', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('Fallen Acacia Blocking Lane', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('Category and Security Level are strictly AI-evaluated and read-only while Title and Description remain editable', (tester) async {
    final fakeReportService = FakeHazardReportService();
    HazardReportData? submittedReport;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportHazardContentWidget(
              onClose: () {},
              initialLocation: const LatLng(10.3157, 123.8920),
              imagePicker: FakeImagePicker(_validPngBytes),
              geminiService: FakeGeminiHazardService(
                const GeminiHazardResult(
                  isHazard: true,
                  category: HazardCategories.roadDamage,
                  securityLevel: HazardSecurityLevels.high,
                  confidence: 99,
                  title: 'Road Cliff Collapse',
                  description: 'Major lane collapse along steep embankment.',
                  modelUsed: 'gemini-3-flash-preview',
                ),
              ),
              hazardReportService: fakeReportService,
              onReportSubmitted: (report) => submittedReport = report,
            ),
          ),
        ),
      ),
    );

    // Upload and analyze photo
    await tester.tap(find.text('Add a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery / Files'));
    await tester.pumpAndSettle();

    // 1. Verify NO DropdownButton exists for category, and AI-evaluated category is displayed
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byKey(const ValueKey('ai_locked_category_box')), findsOneWidget);
    expect(find.text(HazardCategories.roadDamage), findsOneWidget);

    // 2. Attempt tapping the category box and tapping "Low" / "Medium" security pills -> cannot override AI
    await tester.tap(find.byKey(const ValueKey('ai_locked_category_box')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(HazardCategories.flood), findsNothing);

    await tester.tap(find.text('Low'), warnIfMissed: false);
    await tester.tap(find.text('Medium'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 3. Verify Title & Description remain editable by the user
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.at(0), 'Severe Road Washout Near Bridge');
    await tester.enterText(textFields.at(1), 'Half of the asphalt lane has caved into the ravine.');
    await tester.pump();

    // 4. Submit and confirm AI category & level are preserved alongside user-edited details
    await tester.ensureVisible(find.text('Submit Report'));
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(submittedReport, isNotNull);
    expect(submittedReport!.category, HazardCategories.roadDamage);
    expect(submittedReport!.securityLevel, HazardSecurityLevels.high);
    expect(submittedReport!.title, 'Severe Road Washout Near Bridge');
    expect(submittedReport!.description, 'Half of the asphalt lane has caved into the ravine.');
    expect(fakeReportService.lastSubmittedPayload!['hazard_category'], 'Road damage');
    expect(fakeReportService.lastSubmittedPayload!['severity_level'], 'High');
  });

  testWidgets('Replacing a verified hazard photo with a rejected non-hazard clears stale AI category and level', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportHazardContentWidget(
              onClose: () {},
              initialLocation: const LatLng(10.3157, 123.8920),
              imagePicker: FakeImagePicker(_validPngBytes),
              geminiService: SequenceGeminiHazardService([
                const GeminiHazardResult(
                  isHazard: true,
                  category: HazardCategories.flood,
                  securityLevel: HazardSecurityLevels.high,
                  confidence: 96,
                  title: 'Deep Street Flooding',
                  description: 'Water covering road.',
                  modelUsed: 'gemini-3-flash-preview',
                ),
                GeminiHazardResult.notAHazard(
                  reason: 'This image shows a coffee mug indoors.',
                  modelUsed: 'gemini-3-flash-preview',
                ),
              ]),
              hazardReportService: FakeHazardReportService(),
            ),
          ),
        ),
      ),
    );

    // First photo: valid hazard
    await tester.tap(find.text('Add a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery / Files'));
    await tester.pumpAndSettle();
    expect(find.text(HazardCategories.flood), findsOneWidget);

    // Second photo via "Change": non-hazard rejected -> stale AI evaluation must disappear
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery / Files'));
    await tester.pumpAndSettle();

    // Dismiss "Not a Hazard" dialog
    expect(find.text('Not a Hazard'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai_locked_category_box')), findsNothing);
    expect(find.text(HazardCategories.flood), findsNothing);
    expect(find.text('Add a photo'), findsOneWidget);
  });
}
