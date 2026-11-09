import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gemini_hazard_service.dart';
import 'location_service.dart';

/// Canonical lifecycle statuses for a community hazard report:
/// - [pending]: Newly reported; awaits admin verification and is not shown on the map.
/// - [active]: Verified by an admin and actively displayed on the live map.
/// - [resolved]: Hazard is no longer present and is hidden from the live map.
class HazardReportStatuses {
  static const String pending = 'pending';
  static const String active = 'active';
  static const String resolved = 'resolved';
  static const String archived = 'archived';
  static const String rejected = 'rejected';

  static String normalize(
    String? raw, {
    String defaultStatus = active,
  }) {
    switch (raw?.trim().toLowerCase()) {
      case pending:
      case 'pending_verification':
      case 'needs_verification':
        return pending;
      case active:
      case 'verified':
        return active;
      case resolved:
      case 'cleared':
        return resolved;
      case archived:
        return archived;
      case rejected:
        return rejected;
      default:
        return defaultStatus;
    }
  }

  static String labelFor(String? status) {
    switch (normalize(status)) {
      case pending:
        return 'Pending - Needs Verification';
      case resolved:
        return 'Resolved';
      case archived:
        return 'Archived';
      case rejected:
        return 'Rejected';
      case active:
      default:
        return 'Active';
    }
  }

  static String descriptionFor(String? status) {
    switch (normalize(status)) {
      case pending:
        return 'Needs admin verification before appearing on the map';
      case resolved:
        return 'Hazard is no longer present and is not shown on the map';
      case archived:
        return 'Archived report';
      case rejected:
        return 'Report was not approved during verification';
      case active:
      default:
        return 'Verified and currently shown on the live map';
    }
  }

  /// Returns true only when [status] is accepted (`active` or `resolved`),
  /// so unaccepted (`pending`, `rejected`, `archived`) reports do not reflect
  /// on the user's reports or point counts until verified.
  static bool isAcceptedForUserReports(String? status) {
    final norm = normalize(status, defaultStatus: pending);
    return norm == active || norm == resolved;
  }
}

/// Data model representing a user-submitted camera proof that a hazard is resolved,
/// stored in `public.hazard_resolution_reports` for admin verification.
class HazardResolutionReportData {
  final String id;
  final String reportId;
  final String? reportedBy;
  final String hazardCategory;
  final String detectedHazard;
  final String hazardDescription;
  final String severityLevel;
  final String locationAddress;
  final LatLng? location;
  final String? originalImageUrl;
  final String resolutionImageUrl;
  final Uint8List? resolutionImageBytes;
  final String? resolutionNote;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  const HazardResolutionReportData({
    required this.id,
    required this.reportId,
    this.reportedBy,
    required this.hazardCategory,
    required this.detectedHazard,
    this.hazardDescription = '',
    required this.severityLevel,
    required this.locationAddress,
    this.location,
    this.originalImageUrl,
    required this.resolutionImageUrl,
    this.resolutionImageBytes,
    this.resolutionNote,
    this.status = 'pending',
    required this.createdAt,
  });

  factory HazardResolutionReportData.fromRow(Map<String, dynamic> row) {
    final lat = HazardReportData._parseCoordinate(row['latitude']);
    final lng = HazardReportData._parseCoordinate(row['longitude']);
    final LatLng? parsedLocation = (lat != null &&
            lng != null &&
            lat >= -90.0 &&
            lat <= 90.0 &&
            lng >= -180.0 &&
            lng <= 180.0)
        ? LatLng(lat, lng)
        : null;

    final rawCreatedAt = row['created_at']?.toString();
    final DateTime createdAt = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final rawStatus = row['status']?.toString().trim().toLowerCase() ?? '';
    final normalizedStatus =
        (rawStatus == 'approved' || rawStatus == 'rejected')
            ? rawStatus
            : 'pending';

    return HazardResolutionReportData(
      id: row['id']?.toString() ?? generateUuidV4(),
      reportId: row['report_id']?.toString() ?? '',
      reportedBy: row['reported_by']?.toString(),
      hazardCategory: HazardCategories.normalize(
        row['hazard_category']?.toString(),
      ),
      detectedHazard: row['detected_hazard']?.toString().trim() ?? 'Hazard',
      hazardDescription: row['hazard_description']?.toString().trim() ?? '',
      severityLevel: HazardSecurityLevels.normalize(
        row['severity_level']?.toString(),
      ),
      locationAddress:
          row['location_address']?.toString().trim() ?? 'Current Location',
      location: parsedLocation,
      originalImageUrl: row['original_image_url']?.toString(),
      resolutionImageUrl: row['resolution_image_url']?.toString() ?? '',
      resolutionNote: row['resolution_note']?.toString(),
      status: normalizedStatus,
      createdAt: createdAt,
    );
  }
}

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
  final String? resolutionStatus;
  final String? resolutionImageUrl;
  final int resolutionCount;
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
    this.resolutionStatus,
    this.resolutionImageUrl,
    this.resolutionCount = 0,
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
    final status = HazardReportStatuses.normalize(
      rawStatus,
      defaultStatus: HazardReportStatuses.active,
    );

    final rawResolutionStatus =
        row['resolution_status']?.toString().trim().toLowerCase();
    final String? resolutionStatus = (rawResolutionStatus != null &&
            rawResolutionStatus.isNotEmpty)
        ? rawResolutionStatus
        : null;
    final String? resolutionImageUrl =
        row['resolution_image_url']?.toString().trim().isNotEmpty == true
            ? row['resolution_image_url'].toString().trim()
            : null;

    final rawPoints = row['points_awarded'];
    final int pointsAwarded = rawPoints is num
        ? rawPoints.round()
        : (int.tryParse(rawPoints?.toString() ?? '') ??
            HazardReportService.calculateSeverityPoints(normalizedSecurity));

    final rawResCount = row['resolution_count'];
    final int resolutionCount = rawResCount is num
        ? rawResCount.toInt()
        : (int.tryParse(rawResCount?.toString() ?? '') ?? 0);

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
      resolutionStatus: resolutionStatus,
      resolutionImageUrl: resolutionImageUrl,
      resolutionCount: resolutionCount,
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
    String? resolutionStatus,
    String? resolutionImageUrl,
    int? resolutionCount,
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
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      resolutionImageUrl: resolutionImageUrl ?? this.resolutionImageUrl,
      resolutionCount: resolutionCount ?? this.resolutionCount,
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
  static final Map<String, HazardResolutionReportData>
      _sessionResolutionReports = <String, HazardResolutionReportData>{};
  static final StreamController<HazardReportData> _reportStreamController =
      StreamController<HazardReportData>.broadcast();
  static final StreamController<HazardResolutionReportData>
      _resolutionStreamController =
      StreamController<HazardResolutionReportData>.broadcast();
  static final StreamController<void> _remoteReportChangesController =
      StreamController<void>.broadcast();

  static Stream<void> get remoteReportChangesStream =>
      _remoteReportChangesController.stream;

  static void notifyRemoteReportChange() {
    if (!_remoteReportChangesController.isClosed) {
      _remoteReportChangesController.add(null);
    }
  }

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

  /// Broadcast stream emitting newly submitted hazard resolution reports.
  static Stream<HazardResolutionReportData> get resolutionStream =>
      _resolutionStreamController.stream;

  /// Subscribes to real-time changes on `ReportTable` in Supabase,
  /// calling [onReportChanged] whenever a report status or record is updated remotely.
  RealtimeChannel? subscribeToRemoteReportChanges({
    required void Function() onReportChanged,
  }) {
    final client = _tryGetClient();
    if (client == null) return null;
    try {
      final channelName = 'public:ReportTable:${generateUuidV4()}';
      final channel = client.channel(channelName);
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ReportTable',
            callback: (_) {
              onReportChanged();
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      debugPrint('Warning: Failed to subscribe to ReportTable realtime: $e');
      return null;
    }
  }

  /// Removes and unsubscribes a RealtimeChannel.
  void unsubscribeFromRemoteReportChanges(RealtimeChannel? channel) {
    if (channel == null) return;
    final client = _tryGetClient();
    if (client == null) return;
    try {
      client.removeChannel(channel);
    } catch (_) {}
  }

  /// Snapshot of reports submitted during the active app session.
  static List<HazardReportData> get sessionReports =>
      List<HazardReportData>.unmodifiable(_sessionReports);

  /// Snapshot of resolution reports submitted during the active app session, keyed by `reportId`.
  static Map<String, HazardResolutionReportData> get sessionResolutionReports =>
      Map<String, HazardResolutionReportData>.unmodifiable(
        _sessionResolutionReports,
      );

  /// Returns the current signed-in user ID or null.
  String? get currentUserId => _tryGetClient()?.auth.currentUser?.id;

  /// Returns true if this user has already submitted a resolution report for [reportId] that is still pending.
  static bool hasUserSubmittedResolution(String? reportId, [String? userId]) {
    if (reportId == null || reportId.trim().isEmpty) return false;
    final key = reportId.trim();
    final sessionRes = _sessionResolutionReports[key];
    if (sessionRes != null && sessionRes.status == 'pending') {
      if (userId != null &&
          sessionRes.reportedBy != null &&
          sessionRes.reportedBy == userId) {
        return true;
      }
      if (userId == null && sessionRes.reportedBy == null) {
        return true;
      }
    }
    for (final r in _sessionReports) {
      if (r.reportId == key && r.resolutionStatus == 'pending') {
        if (userId != null && r.userId != null && r.userId == userId) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns true if a resolution report is currently pending admin verification for [reportId].
  static bool hasPendingResolution(String? reportId) {
    if (reportId == null || reportId.trim().isEmpty) return false;
    final key = reportId.trim();
    final sessionRes = _sessionResolutionReports[key];
    if (sessionRes != null && sessionRes.status == 'pending') return true;
    for (final r in _sessionReports) {
      if (r.reportId == key && r.resolutionStatus == 'pending') {
        return true;
      }
    }
    return false;
  }

  /// Records a newly submitted report in session state and notifies listeners (e.g. [MapScreen], Home, Alerts).
  static void recordSubmittedReport(HazardReportData report) {
    final reportId = report.reportId;
    if (reportId != null && reportId.isNotEmpty) {
      _sessionReports.removeWhere((existing) => existing.reportId == reportId);
    }
    _sessionReports.insert(0, report);
    _reportStreamController.add(report);
  }

  /// Records a newly submitted hazard resolution report in session state and notifies listeners.
  static void recordSubmittedResolutionReport(
    HazardResolutionReportData resolution,
  ) {
    final reportId = resolution.reportId.trim();
    if (reportId.isNotEmpty) {
      _sessionResolutionReports[reportId] = resolution;
      for (int i = 0; i < _sessionReports.length; i++) {
        if (_sessionReports[i].reportId == reportId) {
          final isApproved = resolution.status == 'approved';
          _sessionReports[i] = _sessionReports[i].copyWith(
            resolutionStatus: resolution.status,
            resolutionImageUrl: resolution.resolutionImageUrl,
            status: isApproved ? 'resolved' : null,
          );
        }
      }
    }
    _resolutionStreamController.add(resolution);
    if (resolution.status == 'approved') {
      _remoteReportChangesController.add(null);
    }
  }

  @visibleForTesting
  static void clearSessionReports() {
    _sessionReports.clear();
    _sessionResolutionReports.clear();
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
      'status': HazardReportStatuses.pending,
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
      final persistedStatus = HazardReportStatuses.normalize(
        savedRow['status']?.toString(),
        defaultStatus: HazardReportStatuses.pending,
      );
      recordSubmittedReport(
        HazardReportData.fromReportRow(savedRow).copyWith(
          category: HazardCategories.normalize(category),
          securityLevel: HazardSecurityLevels.normalize(securityLevel),
          description: trimmedDescription,
          location: effectiveLocation,
          imageBytes: imageBytes,
          status: persistedStatus,
        ),
      );
      return savedRow;
    } catch (e) {
      debugPrint('Error inserting into ReportTable: $e');
      rethrow;
    }
  }

  /// Submits a user camera resolution report for an existing hazard into
  /// `public.hazard_resolution_reports` (and uploads the proof image to `hazard-reports`)
  /// so an admin can verify that the hazard is resolved.
  Future<HazardResolutionReportData> submitHazardResolutionReport({
    required String reportId,
    required String category,
    required String title,
    required String description,
    required String securityLevel,
    required String locationAddress,
    LatLng? location,
    String? originalImageUrl,
    required Uint8List resolutionImageBytes,
    String? mimeType,
    String? resolutionNote,
  }) async {
    final trimmedReportId = reportId.trim();
    if (trimmedReportId.isEmpty) {
      throw ArgumentError('reportId must not be empty');
    }

    if (resolutionImageBytes.isEmpty) {
      throw ArgumentError('resolutionImageBytes must not be empty');
    }

    final resolutionId = generateUuidV4();
    final client = _tryGetClient();
    final currentUserId = client?.auth.currentUser?.id;
    bool reportAnonymously = false;
    if (client != null && currentUserId != null) {
      try {
        final securityRow = await client
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

    final effectiveUserId = reportAnonymously ? null : currentUserId;

    // Idempotency check: if user already submitted a pending resolution for this hazard (Comment 9)
    if (client != null) {
      try {
        var query = client
            .from('hazard_resolution_reports')
            .select()
            .eq('report_id', trimmedReportId)
            .eq('status', 'pending');
        if (effectiveUserId != null) {
          query = query.eq('reported_by', effectiveUserId);
        } else {
          query = query.filter('reported_by', 'is', 'null');
        }
        final existingPending = await query.maybeSingle();
        if (existingPending != null) {
          final record = HazardResolutionReportData.fromRow(existingPending);
          final existingEnriched = HazardResolutionReportData(
            id: record.id,
            reportId: trimmedReportId,
            reportedBy: record.reportedBy,
            hazardCategory: HazardCategories.normalize(category),
            detectedHazard: title.trim().isNotEmpty
                ? title.trim()
                : cleanCategory(category),
            hazardDescription: description.trim(),
            severityLevel: HazardSecurityLevels.normalize(securityLevel),
            locationAddress: locationAddress.trim().isNotEmpty
                ? locationAddress.trim()
                : 'Current Location',
            location: location ?? record.location,
            originalImageUrl: originalImageUrl ?? record.originalImageUrl,
            resolutionImageUrl: record.resolutionImageUrl,
            resolutionImageBytes: resolutionImageBytes,
            resolutionNote: record.resolutionNote,
            status: record.status,
            createdAt: record.createdAt,
          );
          recordSubmittedResolutionReport(existingEnriched);
          return existingEnriched;
        }
      } catch (e) {
        debugPrint(
            'Warning: Could not check for existing pending resolution: $e');
      }
    }

    // 1. Upload resolution proof photo to Supabase Storage bucket `hazard-reports`
    String? resolutionImageUrl;
    if (client != null) {
      resolutionImageUrl = await uploadHazardPhoto(
        reportId: 'resolutions/${trimmedReportId}_$resolutionId',
        bytes: resolutionImageBytes,
        mimeType: mimeType,
      );
    }

    // Fail the submission without inserting if proof photo upload fails (Comment 3)
    if (resolutionImageUrl == null || resolutionImageUrl.trim().isEmpty) {
      throw StateError(
        'Failed to upload resolution proof photo to storage. A valid proof image is required before submitting.',
      );
    }
    final effectiveResolutionUrl = resolutionImageUrl.trim();

    final nowUtcIso = DateTime.now().toUtc().toIso8601String();
    final cleanedCategory = cleanCategory(category);
    final normalizedSeverity = HazardSecurityLevels.normalize(securityLevel);
    final trimmedTitle =
        title.trim().isNotEmpty ? title.trim() : cleanedCategory;
    final trimmedDesc = description.trim();
    final trimmedAddr = locationAddress.trim().isNotEmpty
        ? locationAddress.trim()
        : 'Current Location';
    final trimmedNote = resolutionNote?.trim();

    final payload = <String, dynamic>{
      'id': resolutionId,
      'report_id': trimmedReportId,
      'reported_by': effectiveUserId,
      'hazard_category': cleanedCategory,
      'detected_hazard': trimmedTitle,
      'hazard_description': trimmedDesc.isNotEmpty ? trimmedDesc : null,
      'severity_level': normalizedSeverity,
      'location_address': trimmedAddr,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'original_image_url': originalImageUrl,
      'resolution_image_url': effectiveResolutionUrl,
      'resolution_note':
          (trimmedNote != null && trimmedNote.isNotEmpty) ? trimmedNote : null,
      'status': 'pending',
      'created_at': nowUtcIso,
      'updated_at': nowUtcIso,
    };

    Map<String, dynamic> savedRow = payload;
    if (client != null) {
      try {
        final response = await client
            .from('hazard_resolution_reports')
            .insert(payload)
            .select()
            .maybeSingle();
        if (response != null) {
          savedRow = response;
        }
        // Check if multiple resolution reports triggered auto-resolution on ReportTable
        try {
          final parentCheck = await client
              .from('ReportTable')
              .select('status, resolution_status')
              .eq('reportID', trimmedReportId)
              .maybeSingle();
          if (parentCheck != null && parentCheck['status'] == 'resolved') {
            savedRow = Map<String, dynamic>.from(savedRow);
            savedRow['status'] = 'approved';
          }
        } catch (_) {}
      } catch (e) {
        // If conflict on pending resolution (due to unique index), retrieve existing
        try {
          var query = client
              .from('hazard_resolution_reports')
              .select()
              .eq('report_id', trimmedReportId)
              .eq('status', 'pending');
          if (effectiveUserId != null) {
            query = query.eq('reported_by', effectiveUserId);
          } else {
            query = query.filter('reported_by', 'is', 'null');
          }
          final conflictExisting = await query.maybeSingle();
          if (conflictExisting != null) {
            savedRow = conflictExisting;
          } else {
            debugPrint('Error inserting into hazard_resolution_reports: $e');
            rethrow;
          }
        } catch (_) {
          debugPrint('Error inserting into hazard_resolution_reports: $e');
          rethrow;
        }
      }
    }

    final record = HazardResolutionReportData.fromRow(savedRow);
    final enriched = HazardResolutionReportData(
      id: record.id,
      reportId: trimmedReportId,
      reportedBy: record.reportedBy,
      hazardCategory: HazardCategories.normalize(category),
      detectedHazard: trimmedTitle,
      hazardDescription: trimmedDesc,
      severityLevel: normalizedSeverity,
      locationAddress: trimmedAddr,
      location: location ?? record.location,
      originalImageUrl: originalImageUrl ?? record.originalImageUrl,
      resolutionImageUrl: record.resolutionImageUrl,
      resolutionImageBytes: resolutionImageBytes,
      resolutionNote: record.resolutionNote,
      status: record.status,
      createdAt: record.createdAt,
    );

    recordSubmittedResolutionReport(enriched);
    return enriched;
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
        final sessionRes = _sessionResolutionReports[id];
        final effective = (sessionRes != null && report.resolutionStatus == null)
            ? report.copyWith(
                resolutionStatus: sessionRes.status,
                resolutionImageUrl: sessionRes.resolutionImageUrl,
              )
            : report;
        mergedById.putIfAbsent(id, () => effective);
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

  /// Fetches accepted (`active` or `resolved`) hazard reports submitted by [userId]
  /// (or the current authenticated user) from `public.ReportTable`, ordered newest first.
  /// Unaccepted (`pending`, `rejected`, `archived`) reports are excluded by default so
  /// they do not reflect on the user's reports or points until verified.
  Future<List<HazardReportData>> fetchUserReports({
    String? userId,
    int limit = 100,
    bool includeUnaccepted = false,
  }) async {
    final client = _tryGetClient();
    final targetUserId = userId ?? client?.auth.currentUser?.id;

    final mergedById = <String, HazardReportData>{};
    final unkeyed = <HazardReportData>[];

    void addReport(HazardReportData report) {
      if (!includeUnaccepted &&
          !HazardReportStatuses.isAcceptedForUserReports(report.status)) {
        return;
      }
      final id = report.reportId;
      if (id != null && id.isNotEmpty) {
        final sessionRes = _sessionResolutionReports[id];
        final effective = (sessionRes != null && report.resolutionStatus == null)
            ? report.copyWith(
                resolutionStatus: sessionRes.status,
                resolutionImageUrl: sessionRes.resolutionImageUrl,
              )
            : report;
        mergedById.putIfAbsent(id, () => effective);
      } else {
        unkeyed.add(report);
      }
    }

    final dbById = <String, HazardReportData>{};
    bool dbQuerySucceeded = false;
    if (client != null && targetUserId != null && targetUserId.isNotEmpty) {
      try {
        final rawRows = await client
            .from('ReportTable')
            .select()
            .eq('user_id', targetUserId)
            .order('created_at', ascending: false)
            .limit(limit);
        dbQuerySucceeded = true;

        for (final dynamic item in (rawRows as List<dynamic>)) {
          if (item is Map<String, dynamic>) {
            final parsed = HazardReportData.fromReportRow(item);
            if (parsed.reportId != null && parsed.reportId!.isNotEmpty) {
              dbById[parsed.reportId!] = parsed;
            }
            addReport(parsed);
          }
        }

        // Sync session cache statuses with authoritative DB statuses
        for (int i = 0; i < _sessionReports.length; i++) {
          final sr = _sessionReports[i];
          final id = sr.reportId;
          if (id != null && dbById.containsKey(id)) {
            _sessionReports[i] = sr.copyWith(status: dbById[id]!.status);
          }
        }
      } catch (e) {
        debugPrint('Warning: Failed to fetch user reports from ReportTable: $e');
      }
    }

    if (!dbQuerySucceeded) {
      for (final sessionReport in _sessionReports) {
        if (targetUserId == null ||
            sessionReport.userId == null ||
            sessionReport.userId == targetUserId) {
          addReport(sessionReport);
        }
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
