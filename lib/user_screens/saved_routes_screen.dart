import 'package:flutter/material.dart';
import '../map_screen.dart';
import '../services/hazard_report_service.dart';
import '../services/location_service.dart';
import '../services/safe_route_service.dart';
import '../widgets/route_place_picker_sheet.dart';
import 'route_screen.dart';

class SavedRoutesScreen extends StatefulWidget {
  final SafeRouteService? safeRouteService;
  final HazardReportService? hazardReportService;

  const SavedRoutesScreen({
    super.key,
    this.safeRouteService,
    this.hazardReportService,
  });

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  static const Color _primaryNavy = Color(0xFF233253);
  static const Color _secondaryGrey = Color(0xFF8A94A6);
  static const Color _bgBeige = Color(0xFFFAF8F5);
  static const Color _accentBlue = Color(0xFF1E6FD9);
  static const Color _lightBlue = Color(0xFFEBF3FC);

  late final HazardReportService _hazardReportService;
  late final SafeRouteService _safeRouteService;

  List<SavedRouteRecord> _savedRoutes = const <SavedRouteRecord>[];
  List<HazardReportData> _activeHazards = const <HazardReportData>[];
  bool _isLoading = true;
  bool _isSavingRoute = false;

  @override
  void initState() {
    super.initState();
    _hazardReportService = widget.hazardReportService ?? HazardReportService();
    _safeRouteService = widget.safeRouteService ??
        SafeRouteService(hazardReportService: _hazardReportService);
    _loadSavedRoutes();
  }

  Future<void> _loadSavedRoutes() async {
    if (mounted && _savedRoutes.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final hazards = await _hazardReportService.fetchReports(
        limit: 120,
        activeOnly: true,
      );
      final routes = await _safeRouteService.fetchSavedRoutes(
        activeHazards: hazards,
      );
      if (!mounted) return;
      setState(() {
        _activeHazards = hazards;
        _savedRoutes = routes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _planAndSaveNewRoute() async {
    if (_isSavingRoute) return;
    final currentPos = await LocationService.getLastKnownLocation() ??
        LocationService.defaultLocation;
    if (!mounted) return;

    final originPick = await showRoutePlacePickerSheet(
      context,
      title: 'Choose Starting Point',
      currentLocation: currentPos,
      allowCurrentLocationOption: true,
    );
    if (originPick == null || !mounted) return;

    final destPick = await showRoutePlacePickerSheet(
      context,
      title: 'Choose Destination to Save',
      currentLocation: currentPos,
      allowCurrentLocationOption: false,
    );
    if (destPick == null || !mounted) return;

    setState(() => _isSavingRoute = true);
    try {
      final planned = await _safeRouteService.findSafeRoute(
        origin: originPick.location,
        originLabel: originPick.label,
        destination: destPick.location,
        destinationLabel: destPick.label,
        travelMode: RouteTravelMode.walking,
        avoidHazards: true,
      );
      final saved = await _safeRouteService.savePlannedRoute(planned: planned);
      await _loadSavedRoutes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${saved.title}"'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save route: $e'),
          backgroundColor: const Color(0xFFD9383A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingRoute = false);
      }
    }
  }

  Future<void> _openSavedRouteOnMap(
    SavedRouteRecord record, {
    required bool autoStartNavigation,
  }) async {
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLocation: record.origin,
          hazardReportService: _hazardReportService,
          safeRouteService: _safeRouteService,
          initialRoute: routeToOpen,
          autoStartNavigation: autoStartNavigation,
        ),
      ),
    );
    if (mounted) {
      await _loadSavedRoutes();
    }
  }

  Future<void> _renameRoute(SavedRouteRecord record) async {
    final controller = TextEditingController(text: record.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Rename Saved Route',
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
            hintText: 'e.g. Home to Campus',
            filled: true,
            fillColor: const Color(0xFFF4F6F9),
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
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await _safeRouteService.renameSavedRoute(record.id, newName);
      await _loadSavedRoutes();
    }
  }

  Future<void> _deleteRoute(SavedRouteRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Saved Route',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
          ),
        ),
        content: Text(
          'Remove "${record.title}" from your saved routes?',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: _secondaryGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: _secondaryGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9383A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _safeRouteService.deleteSavedRoute(record.id);
    await _loadSavedRoutes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved route deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ({Color bg, Color text}) _riskBadgeStyle(RouteRiskLevel risk) {
    switch (risk) {
      case RouteRiskLevel.high:
        return (
          bg: const Color(0xFFFEE2E2),
          text: const Color(0xFFDC2626),
        );
      case RouteRiskLevel.moderate:
        return (
          bg: const Color(0xFFFEF3C7),
          text: const Color(0xFFD97706),
        );
      case RouteRiskLevel.low:
      case RouteRiskLevel.safe:
        return (
          bg: const Color(0xFFE8F5E9),
          text: const Color(0xFF2E7D32),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBeige,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryNavy,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saved Routes',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
          ),
        ),
        actions: [
          if (_isSavingRoute)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accentBlue,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Save a new route',
              icon: const Icon(
                Icons.add_road_rounded,
                color: _accentBlue,
              ),
              onPressed: _planAndSaveNewRoute,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: _primaryNavy,
        onRefresh: _loadSavedRoutes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(18),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: _primaryNavy),
                ),
              )
            else if (_savedRoutes.isEmpty)
              _buildEmptyState()
            else
              ..._savedRoutes.map(
                (route) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSavedRouteCard(route),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3765),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bookmark_added_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_savedRoutes.length} Saved ${_savedRoutes.length == 1 ? 'Route' : 'Routes'}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Real-time hazard risk is automatically checked for your saved routes.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isSavingRoute ? null : _planAndSaveNewRoute,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'New',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7D046),
              foregroundColor: const Color(0xFF1E3765),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bookmark_border_rounded,
              color: _accentBlue,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No saved routes yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Save your frequent routes from the Route Planner or add one here for one-tap turn-by-turn navigation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _secondaryGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isSavingRoute ? null : _planAndSaveNewRoute,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Save a Route Now',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RouteScreen(
                        safeRouteService: _safeRouteService,
                        hazardReportService: _hazardReportService,
                        initialLocation: LocationService.defaultLocation,
                        skipLocationLookup: true,
                      ),
                    ),
                  );
                  if (mounted) {
                    await _loadSavedRoutes();
                  }
                },
                icon: const Icon(Icons.alt_route_rounded, size: 17),
                label: const Text(
                  'Open Route Planner',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryNavy,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRouteCard(SavedRouteRecord route) {
    final riskStyle = _riskBadgeStyle(route.riskLevel);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Travel mode pill, Risk level pill, Menu actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _lightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      route.travelMode.icon,
                      size: 13,
                      color: _accentBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      route.travelMode.label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _accentBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskStyle.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  route.riskLevel.badgeLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: riskStyle.text,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Rename route',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: _secondaryGrey,
                ),
                onPressed: () => _renameRoute(route),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              IconButton(
                tooltip: 'Delete route',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFD9383A),
                ),
                onPressed: () => _deleteRoute(route),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Title
          Text(
            route.title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _primaryNavy,
            ),
          ),

          const SizedBox(height: 6),

          // Origin -> Destination
          Row(
            children: [
              const Icon(
                Icons.trip_origin_rounded,
                size: 12,
                color: _accentBlue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${route.originLabel} → ${route.destinationLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: _secondaryGrey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Distance, duration & hazard count
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 13,
                color: _secondaryGrey,
              ),
              const SizedBox(width: 5),
              Text(
                route.distanceAndTimeLabel,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
              if (route.hazardCount > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '· ${route.hazardCount} active ${route.hazardCount == 1 ? 'hazard' : 'hazards'} nearby',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F3F6)),
          const SizedBox(height: 8),

          // Action buttons: Preview on Map & Start Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _openSavedRouteOnMap(
                  route,
                  autoStartNavigation: false,
                ),
                icon: const Icon(
                  Icons.map_outlined,
                  size: 15,
                  color: _primaryNavy,
                ),
                label: const Text(
                  'View on Map',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openSavedRouteOnMap(
                  route,
                  autoStartNavigation: true,
                ),
                icon: const Icon(Icons.navigation_rounded, size: 15),
                label: const Text(
                  'Start Navigation',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
