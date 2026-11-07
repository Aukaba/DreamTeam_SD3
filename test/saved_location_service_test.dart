import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/services/saved_location_service.dart';
import 'package:dreamteam_sd3/user_screens/saved_locations_screen.dart';

class FakeEmptySavedLocationService extends SavedLocationService {
  FakeEmptySavedLocationService() : super(client: null);

  @override
  Future<List<SavedLocation>> getSavedLocations() async => [];
}

class FakePopulatedSavedLocationService extends SavedLocationService {
  FakePopulatedSavedLocationService() : super(client: null);

  @override
  Future<List<SavedLocation>> getSavedLocations() async {
    return [
      SavedLocation(
        id: 'loc_1',
        userId: 'user_123',
        title: 'Home',
        address: 'Guadalupe, Cebu City',
        location: const LatLng(10.3200, 123.8800),
        category: 'home',
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      ),
      SavedLocation(
        id: 'loc_2',
        userId: 'user_123',
        title: 'CIT-University',
        address: 'N. Bacalso Ave, Cebu City',
        location: const LatLng(10.2944, 123.8811),
        category: 'school',
        createdAt: DateTime(2026, 11, 2),
        updatedAt: DateTime(2026, 11, 2),
      ),
    ];
  }
}

void main() {
  group('SavedLocation Model Tests', () {
    test('fromJson parses full database record correctly', () {
      final json = {
        'id': 'abc-123',
        'user_id': 'user-456',
        'title': 'Ayala Center Cebu',
        'address': 'Cardinal Rosales Ave, Cebu City',
        'latitude': 10.3175,
        'longitude': 123.9056,
        'category': 'shopping',
        'created_at': '2026-11-01T10:00:00Z',
        'updated_at': '2026-11-01T10:00:00Z',
      };

      final location = SavedLocation.fromJson(json);

      expect(location.id, 'abc-123');
      expect(location.userId, 'user-456');
      expect(location.title, 'Ayala Center Cebu');
      expect(location.address, 'Cardinal Rosales Ave, Cebu City');
      expect(location.location.latitude, 10.3175);
      expect(location.location.longitude, 123.9056);
      expect(location.category, 'shopping');
      expect(location.icon, Icons.shopping_bag_rounded);
      expect(location.color, const Color(0xFFF59E0B));
    });

    test('toJson serializes location correctly', () {
      final location = SavedLocation(
        id: 'uuid-1',
        userId: 'user-1',
        title: 'My Work',
        address: 'IT Park, Lahug',
        location: const LatLng(10.3298, 123.9060),
        category: 'work',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = location.toJson();
      expect(map['title'], 'My Work');
      expect(map['category'], 'work');
      expect(map['latitude'], 10.3298);
      expect(map['longitude'], 123.9060);
    });

    test('Category icons and colors return expected defaults', () {
      final homeLoc = SavedLocation(
        id: '1',
        userId: 'u',
        title: 'H',
        address: 'A',
        location: const LatLng(0, 0),
        category: 'home',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(homeLoc.icon, Icons.home_rounded);
      expect(homeLoc.color, const Color(0xFF10B981));

      final schoolLoc = SavedLocation(
        id: '2',
        userId: 'u',
        title: 'S',
        address: 'A',
        location: const LatLng(0, 0),
        category: 'school',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(schoolLoc.icon, Icons.school_rounded);
      expect(schoolLoc.color, const Color(0xFF8B5CF6));
    });
  });

  group('SavedLocationsScreen Widget Tests', () {
    testWidgets('Renders empty state when user has no saved locations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SavedLocationsScreen(
            service: FakeEmptySavedLocationService(),
          ),
        ),
      );

      // Wait for async load
      await tester.pumpAndSettle();

      expect(find.text('Saved Locations'), findsOneWidget);
      expect(find.text('No saved locations yet'), findsOneWidget);
      expect(find.text('Add Location'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets('Renders saved locations list with titles and addresses',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SavedLocationsScreen(
            service: FakePopulatedSavedLocationService(),
          ),
        ),
      );

      // Wait for async load
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Guadalupe, Cebu City'), findsOneWidget);
      expect(find.text('CIT-University'), findsOneWidget);
      expect(find.text('N. Bacalso Ave, Cebu City'), findsOneWidget);

      // Verify category icons
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);

      // Verify action buttons
      expect(find.byIcon(Icons.near_me_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));
    });
  });
}

