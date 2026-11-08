import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dreamteam_sd3/Authentication/auth_service.dart';
import 'package:dreamteam_sd3/services/profile_service.dart';
import 'package:dreamteam_sd3/user_screens/help_support_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_profile_screen.dart';

class _FakeProfileService extends ProfileService {
  final UserProfile storedProfile;

  _FakeProfileService(this.storedProfile);

  @override
  Future<UserProfile?> getProfile() async => storedProfile;
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> signOut() async {}
}

void main() {
  group('Help & Support Integration Tests', () {
    testWidgets(
        'UserProfileScreen navigates to Help & Support (without ticket form, hero card, or App Settings)',
        (tester) async {
      final profileService = _FakeProfileService(
        const UserProfile(
          id: 'user-1',
          email: 'maria@saferoute.ph',
          fullName: 'Maria Santos',
          username: 'maria_s',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            profileService: profileService,
            authService: _FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to SUPPORT section and verify App Settings is removed
      await tester.scrollUntilVisible(
        find.text('Help & Support'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('App Settings'), findsNothing);

      // Tap Help & Support
      await tester.tap(find.text('Help & Support'));
      await tester.pumpAndSettle();

      expect(find.byType(HelpSupportScreen), findsOneWidget);
      // Verify "How can we help you today?" hero card and support tickets are removed
      expect(find.text('How can we help you today?'), findsNothing);
      expect(find.text('Submit a Support Ticket'), findsNothing);
      expect(find.text('MY SUPPORT TICKETS'), findsNothing);

      // Verify Emergency Hotlines, Quick Guides, FAQs, and Contact Support are present
      expect(find.text('EMERGENCY HOTLINES'), findsOneWidget);
      expect(find.text('SAFEROUTE QUICK GUIDES'), findsOneWidget);
      expect(find.text('FREQUENTLY ASKED QUESTIONS'), findsOneWidget);
      expect(find.text('SafeRoute Support Desk'), findsOneWidget);
    });
  });
}
