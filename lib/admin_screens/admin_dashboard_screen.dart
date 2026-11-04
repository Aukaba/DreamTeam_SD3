import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_reports_screen.dart';
import 'admin_profile_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isSmallScreen = screenWidth < 360;
            final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
            final isTablet = screenWidth >= 600;
            final isDesktop = screenWidth >= 1200;

            final padding = isDesktop ? 48.0 : (isTablet ? 32.0 : (isSmallScreen ? 12.0 : 20.0));
            final verticalSpacing = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSafeRouteLogo(isDesktop: isDesktop),
                        _buildHeaderIcons(isTablet: isTablet, context: context),
                      ],
                    ),
                    SizedBox(height: verticalSpacing),
                    _buildGreeting(isSmallScreen: isSmallScreen, isTablet: isTablet, isDesktop: isDesktop),
                    SizedBox(height: verticalSpacing),
                    _buildReviewReportsButton(isSmallScreen: isSmallScreen, context: context),
                    SizedBox(height: verticalSpacing),
                    _buildStatsCards(
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    ),
                    SizedBox(height: verticalSpacing),
                    _buildLatestReportsSection(
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    ),
                    SizedBox(height: verticalSpacing),
                    _buildAreasCoveredSection(
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    ),
                    SizedBox(height: verticalSpacing * 4),
                  ],
                ),
              ),
            );
          },
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
          const _BellIcon(),
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
        );
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
              'Review reports',
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
            value: '28',
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
            value: '3',
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
            value: '142',
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
            value: '2,481',
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
                value: '28',
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
                value: '3',
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
                  value: '142',
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
                  value: '2,481',
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
                  value: '142',
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
                  value: '2,481',
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
    required bool isSmallScreen,
    required bool isMediumScreen,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final padding = isDesktop ? 32.0 : (isTablet ? 24.0 : (isSmallScreen ? 12.0 : 16.0));
    final spacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

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
          _ReportItem(
            title: 'Flooded road',
            location: 'Near University Avenue',
            time: '8 min ago',
            status: 'Pending',
            statusColor: const Color(0xFFFFF1E6),
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
          SizedBox(height: spacing),
          _ReportItem(
            title: 'Road damage',
            location: 'Near Capitol Site',
            time: '9 min ago',
            status: 'Pending',
            statusColor: const Color(0xFFFFF1E6),
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
          SizedBox(height: spacing),
          _ReportItem(
            title: 'Minor accident',
            location: 'Near Fuente Osmeña Circle',
            time: '12 min ago',
            status: 'Verified',
            statusColor: const Color(0xFFE8F7F0),
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildAreasCoveredSection({
    required bool isSmallScreen,
    required bool isMediumScreen,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final padding = isDesktop ? 32.0 : (isTablet ? 24.0 : (isSmallScreen ? 12.0 : 16.0));
    final spacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
    final innerSpacing = isDesktop ? 16.0 : 12.0;

    // Colors shared by the ring and the legend so they always match.
    const navy = Color(0xFF1F3A5F);
    const teal = Color(0xFF61B5AB);

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
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
            isDesktop: isDesktop,
            icon: Icons.analytics,
            iconSizeMultiplier: 1.3,
          ),
          SizedBox(height: spacing),
          Text(
            'Areas covered.',
            style: GoogleFonts.inter(
              color: navy,
              fontSize: isDesktop ? 28 : (isTablet ? 24 : (isSmallScreen ? 18 : 20)),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing),
          if (isSmallScreen)
            Column(
              children: [
                _CircularProgress(
                  percentage: '92%',
                  progress: 0.92,
                  isSmallScreen: true,
                  isTablet: false,
                  isDesktop: false,
                ),
                SizedBox(height: spacing),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics',
                      style: GoogleFonts.inter(
                        color: navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: innerSpacing),
                    _LegendItem(
                      color: navy,
                      label: 'Reports verified',
                      value: '84%',
                      isSmallScreen: true,
                      isTablet: false,
                      isDesktop: false,
                    ),
                    SizedBox(height: innerSpacing),
                    _LegendItem(
                      color: teal,
                      label: 'Reports within 1hr',
                      value: '36%',
                      isSmallScreen: true,
                      isTablet: false,
                      isDesktop: false,
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CircularProgress(
                  percentage: '92%',
                  progress: 0.92,
                  isSmallScreen: false,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics',
                        style: GoogleFonts.inter(
                          color: navy,
                          fontSize: isDesktop ? 20 : (isTablet ? 18 : 15),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: innerSpacing),
                      _LegendItem(
                        color: navy,
                        label: 'Reports verified',
                        value: '84%',
                        isSmallScreen: false,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      SizedBox(height: innerSpacing),
                      _LegendItem(
                        color: teal,
                        label: 'Reports within 1hr',
                        value: '36%',
                        isSmallScreen: false,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Image.asset(
          'assets/image/LogoSR.png',
          width: 43,
          height: 47,
        ),
        const SizedBox(height: 8),
        Text.rich(
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
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required Color iconColor,
    required String label,
    required bool showViewAll,
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDesktop,
    IconData? icon,
    double iconSizeMultiplier = 1.0,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
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
        if (showViewAll)
          Row(
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
  final String time;
  final String status;
  final Color statusColor;
  final bool isSmallScreen;
  final bool isTablet;
  final bool isDesktop;

  const _ReportItem({
    required this.title,
    required this.location,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.isSmallScreen,
    required this.isTablet,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final imageSize = isDesktop ? 120.0 : (isTablet ? 96.0 : (isSmallScreen ? 60.0 : 72.0));
    final spacing = isDesktop ? 24.0 : (isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0));
    final padding = isDesktop ? 20.0 : (isTablet ? 16.0 : (isSmallScreen ? 10.0 : 12.0));

    return Container(
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
            child: const Icon(
              Icons.report_problem,
              size: 32,
              color: Color(0xFF1F3A5F),
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
                SizedBox(height: spacing),
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
                SizedBox(height: spacing),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7B8794),
                    fontSize: isDesktop ? 16 : (isTablet ? 14 : (isSmallScreen ? 11 : 12)),
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
    );
  }
}

/// Donut chart: [progress] of the ring is navy (starting at 12 o'clock,
/// clockwise) and the remaining part is teal.
class _CircularProgress extends StatelessWidget {
  final String percentage;
  final double progress; // 0.0 - 1.0
  final bool isSmallScreen;
  final bool isTablet;
  final bool isDesktop;

  const _CircularProgress({
    required this.percentage,
    this.progress = 0.92,
    required this.isSmallScreen,
    required this.isTablet,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final size = isDesktop ? 180.0 : (isTablet ? 160.0 : (isSmallScreen ? 120.0 : 140.0));
    final fontSize = isDesktop ? 36.0 : (isTablet ? 32.0 : (isSmallScreen ? 24.0 : 28.0));
    final strokeWidth = isDesktop ? 18.0 : (isTablet ? 16.0 : (isSmallScreen ? 10.0 : 14.0));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              progressColor: const Color(0xFF1F3A5F), // navy = the 92%
              trackColor: const Color(0xFF61B5AB), // teal = the remaining 8%
            ),
          ),
          Text(
            percentage,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF1F3A5F),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Full ring (the part not covered by progress shows as the track color)
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc: starts at 12 o'clock and sweeps clockwise
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
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
    final dotSize = isDesktop ? 14.0 : (isTablet ? 12.0 : (isSmallScreen ? 8.0 : 10.0));
    final spacing = isDesktop ? 14.0 : (isTablet ? 12.0 : (isSmallScreen ? 8.0 : 10.0));
    final fontSize = isDesktop ? 13.0 : (isTablet ? 12.0 : (isSmallScreen ? 10.0 : 11.0));

    return Row(
      mainAxisSize: MainAxisSize.min,
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
            style: GoogleFonts.inter(
              color: const Color(0xFF5B6B7A),
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
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