import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

/// Shows the "Report a hazard" bottom sheet modal (used on home screen).
void showReportHazardModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    builder: (BuildContext modalContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20.0,
            12.0,
            20.0,
            MediaQuery.of(modalContext).viewInsets.bottom + 20.0,
          ),
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
              ReportHazardContentWidget(
                onClose: () => Navigator.pop(modalContext),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shows the "Report a hazard" centered floating popup dialog.
void showReportHazardDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ReportHazardContentWidget(
            onClose: () => Navigator.pop(dialogContext),
          ),
        ),
      );
    },
  );
}

/// Shared inner content of the Report Hazard form with AI image analysis.
class ReportHazardContentWidget extends StatefulWidget {
  final VoidCallback onClose;

  const ReportHazardContentWidget({
    super.key,
    required this.onClose,
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
  String? _detectedHazard;
  String? _selectedCategory; // e.g. "Other"
  String _selectedSeverity = 'Low';
  int? _confidencePercent;
  String? _analysisError;

  // Form submission state
  bool _isSubmitting = false;
  late final TextEditingController _detectedHazardController;

  @override
  void initState() {
    super.initState();
    _detectedHazardController = TextEditingController();
  }

  @override
  void dispose() {
    _detectedHazardController.dispose();
    super.dispose();
  }

  // ── UUID generator for reportID ─────────────────────────────────────────────

  String _generateReportId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    // Set version to 4
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    values[8] = (values[8] & 0x3f) | 0x80;
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ── Submit hazard report to Supabase ReportTable ────────────────────────────

  Future<void> _submitReport() async {
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      // Generate unique reportID
      final reportId = _generateReportId();

      // Upload image to Supabase Storage if available
      String? imageUrl;
      if (_imageBytes != null) {
        try {
          final ext =
              _selectedImage?.name.split('.').last.toLowerCase() ?? 'jpg';
          final fileName = '$reportId.$ext';
          final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

          await supabase.storage.from('hazard-reports').uploadBinary(
                fileName,
                _imageBytes!,
                fileOptions: FileOptions(contentType: mimeType, upsert: true),
              );

          imageUrl = supabase.storage
              .from('hazard-reports')
              .getPublicUrl(fileName);
        } catch (uploadError) {
          debugPrint('Image upload failed, proceeding with report insert: $uploadError');
        }
      }

      final hazardDesc = _detectedHazardController.text.trim().isNotEmpty
          ? _detectedHazardController.text.trim()
          : (_detectedHazard ?? 'Unknown hazard');

      // Insert into Supabase ReportTable
      await supabase.from('ReportTable').insert({
        'reportID': reportId,
        'user_id': user?.id,
        'hazard_category': _selectedCategory ?? 'Other',
        'detected_hazard': hazardDesc,
        'severity_level': _selectedSeverity,
        'confidence': _confidencePercent,
        'location_address': _selectedAddress != 'Current Location'
            ? _selectedAddress
            : 'Current Location',
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
        'image_url': imageUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

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

      widget.onClose();
    } catch (e) {
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

  // ── Location picker ─────────────────────────────────────────────────────────

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

  // ── Photo picking + Gemini analysis ─────────────────────────────────────────

  Future<void> _pickImageAndAnalyze() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    // Read bytes immediately — works on both web and mobile
    final bytes = await image.readAsBytes();

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

    await _analyzeImageWithGemini(bytes, image.name);
  }

  Future<void> _analyzeImageWithGemini(Uint8List imageBytes, String fileName) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _analysisError = 'Gemini API key not found in .env';
        });
        return;
      }

      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
      );

      final mimeType = fileName.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      const prompt = '''
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

      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ]),
      ]);

      final text = response.text ?? '';
      _parseGeminiResponse(text);
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisError = 'AI analysis failed: ${e.toString()}';
      });
    }
  }

  void _parseGeminiResponse(String text) {
    try {
      // Strip any accidental markdown fences
      String cleaned = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // Simple manual JSON parse
      String extractField(String key) {
        final pattern = RegExp('"$key"\\s*:\\s*"?([^",}]+)"?');
        final match = pattern.firstMatch(cleaned);
        return match?.group(1)?.trim() ?? '';
      }

      int extractInt(String key) {
        final pattern = RegExp('"$key"\\s*:\\s*(\\d+)');
        final match = pattern.firstMatch(cleaned);
        return int.tryParse(match?.group(1) ?? '') ?? 0;
      }

      bool extractBool(String key) {
        final pattern = RegExp('"$key"\\s*:\\s*(true|false)');
        final match = pattern.firstMatch(cleaned);
        return match?.group(1) == 'true';
      }

      final isHazard = extractBool('is_hazard');

      // Reject non-hazard images — clear photo and show error
      if (!isHazard) {
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

      final hazard = extractField('detected_hazard');
      final category = extractField('hazard_category');
      final severity = extractField('severity_level');
      final confidence = extractInt('confidence');

      // Validate category against allowed list
      final validCategories =
          _hazardCategories.map((c) => c['label']!).toList();
      final resolvedCategory =
          validCategories.contains(category) ? category : 'Other';

      // Validate severity
      final resolvedSeverity =
          _severityLevels.contains(severity) ? severity : 'Low';

      setState(() {
        _isAnalyzing = false;
        _detectedHazard = hazard.isNotEmpty ? hazard : 'Unknown';
        _detectedHazardController.text = _detectedHazard!;
        _selectedCategory = resolvedCategory;
        _selectedSeverity = resolvedSeverity;
        _confidencePercent = confidence;
      });
    } catch (_) {
      setState(() {
        _isAnalyzing = false;
        _analysisError = 'Could not parse AI response.';
      });
    }
  }

  // ── Build helpers ────────────────────────────────────────────────────────────

  String _categoryDisplay(String label) {
    final cat =
        _hazardCategories.firstWhere((c) => c['label'] == label, orElse: () => {'emoji': '⚠️', 'label': label});
    return '${cat['emoji']} ${cat['label']}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
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
                icon: const Icon(Icons.close, color: _primaryNavy, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Photo Card ─────────────────────────────────────────────────────
          _buildPhotoCard(),

          const SizedBox(height: 12),

          // ── AI Analysis Result (shown after image pick) ────────────────────
          if (_isAnalyzing) _buildAnalyzingCard(),
          if (!_isAnalyzing && _detectedHazard != null) _buildAiResultCard(),
          if (!_isAnalyzing && _analysisError != null) _buildErrorCard(),

          if (_detectedHazard != null || _analysisError != null)
            const SizedBox(height: 12),

          // ── Current Location Card ──────────────────────────────────────────
          _buildLocationCard(),

          const SizedBox(height: 20),

          // ── Submit Button ──────────────────────────────────────────────────
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

  // ── Photo card ─────────────────────────────────────────────────────────────

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
          onTap: _pickImageAndAnalyze,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                // Thumbnail or + icon
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
                  const Icon(Icons.add, color: _primaryNavy, size: 22),

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
                            ? 'Photo selected from PC'
                            : 'Help our community understand the issue',
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

  // ── Analyzing spinner card ─────────────────────────────────────────────────

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
            child: CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy),
          ),
          SizedBox(width: 12),
          Text(
            'Analyzing image with Gemini AI…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _primaryNavy,
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Result card ─────────────────────────────────────────────────────────

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
          // Header row
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

          // Detected Hazard label
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
          // Detected Hazard field
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
            ),
            child: TextField(
              controller: _detectedHazardController,
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

          // Hazard Category label
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
              onChanged: (val) {
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

          // Severity Level label
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

          // Helper text
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

  // ── Severity selector buttons ──────────────────────────────────────────────

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
            onTap: () => setState(() => _selectedSeverity = level),
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

  // ── Error card ─────────────────────────────────────────────────────────────

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
            isRejection ? Icons.image_not_supported_outlined : Icons.error_outline,
            color: isRejection ? const Color(0xFFD97706) : const Color(0xFFDC2626),
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
                color: isRejection ? const Color(0xFF92400E) : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Location card ──────────────────────────────────────────────────────────

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
          onTap: _openLocationPicker,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
