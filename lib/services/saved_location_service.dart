import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a location saved by the user in the database.
class SavedLocation {
  final String id;
  final String userId;
  final String title;
  final String address;
  final LatLng location;
  final String category; // 'home', 'work', 'school', 'shopping', 'custom'
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedLocation({
    required this.id,
    required this.userId,
    required this.title,
    required this.address,
    required this.location,
    this.category = 'custom',
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Saved Place',
      address: json['address']?.toString() ?? '',
      location: LatLng(
        (json['latitude'] as num?)?.toDouble() ?? 0.0,
        (json['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      category: json['category']?.toString() ?? 'custom',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'title': title,
      'address': address,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'category': category,
    };
  }

  IconData get icon {
    switch (category.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
      case 'office':
        return Icons.work_rounded;
      case 'school':
      case 'university':
        return Icons.school_rounded;
      case 'shopping':
      case 'mall':
        return Icons.shopping_bag_rounded;
      case 'food':
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'hospital':
      case 'health':
        return Icons.local_hospital_rounded;
      default:
        return Icons.bookmark_rounded;
    }
  }

  Color get color {
    switch (category.toLowerCase()) {
      case 'home':
        return const Color(0xFF10B981);
      case 'work':
      case 'office':
        return const Color(0xFF3B82F6);
      case 'school':
      case 'university':
        return const Color(0xFF8B5CF6);
      case 'shopping':
        return const Color(0xFFF59E0B);
      case 'hospital':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF263354);
    }
  }
}

/// Service to perform CRUD operations on the `saved_locations` Supabase table.
class SavedLocationService {
  final SupabaseClient? _client;

  SavedLocationService({SupabaseClient? client}) : _client = client;

  SupabaseClient get client => _client ?? Supabase.instance.client;

  User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Fetch all saved locations for the currently signed-in user.
  Future<List<SavedLocation>> getSavedLocations() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await client
        .from('saved_locations')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((json) => SavedLocation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Save a new location for the currently signed-in user.
  Future<SavedLocation> saveLocation({
    required String title,
    required String address,
    required LatLng location,
    String category = 'custom',
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('You must be signed in to save locations.');
    }

    final data = {
      'user_id': user.id,
      'title': title.trim(),
      'address': address.trim(),
      'latitude': location.latitude,
      'longitude': location.longitude,
      'category': category.trim().toLowerCase(),
    };

    final response = await client
        .from('saved_locations')
        .insert(data)
        .select()
        .single();

    return SavedLocation.fromJson(response);
  }

  /// Delete a saved location by its primary key ID.
  Future<void> deleteSavedLocation(String id) async {
    final user = currentUser;
    if (user == null) return;

    await client
        .from('saved_locations')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  /// Check whether a location with this title and nearby coordinates is already saved.
  Future<bool> isLocationSaved(String title, LatLng location) async {
    final user = currentUser;
    if (user == null) return false;

    final response = await client
        .from('saved_locations')
        .select('id, latitude, longitude')
        .eq('user_id', user.id)
        .ilike('title', title.trim())
        .limit(1);

    final list = response as List<dynamic>;
    if (list.isEmpty) return false;

    final lat = (list.first['latitude'] as num).toDouble();
    final lon = (list.first['longitude'] as num).toDouble();
    const distance = Distance();
    return distance.distance(location, LatLng(lat, lon)) < 50;
  }
}
