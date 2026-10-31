import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/widgets/interactive_location_picker.dart';

void main() {
  group('InteractiveLocationPicker Widget Tests', () {
    testWidgets('Renders search text field with proper hint and icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveLocationPicker(
              initialLocation: LatLng(10.3157, 123.8854),
              initialAddress: 'Cebu City Hall',
            ),
          ),
        ),
      );

      // Verify TextField is rendered with placeholder
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search location or street'), findsOneWidget); // placeholder
      expect(find.text('Cebu City Hall'), findsOneWidget); // initial address in field
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    test('Production formatDisplayName parses raw address into top 2 segments', () {
      const rawDisplayName =
          'Cebu Institute of Technology - University, Natalio Bacalso Avenue, Tres de Abril Village, San Nicolas Proper, Duljo Fatima, Cebu City, Central Visayas, 6000, Philippines';

      final formatted = InteractiveLocationPicker.formatDisplayName(rawDisplayName);
      expect(
        formatted,
        'Cebu Institute of Technology - University, Natalio Bacalso Avenue',
      );
    });

    test('Production applyRegionScoping correctly appends default region when absent', () {
      expect(
        InteractiveLocationPicker.applyRegionScoping('Colon Street'),
        'Colon Street, Cebu',
      );
      expect(
        InteractiveLocationPicker.applyRegionScoping('Ayala Center Cebu'),
        'Ayala Center Cebu',
      );
      expect(
        InteractiveLocationPicker.applyRegionScoping('Mandaue City, Cebu'),
        'Mandaue City, Cebu',
      );
    });

    test('Production parseSuggestion extracts title, subtitle and full address', () {
      final option = {
        'name': 'Fuente Osmeña Circle',
        'display_name': 'Fuente Osmeña Circle, B. Rodriguez Street, Capitol Site, Cebu City, Cebu, 6000, Philippines',
      };

      final parsed = InteractiveLocationPicker.parseSuggestion(option);
      expect(parsed.title, 'Fuente Osmeña Circle');
      expect(parsed.subtitle, 'B. Rodriguez Street, Capitol Site');
      expect(parsed.fullAddress, option['display_name']);
    });

    testWidgets('Confirm button is enabled when address is resolved',
        (WidgetTester tester) async {
      LatLng? confirmedLoc;
      String? confirmedAddr;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveLocationPicker(
              initialLocation: const LatLng(10.3157, 123.8854),
              initialAddress: 'Cebu City Hall, D. Jakosalem St',
              onLocationConfirmed: (loc, addr) {
                confirmedLoc = loc;
                confirmedAddr = addr;
              },
            ),
          ),
        ),
      );

      final confirmButtonFinder = find.widgetWithText(ElevatedButton, 'Confirm Location');
      expect(confirmButtonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(confirmButtonFinder);
      expect(button.onPressed, isNotNull);

      await tester.tap(confirmButtonFinder);
      await tester.pump();

      expect(confirmedLoc, const LatLng(10.3157, 123.8854));
      expect(confirmedAddr, 'Cebu City Hall, D. Jakosalem St');
    });
  });
}
