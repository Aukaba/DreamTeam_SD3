import 'package:flutter/material.dart';
import '../Authentication/auth_service.dart';
import '../Authentication/login_page.dart';
import '../widgets/custom_wavy_header.dart';
import '../widgets/safe_route_bottom_nav.dart';
import '../navigation/app_navigation.dart';
import 'user_leaderboard_screen.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgBeige = Color(0xFFFAF8F5);
const Color _lightBlue = Color(0xFFEFF5FB);
const Color _badgeBlue = Color(0xFFEAF2FB);
const Color _accentBlue = Color(0xFF7098C2);
const Color _alertRed = Color(0xFFE53935);
const Color _lightRed = Color(0xFFFFEBEE);

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  DateTime? _lastBackPressedAt;
  final AuthService _authService = AuthService();
  bool _isNavigatingToLeaderboard = false;

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
        _showLogoutDialog(context);
      },
      child: Scaffold(
        backgroundColor: _bgBeige,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Custom Wavy Header with SafeRoute Logo
            const CustomWavyHeader(),

            // 2. Main Scrollable Content pulled up into the wave curve
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Section (Avatar, Info, Edit Button)
                    _buildProfileHeader(),

                    const SizedBox(height: 28),

                    // Stats Row (Reports, Helpful Votes, Safe Routes, Days Active)
                    _buildStatsRow(),

                    const SizedBox(height: 28),

                    // View Leaderboard Button
                    _buildLeaderboardButton(),

                    const SizedBox(height: 26),

                    // Contributor Badge Card (Safety Contributor Level 2)
                    _buildContributorBadgeCard(),

                    const SizedBox(height: 32),

                    // Account Settings Section
                    _buildSectionHeader('ACCOUNT'),
                    _buildSettingsGroup(
                      children: [
                        _buildSettingsTile(
                          icon: Icons.shield_outlined,
                          title: 'Personal Information',
                          subtitle: 'Name, email, and contact details',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'Security',
                          subtitle: 'Change password and manage account access',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notification Settings',
                          subtitle: 'Choose what updates you want to receive',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.location_on_outlined,
                          title: 'Location Preferences',
                          subtitle: 'Set your default location and travel options',
                          showDivider: false,
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Community Settings Section
                    _buildSectionHeader('COMMUNITY'),
                    _buildSettingsGroup(
                      children: [
                        _buildSettingsTile(
                          icon: Icons.assignment_outlined,
                          title: 'My Reports',
                          subtitle: 'View and manage your submitted reports',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.favorite_border_rounded,
                          title: 'Saved Locations',
                          subtitle: 'Your favorite places and marked areas',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.alt_route_rounded,
                          title: 'Saved Routes',
                          subtitle: 'View and edit your saved routes',
                          showDivider: false,
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Support Settings Section
                    _buildSectionHeader('SUPPORT'),
                    _buildSettingsGroup(
                      children: [
                        _buildSettingsTile(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & Support',
                          subtitle: 'FAQs, guides, and contact support',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.settings_outlined,
                          title: 'App Settings',
                          subtitle: 'Appearance, language, and more',
                          onTap: () {},
                        ),
                        _buildSettingsTile(
                          icon: Icons.logout_rounded,
                          title: 'Log Out',
                          subtitle: 'Sign out from your account',
                          isDestructive: true,
                          showDivider: false,
                          onTap: () => _showLogoutDialog(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeRouteBottomNav(
        currentIndex: 3,
        onTap: (index) => AppNavigation.navigateTo(context, index, currentIndex: 3),
      ),
    ),
  );
  }

  /// Profile Header with Avatar, camera badge, User Info, and Edit Profile button
  Widget _buildProfileHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Circular avatar with camera badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: _lightBlue,
                  child: ClipOval(
                    child: Image.network(
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 76,
                          height: 76,
                          color: _lightBlue,
                          child: const Icon(
                            Icons.person_rounded,
                            size: 42,
                            color: _primaryNavy,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _primaryNavy,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // User Info Column in the middle
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ma. Angelica May',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _primaryNavy,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '@gelic',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _secondaryGrey,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cebu City, Philippines',
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
            ),
          ],
        ),

        // Edit Profile Button positioned on the bottom right, aligned horizontally with location text
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _lightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Stats Row with 4 equal columns inside a white card with rounded corners and drop shadow
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem('12', 'Reports', "You've shared"),
          _buildStatItem('8', 'Helpful Votes', 'From the community'),
          _buildStatItem('5', 'Safe Routes', 'Saved'),
          _buildStatItem('28', 'Days Active', 'Keep it up!'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label, String sublabel) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _primaryNavy,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _primaryNavy,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 8.5,
              fontWeight: FontWeight.w400,
              color: _secondaryGrey,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  /// Full-width "View Leaderboard" Button
  Widget _buildLeaderboardButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: _isNavigatingToLeaderboard
            ? null
            : () async {
                setState(() {
                  _isNavigatingToLeaderboard = true;
                });
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserLeaderboardScreen(),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _isNavigatingToLeaderboard = false;
                  });
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: const Text(
          'View Leaderboard',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Contributor Badge Card
  Widget _buildContributorBadgeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _badgeBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navy Star Icon
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(
              Icons.star_rounded,
              size: 38,
              color: _primaryNavy,
            ),
          ),

          const SizedBox(width: 14),

          // Right side details and progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overline row: COMMUNITY MEMBER & Level 2
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'COMMUNITY MEMBER',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: _accentBlue,
                      ),
                    ),
                    Text(
                      'Level 2',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: _primaryNavy,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                // Title
                const Text(
                  'Safety Contributor',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),

                const SizedBox(height: 2),

                // Subtitle
                const Text(
                  "You're helping make your community safer!",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7B95),
                  ),
                ),

                const SizedBox(height: 10),

                // Progress Bar with Points Label
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          value: 120 / 200,
                          backgroundColor: Color(0xFFD6E4F0),
                          valueColor: AlwaysStoppedAnimation<Color>(_primaryNavy),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '120 / 200 pts',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _accentBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section Header (ACCOUNT, COMMUNITY, SUPPORT)
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: _secondaryGrey,
        ),
      ),
    );
  }

  /// Card wrapper for a group of settings tiles
  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Container(
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
        children: children,
      ),
    );
  }

  /// Reusable Settings Tile
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
    bool showDivider = true,
  }) {
    final iconColor = isDestructive ? _alertRed : _primaryNavy;
    final iconBgColor = isDestructive ? _lightRed : _lightBlue;
    final titleColor = isDestructive ? _alertRed : _primaryNavy;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Icon in circular background
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: iconColor,
                  ),
                ),

                const SizedBox(width: 14),

                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: _secondaryGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Chevron icon
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFFB0BAC9),
                ),
              ],
            ),
          ),
        ),

        // Divider
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            endIndent: 16,
            color: Color(0xFFF1F3F6),
          ),
      ],
    );
  }

  /// Logout confirmation dialog
  void _showLogoutDialog(BuildContext context) {
    final nav = Navigator.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              color: _primaryNavy,
            ),
          ),
          content: const Text(
            'Are you sure you want to sign out of SafeRoute?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: _secondaryGrey,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _authService.signOut();
                if (mounted) {
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _alertRed,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
