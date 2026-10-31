import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'services/location_service.dart';
import 'widgets/report_hazard_modal.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapScreen({super.key, this.initialLocation});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// Alias for UserFullMapScreen so both names can be used interchangeably
typedef UserFullMapScreen = MapScreen;

class _HazardItem {
  final String id;
  final String overline;
  final String title;
  final String subtitle;
  final String distance;
  final String badgeText;
  final Color themeColor;
  final Color bgColor;
  final Color iconBgColor;
  final Color badgeBgColor;
  final IconData icon;
  final LatLng location;
  final int filterCategoryIndex; // 1 = Roadwork/Obstruction, 2 = Flooding, 3 = Safety, 4 = Crime

  const _HazardItem({
    required this.id,
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.distance,
    required this.badgeText,
    required this.themeColor,
    required this.bgColor,
    required this.iconBgColor,
    required this.badgeBgColor,
    required this.icon,
    required this.location,
    required this.filterCategoryIndex,
  });
}

class _MapScreenState extends State<MapScreen> {
  int _selectedFilterIndex = 0;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final MapController _mapController = MapController();
  int _tileStyleIndex = 0;
  bool _hasTileError = false;

  // Camera tracking for dynamic scale indicator
  double _currentZoom = 16.0;
  double _currentLatitude = 10.3157;

  // Device location initialized dynamically
  late LatLng _currentLocation;

  // Landmark hazard coordinates
  static const LatLng _roadworkLocation = LatLng(10.3182, 123.8895);
  static const LatLng _floodingLocation = LatLng(10.3135, 123.8880);
  static const LatLng _lightingLocation = LatLng(10.3195, 123.8940);
  static const LatLng _crimeLocation = LatLng(10.3115, 123.8945);

  static const List<double> _scaleDistances = [
    10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000
  ];

  static const List<String> _tileUrls = [
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
  ];

  static const List<String> _tileNames = [
    'OpenStreetMap Standard',
    'CartoDB Voyager',
  ];

  late final List<_HazardItem> _allHazards = [
    const _HazardItem(
      id: 'safety_1',
      overline: 'SAFETY',
      title: 'Poor lighting area',
      subtitle: 'Near University Avenue (around 2:14 PM)',
      distance: '0.3 km away',
      badgeText: 'High',
      themeColor: Color(0xFFEF4444),
      bgColor: Color(0xFFFFF5F5),
      iconBgColor: Color(0xFFFEE2E2),
      badgeBgColor: Color(0xFFFEE2E2),
      icon: Icons.lightbulb_outline_rounded,
      location: _lightingLocation,
      filterCategoryIndex: 3,
    ),
    const _HazardItem(
      id: 'obstruction_1',
      overline: 'OBSTRUCTION',
      title: 'Blocked sidewalk',
      subtitle: 'Near Capitol Site (around 1:32 PM)',
      distance: '0.6 km away',
      badgeText: 'Medium',
      themeColor: Color(0xFFD97706),
      bgColor: Color(0xFFFFFDF5),
      iconBgColor: Color(0xFFFEF3C7),
      badgeBgColor: Color(0xFFFEF3C7),
      icon: Icons.construction_rounded,
      location: _roadworkLocation,
      filterCategoryIndex: 1,
    ),
    const _HazardItem(
      id: 'crime_1',
      overline: 'CRIME',
      title: 'Suspicious activity',
      subtitle: 'Near Mango Square (around 12:45 PM)',
      distance: '1.2 km away',
      badgeText: 'Low',
      themeColor: Color(0xFF3B82F6),
      bgColor: Color(0xFFF5F9FF),
      iconBgColor: Color(0xFFDBEAFE),
      badgeBgColor: Color(0xFFDBEAFE),
      icon: Icons.error_outline_rounded,
      location: _crimeLocation,
      filterCategoryIndex: 4,
    ),
    const _HazardItem(
      id: 'flooding_1',
      overline: 'FLOODING',
      title: 'Minor street flooding',
      subtitle: 'Near Capitol Site (around 1:50 PM)',
      distance: '0.4 km away',
      badgeText: 'Low',
      themeColor: Color(0xFF4A90E2),
      bgColor: Color(0xFFF0F9FF),
      iconBgColor: Color(0xFFE0F2FE),
      badgeBgColor: Color(0xFFE0F2FE),
      icon: Icons.water_drop_rounded,
      location: _floodingLocation,
      filterCategoryIndex: 2,
    ),
  ];

  List<_HazardItem> get _filteredHazards {
    if (_selectedFilterIndex == 0) {
      return _allHazards;
    }
    return _allHazards
        .where((hazard) => hazard.filterCategoryIndex == _selectedFilterIndex)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation ?? LocationService.defaultLocation;
    _currentLatitude = _currentLocation.latitude;
    _initDeviceLocation();
  }

  Future<void> _initDeviceLocation() async {
    final lastKnown = await LocationService.getLastKnownLocation();
    if (lastKnown != null && mounted) {
      setState(() {
        _currentLocation = lastKnown;
        _currentLatitude = lastKnown.latitude;
      });
      _mapController.move(_currentLocation, _currentZoom);
    }

    final current = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = current;
        _currentLatitude = current.latitude;
      });
      _mapController.move(_currentLocation, _currentZoom);
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // Design Colors matching Figma
  static const Color _primaryNavy = Color(0xFF263354);
  static const Color _secondaryGrey = Color(0xFF8A94A6);
  static const Color _accentOrange = Color(0xFFF37C34);
  static const Color _accentBlue = Color(0xFF4A90E2);
  static const Color _safeGreen = Color(0xFF2E7D32);
  static const Color _safeGreenBg = Color(0xFFE8F5E9);

  ({double width, String label}) _calculateScale() {
    final latRad = _currentLatitude * math.pi / 180.0;
    final metersPerPixel =
        (40075016.686 * math.cos(latRad)) / math.pow(2.0, _currentZoom + 8.0);

    const targetPixels = 50.0;
    final targetDistance = targetPixels * metersPerPixel;

    double bestDistance = _scaleDistances.first;
    double minDiff = (targetDistance - bestDistance).abs();
    for (final d in _scaleDistances) {
      final diff = (targetDistance - d).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestDistance = d;
      }
    }

    final width = (bestDistance / metersPerPixel).clamp(24.0, 96.0);
    final label = bestDistance >= 1000
        ? '${(bestDistance / 1000).toStringAsFixed(bestDistance % 1000 == 0 ? 0 : 1)} km'
        : '${bestDistance.toInt()} m';

    return (width: width, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EC),
      body: Stack(
        children: [
          // -------------------------------------------------------------------
          // LAYER 1 (BOTTOM): FLUTTER MAP
          // -------------------------------------------------------------------
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: _currentZoom,
                minZoom: 3.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (camera, hasGesture) {
                  if ((camera.zoom - _currentZoom).abs() > 0.05 ||
                      (camera.center.latitude - _currentLatitude).abs() > 0.001) {
                    setState(() {
                      _currentZoom = camera.zoom;
                      _currentLatitude = camera.center.latitude;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrls[_tileStyleIndex],
                  fallbackUrl: _tileUrls[(_tileStyleIndex + 1) % _tileUrls.length],
                  userAgentPackageName: 'com.dreamteam.sd3',
                  evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                  errorTileCallback: (tile, error, stackTrace) {
                    if (!_hasTileError && mounted) {
                      setState(() {
                        _hasTileError = true;
                      });
                    }
                  },
                ),
                SimpleAttributionWidget(
                  alignment: Alignment.bottomRight,
                  source: Text(
                    _tileStyleIndex == 0
                        ? '© OpenStreetMap contributors'
                        : '© CARTO, © OpenStreetMap',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF4B5563)),
                  ),
                ),
                MarkerLayer(
                  markers: _buildMapMarkers(),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // LAYER 2: FLOATING TOP ELEMENTS (Search Bar, Filters, Live Map Badge)
          // -------------------------------------------------------------------
          _buildTopControls(),

          // Tile Error Banner (if basemap fails to load)
          if (_hasTileError)
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Map tiles unavailable. Check internet connection.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _hasTileError = false;
                        });
                      },
                      child: const Icon(Icons.refresh_rounded, color: Color(0xFFDC2626), size: 18),
                    ),
                  ],
                ),
              ),
            ),

          // -------------------------------------------------------------------
          // LAYER 3: FLOATING ACTION BUTTONS (Report hazard, Crosshair, Layers, Scale)
          // -------------------------------------------------------------------
          _buildFloatingActionButtons(screenSize),

          // -------------------------------------------------------------------
          // LAYER 4 (ABSOLUTE TOP): DRAGGABLE SCROLLABLE SHEET
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
                  const SizedBox(width: 10),

                  // Search input
                  const Expanded(
                    child: TextField(
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: _primaryNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search destination or hazard...',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: _secondaryGrey,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // LogoSR Asset branding
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
                const SizedBox(width: 10),
                _buildFilterChip(
                  index: 3,
                  label: 'Safety',
                  icon: Icons.warning_amber_rounded,
                  activeBg: Colors.white,
                  activeText: _primaryNavy,
                  activeIcon: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 10),
                _buildFilterChip(
                  index: 4,
                  label: 'Crime',
                  icon: Icons.shield_outlined,
                  activeBg: Colors.white,
                  activeText: _primaryNavy,
                  activeIcon: const Color(0xFF3B82F6),
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
  // MAP MARKERS & OVERLAYS
  // ---------------------------------------------------------------------------
  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[
      // 1. Current Location Marker (always visible)
      Marker(
        point: _currentLocation,
        width: 100,
        height: 115,
        alignment: Alignment.center,
        child: _buildCurrentLocationMarker(),
      ),
    ];

    // Add matching markers for every filtered hazard
    for (final hazard in _filteredHazards) {
      markers.add(_buildHazardMarker(hazard));
    }

    return markers;
  }

  // 1. Current Location with Radar & "You are here"
  Widget _buildCurrentLocationMarker() {
    return GestureDetector(
      onTap: () {
        _recenterToCurrentLocation();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are here (Current Location)'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
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
                        color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // "You are here" label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Generic Hazard Marker Matching Card
  Marker _buildHazardMarker(_HazardItem hazard) {
    return Marker(
      point: hazard.location,
      width: 140,
      height: 75,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          _mapController.move(hazard.location, 17.0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${hazard.title}: ${hazard.subtitle}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill label above
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                  ),
                  children: [
                    TextSpan(
                      text: '${hazard.title} ',
                      style: const TextStyle(
                        color: _primaryNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: hazard.distance.split(' ').first,
                      style: const TextStyle(
                        color: _secondaryGrey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Hazard marker circle
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: hazard.themeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: hazard.themeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                hazard.icon,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recenterToCurrentLocation() async {
    final current = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = current;
        _currentLatitude = current.latitude;
      });
      _mapController.move(current, 16.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Centered on current location'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleTileStyle() {
    setState(() {
      _tileStyleIndex = (_tileStyleIndex + 1) % _tileUrls.length;
      _hasTileError = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${_tileNames[_tileStyleIndex]}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onHazardCardTap(_HazardItem hazard) {
    // Ensure the marker is visible under the active filter
    if (_selectedFilterIndex != 0 &&
        _selectedFilterIndex != hazard.filterCategoryIndex) {
      setState(() {
        _selectedFilterIndex = hazard.filterCategoryIndex;
      });
    }

    _mapController.move(hazard.location, 17.0);

    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.22,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // LAYER 3: FLOATING ACTION BUTTONS (Report hazard, Crosshair, Layers, Scale)
  // ---------------------------------------------------------------------------
  Widget _buildFloatingActionButtons(Size screenSize) {
    final collapsedOffset = screenSize.height * 0.22 + 12.0;
    final scale = _calculateScale();

    return Stack(
      children: [
        // Dynamic Scale bar on the map
        Positioned(
          left: 20,
          top: screenSize.height * 0.29,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: Size(scale.width, 8),
                painter: _ScaleLinePainter(),
              ),
              const SizedBox(width: 6),
              Text(
                scale.label,
                style: const TextStyle(
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
                onTap: _toggleTileStyle,
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
            onTap: _recenterToCurrentLocation,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            _mapController.rotate(0.0);
          },
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
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LAYER 4 (ABSOLUTE TOP): DRAGGABLE SCROLLABLE SHEET
  // ---------------------------------------------------------------------------
  Widget _buildDraggableScrollableSheet() {
    final filtered = _filteredHazards;

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
                          'Safe route monitored in real time',
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
                    if (filtered.isEmpty)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _secondaryGrey,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      for (final hazard in filtered) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: hazard.themeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                    const SizedBox(width: 3),
                    Text(
                      '${filtered.length} nearby hazard${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
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

              // 6. Filtered Hazard Cards
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'No hazards reported for this category',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: _secondaryGrey,
                      ),
                    ),
                  ),
                )
              else
                for (int i = 0; i < filtered.length; i++) ...[
                  _buildHazardReportCard(
                    hazard: filtered[i],
                    onTap: () => _onHazardCardTap(filtered[i]),
                  ),
                  if (i < filtered.length - 1) const SizedBox(height: 12),
                ],

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
                    onTap: () {
                      setState(() => _selectedFilterIndex = 0);
                      _mapController.move(_currentLocation, 15.0);
                      if (_sheetController.isAttached) {
                        _sheetController.animateTo(
                          0.22,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
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
    required _HazardItem hazard,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: hazard.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
                    color: hazard.iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hazard.icon,
                    color: hazard.themeColor,
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
                        hazard.overline,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hazard.themeColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hazard.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hazard.subtitle,
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
                            hazard.distance,
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
                        color: hazard.badgeBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        hazard.badgeText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: hazard.themeColor,
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
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
