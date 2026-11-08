import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/services/alert_service.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';
import 'package:dreamteam_sd3/services/profile_service.dart';
import 'package:dreamteam_sd3/services/safe_route_service.dart';
import 'package:dreamteam_sd3/services/saved_location_service.dart';
import 'package:dreamteam_sd3/user_screens/alerts_screen.dart';
import 'package:dreamteam_sd3/user_screens/route_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_home_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_profile_screen.dart';
import 'package:dreamteam_sd3/widgets/custom_wavy_header.dart';

class _MockProfileService extends ProfileService {
  final UserProfile _profile;

  _MockProfileService({UserProfile? profile})
      : _profile = profile ??
            const UserProfile(
              id: 'test-user',
              fullName: 'Ma. Angelica May',
              email: 'gelic@example.com',
              username: 'gelic',
              address: 'Cebu City, Philippines',
            );

  @override
  Future<UserProfile?> getProfile() async => _profile;
}

class _MockHazardReportService extends HazardReportService {
  @override
  Future<List<HazardReportData>> fetchReports({
    int limit = 100,
    bool activeOnly = true,
  }) async =>
      <HazardReportData>[];
}

class _MockAlertService extends AlertService {
  @override
  Future<List<AlertItem>> fetchAlerts({int limit = 50}) async => <AlertItem>[];
}

class _MockSafeRouteService extends SafeRouteService {}

class _MockSavedLocationService extends SavedLocationService {
  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => <SavedLocation>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const primaryNavy = Color(0xFF233253);
  const secondaryGrey = Color(0xFF8A94A6);

  group('Header Typography & RefreshIndicator Displacement Regression Tests', () {
    testWidgets('UserHomeScreen has Figma typography and settled displacement below header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: UserHomeScreen(
            hazardReportService: _MockHazardReportService(),
            alertService: _MockAlertService(),
            initialLocation: const LatLng(10.3157, 123.8920),
            skipLocationLookup: true,
          ),
        ),
      );
      await tester.pump();

      final BuildContext context = tester.element(find.byType(UserHomeScreen));
      final double headerHeight = CustomWavyHeader.height(context);

      // Verify RefreshIndicator displacement is at or below the header's lower edge
      final refreshFinder = find.byType(RefreshIndicator);
      expect(refreshFinder, findsOneWidget);
      final refreshWidget = tester.widget<RefreshIndicator>(refreshFinder);
      expect(refreshWidget.displacement, greaterThanOrEqualTo(headerHeight));

      // Overline Greeting text
      final greetingFinder = find.byWidgetPredicate((widget) {
        if (widget is! Text) return false;
        final data = widget.data ?? '';
        return data.startsWith('GOOD ');
      });
      expect(greetingFinder, findsOneWidget);
      final greetingText = tester.widget<Text>(greetingFinder);
      expect(greetingText.style?.fontFamily, 'Poppins');
      expect(greetingText.style?.fontSize, 11);
      expect(greetingText.style?.fontWeight, FontWeight.w600);
      expect(greetingText.style?.color, secondaryGrey);
      expect(greetingText.style?.letterSpacing, 1.5);

      // Main title
      final titleFinder = find.text('Stay safe out there.');
      expect(titleFinder, findsOneWidget);
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.style?.fontFamily, 'Poppins');
      expect(titleText.style?.fontSize, 24);
      expect(titleText.style?.fontWeight, FontWeight.w700);
      expect(titleText.style?.color, primaryNavy);
      expect(titleText.style?.letterSpacing, -0.4);
      expect(titleText.style?.height, 1.2);
    });

    testWidgets('RouteScreen has Figma typography and settled displacement below header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: RouteScreen(
            safeRouteService: _MockSafeRouteService(),
            hazardReportService: _MockHazardReportService(),
            savedLocationService: _MockSavedLocationService(),
            initialLocation: const LatLng(10.3157, 123.8920),
            skipLocationLookup: true,
            skipAutoSuggestion: true,
          ),
        ),
      );
      await tester.pump();

      final BuildContext context = tester.element(find.byType(RouteScreen));
      final double headerHeight = CustomWavyHeader.height(context);

      // Verify RefreshIndicator displacement is at or below the header's lower edge
      final refreshFinder = find.byType(RefreshIndicator);
      expect(refreshFinder, findsOneWidget);
      final refreshWidget = tester.widget<RefreshIndicator>(refreshFinder);
      expect(refreshWidget.displacement, greaterThanOrEqualTo(headerHeight));

      // Overline
      final overlineFinder = find.text('MY ROUTES');
      expect(overlineFinder, findsOneWidget);
      final overlineText = tester.widget<Text>(overlineFinder);
      expect(overlineText.style?.fontFamily, 'Poppins');
      expect(overlineText.style?.fontSize, 11);
      expect(overlineText.style?.fontWeight, FontWeight.w600);
      expect(overlineText.style?.color, secondaryGrey);
      expect(overlineText.style?.letterSpacing, 1.5);

      // Main Title
      final titleFinder = find.text('Plan your route,\ntravel safer.');
      expect(titleFinder, findsOneWidget);
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.style?.fontFamily, 'Poppins');
      expect(titleText.style?.fontSize, 24);
      expect(titleText.style?.fontWeight, FontWeight.w700);
      expect(titleText.style?.color, primaryNavy);
      expect(titleText.style?.letterSpacing, -0.4);
      expect(titleText.style?.height, 1.2);

      // Subtitle
      final subtitleFinder = find.text(
        'Find the safest way to your destination with real-time hazard avoidance and turn-by-turn navigation.',
      );
      expect(subtitleFinder, findsOneWidget);
      final subtitleText = tester.widget<Text>(subtitleFinder);
      expect(subtitleText.style?.fontFamily, 'Poppins');
      expect(subtitleText.style?.fontSize, 12);
      expect(subtitleText.style?.fontWeight, FontWeight.w400);
      expect(subtitleText.style?.color, secondaryGrey);
      expect(subtitleText.style?.height, 1.35);
    });

    testWidgets('AlertsScreen has Figma typography and settled displacement below header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AlertsScreen(
            alertService: _MockAlertService(),
            hazardReportService: _MockHazardReportService(),
          ),
        ),
      );
      await tester.pump();

      final BuildContext context = tester.element(find.byType(AlertsScreen));
      final double headerHeight = CustomWavyHeader.height(context);

      // Verify RefreshIndicator displacement is at or below the header's lower edge
      final refreshFinder = find.byType(RefreshIndicator);
      expect(refreshFinder, findsOneWidget);
      final refreshWidget = tester.widget<RefreshIndicator>(refreshFinder);
      expect(refreshWidget.displacement, greaterThanOrEqualTo(headerHeight));

      // Overline
      final overlineFinder = find.text('NOTIFICATIONS');
      expect(overlineFinder, findsOneWidget);
      final overlineText = tester.widget<Text>(overlineFinder);
      expect(overlineText.style?.fontFamily, 'Poppins');
      expect(overlineText.style?.fontSize, 11);
      expect(overlineText.style?.fontWeight, FontWeight.w600);
      expect(overlineText.style?.color, secondaryGrey);
      expect(overlineText.style?.letterSpacing, 1.5);

      // Main Title
      final titleFinder = find.text('Stay updated,\nstay safer.');
      expect(titleFinder, findsOneWidget);
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.style?.fontFamily, 'Poppins');
      expect(titleText.style?.fontSize, 24);
      expect(titleText.style?.fontWeight, FontWeight.w700);
      expect(titleText.style?.color, primaryNavy);
      expect(titleText.style?.letterSpacing, -0.4);
      expect(titleText.style?.height, 1.2);

      // Subtitle
      final subtitleFinder = find.text(
        'Get the latest alerts, community reports, and important updates in your area.',
      );
      expect(subtitleFinder, findsOneWidget);
      final subtitleText = tester.widget<Text>(subtitleFinder);
      expect(subtitleText.style?.fontFamily, 'Poppins');
      expect(subtitleText.style?.fontSize, 12);
      expect(subtitleText.style?.fontWeight, FontWeight.w400);
      expect(subtitleText.style?.color, secondaryGrey);
      expect(subtitleText.style?.height, 1.35);
    });

    testWidgets('UserProfileScreen has Figma typography and settled displacement below header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final profileService = _MockProfileService();

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            profileService: profileService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final BuildContext context = tester.element(find.byType(UserProfileScreen));
      final double headerHeight = CustomWavyHeader.height(context);

      // Verify RefreshIndicator displacement is at or below the header's lower edge
      final refreshFinder = find.byType(RefreshIndicator);
      expect(refreshFinder, findsOneWidget);
      final refreshWidget = tester.widget<RefreshIndicator>(refreshFinder);
      expect(refreshWidget.displacement, greaterThanOrEqualTo(headerHeight));

      // Display Name
      final nameFinder = find.text('Ma. Angelica May');
      expect(nameFinder, findsOneWidget);
      final nameText = tester.widget<Text>(nameFinder);
      expect(nameText.style?.fontFamily, 'Poppins');
      expect(nameText.style?.fontSize, 18);
      expect(nameText.style?.fontWeight, FontWeight.w700);
      expect(nameText.style?.color, primaryNavy);

      // Username
      final usernameFinder = find.text('@gelic');
      expect(usernameFinder, findsOneWidget);
      final usernameText = tester.widget<Text>(usernameFinder);
      expect(usernameText.style?.fontFamily, 'Poppins');
      expect(usernameText.style?.fontSize, 12);
      expect(usernameText.style?.fontWeight, FontWeight.w500);
      expect(usernameText.style?.color, secondaryGrey);

      // Location
      final locationFinder = find.text('Cebu City, Philippines');
      expect(locationFinder, findsOneWidget);
      final locationText = tester.widget<Text>(locationFinder);
      expect(locationText.style?.fontFamily, 'Poppins');
      expect(locationText.style?.fontSize, 11);
      expect(locationText.style?.fontWeight, FontWeight.w400);
      expect(locationText.style?.color, secondaryGrey);
    });
  });
}

