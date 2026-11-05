import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamteam_sd3/services/location_service.dart';
import 'package:dreamteam_sd3/widgets/interactive_location_picker.dart';

/// Shared color constants used by the report hazard modal and dialog.
const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);

/// Hazard categories available for selection.
const List<Map<String, String>> _hazardCategories = [
  {'emoji': '🌊', 'label': 'Flood'},
  {'emoji': '🚧', 'label': 'Road damage'},
  {'emoji': '🚗', 'label': 'Accident'},
  {'emoji': '🌳', 'label': 'Fallen tree'},
  {'emoji': '🔥', 'label': 'Fire'},
  {'emoji': '💡', 'label': 'Broken streetlight'},
  {'emoji': '🚫', 'label': 'Blocked road'},
  {'emoji': '⚠️', 'label': 'Other'},
];

/// Severity levels available for selection.
const List<String> _severityLevels = ['Low', 'Medium', 'High', 'Critical'];

const String _geminiPrompt = '''
You are a hazard detection AI for a community safety app.
Analyze this image and respond with ONLY a JSON object (no markdown, no code fences) using this exact format:
{
  "is_hazard": <true or false>,
  "detected_hazard": "<short descriptive name of what is seen>",
  "hazard_category": "<one of: Flood, Road damage, Accident, Fallen tree, Fire, Broken streetlight, Blocked road, Other>",
  "severity_level": "<one of: Low, Medium, High, Critical>",
  "confidence": <integer 0-100>
}

Rules:
- is_hazard: true ONLY if the image shows a real-world public safety or road hazard (e.g. flood, accident, fire, fallen tree, road damage, broken streetlight, blocked road). Set false for animals, people, food, selfies, nature scenery, objects, or anything unrelated to a public hazard.
- detected_hazard: concise phrase describing what is seen (e.g. "Flooded road", "Car accident", "Clear Roadway")
- hazard_category: pick the best match from the list above (only relevant when is_hazard is true)
- severity_level: Low = minor inconvenience, Medium = affects traffic/community, High = dangerous/urgent, Critical = life-threatening
- confidence: your confidence percentage as an integer
''';

/// Shows the "Report a hazard" bottom sheet modal (used on home screen).
void showReportHazardModal(
  BuildContext context, {
  VoidCallback? onReportSubmitted,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    builder: (BuildContext modalContext) {
      final double maxHeight =
          MediaQuery.of(modalContext).size.height * 0.88;

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20.0,
            12.0,
            20.0,
            MediaQuery.of(modalContext).viewInsets.bottom + 20.0,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
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
                Flexible(
                  child: ReportHazardContentWidget(
                    onClose: () => Navigator.pop(modalContext),
                    onReportSubmitted: onReportSubmitted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shows the "Report a hazard" centered floating popup dialog.
void showReportHazardDialog(
  BuildContext context, {
  VoidCallback? onReportSubmitted,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (BuildContext dialogContext) {
      final double maxHeight =
          MediaQuery.of(dialogContext).size.height * 0.85;

      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ReportHazardContentWidget(
              onClose: () => Navigator.pop(dialogContext),
              onReportSubmitted: onReportSubmitted,
            ),
          ),
        ),
      );
    },
  );
}

/// Shared inner content of the Report Hazard form with AI image analysis.
class ReportHazardContentWidget extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onReportSubmitted;

  const ReportHazardContentWidget({
    super.key,
    required this.onClose,
    this.onReportSubmitted,
  });

  @override
  State<ReportHazardContentWidget> createState() =>
      _ReportHazardContentWidgetState();
}

class _ReportHazardContentWidgetState
    extends State<ReportHazardContentWidget> {
  // Location state
  LatLng? _selectedLocation;
  String _selectedAddress = 'Current Location';

  // Photo state
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // AI analysis state
  bool _isAnalyzing = false;
  int _analysisRequestId = 0;
  String? _detectedHazard;
  String? _selectedCategory;
  String _selectedSeverity = 'Low';
  int? _confidencePercent;
  String? _analysisError;

  // Form submission state & stable draft idempotency key
  bool _isSubmitting = false;
  String? _draftReportId;
  late final TextEditingController _detectedHazardController;

  @override
  void initState() {
    super.initState();
    _detectedHazardController = TextEditingController();
    _initDeviceLocation();
  }

  @override
  void dispose() {
    _detectedHazardController.dispose();
    super.dispose();
  }

  /// Automatically fetches current location to prevent null coordinates on submit.
  Future<void> _initDeviceLocation() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _selectedLocation = loc;
      });
    } catch (e) {
      debugPrint('Could not initialize current location: $e');
    }
  }

  /// RFC-4122 v4 UUID generator for unique report IDs without external packages.
  String _generateReportId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ── Photo Selection (Camera & Gallery) ───────────────────────────────────────

  void _showImageSourcePicker() {
    if (_isSubmitting) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext pickerContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const Text(
                  'Select Photo Source',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0F4FF),
                    child: Icon(Icons.camera_alt_outlined, color: _primaryNavy),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _primaryNavy,
                    ),
                  ),
                  subtitle: const Text(
                    'Use device camera to capture hazard',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _secondaryGrey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(pickerContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0F4FF),
                    child: Icon(Icons.photo_library_outlined, color: _primaryNavy),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _primaryNavy,
                    ),
                  ),
                  subtitle: const Text(
                    'Select an existing image from your device',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _secondaryGrey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(pickerContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      final currentRequestId = ++_analysisRequestId;

      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
        _isAnalyzing = true;
        _detectedHazard = null;
        _detectedHazardController.clear();
        _selectedCategory = null;
        _confidencePercent = null;
        _analysisError = null;
      });

      await _analyzeImageWithGemini(bytes, image.name, currentRequestId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisError = 'Unable to select or read photo: ${e.toString()}';
      });
    }
  }

  // ── Gemini Analysis (Server-side Edge Function first, client fallback) ──────

  Future<void> _analyzeImageWithGemini(
    Uint8List imageBytes,
    String fileName,
    int requestId,
  ) async {
    try {
      final mimeType = fileName.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      String? responseText;

      // 1. Attempt server-side edge function first to keep API key off client
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'analyze-hazard',
          body: {
            'imageBase64': base64Encode(imageBytes),
            'mimeType': mimeType,
          },
        );
        if (res.status == 200 && res.data != null) {
          responseText = res.data is String
              ? res.data as String
              : jsonEncode(res.data);
        }
      } catch (funcError) {
        debugPrint(
            'Server-side analyze endpoint unavailable, checking local key: $funcError');
      }

      // 2. Fall back to direct Gemini client if server function is not deployed
      if (responseText == null) {
        final apiKey = dotenv.env['GEMINI_API_KEY'];
        if (apiKey == null || apiKey.isEmpty) {
          if (!mounted) return;
          if (requestId != _analysisRequestId) return;
          setState(() {
            _isAnalyzing = false;
            _analysisError =
                'GEMINI_API_KEY is not configured in .env. Please see .env.example for setup instructions.';
          });
          return;
        }

        // Exclusively Gemini 3 and above models
        const gemini3Models = [
          'gemini-3.8-flash',
          'gemini-3-flash-preview',
          'gemini-3-flash',
          'gemini-3.6-flash',
          'gemini-3.8-pro',
        ];

        dynamic lastError;
        for (final modelName in gemini3Models) {
          int retries = 2;
          while (retries > 0) {
            try {
              debugPrint('Attempting AI analysis with model: $modelName');
              final model = GenerativeModel(
                model: modelName,
                apiKey: apiKey,
              );

              final response = await model.generateContent([
                Content.multi([
                  TextPart(_geminiPrompt),
                  DataPart(mimeType, imageBytes),
                ]),
              ]);

              if (response.text != null && response.text!.isNotEmpty) {
                responseText = response.text;
                break;
              }
            } catch (modelErr) {
              lastError = modelErr;
              final is503 = modelErr.toString().contains('503') ||
                  modelErr.toString().toLowerCase().contains('high demand');
              if (is503 && retries > 1) {
                retries--;
                debugPrint('Model $modelName 503 spike. Retrying in 1.5s...');
                await Future.delayed(const Duration(milliseconds: 1500));
                continue;
              }
              debugPrint('Model $modelName error: $modelErr. Trying next Gemini 3 model...');
              break;
            }
          }
          if (responseText != null) break;
        }

        if (responseText == null) {
          throw lastError ?? Exception('All Gemini 3 candidate models failed');
        }
      }

      if (responseText.isEmpty) {
        throw Exception('Received empty response from AI analysis');
      }

      if (!mounted) return;
      _parseGeminiResponse(responseText, requestId);
    } catch (e) {
      if (!mounted) return;
      if (requestId != _analysisRequestId) return;
      final isHighDemand = e.toString().contains('503') ||
          e.toString().toLowerCase().contains('high demand') ||
          e.toString().toLowerCase().contains('unavailable');

      setState(() {
        _isAnalyzing = false;
        if (isHighDemand) {
          // Graceful degradation: unlock manual inputs so the user is never blocked
          _detectedHazard ??= '';
          _detectedHazardController.text = _detectedHazard!;
          _selectedCategory ??= 'Other';
          _analysisError =
              '⚠️ AI analysis is temporarily busy due to high demand. You can fill in the hazard details manually below and submit your report.';
        } else {
          _analysisError = 'AI analysis failed: ${e.toString()}';
        }
      });
    }
  }

  void _parseGeminiResponse(String text, int requestId) {
    if (requestId != _analysisRequestId) return;

    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) {
        if (!mounted) return;
        setState(() {
          _isAnalyzing = false;
          _analysisError = 'Unable to parse AI response. Please try again.';
        });
        return;
      }

      final Map<String, dynamic> data =
          jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      // If is_hazard boolean is missing or invalid, report parse error without clearing photo
      if (!data.containsKey('is_hazard') || data['is_hazard'] is! bool) {
        if (!mounted) return;
        setState(() {
          _isAnalyzing = false;
          _analysisError =
              'AI could not verify if the photo shows a hazard. Please try again.';
        });
        return;
      }

      final bool isHazard = data['is_hazard'] as bool;

      // Confirmed non-hazard image: clear photo and show rejection warning
      if (!isHazard) {
        if (!mounted) return;
        setState(() {
          _isAnalyzing = false;
          _selectedImage = null;
          _imageBytes = null;
          _detectedHazard = null;
          _detectedHazardController.clear();
          _analysisError =
              '⚠️ This photo doesn\'t appear to show a public hazard. '
              'Please upload an image of a flood, accident, road damage, '
              'fire, fallen tree, or similar hazard.';
        });
        return;
      }

      final String hazard = (data['detected_hazard'] ?? '').toString().trim();
      final String category = (data['hazard_category'] ?? '').toString().trim();
      final String severity = (data['severity_level'] ?? '').toString().trim();
      final int confidence = (data['confidence'] is num)
          ? (data['confidence'] as num).toInt()
          : (int.tryParse(data['confidence']?.toString() ?? '') ?? 0);

      final validCategories =
          _hazardCategories.map((c) => c['label']!).toList();
      final resolvedCategory =
          validCategories.contains(category) ? category : 'Other';

      final resolvedSeverity =
          _severityLevels.contains(severity) ? severity : 'Low';

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _detectedHazard = hazard.isNotEmpty ? hazard : 'Hazard detected';
        _detectedHazardController.text = _detectedHazard!;
        _selectedCategory = resolvedCategory;
        _selectedSeverity = resolvedSeverity;
        _confidencePercent = confidence.clamp(0, 100);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisError = 'Could not parse AI response: ${e.toString()}';
      });
    }
  }

  // ── Location Picker ─────────────────────────────────────────────────────────

  void _openLocationPicker() {
    if (_isSubmitting) return;

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
            initialAddress:
                _selectedAddress != 'Current Location' ? _selectedAddress : null,
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

  // ── Submit Hazard Report ───────────────────────────────────────────────────

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    if (_detectedHazard == null && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add and analyze a photo of a hazard before submitting.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Ensure valid coordinates exist
    if (_selectedLocation == null) {
      try {
        _selectedLocation = await LocationService.getCurrentLocation();
      } catch (_) {}
    }

    if (!mounted) return;

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location is required. Please tap "Current Location" to choose a point on the map.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Snapshot all fields before entering async awaits to prevent drift
    final String reportId = _draftReportId ??= _generateReportId();
    final Uint8List? snapshotBytes = _imageBytes;
    final String snapshotFileName = _selectedImage?.name ?? 'photo.jpg';
    final String snapshotCategory = _selectedCategory ?? 'Other';
    final String snapshotHazardDesc =
        _detectedHazardController.text.trim().isNotEmpty
            ? _detectedHazardController.text.trim()
            : (_detectedHazard ?? 'Hazard detected');
    final String snapshotSeverity = _selectedSeverity;
    final int? snapshotConfidence = _confidencePercent;
    final String snapshotAddress = _selectedAddress != 'Current Location'
        ? _selectedAddress
        : 'Current Location';
    final LatLng snapshotLocation = _selectedLocation!;

    setState(() {
      _isSubmitting = true;
    });

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    String? uploadedFileName;
    String? imageUrl;

    try {
      // 1. Upload photo if present — fail early if upload fails to prevent losing photo
      if (snapshotBytes != null) {
        final ext =
            snapshotFileName.split('.').last.toLowerCase();
        final safeExt = (ext == 'png') ? 'png' : 'jpg';
        final fileName = '$reportId.$safeExt';
        final mimeType = safeExt == 'png' ? 'image/png' : 'image/jpeg';

        try {
          await supabase.storage.from('hazard-reports').uploadBinary(
                fileName,
                snapshotBytes,
                fileOptions: FileOptions(contentType: mimeType, upsert: true),
              );
          uploadedFileName = fileName;
          imageUrl = supabase.storage
              .from('hazard-reports')
              .getPublicUrl(fileName);
        } catch (uploadErr) {
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload hazard photo: $uploadErr. Report was not submitted.',
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      // 2. Insert/upsert into ReportTable using stable reportID idempotency key
      await supabase.from('ReportTable').upsert({
        'reportID': reportId,
        'user_id': user?.id,
        'hazard_category': snapshotCategory,
        'detected_hazard': snapshotHazardDesc,
        'severity_level': snapshotSeverity,
        'confidence': snapshotConfidence,
        'location_address': snapshotAddress,
        'latitude': snapshotLocation.latitude,
        'longitude': snapshotLocation.longitude,
        'image_url': imageUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'reportID');

      if (!mounted) return;

      // Reset draft key on successful submission
      _draftReportId = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hazard report submitted successfully!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Notify caller to reload reports (e.g. MapScreen)
      widget.onReportSubmitted?.call();
      widget.onClose();
    } catch (e) {
      // 3. Clean up uploaded storage object if database insert fails
      if (uploadedFileName != null) {
        try {
          await supabase.storage
              .from('hazard-reports')
              .remove([uploadedFileName]);
        } catch (cleanErr) {
          debugPrint('Could not clean up uploaded photo on error: $cleanErr');
        }
      }

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit report: ${e.toString()}',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build Helpers ────────────────────────────────────────────────────────────

  String _categoryDisplay(String label) {
    final cat = _hazardCategories.firstWhere(
      (c) => c['label'] == label,
      orElse: () => {'emoji': '⚠️', 'label': label},
    );
    return '${cat['emoji']} ${cat['label']}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                onPressed: _isSubmitting ? null : widget.onClose,
                icon: const Icon(Icons.close, color: _primaryNavy, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Photo Card
          _buildPhotoCard(),

          const SizedBox(height: 12),

          // AI Analysis Result / Loading / Error
          if (_isAnalyzing) _buildAnalyzingCard(),
          if (!_isAnalyzing && _detectedHazard != null) _buildAiResultCard(),
          if (!_isAnalyzing && _analysisError != null) _buildErrorCard(),

          if (_detectedHazard != null || _analysisError != null)
            const SizedBox(height: 12),

          // Location Card
          _buildLocationCard(),

          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryNavy,
                disabledBackgroundColor: _primaryNavy.withValues(alpha: 0.6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
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
      ),
    );
  }

  // ── Photo Card Widget ───────────────────────────────────────────────────────

  Widget _buildPhotoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting ? null : _showImageSourcePicker,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                if (_selectedImage != null && _imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _imageBytes!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Icon(Icons.add_a_photo_outlined,
                      color: _primaryNavy, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedImage != null ? 'Change photo' : 'Add a photo',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedImage != null
                            ? 'Tap to retake or change'
                            : 'Camera or gallery photo of the hazard',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_upward, color: _primaryNavy, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Analyzing Spinner Card ─────────────────────────────────────────────────

  Widget _buildAnalyzingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0DAFB), width: 1.2),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Analyzing image with Gemini AI…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Result Card ─────────────────────────────────────────────────────────

  Widget _buildAiResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF5B6EF5), size: 16),
              const SizedBox(width: 6),
              const Text(
                'AI Analysis Result',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
              const Spacer(),
              if (_confidencePercent != null)
                Text(
                  'Confidence: $_confidencePercent%',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B6EF5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Detected Hazard field
          const Text(
            'Detected Hazard',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _secondaryGrey,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
            ),
            child: TextField(
              controller: _detectedHazardController,
              enabled: !_isSubmitting,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _primaryNavy,
              ),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Hazard Category dropdown
          const Text(
            'Hazard Category',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _secondaryGrey,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
            ),
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: _secondaryGrey),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _primaryNavy,
              ),
              items: _hazardCategories.map((cat) {
                final label = cat['label']!;
                return DropdownMenuItem<String>(
                  value: label,
                  child: Text('${cat['emoji']} $label'),
                );
              }).toList(),
              onChanged: _isSubmitting
                  ? null
                  : (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
              selectedItemBuilder: (context) {
                return _hazardCategories.map((cat) {
                  final label = cat['label']!;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _categoryDisplay(label),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _primaryNavy,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ),
          const SizedBox(height: 14),

          // Severity Level buttons
          const Text(
            'Severity Level',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _secondaryGrey,
            ),
          ),
          const SizedBox(height: 8),
          _buildSeveritySelector(),

          const SizedBox(height: 10),
          const Text(
            'You can confirm or adjust the AI detected values above.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: _secondaryGrey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── Severity Selector ───────────────────────────────────────────────────────

  Widget _buildSeveritySelector() {
    return Row(
      children: _severityLevels.map((level) {
        final isSelected = _selectedSeverity == level;

        Color bgColor = Colors.white;
        Color textColor = _primaryNavy;
        Color borderColor = const Color(0xFFD1D5DB);

        if (isSelected) {
          switch (level) {
            case 'Low':
              bgColor = const Color(0xFFD1FAE5);
              textColor = const Color(0xFF065F46);
              borderColor = const Color(0xFF6EE7B7);
              break;
            case 'Medium':
              bgColor = const Color(0xFFFEF3C7);
              textColor = const Color(0xFF92400E);
              borderColor = const Color(0xFFFCD34D);
              break;
            case 'High':
              bgColor = const Color(0xFFFFEDD5);
              textColor = const Color(0xFF9A3412);
              borderColor = const Color(0xFFFDBA74);
              break;
            case 'Critical':
              bgColor = const Color(0xFFFEE2E2);
              textColor = const Color(0xFF991B1B);
              borderColor = const Color(0xFFFCA5A5);
              break;
          }
        }

        return Expanded(
          child: GestureDetector(
            onTap: _isSubmitting
                ? null
                : () => setState(() => _selectedSeverity = level),
            child: Container(
              margin: EdgeInsets.only(
                right: level != _severityLevels.last ? 6 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                level,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Error Card Widget ──────────────────────────────────────────────────────

  Widget _buildErrorCard() {
    final isRejection = _analysisError?.startsWith('⚠️') ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRejection ? const Color(0xFFFFF7ED) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRejection ? const Color(0xFFFDBA74) : const Color(0xFFFCA5A5),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejection
                ? Icons.image_not_supported_outlined
                : Icons.error_outline,
            color: isRejection
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _analysisError ?? '',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isRejection
                    ? const Color(0xFF92400E)
                    : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Location Card Widget ───────────────────────────────────────────────────

  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting ? null : _openLocationPicker,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
                const Icon(Icons.chevron_right, color: _secondaryGrey, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
