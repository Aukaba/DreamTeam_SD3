import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(color: Color(0xFFF7F0EA)),
          child: Column(
            children: [
              // Top header with gradient circle
              Stack(
                children: [
                  Container(
                    height: screenHeight * 0.25,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0.50, -0.00),
                        end: Alignment(0.50, 1.00),
                        colors: [Color(0xFFD9D9D9), Color(0xFFA3A9B9), Color(0xFF3D4F7D)],
                      ),
                    ),
                  ),
                  // Logo/brand image placeholder
                  Positioned(
                    top: screenHeight * 0.025,
                    left: screenWidth * 0.08,
                    right: screenWidth * 0.08,
                    child: Container(
                      height: screenHeight * 0.18,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'SafeRoute Logo',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Hero image section
              Container(
                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.35,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D4F7D),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.28,
                      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x3F000000),
                            blurRadius: 7,
                            offset: const Offset(0, 4),
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Hero Image',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Feature badges
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.02, left: screenWidth * 0.05),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFFF7F0EA), size: 15),
                    const SizedBox(width: 5),
                    Text(
                      'Safer routes',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFF7F0EA),
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.15),
                    const Icon(Icons.notifications, color: Color(0xFFF7F0EA), size: 15),
                    const SizedBox(width: 5),
                    Text(
                      'Helpful alerts',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFF7F0EA),
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.005, left: screenWidth * 0.05),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Avoid active hazards on your way.',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFF7F0EA),
                          fontSize: isSmallScreen ? 7 : 8,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.1),
                    Expanded(
                      child: Text(
                        'Know what is happening nearby.',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFF7F0EA),
                          fontSize: isSmallScreen ? 7 : 8,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Main headline
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.05, left: screenWidth * 0.05, right: screenWidth * 0.05),
                child: Text(
                  'MOVE THROUGH YOUR CITY\nWITH CONFIDENCE.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF3D4F7D),
                    fontSize: isSmallScreen ? 16 : 20,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 4),
                        blurRadius: 5,
                        color: Color(0x40000000),
                      )
                    ],
                  ),
                ),
              ),
              // Description
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.02, left: screenWidth * 0.05, right: screenWidth * 0.05),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'SafeRoute',
                        style: GoogleFonts.inriaSans(
                          color: const Color(0xFF3D4F7D),
                          fontSize: isSmallScreen ? 10 : 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' helps you find calmer paths, stay informed about hazards, and look out for the people around you.',
                        style: GoogleFonts.inriaSans(
                          color: const Color(0xFF3D4F7D),
                          fontSize: isSmallScreen ? 10 : 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Get Started button
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.025, left: screenWidth * 0.08, right: screenWidth * 0.08),
                child: Container(
                  width: double.infinity,
                  height: screenHeight * 0.05,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(-1.0, 0.0),
                      end: Alignment(1.0, 0.0),
                      colors: [Colors.white, Color(0xFF112250)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x3F000000),
                        blurRadius: 7,
                        offset: const Offset(0, 4),
                        spreadRadius: 3,
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'GET STARTED',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontSize: isSmallScreen ? 10 : 12,
                        fontWeight: FontWeight.w400,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 4),
                            blurRadius: 4,
                            color: Color(0x40000000),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.012),
                child: Text(
                  'free for every community.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF3D4F7D),
                    fontSize: isSmallScreen ? 8 : 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // Dark section - How SafeRoute helps
              Container(
                margin: EdgeInsets.only(top: screenHeight * 0.05),
                padding: EdgeInsets.all(screenWidth * 0.045),
                decoration: const BoxDecoration(
                  color: Color(0xFF3D4F7D),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW SAFEROUTE HELPS',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 8 : 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.012),
                    Text(
                      'Small updates can prevent big surprises.',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 16 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.018),
                    Text(
                      'We bring neighbors, local awareness, and simple tools together so you can make confident choices before you step out.',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 9 : 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.035),
                    // Feature cards
                    _buildFeatureCard(
                      icon: Icons.visibility,
                      title: 'See hazards sooner',
                      description: 'Get a calm, clear view of what is happening around you.',
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: screenHeight * 0.012),
                    _buildFeatureCard(
                      icon: Icons.people,
                      title: 'Look out for each other',
                      description: 'Share useful reports that help your community stay prepared.',
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: screenHeight * 0.012),
                    _buildFeatureCard(
                      icon: Icons.route,
                      title: 'Choose a better way',
                      description: 'Plan around trouble spots and keep your journey moving.',
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: screenHeight * 0.035),
                    // CTA section
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.12,
                      decoration: BoxDecoration(
                        color: const Color(0x263D4F7D),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Your awareness makes a difference.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 11 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            'Start with one safer trip today.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 7 : 9,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isSmallScreen,
  }) {
    return Container(
      width: double.infinity,
      height: isSmallScreen ? 50 : 60,
      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0x263D4F7D),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 30 : 35,
            height: isSmallScreen ? 28 : 33,
            decoration: BoxDecoration(
              color: const Color(0x33D9D9D9),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, color: Colors.white, size: isSmallScreen ? 18 : 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 8 : 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 1 : 2),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 6 : 7,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
