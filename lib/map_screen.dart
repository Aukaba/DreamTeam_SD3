import 'package:flutter/material.dart';
import 'widgets/report_hazard_modal.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// Alias for UserFullMapScreen so both names can be used interchangeably
typedef UserFullMapScreen = MapScreen;

class _MapScreenState extends State<MapScreen> {
  int _selectedFilterIndex = 0;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  // Design Colors matching Figma
  static const Color _primaryNavy = Color(0xFF263354);
  static const Color _routeBlue = Color(0xFF7098C2);
  static const Color _secondaryGrey = Color(0xFF8A94A6);
  static const Color _accentOrange = Color(0xFFF37C34);
  static const Color _accentBlue = Color(0xFF4A90E2);
  static const Color _safeGreen = Color(0xFF2E7D32);
  static const Color _safeGreenBg = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EC),
      body: Stack(
        children: [
          // -------------------------------------------------------------------
          // LAYER 1 (BOTTOM): THE MAP BACKGROUND
          // -------------------------------------------------------------------
          Positioned.fill(
            child: CustomPaint(
              painter: _FullMapBackgroundPainter(),
              size: screenSize,
            ),
          ),

          // -------------------------------------------------------------------
          // LAYER 2: MAP OVERLAYS (Hazard & Location Markers)
          // -------------------------------------------------------------------
          _buildMapOverlays(screenSize),

          // -------------------------------------------------------------------
          // LAYER 3: FLOATING TOP ELEMENTS (Search Bar, Filters, Live Map Badge)
          // -------------------------------------------------------------------
          _buildTopControls(),

          // -------------------------------------------------------------------
          // LAYER 4: FLOATING ACTION BUTTONS (Report hazard, Crosshair, Layers, Scale)
          // -------------------------------------------------------------------
          _buildFloatingActionButtons(screenSize),

          // -------------------------------------------------------------------
          // LAYER 5 (ABSOLUTE TOP): DRAGGABLE SCROLLABLE SHEET
          // -------------------------------------------------------------------
          Positioned.fill(
            child: _buildDraggableScrollableSheet(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP CONTROLS (Search Bar, Filter Chips, Live Map Badge)
  // ---------------------------------------------------------------------------
  Widget _buildTopControls() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                children: [
                  // Back Arrow
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: _primaryNavy,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 14),

                  // Middle Search SafeRoute Text
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                        ),
                        children: [
                          TextSpan(
                            text: 'Search ',
                            style: TextStyle(
                              color: _secondaryGrey,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextSpan(
                            text: 'Safe',
                            style: TextStyle(
                              color: _primaryNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: 'Route',
                            style: TextStyle(
                              color: _routeBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right SafeRoute route icon
                  Image.asset(
                    'assets/image/LogoSR.png',
                    height: 24,
                    width: 24,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter Chips (Horizontally Scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                _buildFilterChip(
                  index: 0,
                  label: 'All hazards',
                  icon: Icons.tune_rounded,
                  activeBg: _primaryNavy,
                  activeText: Colors.white,
                  activeIcon: Colors.white,
                ),
                const SizedBox(width: 10),
                _buildFilterChip(
                  index: 1,
                  label: 'Roadwork',
                  icon: Icons.construction_rounded,
                  activeBg: Colors.white,
                  activeText: _primaryNavy,
                  activeIcon: _accentOrange,
                ),
                const SizedBox(width: 10),
                _buildFilterChip(
                  index: 2,
                  label: 'Flooding',
                  icon: Icons.water_drop_outlined,
                  activeBg: Colors.white,
                  activeText: _primaryNavy,
                  activeIcon: _accentBlue,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Live Map Badge
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _accentOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE MAP',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _primaryNavy,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required int index,
    required String label,
    required IconData icon,
    required Color activeBg,
    required Color activeText,
    required Color activeIcon,
  }) {
    final isSelected = _selectedFilterIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeIcon : _secondaryGrey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? activeText : _secondaryGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAP OVERLAYS (Current Location, Roadwork, Flooding)
  // ---------------------------------------------------------------------------
  Widget _buildMapOverlays(Size screenSize) {
    return Stack(
      children: [
        // 1. Roadwork Hazard (top: ~35%, left: ~28%)
        Positioned(
          top: screenSize.height * 0.35,
          left: screenSize.width * 0.28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill label above
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: 'Roadwork ',
                        style: TextStyle(
                          color: _primaryNavy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '200 m',
                        style: TextStyle(
                          color: _secondaryGrey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Orange hazard marker circle with barrier/hazard icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _accentOrange.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),

        // 2. Current Location with Radar & "You are here" (center of screen)
        Positioned(
          top: screenSize.height * 0.49,
          left: screenSize.width * 0.40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Radar beam & Center dot
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer radar pulse circle
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                    ),

                    // Translucent direction radar cone
                    ClipPath(
                      clipper: _RadarConeClipper(),
                      child: Container(
                        width: 84,
                        height: 84,
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.30),
                      ),
                    ),

                    // Blue current location dot with white border
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF2563EB).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // "You are here" label pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'You are here',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _primaryNavy,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Flooding Hazard (bottom-left)
        Positioned(
          top: screenSize.height * 0.63,
          left: screenSize.width * 0.18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue circle with water drop icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _accentBlue.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(height: 4),

              // Blue text label
              const Text(
                'Minor flooding',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _accentBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LAYER 4: FLOATING ACTION BUTTONS (Report hazard, Crosshair, Layers, Scale)
  // ---------------------------------------------------------------------------
  Widget _buildFloatingActionButtons(Size screenSize) {
    final collapsedOffset = screenSize.height * 0.22 + 12.0;

    return Stack(
      children: [
        // Scale bar (100 m) on the map
        Positioned(
          left: 20,
          top: screenSize.height * 0.29,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(44, 8),
                painter: _ScaleLinePainter(),
              ),
              const SizedBox(width: 6),
              const Text(
                '100 m',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),

        // Left: "Report hazard" button
        Positioned(
          left: 20,
          bottom: collapsedOffset,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                showReportHazardDialog(context);
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _primaryNavy,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryNavy.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Report hazard',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right: Layers & North Compass
        Positioned(
          right: 20,
          top: screenSize.height * 0.22,
          child: Column(
            children: [
              _buildCircleFab(
                icon: Icons.layers_outlined,
                size: 44,
                iconSize: 22,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildNorthCompassFab(),
            ],
          ),
        ),

        // Right: Crosshair / My Location FAB
        Positioned(
          right: 20,
          bottom: collapsedOffset,
          child: _buildCircleFab(
            icon: Icons.my_location_rounded,
            size: 48,
            iconSize: 24,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildCircleFab({
    required IconData icon,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(
            icon,
            size: iconSize,
            color: _primaryNavy,
          ),
        ),
      ),
    );
  }

  Widget _buildNorthCompassFab() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'N',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: _primaryNavy,
                height: 1.0,
              ),
            ),
            Icon(
              Icons.navigation,
              size: 14,
              color: _primaryNavy,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LAYER 5 (ABSOLUTE TOP): DRAGGABLE SCROLLABLE SHEET
  // ---------------------------------------------------------------------------
  Widget _buildDraggableScrollableSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.22,
      minChildSize: 0.22,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.22, 0.88],
      builder: (BuildContext sheetContext, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 36.0),
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Status Row: Green safe area
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _safeGreenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: _safeGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are in a safe area',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _primaryNavy,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Capitol Site, Cebu City',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: _secondaryGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 3. Horizontal Divider
              const Divider(
                color: Color(0xFFF1F5F9),
                thickness: 1,
                height: 1,
              ),

              const SizedBox(height: 12),

              // 4. Summary Row (tappable to expand/collapse)
              GestureDetector(
                onTap: () {
                  if (_sheetController.isAttached) {
                    final target = _sheetController.size < 0.5 ? 0.88 : 0.22;
                    _sheetController.animateTo(
                      target,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _accentOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _accentBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '2 nearby hazards',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                    ),
                    const Spacer(),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Updated just now',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _secondaryGrey,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: _secondaryGrey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. List Title
              const Text(
                'Nearby Hazard Reports',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _primaryNavy,
                ),
              ),

              const SizedBox(height: 14),

              // 6. Hazard Cards (12px vertical spacing between cards)
              // Card 1: High Severity (Safety - Red / Pale Pink)
              _buildHazardReportCard(
                overline: 'SAFETY',
                title: 'Poor lighting area',
                subtitle: 'Near University Avenue (around 2:14 PM)',
                distance: '0.3 km away',
                badgeText: 'High',
                themeColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFFF5F5),
                iconBgColor: const Color(0xFFFEE2E2),
                badgeBgColor: const Color(0xFFFEE2E2),
                icon: Icons.warning_amber_rounded,
              ),

              const SizedBox(height: 12),

              // Card 2: Medium Severity (Obstruction - Orange/Amber / Pale Yellow)
              _buildHazardReportCard(
                overline: 'OBSTRUCTION',
                title: 'Blocked sidewalk',
                subtitle: 'Near Capitol Site (around 1:32 PM)',
                distance: '0.6 km away',
                badgeText: 'Medium',
                themeColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFDF5),
                iconBgColor: const Color(0xFFFEF3C7),
                badgeBgColor: const Color(0xFFFEF3C7),
                icon: Icons.warning_amber_rounded,
              ),

              const SizedBox(height: 12),

              // Card 3: Low Severity (Crime - Blue / Pale Blue)
              _buildHazardReportCard(
                overline: 'CRIME',
                title: 'Suspicious activity',
                subtitle: 'Near Mango Square (around 12:45 PM)',
                distance: '1.2 km away',
                badgeText: 'Low',
                themeColor: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFF5F9FF),
                iconBgColor: const Color(0xFFDBEAFE),
                badgeBgColor: const Color(0xFFDBEAFE),
                icon: Icons.error_outline_rounded,
              ),

              const SizedBox(height: 16),

              // 7. Footer Action Button: "View all hazards"
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            color: _primaryNavy,
                            size: 20,
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'View all hazards',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryNavy,
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: _primaryNavy,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Reusable Hazard Report Card
  Widget _buildHazardReportCard({
    required String overline,
    required String title,
    required String subtitle,
    required String distance,
    required String badgeText,
    required Color themeColor,
    required Color bgColor,
    required Color iconBgColor,
    required Color badgeBgColor,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Circular container holding the warning icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: themeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Middle: Expanded details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overline,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: themeColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: _secondaryGrey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            distance,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: _secondaryGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right: Severity badge and right chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: themeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RADAR CONE CLIPPER FOR CURRENT LOCATION
// -----------------------------------------------------------------------------
class _RadarConeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    path.moveTo(center.dx, center.dy);
    // Cone pointing towards top-left / North-North-West
    path.lineTo(center.dx - 22, 0);
    path.lineTo(center.dx + 22, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// -----------------------------------------------------------------------------
// SCALE LINE PAINTER [___]
// -----------------------------------------------------------------------------
class _ScaleLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// STYLIZED REALISTIC FULL-MAP BACKGROUND PAINTER
// -----------------------------------------------------------------------------
class _FullMapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base Map Background (#F4F2EC)
    final bgPaint = Paint()..color = const Color(0xFFF4F2EC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Green Park Areas
    final parkPaint = Paint()..color = const Color(0xFFDCEBD9);

    // Cebu City Park (top center)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.22, size.height * 0.16, size.width * 0.38, 90),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // Capitol Grounds (mid left)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-10, size.height * 0.24, size.width * 0.30, 70),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // Bottom-left green zone
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-10, size.height * 0.68, size.width * 0.26, 90),
        const Radius.circular(16),
      ),
      parkPaint,
    );

    // 3. Subtle Building Blocks (#E5EAEB)
    final buildingPaint = Paint()..color = const Color(0xFFE5EAEB);

    final buildings = [
      Rect.fromLTWH(size.width * 0.08, size.height * 0.29, 36, 24),
      Rect.fromLTWH(size.width * 0.70, size.height * 0.20, 48, 30),
      Rect.fromLTWH(size.width * 0.75, size.height * 0.30, 45, 34),
      Rect.fromLTWH(size.width * 0.12, size.height * 0.42, 60, 26),
      Rect.fromLTWH(size.width * 0.65, size.height * 0.45, 75, 40),
      Rect.fromLTWH(size.width * 0.68, size.height * 0.58, 65, 36),
      Rect.fromLTWH(size.width * 0.28, size.height * 0.68, 50, 32),
      Rect.fromLTWH(size.width * 0.12, size.height * 0.82, 55, 30),
      Rect.fromLTWH(size.width * 0.72, size.height * 0.82, 60, 32),
    ];

    for (final b in buildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b, const Radius.circular(4)),
        buildingPaint,
      );
    }

    // 4. White Local Streets (with borders)
    final streetBorderPaint = Paint()
      ..color = const Color(0xFFE2E6EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final streetPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final streetPaths = [
      // Street 1: M. Velez St
      Path()
        ..moveTo(-10, size.height * 0.36)
        ..lineTo(size.width * 0.35, size.height * 0.33),
      // Street 2: Grid behind Capitol
      Path()
        ..moveTo(size.width * 0.08, size.height * 0.53)
        ..lineTo(size.width * 0.32, size.height * 0.50)
        ..lineTo(size.width * 0.44, size.height * 0.58)
        ..lineTo(size.width * 0.24, size.height * 0.62)
        ..close(),
      // Diagonal street connecting to Capitol site
      Path()
        ..moveTo(size.width * 0.04, size.height * 0.71)
        ..lineTo(size.width * 0.28, size.height * 0.51)
        ..lineTo(size.width * 0.55, size.height * 0.57),
      // Street to right of Osmeña Blvd
      Path()
        ..moveTo(size.width * 0.62, size.height * 0.55)
        ..lineTo(size.width + 10, size.height * 0.52),
      Path()
        ..moveTo(size.width * 0.60, size.height * 0.36)
        ..lineTo(size.width + 10, size.height * 0.43),
      Path()
        ..moveTo(size.width * 0.68, size.height * 0.18)
        ..lineTo(size.width * 0.78, size.height * 0.34)
        ..lineTo(size.width + 10, size.height * 0.32),
    ];

    for (final p in streetPaths) {
      canvas.drawPath(p, streetBorderPaint);
      canvas.drawPath(p, streetPaint);
    }

    // 5. Main Primary Yellow Roads (N. Escario & Osmeña Blvd)
    final mainRoadBorder = Paint()
      ..color = const Color(0xFFE4D69B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final mainRoad = Paint()
      ..color = const Color(0xFFF7E7A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // N. Escario St (diagonal across map)
    final escarioPath = Path()
      ..moveTo(-10, size.height * 0.46)
      ..lineTo(size.width * 0.60, size.height * 0.36)
      ..lineTo(size.width + 10, size.height * 0.31);

    canvas.drawPath(escarioPath, mainRoadBorder);
    canvas.drawPath(escarioPath, mainRoad);

    // Osmeña Blvd (Vertical Main Avenue)
    final osmenaPath = Path()
      ..moveTo(size.width * 0.69, -10)
      ..lineTo(size.width * 0.61, size.height * 0.36)
      ..lineTo(size.width * 0.58, size.height * 0.77);

    canvas.drawPath(osmenaPath, mainRoadBorder);
    canvas.drawPath(osmenaPath, mainRoad);

    // 6. Fuente Osmeña Circle / Roundabout (at bottom right)
    final circleCenter = Offset(size.width * 0.58, size.height * 0.80);
    const circleRadius = 50.0;

    // Outer roundabout road
    canvas.drawCircle(circleCenter, circleRadius + 6, mainRoadBorder);
    canvas.drawCircle(circleCenter, circleRadius + 6, mainRoad);

    // Inner green park
    canvas.drawCircle(circleCenter, circleRadius - 4,
        Paint()..color = const Color(0xFFD6E8D5));
    // Center fountain / monument dot
    canvas.drawCircle(
        circleCenter, 10, Paint()..color = const Color(0xFFA5CADE));

    // Road continuing below roundabout
    final maxilomRoad = Path()
      ..moveTo(circleCenter.dx - circleRadius - 10, circleCenter.dy + 16)
      ..lineTo(circleCenter.dx + circleRadius + size.width * 0.4,
          circleCenter.dy + 16);
    canvas.drawPath(maxilomRoad, mainRoadBorder);
    canvas.drawPath(maxilomRoad, mainRoad);

    // 7. Place and Street Name Labels
    _drawLabel(
        canvas, 'CEBU CITY', Offset(size.width * 0.35, size.height * 0.18),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6B7280));
    _drawLabel(canvas, 'Cebu Provincial\nCapitol',
        Offset(size.width * 0.08, size.height * 0.26),
        fontSize: 9, color: const Color(0xFF64748B));
    _drawLabel(
        canvas, 'M. Velez St.', Offset(size.width * 0.06, size.height * 0.33),
        fontSize: 9, color: const Color(0xFF64748B));
    _drawLabel(
        canvas, 'N. Escario St.', Offset(size.width * 0.56, size.height * 0.36),
        fontSize: 9, color: const Color(0xFF64748B), angle: -0.15);
    _drawLabel(
        canvas, 'CAPITOL SITE', Offset(size.width * 0.15, size.height * 0.48),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6B7280));
    _drawLabel(canvas, 'Don Gil Garcia St.',
        Offset(size.width * 0.09, size.height * 0.54),
        fontSize: 9, color: const Color(0xFF64748B), angle: -0.3);
    _drawLabel(canvas, 'Chong Hua\nHospital',
        Offset(size.width * 0.74, size.height * 0.54),
        fontSize: 9, color: const Color(0xFF64748B));
    _drawLabel(canvas, 'Cebu Doctors\'\nUniversity Hospital',
        Offset(size.width * 0.72, size.height * 0.46),
        fontSize: 9, color: const Color(0xFF64748B));
    _drawLabel(canvas, 'J. Llorente St.',
        Offset(size.width * 0.35, size.height * 0.68),
        fontSize: 9, color: const Color(0xFF64748B));
    _drawLabel(
        canvas, 'Maxilom Ave.', Offset(size.width * 0.74, size.height * 0.82),
        fontSize: 9, color: const Color(0xFF64748B));
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w500,
    Color color = const Color(0xFF6B7280),
    double angle = 0.0,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: 1.1,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (angle != 0.0) {
      canvas.rotate(angle);
    }
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
