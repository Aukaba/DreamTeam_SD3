import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// The result returned when closing the camera capture screen.
class CameraCaptureResult {
  /// The photo captured by the camera.
  final XFile? file;

  /// True if the user elected to open gallery/files instead (e.g. if camera is unavailable).
  final bool openGallery;

  const CameraCaptureResult({
    this.file,
    this.openGallery = false,
  });
}

/// A full camera capture screen that interfaces directly with the device's
/// webcam / physical camera using [package:camera].
class CameraCaptureScreen extends StatefulWidget {
  /// Optional pre-supplied camera list (helpful for testing or injection).
  final List<CameraDescription>? cameras;

  const CameraCaptureScreen({
    super.key,
    this.cameras,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  CameraController? _controller;

  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  XFile? _capturedPhoto;
  Uint8List? _capturedBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameras.isNotEmpty) {
        _initCameraController(_cameras[_selectedCameraIndex]);
      }
    }
  }

  Future<void> _initializeCameras() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final cameras = widget.cameras ?? await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'No active camera or webcam was found on this device. Please connect a camera or choose a photo from your files.';
        });
        return;
      }

      _cameras = cameras;

      // Prefer back camera on mobile; default to first camera on desktop/web
      int initialIndex = 0;
      for (int i = 0; i < cameras.length; i++) {
        if (cameras[i].lensDirection == CameraLensDirection.back) {
          initialIndex = i;
          break;
        }
      }
      _selectedCameraIndex = initialIndex;

      await _initCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Unable to access camera: ${e.toString().replaceAll('Exception: ', '')}.\n'
            'Please ensure camera permissions are allowed in your system/browser settings.';
      });
    }
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final oldController = _controller;
    if (oldController != null) {
      _controller = null;
      await oldController.dispose();
    }

    final newController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = newController;

    try {
      await newController.initialize();
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Camera initialization failed: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1 || _isCapturing) return;

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _selectedCameraIndex = nextIndex;
      _isInitializing = true;
    });

    await _initCameraController(_cameras[nextIndex]);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing) {
      return;
    }

    try {
      setState(() {
        _isCapturing = true;
      });

      final XFile photo = await controller.takePicture();
      final Uint8List bytes = await photo.readAsBytes();

      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _capturedPhoto = photo;
        _capturedBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture photo: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedPhoto = null;
      _capturedBytes = null;
    });
  }

  void _usePhoto() {
    if (_capturedPhoto != null) {
      Navigator.pop(
        context,
        CameraCaptureResult(file: _capturedPhoto),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Camera preview or Captured photo or Loading / Error
            _buildMainContent(),

            // 2. Flash effect during capture
            if (_isCapturing)
              Container(
                color: Colors.white.withValues(alpha: 0.6),
              ),

            // 3. Top bar (Close, camera switch)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildTopBar(),
            ),

            // 4. Bottom action bar (Shutter button or Retake / Confirm)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_capturedBytes != null) {
      // Photo preview review mode
      return Center(
        child: Image.memory(
          _capturedBytes!,
          fit: BoxFit.contain,
        ),
      );
    }

    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Connecting to camera...',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _buildErrorView();
    }

    // Active live camera viewfinder
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        double aspectRatio = controller.value.aspectRatio;

        // When in portrait on mobile, aspect ratio might need inverting
        if (previewSize != null &&
            constraints.maxHeight > constraints.maxWidth &&
            aspectRatio > 1.0) {
          aspectRatio = 1.0 / aspectRatio;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: CameraPreview(controller),
              ),
            ),

            // Hazard framing guide overlay
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.center_focus_strong,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Align hazard within view',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close button
        IconButton(
          tooltip: 'Close',
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(10),
          ),
          icon: const Icon(Icons.close, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),

        // Title if in review mode
        if (_capturedBytes != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Review Photo',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),

        // Switch camera button
        if (_capturedBytes == null && _cameras.length > 1)
          IconButton(
            tooltip: 'Switch Camera',
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(10),
            ),
            icon: const Icon(Icons.flip_camera_ios_outlined,
                color: Colors.white, size: 22),
            onPressed: _switchCamera,
          )
        else if (_capturedBytes == null)
          const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_errorMessage != null) {
      return const SizedBox.shrink();
    }

    if (_capturedBytes != null) {
      // Retake and Use Photo actions
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.black.withValues(alpha: 0.4),
              ),
              onPressed: _retakePhoto,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(
                'Retake',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _usePhoto,
              icon: const Icon(Icons.check, size: 20),
              label: const Text(
                'Use Photo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Shutter capture button bar
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Gallery shortcut button
        IconButton(
          tooltip: 'Choose from Files',
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(Icons.photo_library_outlined,
              color: Colors.white, size: 24),
          onPressed: () {
            Navigator.pop(
              context,
              const CameraCaptureResult(openGallery: true),
            );
          },
        ),

        // Shutter Button
        GestureDetector(
          onTap: _takePicture,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),

        // Placeholder spacer to keep shutter centered
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Camera Not Available',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ??
                  'No camera was found on your device or access was not granted.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  const CameraCaptureResult(openGallery: true),
                );
              },
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text(
                'Choose from Gallery / Files',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

