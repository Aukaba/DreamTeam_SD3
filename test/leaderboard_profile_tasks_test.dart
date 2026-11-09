import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamteam_sd3/Authentication/auth_service.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';
import 'package:dreamteam_sd3/services/leaderboard_service.dart';
import 'package:dreamteam_sd3/services/profile_service.dart';
import 'package:dreamteam_sd3/services/safe_route_service.dart';
import 'package:dreamteam_sd3/user_screens/my_reports_screen.dart';
import 'package:dreamteam_sd3/user_screens/saved_routes_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_leaderboard_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_profile_screen.dart';

class _FakeProfileService extends ProfileService {
  final UserProfile profile;
  _FakeProfileService(this.profile);

  @override
  Future<UserProfile?> getProfile() async => profile;
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> signOut() async {}
}

class _FakeHazardReportService extends HazardReportService {
  final List<HazardReportData> userReports;

  _FakeHazardReportService(this.userReports);

  @override
  Future<List<HazardReportData>> fetchUserReports({
    String? userId,
    int limit = 100,
    bool includeUnaccepted = false,
  }) async {
    return userReports
        .where(
          (r) =>
              includeUnaccepted ||
              HazardReportStatuses.isAcceptedForUserReports(r.status),
        )
        .toList();
  }

  @override
  Future<List<HazardReportData>> fetchReports({
    int limit = 100,
    bool activeOnly = true,
  }) async {
    return List<HazardReportData>.from(userReports);
  }

  @override
  Future<void> deleteUserReport(String reportId) async {
    userReports.removeWhere((r) => r.reportId == reportId);
  }
}

class _FakeSafeRouteService extends SafeRouteService {
  final List<SavedRouteRecord> routes;

  _FakeSafeRouteService(this.routes);

  @override
  Future<List<SavedRouteRecord>> fetchSavedRoutes({
    List<HazardReportData>? activeHazards,
  }) async {
    return List<SavedRouteRecord>.from(routes);
  }

  @override
  Future<void> renameSavedRoute(String id, String newTitle) async {
    final idx = routes.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      final old = routes[idx];
      routes[idx] = SavedRouteRecord(
        id: old.id,
        userId: old.userId,
        title: newTitle,
        originLabel: old.originLabel,
        origin: old.origin,
        destinationLabel: old.destinationLabel,
        destination: old.destination,
        travelMode: old.travelMode,
        avoidHazards: old.avoidHazards,
        distanceMeters: old.distanceMeters,
        durationSeconds: old.durationSeconds,
        hazardCount: old.hazardCount,
        riskLevel: old.riskLevel,
        routeSummary: old.routeSummary,
        polyline: old.polyline,
        steps: old.steps,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> deleteSavedRoute(String id) async {
    routes.removeWhere((r) => r.id == id);
  }
}

class _FakeLeaderboardService extends LeaderboardService {
  final List<LeaderboardUserEntry> entries;
  final UserGamificationStats stats;

  _FakeLeaderboardService({
    required this.entries,
    required this.stats,
  });

  @override
  Future<List<LeaderboardUserEntry>> fetchLeaderboard({
    bool isWeekly = false,
  }) async {
    return entries;
  }

  @override
  Future<UserGamificationStats> fetchCurrentUserGamificationStats() async {
    return stats;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    HazardReportService.clearSessionReports();
  });

  group('Task 1: Report Severity Points & Level Progression Math', () {
    test('Severity points start at 1 (Low) and increase by 1 per severity level', () {
      expect(HazardReportService.calculateSeverityPoints('Low'), 1);
      expect(HazardReportService.calculateSeverityPoints('Medium'), 2);
      expect(HazardReportService.calculateSeverityPoints('High'), 3);
      expect(HazardReportService.calculateSeverityPoints('Critical'), 3);
    });

    test('Level 1 requires 20 points and each level up requires 1/4 more points (Lv 2 = 25, Lv 3 = 31, Lv 4 = 39)', () {
      expect(LevelProgressData.pointsRequiredForLevel(1), 20);
      expect(LevelProgressData.pointsRequiredForLevel(2), 25);
      expect(LevelProgressData.pointsRequiredForLevel(3), 31);
      expect(LevelProgressData.pointsRequiredForLevel(4), 39);
      expect(LevelProgressData.pointsRequiredForLevel(5), 49);

      final lv1Start = LevelProgressData.fromTotalPoints(0);
      expect(lv1Start.level, 1);
      expect(lv1Start.currentLevelPoints, 0);
      expect(lv1Start.nextLevelRequiredPoints, 20);

      final lv1Almost = LevelProgressData.fromTotalPoints(19);
      expect(lv1Almost.level, 1);
      expect(lv1Almost.currentLevelPoints, 19);
      expect(lv1Almost.nextLevelRequiredPoints, 20);

      // Earning 20 points reaches Level 2, where 25 points are needed for Level 3
      final lv2Start = LevelProgressData.fromTotalPoints(20);
      expect(lv2Start.level, 2);
      expect(lv2Start.currentLevelPoints, 0);
      expect(lv2Start.nextLevelRequiredPoints, 25);

      final lv2Mid = LevelProgressData.fromTotalPoints(25);
      expect(lv2Mid.level, 2);
      expect(lv2Mid.currentLevelPoints, 5);
      expect(lv2Mid.nextLevelRequiredPoints, 25);

      // Earning 20 + 25 = 45 points reaches Level 3, where 31 points are needed
      final lv3Start = LevelProgressData.fromTotalPoints(45);
      expect(lv3Start.level, 3);
      expect(lv3Start.currentLevelPoints, 0);
      expect(lv3Start.nextLevelRequiredPoints, 31);
    });

    testWidgets('UserLeaderboardScreen renders DB rankings for Points, Reports, and Routes tabs', (tester) async {
      final entries = <LeaderboardUserEntry>[
        LeaderboardUserEntry(
          userId: 'u-1',
          displayName: 'Juan Dela Cruz',
          username: 'juandc',
          reportCount: 10,
          safetyPoints: 25,
          savedRoutesCount: 4,
          allTimePoints: 25,
          allTimeReports: 10,
          levelProgress: LevelProgressData.fromTotalPoints(25),
          daysActive: 14,
          isCurrentUser: true,
        ),
        LeaderboardUserEntry(
          userId: 'u-2',
          displayName: 'Maria Santos',
          username: 'marias',
          reportCount: 6,
          safetyPoints: 15,
          savedRoutesCount: 7,
          allTimePoints: 15,
          allTimeReports: 6,
          levelProgress: LevelProgressData.fromTotalPoints(15),
          daysActive: 9,
          isCurrentUser: false,
        ),
      ];

      final fakeLeaderboard = _FakeLeaderboardService(
        entries: entries,
        stats: UserGamificationStats.fromCounts(
          reportCount: 10,
          totalPoints: 25,
          savedRoutesCount: 4,
          daysActive: 14,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserLeaderboardScreen(
            leaderboardService: fakeLeaderboard,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Safety Points tab shows points and severity point rules
      expect(find.text('Juan Dela Cruz'), findsWidgets);
      expect(find.text('Maria Santos'), findsWidgets);
      expect(find.text('25 pts'), findsOneWidget);
      expect(find.text('Low severity hazard report'), findsOneWidget);
      expect(find.text('Medium severity hazard report'), findsOneWidget);
      expect(find.text('High severity hazard report'), findsOneWidget);

      // Switch to Reports tab
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('REPORTS'), findsOneWidget);
      expect(find.text('10 reports'), findsOneWidget);

      // Switch to Routes tab (Maria has 7 routes vs Juan's 4 routes)
      await tester.tap(find.text('Routes'));
      await tester.pumpAndSettle();
      expect(find.text('ROUTES'), findsOneWidget);
      expect(find.text('7 routes'), findsOneWidget);
    });
  });

  group('Task 2, 3, 4: UserProfileScreen, MyReportsScreen & SavedRoutesScreen', () {
    testWidgets('UserProfileScreen removes Notification Settings & Location Preferences and shows live Level 2 (5 / 25 pts)', (tester) async {
      final fakeProfile = _FakeProfileService(
        const UserProfile(
          id: 'u-1',
          email: 'juan@saferoute.ph',
          fullName: 'Juan Dela Cruz',
          username: 'juandc',
        ),
      );
      final fakeLeaderboard = _FakeLeaderboardService(
        entries: const <LeaderboardUserEntry>[],
        stats: UserGamificationStats.fromCounts(
          reportCount: 9,
          totalPoints: 25, // Level 2: 5 / 25 pts
          savedRoutesCount: 3,
          daysActive: 12,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            profileService: fakeProfile,
            authService: _FakeAuthService(),
            leaderboardService: fakeLeaderboard,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Task 2: Notification Settings & Location Preferences must NOT exist
      expect(find.text('Notification Settings'), findsNothing);
      expect(find.text('Location Preferences'), findsNothing);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);

      // Task 1: Level 2 progress bar shows 5 / 25 pts
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text('5 / 25 pts'), findsOneWidget);
      expect(find.text('9'), findsOneWidget); // 9 Reports
      expect(find.text('25'), findsOneWidget); // 25 Safety Points
      expect(find.text('3'), findsOneWidget); // 3 Safe Routes
    });

    testWidgets('Task 3: My Reports button opens MyReportsScreen and lists user past reports with severity points', (tester) async {
      final reports = <HazardReportData>[
        HazardReportData(
          reportId: 'rep-1',
          userId: 'u-1',
          category: '🚧 Road damage',
          securityLevel: 'High',
          title: 'Collapsed Roadway',
          description: 'Deep road collapse blocking right lane',
          address: 'Osmena Blvd, Cebu City',
          location: const LatLng(10.3157, 123.8854),
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        HazardReportData(
          reportId: 'rep-2',
          userId: 'u-1',
          category: '🌊 Flood',
          securityLevel: 'Low',
          title: 'Minor Street Puddle',
          description: 'Ankle-deep water near curb',
          address: 'Colon St, Cebu City',
          location: const LatLng(10.2966, 123.8994),
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      final fakeHazardService = _FakeHazardReportService(reports);

      await tester.pumpWidget(
        MaterialApp(
          home: MyReportsScreen(
            hazardReportService: fakeHazardService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Reports'), findsOneWidget);
      expect(find.text('Collapsed Roadway'), findsOneWidget);
      expect(find.text('Minor Street Puddle'), findsOneWidget);
      expect(find.text('+3 pts'), findsOneWidget);
      expect(find.text('+1 pt'), findsOneWidget);
      expect(find.text('4 pts'), findsOneWidget); // 3 + 1 = 4 total pts
    });

    testWidgets('Task 4: Saved Routes screen displays saved routes and supports renaming and deleting', (tester) async {
      final routes = <SavedRouteRecord>[
        SavedRouteRecord(
          id: 'route-1',
          userId: 'u-1',
          title: 'Home to University',
          originLabel: 'Labangon',
          origin: const LatLng(10.3010, 123.8820),
          destinationLabel: 'CIT-U Campus',
          destination: const LatLng(10.2945, 123.8811),
          travelMode: RouteTravelMode.walking,
          distanceMeters: 1250,
          durationSeconds: 900,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      final fakeSafeRouteService = _FakeSafeRouteService(routes);
      final fakeHazardService = _FakeHazardReportService(<HazardReportData>[]);

      await tester.pumpWidget(
        MaterialApp(
          home: SavedRoutesScreen(
            safeRouteService: fakeSafeRouteService,
            hazardReportService: fakeHazardService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved Routes'), findsOneWidget);
      expect(find.text('Home to University'), findsOneWidget);
      expect(find.text('Labangon → CIT-U Campus'), findsOneWidget);
      expect(find.text('Start Navigation'), findsOneWidget);
    });
  });
}

