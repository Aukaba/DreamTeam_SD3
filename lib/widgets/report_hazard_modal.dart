import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';
import 'package:dreamteam_sd3/services/location_service.dart';
import 'package:dreamteam_sd3/widgets/camera_capture_screen.dart';
import 'package:dreamteam_sd3/widgets/interactive_location_picker.dart';

export 'package:dreamteam_sd3/services/hazard_report_service.dart'
    show HazardReportData;

/// Shared color constants used by the report hazard modal and dialog.
const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _borderGrey = Color(0xFFE2E8F0);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);

/// Shows the "Report a hazard" bottom sheet modal (used on home screen).
void showReportHazardModal(
  BuildContext context, {
  LatLng? initialLocation,
  void Function(HazardReportData report)? onReportSubmitted,
  Future<XFile?> Function(BuildContext context)? cameraLauncher,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    builder: (BuildContext modalContext) {
      final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 20.0 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Content
                ReportHazardContentWidget(
                  onClose: () => Navigator.pop(modalContext),
                  initialLocation: initialLocation,
                  onReportSubmitted: onReportSubmitted,
                  cameraLauncher: cameraLauncher,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shows the "Report a hazard" centered floating popup dialog
/// exactly as shown in the map design.
void showReportHazardDialog(
  BuildContext context, {
  LatLng? initialLocation,
  void Function(HazardReportData report)? onReportSubmitted,
  Future<XFile?> Function(BuildContext context)? cameraLauncher,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (BuildContext dialogContext) {
      final bottomInset = MediaQuery.of(dialogContext).viewInsets.bottom;
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0 + bottomInset),
            child: ReportHazardContentWidget(
              onClose: () => Navigator.pop(dialogContext),
              initialLocation: initialLocation,
              onReportSubmitted: onReportSubmitted,
              cameraLauncher: cameraLauncher,
            ),
          ),
        ),
      );
    },
  );
}

/// Shared inner content of the Report Hazard form with Gemini AI integration
/// and interactive location picker support.
class ReportHazardContentWidget extends StatefulWidget {
  final VoidCallback onClose;
  final LatLng? initialLocation;
  final void Function(HazardReportData report)? onReportSubmitted;
  final GeminiHazardService? geminiService;
  final HazardReportService? hazardReportService;
  final ImagePicker? imagePicker;
  final Future<LatLng> Function()? currentLocationResolver;
  final Future<XFile?> Function(BuildContext context)? cameraLauncher;

  const ReportHazardContentWidget({
    super.key,
    required this.onClose,
    this.initialLocation,
    this.onReportSubmitted,
    this.geminiService,
    this.hazardReportService,
    this.imagePicker,
    this.currentLocationResolver,
    this.cameraLauncher,
  });

  @override
  State<ReportHazardContentWidget> createState() =>
      _ReportHazardContentWidgetState();
}

class _ReportHazardContentWidgetState extends State<ReportHazardContentWidget> {
  late final GeminiHazardService _geminiService;
  late final HazardReportService _hazardReportService;
  late final ImagePicker _picker;

  LatLng? _selectedLocation;
  String _selectedAddress = 'Current Location';

  // Photo & AI Analysis State
  Uint8List? _selectedImageBytes;
  String? _imageFileName;
  String? _imageMimeType;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;
  int _analysisRequestId = 0;
  String? _errorMessage;
  GeminiHazardResult? _aiResult;

  // Editable Details Fields (Category & Security Level are strictly AI-evaluated)
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _geminiService = widget.geminiService ?? GeminiHazardService();
    _hazardReportService = widget.hazardReportService ?? HazardReportService();
    _picker = widget.imagePicker ?? ImagePicker();
    _selectedLocation = widget.initialLocation;
  }

  Future<LatLng> _resolveCurrentLocation() async {
    final resolver =
        widget.currentLocationResolver ?? LocationService.getCurrentLocation;
    return resolver();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _openLocationPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              'Select Hazard Location',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _primaryNavy,
              ),
            ),
            backgroundColor: Colors.white,
            foregroundColor: _primaryNavy,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: InteractiveLocationPicker(
            initialLocation: _selectedLocation,
            initialAddress: _selectedAddress != 'Current Location'
                ? _selectedAddress
                : null,
            onLocationConfirmed: (location, address) {
              setState(() {
                _selectedLocation = location;
                _selectedAddress = address;
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  static String _detectMimeType({
    required Uint8List bytes,
    String? fileName,
    String? rawMimeType,
  }) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'image/gif';
    }

    final normalizedMime = rawMimeType?.trim().toLowerCase() ?? '';
    if (normalizedMime.startsWith('image/')) {
      return normalizedMime;
    }

    final lowerName = fileName?.trim().toLowerCase() ?? '';
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _showPhotoSourceSheet() async {
    if (_isAnalyzing || _isSubmitting) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Hazard Photo',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a clear image showing the road or community hazard.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _secondaryGrey,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: _primaryNavy),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryNavy,
                    ),
                  ),
                  subtitle: const Text(
                    'Use your camera to capture the live scene',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _secondaryGrey),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _takePhotoWithCamera();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: _primaryNavy),
                  ),
                  title: const Text(
                    'Choose from Gallery / Files',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryNavy,
                    ),
                  ),
                  subtitle: const Text(
                    'Select an existing image from your device',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _secondaryGrey),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndProcessImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _takePhotoWithCamera() async {
    if (_isAnalyzing || _isSubmitting) return;
    try {
      XFile? capturedFile;

      if (widget.cameraLauncher != null) {
        capturedFile = await widget.cameraLauncher!(context);
      } else if (widget.imagePicker != null) {
        capturedFile = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
      } else {
        final result = await Navigator.of(context).push<CameraCaptureResult>(
          MaterialPageRoute(
            builder: (ctx) => const CameraCaptureScreen(
              maxWidth: 1600,
              maxHeight: 1600,
            ),
            fullscreenDialog: true,
          ),
        );

        if (!mounted || result == null) return;

        if (result.openGallery) {
          await _pickAndProcessImage(ImageSource.gallery);
          return;
        }

        capturedFile = result.file;
      }

      if (capturedFile != null && mounted) {
        await _processImageFile(capturedFile);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
          'Failed to take photo: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    if (_isAnalyzing || _isSubmitting) return;
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (file == null || !mounted) return;
      await _processImageFile(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _selectedImageBytes = null;
        _imageFileName = null;
        _imageMimeType = null;
        _aiResult = null;
        _titleController.clear();
        _descriptionController.clear();
        _errorMessage =
            'Failed to select image: ${e.toString().replaceAll('Exception: ', '')}';
      });
      _showErrorDialog(_errorMessage!);
    }
  }

  Future<void> _processImageFile(XFile file) async {
    if (!mounted || _isAnalyzing || _isSubmitting) return;

    final int requestId = ++_analysisRequestId;
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _aiResult = null;
    });

    try {
      final normalizedFile = await CameraCaptureScreen.normalizeImageFile(
        file,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || requestId != _analysisRequestId) return;

      final bytes = await normalizedFile.readAsBytes();
      if (!mounted || requestId != _analysisRequestId) return;

      final effectiveName = normalizedFile.name.trim().isNotEmpty
          ? normalizedFile.name.trim()
          : (file.name.trim().isNotEmpty ? file.name.trim() : null);

      final mimeType = _detectMimeType(
        bytes: bytes,
        fileName: effectiveName,
        rawMimeType: normalizedFile.mimeType ?? file.mimeType,
      );

      setState(() {
        _selectedImageBytes = bytes;
        _imageFileName = effectiveName;
        _imageMimeType = mimeType;
      });

      // Call Gemini 3 to analyze the hazard image
      final result = await _geminiService.analyzeHazardImage(
        imageBytes: bytes,
        mimeType: mimeType,
      );

      if (!mounted || requestId != _analysisRequestId) return;

      if (!result.isHazard) {
        // User uploaded something other than a hazard -> report error
        setState(() {
          _isAnalyzing = false;
          _selectedImageBytes = null;
          _imageFileName = null;
          _imageMimeType = null;
          _aiResult = null;
          _titleController.clear();
          _descriptionController.clear();
          _errorMessage = result.errorMessage ??
              'The uploaded image is not a recognized road or safety hazard. Please upload a photo of a hazard.';
        });
        _showNotAHazardDialog(result.errorMessage);
      } else {
        // Valid hazard detected: category & security level are locked to AI evaluation
        setState(() {
          _isAnalyzing = false;
          _aiResult = result;
          _titleController.text = result.title;
          _descriptionController.text = result.description;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted || requestId != _analysisRequestId) return;
      setState(() {
        _isAnalyzing = false;
        _selectedImageBytes = null;
        _imageFileName = null;
        _imageMimeType = null;
        _aiResult = null;
        _titleController.clear();
        _descriptionController.clear();
        _errorMessage =
            'Failed to analyze image: ${e.toString().replaceAll('Exception: ', '')}';
      });
      _showErrorDialog(_errorMessage!);
    }
  }

  void _showNotAHazardDialog(String? reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: _accentRed, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Not a Hazard',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _primaryNavy,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The uploaded photo does not appear to show a valid community or road hazard.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _primaryNavy,
              ),
            ),
            if (reason != null && reason.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: _accentRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Please provide a photo of an active hazard such as road damage, flooding, vehicle collision, fallen tree, fire, or road obstruction.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: _secondaryGrey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Dismiss',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: _secondaryGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPhotoSourceSheet();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Try Another Photo',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Analysis Error',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _primaryNavy,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _secondaryGrey,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static double? _parseCoord(dynamic value) {
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  Future<void> _submitReport() async {
    if (_selectedImageBytes == null || _aiResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please add and analyze a hazard photo before submitting.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: _primaryNavy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Snapshot all report fields before awaiting any async operations so late UI
    // mutations cannot cause the map marker to diverge from the persisted row.
    final aiEvaluation = _aiResult!;
    final submittedCategory = aiEvaluation.category;
    final submittedSecurityLevel = aiEvaluation.securityLevel;
    final submittedTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : aiEvaluation.title;
    final submittedDescription = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : aiEvaluation.description;
    final submittedAddress = _selectedAddress;
    final submittedImageBytes = Uint8List.fromList(_selectedImageBytes!);
    final submittedMimeType = _imageMimeType;
    final submittedConfidence = aiEvaluation.confidence;
    final capturedLocation = _selectedLocation;
    final submittedTimestamp = DateTime.now();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final resolvedLocation =
          capturedLocation ?? await _resolveCurrentLocation();

      // Submit to Supabase `ReportTable` and Storage bucket `hazard-reports`
      final insertedRow = await _hazardReportService.submitReport(
        category: submittedCategory,
        securityLevel: submittedSecurityLevel,
        title: submittedTitle,
        description: submittedDescription,
        locationAddress: submittedAddress,
        location: resolvedLocation,
        imageBytes: submittedImageBytes,
        confidence: submittedConfidence,
        mimeType: submittedMimeType,
      );

      final savedLat = _parseCoord(insertedRow['latitude']);
      final savedLng = _parseCoord(insertedRow['longitude']);
      final persistedLocation =
          (savedLat != null && savedLng != null)
              ? LatLng(savedLat, savedLng)
              : resolvedLocation;
      final persistedTimestamp = insertedRow['created_at'] != null
          ? (DateTime.tryParse(insertedRow['created_at'].toString())?.toLocal() ??
              submittedTimestamp)
          : submittedTimestamp;

      final persistedStatus = HazardReportStatuses.normalize(
        insertedRow['status']?.toString(),
        defaultStatus: HazardReportStatuses.pending,
      );

      final report = HazardReportData(
        reportId: insertedRow['reportID']?.toString(),
        userId: insertedRow['user_id']?.toString(),
        category: submittedCategory,
        securityLevel: submittedSecurityLevel,
        title: submittedTitle,
        description: submittedDescription,
        address: submittedAddress,
        location: persistedLocation,
        imageBytes: submittedImageBytes,
        imageUrl: insertedRow['image_url']?.toString(),
        confidence: submittedConfidence,
        status: persistedStatus,
        timestamp: persistedTimestamp,
      );

      HazardReportService.recordSubmittedReport(report);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      widget.onReportSubmitted?.call(report);

      final bool isAutoActive = report.status == HazardReportStatuses.active;
      final String snackMessage = isAutoActive
          ? '${report.category} reported and auto-verified as active! +${report.pointsAwarded} safety ${report.pointsAwarded == 1 ? 'pt' : 'pts'} earned.'
          : '${report.category} reported! Pending admin verification.';

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  snackMessage,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      _showErrorDialog(
        'Failed to submit report to Supabase: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMUNITY REPORT',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _secondaryGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Report a hazard',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _primaryNavy,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(
                Icons.close,
                color: _primaryNavy,
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Photo Upload / Status Card
        _buildPhotoSection(),

        // Error Banner if non-hazard was uploaded
        if (_errorMessage != null && !_isAnalyzing) ...[
          const SizedBox(height: 10),
          _buildErrorBanner(),
        ],

        // Gemini AI Detection Results (When photo is verified)
        if (_aiResult != null && !_isAnalyzing) ...[
          const SizedBox(height: 14),
          _buildAiResultsSection(),
        ],

        const SizedBox(height: 12),

        // "Current Location" Card (Launches InteractiveLocationPicker)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _borderGrey,
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (_isAnalyzing || _isSubmitting) ? null : _openLocationPicker,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF19456B),
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAddress,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _primaryNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tap to choose location on map',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: _secondaryGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: _secondaryGrey,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // "Submit Report" Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_isAnalyzing || _isSubmitting) ? null : _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: _isAnalyzing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Analyzing with Gemini AI...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Submitting to Supabase...',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  /// Photo selection, loading indicator, or verified preview card.
  Widget _buildPhotoSection() {
    if (_isAnalyzing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryNavy),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Analyzing photo with Gemini AI...',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _primaryNavy,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Determining hazard category and security level',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: _secondaryGrey,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedImageBytes != null && _aiResult != null) {
      // Photo successfully analyzed and verified
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderGrey, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Image.memory(
                    _selectedImageBytes!,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryNavy.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFFFDE047), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Gemini AI Verified',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _isSubmitting ? null : _showPhotoSourceSheet,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.refresh, size: 18, color: _primaryNavy),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _imageFileName ?? 'Hazard photo verified',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _showPhotoSourceSheet,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Default "Add a photo" card (matches the design in the screenshot)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _borderGrey,
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showPhotoSourceSheet,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  color: _primaryNavy,
                  size: 22,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add a photo',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Help our community understand the issue',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_upward,
                  color: _primaryNavy,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Banner displayed when user uploads a photo that is not a hazard.
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _accentRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Non-hazard image rejected',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9F1239),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Color(0xFFBE123C),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF9F1239)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// The AI Results section presenting the read-only AI-evaluated Category and Security Level,
  /// followed by user-editable Hazard Details.
  Widget _buildAiResultsSection() {
    final aiEvaluation = _aiResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hazard Category Card (Read-only, AI-evaluated)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderGrey, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HAZARD CATEGORY',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _secondaryGrey,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 11),
                        SizedBox(width: 3),
                        Text(
                          'AI Detected',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Read-only AI Category Display (non-editable by user)
              Container(
                key: const ValueKey('ai_locked_category_box'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderGrey),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        aiEvaluation.category,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                    ),
                    const Tooltip(
                      message: 'Evaluated automatically by Gemini AI',
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: _secondaryGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Security Level Card (Read-only, AI-evaluated)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderGrey, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SECURITY LEVEL',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _secondaryGrey,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 11),
                        SizedBox(width: 3),
                        Text(
                          'AI Evaluated',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Read-only Security Level Indicator: Low, Medium, High
              Row(
                key: const ValueKey('ai_locked_security_level_row'),
                children: [
                  _buildSecurityLevelIndicator(
                    'Low',
                    aiEvaluation.securityLevel,
                    const Color(0xFF3B82F6),
                    const Color(0xFFDBEAFE),
                  ),
                  const SizedBox(width: 8),
                  _buildSecurityLevelIndicator(
                    'Medium',
                    aiEvaluation.securityLevel,
                    const Color(0xFFD97706),
                    const Color(0xFFFEF3C7),
                  ),
                  const SizedBox(width: 8),
                  _buildSecurityLevelIndicator(
                    'High',
                    aiEvaluation.securityLevel,
                    const Color(0xFFEF4444),
                    const Color(0xFFFEE2E2),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Title and Description Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderGrey, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HAZARD DETAILS',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _secondaryGrey,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                readOnly: _isSubmitting,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _secondaryGrey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _borderGrey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _borderGrey),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                readOnly: _isSubmitting,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: _primaryNavy,
                ),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _secondaryGrey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _borderGrey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _borderGrey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityLevelIndicator(
    String level,
    String evaluatedLevel,
    Color activeColor,
    Color activeBg,
  ) {
    final isSelected = evaluatedLevel.toLowerCase() == level.toLowerCase();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : _borderGrey,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.lock_outline_rounded,
                size: 13,
                color: activeColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              level,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : _secondaryGrey.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
