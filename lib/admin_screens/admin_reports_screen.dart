import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_profile_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Container(
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

                return SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48.0 : (isTablet ? 32.0 : 16.0),
                      vertical: isDesktop ? 32.0 : 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isSmallScreen, isTablet, isDesktop, context),
                        SizedBox(height: isDesktop ? 32 : 24),
                        _buildGreeting(isSmallScreen, isTablet, isDesktop),
                        SizedBox(height: isDesktop ? 24 : 16),
                        _buildSearchBar(isSmallScreen, isTablet, isDesktop),
                        SizedBox(height: isDesktop ? 32 : 24),
                        _buildReportCard(
                          title: 'Flooded road',
                          location: 'Maguikay Avenue, Cebu City',
                          time: '9 min ago',
                          status: 'Pending',
                          statusColor: const Color(0xFFFDF0DC),
                          statusTextColor: const Color(0xFFC17F24),
                          hasAlert: true,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
                        SizedBox(height: isDesktop ? 24 : 16),
                        _buildReportCard(
                          title: 'Road damage',
                          location: 'R. Duterte Street, Cebu City',
                          time: '8 min ago',
                          status: 'Pending',
                          statusColor: const Color(0xFFFDF0DC),
                          statusTextColor: const Color(0xFFC17F24),
                          hasAlert: true,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
                        SizedBox(height: isDesktop ? 24 : 16),
                        _buildReportCard(
                          title: 'Minor accident',
                          location: 'N. Bacalso Avenue, Cebu City',
                          time: '12 min ago',
                          status: 'Verified',
                          statusColor: const Color(0xFFD4F5E5),
                          statusTextColor: const Color(0xFF1A7A45),
                          hasAlert: false,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen, bool isTablet, bool isDesktop, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              customBorder: const CircleBorder(),
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
            SizedBox(width: isDesktop ? 20 : 14),
            Image.asset(
              'assets/image/LogoSR.png',
              width: 43,
              height: 47,
            ),
            SizedBox(width: isDesktop ? 20 : 14),
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
        ),
        Row(
          children: [
            Container(
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
                Icons.notifications_outlined,
                size: 20,
                color: Color(0xFF5B6B7A),
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 12),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FB),
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 1,
                    color: const Color(0xFFD0E8F5),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Color(0xFF5B6B7A),
                ),
              ),
            ),
          ],
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
            color: const Color(0xFF7B9BAD),
            fontSize: isDesktop ? 15 : 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 4),
        Text(
          'Stay safe out there.',
          style: GoogleFonts.inter(
            color: const Color(0xFF1A2B4A),
            fontSize: isDesktop ? 30 : 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isSmallScreen, bool isTablet, bool isDesktop) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F7),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          width: 1,
          color: const Color(0xFFE2E8ED),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search Reports...',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFFA8BFCA),
            fontSize: isDesktop ? 15 : 13,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: Color(0xFFA8BFCA),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.inter(
          color: const Color(0xFF1A2B4A),
          fontSize: isDesktop ? 15 : 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String location,
    required String time,
    required String status,
    required Color statusColor,
    required Color statusTextColor,
    required bool hasAlert,
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final imageSize = isDesktop ? 96.0 : 72.0;
    final spacing = isDesktop ? 24.0 : 16.0;
    final padding = isDesktop ? 24.0 : 16.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: 1,
          color: const Color(0xFFE8EDF2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: imageSize,
            height: imageSize,
            child: Stack(
              children: [
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFE8F4FB),
                  ),
                  child: const Icon(
                    Icons.report_problem,
                    size: 32,
                    color: Color(0xFF1F3A5F),
                  ),
                ),
                if (hasAlert)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          '!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        borderRadius: BorderRadius.circular(10),
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
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1A2B4A),
                          fontSize: isDesktop ? 17 : 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 12 : 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: statusTextColor,
                          fontSize: isDesktop ? 11 : 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 8 : 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: Color(0xFF7B9BAD),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF7B9BAD),
                          fontSize: isDesktop ? 11 : 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 8 : 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: Color(0xFF7B9BAD),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7B9BAD),
                        fontSize: isDesktop ? 11 : 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: Color(0xFF1F3A5F),
          ),
        ],
      ),
    );
  }
}
