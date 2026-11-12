import 'dart:async';
import 'package:flutter/material.dart';
import '../navigation/app_navigation.dart';
import '../services/hazard_report_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/safe_route_bottom_nav.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _navyHeader = Color(0xFF1C3A70);
const Color _secondaryGrey = Color(0xFF8A94A6);
const Color _bgBeige = Color(0xFFFAF8F5);
const Color _goldYellow = Color(0xFFF7D046);
const Color _goldBorder = Color(0xFFFFC107);
const Color _silverBorder = Color(0xFFCBD5E1);
const Color _bronzeBorder = Color(0xFFCD7F32);

/// Data models for category-driven leaderboard rendering
class LeaderboardUserData {
  final int rank;
  final String name;
  final String initials;
  final String? subtitle;
  final String score;
  final String? avatarUrl;
  final String badgeText;
  final IconData badgeIcon;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final bool isCurrentUser;

  const LeaderboardUserData({
    required this.rank,
    required this.name,
    required this.initials,
    this.subtitle,
    required this.score,
    this.avatarUrl,
    required this.badgeText,
    required this.badgeIcon,
    required this.badgeBgColor,
    required this.badgeTextColor,
    this.isCurrentUser = false,
  });
}

class PodiumUserData {
  final String name;
  final String initials;
  final String score;
  final String? avatarUrl;

  const PodiumUserData({
    required this.name,
    required this.initials,
    required this.score,
    this.avatarUrl,
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
  final String initials;
  final String stat;
  final String badgePill;
  final String? avatarUrl;

  const CurrentUserRankData({
    required this.rank,
    required this.name,
    required this.initials,
    required this.stat,
    required this.badgePill,
    this.avatarUrl,
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
  final LeaderboardService? leaderboardService;

  const UserLeaderboardScreen({
    super.key,
    this.leaderboardService,
  });

  @override
  State<UserLeaderboardScreen> createState() => _UserLeaderboardScreenState();
}

class _UserLeaderboardScreenState extends State<UserLeaderboardScreen> {
  late final LeaderboardService _leaderboardService;
  StreamSubscription<HazardReportData>? _reportSubscription;

  int _selectedTabIndex = 0; // 0: Safety Points, 1: Reports, 2: Routes
  bool _isWeekly = false;
  bool _isLoading = true;
  List<LeaderboardUserEntry> _entries = const <LeaderboardUserEntry>[];

  @override
  void initState() {
    super.initState();
    _leaderboardService = widget.leaderboardService ?? LeaderboardService();
    _loadLeaderboard();
    _reportSubscription = HazardReportService.reportStream.listen((_) {
      _loadLeaderboard();
    });
  }

  @override
  void dispose() {
    _reportSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    if (mounted && _entries.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final fetched = await _leaderboardService.fetchLeaderboard(
        isWeekly: _isWeekly,
      );
      if (!mounted) return;
      setState(() {
        _entries = fetched;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _toggleTimeframe() {
    setState(() {
      _isWeekly = !_isWeekly;
      _isLoading = true;
    });
    _loadLeaderboard();
  }

  ({
    String text,
    IconData icon,
    Color bgColor,
    Color textColor,
  }) _badgeStyleForLevel(LevelProgressData levelProgress) {
    final label = levelProgress.badgeLabel;
    switch (label) {
      case 'Hero':
        return (
          text: 'Hero',
          icon: Icons.shield_rounded,
          bgColor: const Color(0xFFEBF3FC),
          textColor: const Color(0xFF2B548F),
        );
      case 'Guard':
        return (
          text: 'Guard',
          icon: Icons.star_rounded,
          bgColor: const Color(0xFFEBF3FC),
          textColor: const Color(0xFF2B548F),
        );
      case 'Scout':
        return (
          text: 'Scout',
          icon: Icons.local_fire_department_rounded,
          bgColor: const Color(0xFFFFF7EB),
          textColor: const Color(0xFFC27803),
        );
      case 'Watcher':
        return (
          text: 'Watcher',
          icon: Icons.remove_red_eye_rounded,
          bgColor: const Color(0xFFE8F5E9),
          textColor: const Color(0xFF2E7D32),
        );
      case 'Rookie':
      default:
        return (
          text: 'Rookie',
          icon: Icons.lightbulb_outline_rounded,
          bgColor: const Color(0xFFFFF9E6),
          textColor: const Color(0xFFB78103),
        );
    }
  }

  String _podiumScoreLabel(LeaderboardUserEntry entry, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return '${entry.reportCount} ${entry.reportCount == 1 ? 'report' : 'reports'}';
      case 2:
        return '${entry.savedRoutesCount} ${entry.savedRoutesCount == 1 ? 'route' : 'routes'}';
      case 0:
      default:
        return '${entry.safetyPoints} pts';
    }
  }

  String _rowScoreLabel(LeaderboardUserEntry entry, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return '${entry.reportCount}';
      case 2:
        return '${entry.savedRoutesCount}';
      case 0:
      default:
        return '${entry.safetyPoints}';
    }
  }

  String _rowSubtitle(LeaderboardUserEntry entry, int tabIndex) {
    final prefix = entry.isCurrentUser ? 'You · ' : '';
    final levelText = 'Lv ${entry.levelProgress.level}';
    switch (tabIndex) {
      case 1:
        return '$prefix${entry.safetyPoints} pts · $levelText';
      case 2:
        return '$prefix${entry.reportCount} ${entry.reportCount == 1 ? 'report' : 'reports'} · ${entry.safetyPoints} pts';
      case 0:
      default:
        return '$prefix${entry.reportCount} ${entry.reportCount == 1 ? 'report' : 'reports'} · $levelText';
    }
  }

  TabLeaderboardData _buildTabLeaderboardData(int tabIndex) {
    final sorted = LeaderboardService.sortEntriesForCategory(
      _entries,
      tabIndex,
    );

    final String scoreHeader = tabIndex == 1
        ? 'REPORTS'
        : (tabIndex == 2 ? 'ROUTES' : 'POINTS');

    PodiumUserData toPodiumSpot(int idx) {
      if (idx < sorted.length) {
        final e = sorted[idx];
        return PodiumUserData(
          name: e.displayName,
          initials: e.initials,
          score: _podiumScoreLabel(e, tabIndex),
          avatarUrl: e.avatarUrl,
        );
      }
      return PodiumUserData(
        name: '—',
        initials: '—',
        score: tabIndex == 1
            ? '0 reports'
            : (tabIndex == 2 ? '0 routes' : '0 pts'),
      );
    }

    final podium = PodiumData(
      first: toPodiumSpot(0),
      second: toPodiumSpot(1),
      third: toPodiumSpot(2),
    );

    int myIndex = sorted.indexWhere((e) => e.isCurrentUser);
    LeaderboardUserEntry? myEntry = myIndex >= 0 ? sorted[myIndex] : null;
    if (myEntry == null && sorted.isNotEmpty) {
      myIndex = 0;
      myEntry = sorted.first;
    }

    final int myRankNumber = myIndex >= 0 ? myIndex + 1 : 1;
    final CurrentUserRankData currentUserRank;
    if (myEntry != null) {
      final String statText;
      if (tabIndex == 1) {
        statText =
            '${myEntry.reportCount} ${myEntry.reportCount == 1 ? 'report' : 'reports'} · ${myEntry.safetyPoints} pts · Level ${myEntry.levelProgress.level}';
      } else if (tabIndex == 2) {
        statText =
            '${myEntry.savedRoutesCount} ${myEntry.savedRoutesCount == 1 ? 'route' : 'routes'} · Level ${myEntry.levelProgress.level}';
      } else {
        statText =
            '${myEntry.safetyPoints} pts · ${myEntry.reportCount} ${myEntry.reportCount == 1 ? 'report' : 'reports'} · Level ${myEntry.levelProgress.level}';
      }

      currentUserRank = CurrentUserRankData(
        rank: '#$myRankNumber',
        name: myEntry.isCurrentUser
            ? 'You · ${myEntry.displayName}'
            : myEntry.displayName,
        initials: myEntry.initials,
        stat: statText,
        badgePill: myRankNumber <= 3
            ? 'TOP 3'
            : (myRankNumber <= 10
                ? 'TOP 10'
                : 'LVL ${myEntry.levelProgress.level}'),
        avatarUrl: myEntry.avatarUrl,
      );
    } else {
      currentUserRank = const CurrentUserRankData(
        rank: '#1',
        name: 'You',
        initials: 'YO',
        stat: '0 pts · 0 reports · Level 1',
        badgePill: 'LVL 1',
      );
    }

    final list = <LeaderboardUserData>[];
    for (int i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      final badge = _badgeStyleForLevel(entry.levelProgress);
      list.add(
        LeaderboardUserData(
          rank: i + 1,
          name: entry.displayName,
          initials: entry.initials,
          subtitle: _rowSubtitle(entry, tabIndex),
          score: _rowScoreLabel(entry, tabIndex),
          avatarUrl: entry.avatarUrl,
          badgeText: badge.text,
          badgeIcon: badge.icon,
          badgeBgColor: badge.bgColor,
          badgeTextColor: badge.textColor,
          isCurrentUser: entry.isCurrentUser,
        ),
      );
    }

    return TabLeaderboardData(
      scoreColumnHeader: scoreHeader,
      podium: podium,
      currentUser: currentUserRank,
      list: list,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _buildTabLeaderboardData(_selectedTabIndex);

    return Scaffold(
      backgroundColor: _bgBeige,
      body: Stack(
        children: [
          // Background layer: top is consistent navy header, bottom is beige
          Column(
            children: [
              Expanded(
                child: Container(color: _navyHeader),
              ),
              Expanded(
                child: Container(color: _bgBeige),
              ),
            ],
          ),
          RefreshIndicator(
            color: _navyHeader,
            onRefresh: _loadLeaderboard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Navy Header Section with Podium
                  _buildNavyHeader(currentData.podium),

                  // 2. Main Body Content (Rank Card, List, Points Guide)
                  Container(
                    color: _bgBeige,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),

                          // Current User Rank Card (dynamically reflects selected tab)
                          _buildCurrentUserRankCard(currentData.currentUser),

                          const SizedBox(height: 20),

                          if (_isLoading && _entries.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(color: _navyHeader),
                              ),
                            )
                          else
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
                  ),
                ],
              ),
            ),
          ),
        ],
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

            // App Bar Area (Back arrow, Leaderboard title, Timeframe pill)
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
                  // Timeframe Pill Button ("All Time" / "This Week")
                  InkWell(
                    onTap: _toggleTimeframe,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26498A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isWeekly ? 'This Week' : 'All Time',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ],
                      ),
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

  Widget _buildAvatarWidget({
    required String? avatarUrl,
    required String initials,
    required double radius,
  }) {
    final hasUrl = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEFF5FB),
      child: hasUrl
          ? ClipOval(
              child: Image.network(
                avatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Text(
                  initials,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: radius * 0.75,
                    fontWeight: FontWeight.w700,
                    color: _primaryNavy,
                  ),
                ),
              ),
            )
          : Text(
              initials,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w700,
                color: _primaryNavy,
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
                  initials: data.second.initials,
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
                  initials: data.first.initials,
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
                  initials: data.third.initials,
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
    required String initials,
    required String score,
    required String? avatarUrl,
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

        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: _buildAvatarWidget(
                avatarUrl: avatarUrl,
                initials: initials,
                radius: avatarRadius,
              ),
            ),
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

          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: _buildAvatarWidget(
              avatarUrl: user.avatarUrl,
              initials: user.initials,
              radius: 19,
            ),
          ),

          const SizedBox(width: 12),

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
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: 10,
            ),
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
                  width: 96,
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

          ...users.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            final isLast = index == users.length - 1;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLeaderboardRow(user),
                if (!isLast)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F3F6),
                  ),
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
          SizedBox(
            width: 38,
            child: _buildRankBadge(user.rank),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Row(
              children: [
                _buildAvatarWidget(
                  avatarUrl: user.avatarUrl,
                  initials: user.initials,
                  radius: 16,
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
                          fontWeight: user.isCurrentUser
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: _primaryNavy,
                        ),
                      ),
                      if (user.subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          user.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: user.isCurrentUser
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: user.isCurrentUser
                                ? const Color(0xFF1E6FD9)
                                : _secondaryGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

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

          SizedBox(
            width: 96,
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
                    Flexible(
                      child: Text(
                        user.badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: user.badgeTextColor,
                        ),
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
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF2E7D32),
            iconBgColor: const Color(0xFFE8F5E9),
            title: 'Low severity hazard report',
            pointsText: '+1 pt · Counts as 1 report',
          ),

          const SizedBox(height: 12),

          _buildPointGuideItem(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFF57F17),
            iconBgColor: const Color(0xFFFFF8E1),
            title: 'Medium severity hazard report',
            pointsText: '+2 pts · Counts as 1 report',
          ),

          const SizedBox(height: 12),

          _buildPointGuideItem(
            icon: Icons.report_problem_rounded,
            iconColor: const Color(0xFFC62828),
            iconBgColor: const Color(0xFFFFEBEE),
            title: 'High severity hazard report',
            pointsText: '+3 pts · Counts as 1 report',
          ),

          const SizedBox(height: 12),

          _buildPointGuideItem(
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF1E6FD9),
            iconBgColor: const Color(0xFFEBF3FC),
            title: 'Contributor Level Progression',
            pointsText:
                'Level 1 requires 20 pts · +1/4 more pts each level up (Lv 2: 25 pts)',
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
