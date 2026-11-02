import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  // Default coordinates fallback if location services are unavailable or denied
  static const LatLng defaultLocation = LatLng(10.3157, 123.8920);

  /// Retrieves the device's current location, requesting permissions if necessary.
  static Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled; using fallback location.');
        return defaultLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied; using fallback location.');
          return defaultLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever; using fallback location.');
        return defaultLocation;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error obtaining location: $e; using fallback location.');
      return defaultLocation;
    }
  }

  /// Attempts to quickly retrieve the last known position from the system cache.
  static Future<LatLng?> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        return LatLng(position.latitude, position.longitude);
      }
    } catch (_) {}
    return null;
  }
}
