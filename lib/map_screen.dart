import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'services/cebu_landmark_service.dart';
import 'services/gemini_hazard_service.dart';
import 'services/hazard_report_service.dart';
import 'services/location_service.dart';
import 'services/nominatim_rate_limiter.dart';
import 'services/safe_route_service.dart';
import 'services/saved_location_service.dart';
import 'widgets/report_hazard_modal.dart';
import 'widgets/route_place_picker_sheet.dart';
import 'widgets/turn_by_turn_navigation_overlay.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final LatLng? focusHazardLocation;
  final String? focusedReportId;
  final int initialFilterIndex;
  final HazardReportService? hazardReportService;
  final SafeRouteService? safeRouteService;
  final PlannedRouteResult? initialRoute;
  final bool autoStartNavigation;
  final TileProvider? tileProvider;

  const MapScreen({
    super.key,
    this.initialLocation,
    this.focusHazardLocation,
    this.focusedReportId,
    this.initialFilterIndex = 0,
    this.hazardReportService,
    this.safeRouteService,
    this.initialRoute,
    this.autoStartNavigation = false,
    this.tileProvider,
  });

  /// Maps any raw or emoji hazard category explicitly to a map filter index and icon.
  /// Filter indices: 1 = Roadwork/Obstruction, 2 = Flooding, 3 = Safety, 4 = Crime.
  static ({int filterCategoryIndex, IconData icon}) classifyHazardForMap(
    String rawCategory,
  ) {
    switch (HazardCategories.normalize(rawCategory)) {
      case HazardCategories.flood:
        return (
          filterCategoryIndex: 2,
          icon: Icons.water_drop_rounded,
        );
      case HazardCategories.roadDamage:
      case HazardCategories.blockedRoad:
      case HazardCategories.fallenTree:
        return (
          filterCategoryIndex: 1,
          icon: Icons.construction_rounded,
        );
      case HazardCategories.brokenStreetlight:
        return (
          filterCategoryIndex: 3,
          icon: Icons.lightbulb_outline_rounded,
        );
      case HazardCategories.accident:
      case HazardCategories.fire:
      case HazardCategories.other:
      default:
        return (
          filterCategoryIndex: 3,
          icon: Icons.warning_amber_rounded,
        );
    }
  }

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// Alias for UserFullMapScreen so both names can be used interchangeably
typedef UserFullMapScreen = MapScreen;

class _HazardItem {
  final String id;
  final String? reportId;
  final String overline;
  final String title;
  final String subtitle;
  final String description;
  final String address;
  final String? imageUrl;
  final int confidence;
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
    this.reportId,
    required this.overline,
    required this.title,
    required this.subtitle,
    this.description = '',
    this.address = '',
    this.imageUrl,
    this.confidence = 98,
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
  late LatLng _initialCameraCenter;

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

  late final HazardReportService _hazardReportService;
  late final SafeRouteService _safeRouteService;
  StreamSubscription<HazardReportData>? _reportSubscription;
  final List<_HazardItem> _reportedHazards = <_HazardItem>[];
  bool _isLoadingReports = true;
  bool _hasHandledInitialFocus = false;

  // Route preview & Turn-by-Turn Navigation state
  PlannedRouteResult? _activeRoute;
  bool _isNavigating = false;
  bool _isRecalculatingRoute = false;
  bool _isRouteSaved = false;
  bool _isFollowingUser = true;
  bool _isSimulating = false;
  bool _hasArrived = false;
  int _currentStepIndex = 0;
  int _activePolySegmentIndex = 0;
  double _distanceToNextTurnMeters = 0.0;
  double _remainingDistanceMeters = 0.0;
  int _remainingDurationSeconds = 0;
  int _rerouteCount = 0;
  String? _navigationSessionId;
  String? _hazardWarningBanner;
  DateTime? _lastAutoRerouteAt;
  StreamSubscription<Position>? _gpsPositionSub;
  Timer? _simulationTimer;
  double _simulationProgressMeters = 0.0;

  List<_HazardItem> get _allHazards =>
      List<_HazardItem>.unmodifiable(_reportedHazards);

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
    _selectedFilterIndex = widget.initialFilterIndex.clamp(0, 4);
    _currentLocation =
        widget.initialLocation ??
        widget.initialRoute?.origin ??
        LocationService.defaultLocation;
    _initialCameraCenter =
        widget.focusHazardLocation ??
        widget.initialRoute?.origin ??
        _currentLocation;
    if (widget.focusHazardLocation != null) {
      _currentZoom = 17.0;
    }
    _currentLatitude = _initialCameraCenter.latitude;
    _hazardReportService = widget.hazardReportService ?? HazardReportService();
    _safeRouteService =
        widget.safeRouteService ??
        SafeRouteService(hazardReportService: _hazardReportService);

    if (widget.initialRoute != null) {
      _activeRoute = widget.initialRoute;
      _isRouteSaved = widget.initialRoute!.savedRouteId != null;
      _syncNavigationMetricsFromRoute(widget.initialRoute!.primaryRoute);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _activeRoute == null) return;
        if (widget.autoStartNavigation) {
          _startTurnByTurnNavigation();
        } else {
          _fitCameraToRoute(_activeRoute!.primaryRoute.polyline);
        }
      });
    }

    for (final sessionReport in HazardReportService.sessionReports) {
      if (sessionReport.location != null && sessionReport.status == 'active') {
        _upsertReportedHazardItem(_buildHazardItemFromReport(sessionReport));
      }
    }
    _reportSubscription =
        HazardReportService.reportStream.listen(_onExternalReportSubmitted);
    _searchController.addListener(_onSearchChanged);
    _loadSavedReports();
    _initDeviceLocation();
  }

  Future<void> _loadSavedReports() async {
    final savedReports = await _hazardReportService.fetchReports();
    if (!mounted) return;
    _HazardItem? focusedItem;
    setState(() {
      _isLoadingReports = false;
      final mergedById = <String, _HazardItem>{};
      for (final report in savedReports) {
        if (report.location == null) continue;
        final item = _buildHazardItemFromReport(report);
        mergedById.putIfAbsent(item.id, () => item);
      }
      for (final existing in _reportedHazards) {
        mergedById.putIfAbsent(existing.id, () => existing);
      }
      _reportedHazards
        ..clear()
        ..addAll(mergedById.values);

      if (!_hasHandledInitialFocus &&
          widget.focusedReportId != null &&
          widget.focusedReportId!.trim().isNotEmpty) {
        final targetId = widget.focusedReportId!.trim();
        for (final item in _reportedHazards) {
          if (item.reportId == targetId || item.id == 'report_$targetId') {
            focusedItem = item;
            break;
          }
        }
      }
    });

    if (focusedItem != null && !_hasHandledInitialFocus) {
      _hasHandledInitialFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(focusedItem!.location, 17.0);
        _showHazardDetailSheet(focusedItem!);
      });
    }
  }

  void _onExternalReportSubmitted(HazardReportData report) {
    if (!mounted) return;
    setState(() {
      _upsertReportedHazardItem(
        _buildHazardItemFromReport(report),
        insertAtFront: true,
      );
    });

    // Live mid-trip hazard check: if a new hazard was reported on/near our active route
    if (_activeRoute != null &&
        report.location != null &&
        report.status == 'active') {
      final dist = SafeRouteService.pointToPolylineDistanceMeters(
        report.location!,
        _activeRoute!.primaryRoute.polyline,
      );
      if (dist <= 95.0) {
        if (_activeRoute!.avoidHazards) {
          _recalculateActiveRoute(
            originOverride: _isNavigating ? _currentLocation : null,
            originLabelOverride:
                _isNavigating ? 'Current GPS Position' : null,
            isHazardReroute: true,
          );
        } else {
          setState(() {
            _hazardWarningBanner =
                'New ${report.title.toLowerCase()} reported ${dist.round()} m from route';
          });
        }
      }
    }
  }

  void _upsertReportedHazardItem(
    _HazardItem hazard, {
    bool insertAtFront = false,
  }) {
    final existingIdx = _reportedHazards.indexWhere((h) => h.id == hazard.id);
    if (existingIdx != -1) {
      _reportedHazards.removeAt(existingIdx);
      _reportedHazards.insert(insertAtFront ? 0 : existingIdx, hazard);
    } else if (insertAtFront) {
      _reportedHazards.insert(0, hazard);
    } else {
      _reportedHazards.add(hazard);
    }
  }

  void _refreshReportedHazardDistances() {
    for (int i = 0; i < _reportedHazards.length; i++) {
      final item = _reportedHazards[i];
      _reportedHazards[i] = _HazardItem(
        id: item.id,
        reportId: item.reportId,
        overline: item.overline,
        title: item.title,
        subtitle: item.subtitle,
        description: item.description,
        address: item.address,
        imageUrl: item.imageUrl,
        confidence: item.confidence,
        distance: _formatDistanceTo(item.location),
        badgeText: item.badgeText,
        themeColor: item.themeColor,
        bgColor: item.bgColor,
        iconBgColor: item.iconBgColor,
        badgeBgColor: item.badgeBgColor,
        icon: item.icon,
        location: item.location,
        filterCategoryIndex: item.filterCategoryIndex,
      );
    }
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
                'Found ${landmark.name}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Directions',
          textColor: const Color(0xFF6EE7B7),
          onPressed: () => _routeToLandmark(landmark),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _routeToLandmark(CebuLandmark landmark) async {
    setState(() {
      _isRecalculatingRoute = true;
      _selectedLandmark = null;
    });
    final planned = await _safeRouteService.findSafeRoute(
      origin: _currentLocation,
      originLabel: 'Your current location',
      destination: landmark.location,
      destinationLabel: landmark.name,
      travelMode: RouteTravelMode.walking,
      avoidHazards: true,
    );
    if (!mounted) return;
    setState(() {
      _activeRoute = planned;
      _isRecalculatingRoute = false;
      _isRouteSaved = false;
      _isNavigating = false;
      _hasArrived = false;
      _syncNavigationMetricsFromRoute(planned.primaryRoute);
    });
    _fitCameraToRoute(planned.primaryRoute.polyline);
  }

  Future<void> _saveLandmarkDirectly(CebuLandmark landmark) async {
    try {
      final savedService = SavedLocationService();
      if (savedService.currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to save locations.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await savedService.saveLocation(
        title: landmark.name,
        address: landmark.address,
        location: landmark.location,
        category: landmark.category.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${landmark.name}" to your locations!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDistanceTo(LatLng target) {
    final meters = const Distance().distance(_currentLocation, target);
    if (meters < 1000) {
      return '${meters.round()} m away';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _initDeviceLocation() async {
    final hasExplicitHazardFocus = widget.focusHazardLocation != null ||
        widget.initialRoute != null ||
        (widget.focusedReportId != null &&
            widget.focusedReportId!.trim().isNotEmpty);

    final lastKnown = await LocationService.getLastKnownLocation();
    if (lastKnown != null && mounted) {
      setState(() {
        if (!_isSimulating) {
          _currentLocation = lastKnown;
        }
        if (!hasExplicitHazardFocus &&
            _activeRoute == null &&
            !_hasUserInteracted &&
            _selectedLandmark == null) {
          _currentLatitude = lastKnown.latitude;
        }
        _refreshReportedHazardDistances();
      });
      if (!hasExplicitHazardFocus &&
          _activeRoute == null &&
          !_hasUserInteracted &&
          _selectedLandmark == null) {
        _mapController.move(_currentLocation, _currentZoom);
      }
    }

    final current = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        if (!_isSimulating) {
          _currentLocation = current;
        }
        if (!hasExplicitHazardFocus &&
            _activeRoute == null &&
            !_hasUserInteracted &&
            _selectedLandmark == null) {
          _currentLatitude = current.latitude;
        }
        _refreshReportedHazardDistances();
      });
      if (!hasExplicitHazardFocus &&
          _activeRoute == null &&
          !_hasUserInteracted &&
          _selectedLandmark == null) {
        _mapController.move(_currentLocation, _currentZoom);
      }
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

  // ---------------------------------------------------------------------------
  // SAFE ROUTE PREVIEW & TURN-BY-TURN NAVIGATION CONTROLLERS
  // ---------------------------------------------------------------------------

  void _syncNavigationMetricsFromRoute(RouteCandidate route) {
    _currentStepIndex = 0;
    _activePolySegmentIndex = 0;
    _remainingDistanceMeters = route.distanceMeters;
    _remainingDurationSeconds = route.durationSeconds;
    _distanceToNextTurnMeters = route.steps.isNotEmpty
        ? route.steps.first.distanceMeters
        : route.distanceMeters;
    _hazardWarningBanner = route.hazardsOnRoute.isNotEmpty
        ? '${route.hazardsOnRoute.first.hazard.title} within ${route.hazardsOnRoute.first.distanceFromRouteMeters.round()} m of road'
        : null;
  }

  void _fitCameraToRoute(List<LatLng> poly) {
    if (poly.length < 2) return;
    double minLat = poly.first.latitude;
    double maxLat = poly.first.latitude;
    double minLng = poly.first.longitude;
    double maxLng = poly.first.longitude;

    for (final pt in poly) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    if ((maxLat - minLat).abs() < 0.0004 && (maxLng - minLng).abs() < 0.0004) {
      _mapController.move(poly.first, 16.5);
      return;
    }

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(minLat, minLng),
            LatLng(maxLat, maxLng),
          ),
          padding: const EdgeInsets.fromLTRB(48, 170, 48, 250),
          maxZoom: 17.5,
        ),
      );
    } catch (_) {
      _mapController.move(poly[poly.length ~/ 2], 14.5);
    }
  }

  Future<void> _recalculateActiveRoute({
    LatLng? originOverride,
    String? originLabelOverride,
    LatLng? destinationOverride,
    String? destinationLabelOverride,
    RouteTravelMode? modeOverride,
    bool? avoidHazardsOverride,
    bool isHazardReroute = false,
  }) async {
    final current = _activeRoute;
    if (current == null) return;

    setState(() {
      _isRecalculatingRoute = true;
    });

    final nextOrigin = originOverride ?? current.origin;
    final nextOriginLabel = originLabelOverride ?? current.originLabel;
    final nextDest = destinationOverride ?? current.destination;
    final nextDestLabel = destinationLabelOverride ?? current.destinationLabel;
    final nextMode = modeOverride ?? current.travelMode;
    final nextAvoid = avoidHazardsOverride ?? current.avoidHazards;

    final updated = await _safeRouteService.findSafeRoute(
      origin: nextOrigin,
      originLabel: nextOriginLabel,
      destination: nextDest,
      destinationLabel: nextDestLabel,
      travelMode: nextMode,
      avoidHazards: nextAvoid,
    );

    if (!mounted) return;
    setState(() {
      _activeRoute = updated.copyWith(savedRouteId: current.savedRouteId);
      _isRecalculatingRoute = false;
      _syncNavigationMetricsFromRoute(updated.primaryRoute);
      if (isHazardReroute) {
        _rerouteCount++;
      }
    });

    if (isHazardReroute && _navigationSessionId != null) {
      unawaited(
        _safeRouteService.recordNavigationReroute(
          _navigationSessionId,
          rerouteCount: _rerouteCount,
          hazardsAvoided: updated.hazardsAvoided,
          hazardsOnRoute: updated.primaryRoute.hazardsOnRoute.length,
        ),
      );
    }

    if (!_isNavigating) {
      _fitCameraToRoute(updated.primaryRoute.polyline);
    }
  }

  Future<void> _pickRouteEndpoint({required bool isOrigin}) async {
    final current = _activeRoute;
    if (current == null) return;
    final picked = await showRoutePlacePickerSheet(
      context,
      title: isOrigin ? 'Choose Starting Point' : 'Choose Destination',
      currentLocation: _currentLocation,
      allowCurrentLocationOption: isOrigin,
    );
    if (picked == null || !mounted) return;

    await _recalculateActiveRoute(
      originOverride: isOrigin ? picked.location : null,
      originLabelOverride: isOrigin ? picked.label : null,
      destinationOverride: isOrigin ? null : picked.location,
      destinationLabelOverride: isOrigin ? null : picked.label,
    );
  }

  Future<void> _swapRouteEndpoints() async {
    final current = _activeRoute;
    if (current == null) return;
    await _recalculateActiveRoute(
      originOverride: current.destination,
      originLabelOverride: current.destinationLabel,
      destinationOverride: current.origin,
      destinationLabelOverride: current.originLabel,
    );
  }

  Future<void> _saveActiveRoute() async {
    final current = _activeRoute;
    if (current == null) return;
    final saved = await _safeRouteService.savePlannedRoute(planned: current);
    if (!mounted) return;
    setState(() {
      _activeRoute = current.copyWith(savedRouteId: saved.id);
      _isRouteSaved = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved route "${saved.title}"'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startTurnByTurnNavigation() {
    final current = _activeRoute;
    if (current == null) return;

    setState(() {
      _isNavigating = true;
      _hasArrived = false;
      _isFollowingUser = true;
      _rerouteCount = 0;
      _simulationProgressMeters = 0.0;
      _syncNavigationMetricsFromRoute(current.primaryRoute);
    });

    final startPt = current.primaryRoute.polyline.isNotEmpty
        ? current.primaryRoute.polyline.first
        : current.origin;
    _mapController.move(startPt, 17.5);

    unawaited(
      _safeRouteService.startNavigationSession(current).then((sessionId) {
        if (mounted) {
          _navigationSessionId = sessionId;
        }
      }),
    );

    _startLiveGpsNavigationStream();
  }

  void _startLiveGpsNavigationStream() {
    _gpsPositionSub?.cancel();
    try {
      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 4,
        ),
      );
      _gpsPositionSub = stream.listen(
        (pos) {
          if (!mounted || !_isNavigating || _isSimulating) return;
          _updateNavigationProgress(LatLng(pos.latitude, pos.longitude));
        },
        onError: (Object err) {
          debugPrint('Navigation GPS stream note: $err');
        },
      );
    } catch (e) {
      debugPrint('Geolocator position stream unavailable: $e');
    }
  }

  void _updateNavigationProgress(
    LatLng userPos, {
    bool fromSimulation = false,
  }) {
    final active = _activeRoute;
    if (active == null) return;
    final route = active.primaryRoute;
    final poly = route.polyline;
    if (poly.isEmpty) return;

    final snap = SafeRouteService.locateAlongPolyline(userPos, poly);

    // Off-route detection for real GPS (> 70m away from road, 15s cooldown)
    if (!fromSimulation &&
        snap.distanceFromRouteMeters > 70.0 &&
        !_isRecalculatingRoute) {
      final now = DateTime.now();
      if (_lastAutoRerouteAt == null ||
          now.difference(_lastAutoRerouteAt!) > const Duration(seconds: 15)) {
        _lastAutoRerouteAt = now;
        _recalculateActiveRoute(
          originOverride: userPos,
          originLabelOverride: 'Current GPS Position',
          isHazardReroute: true,
        );
        return;
      }
    }

    // Advance step index based on snapped polyline segment
    final steps = route.steps;
    int nextStepIdx = _currentStepIndex;
    const distCalc = Distance();

    if (steps.isNotEmpty) {
      while (nextStepIdx < steps.length - 1) {
        final step = steps[nextStepIdx];
        final turnPoint =
            poly[step.endPolylineIndex.clamp(0, poly.length - 1)];
        final distToTurn = distCalc.distance(snap.snappedPoint, turnPoint);
        if (snap.segmentIndex > step.endPolylineIndex ||
            (snap.segmentIndex >= step.endPolylineIndex - 1 &&
                distToTurn <= 18.0)) {
          nextStepIdx++;
        } else {
          break;
        }
      }
    }

    double distToNextTurn = snap.remainingDistanceMeters;
    if (steps.isNotEmpty) {
      final currentStep = steps[nextStepIdx.clamp(0, steps.length - 1)];
      final targetIdx = currentStep.endPolylineIndex.clamp(0, poly.length - 1);
      if (targetIdx <= snap.segmentIndex) {
        distToNextTurn = distCalc.distance(snap.snappedPoint, poly[targetIdx]);
      } else {
        distToNextTurn =
            distCalc.distance(snap.snappedPoint, poly[snap.segmentIndex + 1]);
        for (int i = snap.segmentIndex + 1; i < targetIdx; i++) {
          distToNextTurn += distCalc.distance(poly[i], poly[i + 1]);
        }
      }
    }

    // Check upcoming hazards within 160m of user's current road position
    String? liveHazardAlert;
    for (final exp in route.hazardsNearCorridor) {
      final hLoc = exp.hazard.location;
      if (hLoc == null) continue;
      final dUser = distCalc.distance(snap.snappedPoint, hLoc);
      if (dUser <= 160.0) {
        liveHazardAlert =
            'Caution: ${exp.hazard.title} ${dUser.round()} m ahead';
        break;
      }
    }

    final remMeters = snap.remainingDistanceMeters;
    final remSeconds =
        (remMeters / active.travelMode.averageSpeedMps).round().clamp(0, 999999);
    final arrived = remMeters <= 22.0;

    setState(() {
      _currentLocation = fromSimulation ? snap.snappedPoint : userPos;
      _activePolySegmentIndex = snap.segmentIndex;
      _currentStepIndex = nextStepIdx;
      _distanceToNextTurnMeters = arrived ? 0.0 : distToNextTurn;
      _remainingDistanceMeters = arrived ? 0.0 : remMeters;
      _remainingDurationSeconds = arrived ? 0 : remSeconds;
      _hazardWarningBanner = liveHazardAlert;
      if (arrived && !_hasArrived) {
        _hasArrived = true;
        _isSimulating = false;
      }
    });

    if (_isFollowingUser) {
      _mapController.move(snap.snappedPoint, math.max(_currentZoom, 17.2));
    }

    if (arrived) {
      _simulationTimer?.cancel();
      unawaited(
        _safeRouteService.finishNavigationSession(
          _navigationSessionId,
          completed: true,
        ),
      );
    }
  }

  void _toggleSimulation() {
    if (_activeRoute == null) return;
    if (_isSimulating) {
      _simulationTimer?.cancel();
      setState(() => _isSimulating = false);
      return;
    }

    final poly = _activeRoute!.primaryRoute.polyline;
    if (poly.length < 2) return;

    if (_hasArrived) {
      _simulationProgressMeters = 0.0;
      setState(() {
        _hasArrived = false;
        _currentStepIndex = 0;
        _activePolySegmentIndex = 0;
      });
    }

    setState(() {
      _isSimulating = true;
      _isFollowingUser = true;
    });

    const distCalc = Distance();
    // Advance smoothly along the road polyline every 400ms
    final stepAdvanceMeters =
        _activeRoute!.travelMode == RouteTravelMode.driving ? 32.0 : 18.0;

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted || !_isNavigating || !_isSimulating || _activeRoute == null) {
        timer.cancel();
        return;
      }
      final routePoly = _activeRoute!.primaryRoute.polyline;
      _simulationProgressMeters += stepAdvanceMeters;
      final pt = _interpolateAlongPolyline(
        routePoly,
        _simulationProgressMeters,
        distCalc,
      );
      _updateNavigationProgress(pt, fromSimulation: true);
    });
  }

  LatLng _interpolateAlongPolyline(
    List<LatLng> poly,
    double targetMeters,
    Distance distCalc,
  ) {
    if (poly.isEmpty) return _currentLocation;
    if (targetMeters <= 0) return poly.first;

    double traversed = 0.0;
    for (int i = 0; i < poly.length - 1; i++) {
      final segLen = distCalc.distance(poly[i], poly[i + 1]);
      if (traversed + segLen >= targetMeters && segLen > 0.01) {
        final t = ((targetMeters - traversed) / segLen).clamp(0.0, 1.0);
        return LatLng(
          poly[i].latitude + (poly[i + 1].latitude - poly[i].latitude) * t,
          poly[i].longitude + (poly[i + 1].longitude - poly[i].longitude) * t,
        );
      }
      traversed += segLen;
    }
    return poly.last;
  }

  void _jumpToStep(int stepIndex) {
    final active = _activeRoute;
    if (active == null) return;
    final steps = active.primaryRoute.steps;
    if (steps.isEmpty) return;
    final clamped = stepIndex.clamp(0, steps.length - 1);
    final step = steps[clamped];

    setState(() {
      _currentStepIndex = clamped;
      _activePolySegmentIndex = step.startPolylineIndex;
      _distanceToNextTurnMeters = step.distanceMeters;
      _isFollowingUser = false;
    });
    _mapController.move(step.location, 17.5);
  }

  void _stopTurnByTurnNavigation() {
    _simulationTimer?.cancel();
    _gpsPositionSub?.cancel();
    final sessionId = _navigationSessionId;
    final wasArrived = _hasArrived;
    _navigationSessionId = null;

    if (!wasArrived && sessionId != null) {
      unawaited(
        _safeRouteService.finishNavigationSession(sessionId, completed: false),
      );
    }

    if (widget.initialRoute != null && widget.autoStartNavigation) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isNavigating = false;
      _isSimulating = false;
      _hasArrived = false;
    });
    if (_activeRoute != null) {
      _fitCameraToRoute(_activeRoute!.primaryRoute.polyline);
    }
  }

  void _exitRouteMode() {
    _simulationTimer?.cancel();
    _gpsPositionSub?.cancel();
    if (widget.initialRoute != null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _activeRoute = null;
      _isNavigating = false;
      _isSimulating = false;
      _hasArrived = false;
    });
  }

  List<Polyline> _buildRoutePolylines() {
    final active = _activeRoute;
    if (active == null) return const <Polyline>[];

    final polylines = <Polyline>[];

    // 1. Alternative candidate routes (only in preview mode so turn-by-turn stays uncluttered)
    if (!_isNavigating && active.alternatives.length > 1) {
      for (final alt in active.alternatives) {
        if (alt.id == active.primaryRoute.id || alt.polyline.length < 2) {
          continue;
        }
        final hasHazard = alt.hazardsOnRoute.isNotEmpty;
        polylines.add(
          Polyline(
            points: alt.polyline,
            strokeWidth: 5.0,
            color: hasHazard
                ? const Color(0xFFF59E0B).withValues(alpha: 0.65)
                : const Color(0xFF64748B).withValues(alpha: 0.55),
          ),
        );
      }
    }

    // 2. Primary SafeRoute polyline (with outer white casing + bright inner path)
    final primaryPoly = active.primaryRoute.polyline;
    if (primaryPoly.length >= 2) {
      if (_isNavigating &&
          _activePolySegmentIndex > 0 &&
          _activePolySegmentIndex < primaryPoly.length - 1) {
        final passed = primaryPoly.sublist(0, _activePolySegmentIndex + 1);
        final remaining = primaryPoly.sublist(_activePolySegmentIndex);
        polylines.add(
          Polyline(
            points: passed,
            strokeWidth: 5.5,
            color: const Color(0xFF94A3B8).withValues(alpha: 0.65),
          ),
        );
        polylines.add(
          Polyline(
            points: remaining,
            strokeWidth: 9.0,
            color: Colors.white,
          ),
        );
        polylines.add(
          Polyline(
            points: remaining,
            strokeWidth: 5.5,
            color: const Color(0xFF2563EB),
          ),
        );
      } else {
        final primaryColor = active.primaryRoute.hazardsOnRoute.isEmpty
            ? const Color(0xFF2563EB)
            : const Color(0xFFD97706);
        polylines.add(
          Polyline(
            points: primaryPoly,
            strokeWidth: 9.0,
            color: Colors.white,
          ),
        );
        polylines.add(
          Polyline(
            points: primaryPoly,
            strokeWidth: 5.5,
            color: primaryColor,
          ),
        );
      }
    }

    return polylines;
  }

  List<CircleMarker> _buildHazardAvoidanceCircles() {
    final active = _activeRoute;
    if (active == null) return const <CircleMarker>[];

    final circles = <CircleMarker>[];
    for (final h in active.corridorHazards) {
      if (h.location == null || h.status != 'active') continue;
      final metrics = SafeRouteService.hazardMetricsForReport(h);
      final isHigh = metrics.severityWeight >= 110.0;
      final baseColor =
          isHigh ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
      circles.add(
        CircleMarker(
          point: h.location!,
          radius: metrics.avoidanceRadiusMeters,
          useRadiusInMeter: true,
          color: baseColor.withValues(alpha: 0.14),
          borderColor: baseColor.withValues(alpha: 0.55),
          borderStrokeWidth: 1.5,
        ),
      );
    }
    return circles;
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _gpsPositionSub?.cancel();
    _reportSubscription?.cancel();
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
        ? '${(bestDistance / 1000).toStringAsFixed(0)} km'
        : '${bestDistance.toStringAsFixed(0)} m';

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
                initialCenter: _initialCameraCenter,
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
                    if (_isNavigating && _isFollowingUser) {
                      setState(() => _isFollowingUser = false);
                    }
                    if (_activeRoute == null) {
                      _reverseGeocodeDebounceTimer?.cancel();
                      _reverseGeocodeDebounceTimer =
                          Timer(const Duration(milliseconds: 800), () {
                        _reverseGeocode(camera.center);
                      });
                    }
                  }
                },
              ),
              children: [
                TileLayer(
                  tileProvider: widget.tileProvider,
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
                if (_activeRoute != null)
                  CircleLayer(
                    circles: _buildHazardAvoidanceCircles(),
                  ),
                if (_activeRoute != null)
                  PolylineLayer(
                    polylines: _buildRoutePolylines(),
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
          // LAYER 2-4: ROUTE PREVIEW / TURN-BY-TURN HUD OR STANDARD MAP UI
          // -------------------------------------------------------------------
          if (_activeRoute != null && _isNavigating)
            Positioned.fill(
              child: TurnByTurnNavigationHud(
                routeResult: _activeRoute!,
                currentStepIndex: _currentStepIndex,
                distanceToNextTurnMeters: _distanceToNextTurnMeters,
                remainingDistanceMeters: _remainingDistanceMeters,
                remainingDurationSeconds: _remainingDurationSeconds,
                isFollowingUser: _isFollowingUser,
                isSimulating: _isSimulating,
                hasArrived: _hasArrived,
                isRerouting: _isRecalculatingRoute,
                hazardWarningBanner: _hazardWarningBanner,
                onRecenter: () {
                  setState(() => _isFollowingUser = true);
                  _mapController.move(_currentLocation, 17.5);
                },
                onToggleSimulation: _toggleSimulation,
                onPrevStep: () => _jumpToStep(_currentStepIndex - 1),
                onNextStep: () => _jumpToStep(_currentStepIndex + 1),
                onRequestSafeReroute: () => _recalculateActiveRoute(
                  originOverride: _currentLocation,
                  originLabelOverride: 'Current GPS Position',
                  avoidHazardsOverride: true,
                  isHazardReroute: true,
                ),
                onStopNavigation: _stopTurnByTurnNavigation,
                onReportHazard: () {
                  showReportHazardDialog(
                    context,
                    initialLocation: _currentLocation,
                    onReportSubmitted: _addReportedHazard,
                  );
                },
                onFocusStep: (step) => _jumpToStep(step.index),
              ),
            )
          else if (_activeRoute != null)
            Positioned.fill(
              child: RoutePreviewOverlay(
                routeResult: _activeRoute!,
                isRecalculating: _isRecalculatingRoute,
                isRouteSaved: _isRouteSaved,
                onExitRoute: _exitRouteMode,
                onTapOrigin: () => _pickRouteEndpoint(isOrigin: true),
                onTapDestination: () => _pickRouteEndpoint(isOrigin: false),
                onSwapEndpoints: _swapRouteEndpoints,
                onTravelModeChanged: (mode) =>
                    _recalculateActiveRoute(modeOverride: mode),
                onAvoidHazardsChanged: (avoid) =>
                    _recalculateActiveRoute(avoidHazardsOverride: avoid),
                onCandidateSelected: (cand) {
                  setState(() {
                    _activeRoute = _activeRoute!.withSelectedCandidate(cand);
                    _syncNavigationMetricsFromRoute(cand);
                  });
                  _fitCameraToRoute(cand.polyline);
                },
                onSaveRoute: _saveActiveRoute,
                onStartTurnByTurn: _startTurnByTurnNavigation,
                onFocusStep: (step) => _mapController.move(step.location, 17.2),
              ),
            )
          else ...[
            _buildTopControls(),
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
            _buildFloatingActionButtons(screenSize),
            Positioned.fill(
              child: _buildDraggableScrollableSheet(),
            ),
          ],
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
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.bookmark_add_outlined,
                                        size: 18,
                                        color: _secondaryGrey,
                                      ),
                                      tooltip: 'Save Place',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          _saveLandmarkDirectly(landmark),
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
        height: 124,
        alignment: Alignment.center,
        child: _buildCurrentLocationMarker(),
      ),
    ];

    // 2. Route Origin, Active Turn, and Destination Pins when a route is active
    if (_activeRoute != null) {
      final poly = _activeRoute!.primaryRoute.polyline;
      final originPt = poly.isNotEmpty ? poly.first : _activeRoute!.origin;
      final destPt = poly.isNotEmpty ? poly.last : _activeRoute!.destination;

      if (!_isNavigating) {
        markers.add(
          Marker(
            point: originPt,
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.trip_origin_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (_activeRoute!.primaryRoute.steps.isNotEmpty) {
        final safeIdx = _currentStepIndex.clamp(
          0,
          _activeRoute!.primaryRoute.steps.length - 1,
        );
        final step = _activeRoute!.primaryRoute.steps[safeIdx];
        markers.add(
          Marker(
            point: step.location,
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                step.maneuverType.icon,
                size: 17,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),
        );
      }

      markers.add(
        Marker(
          point: destPt,
          width: 140,
          height: 72,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _primaryNavy,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  _activeRoute!.destinationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Selected Landmark Search Marker
    if (_selectedLandmark != null) {
      markers.add(_buildSelectedLandmarkMarker(_selectedLandmark!));
    }

    // 4. Filtered hazard markers
    for (final hazard in _filteredHazards) {
      markers.add(_buildHazardMarker(hazard));
    }

    return markers;
  }

  // Selected Landmark Marker with Info Callout, Directions, Save, & Dismiss
  Marker _buildSelectedLandmarkMarker(CebuLandmark landmark) {
    return Marker(
      point: landmark.location,
      width: 205,
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
                    onTap: () => _routeToLandmark(landmark),
                    child: const Icon(
                      Icons.directions_rounded,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => _saveLandmarkDirectly(landmark),
                    child: const Icon(
                      Icons.bookmark_add_outlined,
                      size: 15,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 4),
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
          _showHazardDetailSheet(hazard);
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
        _refreshReportedHazardDistances();
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

  String _formatRelativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.isNegative || diff.inMinutes < 2) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  _HazardItem _buildHazardItemFromReport(HazardReportData report) {
    final classification = MapScreen.classifyHazardForMap(report.category);
    Color themeColor = const Color(0xFFD97706);
    Color bgColor = const Color(0xFFFFFDF5);
    Color iconBgColor = const Color(0xFFFEF3C7);
    Color badgeBgColor = const Color(0xFFFEF3C7);

    final secLower = report.securityLevel.toLowerCase();
    if (secLower.contains('high') || secLower.contains('critical')) {
      themeColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFFF5F5);
      iconBgColor = const Color(0xFFFEE2E2);
      badgeBgColor = const Color(0xFFFEE2E2);
    } else if (secLower.contains('low')) {
      themeColor = const Color(0xFF3B82F6);
      bgColor = const Color(0xFFF5F9FF);
      iconBgColor = const Color(0xFFDBEAFE);
      badgeBgColor = const Color(0xFFDBEAFE);
    }

    final resolvedLocation = report.location ?? _currentLocation;
    final normalizedCategory = HazardCategories.normalize(report.category);
    final overline =
        HazardReportService.cleanCategory(normalizedCategory).toUpperCase();
    final stableId =
        (report.reportId != null && report.reportId!.trim().isNotEmpty)
            ? 'report_${report.reportId!.trim()}'
            : 'report_${report.timestamp.microsecondsSinceEpoch}_${report.title.hashCode}';

    return _HazardItem(
      id: stableId,
      reportId: report.reportId,
      overline: overline,
      title: report.title,
      subtitle: '${report.address} (${_formatRelativeTime(report.timestamp)})',
      description: report.description,
      address: report.address,
      imageUrl: report.imageUrl,
      confidence: report.confidence,
      distance: _formatDistanceTo(resolvedLocation),
      badgeText: report.securityLevel,
      themeColor: themeColor,
      bgColor: bgColor,
      iconBgColor: iconBgColor,
      badgeBgColor: badgeBgColor,
      icon: classification.icon,
      location: resolvedLocation,
      filterCategoryIndex: classification.filterCategoryIndex,
    );
  }

  void _addReportedHazard(HazardReportData report) {
    final newHazard = _buildHazardItemFromReport(report);

    setState(() {
      _upsertReportedHazardItem(newHazard, insertAtFront: true);
    });

    _mapController.move(newHazard.location, 17.0);
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

    _showHazardDetailSheet(hazard);
  }

  void _showHazardDetailSheet(_HazardItem hazard) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                if (hazard.imageUrl != null &&
                    hazard.imageUrl!.trim().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: Image.network(
                        hazard.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: hazard.bgColor,
                          alignment: Alignment.center,
                          child: Icon(
                            hazard.icon,
                            size: 42,
                            color: hazard.themeColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hazard.badgeBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${hazard.overline} • ${hazard.badgeText.toUpperCase()}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: hazard.themeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '✨ AI ${hazard.confidence}%',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  hazard.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),
                if (hazard.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    hazard.description.trim(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: _secondaryGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hazard.subtitle,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _secondaryGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      size: 15,
                      color: _secondaryGrey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hazard.distance,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
                showReportHazardDialog(
                  context,
                  initialLocation: _currentLocation,
                  onReportSubmitted: _addReportedHazard,
                );
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
    const distanceCalc = Distance();
    final nearbyWithin500m = _allHazards
        .where((h) => distanceCalc.distance(_currentLocation, h.location) <= 500)
        .toList();
    final hasHighNearby = nearbyWithin500m
        .any((h) => h.badgeText.toLowerCase().contains('high'));

    final Color statusBgColor = hasHighNearby
        ? const Color(0xFFFEE2E2)
        : (nearbyWithin500m.isNotEmpty
            ? const Color(0xFFFEF3C7)
            : _safeGreenBg);
    final Color statusIconColor = hasHighNearby
        ? const Color(0xFFEF4444)
        : (nearbyWithin500m.isNotEmpty
            ? const Color(0xFFD97706)
            : _safeGreen);
    final IconData statusIcon = nearbyWithin500m.isNotEmpty
        ? Icons.warning_amber_rounded
        : Icons.shield_outlined;
    final String statusTitle = hasHighNearby
        ? 'Caution: High-risk hazard nearby'
        : (nearbyWithin500m.isNotEmpty
            ? '${nearbyWithin500m.length} hazard${nearbyWithin500m.length == 1 ? '' : 's'} within 500m'
            : 'You are in a safe area');
    final String statusSubtitle = nearbyWithin500m.isNotEmpty
        ? 'Stay alert along nearby streets'
        : 'Safe route monitored in real time';

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

              // 2. Status Row: Dynamic area safety status based on nearby DB hazards
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusIconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusSubtitle,
                          style: const TextStyle(
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
                      for (final hazard in filtered.take(6)) ...[
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
                        _isLoadingReports && filtered.isEmpty
                            ? 'Loading hazards...'
                            : '${filtered.length} nearby hazard${filtered.length == 1 ? '' : 's'}',
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
              if (_isLoadingReports && filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _primaryNavy,
                      ),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
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
