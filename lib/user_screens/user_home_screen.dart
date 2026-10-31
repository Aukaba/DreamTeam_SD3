import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../map_screen.dart';
import '../services/location_service.dart';
import '../widgets/report_hazard_modal.dart';
import '../Authentication/auth_service.dart';
import '../Authentication/login_page.dart';
import '../widgets/custom_wavy_header.dart';
import '../widgets/safe_route_bottom_nav.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  DateTime? _lastBackPressedAt;
  final AuthService _authService = AuthService();
  final MapController _mapPreviewController = MapController();
  LatLng _currentLocation = LocationService.defaultLocation;
  bool _previewMapError = false;

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  @override
  void dispose() {
    _mapPreviewController.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    final lastKnown = await LocationService.getLastKnownLocation();
    if (lastKnown != null && mounted) {
      setState(() => _currentLocation = lastKnown);
      _mapPreviewController.move(lastKnown, 15.0);
    }
    final current = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _currentLocation = current);
      _mapPreviewController.move(current, 15.0);
    }
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
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                      const Text(
                        'GOOD MORNING',
                        style: TextStyle(
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
              // Dismiss dialog first
              Navigator.pop(context);
              // Then sign out and navigate
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
          // Map Placeholder container
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MapScreen(),
                    ),
                  );
                },
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: const Color(0xFFEDF2F7),
                  child: Stack(
                    children: [
                      // FlutterMap live preview
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
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              fallbackUrl: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
                              userAgentPackageName: 'com.dreamteam.sd3',
                              evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                              tileBuilder: (context, tileWidget, tile) {
                                return ColorFiltered(
                                  colorFilter: const ColorFilter.matrix(<double>[
                                    0.75, 0.15, 0.10, 0.0, 15.0,
                                    0.05, 0.85, 0.10, 0.0, 15.0,
                                    0.40, 0.40, 0.20, 0.0, 15.0,
                                    0.00, 0.00, 0.00, 1.0,  0.0,
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
                                style: TextStyle(fontSize: 8, color: Color(0xFF4B5563)),
                              ),
                              alignment: Alignment.bottomRight,
                            ),
                            MarkerLayer(
                              markers: [
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
                                Marker(
                                  point: LatLng(
                                    _currentLocation.latitude + 0.0025,
                                    _currentLocation.longitude - 0.0025,
                                  ),
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _accentOrange,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.construction_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Offline indicator if tile requests fail
                      if (_previewMapError)
                        Positioned(
                          bottom: 8,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.wifi_off_rounded, size: 11, color: Color(0xFFDC2626)),
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
                // Safe Area status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'You are in a safe area',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _primaryNavy,
                  ),
                ),
                const Spacer(),

                // Open Map button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapScreen(),
                      ),
                    );
                  },
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
                showReportHazardModal(context);
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
                // Handle Find a route
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
  // RECENT HAZARDS LIST
  // ---------------------------------------------------------------------------
  Widget _buildRecentHazardsSection() {
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
        const Text(
          'Recent hazards',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _primaryNavy,
          ),
        ),
        const SizedBox(height: 12),

        // Card 1: Roadwork
        _buildHazardCard(
          icon: Icons.warning_amber_rounded,
          iconColor: _accentOrange,
          iconBgColor: const Color(0xFFFFF2EB),
          title: 'Roadwork on Escario St.',
          subtitle: '200m away • 5 mins ago',
          onTap: () {},
        ),

        const SizedBox(height: 10),

        // Card 2: Minor flooding
        _buildHazardCard(
          icon: Icons.water_drop_outlined,
          iconColor: _accentBlue,
          iconBgColor: const Color(0xFFEBF3FE),
          title: 'Minor flooding',
          subtitle: '450m away • 12 mins ago',
          onTap: () {},
        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HAZARDS BY TYPE SECTION
  // ---------------------------------------------------------------------------
  Widget _buildHazardsByTypeSection() {
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

        // Row of 3 square white cards
        Row(
          children: [
            Expanded(
              child: _buildHazardTypeCard(
                icon: Icons.traffic_rounded,
                iconColor: _accentOrange,
                iconBgColor: const Color(0xFFFFF2EB),
                label: 'Traffic',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHazardTypeCard(
                icon: Icons.construction_rounded,
                iconColor: _accentBlue,
                iconBgColor: const Color(0xFFEBF3FE),
                label: 'Construction',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHazardTypeCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: _accentRed,
                iconBgColor: const Color(0xFFFDEEEC),
                label: 'Weather',
                onTap: () {},
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
                const EdgeInsets.symmetric(vertical: 18.0, horizontal: 8.0),
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
    return const SafeRouteBottomNav(
      currentIndex: 0,
    );
  }
}
