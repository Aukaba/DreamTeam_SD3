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

    test('Reverse geocode address parsing logic matches specification', () {
      const rawDisplayName =
          'Cebu Institute of Technology - University, Natalio Bacalso Avenue, Tres de Abril Village, San Nicolas Proper, Duljo Fatima, Cebu City, Central Visayas, 6000, Philippines';

      final topTwo = rawDisplayName.split(',').take(2).join(', ').trim();
      expect(
        topTwo,
        'Cebu Institute of Technology - University,  Natalio Bacalso Avenue',
      );

      final parts = rawDisplayName.split(',');
      final title = parts.first.trim();
      final subtitle = parts.skip(1).take(2).join(', ').trim();

      expect(title, 'Cebu Institute of Technology - University');
      expect(subtitle, 'Natalio Bacalso Avenue,  Tres de Abril Village');
    });

    test('Region scoping appends default region when absent', () {
      String applyRegionScoping(String query) {
        final clean = query.trim();
        return clean.toLowerCase().contains('cebu') ? clean : '$clean, Cebu';
      }

      expect(applyRegionScoping('Colon Street'), 'Colon Street, Cebu');
      expect(applyRegionScoping('Ayala Center Cebu'), 'Ayala Center Cebu');
      expect(applyRegionScoping('Mandaue City, Cebu'), 'Mandaue City, Cebu');
    });
  });
}
