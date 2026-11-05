import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dreamteam_sd3/Authentication/auth_service.dart';
import 'package:dreamteam_sd3/Authentication/login_page.dart';
import 'package:dreamteam_sd3/services/profile_service.dart';
import 'package:dreamteam_sd3/services/security_service.dart';
import 'package:dreamteam_sd3/user_screens/security_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_profile_screen.dart';

class _FakeProfileService extends ProfileService {
  @override
  Future<UserProfile?> getProfile() async {
    return const UserProfile(
      id: 'user-sec-1',
      email: 'elena@saferoute.ph',
      fullName: 'Elena Cruz',
    );
  }
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> signOut() async {}
}

class _FakeSecurityService extends SecurityService {
  String validCurrentPassword;
  UserSecuritySettings settings;
  final List<SecurityActivityLog> logs;

  int changePasswordCalls = 0;
  int resetEmailCalls = 0;
  int signOutOthersCalls = 0;
  int signOutAllCalls = 0;

  _FakeSecurityService({
    this.validCurrentPassword = 'OldPassword123!',
    UserSecuritySettings? initialSettings,
    List<SecurityActivityLog>? initialLogs,
  })  : settings = initialSettings ??
            const UserSecuritySettings(
              userId: 'user-sec-1',
              loginAlertsEnabled: true,
              keepSignedIn: true,
              anonymousReporting: false,
            ),
        logs = initialLogs ?? [];

  @override
  Future<AccountAccessOverview?> getSecurityOverview({int logLimit = 15}) async {
    return AccountAccessOverview(
      email: 'elena@saferoute.ph',
      emailVerified: true,
      lastSignInAt: DateTime.now().subtract(const Duration(minutes: 10)),
      currentPlatform: 'Windows',
      settings: settings,
      recentLogs: List<SecurityActivityLog>.from(logs),
    );
  }

  @override
  Future<UserSecuritySettings> updateSecuritySettings({
    bool? loginAlertsEnabled,
    bool? keepSignedIn,
    bool? anonymousReporting,
  }) async {
    settings = settings.copyWith(
      loginAlertsEnabled: loginAlertsEnabled,
      keepSignedIn: keepSignedIn,
      anonymousReporting: anonymousReporting,
    );
    logs.insert(
      0,
      SecurityActivityLog(
        id: logs.length + 1,
        userId: 'user-sec-1',
        eventType: 'security_settings_updated',
        description: 'Updated security preferences',
        platform: 'Windows',
        createdAt: DateTime.now(),
      ),
    );
    return settings;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword != validCurrentPassword) {
      throw Exception('Your current password is incorrect.');
    }
    changePasswordCalls++;
    validCurrentPassword = newPassword;
    settings = settings.copyWith(passwordChangedAt: DateTime.now());
    logs.insert(
      0,
      SecurityActivityLog(
        id: logs.length + 1,
        userId: 'user-sec-1',
        eventType: 'password_changed',
        description: 'Account password updated on Windows',
        platform: 'Windows',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> sendPasswordResetEmail() async {
    resetEmailCalls++;
    logs.insert(
      0,
      SecurityActivityLog(
        id: logs.length + 1,
        userId: 'user-sec-1',
        eventType: 'password_reset_requested',
        description: 'Requested password recovery link',
        platform: 'Windows',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> signOutOtherDevices() async {
    signOutOthersCalls++;
    settings = settings.copyWith(lastGlobalSignoutAt: DateTime.now());
    logs.insert(
      0,
      SecurityActivityLog(
        id: logs.length + 1,
        userId: 'user-sec-1',
        eventType: 'signed_out_other_devices',
        description: 'Signed out of all other active devices',
        platform: 'Windows',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> signOutAllDevices() async {
    signOutAllCalls++;
  }
}

void main() {
  group('Security Models & Password Strength Tests', () {
    test('PasswordStrengthInfo classifies passwords accurately', () {
      expect(
        PasswordStrengthInfo.evaluate('').level,
        PasswordStrengthLevel.empty,
      );
      expect(
        PasswordStrengthInfo.evaluate('12345').level,
        PasswordStrengthLevel.weak,
      );
      expect(
        PasswordStrengthInfo.evaluate('abcdef').level,
        PasswordStrengthLevel.weak,
      );
      expect(
        PasswordStrengthInfo.evaluate('Abcdefgh').level,
        PasswordStrengthLevel.fair,
      );
      expect(
        PasswordStrengthInfo.evaluate('Abcdefg1').level,
        PasswordStrengthLevel.good,
      );
      expect(
        PasswordStrengthInfo.evaluate('SafeRoute#2026!').level,
        PasswordStrengthLevel.strong,
      );
    });

    test('UserSecuritySettings and SecurityActivityLog parse JSON properly',
        () {
      final settings = UserSecuritySettings.fromJson({
        'user_id': 'u-99',
        'login_alerts_enabled': false,
        'keep_signed_in': true,
        'anonymous_reporting': true,
        'password_changed_at': '2026-11-05T16:00:00Z',
      });
      expect(settings.userId, 'u-99');
      expect(settings.loginAlertsEnabled, isFalse);
      expect(settings.keepSignedIn, isTrue);
      expect(settings.anonymousReporting, isTrue);
      expect(settings.passwordChangedAt, isNotNull);

      final log = SecurityActivityLog.fromJson({
        'id': 42,
        'user_id': 'u-99',
        'event_type': 'password_changed',
        'description': 'Account password updated',
        'platform': 'Android',
        'created_at': '2026-11-05T16:05:00Z',
      });
      expect(log.id, 42);
      expect(log.eventType, 'password_changed');
      expect(log.platform, 'Android');
    });
  });

  group('SecurityScreen & UserProfileScreen Integration Tests', () {
    testWidgets(
        'Tapping Security tile on UserProfileScreen opens SecurityScreen with DB state',
        (tester) async {
      final fakeSecurity = _FakeSecurityService();

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            profileService: _FakeProfileService(),
            securityService: fakeSecurity,
            authService: _FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final securityTile = find.text('Security');
      await tester.ensureVisible(securityTile);
      await tester.pumpAndSettle();
      await tester.tap(securityTile);
      await tester.pumpAndSettle();

      expect(find.byType(SecurityScreen), findsOneWidget);
      expect(find.text('Account Protected'), findsOneWidget);
      expect(find.text('Email Verified'), findsOneWidget);
      expect(find.text('elena@saferoute.ph'), findsOneWidget);
      expect(find.text('This Device (Windows)'), findsOneWidget);
    });

    testWidgets(
        'Change password validates inputs, rejects wrong current password, and updates on valid input',
        (tester) async {
      final fakeSecurity =
          _FakeSecurityService(validCurrentPassword: 'CorrectOldPassword!');

      await tester.pumpWidget(
        MaterialApp(
          home: SecurityScreen(service: fakeSecurity),
        ),
      );
      await tester.pumpAndSettle();

      final currentField =
          find.byKey(const Key('security_current_password_field'));
      final newField = find.byKey(const Key('security_new_password_field'));
      final confirmField =
          find.byKey(const Key('security_confirm_password_field'));
      final updateBtn =
          find.byKey(const Key('security_update_password_button'));

      // 1. Wrong current password
      await tester.enterText(currentField, 'WrongPassword123');
      await tester.enterText(newField, 'BrandNewPass#2026');
      await tester.enterText(confirmField, 'BrandNewPass#2026');
      await tester.ensureVisible(updateBtn);
      await tester.pumpAndSettle();
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      expect(fakeSecurity.changePasswordCalls, 0);
      expect(find.text('Your current password is incorrect.'), findsOneWidget);

      // 2. Correct current password -> updates and records audit log
      await tester.enterText(currentField, 'CorrectOldPassword!');
      await tester.ensureVisible(updateBtn);
      await tester.pumpAndSettle();
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      expect(fakeSecurity.changePasswordCalls, 1);
      expect(
        find.text('Account password updated on Windows'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Toggling preferences, signing out other devices, and signing out all devices work end-to-end',
        (tester) async {
      final fakeSecurity = _FakeSecurityService();

      await tester.pumpWidget(
        MaterialApp(
          home: SecurityScreen(service: fakeSecurity),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Toggle Anonymous Hazard Reports switch
      final anonSwitch =
          find.byKey(const Key('security_anonymous_reporting_switch'));
      await tester.ensureVisible(anonSwitch);
      await tester.pumpAndSettle();
      await tester.tap(anonSwitch);
      await tester.pumpAndSettle();

      expect(fakeSecurity.settings.anonymousReporting, isTrue);
      expect(find.text('Updated security preferences'), findsOneWidget);

      // 2. Sign Out of Other Devices
      final signOutOthersBtn =
          find.byKey(const Key('security_sign_out_others_button'));
      await tester.ensureVisible(signOutOthersBtn);
      await tester.pumpAndSettle();
      await tester.tap(signOutOthersBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Out Others'));
      await tester.pumpAndSettle();

      expect(fakeSecurity.signOutOthersCalls, 1);
      expect(
        find.text('Signed out of all other active devices'),
        findsOneWidget,
      );

      // 3. Sign Out of All Devices navigates to LoginPage
      final signOutAllBtn =
          find.byKey(const Key('security_sign_out_all_button'));
      await tester.ensureVisible(signOutAllBtn);
      await tester.pumpAndSettle();
      await tester.tap(signOutAllBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Out All'));
      await tester.pumpAndSettle();

      expect(fakeSecurity.signOutAllCalls, 1);
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}

