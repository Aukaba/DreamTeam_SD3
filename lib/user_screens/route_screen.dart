import 'package:flutter/material.dart';
import '../Authentication/auth_service.dart';
import '../Authentication/login_page.dart';
import '../map_screen.dart';
import '../widgets/custom_wavy_header.dart';
import '../widgets/safe_route_bottom_nav.dart';
import '../navigation/app_navigation.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  // Route Planning Toggles - Persisted outside disposed RouteScreen state
  static bool _avoidHazard = true;

  // System back press and logout guard
  DateTime? _lastBackPressedAt;
  final AuthService _authService = AuthService();

  // Navigation guard to prevent multiple MapScreen instances
  bool _isNavigatingToMap = false;

  void _navigateToMap() {
    if (_isNavigatingToMap) return;
    _isNavigatingToMap = true;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isNavigatingToMap = false;
        });
      }
    });
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
              // 1. Shared Inline Scrollable Header with SafeRoute wave & logo
              const CustomWavyHeader(),

              // 2. Main Scrollable Content pulled up into the wave curve
              Transform.translate(
                offset: const Offset(0, -36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Text Section
                      _buildHeaderTextSection(),

                      const SizedBox(height: 18),

                      // Route Planning Card (From / To / Avoid Hazard / Walking / Find Route)
                      _buildRoutePlanningCard(),

                      const SizedBox(height: 24),

                      // Suggested Route Section
                      _buildSuggestedRouteSection(),

                      const SizedBox(height: 24),

                      // Saved Routes Section
                      _buildSavedRoutesSection(),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeRouteBottomNav(
          currentIndex: 1,
          onTap: (index) => AppNavigation.navigateTo(context, index, currentIndex: 1),
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
          'Find the safest way to your destination with real-time alerts and community reports.',
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
        children: [
          // "From" Input Row
          _buildLocationInputRow(
            icon: Icons.location_on_rounded,
            iconColor: _accentBlue,
            iconBgColor: _lightBlue,
            label: 'From',
            value: 'Your current location',
          ),

          const SizedBox(height: 10),

          // "To" Input Row
          _buildLocationInputRow(
            icon: Icons.flag_rounded,
            iconColor: _accentBlue,
            iconBgColor: _lightBlue,
            label: 'To',
            value: 'Enter destination',
          ),

          const SizedBox(height: 14),

          // Bottom Action Controls: Avoid Hazard toggle, Walking chip, Find Route button
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
                    const SizedBox(width: 4),
                    _buildCustomCompactSwitch(
                      value: _avoidHazard,
                      onChanged: (val) {
                        setState(() {
                          _avoidHazard = val;
                        });
                      },
                    ),
                  ],
                ),

                // b) Walking chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _lightBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_walk_rounded,
                        size: 15,
                        color: _accentBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Walking',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _accentBlue,
                        ),
                      ),
                    ],
                  ),
                ),

                // c) Find Route button
                ElevatedButton(
                  onPressed: _navigateToMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Find Route',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Colors.white,
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

  // Location input row (From / To)
  Widget _buildLocationInputRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon in circular container
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),

          // Label and placeholder value
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

          // Right arrow
          const Icon(
            Icons.arrow_forward_rounded,
            color: _primaryNavy,
            size: 16,
          ),
        ],
      ),
    );
  }

  // Custom compact switch matching Figma navy pill toggle
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
  // 3. SUGGESTED ROUTE SECTION
  // ---------------------------------------------------------------------------
  Widget _buildSuggestedRouteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Suggested Route',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _primaryNavy,
              ),
            ),
            GestureDetector(
              onTap: _navigateToMap,
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

        // Suggested Route Card with Map Snippet
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
            children: [
              // Top Half: Map Snippet Preview
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 136,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SuggestedRouteMapSnippetPainter(),
                  ),
                ),
              ),

              // Bottom Half: Route Information & Safe Area Badge
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    // Route Icon inside circular container
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

                    // Title & Distance / Time
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Safer route found!',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _primaryNavy,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '2.3 km · 12 min',
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

                    // Low Risk Area Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _safeGreenBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            size: 13,
                            color: _safeGreen,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Low risk area →',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _safeGreen,
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
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. SAVED ROUTES SECTION
  // ---------------------------------------------------------------------------
  Widget _buildSavedRoutesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Saved Routes',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _primaryNavy,
              ),
            ),
            Text(
              'See all →',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _secondaryGrey,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Route Item 1: Home to School
        _buildSavedRouteCard(
          title: 'Home to School',
          distanceAndTime: '2.8 km · 14 min',
          statusText: 'Safe',
          statusColor: _primaryNavy,
          statusBgColor: _lightBlue,
          onTap: _navigateToMap,
        ),

        const SizedBox(height: 10),

        // Route Item 2: Home to Work
        _buildSavedRouteCard(
          title: 'Home to Work',
          distanceAndTime: '5.4 km · 22 min',
          statusText: 'Moderate risk',
          statusColor: _warningAmber,
          statusBgColor: _warningAmberBg,
          onTap: _navigateToMap,
        ),

        const SizedBox(height: 10),

        // Route Item 3: University Route
        _buildSavedRouteCard(
          title: 'University Route',
          distanceAndTime: '3.1 km · 16 min',
          statusText: 'Safe',
          statusColor: _primaryNavy,
          statusBgColor: _lightBlue,
          onTap: _navigateToMap,
        ),
      ],
    );
  }

  // Reusable Saved Route Card
  Widget _buildSavedRouteCard({
    required String title,
    required String distanceAndTime,
    required String statusText,
    required Color statusColor,
    required Color statusBgColor,
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
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              children: [
                // Home icon in soft blue circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _lightBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_outlined,
                    color: _primaryNavy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Title, Distance/Time, and Status pill badge
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
                        distanceAndTime,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Status pill badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

                // Right side: vertical ellipsis top & right arrow bottom
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
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.arrow_forward_rounded,
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
// SUGGESTED ROUTE MAP SNIPPET PAINTER
// Draws a high-fidelity vector preview of the route map with sea coastline,
// winding blue route line, start/end pins, and risk icons.
// -----------------------------------------------------------------------------
class _SuggestedRouteMapSnippetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base land background (#F3F5F7)
    final landPaint = Paint()..color = const Color(0xFFF3F5F7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // 2. Subtle green park patches
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

    // 3. Subtle road grid lines
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

    // 4. Blue Water / Coastline on the bottom-right
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

    // 5. The Active Blue Route Line
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

    // 6. Start Point: Pulsing halo circle and blue dot
    final startOffset = Offset(size.width * 0.16, size.height * 0.72);
    // Outer halo
    canvas.drawCircle(
      startOffset,
      13,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.25),
    );
    // Inner white border & blue dot
    canvas.drawCircle(startOffset, 6, Paint()..color = Colors.white);
    canvas.drawCircle(startOffset, 4, Paint()..color = const Color(0xFF2563EB));

    // 7. Danger Markers & Safe Shield along the route
    // Marker A: Red hazard triangle at (0.38, 0.44)
    _drawHazardBadge(
      canvas,
      Offset(size.width * 0.38, size.height * 0.44),
      color: const Color(0xFFEF4444),
      bgColor: const Color(0xFFFEE2E2),
    );

    // Marker B: Blue safety shield in the middle at (0.51, 0.56)
    _drawShieldBadge(
      canvas,
      Offset(size.width * 0.51, size.height * 0.56),
      color: const Color(0xFF2563EB),
      bgColor: const Color(0xFFDBEAFE),
    );

    // Marker C: Yellow/Amber hazard triangle at (0.65, 0.46)
    _drawHazardBadge(
      canvas,
      Offset(size.width * 0.65, size.height * 0.46),
      color: const Color(0xFFD97706),
      bgColor: const Color(0xFFFEF3C7),
    );

    // 8. Destination Navy Pin Icon at (0.83, 0.36)
    final endOffset = Offset(size.width * 0.83, size.height * 0.36);
    _drawDestinationPin(canvas, endOffset);
  }

  void _drawHazardBadge(Canvas canvas, Offset center, {required Color color, required Color bgColor}) {
    final badgePaint = Paint()..color = bgColor;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Small rounded container
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 18, height: 18),
        const Radius.circular(5),
      ),
      badgePaint,
    );

    // Mini triangle exclamation
    final tri = Path()
      ..moveTo(center.dx, center.dy - 5)
      ..lineTo(center.dx + 4.5, center.dy + 4)
      ..lineTo(center.dx - 4.5, center.dy + 4)
      ..close();
    canvas.drawPath(tri, strokePaint);
  }

  void _drawShieldBadge(Canvas canvas, Offset center, {required Color color, required Color bgColor}) {
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
      ..cubicTo(center.dx + 3.5, center.dy + 4, center.dx, center.dy + 5, center.dx, center.dy + 5)
      ..cubicTo(center.dx, center.dy + 5, center.dx - 3.5, center.dy + 4, center.dx - 4, center.dy + 1)
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
    // Pin head & pointer
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
    // Center white dot
    canvas.drawCircle(Offset(center.dx, center.dy - 5), 2.2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
