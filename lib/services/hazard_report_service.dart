import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper to generate a standard RFC 4122 version 4 UUID string.
String generateUuidV4() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40; // Version 4
  values[8] = (values[8] & 0x3f) | 0x80; // Variant 10
  return [
    values.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    values.sublist(4, 6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    values.sublist(6, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    values.sublist(8, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    values.sublist(10, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
  ].join('-');
}

/// Service that uploads hazard details and images to Supabase (`ReportTable` and `hazard-reports` bucket).
class HazardReportService {
  final SupabaseClient? _explicitClient;

  HazardReportService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient get _client => _explicitClient ?? Supabase.instance.client;

  /// Strips leading emoji for clean database storage, matching the `ReportTable` format.
  /// Example: "🚧 Road damage" -> "Road damage", "🌳 Fallen tree" -> "Fallen tree"
  static String cleanCategory(String category) {
    final stripped = category.replaceAll(RegExp(r'^[^\w\s]+\s*'), '').trim();
    return stripped.isNotEmpty ? stripped : category.trim();
  }

  /// Uploads photo binary to Supabase Storage bucket `hazard-reports`
  /// and returns the public object URL.
  Future<String?> uploadHazardPhoto({
    required String reportId,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final storagePath = '$reportId.jpg';
    try {
      await _client.storage.from('hazard-reports').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType ?? 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl = _client.storage.from('hazard-reports').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Warning: Failed to upload hazard photo to storage: $e');
      return null;
    }
  }

  /// Submits the hazard report details into `public.ReportTable` in Supabase.
  Future<Map<String, dynamic>> submitReport({
    required String category,
    required String securityLevel,
    required String title,
    required String description,
    required String locationAddress,
    LatLng? location,
    Uint8List? imageBytes,
    int confidence = 98,
    String? mimeType,
  }) async {
    final reportId = generateUuidV4();
    final currentUserId = _client.auth.currentUser?.id;
    bool reportAnonymously = false;
    if (currentUserId != null) {
      try {
        final securityRow = await _client
            .from('user_security_settings')
            .select('anonymous_reporting')
            .eq('user_id', currentUserId)
            .maybeSingle();
        reportAnonymously =
            securityRow?['anonymous_reporting'] as bool? ?? false;
      } catch (_) {
        reportAnonymously = false;
      }
    }

    // 1. Upload photo to Supabase Storage if present
    String? imageUrl;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      imageUrl = await uploadHazardPhoto(
        reportId: reportId,
        bytes: imageBytes,
        mimeType: mimeType,
      );
    }

    // 2. Prepare payload matching `ReportTable` columns
    final payload = <String, dynamic>{
      'reportID': reportId,
      'user_id': reportAnonymously ? null : currentUserId,
      'hazard_category': cleanCategory(category),
      'detected_hazard': title.trim().isNotEmpty ? title.trim() : cleanCategory(category),
      'severity_level': securityLevel,
      'confidence': confidence,
      'location_address': locationAddress.trim().isNotEmpty ? locationAddress.trim() : 'Current Location',
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'image_url': imageUrl,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    // 3. Insert into Supabase `ReportTable`
    try {
      final response = await _client.from('ReportTable').insert(payload).select().maybeSingle();
      return response ?? payload;
    } catch (e) {
      debugPrint('Error inserting into ReportTable: $e');
      rethrow;
    }
  }
}
