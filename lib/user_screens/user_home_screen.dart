import 'package:flutter/material.dart';
import '../map_screen.dart';
import '../widgets/report_hazard_modal.dart';
import '../Authentication/auth_service.dart';
import '../login_page.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentNavIndex = 0;
  DateTime? _lastBackPressedAt;
  final AuthService _authService = AuthService();

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
    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          return false;
        }
        // Show logout dialog on second back press
        await _showLogoutDialog();
        return false; // Never allow back to proceed after logout
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
                Navigator.pushAndRemoveUntil(
                  context,
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
    return Stack(
      children: [
        // Wavy Blue Background
        Image.asset(
          'assets/image/saferoute_heather.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
        ),

        // SafeRoute Logo positioned over top-left of the blue wave
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 10.0),
            child: Image.asset(
              'assets/image/saferoute_logo_and_icon.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
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
              child: Container(
                height: 150,
                width: double.infinity,
                color: const Color(0xFFEDF2F7),
                child: Stack(
                  children: [
                    // Stylized road canvas
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MapCanvasPainter(),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() {
              _currentNavIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: _primaryNavy,
          unselectedItemColor: _secondaryGrey,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.home_rounded, size: 24),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: _RouteNavIcon(
                  color: _currentNavIndex == 1 ? _primaryNavy : _secondaryGrey,
                ),
              ),
              label: 'Route',
            ),
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.notifications_none_rounded, size: 24),
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.person_outline_rounded, size: 24),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ROUTE BOTTOM NAV ICON (S-Curve Route Path matching Figma)
// -----------------------------------------------------------------------------
class _RouteNavIcon extends StatelessWidget {
  final Color color;

  const _RouteNavIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _RouteNavPainter(color: color),
      ),
    );
  }
}

class _RouteNavPainter extends CustomPainter {
  final Color color;

  _RouteNavPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Start circle at top left
    canvas.drawCircle(
        Offset(size.width * 0.28, size.height * 0.24), 2.2, dotPaint);

    final path = Path()
      ..moveTo(size.width * 0.38, size.height * 0.24)
      ..lineTo(size.width * 0.65, size.height * 0.24)
      ..arcToPoint(
        Offset(size.width * 0.65, size.height * 0.52),
        radius: Radius.circular(size.width * 0.14),
        clockwise: true,
      )
      ..lineTo(size.width * 0.35, size.height * 0.52)
      ..arcToPoint(
        Offset(size.width * 0.35, size.height * 0.80),
        radius: Radius.circular(size.width * 0.14),
        clockwise: false,
      )
      ..lineTo(size.width * 0.62, size.height * 0.80);

    canvas.drawPath(path, strokePaint);
    // End circle at bottom right
    canvas.drawCircle(
        Offset(size.width * 0.72, size.height * 0.80), 2.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RouteNavPainter oldDelegate) =>
      oldDelegate.color != color;
}

// -----------------------------------------------------------------------------
// STYLIZED MAP PLACEHOLDER CANVAS PAINTER
// -----------------------------------------------------------------------------
class _MapCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle road lines
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path1 = Path()
      ..moveTo(-10, size.height * 0.72)
      ..lineTo(size.width * 0.32, size.height * 0.52)
      ..lineTo(size.width * 0.65, size.height * 0.40)
      ..lineTo(size.width + 10, size.height * 0.62);

    final path2 = Path()
      ..moveTo(size.width * 0.22, 0)
      ..lineTo(size.width * 0.32, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height + 10);

    // Draw borders first, then inner roads
    canvas.drawPath(path1, roadBorderPaint);
    canvas.drawPath(path2, roadBorderPaint);
    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path2, roadPaint);

    // Location / landmark dots
    final dotPaint = Paint()
      ..color = const Color(0xFF8A94A6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.42, size.height * 0.48),
      3.5,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.55),
      3.0,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
