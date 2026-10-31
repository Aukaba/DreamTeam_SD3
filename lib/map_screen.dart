import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'services/cebu_landmark_service.dart';
import 'services/location_service.dart';
import 'services/nominatim_rate_limiter.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _tileStyleIndex = 0;
  bool _hasTileError = false;

  // Search state
  List<CebuLandmark> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchingOnline = false;
  CebuLandmark? _selectedLandmark;
  Timer? _searchDebounceTimer;
  Timer? _reverseGeocodeDebounceTimer;
  bool _isProgrammaticTextUpdate = false;
  bool _hasUserInteracted = false;
  int _reverseGeocodeRequestId = 0;

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

  static const List<String> _tileNames = [
    'Natural Modern',
    'Cool Slate',
    'OpenStreetMap Standard',
  ];

  static const List<List<double>?> _tileColorMatrices = [
    // 0: Natural Modern (Soft pastel greens/blues, crisp white roads, zero yellow/brown)
    <double>[
      0.75, 0.15, 0.10, 0.0, 15.0,
      0.05, 0.85, 0.10, 0.0, 15.0,
      0.40, 0.40, 0.20, 0.0, 15.0,
      0.00, 0.00, 0.00, 1.0,  0.0,
    ],
    // 1: Cool Slate (Modern minimalist light slate / cool tone)
    <double>[
      0.70, 0.15, 0.10, 0.0, 18.0,
      0.06, 0.82, 0.10, 0.0, 18.0,
      0.25, 0.30, 0.45, 0.0, 22.0,
      0.00, 0.00, 0.00, 1.0,  0.0,
    ],
    // 2: Standard OpenStreetMap (unfiltered)
    null,
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
    _searchController.addListener(_onSearchChanged);
    _initDeviceLocation();
  }

  void _onSearchChanged() {
    if (_isProgrammaticTextUpdate) return;

    // User is actively typing/editing the query: clear previously selected landmark pin
    if (_selectedLandmark != null) {
      setState(() {
        _selectedLandmark = null;
      });
    }

    final query = _searchController.text.trim();
    if (query.isEmpty || query.length < 3) {
      _searchDebounceTimer?.cancel();
      if (_searchResults.isNotEmpty || _isSearching || _isSearchingOnline) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _isSearchingOnline = false;
        });
      }
      return;
    }

    // 1. Instant local search (0ms latency, works offline for all barangays, streets, shops)
    final localResults = CebuLandmarkService.searchLocal(
      query,
      userLocation: _currentLocation,
    );
    setState(() {
      _searchResults = localResults;
      _isSearching = true;
      _isSearchingOnline = true;
    });

    // 2. 600ms debounced online geocoding (Nominatim OpenStreetMap)
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final onlineResults = await CebuLandmarkService.searchOnline(
        query,
        userLocation: _currentLocation,
      );

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _isSearchingOnline = false;
        if (onlineResults.isNotEmpty) {
          final merged = List<CebuLandmark>.from(_searchResults);
          for (final online in onlineResults) {
            // Deduplicate only when stable IDs match or (matching names AND distance < 35m)
            final isDuplicate = merged.any((l) =>
                (l.id == online.id) ||
                (l.name.toLowerCase() == online.name.toLowerCase() &&
                    const Distance().distance(l.location, online.location) < 35));
            if (!isDuplicate) {
              merged.add(online);
            }
          }
          _searchResults = merged.take(10).toList();
        }
      });
    });
  }

  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _isProgrammaticTextUpdate = true;
    _searchController.clear();
    _isProgrammaticTextUpdate = false;
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _isSearching = false;
      _isSearchingOnline = false;
      _selectedLandmark = null;
    });
  }

  void _selectLandmark(CebuLandmark landmark) {
    _hasUserInteracted = true;
    _searchDebounceTimer?.cancel();
    _searchFocusNode.unfocus();

    _isProgrammaticTextUpdate = true;
    _searchController.text = landmark.name;
    _isProgrammaticTextUpdate = false;

    setState(() {
      _selectedLandmark = landmark;
      _searchResults = [];
      _isSearching = false;
      _isSearchingOnline = false;
    });

    // Adapt zoom level: wider for whole barangays, medium for streets, close-up for shops/landmarks
    double targetZoom = 17.5;
    if (landmark.category == LandmarkCategory.barangay) {
      targetZoom = 15.5;
    } else if (landmark.category == LandmarkCategory.street) {
      targetZoom = 16.5;
    }

    _mapController.move(landmark.location, targetZoom);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(landmark.icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Found ${landmark.name} (${landmark.categoryLabel})',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDistanceTo(LatLng target) {
    final meters = const Distance().distance(_currentLocation, target);
    if (meters < 1000) {
      return '${meters.round()} m away';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _initDeviceLocation() async {
    final lastKnown = await LocationService.getLastKnownLocation();
    if (_hasUserInteracted || _selectedLandmark != null) return;
    if (lastKnown != null && mounted) {
      setState(() {
        _currentLocation = lastKnown;
        _currentLatitude = lastKnown.latitude;
      });
      _mapController.move(_currentLocation, _currentZoom);
    }

    final current = await LocationService.getCurrentLocation();
    if (_hasUserInteracted || _selectedLandmark != null) return;
    if (mounted) {
      setState(() {
        _currentLocation = current;
        _currentLatitude = current.latitude;
      });
      _mapController.move(_currentLocation, _currentZoom);
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    final reqId = ++_reverseGeocodeRequestId;
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1',
      );
      final response = await NominatimRateLimiter.instance
          .get(url)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          final raw = data['display_name'].toString();
          // Extract display_name and take the top 2 comma-separated segments
          final formatted = raw.split(',').take(2).map((s) => s.trim()).join(', ');
          if (mounted &&
              reqId == _reverseGeocodeRequestId &&
              _selectedLandmark == null &&
              !_searchFocusNode.hasFocus &&
              const Distance().distance(pos, _mapController.camera.center) < 25) {
            _isProgrammaticTextUpdate = true;
            _searchController.text = formatted;
            _isProgrammaticTextUpdate = false;
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _reverseGeocodeDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      backgroundColor: const Color(0xFFF1F5F9),
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
                onTap: (tapPosition, point) {
                  if (_searchFocusNode.hasFocus) {
                    _searchFocusNode.unfocus();
                  }
                  if (_isSearching) {
                    setState(() => _isSearching = false);
                  }
                },
                onPositionChanged: (camera, hasGesture) {
                  if ((camera.zoom - _currentZoom).abs() > 0.05 ||
                      (camera.center.latitude - _currentLatitude).abs() > 0.001) {
                    setState(() {
                      _currentZoom = camera.zoom;
                      _currentLatitude = camera.center.latitude;
                    });
                  }

                  // When hasGesture is true, user dragged/panned the map:
                  // debounce reverse geocoding by 800ms to update search text
                  if (hasGesture) {
                    _hasUserInteracted = true;
                    _reverseGeocodeDebounceTimer?.cancel();
                    _reverseGeocodeDebounceTimer =
                        Timer(const Duration(milliseconds: 800), () {
                      _reverseGeocode(camera.center);
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  fallbackUrl: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.dreamteam.sd3',
                  evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                  tileBuilder: (context, tileWidget, tile) {
                    final matrix = _tileColorMatrices[_tileStyleIndex];
                    if (matrix != null) {
                      return ColorFiltered(
                        colorFilter: ColorFilter.matrix(matrix),
                        child: tileWidget,
                      );
                    }
                    return tileWidget;
                  },
                  errorTileCallback: (tile, error, stackTrace) {
                    if (!_hasTileError && mounted) {
                      setState(() {
                        _hasTileError = true;
                      });
                    }
                  },
                ),
                const SimpleAttributionWidget(
                  alignment: Alignment.bottomRight,
                  source: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 9, color: Color(0xFF4B5563)),
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
                    color: Colors.black.withValues(alpha: 0.08),
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
                    onPressed: () {
                      if (_isSearching || _selectedLandmark != null) {
                        _clearSearch();
                      } else {
                        Navigator.pop(context);
                      }
                    },
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
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) async {
                        final submitted = value.trim();
                        if (submitted.isEmpty) return;

                        if (_searchResults.isNotEmpty) {
                          _selectLandmark(_searchResults.first);
                        } else {
                          setState(() {
                            _isSearchingOnline = true;
                          });
                          final localMatches = CebuLandmarkService.searchLocal(
                            submitted,
                            userLocation: _currentLocation,
                          );
                          if (localMatches.isNotEmpty) {
                            if (mounted && _searchController.text.trim() == submitted) {
                              _selectLandmark(localMatches.first);
                            }
                          } else {
                            final onlineMatches =
                                await CebuLandmarkService.searchOnline(
                              submitted,
                              userLocation: _currentLocation,
                            );
                            if (onlineMatches.isNotEmpty &&
                                mounted &&
                                _searchController.text.trim() == submitted) {
                              _selectLandmark(onlineMatches.first);
                            }
                          }
                          if (mounted) {
                            setState(() {
                              _isSearchingOnline = false;
                            });
                          }
                        }
                      },
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: _primaryNavy,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Search location (e.g. Cebu Institute of Technology)...',
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

                  // Clear button when query is present, otherwise LogoSR
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _secondaryGrey,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
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

          // Search Suggestions Dropdown Overlay
          if (_isSearching && _searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8.0, left: 20.0, right: 20.0),
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearchingOnline)
                      const LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: Color(0xFFF1F5F9),
                        color: _primaryNavy,
                      ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Color(0xFFF1F5F9),
                          height: 1,
                          thickness: 1,
                          indent: 58,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final landmark = _searchResults[index];
                          final distStr = _formatDistanceTo(landmark.location);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectLandmark(landmark),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: landmark.color.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        landmark.icon,
                                        color: landmark.color,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            landmark.name,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _primaryNavy,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: landmark.color.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  landmark.categoryLabel,
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: landmark.color,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  landmark.address,
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w400,
                                                    color: _secondaryGrey,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        distStr,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: _secondaryGrey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_isSearching &&
              _searchController.text.trim().isNotEmpty &&
              _isSearchingOnline)
            Container(
              margin: const EdgeInsets.only(top: 8.0, left: 20.0, right: 20.0),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryNavy,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Searching locations, buildings & businesses...',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _secondaryGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_isSearching &&
              _searchController.text.trim().isNotEmpty &&
              _searchResults.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8.0, left: 20.0, right: 20.0),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_off_rounded, color: _secondaryGrey, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No matching locations or businesses found',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _secondaryGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
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

    // 2. Selected Landmark Search Marker
    if (_selectedLandmark != null) {
      markers.add(_buildSelectedLandmarkMarker(_selectedLandmark!));
    }

    // 3. Filtered hazard markers
    for (final hazard in _filteredHazards) {
      markers.add(_buildHazardMarker(hazard));
    }

    return markers;
  }

  // Selected Landmark Marker with Info Callout & Dismiss
  Marker _buildSelectedLandmarkMarker(CebuLandmark landmark) {
    return Marker(
      point: landmark.location,
      width: 180,
      height: 96,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          _mapController.move(landmark.location, 17.0);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Callout Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      landmark.name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLandmark = null;
                        _searchController.clear();
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: _secondaryGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Pin with pulse ring
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: landmark.color.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: landmark.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: landmark.color.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    landmark.icon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      _reverseGeocode(current);
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
      _tileStyleIndex = (_tileStyleIndex + 1) % _tileNames.length;
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
                    Flexible(
                      child: Text(
                        '${filtered.length} nearby hazard${filtered.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Updated just now',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: _secondaryGrey,
                          ),
                        ),
                        SizedBox(width: 2),
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
