import 'package:flutter/material.dart';

const Color _primaryNavy = Color(0xFF233253);
const Color _secondaryGrey = Color(0xFF8A94A6);

/// Shared bottom navigation bar for SafeRoute.
/// Takes [currentIndex] and an optional [onTap] callback.
class SafeRouteBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const SafeRouteBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: _primaryNavy,
          unselectedItemColor: _secondaryGrey,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.home_rounded, size: 24),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: RouteNavIcon(
                  color: currentIndex == 1 ? _primaryNavy : _secondaryGrey,
                ),
              ),
              label: 'Route',
            ),
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.notifications_none_rounded, size: 24),
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.person_outline_rounded, size: 24),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// S-Curve Route Path bottom nav icon matching Figma design.
class RouteNavIcon extends StatelessWidget {
  final Color color;
  final double size;

  const RouteNavIcon({
    super.key,
    required this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RouteNavPainter(color: color),
      ),
    );
  }
}

class _RouteNavPainter extends CustomPainter {
  final Color color;

  _RouteNavPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Start circle at top left
    canvas.drawCircle(
      Offset(size.width * 0.28, size.height * 0.24),
      2.2,
      dotPaint,
    );

    final path = Path()
      ..moveTo(size.width * 0.38, size.height * 0.24)
      ..lineTo(size.width * 0.65, size.height * 0.24)
      ..arcToPoint(
        Offset(size.width * 0.65, size.height * 0.52),
        radius: Radius.circular(size.width * 0.14),
        clockwise: true,
      )
      ..lineTo(size.width * 0.35, size.height * 0.52)
      ..arcToPoint(
        Offset(size.width * 0.35, size.height * 0.80),
        radius: Radius.circular(size.width * 0.14),
        clockwise: false,
      )
      ..lineTo(size.width * 0.62, size.height * 0.80);

    canvas.drawPath(path, strokePaint);
    // End circle at bottom right
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.80),
      2.2,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteNavPainter oldDelegate) =>
      oldDelegate.color != color;
}

