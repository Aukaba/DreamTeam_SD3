import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../Authentication/auth_service.dart';
import '../Authentication/login_page.dart';
import '../map_screen.dart';
import '../navigation/app_navigation.dart';
import '../services/cebu_landmark_service.dart';
import '../services/hazard_report_service.dart';
import '../services/location_service.dart';
import '../services/safe_route_service.dart';
import '../services/saved_location_service.dart';
import '../widgets/custom_wavy_header.dart';
import '../widgets/route_place_picker_sheet.dart';
import '../widgets/safe_route_bottom_nav.dart';
import '../widgets/turn_by_turn_navigation_overlay.dart';

class RouteScreen extends StatefulWidget {
  final SafeRouteService? safeRouteService;
  final HazardReportService? hazardReportService;
  final SavedLocationService? savedLocationService;
  final LatLng? initialLocation;
  final bool skipLocationLookup;
  final bool skipAutoSuggestion;

  const RouteScreen({
    super.key,
    this.safeRouteService,
    this.hazardReportService,
    this.savedLocationService,
    this.initialLocation,
    this.skipLocationLookup = false,
    this.skipAutoSuggestion = false,
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  // Persisted route planning preferences across tab switches
  static bool _avoidHazard = true;
  static RouteTravelMode _travelMode = RouteTravelMode.walking;

  // System back press and logout guard
  DateTime? _lastBackPressedAt;
  final AuthService _authService = AuthService();

  // Services
  late final HazardReportService _hazardReportService;
  late final SafeRouteService _safeRouteService;
  late final SavedLocationService _savedLocationService;
  StreamSubscription<HazardReportData>? _hazardStreamSub;

  // Endpoint & Route State
  late LatLng _currentLocation;
  late LatLng _originLocation;
  String _originLabel = 'Your current location';
  bool _originUsesCurrentGps = true;

  LatLng? _destinationLocation;
  String? _destinationLabel;

  PlannedRouteResult? _plannedRoute;
  bool _isFindingRoute = false;
  bool _isSavedCurrentPlan = false;
  bool _isLoadingSavedRoutes = true;
  bool _isNavigatingToMap = false;
  bool _previewTileError = false;

  List<HazardReportData> _activeHazards = <HazardReportData>[];
  List<SavedRouteRecord> _savedRoutes = <SavedRouteRecord>[];
  List<SavedLocation> _savedPlaces = <SavedLocation>[];

  // Design Colors matching Figma
  static const Color _bgWarm = Color(0xFFF8F7F4);
  static const Color _primaryNavy = Color(0xFF263354);
  static const Color _secondaryGrey = Color(0xFF8A94A6);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _inputBg = Color(0xFFF4F6F9);
  static const Color _accentBlue = Color(0xFF4A90E2);
  static const Color _lightBlue = Color(0xFFEBF3FE);
  static const Color _safeGreen = Color(0xFF2E7D32);
  static const Color _safeGreenBg = Color(0xFFE8F5E9);
  static const Color _warningAmber = Color(0xFFD97706);
  static const Color _warningAmberBg = Color(0xFFFEF3C7);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _dangerRedBg = Color(0xFFFEE2E2);

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation ?? LocationService.defaultLocation;
    _originLocation = _currentLocation;
    _hazardReportService = widget.hazardReportService ?? HazardReportService();
    _safeRouteService = widget.safeRouteService ??
        SafeRouteService(hazardReportService: _hazardReportService);
    _savedLocationService =
        widget.savedLocationService ?? SavedLocationService();

    _hazardStreamSub = HazardReportService.reportStream.listen((_) {
      _refreshDataAndReevaluate();
    });

    _initializeScreenData();
    if (!widget.skipLocationLookup) {
      _resolveDeviceGps();
    }
  }

  @override
  void dispose() {
    _hazardStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveDeviceGps() async {
    final lastKnown = await LocationService.getLastKnownLocation();
    if (lastKnown != null && mounted) {
      setState(() {
        _currentLocation = lastKnown;
        if (_originUsesCurrentGps) {
          _originLocation = lastKnown;
        }
      });
    }
    final live = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _currentLocation = live;
      if (_originUsesCurrentGps) {
        _originLocation = live;
      }
    });
  }

  Future<void> _initializeScreenData() async {
    final hazardsFuture =
        _hazardReportService.fetchReports(limit: 120, activeOnly: true);
    Future<List<SavedLocation>> placesFuture;
    try {
      placesFuture = _savedLocationService.getSavedLocations();
    } catch (_) {
      placesFuture = Future<List<SavedLocation>>.value(<SavedLocation>[]);
    }

    final hazards = await hazardsFuture;
    final savedRoutes =
        await _safeRouteService.fetchSavedRoutes(activeHazards: hazards);
    final places = await placesFuture;

    if (!mounted) return;
    setState(() {
      _activeHazards = hazards;
      _savedRoutes = savedRoutes;
      _savedPlaces = places;
      _isLoadingSavedRoutes = false;
    });

    // Populate Suggested Route automatically if user hasn't picked a destination yet
    if (!widget.skipAutoSuggestion && _destinationLocation == null) {
      if (savedRoutes.isNotEmpty) {
        final top = savedRoutes.first;
        unawaited(
          _computePlannedRoute(
            origin: top.origin,
            originLabel: top.originLabel,
            destination: top.destination,
            destinationLabel: top.destinationLabel,
            savedRouteId: top.id,
            updateInputs: false,
          ),
        );
      } else if (places.isNotEmpty) {
        final place = places.first;
        unawaited(
          _computePlannedRoute(
            origin: _originLocation,
            originLabel: _originLabel,
            destination: place.location,
            destinationLabel: place.title,
            updateInputs: false,
          ),
        );
      } else if (CebuLandmarkService.landmarks.isNotEmpty) {
        final fallbackLm = CebuLandmarkService.landmarks.firstWhere(
          (l) =>
              const Distance().distance(_originLocation, l.location) > 400 &&
              const Distance().distance(_originLocation, l.location) < 6000,
          orElse: () => CebuLandmarkService.landmarks.first,
        );
        unawaited(
          _computePlannedRoute(
            origin: _originLocation,
            originLabel: _originLabel,
            destination: fallbackLm.location,
            destinationLabel: fallbackLm.name,
            updateInputs: false,
          ),
        );
      }
    }
  }

  Future<void> _refreshDataAndReevaluate() async {
    final hazards =
        await _hazardReportService.fetchReports(limit: 120, activeOnly: true);
    final routes =
        await _safeRouteService.fetchSavedRoutes(activeHazards: hazards);
    if (!mounted) return;
    setState(() {
      _activeHazards = hazards;
      _savedRoutes = routes;
    });
    if (_plannedRoute != null) {
      await _computePlannedRoute(
        origin: _plannedRoute!.origin,
        originLabel: _plannedRoute!.originLabel,
        destination: _plannedRoute!.destination,
        destinationLabel: _plannedRoute!.destinationLabel,
        savedRouteId: _plannedRoute!.savedRouteId,
        updateInputs: false,
      );
    }
  }

  Future<PlannedRouteResult?> _computePlannedRoute({
    required LatLng origin,
    required String originLabel,
    required LatLng destination,
    required String destinationLabel,
    String? savedRouteId,
    bool updateInputs = true,
  }) async {
    if (!mounted) return null;
    setState(() {
      _isFindingRoute = true;
      if (updateInputs) {
        _originLocation = origin;
        _originLabel = originLabel;
        _destinationLocation = destination;
        _destinationLabel = destinationLabel;
      }
    });

    final result = await _safeRouteService.findSafeRoute(
      origin: origin,
      originLabel: originLabel,
      destination: destination,
      destinationLabel: destinationLabel,
      travelMode: _travelMode,
      avoidHazards: _avoidHazard,
    );

    if (!mounted) return null;
    final withSavedId =
        savedRouteId != null ? result.copyWith(savedRouteId: savedRouteId) : result;
    setState(() {
      _plannedRoute = withSavedId;
      _isFindingRoute = false;
      _isSavedCurrentPlan = savedRouteId != null;
    });
    return withSavedId;
  }

  Future<void> _pickOrigin() async {
    final selected = await showRoutePlacePickerSheet(
      context,
      title: 'Choose Starting Point',
      currentLocation: _currentLocation,
      allowCurrentLocationOption: true,
      savedLocationService: _savedLocationService,
    );
    if (selected == null || !mounted) return;

    setState(() {
      _originLocation = selected.location;
      _originLabel = selected.label;
      _originUsesCurrentGps = selected.isCurrentLocation;
      _isSavedCurrentPlan = false;
    });

    if (_destinationLocation != null && _destinationLabel != null) {
      await _computePlannedRoute(
        origin: _originLocation,
        originLabel: _originLabel,
        destination: _destinationLocation!,
        destinationLabel: _destinationLabel!,
      );
    }
  }

  Future<void> _pickDestination({bool launchMapAfterPick = false}) async {
    final selected = await showRoutePlacePickerSheet(
      context,
      title: 'Choose Destination',
      currentLocation: _currentLocation,
      allowCurrentLocationOption: false,
      savedLocationService: _savedLocationService,
    );
    if (selected == null || !mounted) return;

    final computed = await _computePlannedRoute(
      origin: _originLocation,
      originLabel: _originLabel,
      destination: selected.location,
      destinationLabel: selected.label,
    );

    if (launchMapAfterPick && computed != null && mounted) {
      await _openRouteOnMap(computed, autoStartNavigation: false);
    }
  }

  Future<void> _swapOriginAndDestination() async {
    if (_destinationLocation == null || _destinationLabel == null) return;
    final prevOrigin = _originLocation;
    final prevOriginLabel = _originLabel;
    final prevDest = _destinationLocation!;
    final prevDestLabel = _destinationLabel!;

    setState(() {
      _originUsesCurrentGps = false;
      _isSavedCurrentPlan = false;
    });

    await _computePlannedRoute(
      origin: prevDest,
      originLabel: prevDestLabel,
      destination: prevOrigin,
      destinationLabel: prevOriginLabel,
    );
  }

  Future<void> _onFindRoutePressed() async {
    if (_isFindingRoute) return;
    if (_destinationLocation == null || _destinationLabel == null) {
      await _pickDestination(launchMapAfterPick: true);
      return;
    }

    final result = await _computePlannedRoute(
      origin: _originLocation,
      originLabel: _originLabel,
      destination: _destinationLocation!,
      destinationLabel: _destinationLabel!,
    );
    if (result != null && mounted) {
      await _openRouteOnMap(result, autoStartNavigation: false);
    }
  }

  Future<void> _openRouteOnMap(
    PlannedRouteResult route, {
    required bool autoStartNavigation,
  }) async {
    if (_isNavigatingToMap) return;
    _isNavigatingToMap = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLocation: _currentLocation,
          hazardReportService: _hazardReportService,
          safeRouteService: _safeRouteService,
          initialRoute: route,
          autoStartNavigation: autoStartNavigation,
        ),
      ),
    );
    if (mounted) {
      setState(() => _isNavigatingToMap = false);
      await _refreshDataAndReevaluate();
    }
  }

  void _navigateToPlainMap() {
    if (_isNavigatingToMap) return;
    if (_plannedRoute != null) {
      _openRouteOnMap(_plannedRoute!, autoStartNavigation: false);
      return;
    }
    _isNavigatingToMap = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLocation: _currentLocation,
          hazardReportService: _hazardReportService,
          safeRouteService: _safeRouteService,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isNavigatingToMap = false);
        _refreshDataAndReevaluate();
      }
    });
  }

  Future<void> _saveCurrentPlannedRoute() async {
    final planned = _plannedRoute;
    if (planned == null) return;
    final saved = await _safeRouteService.savePlannedRoute(planned: planned);
    final updatedList =
        await _safeRouteService.fetchSavedRoutes(activeHazards: _activeHazards);
    if (!mounted) return;
    setState(() {
      _plannedRoute = planned.copyWith(savedRouteId: saved.id);
      _isSavedCurrentPlan = true;
      _savedRoutes = updatedList;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "${saved.title}" to Saved Routes'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchSavedRoute(
    SavedRouteRecord record, {
    required bool startNavigationImmediately,
  }) async {
    setState(() {
      _avoidHazard = record.avoidHazards;
      _travelMode = record.travelMode;
      _isFindingRoute = true;
    });

    PlannedRouteResult routeToOpen;
    try {
      final liveResult = await _safeRouteService.findSafeRoute(
        origin: record.origin,
        originLabel: record.originLabel,
        destination: record.destination,
        destinationLabel: record.destinationLabel,
        travelMode: record.travelMode,
        avoidHazards: record.avoidHazards,
      );
      routeToOpen = liveResult.copyWith(savedRouteId: record.id);
    } catch (_) {
      routeToOpen = record.toCachedPlannedResult(activeHazards: _activeHazards);
    }

    if (!mounted) return;
    setState(() {
      _isFindingRoute = false;
      _plannedRoute = routeToOpen;
      _isSavedCurrentPlan = true;
      _originLocation = record.origin;
      _originLabel = record.originLabel;
      _originUsesCurrentGps = false;
      _destinationLocation = record.destination;
      _destinationLabel = record.destinationLabel;
    });

    await _openRouteOnMap(
      routeToOpen,
      autoStartNavigation: startNavigationImmediately,
    );
  }

  Future<void> _showSavedRouteMenu(SavedRouteRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _primaryNavy,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.navigation_rounded,
                    color: _accentBlue,
                  ),
                  title: const Text(
                    'Start Turn-by-Turn Navigation',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _primaryNavy,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _launchSavedRoute(record, startNavigationImmediately: true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined, color: _primaryNavy),
                  title: const Text(
                    'Preview Route on Map',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: _primaryNavy,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _launchSavedRoute(record, startNavigationImmediately: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: _primaryNavy),
                  title: const Text(
                    'Rename Saved Route',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: _primaryNavy,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _promptRenameSavedRoute(record);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete Saved Route',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _safeRouteService.deleteSavedRoute(record.id);
                    final refreshed = await _safeRouteService.fetchSavedRoutes(
                      activeHazards: _activeHazards,
                    );
                    if (!mounted) return;
                    setState(() {
                      _savedRoutes = refreshed;
                      if (_plannedRoute?.savedRouteId == record.id) {
                        _isSavedCurrentPlan = false;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptRenameSavedRoute(SavedRouteRecord record) async {
    final controller = TextEditingController(text: record.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Rename Route',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _primaryNavy,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Home to University',
            filled: true,
            fillColor: _inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: _secondaryGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await _safeRouteService.renameSavedRoute(record.id, newName);
      final refreshed = await _safeRouteService.fetchSavedRoutes(
        activeHazards: _activeHazards,
      );
      if (mounted) {
        setState(() => _savedRoutes = refreshed);
      }
    }
  }

  void _cycleTravelMode() {
    const modes = RouteTravelMode.values;
    final next = modes[(_travelMode.index + 1) % modes.length];
    setState(() {
      _travelMode = next;
    });
    if (_destinationLocation != null && _destinationLabel != null) {
      _computePlannedRoute(
        origin: _originLocation,
        originLabel: _originLabel,
        destination: _destinationLocation!,
        destinationLabel: _destinationLabel!,
        savedRouteId: _plannedRoute?.savedRouteId,
      );
    } else if (_plannedRoute != null) {
      _computePlannedRoute(
        origin: _plannedRoute!.origin,
        originLabel: _plannedRoute!.originLabel,
        destination: _plannedRoute!.destination,
        destinationLabel: _plannedRoute!.destinationLabel,
        savedRouteId: _plannedRoute!.savedRouteId,
        updateInputs: false,
      );
    }
  }

  Future<bool> _showLogoutDialog() async {
    final nav = Navigator.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Log out?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _primaryNavy,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _secondaryGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _secondaryGrey,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext, true);
              await _authService.signOut();
              if (mounted) {
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Log out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          return;
        }
        await _showLogoutDialog();
      },
      child: Scaffold(
        backgroundColor: _bgWarm,
        body: RefreshIndicator(
          color: _primaryNavy,
          onRefresh: _refreshDataAndReevaluate,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CustomWavyHeader(),
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderTextSection(),
                        const SizedBox(height: 18),
                        _buildRoutePlanningCard(),
                        const SizedBox(height: 24),
                        _buildSuggestedRouteSection(),
                        const SizedBox(height: 24),
                        _buildSavedRoutesSection(),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeRouteBottomNav(
          currentIndex: 1,
          onTap: (index) =>
              AppNavigation.navigateTo(context, index, currentIndex: 1),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. HEADER TEXT SECTION
  // ---------------------------------------------------------------------------
  Widget _buildHeaderTextSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MY ROUTES',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _secondaryGrey,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Plan your route,\ntravel safer.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Find the safest way to your destination with real-time hazard avoidance and turn-by-turn navigation.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _secondaryGrey,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ROUTE PLANNING CARD
  // ---------------------------------------------------------------------------
  Widget _buildRoutePlanningCard() {
    final hasDestination =
        _destinationLabel != null && _destinationLabel!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "From" Input Row
          _buildLocationInputRow(
            icon: Icons.location_on_rounded,
            iconColor: _accentBlue,
            iconBgColor: _lightBlue,
            label: 'From',
            value: _originLabel,
            isPlaceholder: false,
            onTap: _pickOrigin,
            trailingAction: hasDestination
                ? IconButton(
                    icon: const Icon(
                      Icons.swap_vert_rounded,
                      color: _primaryNavy,
                      size: 19,
                    ),
                    tooltip: 'Swap From & To',
                    onPressed: _swapOriginAndDestination,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
          ),

          const SizedBox(height: 10),

          // "To" Input Row
          _buildLocationInputRow(
            icon: Icons.flag_rounded,
            iconColor: _accentBlue,
            iconBgColor: _lightBlue,
            label: 'To',
            value: hasDestination ? _destinationLabel! : 'Enter destination',
            isPlaceholder: !hasDestination,
            onTap: () => _pickDestination(launchMapAfterPick: false),
          ),

          // Quick Saved Places / Popular Destination Chips
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_savedPlaces.isNotEmpty)
                  for (final sp in _savedPlaces.take(4)) ...[
                    _buildQuickDestinationChip(
                      icon: sp.icon,
                      label: sp.title,
                      onTap: () => _computePlannedRoute(
                        origin: _originLocation,
                        originLabel: _originLabel,
                        destination: sp.location,
                        destinationLabel: sp.title,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ]
                else
                  for (final preset in CebuLandmarkService.landmarks.take(3)) ...[
                    _buildQuickDestinationChip(
                      icon: preset.icon,
                      label: preset.name,
                      onTap: () => _computePlannedRoute(
                        origin: _originLocation,
                        originLabel: _originLabel,
                        destination: preset.location,
                        destinationLabel: preset.name,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Bottom Action Controls: Avoid Hazard toggle, Mode chip, Find Route button
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                // a) Avoid Hazard switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.alt_route_rounded,
                      size: 15,
                      color: _secondaryGrey,
                    ),
                    const SizedBox(width: 4),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avoid',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _primaryNavy,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Hazard',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _primaryNavy,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 5),
                    _buildCustomCompactSwitch(
                      value: _avoidHazard,
                      onChanged: (val) {
                        setState(() {
                          _avoidHazard = val;
                        });
                        if (_destinationLocation != null &&
                            _destinationLabel != null) {
                          _computePlannedRoute(
                            origin: _originLocation,
                            originLabel: _originLabel,
                            destination: _destinationLocation!,
                            destinationLabel: _destinationLabel!,
                            savedRouteId: _plannedRoute?.savedRouteId,
                          );
                        } else if (_plannedRoute != null) {
                          _computePlannedRoute(
                            origin: _plannedRoute!.origin,
                            originLabel: _plannedRoute!.originLabel,
                            destination: _plannedRoute!.destination,
                            destinationLabel: _plannedRoute!.destinationLabel,
                            savedRouteId: _plannedRoute!.savedRouteId,
                            updateInputs: false,
                          );
                        }
                      },
                    ),
                  ],
                ),

                // b) Interactive Travel Mode chip (Walking / Cycling / Driving)
                InkWell(
                  onTap: _cycleTravelMode,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _lightBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _travelMode.icon,
                          size: 15,
                          color: _accentBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _travelMode.label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _accentBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // c) Find Route button
                ElevatedButton(
                  onPressed: _isFindingRoute ? null : _onFindRoutePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isFindingRoute) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _isFindingRoute ? 'Finding...' : 'Find Route',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (!_isFindingRoute) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDestinationChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _inputBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: _primaryNavy),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 125),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: _primaryNavy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInputRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
    required bool isPlaceholder,
    required VoidCallback onTap,
    Widget? trailingAction,
  }) {
    return Material(
      color: _inputBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight:
                            isPlaceholder ? FontWeight.w400 : FontWeight.w600,
                        color: isPlaceholder ? _secondaryGrey : _primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingAction != null) ...[
                trailingAction,
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.arrow_forward_rounded,
                color: _primaryNavy,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCompactSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? _primaryNavy : const Color(0xFFE2E8F0),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 17,
            height: 17,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. SUGGESTED ROUTE SECTION (LIVE HAZARD-AWARE ROUTE + TURN-BY-TURN LAUNCH)
  // ---------------------------------------------------------------------------
  Widget _buildSuggestedRouteSection() {
    final planned = _plannedRoute;
    final primary = planned?.primaryRoute;
    final onRouteCount = primary?.hazardsOnRoute.length ?? 0;
    final avoidedCount = planned?.hazardsAvoided ?? 0;

    String headline = 'Safer route found!';
    String subline = 'Select a destination above to calculate safe roads';
    String badgeLabel = 'Low risk area →';
    Color badgeBg = _safeGreenBg;
    Color badgeFg = _safeGreen;
    IconData badgeIcon = Icons.eco_rounded;

    if (planned != null && primary != null) {
      subline =
          '${primary.distanceAndTimeLabel} · ${planned.destinationLabel}';
      if (onRouteCount == 0 && avoidedCount > 0) {
        headline = 'Safer detour route found!';
        badgeLabel = 'Avoided $avoidedCount hazard${avoidedCount == 1 ? '' : 's'}';
      } else if (onRouteCount == 0) {
        headline = 'Hazard-free route ready!';
        badgeLabel = '0 hazards on road';
      } else if (primary.riskLevel == RouteRiskLevel.high) {
        headline = 'Caution along route';
        badgeLabel = '$onRouteCount hazard${onRouteCount == 1 ? '' : 's'} nearby';
        badgeBg = _dangerRedBg;
        badgeFg = _dangerRed;
        badgeIcon = Icons.warning_amber_rounded;
      } else {
        headline = 'Lowest-risk route selected';
        badgeLabel = '$onRouteCount hazard${onRouteCount == 1 ? '' : 's'} nearby';
        badgeBg = _warningAmberBg;
        badgeFg = _warningAmber;
        badgeIcon = Icons.info_outline_rounded;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Suggested Route',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _navigateToPlainMap,
              child: const Text(
                'View on map →',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _secondaryGrey,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Half: Live Route Map Preview (falls back to vector snippet when no route yet)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: GestureDetector(
                  onTap: _navigateToPlainMap,
                  child: SizedBox(
                    height: 146,
                    width: double.infinity,
                    child: (planned != null &&
                            primary != null &&
                            primary.polyline.length >= 2 &&
                            !_previewTileError)
                        ? _buildLiveRouteMiniMap(planned, primary)
                        : CustomPaint(
                            painter: _SuggestedRouteMapSnippetPainter(),
                          ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: _lightBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: RouteNavIcon(
                              color: _accentBlue,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headline,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 13, color: badgeFg),
                              const SizedBox(width: 4),
                              Text(
                                badgeLabel,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: badgeFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Turn-by-Turn Steps Preview & Action Buttons when route is ready
                    if (planned != null && primary != null) ...[
                      if (primary.steps.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _inputBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'TURN-BY-TURN PREVIEW (${primary.steps.length} STEPS)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _secondaryGrey,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => showRouteStepsBottomSheet(
                                      context,
                                      route: primary,
                                      currentStepIndex: 0,
                                    ),
                                    child: const Text(
                                      'All steps →',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: _accentBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              for (final step in primary.steps.take(2))
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Icon(
                                        step.maneuverType.icon,
                                        size: 15,
                                        color: _primaryNavy,
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          step.instruction,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: _primaryNavy,
                                          ),
                                        ),
                                      ),
                                      if (step.distanceMeters > 0)
                                        Text(
                                          step.formattedDistance,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 10.5,
                                            color: _secondaryGrey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saveCurrentPlannedRoute,
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  _isSavedCurrentPlan ? _safeGreen : _primaryNavy,
                              side: BorderSide(
                                color: _isSavedCurrentPlan
                                    ? _safeGreen
                                    : const Color(0xFFE2E8F0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: Icon(
                              _isSavedCurrentPlan
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_add_outlined,
                              size: 16,
                            ),
                            label: Text(
                              _isSavedCurrentPlan ? 'Saved' : 'Save Route',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openRouteOnMap(
                                planned,
                                autoStartNavigation: true,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.navigation_rounded,
                                size: 17,
                              ),
                              label: const Text(
                                'Start Turn-by-Turn',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveRouteMiniMap(
    PlannedRouteResult planned,
    RouteCandidate primary,
  ) {
    final poly = primary.polyline;
    final midPt = poly[poly.length ~/ 2];

    return IgnorePointer(
      child: FlutterMap(
        key: ValueKey<String>(
          'mini_${planned.origin.latitude}_${planned.destination.latitude}_${primary.id}',
        ),
        options: MapOptions(
          initialCenter: midPt,
          initialZoom: 13.8,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dreamteam.sd3',
            errorTileCallback: (_, __, ___) {
              if (!_previewTileError && mounted) {
                setState(() => _previewTileError = true);
              }
            },
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: poly,
                strokeWidth: 6.5,
                color: Colors.white,
              ),
              Polyline(
                points: poly,
                strokeWidth: 4.0,
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: poly.first,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              Marker(
                point: poly.last,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. SAVED ROUTES SECTION (SUPABASE DB + LIVE HAZARD RE-EVALUATION)
  // ---------------------------------------------------------------------------
  Widget _buildSavedRoutesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Saved Routes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
            ),
            if (_savedRoutes.length > 3) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showAllSavedRoutesSheet,
                child: Text(
                  'See all (${_savedRoutes.length}) →',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _secondaryGrey,
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        if (_isLoadingSavedRoutes)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _primaryNavy,
                ),
              ),
            ),
          )
        else if (_savedRoutes.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: _lightBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark_border_rounded,
                    color: _accentBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No saved routes yet',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Plan a trip above and tap "Save Route" to monitor daily commutes against live hazards.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: _secondaryGrey,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < _savedRoutes.take(4).length; i++) ...[
            _buildSavedRouteCardFromRecord(_savedRoutes[i]),
            if (i < _savedRoutes.take(4).length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  void _showAllSavedRoutesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bgWarm,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'All Saved Routes',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _primaryNavy,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: _savedRoutes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final rec = _savedRoutes[idx];
                      return _buildSavedRouteCardFromRecord(
                        rec,
                        onCloseParentSheet: () => Navigator.pop(sheetCtx),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedRouteCardFromRecord(
    SavedRouteRecord record, {
    VoidCallback? onCloseParentSheet,
  }) {
    Color statusColor = _primaryNavy;
    Color statusBgColor = _lightBlue;
    String statusText = 'Safe';

    if (record.riskLevel == RouteRiskLevel.high) {
      statusColor = _dangerRed;
      statusBgColor = _dangerRedBg;
      statusText = 'High risk (${record.hazardCount})';
    } else if (record.riskLevel == RouteRiskLevel.moderate) {
      statusColor = _warningAmber;
      statusBgColor = _warningAmberBg;
      statusText = 'Moderate risk';
    } else if (record.riskLevel == RouteRiskLevel.low) {
      statusColor = _safeGreen;
      statusBgColor = _safeGreenBg;
      statusText = 'Low risk';
    }

    return _buildSavedRouteCard(
      title: record.title,
      distanceAndTime:
          '${record.distanceAndTimeLabel} · ${record.travelMode.label}',
      statusText: statusText,
      statusColor: statusColor,
      statusBgColor: statusBgColor,
      modeIcon: record.travelMode.icon,
      onTap: () {
        onCloseParentSheet?.call();
        _launchSavedRoute(record, startNavigationImmediately: true);
      },
      onMoreTap: () {
        onCloseParentSheet?.call();
        _showSavedRouteMenu(record);
      },
    );
  }

  Widget _buildSavedRouteCard({
    required String title,
    required String distanceAndTime,
    required String statusText,
    required Color statusColor,
    required Color statusBgColor,
    IconData modeIcon = Icons.home_outlined,
    VoidCallback? onTap,
    VoidCallback? onMoreTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _lightBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    modeIcon,
                    color: _primaryNavy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distanceAndTime,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RouteNavIcon(
                              color: statusColor,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                        color: _secondaryGrey,
                        size: 18,
                      ),
                      onPressed: onMoreTap,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.navigation_rounded,
                      color: _primaryNavy,
                      size: 18,
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
// SUGGESTED ROUTE MAP SNIPPET PAINTER (Fallback Vector Preview)
// -----------------------------------------------------------------------------
class _SuggestedRouteMapSnippetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final landPaint = Paint()..color = const Color(0xFFF3F5F7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    final parkPaint = Paint()..color = const Color(0xFFE5EFE3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.04, size.height * 0.15, 60, 40),
        const Radius.circular(6),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.32, size.height * 0.10, 48, 30),
        const Radius.circular(6),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.58, size.height * 0.12, 54, 34),
        const Radius.circular(6),
      ),
      parkPaint,
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final roadBorder = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    final roads = [
      Path()
        ..moveTo(-10, size.height * 0.40)
        ..lineTo(size.width * 0.50, size.height * 0.25)
        ..lineTo(size.width * 0.80, size.height * 0.15),
      Path()
        ..moveTo(size.width * 0.18, 0)
        ..lineTo(size.width * 0.25, size.height + 10),
      Path()
        ..moveTo(size.width * 0.45, 0)
        ..lineTo(size.width * 0.42, size.height + 10),
      Path()
        ..moveTo(size.width * 0.70, 0)
        ..lineTo(size.width * 0.65, size.height + 10),
    ];

    for (final r in roads) {
      canvas.drawPath(r, roadBorder);
      canvas.drawPath(r, roadPaint);
    }

    final waterPaint = Paint()..color = const Color(0xFF98CBEE);
    final waterPath = Path()
      ..moveTo(size.width * 0.68, size.height)
      ..cubicTo(
        size.width * 0.73,
        size.height * 0.80,
        size.width * 0.82,
        size.height * 0.72,
        size.width * 0.88,
        size.height * 0.60,
      )
      ..cubicTo(
        size.width * 0.92,
        size.height * 0.52,
        size.width * 0.94,
        size.height * 0.50,
        size.width + 10,
        size.height * 0.46,
      )
      ..lineTo(size.width + 10, size.height + 10)
      ..lineTo(size.width * 0.68, size.height + 10)
      ..close();

    canvas.drawPath(waterPath, waterPaint);

    final routePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routePath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.72)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.70,
        size.width * 0.28,
        size.height * 0.55,
        size.width * 0.38,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.44,
        size.height * 0.50,
        size.width * 0.48,
        size.height * 0.62,
        size.width * 0.56,
        size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.48,
        size.width * 0.72,
        size.height * 0.58,
        size.width * 0.83,
        size.height * 0.36,
      );

    canvas.drawPath(routePath, routePaint);

    final startOffset = Offset(size.width * 0.16, size.height * 0.72);
    canvas.drawCircle(
      startOffset,
      13,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.25),
    );
    canvas.drawCircle(startOffset, 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      startOffset,
      4,
      Paint()..color = const Color(0xFF2563EB),
    );

    _drawHazardBadge(
      canvas,
      Offset(size.width * 0.38, size.height * 0.44),
      color: const Color(0xFFEF4444),
      bgColor: const Color(0xFFFEE2E2),
    );
    _drawShieldBadge(
      canvas,
      Offset(size.width * 0.51, size.height * 0.56),
      color: const Color(0xFF2563EB),
      bgColor: const Color(0xFFDBEAFE),
    );
    _drawHazardBadge(
      canvas,
      Offset(size.width * 0.65, size.height * 0.46),
      color: const Color(0xFFD97706),
      bgColor: const Color(0xFFFEF3C7),
    );

    final endOffset = Offset(size.width * 0.83, size.height * 0.36);
    _drawDestinationPin(canvas, endOffset);
  }

  void _drawHazardBadge(
    Canvas canvas,
    Offset center, {
    required Color color,
    required Color bgColor,
  }) {
    final badgePaint = Paint()..color = bgColor;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 18, height: 18),
        const Radius.circular(5),
      ),
      badgePaint,
    );

    final tri = Path()
      ..moveTo(center.dx, center.dy - 5)
      ..lineTo(center.dx + 4.5, center.dy + 4)
      ..lineTo(center.dx - 4.5, center.dy + 4)
      ..close();
    canvas.drawPath(tri, strokePaint);
  }

  void _drawShieldBadge(
    Canvas canvas,
    Offset center, {
    required Color color,
    required Color bgColor,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 18, height: 18),
        const Radius.circular(5),
      ),
      Paint()..color = bgColor,
    );

    final shield = Path()
      ..moveTo(center.dx, center.dy - 4.5)
      ..lineTo(center.dx + 4, center.dy - 2.5)
      ..lineTo(center.dx + 4, center.dy + 1)
      ..cubicTo(
        center.dx + 3.5,
        center.dy + 4,
        center.dx,
        center.dy + 5,
        center.dx,
        center.dy + 5,
      )
      ..cubicTo(
        center.dx,
        center.dy + 5,
        center.dx - 3.5,
        center.dy + 4,
        center.dx - 4,
        center.dy + 1,
      )
      ..lineTo(center.dx - 4, center.dy - 2.5)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawDestinationPin(Canvas canvas, Offset center) {
    final pinPaint = Paint()..color = const Color(0xFF263354);
    final pinPath = Path()
      ..moveTo(center.dx, center.dy + 4)
      ..lineTo(center.dx - 5, center.dy - 5)
      ..arcToPoint(
        Offset(center.dx + 5, center.dy - 5),
        radius: const Radius.circular(5),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(pinPath, pinPaint);
    canvas.drawCircle(
      Offset(center.dx, center.dy - 5),
      2.2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
