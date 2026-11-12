import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamteam_sd3/Authentication/auth_service.dart';
import 'package:dreamteam_sd3/Authentication/reset_password_page.dart';

class _FakeAuthService extends AuthService {
  String? lastResetEmail;
  String? lastVerifiedEmail;
  String? lastVerifiedToken;
  String? lastUpdatedPassword;
  bool shouldFailVerifyOtp = false;
  bool shouldFailResetPassword = false;

  @override
  Future<void> resetPassword({required String email}) async {
    if (shouldFailResetPassword) {
      throw const AuthException('Unable to send reset email');
    }
    lastResetEmail = email;
  }

  @override
  Future<AuthResponse> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    if (shouldFailVerifyOtp) {
      throw const AuthException('Token is invalid or has expired');
    }
    lastVerifiedEmail = email;
    lastVerifiedToken = token;
    return AuthResponse(
      session: Session(
        accessToken: 'fake_access_token',
        tokenType: 'bearer',
        user: User(
          id: 'fake_user_id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      ),
    );
  }

  @override
  Future<UserResponse> updatePassword({required String newPassword}) async {
    lastUpdatedPassword = newPassword;
    return UserResponse.fromJson({
      'id': 'fake_user_id',
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> signOut() async {
    // No-op for test
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OTP-based Forgot Password Flow Tests', () {
    late _FakeAuthService fakeAuthService;

    setUp(() {
      fakeAuthService = _FakeAuthService();
    });

    testWidgets(
      'Step 1: Validates email input and sends OTP, transitioning to Step 2',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ResetPasswordPage(
              authService: fakeAuthService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial State: Email input screen
        expect(find.text('RESET PASSWORD'), findsOneWidget);
        expect(find.text('Reset your password.'), findsOneWidget);
        expect(find.byKey(const Key('reset_password_email_field')), findsOneWidget);
        expect(find.text('Send verification code'), findsOneWidget);

        // Try submitting empty email
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();
        expect(find.text('Please enter your email address.'), findsOneWidget);

        // Try submitting invalid email
        await tester.enterText(
          find.byKey(const Key('reset_password_email_field')),
          'invalid_email',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid email address.'), findsOneWidget);

        // Enter valid email and submit
        await tester.enterText(
          find.byKey(const Key('reset_password_email_field')),
          'driver@test.com',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();

        // Verify service was called with email
        expect(fakeAuthService.lastResetEmail, 'driver@test.com');

        // Verify transitioned to Step 2: OTP screen
        expect(find.text('VERIFY OTP'), findsOneWidget);
        expect(find.text('Enter verification code.'), findsOneWidget);
        expect(find.textContaining('driver@test.com'), findsOneWidget);
        expect(find.byKey(const Key('reset_password_otp_field')), findsOneWidget);
        expect(find.text('Verify code'), findsOneWidget);
        expect(find.text('Change email'), findsOneWidget);
      },
    );

    testWidgets(
      'Step 2: Validates OTP input, handles invalid token, and transitions to Step 3 on success',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ResetPasswordPage(
              authService: fakeAuthService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Reach Step 2
        await tester.enterText(
          find.byKey(const Key('reset_password_email_field')),
          'driver@test.com',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();

        // Try submitting empty OTP
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();
        expect(find.text('Please enter the 6-digit verification code.'), findsOneWidget);

        // Try submitting short OTP (< 6 digits)
        await tester.enterText(
          find.byKey(const Key('reset_password_otp_field')),
          '123',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();
        expect(find.text('Verification code must be 6 digits.'), findsOneWidget);

        // Try submitting invalid OTP with service rejection
        fakeAuthService.shouldFailVerifyOtp = true;
        await tester.enterText(
          find.byKey(const Key('reset_password_otp_field')),
          '000000',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();
        expect(find.textContaining('expired or is invalid'), findsOneWidget);

        // Submit valid OTP
        fakeAuthService.shouldFailVerifyOtp = false;
        await tester.enterText(
          find.byKey(const Key('reset_password_otp_field')),
          '654321',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();

        // Verify service was called with email & token
        expect(fakeAuthService.lastVerifiedEmail, 'driver@test.com');
        expect(fakeAuthService.lastVerifiedToken, '654321');

        // Verify transitioned to Step 3: New password screen
        expect(find.text('NEW PASSWORD'), findsOneWidget);
        expect(find.text('Create new password.'), findsOneWidget);
        expect(find.byKey(const Key('reset_password_new_field')), findsOneWidget);
        expect(find.byKey(const Key('reset_password_confirm_field')), findsOneWidget);
        expect(find.text('Update password'), findsOneWidget);
      },
    );

    testWidgets(
      'Step 2: "Change email" allows navigating back to Step 1',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ResetPasswordPage(
              authService: fakeAuthService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Move to Step 2
        await tester.enterText(
          find.byKey(const Key('reset_password_email_field')),
          'wrong@test.com',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();

        expect(find.text('VERIFY OTP'), findsOneWidget);

        // Tap Change email
        await tester.tap(find.text('Change email'));
        await tester.pumpAndSettle();

        // Back on Step 1 with email field editable
        expect(find.text('RESET PASSWORD'), findsOneWidget);
        expect(find.byKey(const Key('reset_password_email_field')), findsOneWidget);
      },
    );

    testWidgets(
      'Step 3: Validates new password and completes reset successfully',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ResetPasswordPage(
              authService: fakeAuthService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: Email
        await tester.enterText(
          find.byKey(const Key('reset_password_email_field')),
          'user@safe.com',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();

        // Step 2: OTP
        await tester.enterText(
          find.byKey(const Key('reset_password_otp_field')),
          '112233',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();

        // Step 3: New Password
        // Test short password
        await tester.enterText(
          find.byKey(const Key('reset_password_new_field')),
          '123',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();
        expect(find.text('Password must be at least 6 characters long.'), findsOneWidget);

        // Test password mismatch
        await tester.enterText(
          find.byKey(const Key('reset_password_new_field')),
          'Password123!',
        );
        await tester.enterText(
          find.byKey(const Key('reset_password_confirm_field')),
          'Password999!',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match. Please verify and try again.'), findsOneWidget);

        // Valid matching passwords
        await tester.enterText(
          find.byKey(const Key('reset_password_confirm_field')),
          'Password123!',
        );
        await tester.tap(find.byKey(const Key('reset_password_primary_button')));
        await tester.pumpAndSettle();

        expect(fakeAuthService.lastUpdatedPassword, 'Password123!');
      },
    );
  });
}
