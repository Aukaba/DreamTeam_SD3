import 'dart:async';

import 'package:dreamteam_sd3/Authentication/role_service.dart';
import 'package:dreamteam_sd3/admin_screens/admin_dashboard_screen.dart';
import 'package:dreamteam_sd3/admin_screens/admin_profile_screen.dart';
import 'package:dreamteam_sd3/admin_screens/admin_reports_screen.dart';
import 'package:dreamteam_sd3/admin_screens/admin_settings_screens.dart';
import 'package:dreamteam_sd3/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session _createFakeSession(String userId) {
  final user = User(
    id: userId,
    appMetadata: const {'role': 'admin'},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
  );
  return Session(
    accessToken: 'fake-access-token-$userId',
    tokenType: 'bearer',
    user: user,
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthWrapper role verification & caching (Comments 4 & 8)', () {
    testWidgets(
      'surfaces error + Retry instead of UserHomeScreen when role lookup fails, then routes admin on Retry',
      (tester) async {
        final streamController = StreamController<AuthState>();
        addTearDown(streamController.close);

        var attempts = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: AuthWrapper(
              authStateStream: streamController.stream,
              roleResolver: (userId) async {
                attempts++;
                if (attempts == 1) {
                  return const UserRoleResolution(
                    status: UserRoleStatus.error,
                    message: 'Temporary network failure',
                  );
                }
                return const UserRoleResolution.admin();
              },
              onSignOut: () async {},
              adminScreen: const Scaffold(body: Text('ADMIN_HOME')),
              userScreen: const Scaffold(body: Text('USER_HOME')),
              loginScreen: const Scaffold(body: Text('LOGIN_SCREEN')),
            ),
          ),
        );

        streamController.add(
          AuthState(AuthChangeEvent.signedIn, _createFakeSession('admin-1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Verification Failed'), findsOneWidget);
        expect(find.text('Temporary network failure'), findsOneWidget);
        expect(find.text('USER_HOME'), findsNothing);
        expect(attempts, 1);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(attempts, 2);
        expect(find.text('ADMIN_HOME'), findsOneWidget);
        expect(find.text('USER_HOME'), findsNothing);
      },
    );

    testWidgets(
      'surfaces Access Not Permitted instead of UserHomeScreen when role is unrecognized',
      (tester) async {
        final streamController = StreamController<AuthState>();
        addTearDown(streamController.close);

        await tester.pumpWidget(
          MaterialApp(
            home: AuthWrapper(
              authStateStream: streamController.stream,
              roleResolver: (_) async => const UserRoleResolution(
                status: UserRoleStatus.unauthorized,
                message: 'Unrecognized account role.',
              ),
              onSignOut: () async {},
              adminScreen: const Scaffold(body: Text('ADMIN_HOME')),
              userScreen: const Scaffold(body: Text('USER_HOME')),
              loginScreen: const Scaffold(body: Text('LOGIN_SCREEN')),
            ),
          ),
        );

        streamController.add(
          AuthState(AuthChangeEvent.signedIn, _createFakeSession('unknown-1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Access Not Permitted'), findsOneWidget);
        expect(find.text('USER_HOME'), findsNothing);
      },
    );

    testWidgets(
      'caches role lookup across repeated auth updates for the same user ID',
      (tester) async {
        final streamController = StreamController<AuthState>();
        addTearDown(streamController.close);

        final queriedUserIds = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: AuthWrapper(
              authStateStream: streamController.stream,
              roleResolver: (userId) async {
                queriedUserIds.add(userId);
                return const UserRoleResolution.user();
              },
              onSignOut: () async {},
              adminScreen: const Scaffold(body: Text('ADMIN_HOME')),
              userScreen: const Scaffold(body: Text('USER_HOME')),
              loginScreen: const Scaffold(body: Text('LOGIN_SCREEN')),
            ),
          ),
        );

        streamController.add(
          AuthState(AuthChangeEvent.signedIn, _createFakeSession('user-1')),
        );
        await tester.pumpAndSettle();
        expect(find.text('USER_HOME'), findsOneWidget);
        expect(queriedUserIds, ['user-1']);

        // Subsequent token refresh / userUpdated events for the same user MUST NOT re-query.
        streamController.add(
          AuthState(
            AuthChangeEvent.tokenRefreshed,
            _createFakeSession('user-1'),
          ),
        );
        await tester.pumpAndSettle();

        streamController.add(
          AuthState(AuthChangeEvent.userUpdated, _createFakeSession('user-1')),
        );
        await tester.pumpAndSettle();

        expect(queriedUserIds, ['user-1']);

        // Signing out and signing in as a different user triggers a new lookup.
        streamController.add(const AuthState(AuthChangeEvent.signedOut, null));
        await tester.pumpAndSettle();
        expect(find.text('LOGIN_SCREEN'), findsOneWidget);

        streamController.add(
          AuthState(AuthChangeEvent.signedIn, _createFakeSession('user-2')),
        );
        await tester.pumpAndSettle();
        expect(queriedUserIds, ['user-1', 'user-2']);
      },
    );
  });

  group('AdminDashboardScreen SafeArea, RingPainter & destinations (Comments 1, 6, 7)', () {
    testWidgets(
      'respects top SafeArea inset and wires View all controls to destinations',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(
              size: Size(430, 932),
              padding: EdgeInsets.only(top: 48),
            ),
            child: MaterialApp(
              home: AdminDashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SafeArea), findsOneWidget);
        final greetingTop =
            tester.getTopLeft(find.text('Good morning, Admin.')).dy;
        expect(greetingTop, greaterThan(48));

        // Tap first "View all" (Latest reports) -> AdminReportsScreen
        final viewAllButtons = find.text('View all');
        expect(viewAllButtons, findsNWidgets(2));

        await tester.ensureVisible(viewAllButtons.first);
        await tester.tap(viewAllButtons.first);
        await tester.pumpAndSettle();

        expect(find.byType(AdminReportsScreen), findsOneWidget);

        // Navigate back and tap second "View all" (Analytics) -> AdminAnalyticsScreen
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();

        final analyticsViewAll = find.text('View all').last;
        await tester.ensureVisible(analyticsViewAll);
        await tester.tap(analyticsViewAll);
        await tester.pumpAndSettle();

        expect(find.byType(AdminAnalyticsScreen), findsOneWidget);
      },
    );
  });

  group('AdminProfileScreen lifecycle & menu destinations (Comments 5 & 6)', () {
    testWidgets(
      'does not call setState after dispose when profile fetch completes late (success & error)',
      (tester) async {
        final successCompleter = Completer<Map<String, dynamic>>();

        await tester.pumpWidget(
          MaterialApp(
            home: AdminProfileScreen(
              profileLoader: () => successCompleter.future,
            ),
          ),
        );

        // Dispose AdminProfileScreen while request is still pending
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('OTHER'))),
        );

        successCompleter.complete({
          'full_name': 'Late Admin',
          'email': 'late@saferoute.ph',
          'role': 'admin',
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Repeat for error path after dispose
        final errorCompleter = Completer<Map<String, dynamic>>();
        await tester.pumpWidget(
          MaterialApp(
            home: AdminProfileScreen(
              profileLoader: () => errorCompleter.future,
            ),
          ),
        );
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('OTHER_2'))),
        );

        errorCompleter.completeError(Exception('Network aborted'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'opens all profile menu destinations and updates admin name from Account Information',
      (tester) async {
        String? savedName;

        await tester.pumpWidget(
          MaterialApp(
            home: AdminProfileScreen(
              profileLoader: () async => {
                'full_name': 'Initial Admin',
                'email': 'admin@saferoute.ph',
                'role': 'admin',
              },
              onSaveFullName: (newName) async {
                savedName = newName;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Initial Admin'), findsOneWidget);

        // 1. Account Information
        await tester.ensureVisible(find.text('Account Information'));
        await tester.tap(find.text('Account Information'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminAccountInfoScreen), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Updated Admin Name');
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        expect(savedName, 'Updated Admin Name');
        expect(find.text('Updated Admin Name'), findsOneWidget);

        // 2. Safety Settings
        await tester.ensureVisible(find.text('Safety Settings'));
        await tester.tap(find.text('Safety Settings'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminSafetySettingsScreen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();

        // 3. Report Management
        await tester.ensureVisible(find.text('Report Management'));
        await tester.tap(find.text('Report Management'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminReportsScreen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();

        // 4. About SafeRoute
        await tester.ensureVisible(find.text('About SafeRoute'));
        await tester.tap(find.text('About SafeRoute'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminAboutSafeRouteScreen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();

        // 5. Help & Support
        await tester.ensureVisible(find.text('Help & Support'));
        await tester.tap(find.text('Help & Support'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminHelpSupportScreen), findsOneWidget);
      },
    );
  });
}

