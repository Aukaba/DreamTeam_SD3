import 'package:flutter/material.dart';
import '../widgets/safe_route_bottom_nav.dart';
import '../navigation/app_navigation.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _navyHeader = Color(0xFF1C3A70);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgBeige = Color(0xFFFAF8F5);
const Color _goldYellow = Color(0xFFF7D046);
const Color _goldBorder = Color(0xFFFFC107);
const Color _silverBorder = Color(0xFFCBD5E1);
const Color _bronzeBorder = Color(0xFFCD7F32);

// Constant Avatar URLs
const String _userAvatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
const String _juanAvatar = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150';
const String _mariaAvatar = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150';
const String _carloAvatar = 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150';
const String _anaAvatar = 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150';
const String _bongAvatar = 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150';
const String _roseAvatar = 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150';
const String _davidAvatar = 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150';

/// Data models for category-driven leaderboard rendering
class LeaderboardUserData {
  final int rank;
  final String name;
  final String? subtitle;
  final String score;
  final String avatarUrl;
  final String badgeText;
  final IconData badgeIcon;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final bool isCurrentUser;

  const LeaderboardUserData({
    required this.rank,
    required this.name,
    this.subtitle,
    required this.score,
    required this.avatarUrl,
    required this.badgeText,
    required this.badgeIcon,
    required this.badgeBgColor,
    required this.badgeTextColor,
    this.isCurrentUser = false,
  });
}

class PodiumUserData {
  final String name;
  final String score;
  final String avatarUrl;

  const PodiumUserData({
    required this.name,
    required this.score,
    required this.avatarUrl,
  });
}

class PodiumData {
  final PodiumUserData first;
  final PodiumUserData second;
  final PodiumUserData third;

  const PodiumData({
    required this.first,
    required this.second,
    required this.third,
  });
}

class CurrentUserRankData {
  final String rank;
  final String name;
  final String stat;
  final String badgePill;
  final String avatarUrl;

  const CurrentUserRankData({
    required this.rank,
    required this.name,
    required this.stat,
    required this.badgePill,
    required this.avatarUrl,
  });
}

class TabLeaderboardData {
  final String scoreColumnHeader;
  final PodiumData podium;
  final CurrentUserRankData currentUser;
  final List<LeaderboardUserData> list;

  const TabLeaderboardData({
    required this.scoreColumnHeader,
    required this.podium,
    required this.currentUser,
    required this.list,
  });
}

class UserLeaderboardScreen extends StatefulWidget {
  const UserLeaderboardScreen({super.key});

  @override
  State<UserLeaderboardScreen> createState() => _UserLeaderboardScreenState();
}

class _UserLeaderboardScreenState extends State<UserLeaderboardScreen> {
  int _selectedTabIndex = 0; // 0: Safety Points, 1: Reports, 2: Routes

  // Category rankings data (Points, Reports, Routes)
  static const Map<int, TabLeaderboardData> _categoriesData = {
    // 0: Safety Points
    0: TabLeaderboardData(
      scoreColumnHeader: 'POINTS',
      podium: PodiumData(
        first: PodiumUserData(
          name: 'Juan D.',
          score: '220 pts',
          avatarUrl: _juanAvatar,
        ),
        second: PodiumUserData(
          name: 'Maria S.',
          score: '185 pts',
          avatarUrl: _mariaAvatar,
        ),
        third: PodiumUserData(
          name: 'Carlo R.',
          score: '162 pts',
          avatarUrl: _carloAvatar,
        ),
      ),
      currentUser: CurrentUserRankData(
        rank: '#8',
        name: 'You · Ma. Angelica May',
        stat: '120 pts · Level 2',
        badgePill: 'TOP 10',
        avatarUrl: _userAvatar,
      ),
      list: [
        LeaderboardUserData(
          rank: 1,
          name: 'Juan D.',
          score: '220',
          avatarUrl: _juanAvatar,
          badgeText: 'Hero',
          badgeIcon: Icons.shield_rounded,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 2,
          name: 'Maria S.',
          score: '185',
          avatarUrl: _mariaAvatar,
          badgeText: 'Guard',
          badgeIcon: Icons.star_rounded,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 3,
          name: 'Carlo R.',
          score: '162',
          avatarUrl: _carloAvatar,
          badgeText: 'Scout',
          badgeIcon: Icons.local_fire_department_rounded,
          badgeBgColor: Color(0xFFFFF7EB),
          badgeTextColor: Color(0xFFC27803),
        ),
        LeaderboardUserData(
          rank: 4,
          name: 'Ana P.',
          score: '148',
          avatarUrl: _anaAvatar,
          badgeText: 'Watcher',
          badgeIcon: Icons.remove_red_eye_rounded,
          badgeBgColor: Color(0xFFE8F5E9),
          badgeTextColor: Color(0xFF2E7D32),
        ),
        LeaderboardUserData(
          rank: 5,
          name: 'Bong L.',
          score: '130',
          avatarUrl: _bongAvatar,
          badgeText: 'Guard',
          badgeIcon: Icons.shield_outlined,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 6,
          name: 'Rose M.',
          score: '118',
          avatarUrl: _roseAvatar,
          badgeText: 'Rookie',
          badgeIcon: Icons.lightbulb_outline_rounded,
          badgeBgColor: Color(0xFFFFF9E6),
          badgeTextColor: Color(0xFFB78103),
        ),
        LeaderboardUserData(
          rank: 7,
          name: 'David K.',
          score: '124',
          avatarUrl: _davidAvatar,
          badgeText: 'Scout',
          badgeIcon: Icons.local_fire_department_rounded,
          badgeBgColor: Color(0xFFFFF7EB),
          badgeTextColor: Color(0xFFC27803),
        ),
        LeaderboardUserData(
          rank: 8,
          name: 'Ma. Angelica May',
          subtitle: 'You',
          score: '120',
          avatarUrl: _userAvatar,
          badgeText: 'Guard',
          badgeIcon: Icons.star_rounded,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
          isCurrentUser: true,
        ),
      ],
    ),

    // 1: Reports (Consistent with 12 Reports on Profile)
    1: TabLeaderboardData(
      scoreColumnHeader: 'REPORTS',
      podium: PodiumData(
        first: PodiumUserData(
          name: 'Juan D.',
          score: '38 reports',
          avatarUrl: _juanAvatar,
        ),
        second: PodiumUserData(
          name: 'Maria S.',
          score: '32 reports',
          avatarUrl: _mariaAvatar,
        ),
        third: PodiumUserData(
          name: 'Carlo R.',
          score: '27 reports',
          avatarUrl: _carloAvatar,
        ),
      ),
      currentUser: CurrentUserRankData(
        rank: '#6',
        name: 'You · Ma. Angelica May',
        stat: '12 reports · Active Reporter',
        badgePill: 'TOP 10',
        avatarUrl: _userAvatar,
      ),
      list: [
        LeaderboardUserData(
          rank: 1,
          name: 'Juan D.',
          score: '38',
          avatarUrl: _juanAvatar,
          badgeText: 'Hero',
          badgeIcon: Icons.shield_rounded,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 2,
          name: 'Maria S.',
          score: '32',
          avatarUrl: _mariaAvatar,
          badgeText: 'Guard',
          badgeIcon: Icons.star_rounded,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 3,
          name: 'Carlo R.',
          score: '27',
          avatarUrl: _carloAvatar,
          badgeText: 'Scout',
          badgeIcon: Icons.local_fire_department_rounded,
          badgeBgColor: Color(0xFFFFF7EB),
          badgeTextColor: Color(0xFFC27803),
        ),
        LeaderboardUserData(
          rank: 4,
          name: 'Ana P.',
          score: '21',
          avatarUrl: _anaAvatar,
          badgeText: 'Watcher',
          badgeIcon: Icons.remove_red_eye_rounded,
          badgeBgColor: Color(0xFFE8F5E9),
          badgeTextColor: Color(0xFF2E7D32),
        ),
        LeaderboardUserData(
          rank: 5,
          name: 'Bong L.',
          score: '16',
          avatarUrl: _bongAvatar,
          badgeText: 'Guard',
          badgeIcon: Icons.shield_outlined,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 6,
          name: 'Ma. Angelica May',
          subtitle: 'You',
          score: '12',
          avatarUrl: _userAvatar,
          badgeText: 'Scout',
          badgeIcon: Icons.local_fire_department_rounded,
          badgeBgColor: Color(0xFFFFF7EB),
          badgeTextColor: Color(0xFFC27803),
          isCurrentUser: true,
        ),
        LeaderboardUserData(
          rank: 7,
          name: 'Rose M.',
          score: '11',
          avatarUrl: _roseAvatar,
          badgeText: 'Rookie',
          badgeIcon: Icons.lightbulb_outline_rounded,
          badgeBgColor: Color(0xFFFFF9E6),
          badgeTextColor: Color(0xFFB78103),
        ),
        LeaderboardUserData(
          rank: 8,
          name: 'David K.',
          score: '9',
          avatarUrl: _davidAvatar,
          badgeText: 'Rookie',
          badgeIcon: Icons.lightbulb_outline_rounded,
          badgeBgColor: Color(0xFFFFF9E6),
          badgeTextColor: Color(0xFFB78103),
        ),
      ],
    ),

    // 2: Routes (Consistent with 5 Safe Routes on Profile)
    2: TabLeaderboardData(
      scoreColumnHeader: 'ROUTES',
      podium: PodiumData(
        first: PodiumUserData(
          name: 'Juan D.',
          score: '25 routes',
          avatarUrl: _juanAvatar,
        ),
        second: PodiumUserData(
          name: 'Maria S.',
          score: '21 routes',
          avatarUrl: _mariaAvatar,
        ),
        third: PodiumUserData(
          name: 'Carlo R.',
          score: '18 routes',
          avatarUrl: _carloAvatar,
        ),
      ),
      currentUser: CurrentUserRankData(
        rank: '#7',
        name: 'You · Ma. Angelica May',
        stat: '5 routes · Safe Navigator',
        badgePill: 'TOP 10',
        avatarUrl: _userAvatar,
      ),
      list: [
        LeaderboardUserData(
          rank: 1,
          name: 'Juan D.',
          score: '25',
          avatarUrl: _juanAvatar,
          badgeText: 'Hero',
          badgeIcon: Icons.shield_rounded,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 2,
          name: 'Maria S.',
          score: '21',
          avatarUrl: _mariaAvatar,
          badgeText: 'Guard',
          badgeIcon: Icons.star_rounded,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 3,
          name: 'Carlo R.',
          score: '18',
          avatarUrl: _carloAvatar,
          badgeText: 'Scout',
          badgeIcon: Icons.local_fire_department_rounded,
          badgeBgColor: Color(0xFFFFF7EB),
          badgeTextColor: Color(0xFFC27803),
        ),
        LeaderboardUserData(
          rank: 4,
          name: 'Ana P.',
          score: '14',
          avatarUrl: _anaAvatar,
          badgeText: 'Watcher',
          badgeIcon: Icons.remove_red_eye_rounded,
          badgeBgColor: Color(0xFFE8F5E9),
          badgeTextColor: Color(0xFF2E7D32),
        ),
        LeaderboardUserData(
          rank: 5,
          name: 'Bong L.',
          score: '10',
          avatarUrl: _bongAvatar,
          badgeText: 'Guard',
          badgeIcon: Icons.shield_outlined,
          badgeBgColor: Color(0xFFEBF3FC),
          badgeTextColor: Color(0xFF2B548F),
        ),
        LeaderboardUserData(
          rank: 6,
          name: 'David K.',
          score: '8',
          avatarUrl: _davidAvatar,
          badgeText: 'Scout',
          badgeIcon: Icons.local_fire_department_rounded,
          badgeBgColor: Color(0xFFFFF7EB),
          badgeTextColor: Color(0xFFC27803),
        ),
        LeaderboardUserData(
          rank: 7,
          name: 'Ma. Angelica May',
          subtitle: 'You',
          score: '5',
          avatarUrl: _userAvatar,
          badgeText: 'Rookie',
          badgeIcon: Icons.lightbulb_outline_rounded,
          badgeBgColor: Color(0xFFFFF9E6),
          badgeTextColor: Color(0xFFB78103),
          isCurrentUser: true,
        ),
        LeaderboardUserData(
          rank: 8,
          name: 'Rose M.',
          score: '4',
          avatarUrl: _roseAvatar,
          badgeText: 'Rookie',
          badgeIcon: Icons.lightbulb_outline_rounded,
          badgeBgColor: Color(0xFFFFF9E6),
          badgeTextColor: Color(0xFFB78103),
        ),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final currentData = _categoriesData[_selectedTabIndex] ?? _categoriesData[0]!;

    return Scaffold(
      backgroundColor: _bgBeige,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Navy Header Section with Podium
            _buildNavyHeader(currentData.podium),

            // 2. Main Body Content (Rank Card, List, Points Guide)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Current User Rank Card (dynamically reflects selected tab)
                  _buildCurrentUserRankCard(currentData.currentUser),

                  const SizedBox(height: 20),

                  // Leaderboard List Table Card (dynamically reflects selected tab)
                  _buildLeaderboardListCard(
                    scoreHeader: currentData.scoreColumnHeader,
                    users: currentData.list,
                  ),

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
              AppNavigation.navigateTo(context, 3, clearStack: true);
            }
          } else {
            // Remove leaderboard and profile routes when navigating to another top-level destination
            AppNavigation.navigateTo(context, index, clearStack: true);
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP NAVY HEADER WITH APP BAR, TABS, AND PODIUM
  // ---------------------------------------------------------------------------
  Widget _buildNavyHeader(PodiumData podiumData) {
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
                  // "This Week" Pill Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26498A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'This Week',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 16,
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

            // The Top 3 Podium (responsive for narrow 320px screens)
            _buildPodium(podiumData),
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
  // PODIUM SECTION (Ranks 2, 1, 3) - Responsive for Narrow Displays (e.g. 320px)
  // ---------------------------------------------------------------------------
  Widget _buildPodium(PodiumData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          // Responsive gap and proportional widths that guarantee 0 overflow
          final gap = totalWidth < 300 ? 6.0 : 10.0;
          final availableWidth = totalWidth - (gap * 2);
          final sideWidth = (availableWidth * 0.31).clamp(55.0, 96.0);
          final centerWidth = (availableWidth * 0.38).clamp(70.0, 110.0);

          final sideAvatarRadius = (sideWidth * 0.32).clamp(20.0, 28.0);
          final centerAvatarRadius = (centerWidth * 0.34).clamp(25.0, 35.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Rank 2 (Left)
              SizedBox(
                width: sideWidth,
                child: _buildPodiumSpot(
                  rank: 2,
                  name: data.second.name,
                  score: data.second.score,
                  avatarUrl: data.second.avatarUrl,
                  avatarRadius: sideAvatarRadius,
                  borderColor: _silverBorder,
                  borderWidth: 3,
                  badgeColor: const Color(0xFFA0AEC0),
                  pedestalColor: const Color(0xFFEBF2FA),
                  pedestalHeight: 52,
                ),
              ),

              SizedBox(width: gap),

              // Rank 1 (Center - Taller, Larger Avatar, Gold)
              SizedBox(
                width: centerWidth,
                child: _buildPodiumSpot(
                  rank: 1,
                  name: data.first.name,
                  score: data.first.score,
                  avatarUrl: data.first.avatarUrl,
                  avatarRadius: centerAvatarRadius,
                  borderColor: _goldBorder,
                  borderWidth: 4,
                  badgeColor: _goldBorder,
                  pedestalColor: const Color(0xFFDEEDFA),
                  pedestalHeight: 80,
                  hasCrown: true,
                ),
              ),

              SizedBox(width: gap),

              // Rank 3 (Right)
              SizedBox(
                width: sideWidth,
                child: _buildPodiumSpot(
                  rank: 3,
                  name: data.third.name,
                  score: data.third.score,
                  avatarUrl: data.third.avatarUrl,
                  avatarRadius: sideAvatarRadius,
                  borderColor: _bronzeBorder,
                  borderWidth: 3,
                  badgeColor: _bronzeBorder,
                  pedestalColor: const Color(0xFFF6EFE5),
                  pedestalHeight: 38,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodiumSpot({
    required int rank,
    required String name,
    required String score,
    required String avatarUrl,
    required double avatarRadius,
    required Color borderColor,
    required double borderWidth,
    required Color badgeColor,
    required Color pedestalColor,
    required double pedestalHeight,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),

        // Score
        Text(
          score,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),

        const SizedBox(height: 8),

        // Pedestal Container (full width within the spot's assigned column)
        Container(
          width: double.infinity,
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
  // 2. USER'S CURRENT RANK CARD
  // ---------------------------------------------------------------------------
  Widget _buildCurrentUserRankCard(CurrentUserRankData user) {
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
          Text(
            user.rank,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _goldYellow,
            ),
          ),

          const SizedBox(width: 14),

          // User Avatar
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
                  user.avatarUrl,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.stat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFB0BAC9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Rank Badge Pill (e.g. TOP 10)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _goldYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.badgePill,
              style: const TextStyle(
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
  Widget _buildLeaderboardListCard({
    required String scoreHeader,
    required List<LeaderboardUserData> users,
  }) {
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
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 10),
            child: Row(
              children: [
                const SizedBox(
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
                const SizedBox(width: 8),
                const Expanded(
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
                    scoreHeader,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _secondaryGrey,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(
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

          // Dynamically rendered user rows
          ...users.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            final isLast = index == users.length - 1;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLeaderboardRow(user),
                if (!isLast)
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F6)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(LeaderboardUserData user) {
    return Container(
      color: user.isCurrentUser ? const Color(0xFFF3F7FD) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          // Rank column (Medals for 1-3, numbers for others)
          SizedBox(
            width: 38,
            child: _buildRankBadge(user.rank),
          ),

          const SizedBox(width: 8),

          // User Avatar & Name
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFF5FB),
                  child: ClipOval(
                    child: Image.network(
                      user.avatarUrl,
                      width: 32,
                      height: 32,
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
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: user.isCurrentUser ? FontWeight.w700 : FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      if (user.subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          user.subtitle!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E6FD9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Score / Points
          SizedBox(
            width: 60,
            child: Text(
              user.score,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _primaryNavy,
              ),
            ),
          ),

          // Badge Pill
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user.badgeBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user.badgeIcon,
                      size: 11,
                      color: user.badgeTextColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      user.badgeText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: user.badgeTextColor,
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
