import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/map_screen.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';
import 'package:dreamteam_sd3/services/safe_route_service.dart';
import 'package:dreamteam_sd3/widgets/turn_by_turn_navigation_overlay.dart';

class _FakeTileImage extends Fake implements TileImage {}

class _FakeHazardReportService extends HazardReportService {
  @override
  Future<List<HazardReportData>> fetchReports({
    int limit = 100,
    bool activeOnly = false,
  }) async {
    return <HazardReportData>[];
  }
}

PlannedRouteResult _createSamplePlannedRoute({int trafficDelaySeconds = 0}) {
  final poly = <LatLng>[
    const LatLng(10.2982, 123.8615),
    const LatLng(10.3050, 123.8700),
    const LatLng(10.3157, 123.8854),
  ];
  final candidate = RouteCandidate(
    id: 'test_cand_1',
    provider: 'tomtom-live-traffic',
    summary: 'Via N. Bacalso Ave',
    polyline: poly,
    steps: <RouteStep>[
      const RouteStep(
        index: 0,
        instruction: 'Head north on N. Bacalso Ave',
        streetName: 'N. Bacalso Ave',
        distanceMeters: 2500,
        durationSeconds: 300,
        maneuverType: ManeuverType.depart,
        location: LatLng(10.2982, 123.8615),
        startPolylineIndex: 0,
        endPolylineIndex: 1,
      ),
      const RouteStep(
        index: 1,
        instruction: 'Arrive at Barangay Capitol Site',
        streetName: 'Capitol Site',
        distanceMeters: 2500,
        durationSeconds: 300,
        maneuverType: ManeuverType.arrive,
        location: LatLng(10.3157, 123.8854),
        startPolylineIndex: 1,
        endPolylineIndex: 2,
      ),
    ],
    distanceMeters: 5000,
    durationSeconds: 600 + trafficDelaySeconds,
    trafficDelaySeconds: trafficDelaySeconds,
  );

  return PlannedRouteResult(
    origin: const LatLng(10.2982, 123.8615),
    originLabel: 'Your current location',
    destination: const LatLng(10.3157, 123.8854),
    destinationLabel: 'Barangay Capitol Site',
    travelMode: RouteTravelMode.driving,
    avoidHazards: true,
    primaryRoute: candidate,
    alternatives: <RouteCandidate>[candidate],
    corridorHazards: const <HazardReportData>[],
    hazardsAvoided: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TomTom Real-Time Traffic Layer Feature Tests', () {
    testWidgets(
      'Traffic toggle button exists and toggling updates map traffic layer and legend chip',
      (tester) async {
        final fakeService = _FakeHazardReportService();

        await tester.pumpWidget(
          MaterialApp(
            home: MapScreen(
              initialLocation: const LatLng(10.3157, 123.8854),
              hazardReportService: fakeService,
              tomtomApiKey: 'TEST_TOMTOM_KEY_ABC123',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Initial State: traffic is disabled
        final trafficButtonFinder = find.byKey(const Key('toggle_traffic_layer_button'));
        expect(trafficButtonFinder, findsOneWidget);
        expect(find.byIcon(Icons.traffic), findsOneWidget);

        // Traffic TileLayer and legend chip should NOT be present initially
        expect(find.byKey(const Key('tomtom_traffic_flow_layer')), findsNothing);
        expect(find.byKey(const Key('traffic_legend_chip')), findsNothing);

        // 2. Toggle Traffic ON
        await tester.tap(trafficButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // TomTom traffic layer is now present directly in map
        final trafficLayerFinder = find.byKey(const Key('tomtom_traffic_flow_layer'));
        expect(trafficLayerFinder, findsOneWidget);

        final trafficTileLayer = tester.widget<TileLayer>(trafficLayerFinder);
        expect(
          trafficTileLayer.urlTemplate,
          contains('api.tomtom.com/traffic/map/4/tile/flow/relative0/{z}/{x}/{y}.png?key=TEST_TOMTOM_KEY_ABC123&tileSize=256'),
        );

        // Sleek floating legend chip is visible with Normal, Slow, Heavy status
        expect(find.byKey(const Key('traffic_legend_chip')), findsOneWidget);
        expect(find.text('Normal'), findsOneWidget);
        expect(find.text('Slow'), findsOneWidget);
        expect(find.text('Heavy'), findsOneWidget);

        // Feedback snackbar is shown
        expect(find.text('Traffic layer enabled (TomTom)'), findsOneWidget);

        // Attribution displays TomTom provider attribution
        expect(
          find.text('© OpenStreetMap contributors | © TomTom Traffic'),
          findsOneWidget,
        );

        // 3. Toggle Traffic OFF
        await tester.tap(trafficButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Traffic layer and legend chip are removed
        expect(find.byKey(const Key('tomtom_traffic_flow_layer')), findsNothing);
        expect(find.byKey(const Key('traffic_legend_chip')), findsNothing);
        expect(find.text('Traffic layer disabled'), findsOneWidget);
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      },
    );

    testWidgets(
      'MapScreen with initialShowTraffic true mounts TomTom layer on startup',
      (tester) async {
        final fakeService = _FakeHazardReportService();

        await tester.pumpWidget(
          MaterialApp(
            home: MapScreen(
              initialLocation: const LatLng(10.3157, 123.8854),
              hazardReportService: fakeService,
              initialShowTraffic: true,
              tomtomApiKey: 'INITIAL_CUSTOM_KEY',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // TomTom layer and legend chip exist on startup
        expect(find.byKey(const Key('tomtom_traffic_flow_layer')), findsOneWidget);
        expect(find.byKey(const Key('traffic_legend_chip')), findsOneWidget);

        final trafficTileLayer = tester.widget<TileLayer>(
          find.byKey(const Key('tomtom_traffic_flow_layer')),
        );
        expect(
          trafficTileLayer.urlTemplate,
          contains('key=INITIAL_CUSTOM_KEY'),
        );
      },
    );

    testWidgets(
      'Route map displays traffic toggle button and toggling enables traffic tiles and legend chip on route view',
      (tester) async {
        final fakeService = _FakeHazardReportService();
        final sampleRoute = _createSamplePlannedRoute(trafficDelaySeconds: 180);

        await tester.pumpWidget(
          MaterialApp(
            home: MapScreen(
              initialLocation: const LatLng(10.2982, 123.8615),
              hazardReportService: fakeService,
              initialRoute: sampleRoute,
              tomtomApiKey: 'ROUTE_TOMTOM_KEY_999',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // RoutePreviewOverlay is rendered
        expect(find.byType(RoutePreviewOverlay), findsOneWidget);

        // Both the chip in RoutePreviewOverlay and the floating FAB on route map exist
        final chipToggle = find.byKey(const Key('route_preview_traffic_toggle_button'));
        final fabToggle = find.byKey(const Key('toggle_traffic_layer_button'));
        expect(chipToggle, findsOneWidget);
        expect(fabToggle, findsOneWidget);

        // Initially traffic layer is not mounted
        expect(find.byKey(const Key('tomtom_traffic_flow_layer')), findsNothing);

        // Tap traffic chip on Route map
        await tester.tap(chipToggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Traffic layer and legend chip are now visible on route map!
        expect(find.byKey(const Key('tomtom_traffic_flow_layer')), findsOneWidget);
        expect(find.byKey(const Key('traffic_legend_chip')), findsOneWidget);

        // Route delay label is displayed
        expect(find.text('+3 min delay'), findsOneWidget);

        // Tap floating FAB to toggle off
        await tester.tap(fabToggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('tomtom_traffic_flow_layer')), findsNothing);
      },
    );

    test('RouteCandidate incorporates traffic delay in safetyWeightedCost and labels', () {
      const candNoTraffic = RouteCandidate(
        id: 'no_traffic',
        provider: 'tomtom',
        summary: 'Via Clear Highway',
        polyline: [LatLng(10.0, 123.0), LatLng(10.1, 123.1)],
        steps: [],
        distanceMeters: 5000,
        durationSeconds: 600,
        trafficDelaySeconds: 0,
      );

      const candWithTraffic = RouteCandidate(
        id: 'with_traffic',
        provider: 'tomtom',
        summary: 'Via Congested Ave',
        polyline: [LatLng(10.0, 123.0), LatLng(10.1, 123.1)],
        steps: [],
        distanceMeters: 4800,
        durationSeconds: 960,
        trafficDelaySeconds: 360, // 6 mins traffic delay
      );

      // Cost calculation checks
      expect(candNoTraffic.safetyWeightedCost, 5000.0);
      // 4800 + (360 * 1.5) = 4800 + 540 = 5340.0
      expect(candWithTraffic.safetyWeightedCost, 5340.0);

      expect(candNoTraffic.trafficDelayLabel, '');
      expect(candWithTraffic.trafficDelayLabel, '+6 min delay');
      expect(candWithTraffic.hasTrafficDelay, isTrue);

      // Ranking: Route without traffic delay is preferred because of lower safetyWeightedCost
      final ranked = SafeRouteService.rankCandidates(
        [candWithTraffic, candNoTraffic],
        avoidHazards: true,
      );
      expect(ranked.first.id, 'no_traffic');
    });

    test('SafeRouteService parses TomTom routing API response with traffic delay', () async {
      final tomtomSampleResponse = jsonEncode({
        'routes': [
          {
            'summary': {
              'lengthInMeters': 4250,
              'travelTimeInSeconds': 720,
              'trafficDelayInSeconds': 240,
            },
            'legs': [
              {
                'points': [
                  {'latitude': 10.2982, 'longitude': 123.8615},
                  {'latitude': 10.3050, 'longitude': 123.8700},
                  {'latitude': 10.3157, 'longitude': 123.8854},
                ],
              }
            ],
            'guidance': {
              'instructions': [
                {
                  'routeOffsetInMeters': 0,
                  'travelTimeInSeconds': 200,
                  'point': {'latitude': 10.2982, 'longitude': 123.8615},
                  'pointIndex': 0,
                  'maneuver': 'DEPART',
                  'message': 'Depart north',
                  'street': 'N. Bacalso Ave',
                },
                {
                  'routeOffsetInMeters': 2000,
                  'travelTimeInSeconds': 520,
                  'point': {'latitude': 10.3157, 'longitude': 123.8854},
                  'pointIndex': 2,
                  'maneuver': 'ARRIVE',
                  'message': 'Arrive at Capitol Site',
                  'street': 'Capitol Site',
                },
              ],
            },
          }
        ]
      });

      final mockClient = MockClient((request) async {
        if (request.url.host.contains('tomtom.com')) {
          return http.Response(tomtomSampleResponse, 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 500);
      });

      final service = SafeRouteService(
        httpClient: mockClient,
        tomtomApiKey: 'VALID_TOMTOM_KEY',
      );

      final result = await service.findSafeRoute(
        origin: const LatLng(10.2982, 123.8615),
        originLabel: 'Origin',
        destination: const LatLng(10.3157, 123.8854),
        destinationLabel: 'Destination',
        travelMode: RouteTravelMode.driving,
      );

      expect(result.primaryRoute.provider, 'tomtom-live-traffic');
      expect(result.primaryRoute.trafficDelaySeconds, 240);
      expect(result.primaryRoute.trafficDelayLabel, '+4 min delay');
      expect(result.primaryRoute.summary, contains('Via N. Bacalso Ave'));
      expect(result.primaryRoute.steps.length, 2);
    });

    testWidgets(
      'Missing or placeholder TomTom API key does not enable traffic and shows notice',
      (tester) async {
        final fakeService = _FakeHazardReportService();

        await tester.pumpWidget(
          MaterialApp(
            home: MapScreen(
              initialLocation: const LatLng(10.3157, 123.8854),
              hazardReportService: fakeService,
              tomtomApiKey: 'YOUR_TOMTOM_API_KEY_HERE',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final trafficButtonFinder = find.byKey(const Key('toggle_traffic_layer_button'));
        await tester.tap(trafficButtonFinder);
        await tester.pump();

        expect(
          find.text('TomTom API key not configured. Real-time traffic unavailable.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('tomtom_traffic_flow_layer')), findsNothing);
      },
    );

    testWidgets(
      'Traffic tile load error surfaces error snackbar and changes legend chip',
      (tester) async {
        final fakeService = _FakeHazardReportService();

        await tester.pumpWidget(
          MaterialApp(
            home: MapScreen(
              initialLocation: const LatLng(10.3157, 123.8854),
              hazardReportService: fakeService,
              initialShowTraffic: true,
              tomtomApiKey: 'VALID_KEY',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final trafficTileLayer = tester.widget<TileLayer>(
          find.byKey(const Key('tomtom_traffic_flow_layer')),
        );
        trafficTileLayer.errorTileCallback?.call(
          _FakeTileImage(),
          Exception('401 Unauthorized'),
          StackTrace.empty,
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Failed to load traffic tiles. Check network connection or API quota.'),
          findsOneWidget,
        );
        expect(find.text('Traffic tiles unavailable'), findsOneWidget);
      },
    );

    testWidgets(
      'Route polylines stay blue and avoid TomTom green/yellow/red traffic colors even with hazards on route',
      (tester) async {
        final fakeService = _FakeHazardReportService();
        final sampleHazard = HazardReportData(
          reportId: 'haz-route-1',
          location: const LatLng(10.3050, 123.8700),
          category: 'Flooding',
          title: 'Street Flooding',
          description: 'Flooded lane',
          securityLevel: 'High',
          address: 'N. Bacalso Ave, Cebu City',
          status: 'active',
          timestamp: DateTime(2026, 11, 13, 12, 0),
        );
        final hazardExposure = RouteHazardExposure(
          hazard: sampleHazard,
          distanceFromRouteMeters: 10.0,
          avoidanceRadiusMeters: 60.0,
          severityWeight: 120.0,
        );
        const poly = <LatLng>[
          LatLng(10.2982, 123.8615),
          LatLng(10.3050, 123.8700),
          LatLng(10.3157, 123.8854),
        ];
        final hazardPrimary = RouteCandidate(
          id: 'primary_with_hazard',
          provider: 'tomtom-live-traffic',
          summary: 'Via N. Bacalso Ave',
          polyline: poly,
          steps: const <RouteStep>[
            RouteStep(
              index: 0,
              instruction: 'Head north on N. Bacalso Ave',
              streetName: 'N. Bacalso Ave',
              distanceMeters: 2500,
              durationSeconds: 300,
              maneuverType: ManeuverType.depart,
              location: LatLng(10.2982, 123.8615),
              startPolylineIndex: 0,
              endPolylineIndex: 1,
            ),
          ],
          distanceMeters: 5000,
          durationSeconds: 600,
          hazardsOnRoute: <RouteHazardExposure>[hazardExposure],
        );
        final hazardAlt = RouteCandidate(
          id: 'alt_with_hazard',
          provider: 'tomtom-live-traffic',
          summary: 'Via Osmena Blvd',
          polyline: const <LatLng>[
            LatLng(10.2982, 123.8615),
            LatLng(10.3090, 123.8750),
            LatLng(10.3157, 123.8854),
          ],
          steps: const <RouteStep>[],
          distanceMeters: 5400,
          durationSeconds: 660,
          hazardsOnRoute: <RouteHazardExposure>[hazardExposure],
        );
        const cleanAlt = RouteCandidate(
          id: 'alt_clean',
          provider: 'tomtom-live-traffic',
          summary: 'Via SRP',
          polyline: <LatLng>[
            LatLng(10.2982, 123.8615),
            LatLng(10.3020, 123.8820),
            LatLng(10.3157, 123.8854),
          ],
          steps: <RouteStep>[],
          distanceMeters: 5600,
          durationSeconds: 690,
        );

        final plannedWithHazards = PlannedRouteResult(
          origin: const LatLng(10.2982, 123.8615),
          originLabel: 'Origin',
          destination: const LatLng(10.3157, 123.8854),
          destinationLabel: 'Destination',
          travelMode: RouteTravelMode.driving,
          avoidHazards: true,
          primaryRoute: hazardPrimary,
          alternatives: <RouteCandidate>[hazardPrimary, hazardAlt, cleanAlt],
          corridorHazards: <HazardReportData>[sampleHazard],
          hazardsAvoided: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MapScreen(
              initialLocation: const LatLng(10.2982, 123.8615),
              hazardReportService: fakeService,
              initialRoute: plannedWithHazards,
              initialShowTraffic: true,
              tomtomApiKey: 'VALID_KEY',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final polylineLayer = tester.widget<PolylineLayer>(
          find.byType(PolylineLayer),
        );
        final colors = polylineLayer.polylines.map((p) => p.color).toList();

        // Primary route uses blue inner stroke + white casing (never yellow/amber/red/green at any opacity)
        expect(colors, contains(const Color(0xFF2563EB)));
        expect(colors, contains(Colors.white));
        expect(
          colors.any((c) {
            final rgb = c.toARGB32() & 0x00FFFFFF;
            return rgb == 0xD97706 ||
                rgb == 0xF59E0B ||
                rgb == 0x22C55E ||
                rgb == 0xEF4444;
          }),
          isFalse,
        );
      },
    );
  });
}
