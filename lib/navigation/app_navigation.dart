import 'package:flutter/material.dart';
import '../user_screens/user_home_screen.dart';
import '../user_screens/route_screen.dart';
import '../user_screens/alerts_screen.dart';
import '../user_screens/user_profile_screen.dart';

/// Centralized navigation helper for top-level screen destinations.
/// Decouples UI widgets like [SafeRouteBottomNav] from specific screen implementations
/// and prevents circular import dependencies across screens.
class AppNavigation {
  /// Navigates to the root screen corresponding to [targetIndex].
  ///
  /// If [currentIndex] matches [targetIndex], navigation is skipped.
  /// If [clearStack] is true, removes all routes from the navigation stack so the
  /// target screen becomes the clean root (e.g. when leaving sub-screens like Leaderboard).
  static void navigateTo(
    BuildContext context,
    int targetIndex, {
    int? currentIndex,
    bool clearStack = false,
  }) {
    if (currentIndex != null && targetIndex == currentIndex) return;

    Widget destination;
    switch (targetIndex) {
      case 0:
        destination = const UserHomeScreen();
        break;
      case 1:
        destination = const RouteScreen();
        break;
      case 2:
        destination = const AlertsScreen();
        break;
      case 3:
        destination = const UserProfileScreen();
        break;
      default:
        return;
    }

    final route = PageRouteBuilder(
      pageBuilder: (context, anim1, anim2) => destination,
      transitionDuration: Duration.zero,
    );

    if (clearStack) {
      Navigator.pushAndRemoveUntil(context, route, (r) => false);
    } else {
      Navigator.pushReplacement(context, route);
    }
  }
}

