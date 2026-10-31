import 'package:flutter/material.dart';

/// Reusable wavy blue header with the SafeRoute logo and icon.
class CustomWavyHeader extends StatelessWidget {
  const CustomWavyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Wavy Blue Background
        Image.asset(
          'assets/image/saferoute_heather.png',
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
    );
  }
}

