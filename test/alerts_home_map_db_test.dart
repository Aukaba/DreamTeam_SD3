import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/map_screen.dart';
import 'package:dreamteam_sd3/services/alert_service.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';
import 'package:dreamteam_sd3/user_screens/alerts_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_home_screen.dart';

class FakeDbHazardReportService extends HazardReportService {
  final List<HazardReportData> dbReports;

  FakeDbHazardReportService({List<HazardReportData>? initialReports})
      : dbReports = List<HazardReportData>.from(initialReports ?? const []);

  @override
  Future<List<HazardReportData>> fetchReports({
    int limit = 100,
    bool activeOnly = true,
  }) async {
    final merged = <String, HazardReportData>{};
    for (final s in HazardReportService.sessionReports) {
      if (s.location == null) continue;
      if (activeOnly && s.status != 'active') continue;
      if (s.reportId != null) merged[s.reportId!] = s;
    }
    for (final r in dbReports) {
      if (r.location == null) continue;
      if (activeOnly && r.status != 'active') continue;
      if (r.reportId != null) merged.putIfAbsent(r.reportId!, () => r);
    }
    final list = merged.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list.take(limit).toList();
  }
}

class FakeDbAlertService extends AlertService {
  final List<AlertItem> storedAlerts;
  final Set<String> readIds = <String>{};
  final Set<String> dismissedIds = <String>{};

  FakeDbAlertService({List<AlertItem>? initialAlerts})
      : storedAlerts = List<AlertItem>.from(initialAlerts ?? const []);

  @override
  Future<List<AlertItem>> fetchAlerts({int limit = 50}) async {
    final visible = <AlertItem>[];
    final seenReportIds = <String>{};

    for (final a in storedAlerts) {
      if (a.reportId != null) seenReportIds.add(a.reportId!);
      if (dismissedIds.contains(a.id) || a.isDismissed) continue;
      visible.add(a.copyWith(isRead: a.isRead || readIds.contains(a.id)));
    }

    for (final session in HazardReportService.sessionReports) {
      if (session.location == null || session.status != 'active') continue;
      if (session.reportId != null && seenReportIds.contains(session.reportId)) {
        continue;
      }
      final derived = AlertItem.fromHazardReport(session);
      if (dismissedIds.contains(derived.id)) continue;
      visible.add(derived.copyWith(isRead: readIds.contains(derived.id)));
    }

    visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    AlertService.unreadCountNotifier.value =
        visible.where((a) => !a.isRead).length;
    return visible.take(limit).toList();
  }

  @override
  Future<void> markAsRead(String alertId) async {
    readIds.add(alertId);
  }

  @override
  Future<void> markAllAsRead(Iterable<String> alertIds) async {
    readIds.addAll(alertIds);
    AlertService.unreadCountNotifier.value = 0;
  }

  @override
  Future<void> dismissAlert(String alertId) async {
    dismissedIds.add(alertId);
    readIds.add(alertId);
  }

  @override
  Future<void> restoreDismissedAlert(String alertId) async {
    dismissedIds.remove(alertId);
  }
}

void main() {
  setUp(() {
    HazardReportService.clearSessionReports();
    AlertService.clearSessionState();
  });

  group('AlertItem & AlertService Unit Tests', () {
    test('AlertItem.fromAlertRow parses hazard, community, and system rows accurately', () {
      final hazardRow = {
        'id': '9675ca77-5c16-4f4a-8028-fa59572c0270',
        'alert_type': 'hazard',
        'title': 'Severe Road Collapse',
        'body': 'A user reported road damage near Dragonfly Cafe (High severity).',
        'location_label': 'Near Dragonfly Cafe, Ground floor 8',
        'latitude': 10.31036,
        'longitude': 123.87655,
        'severity_level': 'High',
        'report_id': 'c80c4ea2-90aa-40a1-95b8-aacb1d4a1617',
        'created_at': '2026-11-05T19:46:24Z',
      };

      final parsed = AlertItem.fromAlertRow(hazardRow);
      expect(parsed.type, AlertType.hazard);
      expect(parsed.title, 'Severe Road Collapse');
      expect(parsed.locationLabel, 'Near Dragonfly Cafe, Ground floor 8');
      expect(parsed.location, const LatLng(10.31036, 123.87655));
      expect(parsed.reportId, 'c80c4ea2-90aa-40a1-95b8-aacb1d4a1617');
      expect(parsed.isRead, isFalse);
    });

    test('AlertItem.fromHazardReport classifies high/emergency as hazard and medium roadwork as community', () {
      final highRoad = HazardReportData(
        reportId: 'r-high',
        category: HazardCategories.roadDamage,
        securityLevel: HazardSecurityLevels.high,
        title: 'Major Sinkhole',
        description: 'Deep sinkhole blocking right lane.',
        address: 'Escario St, Kamputhaw, Cebu City',
        location: const LatLng(10.3168, 123.8891),
        timestamp: DateTime.now(),
      );
      final medRoad = HazardReportData(
        reportId: 'r-med',
        category: HazardCategories.blockedRoad,
        securityLevel: HazardSecurityLevels.medium,
        title: 'Temporary Lane Closure',
        description: '',
        address: 'Colon St, Cebu City',
        location: const LatLng(10.2983, 123.8998),
        timestamp: DateTime.now(),
      );

      final alertHigh = AlertItem.fromHazardReport(highRoad);
      final alertMed = AlertItem.fromHazardReport(medRoad);

      expect(alertHigh.type, AlertType.hazard);
      expect(alertHigh.body, 'Deep sinkhole blocking right lane.');
      expect(alertHigh.locationLabel, 'Near Escario St, Kamputhaw');

      expect(alertMed.type, AlertType.community);
      expect(alertMed.locationLabel, 'Near Colon St, Cebu City');
    });
  });

  group('AlertsScreen DB Connection Widget Tests', () {
    testWidgets('renders DB alerts with accurate filter chip counts, marks all read, and navigates to MapScreen on hazard tap', (tester) async {
      final fakeReportService = FakeDbHazardReportService(
        initialReports: [
          HazardReportData(
            reportId: 'rep-banawa-1',
            category: HazardCategories.roadDamage,
            securityLevel: HazardSecurityLevels.high,
            title: 'Severe Road Collapse',
            description: 'Half of the lane caved in near Banawa.',
            address: 'Ramon Duterte St, Banawa',
            location: const LatLng(10.3104, 123.8765),
            timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
        ],
      );

      final fakeAlertService = FakeDbAlertService(
        initialAlerts: [
          AlertItem(
            id: '11111111-1111-4111-8111-111111111111',
            type: AlertType.hazard,
            title: 'Severe Road Collapse',
            body: 'Half of the lane caved in near Banawa.',
            locationLabel: 'Near Ramon Duterte St, Banawa',
            location: const LatLng(10.3104, 123.8765),
            severityLevel: 'High',
            reportId: 'rep-banawa-1',
            createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
          AlertItem(
            id: '22222222-2222-4222-8222-222222222222',
            type: AlertType.community,
            title: 'Pothole on Main St',
            body: 'Community report: road damage near Colon St.',
            locationLabel: 'Near Colon St, Cebu City',
            location: const LatLng(10.2983, 123.8998),
            severityLevel: 'Medium',
            reportId: 'rep-colon-2',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          AlertItem(
            id: '00000000-0000-4000-8000-000000000001',
            type: AlertType.system,
            title: 'Live Hazard Monitoring Active',
            body: 'SafeRoute Gemini AI hazard verification is active.',
            locationLabel: 'System Notice',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlertsScreen(
            alertService: fakeAlertService,
            hazardReportService: fakeReportService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify all 3 DB alerts render and unread badge equals 3
      expect(find.text('Severe Road Collapse'), findsOneWidget);
      expect(find.text('Pothole on Main St'), findsOneWidget);
      expect(find.text('Live Hazard Monitoring Active'), findsOneWidget);
      expect(AlertService.unreadCountNotifier.value, 3);
      expect(find.text('Mark all read'), findsOneWidget);

      // Filter by Community -> only Community alert shows
      await tester.tap(find.text('Community'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Pothole on Main St'), findsOneWidget);
      expect(find.text('Severe Road Collapse'), findsNothing);

      // Switch back to All and mark all read
      await tester.tap(find.text('All'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Mark all read'));
      await tester.pump();
      expect(AlertService.unreadCountNotifier.value, 0);
      expect(fakeAlertService.readIds.length, 3);

      // Tap located Hazard Alert -> navigates to MapScreen and opens hazard detail sheet
      await tester.tap(find.text('Severe Road Collapse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.text('Half of the lane caved in near Banawa.'), findsOneWidget);
    });

    testWidgets('swipe-to-dismiss persists dismissal and Undo restores the alert', (tester) async {
      final fakeAlertService = FakeDbAlertService(
        initialAlerts: [
          AlertItem(
            id: '00000000-0000-4000-8000-000000000001',
            type: AlertType.system,
            title: 'Live Hazard Monitoring Active',
            body: 'SafeRoute Gemini AI hazard verification is active.',
            locationLabel: 'System Notice',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlertsScreen(alertService: fakeAlertService),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Live Hazard Monitoring Active'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('alert_card_00000000-0000-4000-8000-000000000001')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Hazard Monitoring Active'), findsNothing);
      expect(
        fakeAlertService.dismissedIds
            .contains('00000000-0000-4000-8000-000000000001'),
        isTrue,
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Live Hazard Monitoring Active'), findsOneWidget);
      expect(
        fakeAlertService.dismissedIds
            .contains('00000000-0000-4000-8000-000000000001'),
        isFalse,
      );
    });
  });

  group('UserHomeScreen Recent Hazards & Hazards by Type DB Tests', () {
    testWidgets('displays DB recent hazards, category counts, caution banner within 500m, and live-updates on new report', (tester) async {
      const homeLocation = LatLng(10.3157, 123.8920);
      final fakeReportService = FakeDbHazardReportService(
        initialReports: [
          HazardReportData(
            reportId: 'home-db-1',
            category: HazardCategories.roadDamage,
            securityLevel: HazardSecurityLevels.high,
            title: 'Collapsed Curb on Fuente',
            description: 'Broken concrete curb.',
            address: 'Fuente Osmena, Cebu City',
            location: const LatLng(10.3160, 123.8922), // < 100m away
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          HazardReportData(
            reportId: 'home-db-2',
            category: HazardCategories.flood,
            securityLevel: HazardSecurityLevels.medium,
            title: 'Ankle-Deep Water on Colon',
            description: 'Minor street flooding.',
            address: 'Colon St, Cebu City',
            location: const LatLng(10.2983, 123.8998), // ~2.1 km away
            timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        ],
      );
      final fakeAlertService = FakeDbAlertService();

      await tester.pumpWidget(
        MaterialApp(
          home: UserHomeScreen(
            hazardReportService: fakeReportService,
            alertService: fakeAlertService,
            initialLocation: homeLocation,
            skipLocationLookup: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify hardcoded placeholders are gone and real DB items are shown
      expect(find.text('Roadwork on Escario St.'), findsNothing);
      expect(find.text('Collapsed Curb on Fuente'), findsOneWidget);
      expect(find.text('Ankle-Deep Water on Colon'), findsOneWidget);

      // High-risk hazard within 500m triggers Caution status on Live Map card
      expect(find.text('Caution: High-risk hazard nearby'), findsOneWidget);

      // Verify Hazards by Type live counts (1 Roadwork, 1 Flooding, 0 Safety)
      expect(find.text('Roadwork'), findsOneWidget);
      expect(find.text('Flooding'), findsOneWidget);
      expect(find.text('Safety'), findsOneWidget);
      expect(find.text('1 active'), findsNWidgets(2));
      expect(find.text('0 active'), findsOneWidget);

      // Emit a new Safety hazard report -> Home updates Recent Hazards & Safety count live
      HazardReportService.recordSubmittedReport(
        HazardReportData(
          reportId: 'home-live-3',
          category: HazardCategories.brokenStreetlight,
          securityLevel: HazardSecurityLevels.medium,
          title: 'Busted Lamp on Mango Ave',
          description: 'Dark stretch near intersection.',
          address: 'General Maxilom Ave, Cebu City',
          location: const LatLng(10.3125, 123.8965),
          timestamp: DateTime.now(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Busted Lamp on Mango Ave'), findsOneWidget);
      expect(find.text('1 active'), findsNWidgets(3));
      expect(find.text('0 active'), findsNothing);
    });
  });

  group('MapScreen Pure DB Hazards Tests', () {
    testWidgets('shows 0 nearby hazards and safe area status when ReportTable has no active reports', (tester) async {
      final emptyService = FakeDbHazardReportService(initialReports: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            initialLocation: const LatLng(10.3157, 123.8920),
            hazardReportService: emptyService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('0 nearby hazards'), findsOneWidget);
      expect(find.text('You are in a safe area'), findsOneWidget);
      expect(find.text('Poor lighting area'), findsNothing);
    });
  });
}
