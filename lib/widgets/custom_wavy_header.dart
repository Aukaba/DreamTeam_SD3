import 'package:flutter/material.dart';

/// Reusable wavy blue header with the SafeRoute logo and icon.
class CustomWavyHeader extends StatelessWidget {
  const CustomWavyHeader({super.key});

  /// Height of the wavy header based on the 796x262 asset aspect ratio.
  static double height(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width * (262 / 796);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Wavy Blue Background with transparent area below the wave curve
          Image.asset(
            'assets/image/saferoute_header.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),

          // SafeRoute Logo positioned over top-left of the blue wave
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 10.0),
              child: Image.asset(
                'assets/image/saferoute_logo_and_icon.png',
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

