import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'admin_reports_screen.dart';
import 'admin_settings_screens.dart';

class AdminProfileScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> Function()? profileLoader;
  final Future<void> Function(String fullName)? onSaveFullName;
  final Future<void> Function()? onSignOut;

  const AdminProfileScreen({
    super.key,
    this.profileLoader,
    this.onSaveFullName,
    this.onSignOut,
  });

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (mounted && (!_isLoading || _error != null)) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      Map<String, dynamic> response;

      if (widget.profileLoader != null) {
        response = await widget.profileLoader!();
      } else {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user == null) {
          if (!mounted) return;
          setState(() {
            _error = 'User not authenticated';
            _isLoading = false;
          });
          return;
        }

        final isAdmin =
            await supabase.rpc('verify_admin_access') as bool? ?? false;
        if (!isAdmin) {
          if (!mounted) return;
          setState(() {
            _error = 'Administrator access required';
            _isLoading = false;
          });
          return;
        }

        response = await supabase
            .from('profiles')
            .select('id, email, full_name, avatar_url, role, created_at')
            .eq('id', user.id)
            .eq('role', 'admin')
            .single();
      }

      if (!mounted) return;
      setState(() {
        _profile = response;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openAccountInfo() async {
    final updatedName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAccountInfoScreen(
          initialProfile: _profile,
          onSaveFullName: widget.onSaveFullName,
        ),
      ),
    );

    if (!mounted || updatedName == null) return;
    setState(() {
      _profile = {
        ...?_profile,
        'full_name': updatedName,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/saferoute_admin_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isSmallScreen = screenWidth < 360;
              final isTablet = screenWidth >= 600;
              final isDesktop = screenWidth >= 1200;

              final horizontalPadding = isDesktop
                  ? 48.0
                  : (isTablet ? 32.0 : (isSmallScreen ? 12.0 : 16.0));

              return SingleChildScrollView(
                child: Center(
                  // Keeps the layout from stretching too wide on big screens.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isDesktop ? 32.0 : 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(
                            context,
                            isSmallScreen,
                            isTablet,
                            isDesktop,
                          ),
                          SizedBox(height: isDesktop ? 40 : 24),
                          _buildGreeting(isSmallScreen, isTablet, isDesktop),
                          SizedBox(height: isDesktop ? 40 : 24),
                          _buildProfileCard(
                            isSmallScreen,
                            isTablet,
                            isDesktop,
                          ),
                          SizedBox(height: isDesktop ? 32 : 24),
                          _buildOverviewSection(
                            isSmallScreen,
                            isTablet,
                            isDesktop,
                          ),
                          SizedBox(height: isDesktop ? 32 : 24),
                          _buildSettingsMenu(
                            isSmallScreen,
                            isTablet,
                            isDesktop,
                            context,
                          ),
                          SizedBox(height: isDesktop ? 32 : 24),
                          _buildLogoutButton(
                            isSmallScreen,
                            isTablet,
                            isDesktop,
                            context,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isSmallScreen,
    bool isTablet,
    bool isDesktop,
  ) {
    final gap = isDesktop ? 20.0 : (isSmallScreen ? 8.0 : 14.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left group shrinks if the screen is very narrow.
        Expanded(
          child: Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFE8EEF2),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Color(0xFF1F3A5F),
                  ),
                ),
              ),
              SizedBox(width: gap),
              Image.asset(
                'assets/image/LogoSR.png',
                width: 43,
                height: 47,
              ),
              SizedBox(width: gap),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Safe',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF45596E),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Route',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8AABCE),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting(bool isSmallScreen, bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, Admin.',
          style: GoogleFonts.inter(
            color: const Color(0xFF738297),
            fontSize: isDesktop ? 15 : 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 4),
        Text(
          'Profile',
          style: GoogleFonts.inter(
            color: const Color(0xFF1E2A41),
            fontSize: isDesktop ? 30 : (isSmallScreen ? 22 : 26),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        width: 1,
        color: const Color(0xFFEDF3F8),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 15,
          offset: Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
    );
  }

  Widget _buildProfileCard(bool isSmallScreen, bool isTablet, bool isDesktop) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isDesktop ? 24 : (isSmallScreen ? 14 : 18)),
        decoration: _cardDecoration(),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isDesktop ? 24 : (isSmallScreen ? 14 : 18)),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error loading profile',
              style: GoogleFonts.inter(
                color: const Color(0xFFD95379),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _fetchProfile,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final fullName = _profile?['full_name'] ?? 'Admin';
    final email = _profile?['email'] ?? 'admin@saferoute.ph';
    final avatarUrl = _profile?['avatar_url'];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : (isSmallScreen ? 14 : 18)),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: isSmallScreen ? 60 : 72,
                height: isSmallScreen ? 60 : 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCEAF7),
                  shape: BoxShape.circle,
                ),
                child: avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: isSmallScreen ? 30 : 36,
                              color: const Color(0xFF1E2A41),
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: isSmallScreen ? 30 : 36,
                        color: const Color(0xFF1E2A41),
                      ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6DD3B3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: isDesktop ? 24 : (isSmallScreen ? 12 : 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1E2A41),
                    fontSize: isDesktop ? 19 : 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: isDesktop ? 8 : 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF3FA),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    'Administrator',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF5A88C5),
                      fontSize: isDesktop ? 11 : 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 8 : 4),
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 13,
                      color: Color(0xFF738297),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF738297),
                          fontSize: isDesktop ? 11 : 10,
                          fontWeight: FontWeight.w400,
                        ),
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

  Widget _buildOverviewSection(
    bool isSmallScreen,
    bool isTablet,
    bool isDesktop,
  ) {
    final gap = isDesktop ? 16.0 : (isSmallScreen ? 6.0 : 10.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : (isSmallScreen ? 12 : 16)),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart,
                size: 16,
                color: Color(0xFF1E2A41),
              ),
              const SizedBox(width: 6),
              Text(
                'Overview',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1E2A41),
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 24 : 16),
          // Cards share the available width equally and match each other's
          // height, so nothing can overflow on any screen size.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildStatCard(
                    value: '48',
                    label: 'Total Reports',
                    color: const Color(0xFFF2F7FD),
                    icon: Icons.description,
                    isSmallScreen: isSmallScreen,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _buildStatCard(
                    value: '12',
                    label: 'Active Hazards',
                    color: const Color(0xFFFEF6E9),
                    icon: Icons.warning,
                    isSmallScreen: isSmallScreen,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _buildStatCard(
                    value: '98%',
                    label: 'Area Coverage',
                    color: const Color(0xFFEDF9F4),
                    icon: Icons.map,
                    isSmallScreen: isSmallScreen,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final minHeight = isDesktop ? 96.0 : 82.0;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            size: isDesktop ? 24 : (isSmallScreen ? 18 : 20),
            color: const Color(0xFF1E2A41),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1E2A41),
                    fontSize: isDesktop ? 24 : (isSmallScreen ? 18 : 20),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF738297),
                  fontSize: isDesktop ? 10 : 9,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu(
    bool isSmallScreen,
    bool isTablet,
    bool isDesktop,
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.person,
            iconColor: const Color(0xFFEAF3FB),
            title: 'Account Information',
            subtitle: 'View and edit your admin details',
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            showDivider: true,
            onTap: _openAccountInfo,
          ),
          _buildMenuItem(
            icon: Icons.security,
            iconColor: const Color(0xFFE8F7F0),
            title: 'Safety Settings',
            subtitle: 'Manage alert thresholds and notifications',
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            showDivider: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSafetySettingsScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.report,
            iconColor: const Color(0xFFEAF3FB),
            title: 'Report Management',
            subtitle: 'Oversee and manage all reports',
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            showDivider: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminReportsScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.info,
            iconColor: const Color(0xFFEEF1FA),
            title: 'About SafeRoute',
            subtitle: 'App version and information',
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            showDivider: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAboutSafeRouteScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.help,
            iconColor: const Color(0xFFEEF1FA),
            title: 'Help & Support',
            subtitle: 'Get assistance or contact support',
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            showDivider: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminHelpSupportScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDesktop,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    final iconBox = isSmallScreen ? 36.0 : 40.0;
    final gap = isDesktop ? 20.0 : (isSmallScreen ? 10.0 : 14.0);
    final pad = isDesktop ? 20.0 : (isSmallScreen ? 12.0 : 16.0);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Row(
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: const Color(0xFF1E2A41),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1E2A41),
                          fontSize: isDesktop ? 15 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 6 : 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF738297),
                          fontSize: isDesktop ? 11 : 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Color(0xFF738297),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            color: const Color(0xFFF0F4F8),
            // Lines up with the text: padding + icon box + gap
            margin: EdgeInsets.only(left: pad + iconBox + gap),
          ),
      ],
    );
  }

  Widget _buildLogoutButton(
    bool isSmallScreen,
    bool isTablet,
    bool isDesktop,
    BuildContext context,
  ) {
    return InkWell(
      onTap: () async {
        if (widget.onSignOut != null) {
          await widget.onSignOut!();
        } else {
          await Supabase.instance.client.auth.signOut();
        }
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFDF0F3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout,
                size: 20,
                color: Color(0xFFD95379),
              ),
              const SizedBox(width: 8),
              Text(
                'Log Out',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD95379),
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
