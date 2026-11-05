import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dreamteam_sd3/Authentication/auth_service.dart';
import 'package:dreamteam_sd3/services/profile_service.dart';
import 'package:dreamteam_sd3/user_screens/personal_information_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_profile_screen.dart';

class _FakeProfileService extends ProfileService {
  UserProfile? storedProfile;
  bool shouldSendEmailConfirmation = false;
  int updateCallCount = 0;
  int uploadCallCount = 0;
  int removeAvatarCallCount = 0;

  _FakeProfileService({this.storedProfile});

  @override
  Future<UserProfile?> getProfile() async {
    return storedProfile;
  }

  @override
  Future<ProfileUpdateResult> updateProfile({
    required String fullName,
    required String email,
    String? username,
    String? phoneNumber,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    updateCallCount++;

    String? cleanOpt(String? v) {
      if (v == null) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    String? cleanUser = cleanOpt(username);
    if (cleanUser != null && cleanUser.startsWith('@')) {
      cleanUser = cleanUser.substring(1).trim();
      if (cleanUser.isEmpty) cleanUser = null;
    }

    final emailChanged = storedProfile != null &&
        storedProfile!.email.toLowerCase() != email.trim().toLowerCase();

    final updated = UserProfile(
      id: storedProfile?.id ?? 'user-123',
      email: email.trim(),
      fullName: fullName.trim(),
      username: cleanUser,
      avatarUrl: storedProfile?.avatarUrl,
      phoneNumber: cleanOpt(phoneNumber),
      address: cleanOpt(address),
      emergencyContactName: cleanOpt(emergencyContactName),
      emergencyContactPhone: cleanOpt(emergencyContactPhone),
      role: storedProfile?.role ?? 'user',
    );
    storedProfile = updated;

    return ProfileUpdateResult(
      profile: updated,
      emailConfirmationSent: shouldSendEmailConfirmation || emailChanged,
    );
  }

  @override
  Future<UserProfile> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    uploadCallCount++;
    final ext = ProfileService.detectImageExtension(
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
    final updated = (storedProfile ??
            const UserProfile(
              id: 'user-123',
              email: 'test@saferoute.ph',
              fullName: 'Test User',
            ))
        .copyWith(avatarUrl: 'https://example.com/avatars/avatar.$ext');
    storedProfile = updated;
    return updated;
  }

  @override
  Future<UserProfile> removeAvatar() async {
    removeAvatarCallCount++;
    final updated = (storedProfile ??
            const UserProfile(
              id: 'user-123',
              email: 'test@saferoute.ph',
              fullName: 'Test User',
            ))
        .copyWith(clearAvatarUrl: true);
    storedProfile = updated;
    return updated;
  }
}

class _FakeAuthService extends AuthService {
  bool signedOut = false;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class _FakeImagePicker extends ImagePicker {
  final XFile? fileToReturn;

  _FakeImagePicker({this.fileToReturn});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return fileToReturn;
  }
}

void main() {
  group('UserProfile Model Tests', () {
    test('fromJson parses all personal information fields accurately', () {
      final json = {
        'id': 'uuid-001',
        'email': 'carlos.reyes@example.com',
        'full_name': 'Carlos Reyes',
        'username': 'carlos_r',
        'avatar_url': 'https://example.com/avatar.png',
        'phone_number': '+63 917 123 4567',
        'address': 'Lahug, Cebu City',
        'emergency_contact_name': 'Elena Reyes',
        'emergency_contact_phone': '+63 918 765 4321',
        'role': 'user',
        'created_at': '2026-11-05T10:00:00Z',
        'updated_at': '2026-11-05T12:00:00Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'uuid-001');
      expect(profile.email, 'carlos.reyes@example.com');
      expect(profile.fullName, 'Carlos Reyes');
      expect(profile.displayName, 'Carlos Reyes');
      expect(profile.initials, 'CR');
      expect(profile.formattedUsername, '@carlos_r');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.phoneNumber, '+63 917 123 4567');
      expect(profile.address, 'Lahug, Cebu City');
      expect(profile.displayLocation, 'Lahug, Cebu City');
      expect(profile.emergencyContactName, 'Elena Reyes');
      expect(profile.emergencyContactPhone, '+63 918 765 4321');
      expect(profile.role, 'user');
    });

    test('fromJson uses fallbacks and defaults when optional fields are null',
        () {
      final profile = UserProfile.fromJson(
        {'id': 'uuid-002', 'email': '', 'full_name': null},
        fallbackEmail: 'maria@saferoute.ph',
        fallbackFullName: 'Maria Santos',
      );

      expect(profile.email, 'maria@saferoute.ph');
      expect(profile.fullName, 'Maria Santos');
      expect(profile.initials, 'MS');
      expect(profile.formattedUsername, isNull);
      expect(profile.displayLocation, 'Cebu City, Philippines');
    });

    test('formattedUsername avoids duplicate @ prefix', () {
      const p = UserProfile(
        id: '1',
        email: 'a@b.com',
        fullName: 'Alex',
        username: '@alex_cebu',
      );
      expect(p.formattedUsername, '@alex_cebu');
      expect(p.initials, 'A');
    });
  });

  group('UserProfileScreen & PersonalInformationScreen Widget Tests', () {
    testWidgets('Displays DB user name, email, username, and address',
        (tester) async {
      final fakeService = _FakeProfileService(
        storedProfile: const UserProfile(
          id: 'u-100',
          email: 'juan.delacruz@saferoute.ph',
          fullName: 'Juan Dela Cruz',
          username: 'juandc',
          address: 'IT Park, Cebu City',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            profileService: fakeService,
            authService: _FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('juan.delacruz@saferoute.ph'), findsOneWidget);
      expect(find.text('@juandc'), findsOneWidget);
      expect(find.text('IT Park, Cebu City'), findsOneWidget);
      expect(find.text('JC'), findsOneWidget);
      expect(find.text('Ma. Angelica May'), findsNothing);
    });

    testWidgets(
        'Navigating to Personal Information edits DB fields and updates Profile Screen',
        (tester) async {
      final fakeService = _FakeProfileService(
        storedProfile: const UserProfile(
          id: 'u-101',
          email: 'ana@saferoute.ph',
          fullName: 'Ana Lim',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            profileService: fakeService,
            authService: _FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Personal Information tile and tap it
      final personalInfoTile = find.text('Personal Information');
      await tester.ensureVisible(personalInfoTile);
      await tester.pumpAndSettle();
      await tester.tap(personalInfoTile);
      await tester.pumpAndSettle();

      // Verify PersonalInformationScreen opened with existing values
      expect(find.byType(PersonalInformationScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Ana Lim'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'ana@saferoute.ph'),
        findsOneWidget,
      );

      // Update fields
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ana Marie Lim'); // Full Name
      await tester.enterText(fields.at(1), 'anamarie'); // Username
      await tester.enterText(fields.at(2), 'anamarie@saferoute.ph'); // Email
      await tester.enterText(fields.at(3), '+63 917 555 1234'); // Phone
      await tester.enterText(fields.at(4), 'Banilad, Cebu City'); // Address
      await tester.enterText(fields.at(5), 'Roberto Lim'); // Emergency Name
      await tester.enterText(fields.at(6), '+63 918 555 9876'); // Emergency Tel

      final saveButton = find.text('Save Changes');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Returned to UserProfileScreen with updated DB data
      expect(fakeService.updateCallCount, 1);
      expect(fakeService.storedProfile?.phoneNumber, '+63 917 555 1234');
      expect(fakeService.storedProfile?.emergencyContactName, 'Roberto Lim');
      expect(find.text('Ana Marie Lim'), findsOneWidget);
      expect(find.text('anamarie@saferoute.ph'), findsOneWidget);
      expect(find.text('@anamarie'), findsOneWidget);
      expect(find.text('Banilad, Cebu City'), findsOneWidget);
    });

    testWidgets('PersonalInformationScreen validates invalid inputs',
        (tester) async {
      final fakeService = _FakeProfileService(
        storedProfile: const UserProfile(
          id: 'u-102',
          email: 'valid@saferoute.ph',
          fullName: 'Valid Name',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInformationScreen(
            service: fakeService,
            initialProfile: fakeService.storedProfile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), ''); // Empty full name
      await tester.enterText(fields.at(1), 'bad username!'); // Invalid username
      await tester.enterText(fields.at(2), 'not-an-email'); // Invalid email
      await tester.enterText(fields.at(3), '123'); // Too short phone

      final saveButton = find.text('Save Changes');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(fakeService.updateCallCount, 0);
      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(
        find.text('Only letters, numbers, dots, and underscores allowed'),
        findsOneWidget,
      );
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(
        find.text('Please enter a valid phone number (7–15 digits)'),
        findsOneWidget,
      );
    });

    testWidgets('Uploading and removing profile picture updates state cleanly',
        (tester) async {
      // Minimal valid 1x1 transparent PNG
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      final fakeXFile = XFile.fromData(pngBytes, name: 'photo.png');
      final fakePicker = _FakeImagePicker(fileToReturn: fakeXFile);
      final fakeService = _FakeProfileService(
        storedProfile: const UserProfile(
          id: 'u-103',
          email: 'pic@saferoute.ph',
          fullName: 'Photo Tester',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInformationScreen(
            service: fakeService,
            initialProfile: fakeService.storedProfile,
            imagePicker: fakePicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open photo options and choose from gallery
      await tester.tap(find.text('Change Profile Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(fakeService.uploadCallCount, 1);
      expect(
        fakeService.storedProfile?.avatarUrl,
        'https://example.com/avatars/avatar.png',
      );

      // Now open sheet again and remove photo
      await tester.tap(find.text('Change Profile Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Current Photo'), findsOneWidget);
      await tester.tap(find.text('Remove Current Photo'));
      await tester.pumpAndSettle();

      expect(fakeService.removeAvatarCallCount, 1);
      expect(fakeService.storedProfile?.avatarUrl, isNull);
    });
  });
}
