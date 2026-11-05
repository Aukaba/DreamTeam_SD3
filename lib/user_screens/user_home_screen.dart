import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../map_screen.dart';
import '../services/alert_service.dart';
import '../services/hazard_report_service.dart';
import '../services/location_service.dart';
import '../widgets/report_hazard_modal.dart';
import '../Authentication/auth_service.dart';
import '../Authentication/login_page.dart';
import '../widgets/custom_wavy_header.dart';
import '../widgets/safe_route_bottom_nav.dart';
import '../navigation/app_navigation.dart';

class UserHomeScreen extends StatefulWidget {
  final HazardReportService? hazardReportService;
  final AlertService? alertService;
  final LatLng? initialLocation;
  final bool skipLocationLookup;

  const UserHomeScreen({
    super.key,
    this.hazardReportService,
    this.alertService,
    this.initialLocation,
    this.skipLocationLookup = false,
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  DateTime? _lastBackPressedAt;
  final AuthService _authService = AuthService();
  final MapController _mapPreviewController = MapController();
  late final HazardReportService _hazardReportService;
  late final AlertService _alertService;
  StreamSubscription<HazardReportData>? _reportSubscription;

  late LatLng _currentLocation;
  bool _previewMapError = false;
  bool _isLoadingHazards = true;
  List<HazardReportData> _activeReports = <HazardReportData>[];

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation ?? LocationService.defaultLocation;
    _hazardReportService = widget.hazardReportService ?? HazardReportService();
    _alertService = widget.alertService ?? AlertService();
    _reportSubscription =
        HazardReportService.reportStream.listen(_onNewReportSubmitted);
    _loadHomeData();
    if (!widget.skipLocationLookup) {
      _initCurrentLocation();
    }
  }

  @override
  void dispose() {
    _reportSubscription?.cancel();
    _mapPreviewController.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    final lastKnown = await LocationService.getLastKnownLocation();
    if (lastKnown != null && mounted) {
      setState(() => _currentLocation = lastKnown);
      try {
        _mapPreviewController.move(lastKnown, 15.0);
      } catch (_) {}
    }
    final current = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _currentLocation = current);
      try {
        _mapPreviewController.move(current, 15.0);
      } catch (_) {}
    }
  }

  Future<void> _loadHomeData() async {
    final reportsFuture =
        _hazardReportService.fetchReports(limit: 100, activeOnly: true);
    final alertsFuture = _alertService.fetchAlerts(limit: 50);

    final reports = await reportsFuture;
    await alertsFuture;

    if (!mounted) return;
    setState(() {
      _activeReports = reports;
      _isLoadingHazards = false;
    });
  }

  void _onNewReportSubmitted(HazardReportData report) {
    if (!mounted || report.location == null || report.status != 'active') {
      return;
    }
    setState(() {
      if (report.reportId != null && report.reportId!.isNotEmpty) {
        _activeReports.removeWhere((r) => r.reportId == report.reportId);
      } else {
        _activeReports.removeWhere(
          (r) => r.title == report.title && r.timestamp == report.timestamp,
        );
      }
      _activeReports.insert(0, report);
      _isLoadingHazards = false;
    });
    _alertService.fetchAlerts(limit: 50);
  }

  Future<void> _openMapScreen({
    LatLng? focusHazardLocation,
    String? focusedReportId,
    int initialFilterIndex = 0,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLocation: _currentLocation,
          focusHazardLocation: focusHazardLocation,
          focusedReportId: focusedReportId,
          initialFilterIndex: initialFilterIndex,
          hazardReportService: widget.hazardReportService,
        ),
      ),
    );
    if (mounted) {
      _loadHomeData();
    }
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 18) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  List<HazardReportData> get _recentHazards {
    if (_activeReports.isEmpty) return const <HazardReportData>[];
    const distanceCalc = Distance();
    final within25Km = _activeReports
        .where((r) =>
            r.location != null &&
            distanceCalc.distance(_currentLocation, r.location!) <= 25000)
        .toList();
    final source = within25Km.isNotEmpty ? within25Km : _activeReports;
    return source.take(4).toList();
  }

  ({Color iconColor, Color iconBgColor, IconData icon}) _visualsForReport(
    HazardReportData report,
  ) {
    final classification = MapScreen.classifyHazardForMap(report.category);
    final secLower = report.securityLevel.toLowerCase();
    if (secLower.contains('high')) {
      return (
        iconColor: _accentRed,
        iconBgColor: const Color(0xFFFDEEEC),
        icon: classification.icon,
      );
    }
    if (classification.filterCategoryIndex == 2) {
      return (
        iconColor: _accentBlue,
        iconBgColor: const Color(0xFFEBF3FE),
        icon: classification.icon,
      );
    }
    return (
      iconColor: _accentOrange,
      iconBgColor: const Color(0xFFFFF2EB),
      icon: classification.icon,
    );
  }

  // Color Palette Constants
  static const Color _bgWarm = Color(0xFFF8F7F4);
  static const Color _primaryNavy = Color(0xFF233253);
  static const Color _secondaryGrey = Color(0xFF8A94A6);
  static const Color _accentOrange = Color(0xFFF37C34);
  static const Color _accentGreen = Color(0xFF219653);
  static const Color _accentBlue = Color(0xFF4A90E2);
  static const Color _accentRed = Color(0xFFEB5757);
  static const Color _cardBg = Color(0xFFFFFFFF);

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
          onRefresh: _loadHomeData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Inline Scrollable Header
                _buildScrollableHeader(),

                // 2. Main Scrollable Content pulled up snugly against the wave
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting & Subtitle
                        Text(
                          _greetingText(),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _secondaryGrey,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Stay safe out there.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: _primaryNavy,
                            letterSpacing: -0.4,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 3. Live Map Card
                        _buildLiveMapCard(),

                        const SizedBox(height: 16),

                        // 4. Action Buttons
                        _buildActionButtons(),

                        const SizedBox(height: 24),

                        // 5. Recent Hazards Section
                        _buildRecentHazardsSection(),

                        const SizedBox(height: 24),

                        // 6. Hazards by Type Section
                        _buildHazardsByTypeSection(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Future<bool> _showLogoutDialog() async {
    final nav = Navigator.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context, false),
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
              Navigator.pop(context);
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
                color: _accentRed,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // INLINE SCROLLABLE HEADER
  // ---------------------------------------------------------------------------
  Widget _buildScrollableHeader() {
    return const CustomWavyHeader();
  }

  // ---------------------------------------------------------------------------
  // LIVE MAP CARD
  // ---------------------------------------------------------------------------
  Widget _buildLiveMapCard() {
    const distanceCalc = Distance();
    final nearbyWithin500m = _activeReports
        .where((r) =>
            r.location != null &&
            distanceCalc.distance(_currentLocation, r.location!) <= 500)
        .toList();
    final hasHighNearby = nearbyWithin500m
        .any((r) => r.securityLevel.toLowerCase().contains('high'));

    final Color areaDotColor = hasHighNearby
        ? _accentRed
        : (nearbyWithin500m.isNotEmpty ? _accentOrange : _accentGreen);
    final String areaStatusText = hasHighNearby
        ? 'Caution: High-risk hazard nearby'
        : (nearbyWithin500m.isNotEmpty
            ? '${nearbyWithin500m.length} hazard${nearbyWithin500m.length == 1 ? '' : 's'} reported nearby'
            : 'You are in a safe area');

    final previewMarkers = <Marker>[
      Marker(
        point: _currentLocation,
        width: 22,
        height: 22,
        alignment: Alignment.center,
        child: Container(
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
      ),
      for (final report in _activeReports.take(12))
        if (report.location != null)
          Marker(
            point: report.location!,
            width: 22,
            height: 22,
            alignment: Alignment.center,
            child: Builder(
              builder: (context) {
                final visuals = _visualsForReport(report);
                return Container(
                  decoration: BoxDecoration(
                    color: visuals.iconColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    visuals.icon,
                    color: Colors.white,
                    size: 11,
                  ),
                );
              },
            ),
          ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Map Preview container
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: () => _openMapScreen(),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: const Color(0xFFEDF2F7),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FlutterMap(
                          mapController: _mapPreviewController,
                          options: MapOptions(
                            initialCenter: _currentLocation,
                            initialZoom: 15.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              fallbackUrl:
                                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
                              userAgentPackageName: 'com.dreamteam.sd3',
                              evictErrorTileStrategy:
                                  EvictErrorTileStrategy.dispose,
                              tileBuilder: (context, tileWidget, tile) {
                                return ColorFiltered(
                                  colorFilter:
                                      const ColorFilter.matrix(<double>[
                                    0.75, 0.15, 0.10, 0.0, 15.0,
                                    0.05, 0.85, 0.10, 0.0, 15.0,
                                    0.40, 0.40, 0.20, 0.0, 15.0,
                                    0.00, 0.00, 0.00, 1.0, 0.0,
                                  ]),
                                  child: tileWidget,
                                );
                              },
                              errorTileCallback: (tile, error, stackTrace) {
                                if (!_previewMapError && mounted) {
                                  setState(() => _previewMapError = true);
                                }
                              },
                            ),
                            const SimpleAttributionWidget(
                              source: Text(
                                '© OpenStreetMap contributors',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              alignment: Alignment.bottomRight,
                            ),
                            MarkerLayer(markers: previewMarkers),
                          ],
                        ),
                      ),

                      if (_previewMapError)
                        Positioned(
                          bottom: 8,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2)
                                  .withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  size: 11,
                                  color: Color(0xFFDC2626),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Offline map',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9,
                                    color: Color(0xFF991B1B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Top-left "LIVE MAP" badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
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
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _accentOrange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _activeReports.isEmpty
                                    ? 'LIVE MAP'
                                    : 'LIVE MAP • ${_activeReports.length}',
                                style: const TextStyle(
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
                ),
              ),
            ),
          ),

          // Bottom status row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: areaDotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    areaStatusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Open Map button
                GestureDetector(
                  onTap: () => _openMapScreen(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open Map',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '→',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
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

  // ---------------------------------------------------------------------------
  // ACTION BUTTONS
  // ---------------------------------------------------------------------------
  Widget _buildActionButtons() {
    return Row(
      children: [
        // "Report hazard" button
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                showReportHazardModal(
                  context,
                  initialLocation: _currentLocation,
                  onReportSubmitted: _onNewReportSubmitted,
                );
              },
              borderRadius: BorderRadius.circular(26),
              child: Ink(
                height: 56,
                decoration: BoxDecoration(
                  color: _primaryNavy,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryNavy.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          'hazard',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        // "Find a route" button
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                AppNavigation.navigateTo(context, 1, currentIndex: 0);
              },
              borderRadius: BorderRadius.circular(26),
              child: Ink(
                height: 56,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFDCE2EC),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.near_me_outlined,
                      color: _primaryNavy,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Find a route',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // RECENT HAZARDS LIST (Connected to Supabase ReportTable)
  // ---------------------------------------------------------------------------
  Widget _buildRecentHazardsSection() {
    final recent = _recentHazards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LIVE NEAR YOU',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _secondaryGrey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent hazards',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _primaryNavy,
              ),
            ),
            if (_activeReports.isNotEmpty)
              GestureDetector(
                onTap: () => _openMapScreen(),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _accentBlue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_isLoadingHazards && recent.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
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
        else if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: _accentGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No active hazards reported nearby',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap "Report hazard" above if you spot an issue.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < recent.length; i++) ...[
            Builder(
              builder: (context) {
                final item = recent[i];
                final visuals = _visualsForReport(item);
                final distText = item.location != null
                    ? HazardReportService.formatDistanceBetween(
                        _currentLocation,
                        item.location!,
                      )
                    : item.address;
                final timeText =
                    HazardReportService.formatRelativeTime(item.timestamp);
                return _buildHazardCard(
                  icon: visuals.icon,
                  iconColor: visuals.iconColor,
                  iconBgColor: visuals.iconBgColor,
                  title: item.title,
                  subtitle: '$distText • $timeText',
                  severity: item.securityLevel,
                  onTap: () => _openMapScreen(
                    focusHazardLocation: item.location,
                    focusedReportId: item.reportId,
                  ),
                );
              },
            ),
            if (i < recent.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  // Reusable Hazard Card
  Widget _buildHazardCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    String? severity,
    VoidCallback? onTap,
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
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                // Rounded icon box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Title and subtitle
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
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (severity != null && severity.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      severity,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _secondaryGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HAZARDS BY TYPE SECTION (Connected to Supabase ReportTable counts)
  // ---------------------------------------------------------------------------
  Widget _buildHazardsByTypeSection() {
    int roadworkCount = 0;
    int floodingCount = 0;
    int safetyCount = 0;

    for (final report in _activeReports) {
      final cls = MapScreen.classifyHazardForMap(report.category);
      if (cls.filterCategoryIndex == 1) {
        roadworkCount++;
      } else if (cls.filterCategoryIndex == 2) {
        floodingCount++;
      } else {
        safetyCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMMUNITY ACTIVITY',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _secondaryGrey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Hazards by type',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _primaryNavy,
          ),
        ),
        const SizedBox(height: 12),

        // Row of 3 category cards wired to MapScreen filters
        Row(
          children: [
            Expanded(
              child: _buildHazardTypeCard(
                icon: Icons.construction_rounded,
                iconColor: _accentOrange,
                iconBgColor: const Color(0xFFFFF2EB),
                label: 'Roadwork',
                countLabel: '$roadworkCount active',
                onTap: () => _openMapScreen(initialFilterIndex: 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHazardTypeCard(
                icon: Icons.water_drop_rounded,
                iconColor: _accentBlue,
                iconBgColor: const Color(0xFFEBF3FE),
                label: 'Flooding',
                countLabel: '$floodingCount active',
                onTap: () => _openMapScreen(initialFilterIndex: 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHazardTypeCard(
                icon: Icons.warning_amber_rounded,
                iconColor: _accentRed,
                iconBgColor: const Color(0xFFFDEEEC),
                label: 'Safety',
                countLabel: '$safetyCount active',
                onTap: () => _openMapScreen(initialFilterIndex: 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Reusable Hazard Type Card
  Widget _buildHazardTypeCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String countLabel,
    VoidCallback? onTap,
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
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  countLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _secondaryGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM NAVIGATION BAR
  // ---------------------------------------------------------------------------
  Widget _buildBottomNavigationBar() {
    return SafeRouteBottomNav(
      currentIndex: 0,
      onTap: (index) =>
          AppNavigation.navigateTo(context, index, currentIndex: 0),
    );
  }
}
