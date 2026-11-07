import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamteam_sd3/map_screen.dart';
import 'package:dreamteam_sd3/services/alert_service.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';
import 'package:dreamteam_sd3/services/safe_route_service.dart';
import 'package:dreamteam_sd3/services/saved_location_service.dart';
import 'package:dreamteam_sd3/user_screens/route_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_home_screen.dart';
import 'package:dreamteam_sd3/widgets/turn_by_turn_navigation_overlay.dart';

/// Encodes a list of [LatLng] points into a Google/Valhalla polyline string
/// with configurable [precision] (6 for Valhalla `polyline6`).
String encodeTestPolyline(List<LatLng> points, {int precision = 6}) {
  final factor = precision == 6 ? 1000000.0 : 100000.0;
  final buffer = StringBuffer();
  int prevLat = 0;
  int prevLng = 0;

  void writeValue(int v) {
    int val = v < 0 ? (-2 * v - 1) : (2 * v);
    while (val >= 32) {
      buffer.writeCharCode((32 + (val % 32)) + 63);
      val ~/= 32;
    }
    buffer.writeCharCode(val + 63);
  }

  for (final pt in points) {
    final lat = (pt.latitude * factor).round();
    final lng = (pt.longitude * factor).round();
    writeValue(lat - prevLat);
    writeValue(lng - prevLng);
    prevLat = lat;
    prevLng = lng;
  }
  return buffer.toString();
}

class FakeHazardReportService extends HazardReportService {
  final List<HazardReportData> reports;

  FakeHazardReportService({List<HazardReportData>? initialReports})
      : reports = List<HazardReportData>.from(initialReports ?? const []);

  @override
  Future<List<HazardReportData>> fetchReports({
    int limit = 100,
    bool activeOnly = true,
  }) async {
    final merged = <HazardReportData>[
      ...HazardReportService.sessionReports,
      ...reports,
    ];
    return merged
        .where((r) => r.location != null && (!activeOnly || r.status == 'active'))
        .take(limit)
        .toList();
  }
}

class FakeAlertService extends AlertService {
  @override
  Future<List<AlertItem>> fetchAlerts({int limit = 50}) async => const [];
}

/// Builds a mock Valhalla JSON response for testing turn-by-turn maneuvers.
String buildValhallaTripResponse({
  required List<LatLng> shapePoints,
  required double lengthKm,
  required double timeSeconds,
  required List<Map<String, dynamic>> maneuvers,
}) {
  return json.encode(<String, dynamic>{
    'trip': <String, dynamic>{
      'legs': <Map<String, dynamic>>[
        <String, dynamic>{
          'shape': encodeTestPolyline(shapePoints, precision: 6),
          'summary': <String, dynamic>{
            'length': lengthKm,
            'time': timeSeconds,
          },
          'maneuvers': maneuvers,
        },
      ],
      'summary': <String, dynamic>{
        'length': lengthKm,
        'time': timeSeconds,
      },
      'status': 0,
    },
  });
}

void main() {
  const origin = LatLng(10.3000, 123.8950); // Fuente Circle area
  const directMid = LatLng(10.3100, 123.8950); // Osmena Blvd (active flood!)
  const detourMid = LatLng(10.3100, 123.9040); // Gen. Maxilom Ave (safe road)
  const destination = LatLng(10.3200, 123.8950); // Ayala Center area

  final activeFloodOnDirectRoad = HazardReportData(
    reportId: 'flood-osmena-001',
    location: directMid,
    category: 'Flood',
    title: 'Severe Road Flooding',
    description: 'Deep knee-high floodwater blocking Osmena Boulevard',
    securityLevel: 'High Severity',
    address: 'Osmena Boulevard, Cebu City',
    status: 'active',
    timestamp: DateTime(2026, 11, 6, 12, 0),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    HazardReportService.clearSessionReports();
    AlertService.clearSessionState();
  });

  group('SafeRouteService Geometry & Polyline6 Unit Tests', () {
    test('decodePolyline accurately decodes precision-6 Valhalla shapes including negative SE/SW road turns on Web & VM', () {
      const sample = <LatLng>[
        LatLng(10.295812, 123.878245), // Start in Mambaling
        LatLng(10.295104, 123.878912), // Walk southeast (negative dLat, positive dLng!)
        LatLng(10.294650, 123.877801), // Turn southwest (negative dLat, negative dLng!)
        LatLng(10.304920, 123.876410), // Turn northwest (positive dLat, negative dLng!)
        LatLng(10.322900, 123.884200), // Turn northeast to Guadalupe (positive dLat, positive dLng!)
      ];
      final encoded = encodeTestPolyline(sample, precision: 6);
      final decoded = SafeRouteService.decodePolyline(encoded, precision: 6);

      expect(decoded.length, sample.length);
      for (int i = 0; i < sample.length; i++) {
        expect(decoded[i].latitude, closeTo(sample[i].latitude, 1e-6));
        expect(decoded[i].longitude, closeTo(sample[i].longitude, 1e-6));
      }
    });

    test('SavedRouteRecord.fromJson discards corrupted out-of-range cached polylines', () {
      final record = SavedRouteRecord.fromJson(<String, dynamic>{
        'id': 'corrupted-web-cache-1',
        'title': 'Corrupted Route',
        'origin_label': 'Mambaling',
        'origin_lat': 10.2958,
        'origin_lng': 123.8782,
        'destination_label': 'Barangay Guadalupe',
        'destination_lat': 10.3229,
        'destination_lng': 123.8842,
        'route_polyline': <List<double>>[
          <double>[10.2958, 123.8782],
          <double>[4305.29, 123.8789],
        ],
      });
      expect(record.polyline, isEmpty);
    });

    test('pointToPolylineDistanceMeters distinguishes road-hit hazards from safe roads', () {
      const directPoly = <LatLng>[origin, directMid, destination];
      const safeDetourPoly = <LatLng>[origin, detourMid, destination];

      final hitDist = SafeRouteService.pointToPolylineDistanceMeters(
        activeFloodOnDirectRoad.location!,
        directPoly,
      );
      final detourDist = SafeRouteService.pointToPolylineDistanceMeters(
        activeFloodOnDirectRoad.location!,
        safeDetourPoly,
      );

      expect(hitDist, lessThan(2.0));
      expect(detourDist, greaterThan(450.0));
    });

    test('locateAlongPolyline snaps GPS coordinate, computes remaining distance & bearing', () {
      const poly = <LatLng>[
        LatLng(10.3000, 123.8950),
        LatLng(10.3100, 123.8950),
        LatLng(10.3200, 123.8950),
      ];

      // User slightly east (~22m) of the midpoint heading north
      final snap = SafeRouteService.locateAlongPolyline(
        const LatLng(10.3100, 123.8952),
        poly,
      );

      expect(snap.distanceFromRouteMeters, closeTo(21.9, 3.0));
      expect(snap.snappedPoint.latitude, closeTo(10.3100, 1e-4));
      expect(snap.snappedPoint.longitude, closeTo(123.8950, 1e-4));
      expect(snap.remainingDistanceMeters, closeTo(1112.0, 25.0));
      // Due north bearing (~0° / 360°)
      expect(
        snap.bearingDegrees < 5.0 || snap.bearingDegrees > 355.0,
        isTrue,
      );
    });

    test('buildHazardExclusionPolygon builds closed [lon, lat] GeoJSON ring', () {
      final ring = SafeRouteService.buildHazardExclusionPolygon(
        directMid,
        100.0,
        vertices: 8,
      );

      expect(ring.length, 9); // 8 vertices + closing vertex
      expect(ring.first[0], ring.last[0]);
      expect(ring.first[1], ring.last[1]);
      // Verify GeoJSON [lon, lat] ordering
      expect(ring.first[0], closeTo(123.8959, 0.002));
      expect(ring.first[1], closeTo(10.3100, 0.002));
    });
  });

  group('SafeRouteService Hazard-Prioritized Road Selection Tests', () {
    late List<Map<String, dynamic>> capturedValhallaPayloads;
    late SafeRouteService routingService;

    setUp(() {
      capturedValhallaPayloads = <Map<String, dynamic>>[];

      final mockHttp = MockClient((http.Request request) async {
        if (request.url.host.contains('valhalla1.openstreetmap.de')) {
          final rawJson = request.url.queryParameters['json'] ?? '{}';
          final payload = json.decode(rawJson) as Map<String, dynamic>;
          capturedValhallaPayloads.add(payload);

          final hasExclusion = payload['exclude_polygons'] is List &&
              (payload['exclude_polygons'] as List).isNotEmpty;

          if (hasExclusion) {
            // Return safe hazard-free detour via General Maxilom Ave
            return http.Response(
              buildValhallaTripResponse(
                shapePoints: const <LatLng>[
                  origin,
                  LatLng(10.3050, 123.9010),
                  detourMid,
                  LatLng(10.3160, 123.9010),
                  destination,
                ],
                lengthKm: 2.65,
                timeSeconds: 1180,
                maneuvers: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 1,
                    'instruction': 'Walk northeast on General Maxilom Avenue.',
                    'street_names': <String>['General Maxilom Avenue'],
                    'length': 0.95,
                    'time': 420,
                    'begin_shape_index': 0,
                    'end_shape_index': 2,
                  },
                  <String, dynamic>{
                    'type': 15,
                    'instruction': 'Turn left onto Gorordo Avenue.',
                    'street_names': <String>['Gorordo Avenue'],
                    'length': 0.90,
                    'time': 400,
                    'begin_shape_index': 2,
                    'end_shape_index': 3,
                  },
                  <String, dynamic>{
                    'type': 10,
                    'instruction': 'Turn right onto Cardinal Rosales Avenue.',
                    'street_names': <String>['Cardinal Rosales Avenue'],
                    'length': 0.80,
                    'time': 360,
                    'begin_shape_index': 3,
                    'end_shape_index': 4,
                  },
                  <String, dynamic>{
                    'type': 4,
                    'instruction': 'You have arrived at Ayala Center Cebu.',
                    'street_names': <String>['Cardinal Rosales Avenue'],
                    'length': 0.0,
                    'time': 0,
                    'begin_shape_index': 4,
                    'end_shape_index': 4,
                  },
                ],
              ),
              200,
            );
          }

          // Baseline direct route along Osmena Blvd (passes right through flood!)
          return http.Response(
            buildValhallaTripResponse(
              shapePoints: const <LatLng>[origin, directMid, destination],
              lengthKm: 2.22,
              timeSeconds: 980,
              maneuvers: <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 1,
                  'instruction': 'Walk north on Osmena Boulevard.',
                  'street_names': <String>['Osmena Boulevard'],
                  'length': 2.22,
                  'time': 980,
                  'begin_shape_index': 0,
                  'end_shape_index': 2,
                },
                <String, dynamic>{
                  'type': 4,
                  'instruction': 'You have arrived at your destination.',
                  'street_names': <String>['Osmena Boulevard'],
                  'length': 0.0,
                  'time': 0,
                  'begin_shape_index': 2,
                  'end_shape_index': 2,
                },
              ],
            ),
            200,
          );
        }

        // OSRM fallback returns empty/404 in this unit test so Valhalla candidates are isolated
        return http.Response('{"code":"NoRoute"}', 404);
      });

      routingService = SafeRouteService(
        httpClient: mockHttp,
        hazardReportService: FakeHazardReportService(
          initialReports: <HazardReportData>[activeFloodOnDirectRoad],
        ),
      );
    });

    test('avoidHazards: true sends exclude_polygons and prioritizes 0-hazard road', () async {
      final result = await routingService.findSafeRoute(
        origin: origin,
        originLabel: 'Fuente Osmena Circle',
        destination: destination,
        destinationLabel: 'Ayala Center Cebu',
        travelMode: RouteTravelMode.walking,
        avoidHazards: true,
      );

      // Verified Valhalla was called with graph-level exclude_polygons
      expect(
        capturedValhallaPayloads.any((p) => p.containsKey('exclude_polygons')),
        isTrue,
      );

      // Primary route MUST be the hazard-free General Maxilom Avenue road
      expect(result.primaryRoute.hazardsOnRoute, isEmpty);
      expect(result.primaryRoute.riskLevel, RouteRiskLevel.safe);
      expect(result.primaryRoute.usedHazardExclusion, isTrue);
      expect(result.primaryRoute.summary, contains('General Maxilom Avenue'));
      expect(result.hazardsAvoided, 1);

      // Turn-by-turn steps parsed accurately
      expect(result.primaryRoute.steps.length, 4);
      expect(result.primaryRoute.steps[0].maneuverType, ManeuverType.depart);
      expect(result.primaryRoute.steps[1].maneuverType, ManeuverType.left);
      expect(result.primaryRoute.steps[2].maneuverType, ManeuverType.right);
      expect(result.primaryRoute.steps[3].maneuverType, ManeuverType.arrive);

      // Direct hazardous route is kept in alternatives for transparent comparison
      expect(result.alternatives.length, greaterThanOrEqualTo(2));
      expect(
        result.alternatives.any((c) => c.hazardsOnRoute.isNotEmpty),
        isTrue,
      );
    });

    test('avoidHazards: false selects fastest direct road while flagging active hazards on route', () async {
      final result = await routingService.findSafeRoute(
        origin: origin,
        originLabel: 'Fuente Osmena Circle',
        destination: destination,
        destinationLabel: 'Ayala Center Cebu',
        travelMode: RouteTravelMode.walking,
        avoidHazards: false,
      );

      expect(result.primaryRoute.summary, contains('Osmena Boulevard'));
      expect(result.primaryRoute.hazardsOnRoute.length, 1);
      expect(
        result.primaryRoute.hazardsOnRoute.first.hazard.reportId,
        'flood-osmena-001',
      );
      expect(result.primaryRoute.riskLevel, RouteRiskLevel.high);
      expect(result.hazardsAvoided, 0);
    });

    test('offline fallback generates safe detour around active hazard when network is unreachable', () async {
      final offlineService = SafeRouteService(
        httpClient: MockClient((_) async => http.Response('Offline', 503)),
        hazardReportService: FakeHazardReportService(
          initialReports: <HazardReportData>[activeFloodOnDirectRoad],
        ),
      );

      final result = await offlineService.findSafeRoute(
        origin: origin,
        originLabel: 'Fuente Osmena Circle',
        destination: destination,
        destinationLabel: 'Ayala Center Cebu',
        avoidHazards: true,
      );

      expect(result.primaryRoute.provider, 'fallback');
      expect(result.primaryRoute.usedHazardExclusion, isTrue);
      expect(result.primaryRoute.hazardsOnRoute, isEmpty);
      expect(result.primaryRoute.steps.length, 3);
    });
  });

  group('SavedRouteRecord Persistence & Live Hazard Re-Evaluation', () {
    test('savePlannedRoute, fetchSavedRoutes, renameSavedRoute, deleteSavedRoute, and live hazard updates work end-to-end', () async {
      final hazardStore = <HazardReportData>[];
      final service = SafeRouteService(
        httpClient: MockClient((_) async {
          return http.Response(
            buildValhallaTripResponse(
              shapePoints: const <LatLng>[origin, directMid, destination],
              lengthKm: 2.22,
              timeSeconds: 960,
              maneuvers: <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 1,
                  'instruction': 'Walk north on Osmena Boulevard.',
                  'street_names': <String>['Osmena Boulevard'],
                  'length': 2.22,
                  'time': 960,
                  'begin_shape_index': 0,
                  'end_shape_index': 2,
                },
                <String, dynamic>{
                  'type': 4,
                  'instruction': 'Arrive at Ayala Center Cebu.',
                  'street_names': <String>['Osmena Boulevard'],
                  'length': 0.0,
                  'time': 0,
                  'begin_shape_index': 2,
                  'end_shape_index': 2,
                },
              ],
            ),
            200,
          );
        }),
        hazardReportService: FakeHazardReportService(initialReports: hazardStore),
      );

      final planned = await service.findSafeRoute(
        origin: origin,
        originLabel: 'Fuente Osmena Circle',
        destination: destination,
        destinationLabel: 'Ayala Center Cebu',
      );
      expect(planned.primaryRoute.hazardsOnRoute, isEmpty);

      final saved = await service.savePlannedRoute(planned: planned);
      expect(saved.title, 'Fuente Osmena Circle to Ayala Center Cebu');
      expect(saved.hazardCount, 0);
      expect(saved.riskLevel, RouteRiskLevel.safe);

      // Now simulate a newly reported High-severity flood directly on that saved route
      final reevaluated = await service.fetchSavedRoutes(
        activeHazards: <HazardReportData>[activeFloodOnDirectRoad],
      );
      expect(reevaluated.length, 1);
      expect(reevaluated.first.hazardCount, 1);
      expect(reevaluated.first.riskLevel, RouteRiskLevel.high);

      // Rename saved route
      await service.renameSavedRoute(saved.id, 'Morning Commute');
      final afterRename = await service.fetchSavedRoutes(activeHazards: const []);
      expect(afterRename.first.title, 'Morning Commute');
      expect(afterRename.first.hazardCount, 0);

      // Delete saved route
      await service.deleteSavedRoute(saved.id);
      final afterDelete = await service.fetchSavedRoutes(activeHazards: const []);
      expect(afterDelete, isEmpty);
    });
  });

  group('RouteScreen, MapScreen Turn-by-Turn HUD, & UserHomeScreen Widget Tests', () {
    SafeRouteService buildMockSafeRouteService({
      List<HazardReportData> initialHazards = const <HazardReportData>[],
    }) {
      return SafeRouteService(
        httpClient: MockClient((http.Request req) async {
          if (req.url.host.contains('valhalla1.openstreetmap.de')) {
            return http.Response(
              buildValhallaTripResponse(
                shapePoints: const <LatLng>[
                  origin,
                  LatLng(10.3060, 123.9020),
                  detourMid,
                  destination,
                ],
                lengthKm: 2.50,
                timeSeconds: 1080,
                maneuvers: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 1,
                    'instruction': 'Head north on General Maxilom Avenue',
                    'street_names': <String>['General Maxilom Avenue'],
                    'length': 1.10,
                    'time': 480,
                    'begin_shape_index': 0,
                    'end_shape_index': 2,
                  },
                  <String, dynamic>{
                    'type': 15,
                    'instruction': 'Turn left onto Gorordo Avenue',
                    'street_names': <String>['Gorordo Avenue'],
                    'length': 0.90,
                    'time': 390,
                    'begin_shape_index': 2,
                    'end_shape_index': 3,
                  },
                  <String, dynamic>{
                    'type': 4,
                    'instruction': 'Arrive at Ayala Center Cebu',
                    'street_names': <String>['Cardinal Rosales Avenue'],
                    'length': 0.0,
                    'time': 0,
                    'begin_shape_index': 3,
                    'end_shape_index': 3,
                  },
                ],
              ),
              200,
            );
          }
          return http.Response('{"code":"NoRoute"}', 404);
        }),
        hazardReportService: FakeHazardReportService(
          initialReports: initialHazards,
        ),
      );
    }

    testWidgets('RouteScreen computes safe route, cycles travel mode, saves route, and launches Turn-by-Turn', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeHazards = FakeHazardReportService(
        initialReports: <HazardReportData>[activeFloodOnDirectRoad],
      );
      final safeRouteService = buildMockSafeRouteService(
        initialHazards: <HazardReportData>[activeFloodOnDirectRoad],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RouteScreen(
            safeRouteService: safeRouteService,
            hazardReportService: fakeHazards,
            savedLocationService: SavedLocationService(),
            initialLocation: origin,
            skipLocationLookup: true,
            skipAutoSuggestion: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MY ROUTES'), findsOneWidget);
      expect(find.text('Find Route'), findsOneWidget);
      expect(find.text('Walking'), findsOneWidget);

      // Tap preset quick destination chip "Barangay Guadalupe"
      expect(find.text('Barangay Guadalupe'), findsOneWidget);
      await tester.tap(find.text('Barangay Guadalupe').first);
      await tester.pumpAndSettle();

      // Suggested Route card with turn-by-turn preview and CTAs appears
      expect(find.text('Suggested Route'), findsOneWidget);
      expect(find.text('Save Route'), findsOneWidget);
      expect(find.text('Start Turn-by-Turn'), findsOneWidget);
      expect(find.textContaining('General Maxilom Avenue'), findsWidgets);

      // Verify Suggested Route mini-map applies the Natural Modern desaturated tone filter
      final miniMapTileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(miniMapTileLayer.tileBuilder, isNotNull);
      final dummyContext = tester.element(find.byType(TileLayer));
      final styledTile = miniMapTileLayer.tileBuilder!(
        dummyContext,
        const SizedBox.shrink(),
        TileImage(
          coordinates: const TileCoordinates(0, 0, 0),
          imageProvider: const AssetImage('assets/images/placeholder.png'),
          tileDisplay: const TileDisplay.fadeIn(),
          cancelLoading: Completer<void>(),
          errorImage: null,
          vsync: const TestVSync(),
          onLoadError: (_, __, ___) {},
          onLoadComplete: (_) {},
        ),
      );
      expect(styledTile, isA<ColorFiltered>());
      expect(
        (styledTile as ColorFiltered).colorFilter,
        equals(RouteScreen.naturalMapColorFilter),
      );

      // Cycle travel mode Walking -> Cycling
      await tester.tap(find.text('Walking').first);
      await tester.pumpAndSettle();
      expect(find.text('Cycling'), findsWidgets);

      // Save the route and verify it persists into Saved Routes
      await tester.ensureVisible(find.text('Save Route'));
      await tester.tap(find.text('Save Route'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Saved Routes'), findsOneWidget);
    });

    testWidgets('MapScreen RoutePreviewOverlay & TurnByTurnNavigationHud execute step progression, steps sheet, simulation, and exit', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeHazards = FakeHazardReportService(
        initialReports: <HazardReportData>[activeFloodOnDirectRoad],
      );
      final safeRouteService = buildMockSafeRouteService(
        initialHazards: <HazardReportData>[activeFloodOnDirectRoad],
      );

      final initialPlanned = await safeRouteService.findSafeRoute(
        origin: origin,
        originLabel: 'Fuente Osmena Circle',
        destination: destination,
        destinationLabel: 'Ayala Center Cebu',
        avoidHazards: true,
      );

      final transparentPng = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      );
      final mockTileProvider = NetworkTileProvider(
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            transparentPng,
            200,
            headers: const <String, String>{'content-type': 'image/png'},
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            initialLocation: origin,
            hazardReportService: fakeHazards,
            safeRouteService: safeRouteService,
            initialRoute: initialPlanned,
            autoStartNavigation: false,
            tileProvider: mockTileProvider,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. RoutePreviewOverlay is active initially
      expect(find.byType(RoutePreviewOverlay), findsOneWidget);
      expect(find.text('Start Turn-by-Turn'), findsOneWidget);

      // 2. Start Turn-by-Turn Navigation
      await tester.tap(find.text('Start Turn-by-Turn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TurnByTurnNavigationHud), findsOneWidget);
      expect(find.text('Head north on General Maxilom Avenue'), findsOneWidget);
      expect(find.textContaining('Step 1 of 3'), findsOneWidget);
      expect(find.text('Simulate'), findsOneWidget);

      // 3. Advance to Next Step -> Step 2 of 3
      await tester.tap(find.byTooltip('Next step'));
      await tester.pump();
      expect(find.text('Turn left onto Gorordo Avenue'), findsOneWidget);
      expect(find.textContaining('Step 2 of 3'), findsOneWidget);

      // 4. Go back to Previous Step -> Step 1 of 3
      await tester.tap(find.byTooltip('Previous step'));
      await tester.pump();
      expect(find.text('Head north on General Maxilom Avenue'), findsOneWidget);
      expect(find.textContaining('Step 1 of 3'), findsOneWidget);

      // 5. Open All Steps bottom sheet & close it
      await tester.tap(find.byTooltip('All steps'));
      await tester.pumpAndSettle();
      expect(find.text('Turn-by-Turn Directions'), findsOneWidget);
      expect(find.text('Arrive at Ayala Center Cebu'), findsWidgets);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // 6. Toggle interactive Demo Walk simulation on and off cleanly
      await tester.tap(find.text('Simulate'));
      await tester.pump(const Duration(milliseconds: 950));
      expect(find.text('Pause Demo'), findsOneWidget);
      await tester.tap(find.text('Pause Demo'));
      await tester.pump();
      expect(find.text('Simulate'), findsOneWidget);

      // 7. End Turn-by-Turn Navigation returns cleanly to RoutePreviewOverlay
      await tester.tap(find.text('End'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(RoutePreviewOverlay), findsOneWidget);
    });

    testWidgets('UserHomeScreen "Find a route" button navigates cleanly to RouteScreen', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: UserHomeScreen(
            hazardReportService: FakeHazardReportService(),
            alertService: FakeAlertService(),
            skipLocationLookup: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Find a route'), findsOneWidget);
      await tester.tap(find.text('Find a route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RouteScreen), findsOneWidget);
      expect(find.text('Find Route'), findsOneWidget);
    });
  });
}
