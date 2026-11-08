import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dreamteam_sd3/Authentication/auth_service.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';
import 'package:dreamteam_sd3/services/profile_service.dart';
import 'package:dreamteam_sd3/user_screens/personal_information_screen.dart';
import 'package:dreamteam_sd3/user_screens/user_profile_screen.dart';
import 'package:dreamteam_sd3/widgets/camera_capture_screen.dart';
import 'package:dreamteam_sd3/widgets/report_hazard_modal.dart';

final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class FakeGeminiHazardService extends GeminiHazardService {
  final GeminiHazardResult returnResult;
  Uint8List? lastAnalyzedBytes;
  int analyzeCallCount = 0;

  FakeGeminiHazardService(this.returnResult) : super(apiKey: 'fake_key');

  @override
  Future<GeminiHazardResult> analyzeHazardImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    analyzeCallCount++;
    lastAnalyzedBytes = imageBytes;
    return returnResult;
  }
}

class _FakeImagePicker extends ImagePicker {
  final XFile? fileToReturn;
  ImageSource? lastRequestedSource;
  int pickCallCount = 0;

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
    pickCallCount++;
    lastRequestedSource = source;
    return fileToReturn;
  }
}

class _FakeProfileService extends ProfileService {
  UserProfile storedProfile;
  Uint8List? lastUploadedBytes;
  int uploadCallCount = 0;

  _FakeProfileService(this.storedProfile);

  @override
  Future<UserProfile?> getProfile() async => storedProfile;

  @override
  Future<UserProfile> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (bytes.lengthInBytes > ProfileService.maxAvatarBytes) {
      throw Exception('Profile picture must be smaller than 5 MB.');
    }
    uploadCallCount++;
    lastUploadedBytes = bytes;
    storedProfile =
        storedProfile.copyWith(avatarUrl: 'https://example.com/avatar.png');
    return storedProfile;
  }
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> signOut() async {}
}

class _DelayedXFile extends XFile {
  final Completer<Uint8List> bytesCompleter;
  final String _fileName;

  _DelayedXFile(this.bytesCompleter, {required String name})
      : _fileName = name,
        super.fromData(_validPngBytes, name: name, mimeType: 'image/png');

  @override
  String get name => _fileName;

  @override
  Future<Uint8List> readAsBytes() => bytesCompleter.future;
}

class _ControllableFakeCameraController extends ValueNotifier<CameraValue>
    implements CameraController {
  @override
  final CameraDescription description;

  @override
  final ResolutionPreset resolutionPreset;

  @override
  final bool enableAudio = false;

  @override
  final ImageFormatGroup? imageFormatGroup = null;

  final Completer<void>? initializeCompleter;
  final XFile photoToCapture;
  bool isDisposed = false;
  int initializeCallCount = 0;
  int disposeCallCount = 0;
  int takePictureCallCount = 0;

  _ControllableFakeCameraController({
    required this.description,
    required this.resolutionPreset,
    required this.photoToCapture,
    this.initializeCompleter,
  }) : super(CameraValue.uninitialized(description));

  @override
  Future<void> initialize() async {
    initializeCallCount++;
    if (initializeCompleter != null) {
      await initializeCompleter!.future;
    }
    if (isDisposed) return;
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1280, 720),
    );
  }

  @override
  Future<XFile> takePicture() async {
    takePictureCallCount++;
    return photoToCapture;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    isDisposed = true;
    super.dispose();
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black26);

  @override
  int get cameraId => 1;

  @override
  void debugCheckIsDisposed() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CameraCaptureScreen Widget Tests', () {
    testWidgets('CameraCaptureScreen shows error view when camera list is empty',
        (tester) async {
      CameraCaptureResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<CameraCaptureResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CameraCaptureScreen(cameras: []),
                    ),
                  );
                },
                child: const Text('Open Camera'),
              ),
            ),
          ),
        ),
      );

      // Open camera screen
      await tester.tap(find.text('Open Camera'));
      await tester.pumpAndSettle();

      // Verify empty cameras state UI
      expect(find.text('Camera Not Available'), findsOneWidget);
      expect(
        find.textContaining('No active camera or webcam was found on this device'),
        findsOneWidget,
      );
      expect(find.text('Choose from Gallery / Files'), findsOneWidget);

      // Tapping "Choose from Gallery / Files" should pop with openGallery = true
      await tester.tap(find.text('Choose from Gallery / Files'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.openGallery, isTrue);
      expect(result!.file, isNull);
    });

    testWidgets('CameraCaptureScreen cancel button pops screen without result',
        (tester) async {
      CameraCaptureResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<CameraCaptureResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CameraCaptureScreen(cameras: []),
                    ),
                  );
                },
                child: const Text('Open Camera'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Camera'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets(
        'Comments 3 & 5: Prevents rapid camera switches during initialization and stops camera during review until Retake',
        (tester) async {
      const backCam = CameraDescription(
        name: 'back_cam',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );
      const frontCam = CameraDescription(
        name: 'front_cam',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      );

      final createdControllers = <_ControllableFakeCameraController>[];
      Completer<void>? nextInitCompleter;

      final fakePhoto = XFile.fromData(
        _validPngBytes,
        name: 'captured.png',
        mimeType: 'image/png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CameraCaptureScreen(
            cameras: const [backCam, frontCam],
            controllerBuilder: (desc, preset) {
              final ctrl = _ControllableFakeCameraController(
                description: desc,
                resolutionPreset: preset,
                photoToCapture: fakePhoto,
                initializeCompleter: nextInitCompleter,
              );
              createdControllers.add(ctrl);
              return ctrl;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially back camera is initialized once
      expect(createdControllers.length, 1);
      expect(createdControllers.first.description.name, 'back_cam');
      expect(createdControllers.first.isDisposed, isFalse);

      // Prepare slow initialization for front camera switch
      nextInitCompleter = Completer<void>();

      final switchBtn = find.byTooltip('Switch Camera');
      expect(switchBtn, findsOneWidget);

      // Tap switch camera rapidly multiple times while initialization is pending
      await tester.tap(switchBtn);
      await tester.pump();
      await tester.tap(switchBtn, warnIfMissed: false);
      await tester.pump();

      // Only one switch initialization should be started
      expect(createdControllers.length, 2);
      expect(createdControllers[1].description.name, 'front_cam');

      // Complete front camera initialization
      nextInitCompleter.complete();
      nextInitCompleter = null;
      await tester.pumpAndSettle();

      // Capture photo (shutter button is the GestureDetector in the bottom bar)
      final shutterFinder = find
          .descendant(
            of: find.byType(CameraCaptureScreen),
            matching: find.byType(GestureDetector),
          )
          .last;
      await tester.tap(shutterFinder);
      await tester.pumpAndSettle();

      // Verify review mode is shown and the active camera controller was stopped/disposed! (Comment 5)
      expect(find.text('Review Photo'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      expect(createdControllers[1].isDisposed, isTrue);

      // Tapping Retake reinitializes the camera controller
      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();

      expect(createdControllers.length, 3);
      expect(createdControllers[2].description.name, 'front_cam');
      expect(createdControllers[2].isDisposed, isFalse);
    });
  });

  group('Comments 1, 2, 4: Normalization, Injected Pickers, and Analysis Slot Guard', () {
    test('Comment 1: normalizeImageFile clamps oversized camera captures within maxBytes',
        () async {
      // Create a 6 MiB payload (exceeding ProfileService.maxAvatarBytes = 5 MiB)
      final oversizedBytes = Uint8List(6 * 1024 * 1024);
      final oversizedFile = XFile.fromData(
        oversizedBytes,
        name: 'oversized_camera.jpg',
        mimeType: 'image/jpeg',
      );

      final normalized = await CameraCaptureScreen.normalizeImageFile(
        oversizedFile,
        maxWidth: 1024,
        maxHeight: 1024,
        maxBytes: ProfileService.maxAvatarBytes,
      );
      final resultBytes = await normalized.readAsBytes();

      expect(
        resultBytes.lengthInBytes,
        lessThanOrEqualTo(ProfileService.maxAvatarBytes),
      );
    });

    testWidgets(
        'Comment 2: Injected ImagePicker handles camera selection in ReportHazardContentWidget, UserProfileScreen, and PersonalInformationScreen',
        (tester) async {
      final fakeCameraFile = XFile.fromData(
        _validPngBytes,
        name: 'injected_cam.png',
        mimeType: 'image/png',
      );

      // 1. ReportHazardContentWidget with injected imagePicker
      final reportPicker = _FakeImagePicker(fileToReturn: fakeCameraFile);
      final fakeGemini = FakeGeminiHazardService(
        const GeminiHazardResult(
          isHazard: true,
          category: HazardCategories.roadDamage,
          securityLevel: HazardSecurityLevels.high,
          confidence: 95,
          title: 'Camera Hazard',
          description: 'Captured via injected ImagePicker.',
          modelUsed: 'gemini-3-flash-preview',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportHazardContentWidget(
                onClose: () {},
                imagePicker: reportPicker,
                geminiService: fakeGemini,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a Photo'));
      await tester.pumpAndSettle();

      expect(reportPicker.pickCallCount, 1);
      expect(reportPicker.lastRequestedSource, ImageSource.camera);
      expect(find.text('Camera Hazard'), findsOneWidget);

      // 2. UserProfileScreen with injected imagePicker + oversized camera capture (Comments 1 & 2)
      final oversizedCameraFile = XFile.fromData(
        Uint8List(6 * 1024 * 1024),
        name: 'big_camera.jpg',
        mimeType: 'image/jpeg',
      );
      final profilePicker = _FakeImagePicker(fileToReturn: oversizedCameraFile);
      final profileService = _FakeProfileService(
        const UserProfile(
          id: 'u-1',
          email: 'user@saferoute.ph',
          fullName: 'SafeRoute User',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            profileService: profileService,
            authService: _FakeAuthService(),
            imagePicker: profilePicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a Photo'));
      await tester.pumpAndSettle();

      expect(profilePicker.pickCallCount, 1);
      expect(profilePicker.lastRequestedSource, ImageSource.camera);
      expect(profileService.uploadCallCount, 1);
      expect(
        profileService.lastUploadedBytes!.lengthInBytes,
        lessThanOrEqualTo(ProfileService.maxAvatarBytes),
      );

      // 3. PersonalInformationScreen with injected imagePicker + oversized camera capture (Comments 1 & 2)
      final personalPicker = _FakeImagePicker(fileToReturn: oversizedCameraFile);
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalInformationScreen(
            service: profileService,
            initialProfile: profileService.storedProfile,
            imagePicker: personalPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('personal_info_avatar_tap')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a Photo'));
      await tester.pumpAndSettle();

      expect(personalPicker.pickCallCount, 1);
      expect(personalPicker.lastRequestedSource, ImageSource.camera);
      expect(profileService.uploadCallCount, 2);
    });

    testWidgets(
        'Comment 4: _processImageFile reserves analysis slot before readAsBytes completes to prevent overlapping image analysis',
        (tester) async {
      final firstReadCompleter = Completer<Uint8List>();
      final firstFile = _DelayedXFile(firstReadCompleter, name: 'first.png');
      final secondFile = XFile.fromData(
        _validPngBytes,
        name: 'second.png',
        mimeType: 'image/png',
      );

      int launchCount = 0;
      final fakeGemini = FakeGeminiHazardService(
        const GeminiHazardResult(
          isHazard: true,
          category: HazardCategories.flood,
          securityLevel: HazardSecurityLevels.medium,
          confidence: 92,
          title: 'First Flood Photo',
          description: 'Flooded street.',
          modelUsed: 'gemini-3-flash-preview',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportHazardContentWidget(
                onClose: () {},
                geminiService: fakeGemini,
                cameraLauncher: (ctx) async {
                  launchCount++;
                  return launchCount == 1 ? firstFile : secondFile;
                },
              ),
            ),
          ),
        ),
      );

      // Trigger first camera capture whose readAsBytes is still pending
      await tester.tap(find.text('Add a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a Photo'));
      // Wait for the bottom sheet close animation and cameraLauncher microtask
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify _isAnalyzing was reserved immediately BEFORE firstFile.readAsBytes() completed!
      expect(find.text('Analyzing photo with Gemini AI...'), findsOneWidget);
      expect(launchCount, 1);

      // Now complete first file's readAsBytes
      firstReadCompleter.complete(_validPngBytes);
      await tester.pumpAndSettle();

      expect(fakeGemini.analyzeCallCount, 1);
      expect(find.text('First Flood Photo'), findsOneWidget);
      expect(find.text('first.png'), findsOneWidget);
    });
  });
}
