import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_analytics_service.dart';
import 'admin_reports_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_settings_screens.dart';
import 'admin_report_detail_modal.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Future<AdminAnalyticsRawSnapshot> Function()? analyticsLoader;

  const AdminDashboardScreen({super.key, this.analyticsLoader});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int? _activeUsersCount;
  bool _isLoadingUsers = true;
  int? _overallReportsCount;
  bool _isLoadingOverallReports = true;
  int? _reportsTodayCount;
  bool _isLoadingReportsToday = true;
  int? _verifiedThisWeekCount;
  bool _isLoadingVerifiedThisWeek = true;
  AdminAnalyticsRawSnapshot? _analyticsSnapshot;
  AdminSafetyAnalytics _analytics = AdminSafetyAnalytics.empty();
  bool _isLoadingAnalytics = true;
  List<AdminReportItem> _latestReports = <AdminReportItem>[];
  bool _isLoadingReports = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    await Future.wait([
      _fetchActiveUsersCount(),
      _fetchLatestReports(),
      _fetchOverallReportsCount(),
      _fetchReportsTodayCount(),
      _fetchVerifiedThisWeekCount(),
      _fetchSafetyAnalytics(),
    ]);
  }

  Future<void> _fetchActiveUsersCount() async {
    try {
      final client = Supabase.instance.client;
      final count = await client
          .from('profiles')
          .count(CountOption.exact)
          .eq('role', 'user');

      if (!mounted) return;
      setState(() {
        _activeUsersCount = count;
        _isLoadingUsers = false;
      });
    } catch (e) {
      debugPrint('Error fetching active users count: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _fetchLatestReports() async {
    try {
      final client = Supabase.instance.client;
      final dynamic rawReports = await client
          .from('ReportTable')
          .select()
          .order('created_at', ascending: false)
          .limit(3);

      final List<Map<String, dynamic>> reportRows = [];
      final Set<String> userIds = <String>{};

      if (rawReports is List) {
        for (final item in rawReports) {
          if (item is Map<String, dynamic>) {
            reportRows.add(item);
            final uid = item['user_id']?.toString().trim();
            if (uid != null && uid.isNotEmpty) {
              userIds.add(uid);
            }
          }
        }
      }

      final Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        try {
          final dynamic profilesData = await client
              .from('profiles')
              .select('id, full_name, username, email, avatar_url')
              .inFilter('id', userIds.toList());

          if (profilesData is List) {
            for (final p in profilesData) {
              if (p is Map<String, dynamic> && p['id'] != null) {
                profilesMap[p['id'].toString()] = p;
              }
            }
          }
        } catch (pe) {
          debugPrint('Dashboard profiles fetch skipped: $pe');
        }
      }

      final parsed = reportRows.map((r) {
        final uid = r['user_id']?.toString().trim();
        final profile = uid != null ? profilesMap[uid] : null;
        return AdminReportItem.fromRow(r, profile: profile);
      }).toList();

      if (!mounted) return;
      setState(() {
        _latestReports = parsed;
        _isLoadingReports = false;
      });
    } catch (e) {
      debugPrint('Error fetching latest reports: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _fetchOverallReportsCount() async {
    try {
      final client = Supabase.instance.client;
      final count = await client
          .from('ReportTable')
          .count(CountOption.exact)
          .inFilter('status', ['active', 'resolved', 'archived']);
      if (!mounted) return;
      setState(() {
        _overallReportsCount = count;
        _isLoadingOverallReports = false;
      });
    } catch (e) {
      debugPrint('Error fetching overall reports count: $e');
      if (!mounted) return;
      setState(() => _isLoadingOverallReports = false);
    }
  }

  String get _overallReportsDisplay {
    if (_isLoadingOverallReports) return '...';
    return (_overallReportsCount ?? 0).toString();
  }

  Future<void> _fetchReportsTodayCount() async {
    try {
      final client = Supabase.instance.client;
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfToday.add(const Duration(days: 1));

      final count = await client
          .from('ReportTable')
          .count(CountOption.exact)
          .eq('status', 'pending')
          .gte('created_at', startOfToday.toUtc().toIso8601String())
          .lt('created_at', startOfTomorrow.toUtc().toIso8601String());

      if (!mounted) return;
      setState(() {
        _reportsTodayCount = count;
        _isLoadingReportsToday = false;
      });
    } catch (e) {
      debugPrint('Error fetching reports today count: $e');
      if (!mounted) return;
      setState(() => _isLoadingReportsToday = false);
    }
  }

  String get _reportsTodayDisplay {
    if (_isLoadingReportsToday) return '...';
    return (_reportsTodayCount ?? 0).toString();
  }

  Future<void> _fetchVerifiedThisWeekCount() async {
    try {
      final client = Supabase.instance.client;
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      final count = await client
          .from('ReportTable')
          .count(CountOption.exact)
          .eq('status', 'active')
          .gte('created_at', oneWeekAgo.toUtc().toIso8601String());

      if (!mounted) return;
      setState(() {
        _verifiedThisWeekCount = count;
        _isLoadingVerifiedThisWeek = false;
      });
    } catch (e) {
      debugPrint('Error fetching verified this week count: $e');
      if (!mounted) return;
      setState(() => _isLoadingVerifiedThisWeek = false);
    }
  }

  String get _verifiedThisWeekDisplay {
    if (_isLoadingVerifiedThisWeek) return '...';
    return (_verifiedThisWeekCount ?? 0).toString();
  }

  Future<void> _fetchSafetyAnalytics() async {
    try {
      final snapshot = widget.analyticsLoader != null
          ? await widget.analyticsLoader!()
          : await const AdminAnalyticsService().fetchRawSnapshot();
      final computed = snapshot.compute(
        timeframe: AnalyticsTimeframe.allTime,
      );

      if (!mounted) return;
      setState(() {
        _analyticsSnapshot = snapshot;
        _analytics = computed;
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      debugPrint('Error fetching safety analytics: $e');
      if (!mounted) return;
      setState(() => _isLoadingAnalytics = false);
    }
  }

  String get _activeUsersDisplay {
    if (_isLoadingUsers) {
      return '...';
    }
    if (_activeUsersCount == null) {
      return '0';
    }
    return _activeUsersCount!.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/image/saferoute_admin_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isSmallScreen = screenWidth < 360;
              final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
              final isTablet = screenWidth >= 600;
              final isDesktop = screenWidth >= 1200;

              final padding = isDesktop
                  ? 48.0
                  : (isTablet ? 32.0 : (isSmallScreen ? 12.0 : 20.0));
              final verticalSpacing =
                  isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

              return RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _buildSafeRouteLogo(isDesktop: isDesktop),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderIcons(
                            isTablet: isTablet,
                            context: context,
                          ),
                        ],
                      ),
                      SizedBox(height: verticalSpacing),
                      _buildGreeting(
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      SizedBox(height: verticalSpacing),
                      _buildReviewReportsButton(
                        isSmallScreen: isSmallScreen,
                        context: context,
                      ),
                      SizedBox(height: verticalSpacing),
                      _buildStatsCards(
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      SizedBox(height: verticalSpacing),
                      _buildLatestReportsSection(
                        context: context,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      SizedBox(height: verticalSpacing),
                      _buildSafetyAnalyticsSection(
                        context: context,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      SizedBox(height: verticalSpacing * 4),
                    ],
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

  Widget _buildSafeRouteLogo({required bool isDesktop}) {
    final logoWidth = isDesktop ? 75.0 : 59.0;
    final logoHeight = isDesktop ? 83.0 : 65.0;
    final fontSize = isDesktop ? 30.0 : 25.0;

    return Row(
      children: [
        Container(
          width: logoWidth,
          height: logoHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: const DecorationImage(
              image: AssetImage("assets/image/LogoSR.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Safe',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF45596E),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: 'Route',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF8AABCE),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderIcons({required bool isTablet, required BuildContext context}) {
    return SizedBox(
      height: isTablet ? 48 : 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminReportsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: const _BellIcon(),
          ),
          SizedBox(width: isTablet ? 12 : 10),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: const _MaleIcon(),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting({required bool isSmallScreen, required bool isTablet, required bool isDesktop}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, Admin.',
          style: GoogleFonts.inter(
            color: const Color(0xFF5B6B7A),
            fontSize: isDesktop ? 24 : (isTablet ? 20 : (isSmallScreen ? 14 : 16)),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isDesktop ? 10 : 6),
        Text(
          'Keep your community informed.',
          style: GoogleFonts.inter(
            color: const Color(0xFF1F3A5F),
            fontSize: isDesktop ? 40 : (isTablet ? 34 : (isSmallScreen ? 24 : 28)),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewReportsButton({required bool isSmallScreen, required BuildContext context}) {
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final verticalPadding = isSmallScreen ? 12.0 : 14.0;
    final fontSize = isSmallScreen ? 14.0 : 16.0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminReportsScreen()),
        ).then((_) => _fetchDashboardData());
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            width: 1,
            color: const Color(0xFFD9E2EC),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: isSmallScreen ? 20 : 24,
              color: const Color(0xFF1F3A5F),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              'Manage reports',
              style: GoogleFonts.inter(
                color: const Color(0xFF1F3A5F),
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: isSmallScreen ? 16 : 20,
              color: const Color(0xFF1F3A5F),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards({
    required bool isSmallScreen,
    required bool isMediumScreen,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final spacing = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    if (isSmallScreen) {
      // Single column layout for very small screens
      return Column(
        children: [
          _StatCard(
            iconColor: const Color(0xFFE8F7F0),
            label: 'Overall Reports',
            value: _overallReportsDisplay,
            change: '+12%',
            isSmallScreen: true,
            isTablet: false,
            isDesktop: false,
            icon: Icons.flag,
            hasSecondaryIcon: true,
            secondaryIcon: Icons.arrow_upward,
          ),
          SizedBox(height: spacing),
          _StatCard(
            iconColor: const Color(0xFFFFF1E6),
            label: 'Report today',
            value: _reportsTodayDisplay,
            change: 'Needs Attention',
            isSmallScreen: true,
            isTablet: false,
            isDesktop: false,
            icon: Icons.warning,
            hasSecondaryIcon: true,
          ),
          SizedBox(height: spacing),
          _StatCard(
            iconColor: const Color(0xFFE8F7F0),
            label: 'Verified this week',
            value: _verifiedThisWeekDisplay,
            change: '+18%',
            isSmallScreen: true,
            isTablet: false,
            isDesktop: false,
            icon: Icons.check_circle,
            hasSecondaryIcon: true,
            secondaryIcon: Icons.arrow_upward,
          ),
          SizedBox(height: spacing),
          _StatCard(
            iconColor: const Color(0xFFFCE8F3),
            label: 'Active users',
            value: _activeUsersDisplay,
            change: '+9%',
            isSmallScreen: true,
            isTablet: false,
            isDesktop: false,
            icon: Icons.people,
            hasSecondaryIcon: true,
            secondaryIcon: Icons.arrow_upward,
          ),
        ],
      );
    }

    // 2x2 grid for normal screens, 4x1 for desktop
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                iconColor: const Color(0xFFE8F7F0),
                label: 'Overall Reports',
                value: _overallReportsDisplay,
                change: '+12%',
                isSmallScreen: false,
                isTablet: isTablet,
                isDesktop: isDesktop,
                icon: Icons.flag,
                hasSecondaryIcon: true,
                secondaryIcon: Icons.arrow_upward,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _StatCard(
                iconColor: const Color(0xFFFFF1E6),
                label: 'Report today',
                value: _reportsTodayDisplay,
                change: 'Needs Attention',
                isSmallScreen: false,
                isTablet: isTablet,
                isDesktop: isDesktop,
                icon: Icons.warning,
                hasSecondaryIcon: true,
              ),
            ),
            if (isDesktop) SizedBox(width: spacing),
            if (isDesktop)
              Expanded(
                child: _StatCard(
                  iconColor: const Color(0xFFE8F7F0),
                  label: 'Verified this week',
                  value: _verifiedThisWeekDisplay,
                  change: '+18%',
                  isSmallScreen: false,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  icon: Icons.check_circle,
                  hasSecondaryIcon: true,
                  secondaryIcon: Icons.arrow_upward,
                ),
              ),
            if (isDesktop) SizedBox(width: spacing),
            if (isDesktop)
              Expanded(
                child: _StatCard(
                  iconColor: const Color(0xFFFCE8F3),
                  label: 'Active users',
                  value: _activeUsersDisplay,
                  change: '+9%',
                  isSmallScreen: false,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  icon: Icons.people,
                  hasSecondaryIcon: true,
                  secondaryIcon: Icons.arrow_upward,
                ),
              ),
          ],
        ),
        if (!isDesktop) SizedBox(height: spacing),
        if (!isDesktop)
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  iconColor: const Color(0xFFE8F7F0),
                  label: 'Verified this week',
                  value: _verifiedThisWeekDisplay,
                  change: '+18%',
                  isSmallScreen: false,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  icon: Icons.check_circle,
                  hasSecondaryIcon: true,
                  secondaryIcon: Icons.arrow_upward,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _StatCard(
                  iconColor: const Color(0xFFFCE8F3),
                  label: 'Active users',
                  value: _activeUsersDisplay,
                  change: '+9%',
                  isSmallScreen: false,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  icon: Icons.people,
                  hasSecondaryIcon: true,
                  secondaryIcon: Icons.arrow_upward,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLatestReportsSection({
    required BuildContext context,
    required bool isSmallScreen,
    required bool isMediumScreen,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final padding = isDesktop ? 32.0 : (isTablet ? 24.0 : (isSmallScreen ? 12.0 : 16.0));
    final spacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

    void openReports() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminReportsScreen()),
      ).then((_) => _fetchDashboardData());
    }

    void openReportModal(AdminReportItem report) async {
      final updated = await showAdminReportDetailModal(
        context: context,
        report: report,
        onReportUpdated: _fetchDashboardData,
      );
      if (updated == true) {
        _fetchDashboardData();
      }
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          width: 1,
          color: const Color(0xFFD9E2EC),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121F3A5F),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            iconColor: const Color(0xFFFFF4CC),
            label: 'REQUIRES ACTION',
            showViewAll: true,
            onViewAll: openReports,
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            icon: Icons.flash_on,
            iconSizeMultiplier: 1.3,
          ),
          SizedBox(height: spacing),
          Text(
            'Latest reports.',
            style: GoogleFonts.inter(
              color: const Color(0xFF1F3A5F),
              fontSize: isDesktop ? 28 : (isTablet ? 24 : (isSmallScreen ? 18 : 20)),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing),
          if (_isLoadingReports)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1F3A5F),
                ),
              ),
            )
          else if (_latestReports.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No reports pending review at this time.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7B9BAD),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ..._latestReports.asMap().entries.map((entry) {
              final index = entry.key;
              final report = entry.value;
              final isPending = report.status.toLowerCase() == 'pending';
              final isActive = report.status.toLowerCase() == 'active';

              Color statusBg;
              if (isActive) {
                statusBg = const Color(0xFFE8F7F0);
              } else if (isPending) {
                statusBg = const Color(0xFFFFF1E6);
              } else {
                statusBg = const Color(0xFFF0F4F8);
              }

              return Column(
                children: [
                  if (index > 0) SizedBox(height: spacing),
                  _ReportItem(
                    title: report.detectedHazard,
                    location: report.locationAddress,
                    reporterName: report.reporterName,
                    imageUrl: report.imageUrl,
                    time: formatRelativeTime(report.createdAt),
                    status: report.status.toUpperCase(),
                    statusColor: statusBg,
                    isSmallScreen: isSmallScreen,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    onTap: () => openReportModal(report),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSafetyAnalyticsSection({
    required BuildContext context,
    required bool isSmallScreen,
    required bool isMediumScreen,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final padding =
        isDesktop ? 32.0 : (isTablet ? 24.0 : (isSmallScreen ? 12.0 : 16.0));
    final spacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
    final innerSpacing = isDesktop ? 14.0 : 10.0;

    const navy = Color(0xFF1F3A5F);
    const highRiskColor = Color(0xFFDC2626);
    const mediumRiskColor = Color(0xFFF59E0B);
    const lowRiskColor = Color(0xFF10B981);

    final activeTotal = _analytics.activeHazardsCount;
    final String activeCountLabel =
        _isLoadingAnalytics ? '...' : '$activeTotal';

    String formatSeverityValue(int count) {
      if (_isLoadingAnalytics) return '...';
      if (activeTotal == 0) return '0';
      final pct = ((count / activeTotal) * 100).round();
      return '$count ($pct%)';
    }

    final riskBadgeColor = activeTotal == 0
        ? const Color(0xFFE8F7F0)
        : (_analytics.activeHighCount > 0
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFFEF3C7));
    final riskBadgeTextColor = activeTotal == 0
        ? const Color(0xFF047857)
        : (_analytics.activeHighCount > 0
            ? const Color(0xFFB91C1C)
            : const Color(0xFFB45309));

    final topCategories = _analytics.topCategories.take(3).toList();
    final topHotspot =
        _analytics.topHotspots.isNotEmpty ? _analytics.topHotspots.first : null;

    void openFullAnalytics() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminAnalyticsScreen(
            initialSnapshot: _analyticsSnapshot,
          ),
        ),
      ).then((_) => _fetchDashboardData());
    }

    Widget buildSeverityBreakdownColumn() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active hazard severity',
            style: GoogleFonts.inter(
              color: navy,
              fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: innerSpacing),
          _LegendItem(
            color: highRiskColor,
            label: 'High severity',
            value: formatSeverityValue(_analytics.activeHighCount),
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
          SizedBox(height: innerSpacing * 0.75),
          _LegendItem(
            color: mediumRiskColor,
            label: 'Medium severity',
            value: formatSeverityValue(_analytics.activeMediumCount),
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
          SizedBox(height: innerSpacing * 0.75),
          _LegendItem(
            color: lowRiskColor,
            label: 'Low severity',
            value: formatSeverityValue(_analytics.activeLowCount),
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
        ],
      );
    }

    final clearedPill = _AnalyticsMetricPill(
      label: 'Cleared Rate',
      value: _isLoadingAnalytics
          ? '...'
          : (_analytics.hasResolutionDenominator
              ? '${_analytics.resolutionRatePercent}%'
              : '—'),
      sublabel: _isLoadingAnalytics
          ? 'Resolved vs active'
          : '${_analytics.resolvedReportsAllTime} resolved',
      accentColor: const Color(0xFF0F766E),
      bgColor: const Color(0xFFE8F7F0),
    );

    final reviewQueuePill = InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminReportsScreen(),
          ),
        ).then((_) => _fetchDashboardData());
      },
      borderRadius: BorderRadius.circular(14),
      child: _AnalyticsMetricPill(
        label: 'Review Queue',
        value: _isLoadingAnalytics ? '...' : '${_analytics.totalActionQueue}',
        sublabel: _isLoadingAnalytics
            ? 'Pending triage'
            : '${_analytics.pendingReportsCount} new · ${_analytics.pendingResolutionProofsCount} clear',
        accentColor: _analytics.totalActionQueue > 0
            ? const Color(0xFFB45309)
            : navy,
        bgColor: _analytics.totalActionQueue > 0
            ? const Color(0xFFFFF1E6)
            : const Color(0xFFF8FAFC),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          width: 1,
          color: const Color(0xFFD9E2EC),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121F3A5F),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            iconColor: const Color(0xFFEEF4F8),
            label: 'ANALYTICS',
            showViewAll: true,
            onViewAll: openFullAnalytics,
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            icon: Icons.analytics,
            iconSizeMultiplier: 1.3,
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hazard operations.',
                  style: GoogleFonts.inter(
                    color: navy,
                    fontSize: isDesktop
                        ? 28
                        : (isTablet ? 24 : (isSmallScreen ? 18 : 20)),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: riskBadgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: riskBadgeTextColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isLoadingAnalytics
                          ? 'Loading'
                          : _analytics.overallRiskLabel,
                      style: GoogleFonts.inter(
                        color: riskBadgeTextColor,
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          if (isSmallScreen)
            Column(
              children: [
                _HazardSeverityDonut(
                  centerValue: activeCountLabel,
                  centerSubtitle: activeTotal == 0 && !_isLoadingAnalytics
                      ? 'all clear'
                      : 'active',
                  highCount: _analytics.activeHighCount,
                  mediumCount: _analytics.activeMediumCount,
                  lowCount: _analytics.activeLowCount,
                  isSmallScreen: true,
                  isTablet: false,
                  isDesktop: false,
                ),
                SizedBox(height: spacing),
                buildSeverityBreakdownColumn(),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HazardSeverityDonut(
                  centerValue: activeCountLabel,
                  centerSubtitle: activeTotal == 0 && !_isLoadingAnalytics
                      ? 'all clear'
                      : 'active',
                  highCount: _analytics.activeHighCount,
                  mediumCount: _analytics.activeMediumCount,
                  lowCount: _analytics.activeLowCount,
                  isSmallScreen: false,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
                SizedBox(width: spacing),
                Expanded(child: buildSeverityBreakdownColumn()),
              ],
            ),
          SizedBox(height: spacing),
          // Symmetric operational health & triage queue row
          Row(
            children: [
              Expanded(child: clearedPill),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(child: reviewQueuePill),
            ],
          ),
          if (topCategories.isNotEmpty) ...[
            SizedBox(height: spacing),
            const Divider(height: 1, color: Color(0xFFE6EDF5)),
            SizedBox(height: innerSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Top Hazard Categories',
                    style: GoogleFonts.inter(
                      color: navy,
                      fontSize: isSmallScreen ? 12.5 : 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '7d: ${_analytics.sevenDayReportedTotal} new · ${_analytics.sevenDayResolvedTotal} cleared',
                    style: GoogleFonts.inter(
                      color: navy,
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < topCategories.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _CategoryMiniBar(
                stat: topCategories[i],
                maxTotal: topCategories.first.totalCount,
                barColor: topCategories[i].highSeverityCount > 0
                    ? navy
                    : const Color(0xFF61B5AB),
              ),
            ],
          ],
          if (topHotspot != null) ...[
            SizedBox(height: innerSpacing),
            InkWell(
              onTap: openFullAnalytics,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6EDF5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Top hotspot: ${topHotspot.areaLabel} (${topHotspot.activeCount} active · ${topHotspot.totalCount} total)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: navy,
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF5B6B7A),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required Color iconColor,
    required String label,
    required bool showViewAll,
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDesktop,
    VoidCallback? onViewAll,
    IconData? icon,
    double iconSizeMultiplier = 1.0,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: (isDesktop ? 44 : (isTablet ? 36 : (isSmallScreen ? 24 : 28))) * iconSizeMultiplier,
                height: (isDesktop ? 44 : (isTablet ? 36 : (isSmallScreen ? 24 : 28))) * iconSizeMultiplier,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: icon != null
                    ? Icon(
                        icon,
                        size: (isDesktop ? 22 : (isTablet ? 18 : (isSmallScreen ? 12 : 14))) * iconSizeMultiplier,
                        color: const Color(0xFF1F3A5F),
                      )
                    : null,
              ),
              SizedBox(width: isDesktop ? 14 : (isTablet ? 12 : (isSmallScreen ? 8 : 10))),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1F3A5F),
                    fontSize: isDesktop ? 15 : (isTablet ? 13 : (isSmallScreen ? 10 : 11)),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.60,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showViewAll) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onViewAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1F3A5F),
                      fontSize: isDesktop ? 18 : (isTablet ? 16 : (isSmallScreen ? 12 : 14)),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : (isTablet ? 6 : (isSmallScreen ? 4 : 5))),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: isDesktop ? 16 : (isTablet ? 14 : (isSmallScreen ? 10 : 12)),
                    color: const Color(0xFF1F3A5F),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BellIcon extends StatelessWidget {
  const _BellIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFEEF4F8),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.notifications_outlined,
        size: 24,
        color: Color(0xFF5B6B7A),
      ),
    );
  }
}

class _MaleIcon extends StatelessWidget {
  const _MaleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFEEF4F8),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_outline,
        size: 24,
        color: Color(0xFF5B6B7A),
      ),
    );
  }
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: const BoxDecoration(
        color: Color(0xFFEEF4F8),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.arrow_forward_ios,
        size: 12,
        color: Color(0xFF1F3A5F),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color iconColor;
  final String label;
  final String value;
  final String change;
  final bool isSmallScreen;
  final bool isTablet;
  final bool isDesktop;
  final IconData icon;
  final bool hasSecondaryIcon;
  final IconData? secondaryIcon;

  const _StatCard({
    required this.iconColor,
    required this.label,
    required this.value,
    required this.change,
    required this.isSmallScreen,
    required this.isTablet,
    required this.isDesktop,
    required this.icon,
    this.hasSecondaryIcon = false,
    this.secondaryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final height = isDesktop ? 200.0 : (isTablet ? 180.0 : (isSmallScreen ? 130.0 : 148.0));
    final padding = isDesktop ? 24.0 : (isTablet ? 20.0 : (isSmallScreen ? 12.0 : 14.0));

    return Container(
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          width: 1,
          color: const Color(0xFFD9E2EC),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121F3A5F),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isDesktop ? 48 : (isTablet ? 40 : (isSmallScreen ? 24 : 30)),
                height: isDesktop ? 48 : (isTablet ? 40 : (isSmallScreen ? 24 : 30)),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: isDesktop ? 24 : (isTablet ? 20 : (isSmallScreen ? 14 : 18)),
                  color: const Color(0xFF1F3A5F),
                ),
              ),
              const Spacer(),
              if (hasSecondaryIcon)
                Container(
                  width: isDesktop ? 32 : (isTablet ? 28 : (isSmallScreen ? 24 : 26)),
                  height: isDesktop ? 32 : (isTablet ? 28 : (isSmallScreen ? 24 : 26)),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        secondaryIcon ?? Icons.circle,
                        size: isDesktop ? 20 : (isTablet ? 18 : (isSmallScreen ? 16 : 18)),
                        color: const Color(0xFF1F3A5F),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF5B6B7A),
              fontSize: isDesktop ? 15 : (isTablet ? 13 : (isSmallScreen ? 10 : 11)),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.60,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFF1F3A5F),
              fontSize: isDesktop ? 40 : (isTablet ? 34 : (isSmallScreen ? 24 : 28)),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            change,
            style: GoogleFonts.inter(
              color: const Color(0xFF1F3A5F),
              fontSize: isDesktop ? 16 : (isTablet ? 14 : (isSmallScreen ? 11 : 12)),
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _ReportItem extends StatelessWidget {
  final String title;
  final String location;
  final String? reporterName;
  final String? imageUrl;
  final String time;
  final String status;
  final Color statusColor;
  final bool isSmallScreen;
  final bool isTablet;
  final bool isDesktop;
  final VoidCallback? onTap;

  const _ReportItem({
    required this.title,
    required this.location,
    this.reporterName,
    this.imageUrl,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.isSmallScreen,
    required this.isTablet,
    required this.isDesktop,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageSize = isDesktop ? 120.0 : (isTablet ? 96.0 : (isSmallScreen ? 60.0 : 72.0));
    final spacing = isDesktop ? 24.0 : (isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0));
    final padding = isDesktop ? 20.0 : (isTablet ? 16.0 : (isSmallScreen ? 10.0 : 12.0));

    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            width: 1,
            color: const Color(0xFFE6EDF5),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FB),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Image.network(
                    imageUrl!.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.report_problem,
                        size: 32,
                        color: Color(0xFF1F3A5F),
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(
                      Icons.report_problem,
                      size: 32,
                      color: Color(0xFF1F3A5F),
                    ),
                  ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1F3A5F),
                          fontSize: isDesktop ? 20 : (isTablet ? 18 : (isSmallScreen ? 13 : 15)),
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 12 : (isTablet ? 10 : (isSmallScreen ? 6 : 8)),
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1F3A5F),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1F3A5F),
                              fontSize: isDesktop ? 15 : (isTablet ? 13 : (isSmallScreen ? 10 : 11)),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing * 0.5),
                Text(
                  location,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF5B6B7A),
                    fontSize: isDesktop ? 17 : (isTablet ? 15 : (isSmallScreen ? 12 : 13)),
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (reporterName != null && reporterName!.isNotEmpty) ...[
                  SizedBox(height: spacing * 0.3),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 13,
                        color: Color(0xFF7B9BAD),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Reported by: $reporterName',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF7B9BAD),
                            fontSize: isDesktop ? 14 : (isTablet ? 13 : 11),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: spacing * 0.3),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7B8794),
                    fontSize: isDesktop ? 15 : (isTablet ? 13 : (isSmallScreen ? 10 : 11)),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing),
          const _SmallIcon(),
        ],
      ),
      ),
    );
  }
}

/// Segmented donut showing active road hazards grouped by severity
/// (High = Red, Medium = Amber, Low = Emerald) with center active count.
class _HazardSeverityDonut extends StatelessWidget {
  final String centerValue;
  final String centerSubtitle;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final bool isSmallScreen;
  final bool isTablet;
  final bool isDesktop;

  const _HazardSeverityDonut({
    required this.centerValue,
    required this.centerSubtitle,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.isSmallScreen,
    required this.isTablet,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final size = isDesktop
        ? 168.0
        : (isTablet ? 148.0 : (isSmallScreen ? 116.0 : 132.0));
    final fontSize = isDesktop
        ? 32.0
        : (isTablet ? 28.0 : (isSmallScreen ? 22.0 : 26.0));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _SeverityDonutPainter(
              highCount: highCount,
              mediumCount: mediumCount,
              lowCount: lowCount,
              trackColor: const Color(0xFFE8EEF2),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1F3A5F),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                centerSubtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF7B9BAD),
                  fontSize: isSmallScreen ? 9.5 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeverityDonutPainter extends CustomPainter {
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final Color trackColor;

  _SeverityDonutPainter({
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final strokeWidth = size.width * 0.125;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final total = highCount + mediumCount + lowCount;
    if (total <= 0) {
      final clearPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, clearPaint);
      return;
    }

    final segments = <(int, Color)>[
      (highCount, const Color(0xFFDC2626)),
      (mediumCount, const Color(0xFFF59E0B)),
      (lowCount, const Color(0xFF10B981)),
    ].where((s) => s.$1 > 0).toList();

    final double gapRad = segments.length > 1 ? 0.06 : 0.0;
    final double totalGap = gapRad * segments.length;
    final double usableArc = (2 * math.pi) - totalGap;

    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      final double sweep = usableArc * (seg.$1 / total);
      final paint = Paint()
        ..color = seg.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle + (gapRad / 2),
        math.max(0.02, sweep),
        false,
        paint,
      );
      startAngle += sweep + gapRad;
    }
  }

  @override
  bool shouldRepaint(covariant _SeverityDonutPainter old) =>
      old.highCount != highCount ||
      old.mediumCount != mediumCount ||
      old.lowCount != lowCount ||
      old.trackColor != trackColor;
}

class _AnalyticsMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final Color accentColor;
  final Color bgColor;

  const _AnalyticsMetricPill({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.accentColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF5B6B7A),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF7B8794),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMiniBar extends StatelessWidget {
  final HazardCategoryStat stat;
  final int maxTotal;
  final Color barColor;

  const _CategoryMiniBar({
    required this.stat,
    required this.maxTotal,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final double ratio =
        maxTotal > 0 ? (stat.totalCount / maxTotal).clamp(0.08, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1F3A5F),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stat.activeCount > 0
                  ? '${stat.activeCount} active · ${stat.totalCount} total'
                  : '${stat.totalCount} total',
              style: GoogleFonts.inter(
                color: const Color(0xFF5B6B7A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 7,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFE8EEF2),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final bool isSmallScreen;
  final bool isTablet;
  final bool isDesktop;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.isSmallScreen,
    required this.isTablet,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize = isDesktop ? 12.0 : (isTablet ? 11.0 : (isSmallScreen ? 8.0 : 10.0));
    final spacing = isDesktop ? 12.0 : (isTablet ? 10.0 : (isSmallScreen ? 6.0 : 8.0));
    final fontSize = isDesktop ? 13.0 : (isTablet ? 12.0 : (isSmallScreen ? 10.5 : 11.5));

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF5B6B7A),
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: spacing),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFF1F3A5F),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}