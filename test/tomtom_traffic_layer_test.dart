import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/map_screen.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';

class _FakeHazardReportService extends HazardReportService {
  @override
  Future<List<HazardReportData>> fetchReports({
    int limit = 100,
    bool activeOnly = false,
  }) async {
    return <HazardReportData>[];
  }
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

        // 3. Toggle Traffic OFF
        await tester.tap(trafficButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Traffic layer and legend chip are removed
        expect(find.byKey(const Key('tomtom_traffic_flow_layer')), findsNothing);
        expect(find.byKey(const Key('traffic_legend_chip')), findsNothing);
        expect(find.text('Traffic layer disabled'), findsOneWidget);
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
  });
}
