import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/widgets/interactive_location_picker.dart';

/// Shared color constants used by the report hazard modal and dialog.
const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);

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

              // Content
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

/// Shows the "Report a hazard" centered floating popup dialog
/// exactly as shown in the map design.
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

/// Shared inner content of the Report Hazard form with interactive location picker support.
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

class _ReportHazardContentWidgetState extends State<ReportHazardContentWidget> {
  LatLng? _selectedLocation;
  String _selectedAddress = 'Current Location';

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

        // "Add a photo" Card
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
                // Photo selection action
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
        ),

        const SizedBox(height: 12),

        // "Current Location" Card (Launches InteractiveLocationPicker)
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
              onTap: _openLocationPicker,
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
            onPressed: widget.onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
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
