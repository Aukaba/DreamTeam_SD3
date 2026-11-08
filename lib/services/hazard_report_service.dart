import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gemini_hazard_service.dart';
import 'location_service.dart';

/// Data model representing a submitted or persisted hazard report.
class HazardReportData {
  final String? reportId;
  final String? userId;
  final String category;
  final String securityLevel;
  final String title;
  final String description;
  final String address;
  final LatLng? location;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final int confidence;
  final String status;
  final int pointsAwarded;
  final DateTime timestamp;

  const HazardReportData({
    this.reportId,
    this.userId,
    required this.category,
    required this.securityLevel,
    required this.title,
    required this.description,
    required this.address,
    this.location,
    this.imageBytes,
    this.imageUrl,
    this.confidence = 98,
    this.status = 'active',
    int? pointsAwarded,
    required this.timestamp,
  }) : pointsAwarded = pointsAwarded ??
            (securityLevel == 'High'
                ? 3
                : (securityLevel == 'Medium' ? 2 : 1));

  static double? _parseCoordinate(dynamic value) {
    if (value is num) {
      final asDouble = value.toDouble();
      return asDouble.isFinite ? asDouble : null;
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null && parsed.isFinite) {
        return parsed;
      }
    }
    return null;
  }

  /// Creates a [HazardReportData] from a `public.ReportTable` row.
  factory HazardReportData.fromReportRow(Map<String, dynamic> row) {
    final rawCategory = row['hazard_category']?.toString();
    final normalizedCategory = HazardCategories.normalize(rawCategory);
    final rawSeverity = row['severity_level']?.toString();
    final normalizedSecurity = HazardSecurityLevels.normalize(rawSeverity);

    final rawTitle = row['detected_hazard']?.toString().trim() ?? '';
    final title = rawTitle.isNotEmpty
        ? rawTitle
        : HazardReportService.cleanCategory(normalizedCategory);

    final rawAddress = row['location_address']?.toString().trim() ?? '';
    final address = rawAddress.isNotEmpty ? rawAddress : 'Current Location';

    final lat = _parseCoordinate(row['latitude']);
    final lng = _parseCoordinate(row['longitude']);
    final LatLng? parsedLocation = (lat != null &&
            lng != null &&
            lat >= -90.0 &&
            lat <= 90.0 &&
            lng >= -180.0 &&
            lng <= 180.0)
        ? LatLng(lat, lng)
        : null;

    final rawConfidence = row['confidence'];
    final int confidence = rawConfidence is num
        ? rawConfidence.round().clamp(1, 100)
        : (int.tryParse(rawConfidence?.toString() ?? '')?.clamp(1, 100) ?? 98);

    final rawCreatedAt = row['created_at']?.toString();
    final DateTime timestamp = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final rawId =
        row['reportID']?.toString() ?? row['report_id']?.toString();
    final rawUserId = row['user_id']?.toString().trim();

    final rawStatus = row['status']?.toString().trim().toLowerCase() ?? '';
    final status =
        (rawStatus == 'resolved' || rawStatus == 'archived') ? rawStatus : 'active';

    final rawPoints = row['points_awarded'];
    final int pointsAwarded = rawPoints is num
        ? rawPoints.round()
        : (int.tryParse(rawPoints?.toString() ?? '') ??
            HazardReportService.calculateSeverityPoints(normalizedSecurity));

    return HazardReportData(
      reportId: (rawId != null && rawId.trim().isNotEmpty) ? rawId.trim() : null,
      userId: (rawUserId != null && rawUserId.isNotEmpty) ? rawUserId : null,
      category: normalizedCategory,
      securityLevel: normalizedSecurity,
      title: title,
      description: row['description']?.toString().trim() ?? '',
      address: address,
      location: parsedLocation,
      imageUrl: row['image_url']?.toString(),
      confidence: confidence,
      status: status,
      pointsAwarded: pointsAwarded,
      timestamp: timestamp,
    );
  }

  HazardReportData copyWith({
    String? reportId,
    String? userId,
    String? category,
    String? securityLevel,
    String? title,
    String? description,
    String? address,
    LatLng? location,
    Uint8List? imageBytes,
    String? imageUrl,
    int? confidence,
    String? status,
    int? pointsAwarded,
    DateTime? timestamp,
  }) {
    final nextSecurity = securityLevel ?? this.securityLevel;
    return HazardReportData(
      reportId: reportId ?? this.reportId,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      securityLevel: nextSecurity,
      title: title ?? this.title,
      description: description ?? this.description,
      address: address ?? this.address,
      location: location ?? this.location,
      imageBytes: imageBytes ?? this.imageBytes,
      imageUrl: imageUrl ?? this.imageUrl,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      pointsAwarded: pointsAwarded ??
          (securityLevel != null
              ? HazardReportService.calculateSeverityPoints(nextSecurity)
              : this.pointsAwarded),
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

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

/// Service that uploads and retrieves hazard details and images in Supabase (`ReportTable` and `hazard-reports` bucket).
class HazardReportService {
  final SupabaseClient? _explicitClient;
  final Future<LatLng> Function()? _locationResolver;

  static final List<HazardReportData> _sessionReports = <HazardReportData>[];
  static final StreamController<HazardReportData> _reportStreamController =
      StreamController<HazardReportData>.broadcast();

  HazardReportService({
    SupabaseClient? client,
    Future<LatLng> Function()? locationResolver,
  })  : _explicitClient = client,
        _locationResolver = locationResolver;

  SupabaseClient get _client => _explicitClient ?? Supabase.instance.client;

  SupabaseClient? _tryGetClient() {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Broadcast stream emitting newly submitted hazard reports across screens.
  static Stream<HazardReportData> get reportStream =>
      _reportStreamController.stream;

  /// Snapshot of reports submitted during the active app session.
  static List<HazardReportData> get sessionReports =>
      List<HazardReportData>.unmodifiable(_sessionReports);

  /// Records a newly submitted report in session state and notifies listeners (e.g. [MapScreen], Home, Alerts).
  static void recordSubmittedReport(HazardReportData report) {
    final reportId = report.reportId;
    if (reportId != null && reportId.isNotEmpty) {
      _sessionReports.removeWhere((existing) => existing.reportId == reportId);
    }
    _sessionReports.insert(0, report);
    _reportStreamController.add(report);
  }

  @visibleForTesting
  static void clearSessionReports() {
    _sessionReports.clear();
  }

  /// Strips leading emoji for clean database storage, matching the `ReportTable` format.
  /// Example: "🚧 Road damage" -> "Road damage", "🌳 Fallen tree" -> "Fallen tree"
  static String cleanCategory(String category) {
    final stripped = category.replaceAll(RegExp(r'^[^\w\s]+\s*'), '').trim();
    return stripped.isNotEmpty ? stripped : category.trim();
  }

  /// Calculates points awarded for a report based on its severity level:
  /// - Low -> 1 pt
  /// - Medium -> 2 pts
  /// - High (or Critical) -> 3 pts
  static int calculateSeverityPoints(String? severityLevel) {
    final norm = (severityLevel ?? '').trim().toLowerCase();
    if (norm.contains('high') ||
        norm.contains('critical') ||
        norm.contains('severe')) {
      return 3;
    }
    if (norm.contains('med') || norm.contains('mod')) {
      return 2;
    }
    return 1;
  }

  /// Formats a human-readable relative timestamp (e.g. "Just now", "5m ago", "2h ago").
  static String formatRelativeTime(DateTime timestamp, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(timestamp);
    if (diff.isNegative || diff.inMinutes < 2) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  /// Formats distance in meters or kilometers from [origin] to [target].
  static String formatDistanceBetween(LatLng origin, LatLng target) {
    final meters = const Distance().distance(origin, target);
    if (meters < 1000) {
      return '${meters.round()}m away';
    }
    return '${(meters / 1000.0).toStringAsFixed(1)} km away';
  }

  static String _extensionForMimeType(String? mimeType) {
    switch (mimeType?.trim().toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }

  /// Uploads photo binary to Supabase Storage bucket `hazard-reports`
  /// and returns the public object URL.
  Future<String?> uploadHazardPhoto({
    required String reportId,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final ext = _extensionForMimeType(mimeType);
    final storagePath = '$reportId.$ext';
    try {
      await _client.storage.from('hazard-reports').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType ?? 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl =
          _client.storage.from('hazard-reports').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Warning: Failed to upload hazard photo to storage: $e');
      return null;
    }
  }

  /// Submits the hazard report details into `public.ReportTable` in Supabase.
  /// Note: Database trigger `on_report_table_sync_alert` automatically publishes
  /// the corresponding Hazard or Community alert into `public.alerts`.
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
    final effectiveLocation = location ??
        await (_locationResolver ?? LocationService.getCurrentLocation)();
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

    final trimmedDescription = description.trim();

    // 2. Prepare payload matching `ReportTable` columns
    final payload = <String, dynamic>{
      'reportID': reportId,
      'user_id': reportAnonymously ? null : currentUserId,
      'hazard_category': cleanCategory(category),
      'detected_hazard':
          title.trim().isNotEmpty ? title.trim() : cleanCategory(category),
      'description': trimmedDescription.isNotEmpty ? trimmedDescription : null,
      'severity_level': securityLevel,
      'confidence': confidence,
      'location_address': locationAddress.trim().isNotEmpty
          ? locationAddress.trim()
          : 'Current Location',
      'latitude': effectiveLocation.latitude,
      'longitude': effectiveLocation.longitude,
      'image_url': imageUrl,
      'status': 'active',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    // 3. Insert into Supabase `ReportTable`
    try {
      final response = await _client
          .from('ReportTable')
          .insert(payload)
          .select()
          .maybeSingle();
      final savedRow = response ?? payload;
      recordSubmittedReport(
        HazardReportData.fromReportRow(savedRow).copyWith(
          category: HazardCategories.normalize(category),
          securityLevel: HazardSecurityLevels.normalize(securityLevel),
          description: trimmedDescription,
          location: effectiveLocation,
          imageBytes: imageBytes,
          status: 'active',
        ),
      );
      return savedRow;
    } catch (e) {
      debugPrint('Error inserting into ReportTable: $e');
      rethrow;
    }
  }

  /// Loads saved hazard reports from `public.ReportTable` (with usable coordinates),
  /// merged with any reports submitted during the current app session.
  Future<List<HazardReportData>> fetchReports({
    int limit = 100,
    bool activeOnly = true,
  }) async {
    final mergedById = <String, HazardReportData>{};
    final unkeyed = <HazardReportData>[];

    void addReport(HazardReportData report) {
      if (report.location == null) return;
      if (activeOnly && report.status != 'active') return;
      final id = report.reportId;
      if (id != null && id.isNotEmpty) {
        mergedById.putIfAbsent(id, () => report);
      } else {
        unkeyed.add(report);
      }
    }

    for (final sessionReport in _sessionReports) {
      addReport(sessionReport);
    }

    final client = _tryGetClient();
    if (client != null) {
      try {
        var query = client
            .from('ReportTable')
            .select()
            .not('latitude', 'is', null)
            .not('longitude', 'is', null);
        if (activeOnly) {
          query = query.eq('status', 'active');
        }
        final rawRows = await query
            .order('created_at', ascending: false)
            .limit(limit);

        for (final dynamic item in (rawRows as List<dynamic>)) {
          if (item is Map<String, dynamic>) {
            addReport(HazardReportData.fromReportRow(item));
          }
        }
      } catch (e) {
        debugPrint('Warning: Failed to fetch reports from ReportTable: $e');
      }
    }

    final combined = <HazardReportData>[
      ...mergedById.values,
      ...unkeyed,
    ];
    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (combined.length > limit) {
      return combined.sublist(0, limit);
    }
    return combined;
  }

  /// Fetches recent active hazard reports for the Home screen.
  /// Prioritizes recent reports within [preferredRadiusMeters] of [nearLocation]
  /// when available, falling back to the latest active reports overall.
  Future<List<HazardReportData>> fetchRecentHazards({
    LatLng? nearLocation,
    int limit = 4,
    double preferredRadiusMeters = 25000,
  }) async {
    final allActive = await fetchReports(limit: 100, activeOnly: true);
    if (allActive.isEmpty) return const <HazardReportData>[];

    if (nearLocation != null) {
      const distanceCalc = Distance();
      final withinRadius = allActive
          .where((r) =>
              r.location != null &&
              distanceCalc.distance(nearLocation, r.location!) <=
                  preferredRadiusMeters)
          .toList();
      if (withinRadius.isNotEmpty) {
        return withinRadius.take(limit).toList();
      }
    }
    return allActive.take(limit).toList();
  }

  /// Fetches all hazard reports submitted by [userId] (or the current authenticated user)
  /// from `public.ReportTable`, ordered newest first.
  Future<List<HazardReportData>> fetchUserReports({
    String? userId,
    int limit = 100,
  }) async {
    final client = _tryGetClient();
    final targetUserId = userId ?? client?.auth.currentUser?.id;

    final mergedById = <String, HazardReportData>{};
    final unkeyed = <HazardReportData>[];

    void addReport(HazardReportData report) {
      final id = report.reportId;
      if (id != null && id.isNotEmpty) {
        mergedById.putIfAbsent(id, () => report);
      } else {
        unkeyed.add(report);
      }
    }

    for (final sessionReport in _sessionReports) {
      if (targetUserId == null ||
          sessionReport.userId == null ||
          sessionReport.userId == targetUserId) {
        addReport(sessionReport);
      }
    }

    if (client != null && targetUserId != null && targetUserId.isNotEmpty) {
      try {
        final rawRows = await client
            .from('ReportTable')
            .select()
            .eq('user_id', targetUserId)
            .order('created_at', ascending: false)
            .limit(limit);

        for (final dynamic item in (rawRows as List<dynamic>)) {
          if (item is Map<String, dynamic>) {
            addReport(HazardReportData.fromReportRow(item));
          }
        }
      } catch (e) {
        debugPrint('Warning: Failed to fetch user reports from ReportTable: $e');
      }
    }

    final combined = <HazardReportData>[
      ...mergedById.values,
      ...unkeyed,
    ];
    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (combined.length > limit) {
      return combined.sublist(0, limit);
    }
    return combined;
  }

  /// Deletes a user's own submitted report from `public.ReportTable` and local session cache.
  Future<void> deleteUserReport(String reportId) async {
    final trimmed = reportId.trim();
    if (trimmed.isEmpty) return;

    _sessionReports.removeWhere((r) => r.reportId == trimmed);

    final client = _tryGetClient();
    final currentUserId = client?.auth.currentUser?.id;
    if (client != null && currentUserId != null) {
      await client
          .from('ReportTable')
          .delete()
          .eq('reportID', trimmed)
          .eq('user_id', currentUserId);
    }
  }
}
