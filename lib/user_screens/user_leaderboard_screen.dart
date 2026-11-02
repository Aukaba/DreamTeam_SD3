import 'package:flutter/material.dart';
import '../widgets/safe_route_bottom_nav.dart';
import 'user_profile_screen.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _navyHeader = Color(0xFF1C3A70);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgBeige = Color(0xFFFAF8F5);
const Color _goldYellow = Color(0xFFF7D046);
const Color _goldBorder = Color(0xFFFFC107);
const Color _silverBorder = Color(0xFFCBD5E1);
const Color _bronzeBorder = Color(0xFFCD7F32);

class UserLeaderboardScreen extends StatefulWidget {
  const UserLeaderboardScreen({super.key});

  @override
  State<UserLeaderboardScreen> createState() => _UserLeaderboardScreenState();
}

class _UserLeaderboardScreenState extends State<UserLeaderboardScreen> {
  int _selectedTabIndex = 0; // 0: Safety Points, 1: Reports, 2: Routes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBeige,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Navy Header Section with Podium
            _buildNavyHeader(),

            // 2. Main Body Content (Rank Card, List, Points Guide)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Current User Rank Card
                  _buildCurrentUserRankCard(),

                  const SizedBox(height: 20),

                  // Leaderboard List Table Card
                  _buildLeaderboardListCard(),

                  const SizedBox(height: 20),

                  // "How to Earn Points" Card
                  _buildHowToEarnPointsCard(),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeRouteBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index == 3) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, anim1, anim2) => const UserProfileScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
            }
          } else {
            SafeRouteBottomNav.navigateTo(context, index);
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP NAVY HEADER WITH APP BAR, TABS, AND PODIUM
  // ---------------------------------------------------------------------------
  Widget _buildNavyHeader() {
    return Container(
      color: _navyHeader,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),

            // App Bar Area (Back arrow, Leaderboard title, "This Week" pill)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'This Week',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _goldYellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Tabs Row ("Safety Points", "Reports", "Routes")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildTabItem(index: 0, label: 'Safety Points'),
                  const SizedBox(width: 24),
                  _buildTabItem(index: 1, label: 'Reports'),
                  const SizedBox(width: 24),
                  _buildTabItem(index: 2, label: 'Routes'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // The Top 3 Podium
            _buildPodium(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({required int index, required String label}) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: isSelected
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _navyHeader,
                ),
              ),
            )
          : Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // PODIUM SECTION (Ranks 2, 1, 3)
  // ---------------------------------------------------------------------------
  Widget _buildPodium() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rank 2 (Left)
          _buildPodiumSpot(
            rank: 2,
            name: 'Maria S.',
            points: '185 pts',
            avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
            avatarRadius: 28,
            borderColor: _silverBorder,
            borderWidth: 3,
            badgeColor: const Color(0xFFA0AEC0),
            pedestalColor: const Color(0xFFEBF2FA),
            pedestalHeight: 52,
            pedestalWidth: 88,
          ),

          const SizedBox(width: 10),

          // Rank 1 (Center - Taller, Larger Avatar, Gold)
          _buildPodiumSpot(
            rank: 1,
            name: 'Juan D.',
            points: '220 pts',
            avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
            avatarRadius: 35,
            borderColor: _goldBorder,
            borderWidth: 4,
            badgeColor: _goldBorder,
            pedestalColor: const Color(0xFFDEEDFA),
            pedestalHeight: 80,
            pedestalWidth: 98,
            hasCrown: true,
          ),

          const SizedBox(width: 10),

          // Rank 3 (Right)
          _buildPodiumSpot(
            rank: 3,
            name: 'Carlo R.',
            points: '162 pts',
            avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
            avatarRadius: 28,
            borderColor: _bronzeBorder,
            borderWidth: 3,
            badgeColor: _bronzeBorder,
            pedestalColor: const Color(0xFFF6EFE5),
            pedestalHeight: 38,
            pedestalWidth: 88,
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumSpot({
    required int rank,
    required String name,
    required String points,
    required String avatarUrl,
    required double avatarRadius,
    required Color borderColor,
    required double borderWidth,
    required Color badgeColor,
    required Color pedestalColor,
    required double pedestalHeight,
    required double pedestalWidth,
    bool hasCrown = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for Rank 1
        if (hasCrown)
          const Padding(
            padding: EdgeInsets.only(bottom: 2.0),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: _goldYellow,
              size: 20,
            ),
          )
        else
          const SizedBox(height: 22),

        // Avatar with Border and Rank Badge
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: const Color(0xFFEFF5FB),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: avatarRadius * 2,
                    height: avatarRadius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person_rounded,
                      size: avatarRadius * 1.2,
                      color: _primaryNavy,
                    ),
                  ),
                ),
              ),
            ),

            // Number Badge
            Positioned(
              bottom: -8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Name
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),

        // Points
        Text(
          points,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),

        const SizedBox(height: 8),

        // Pedestal Container
        Container(
          width: pedestalWidth,
          height: pedestalHeight,
          decoration: BoxDecoration(
            color: pedestalColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. USER'S CURRENT RANK CARD (#8)
  // ---------------------------------------------------------------------------
  Widget _buildCurrentUserRankCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3765),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Number
          const Text(
            '#8',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _goldYellow,
            ),
          ),

          const SizedBox(width: 14),

          // User Avatar with Camera/cat asset
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFEFF5FB),
              child: ClipOval(
                child: Image.network(
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person_rounded,
                    size: 24,
                    color: _primaryNavy,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // User Info
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You · Ma. Angelica May',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '120 pts · Level 2',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFB0BAC9),
                  ),
                ),
              ],
            ),
          ),

          // TOP 10 Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _goldYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'TOP 10',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E3765),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. LEADERBOARD LIST TABLE CARD
  // ---------------------------------------------------------------------------
  Widget _buildLeaderboardListCard() {
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
        children: [
          // Header Row
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    'RANK',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _secondaryGrey,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'USER',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _secondaryGrey,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'POINTS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _secondaryGrey,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'BADGE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _secondaryGrey,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F6)),

          // Rank Items (1 through 6)
          _buildLeaderboardRow(
            rank: 1,
            name: 'Juan D.',
            subtitle: 'You',
            points: '220',
            avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
            badgeText: 'Hero',
            badgeIcon: Icons.shield_rounded,
            badgeBgColor: const Color(0xFFEBF3FC),
            badgeTextColor: const Color(0xFF2B548F),
            isCurrentUser: true,
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F6)),

          _buildLeaderboardRow(
            rank: 2,
            name: 'Maria S.',
            points: '185',
            avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
            badgeText: 'Guard',
            badgeIcon: Icons.star_rounded,
            badgeBgColor: const Color(0xFFE8F1FC),
            badgeTextColor: const Color(0xFF1E6FD9),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F6)),

          _buildLeaderboardRow(
            rank: 3,
            name: 'Carlo R.',
            points: '162',
            avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
            badgeText: 'Scout',
            badgeIcon: Icons.local_fire_department_rounded,
            badgeBgColor: const Color(0xFFFFF3E0),
            badgeTextColor: const Color(0xFFE65100),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F6)),

          _buildLeaderboardRow(
            rank: 4,
            name: 'Ana P.',
            points: '148',
            avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150',
            badgeText: 'Watcher',
            badgeIcon: Icons.eco_rounded,
            badgeBgColor: const Color(0xFFE8F5E9),
            badgeTextColor: const Color(0xFF2E7D32),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F6)),

          _buildLeaderboardRow(
            rank: 5,
            name: 'Bong L.',
            points: '130',
            avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
            badgeText: 'Guard',
            badgeIcon: Icons.shield_rounded,
            badgeBgColor: const Color(0xFFE8F1FC),
            badgeTextColor: const Color(0xFF1E6FD9),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F6)),

          _buildLeaderboardRow(
            rank: 6,
            name: 'Rose M.',
            points: '118',
            avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
            badgeText: 'Rookie',
            badgeIcon: Icons.lightbulb_rounded,
            badgeBgColor: const Color(0xFFFFF8E1),
            badgeTextColor: const Color(0xFFB78103),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow({
    required int rank,
    required String name,
    String? subtitle,
    required String points,
    required String avatarUrl,
    required String badgeText,
    required IconData badgeIcon,
    required Color badgeBgColor,
    required Color badgeTextColor,
    bool isCurrentUser = false,
  }) {
    return Container(
      color: isCurrentUser ? const Color(0xFFF6FAFE) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Rank column (Medal for 1, 2, 3 or number for 4+)
          SizedBox(
            width: 38,
            child: _buildRankBadge(rank),
          ),

          const SizedBox(width: 8),

          // User avatar + Name
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFEFF5FB),
                  child: ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: _primaryNavy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
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

          // Points column
          SizedBox(
            width: 60,
            child: Text(
              points,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w600,
                color: isCurrentUser ? const Color(0xFF1E6FD9) : _primaryNavy,
              ),
            ),
          ),

          // Badge column
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badgeIcon,
                      size: 11,
                      color: badgeTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return const Icon(
        Icons.workspace_premium_rounded,
        color: Color(0xFFF5A623),
        size: 20,
      );
    } else if (rank == 2) {
      return const Icon(
        Icons.workspace_premium_rounded,
        color: Color(0xFFA0AEC0),
        size: 20,
      );
    } else if (rank == 3) {
      return const Icon(
        Icons.workspace_premium_rounded,
        color: Color(0xFFCD7F32),
        size: 20,
      );
    } else {
      return Text(
        '$rank',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _secondaryGrey,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 4. "HOW TO EARN POINTS" SECTION
  // ---------------------------------------------------------------------------
  Widget _buildHowToEarnPointsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Text(
            'How to Earn Points',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _primaryNavy,
            ),
          ),

          const SizedBox(height: 14),

          _buildPointGuideItem(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFF2E7D32),
            iconBgColor: const Color(0xFFE8F5E9),
            title: 'Submit a hazard report',
            pointsText: '+10 pts per approved report',
          ),

          const SizedBox(height: 12),

          _buildPointGuideItem(
            icon: Icons.map_outlined,
            iconColor: const Color(0xFF1E6FD9),
            iconBgColor: const Color(0xFFEBF3FC),
            title: 'Complete safe routes',
            pointsText: '+5 pts per completed route',
          ),

          const SizedBox(height: 12),

          _buildPointGuideItem(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFF57F17),
            iconBgColor: const Color(0xFFFFF8E1),
            title: 'Daily login streak',
            pointsText: '+2 pts per day',
          ),
        ],
      ),
    );
  }

  Widget _buildPointGuideItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String pointsText,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
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

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _primaryNavy,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                pointsText,
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
      ],
    );
  }
}
