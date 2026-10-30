import 'package:flutter/material.dart';
import '../Authentication/auth_service.dart';
import '../login_page.dart';
import '../widgets/custom_wavy_header.dart';
import '../widgets/safe_route_bottom_nav.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgWarm = Color(0xFFFAF8F5);
const Color _timeBlue = Color(0xFF5B82A6);
const Color _hazardRed = Color(0xFFE53935);
const Color _hazardBg = Color(0xFFFFF5F5);
const Color _hazardIconBg = Color(0xFFFFE5E5);
const Color _communityGreen = Color(0xFF2E7D32);
const Color _communityBg = Color(0xFFF3FAF6);
const Color _communityIconBg = Color(0xFFDDF3E7);
const Color _systemBlue = Color(0xFF1976D2);
const Color _systemBg = Color(0xFFF0F7FE);
const Color _systemIconBg = Color(0xFFD9ECFD);

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  DateTime? _lastBackPressedAt;
  final AuthService _authService = AuthService();
  int _selectedFilterIndex = 0;

  Future<bool> _showLogoutDialog() async {
    final nav = Navigator.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
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
                color: _hazardRed,
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
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Wave Header with Logo
              const CustomWavyHeader(),

              // Main Scrollable Content pulled up into the wave curve
              Transform.translate(
                offset: const Offset(0, -36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overline
                      const Text(
                        'NOTIFICATIONS',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _secondaryGrey,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Main Title
                      const Text(
                        'Stay updated,\nstay safer.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _primaryNavy,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Subtitle
                      const Text(
                        'Get the latest alerts, community reports, and important updates in your area.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Filter Chips Row
                      _buildFilterChipsRow(),

                      const SizedBox(height: 24),

                      // Card 1: Hazard Alert
                      if (_selectedFilterIndex == 0 || _selectedFilterIndex == 1) ...[
                        _buildAlertCard(
                          cardBgColor: _hazardBg,
                          iconBgColor: _hazardIconBg,
                          icon: Icons.warning_amber_rounded,
                          iconColor: _hazardRed,
                          overlineText: 'HAZARD ALERT',
                          overlineColor: _hazardRed,
                          title: 'Poor lighting reported',
                          body:
                              'A user reported poor lighting near University Avenue (around 2:14 PM).',
                          metaIcon: Icons.location_on_outlined,
                          metaText: 'Near University Avenue',
                          timeElapsed: '2h ago',
                          onTap: () {},
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Card 2: Community Update
                      if (_selectedFilterIndex == 0 || _selectedFilterIndex == 2) ...[
                        _buildAlertCard(
                          cardBgColor: _communityBg,
                          iconBgColor: _communityIconBg,
                          icon: Icons.groups_rounded,
                          iconColor: _communityGreen,
                          overlineText: 'COMMUNITY UPDATE',
                          overlineColor: _communityGreen,
                          title: 'Road blockage',
                          body:
                              'Temporary road blockage near Costal Rd. Use alternative routes if possible.',
                          metaIcon: Icons.location_on_outlined,
                          metaText: 'Near Costal Rd.',
                          timeElapsed: '2h ago',
                          onTap: () {},
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Card 3: System Update
                      if (_selectedFilterIndex == 0 || _selectedFilterIndex == 3) ...[
                        _buildAlertCard(
                          cardBgColor: _systemBg,
                          iconBgColor: _systemIconBg,
                          icon: Icons.settings_rounded,
                          iconColor: _systemBlue,
                          overlineText: 'SYSTEM UPDATE',
                          overlineColor: _systemBlue,
                          title: 'App maintenance',
                          body:
                              'SafeRoute will undergo scheduled maintenance tonight from 11:00 PM to 1:00 AM.',
                          metaIcon: Icons.access_time_rounded,
                          metaText: 'System Notice',
                          timeElapsed: '2h ago',
                          onTap: () {},
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const SafeRouteBottomNav(
          currentIndex: 2,
        ),
      ),
    );
  }

  /// Horizontally scrollable row of custom filter chips
  Widget _buildFilterChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(
            index: 0,
            label: 'All',
            icon: Icons.notifications_rounded,
            defaultIconColor: _secondaryGrey,
            badgeCount: '6',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            index: 1,
            label: 'Hazard',
            icon: Icons.warning_amber_rounded,
            defaultIconColor: _hazardRed,
            badgeCount: '6',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            index: 2,
            label: 'Community',
            icon: Icons.groups_rounded,
            defaultIconColor: _communityGreen,
            badgeCount: '6',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            index: 3,
            label: 'System',
            icon: Icons.settings_rounded,
            defaultIconColor: _systemBlue,
            badgeCount: '6',
          ),
        ],
      ),
    );
  }

  /// Reusable Filter Chip widget
  Widget _buildFilterChip({
    required int index,
    required String label,
    required IconData icon,
    required Color defaultIconColor,
    required String badgeCount,
  }) {
    final isSelected = _selectedFilterIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryNavy : const Color(0xFFE5E9EE),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : defaultIconColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF233253),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF33588A) : const Color(0xFF6B8BB4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable Alert Card matching target Figma layout
  Widget _buildAlertCard({
    required Color cardBgColor,
    required Color iconBgColor,
    required IconData icon,
    required Color iconColor,
    required String overlineText,
    required Color overlineColor,
    required String title,
    required String body,
    required IconData metaIcon,
    required String metaText,
    required String timeElapsed,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left square icon container
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
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // Middle content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top overline & time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        overlineText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: overlineColor,
                        ),
                      ),
                      Text(
                        timeElapsed,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _timeBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Main Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _primaryNavy,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Body text
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF5A6B82),
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Location/meta row
                  Row(
                    children: [
                      Icon(
                        metaIcon,
                        size: 13,
                        color: const Color(0xFF5A6B82),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          metaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF384E6D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right arrow
            const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: Color(0xFF6B8BB4),
            ),
          ],
        ),
      ),
    );
  }
}
