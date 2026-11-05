import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Authentication/auth_error_handler.dart';
import '../Authentication/auth_service.dart';
import '../Authentication/login_page.dart';
import '../navigation/app_navigation.dart';
import '../services/profile_service.dart';
import '../widgets/custom_wavy_header.dart';
import '../widgets/safe_route_bottom_nav.dart';
import 'personal_information_screen.dart';
import 'saved_locations_screen.dart';
import 'user_leaderboard_screen.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgBeige = Color(0xFFFAF8F5);
const Color _lightBlue = Color(0xFFEFF5FB);
const Color _badgeBlue = Color(0xFFEAF2FB);
const Color _accentBlue = Color(0xFF7098C2);
const Color _alertRed = Color(0xFFE53935);
const Color _lightRed = Color(0xFFFFEBEE);
const Color _successGreen = Color(0xFF10B981);

class UserProfileScreen extends StatefulWidget {
  final ProfileService? profileService;
  final AuthService? authService;
  final ImagePicker? imagePicker;

  const UserProfileScreen({
    super.key,
    this.profileService,
    this.authService,
    this.imagePicker,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  DateTime? _lastBackPressedAt;
  late final AuthService _authService;
  late final ProfileService _profileService;
  late final ImagePicker _picker;

  UserProfile? _profile;
  Uint8List? _pendingAvatarBytes;
  bool _isLoadingProfile = true;
  bool _isUploadingAvatar = false;
  bool _isNavigatingToLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _profileService = widget.profileService ?? ProfileService();
    _picker = widget.imagePicker ?? ImagePicker();
    _loadProfile();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingProfile = true;
      });
    }

    try {
      final fetched = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = fetched;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _openPersonalInformation() async {
    final result = await Navigator.of(context).push<UserProfile?>(
      MaterialPageRoute(
        builder: (context) => PersonalInformationScreen(
          service: _profileService,
          initialProfile: _profile,
          imagePicker: _picker,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _profile = result;
      });
    } else {
      _loadProfile(silent: true);
    }
  }

  String _friendlyError(Object error) {
    if (error is StorageException) {
      return error.message.isNotEmpty
          ? error.message
          : 'Failed to upload profile photo. Please try again.';
    }
    if (error is AuthException || error is PostgrestException) {
      return AuthErrorHandler.getErrorMessage(error);
    }
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return AuthErrorHandler.getErrorMessage(error);
  }

  void _showAvatarOptionsSheet() {
    if (_isUploadingAvatar) return;
    final hasAvatar =
        _profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                const Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: _lightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: _primaryNavy,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryNavy,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadAvatar(ImageSource.gallery);
                  },
                ),
                if (!kIsWeb)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: _lightBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: _primaryNavy,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Take a Photo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryNavy,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadAvatar(ImageSource.camera);
                    },
                  ),
                if (hasAvatar)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: _lightRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: _alertRed,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Remove Current Photo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _alertRed,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _removeAvatar();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pendingAvatarBytes = bytes;
        _isUploadingAvatar = true;
      });

      final updated = await _profileService.uploadAvatar(
        bytes: bytes,
        fileName: picked.name.isNotEmpty ? picked.name : picked.path,
        mimeType: picked.mimeType,
      );

      if (!mounted) return;
      setState(() {
        _profile = updated;
        _pendingAvatarBytes = null;
        _isUploadingAvatar = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: _successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingAvatarBytes = null;
        _isUploadingAvatar = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final updated = await _profileService.removeAvatar();
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _pendingAvatarBytes = null;
        _isUploadingAvatar = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile picture removed.'),
          backgroundColor: _primaryNavy,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        _showLogoutDialog(context);
      },
      child: Scaffold(
        backgroundColor: _bgBeige,
        body: RefreshIndicator(
          color: _primaryNavy,
          onRefresh: () => _loadProfile(silent: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
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
                              onTap: _openPersonalInformation,
                            ),
                            _buildSettingsTile(
                              icon: Icons.lock_outline_rounded,
                              title: 'Security',
                              subtitle:
                                  'Change password and manage account access',
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
                              subtitle:
                                  'Set your default location and travel options',
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
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SavedLocationsScreen(),
                                  ),
                                );
                              },
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
        ),
        bottomNavigationBar: SafeRouteBottomNav(
          currentIndex: 3,
          onTap: (index) =>
              AppNavigation.navigateTo(context, index, currentIndex: 3),
        ),
      ),
    );
  }

  /// Profile Header with Avatar, camera badge, User Info, and Edit Profile button
  Widget _buildProfileHeader() {
    final avatarUrl = _profile?.avatarUrl;
    final displayName = _isLoadingProfile && _profile == null
        ? 'Loading...'
        : (_profile?.displayName ?? 'SafeRoute User');
    final emailText = _profile?.email.trim() ?? '';
    final usernameText = _profile?.formattedUsername;
    final locationText = _profile?.displayLocation ?? 'Cebu City, Philippines';
    final initials = _profile?.initials ?? 'U';

    Widget avatarImage;
    if (_pendingAvatarBytes != null) {
      avatarImage = Image.memory(
        _pendingAvatarBytes!,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarImage = Image.network(
        avatarUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildAvatarFallback(initials);
        },
      );
    } else {
      avatarImage = _buildAvatarFallback(initials);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Circular avatar with camera badge
        GestureDetector(
          key: const Key('profile_avatar_tap'),
          onTap: _showAvatarOptionsSheet,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: _lightBlue,
                child: ClipOval(child: avatarImage),
              ),
              if (_isUploadingAvatar)
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
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
        ),

        const SizedBox(width: 14),

        // User Info Column in the middle
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),
                if (usernameText != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    usernameText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _accentBlue,
                    ),
                  ),
                ],
                if (emailText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    emailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _secondaryGrey,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  locationText,
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
        ),

        const SizedBox(width: 8),

        // Edit Profile Button aligned cleanly without overlapping long text
        InkWell(
          key: const Key('edit_profile_button'),
          onTap: _openPersonalInformation,
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
      ],
    );
  }

  Widget _buildAvatarFallback(String initials) {
    if (_profile == null) {
      return Container(
        width: 76,
        height: 76,
        color: _lightBlue,
        child: const Icon(
          Icons.person_rounded,
          size: 40,
          color: _primaryNavy,
        ),
      );
    }
    return Container(
      width: 76,
      height: 76,
      color: _lightBlue,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _primaryNavy,
        ),
      ),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_primaryNavy),
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
