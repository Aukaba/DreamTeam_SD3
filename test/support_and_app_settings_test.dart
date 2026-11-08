import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dreamteam_sd3/Authentication/auth_service.dart';
import 'package:dreamteam_sd3/services/profile_service.dart';
import 'package:dreamteam_sd3/services/safe_route_service.dart';
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
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets(
        'UserProfileScreen navigates to Help & Support (without ticket form controls, hero card, or App Settings)',
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
      // Verify "How can we help you today?" hero card and support ticket headings are removed
      expect(find.text('How can we help you today?'), findsNothing);
      expect(find.text('Submit a Support Ticket'), findsNothing);
      expect(find.text('MY SUPPORT TICKETS'), findsNothing);

      // Verify ticket form widgets and identifying controls are absent
      expect(find.byType(Form), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byKey(const Key('open_ticket_form_button')), findsNothing);
      expect(
        find.byKey(const Key('support_ticket_subject_field')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('support_ticket_message_field')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('submit_support_ticket_button')),
        findsNothing,
      );

      // Verify Emergency Hotlines, Quick Guides, FAQs, and Contact Support are present
      expect(find.text('EMERGENCY HOTLINES'), findsOneWidget);
      expect(find.text('SAFEROUTE QUICK GUIDES'), findsOneWidget);
      expect(find.text('FREQUENTLY ASKED QUESTIONS'), findsOneWidget);
      expect(find.text('SafeRoute Support Desk'), findsOneWidget);
    });

    testWidgets(
        'HelpSupportScreen shows copied snackbar only when Clipboard.setData succeeds and reports failure on error',
        (tester) async {
      bool shouldFailClipboard = false;
      String? copiedText;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          if (shouldFailClipboard) {
            throw PlatformException(
              code: 'CLIPBOARD_ERROR',
              message: 'Clipboard unavailable',
            );
          }
          final args = call.arguments as Map<dynamic, dynamic>?;
          copiedText = args?['text']?.toString();
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HelpSupportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Copy Email button
      await tester.scrollUntilVisible(
        find.byKey(const Key('copy_support_email_button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 1. Successful clipboard write shows success snackbar
      await tester.tap(find.byKey(const Key('copy_support_email_button')));
      await tester.pumpAndSettle();

      expect(copiedText, 'support@saferoute.ph');
      expect(
        find.text('Support Email copied: support@saferoute.ph'),
        findsOneWidget,
      );

      // 2. Failed clipboard write does NOT show "copied" snackbar; reports failure instead
      shouldFailClipboard = true;
      await tester.tap(find.byKey(const Key('copy_support_email_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Support Email copied: support@saferoute.ph'),
        findsNothing,
      );
      expect(
        find.text(
          'Failed to copy Support Email. Please copy it manually: support@saferoute.ph',
        ),
        findsOneWidget,
      );
    });

    test(
        'SafeRouteService.formatDistance handles zero, negative, non-finite, meter, and kilometer values accurately',
        () {
      expect(SafeRouteService.formatDistance(0), '0 m');
      expect(SafeRouteService.formatDistance(-0.0), '0 m');
      expect(SafeRouteService.formatDistance(-42.5), '0 m');
      expect(SafeRouteService.formatDistance(double.nan), '0 m');
      expect(SafeRouteService.formatDistance(double.infinity), '0 m');
      expect(SafeRouteService.formatDistance(double.negativeInfinity), '0 m');
      expect(SafeRouteService.formatDistance(45.2), '45 m');
      expect(SafeRouteService.formatDistance(146.0), '150 m');
      expect(SafeRouteService.formatDistance(1500.0), '1.5 km');
      expect(SafeRouteService.formatDistance(12400.0), '12 km');
    });
  });
}
