import 'package:flutter/material.dart';

/// Reusable wavy blue header with the SafeRoute logo and icon.
class CustomWavyHeader extends StatelessWidget {
  const CustomWavyHeader({super.key});

  /// Height of the wavy header including device top notch/status bar
  /// plus the 796x262 asset aspect ratio wave height.
  static double height(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    return topPadding + (width * (262 / 796));
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    final waveHeight = width * (262 / 796);

    return SizedBox(
      height: topPadding + waveHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Status bar background gradient blending seamlessly into the wave asset
          if (topPadding > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topPadding + 1.5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF15437F),
                      Color(0xFF416B9B),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Wavy Blue Background with transparent area below the wave curve
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            height: waveHeight,
            child: Image.asset(
              'assets/image/saferoute_header.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),

          // 3. SafeRoute Logo positioned over top-left of the blue wave
          Positioned(
            top: topPadding + 10.0,
            left: 20.0,
            child: Image.asset(
              'assets/image/saferoute_logo_and_icon.png',
              height: 38,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

