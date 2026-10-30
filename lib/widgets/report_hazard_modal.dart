import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_hazard_service.dart';

/// Shared color constants
const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _accentBlue = Color(0xFF2563EB);
const Color _errorRed = Color(0xFFEF4444);

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
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 20.0),
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

                  ReportHazardContent(
                    onClose: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Shows the "Report a hazard" centered floating popup dialog (used on map screen).
void showReportHazardDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ReportHazardContent(
              onClose: () => Navigator.pop(dialogContext),
            ),
          ),
        ),
      );
    },
  );
}

class ReportHazardContent extends StatefulWidget {
  final VoidCallback onClose;

  const ReportHazardContent({super.key, required this.onClose});

  @override
  State<ReportHazardContent> createState() => _ReportHazardContentState();
}

class _ReportHazardContentState extends State<ReportHazardContent> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  HazardAnalysisResult? _analysisResult;
  String? _rejectionError;

  // Selected editable values by user
  String? _selectedCategory;
  String? _selectedSeverity;
  late TextEditingController _detectedController;

  final List<String> _severityLevels = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    _detectedController = TextEditingController();
  }

  @override
  void dispose() {
    _detectedController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _isAnalyzing = true;
          _analysisResult = null;
          _rejectionError = null;
        });

        final mimeType = image.mimeType ?? 'image/jpeg';
        final result = await GeminiHazardService.analyzeHazardImage(bytes, mimeType);

        if (mounted) {
          if (!result.isRoadHazard) {
            setState(() {
              _isAnalyzing = false;
              _analysisResult = null;
              _rejectionError = result.rejectionReason ??
                  'This photo does not appear to show a valid road or traffic hazard. Please upload a photo of a road issue.';
            });
          } else {
            setState(() {
              _analysisResult = result;
              _rejectionError = null;
              _selectedCategory = result.category;
              _selectedSeverity = result.severity;
              _detectedController.text = result.detected;
              _isAnalyzing = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _rejectionError = 'Failed to analyze photo: $e';
        });
      }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return const Color(0xFF10B981);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'high':
        return const Color(0xFFEF4444);
      case 'critical':
        return const Color(0xFFB91C1C);
      default:
        return _primaryNavy;
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

        // Photo Upload / Preview Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _rejectionError != null
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Row(
                  children: [
                    if (_imageBytes != null)
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
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _primaryNavy,
                          size: 24,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _imageBytes != null ? 'Change photo' : 'Add a photo',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _imageBytes != null
                                ? 'Photo selected from PC'
                                : 'Upload a photo of the road hazard',
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
                    const Icon(
                      Icons.arrow_upward,
                      color: _primaryNavy,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Loading Indicator during Gemini Analysis
        if (_isAnalyzing) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Gemini AI is analyzing the hazard photo...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Invalid Road Hazard Rejection Banner
        if (_rejectionError != null && !_isAnalyzing) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: _errorRed, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Not a valid road hazard',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _errorRed,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _rejectionError!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // AI Results & Editable Confirmation Card
        if (_analysisResult != null && !_isAnalyzing) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: _accentBlue, size: 18),
                    const SizedBox(width: 8),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Confidence: ${_analysisResult!.confidence}%',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Detected hazard name / edit
                const Text(
                  'Detected Hazard',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _secondaryGrey,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _detectedController,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryNavy,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Category selector
                const Text(
                  'Hazard Category',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _secondaryGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _primaryNavy,
                      ),
                      items: GeminiHazardService.categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(GeminiHazardService.getCategoryWithEmoji(cat)),
                        );
                      }).toList(),
                      onChanged: (newCat) {
                        if (newCat != null) {
                          setState(() {
                            _selectedCategory = newCat;
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Severity selector
                const Text(
                  'Severity Level',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _secondaryGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: _severityLevels.map((sev) {
                    final isSelected = (_selectedSeverity?.toLowerCase() == sev.toLowerCase());
                    final sevColor = _getSeverityColor(sev);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSeverity = sev;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? sevColor.withValues(alpha: 0.15) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? sevColor : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              sev,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? sevColor : _secondaryGrey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),
                const Text(
                  'You can confirm or adjust the AI detected values above.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: _secondaryGrey,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // "Current Location" Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Handle Current Location
              },
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: _secondaryGrey,
                      size: 22,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Current Location',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _primaryNavy,
                        ),
                      ),
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
            onPressed: (_analysisResult == null || _rejectionError != null)
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _errorRed,
                        content: Text(
                          _rejectionError ??
                              'Please upload a valid photo of a road hazard before submitting.',
                        ),
                      ),
                    );
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text(
                          'Hazard reported: ${_detectedController.text.isNotEmpty ? _detectedController.text : (_selectedCategory ?? "Hazard")} (${_selectedSeverity ?? "Normal"} severity)',
                        ),
                      ),
                    );
                    widget.onClose();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: (_analysisResult == null || _rejectionError != null)
                  ? const Color(0xFF94A3B8)
                  : _primaryNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: const Text(
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
}
