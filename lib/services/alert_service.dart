import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gemini_hazard_service.dart';
import 'hazard_report_service.dart';

/// Category of an alert displayed on [AlertsScreen].
enum AlertType {
  hazard,
  community,
  system;

  static AlertType fromRaw(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'hazard':
        return AlertType.hazard;
      case 'community':
        return AlertType.community;
      case 'system':
      default:
        return AlertType.system;
    }
  }
}

/// Immutable representation of an alert item from `public.alerts` merged with
/// the user's read/dismissed state from `public.user_alert_states`.
class AlertItem {
  final String id;
  final AlertType type;
  final String title;
  final String body;
  final String locationLabel;
  final LatLng? location;
  final String? severityLevel;
  final String? reportId;
  final String? targetUserId;
  final DateTime createdAt;
  final bool isRead;
  final bool isDismissed;

  const AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.locationLabel,
    this.location,
    this.severityLevel,
    this.reportId,
    this.targetUserId,
    required this.createdAt,
    this.isRead = false,
    this.isDismissed = false,
  });

  static double? _parseCoordinate(dynamic value) {
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  /// Builds an [AlertItem] from a `public.alerts` row.
  factory AlertItem.fromAlertRow(
    Map<String, dynamic> row, {
    bool isRead = false,
    bool isDismissed = false,
  }) {
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

    final rawCreatedAt = row['created_at']?.toString();
    final createdAt = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final rawLocationLabel = row['location_label']?.toString().trim() ?? '';

    return AlertItem(
      id: row['id']?.toString() ?? generateUuidV4(),
      type: AlertType.fromRaw(row['alert_type']?.toString()),
      title: row['title']?.toString().trim().isNotEmpty == true
          ? row['title'].toString().trim()
          : 'SafeRoute Alert',
      body: row['body']?.toString().trim() ?? '',
      locationLabel:
          rawLocationLabel.isNotEmpty ? rawLocationLabel : 'System Notice',
      location: parsedLocation,
      severityLevel: row['severity_level']?.toString(),
      reportId: row['report_id']?.toString(),
      targetUserId: row['target_user_id']?.toString(),
      createdAt: createdAt,
      isRead: isRead,
      isDismissed: isDismissed,
    );
  }

  /// Derives an immediate [AlertItem] from an in-session [HazardReportData]
  /// using the same classification rules as `public.sync_alert_from_hazard_report()`.
  factory AlertItem.fromHazardReport(
    HazardReportData report, {
    bool isRead = false,
    bool isDismissed = false,
  }) {
    final normalizedCategory = HazardCategories.normalize(report.category);
    final cleanCat = HazardReportService.cleanCategory(normalizedCategory);
    final normalizedSeverity =
        HazardSecurityLevels.normalize(report.securityLevel);

    final isEmergencyOrHigh = normalizedSeverity == HazardSecurityLevels.high ||
        normalizedCategory == HazardCategories.flood ||
        normalizedCategory == HazardCategories.fire ||
        normalizedCategory == HazardCategories.accident ||
        normalizedCategory == HazardCategories.brokenStreetlight;

    final type = isEmergencyOrHigh ? AlertType.hazard : AlertType.community;

    String locationLabel;
    final rawAddr = report.address.trim();
    if (rawAddr.isEmpty || rawAddr.toLowerCase() == 'current location') {
      locationLabel = 'Reported nearby';
    } else {
      final parts = rawAddr
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(2)
          .join(', ');
      final concise = parts.isNotEmpty ? parts : rawAddr;
      locationLabel = concise.toLowerCase().startsWith('near ')
          ? concise
          : 'Near $concise';
    }

    final body = report.description.trim().isNotEmpty
        ? report.description.trim()
        : (type == AlertType.hazard
            ? 'A user reported ${cleanCat.toLowerCase()} ${locationLabel.toLowerCase()} ($normalizedSeverity severity).'
            : 'Community report: ${cleanCat.toLowerCase()} ${locationLabel.toLowerCase()}. Use alternative routes if needed.');

    final reportId = report.reportId?.trim();
    return AlertItem(
      id: (reportId != null && reportId.isNotEmpty)
          ? 'session_alert_$reportId'
          : 'session_alert_${report.timestamp.microsecondsSinceEpoch}',
      type: type,
      title: report.title.trim().isNotEmpty ? report.title.trim() : cleanCat,
      body: body,
      locationLabel: locationLabel,
      location: report.location,
      severityLevel: normalizedSeverity,
      reportId: reportId,
      createdAt: report.timestamp,
      isRead: isRead,
      isDismissed: isDismissed,
    );
  }

  AlertItem copyWith({
    String? id,
    AlertType? type,
    String? title,
    String? body,
    String? locationLabel,
    LatLng? location,
    String? severityLevel,
    String? reportId,
    String? targetUserId,
    DateTime? createdAt,
    bool? isRead,
    bool? isDismissed,
  }) {
    return AlertItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      locationLabel: locationLabel ?? this.locationLabel,
      location: location ?? this.location,
      severityLevel: severityLevel ?? this.severityLevel,
      reportId: reportId ?? this.reportId,
      targetUserId: targetUserId ?? this.targetUserId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

/// Service connecting [AlertsScreen] and unread alert badges to `public.alerts`
/// and `public.user_alert_states` in Supabase.
class AlertService {
  final SupabaseClient? _explicitClient;

  /// Reactive unread alert count across the app session.
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Session-level read/dismissed cache so guest users or offline sessions also
  /// retain read/dismissed interactions cleanly.
  static final Set<String> _sessionReadIds = <String>{};
  static final Set<String> _sessionDismissedIds = <String>{};

  AlertService({SupabaseClient? client}) : _explicitClient = client;

  SupabaseClient? _tryGetClient() {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void clearSessionState() {
    _sessionReadIds.clear();
    _sessionDismissedIds.clear();
    unreadCountNotifier.value = 0;
  }

  static bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  /// Fetches active non-dismissed alerts from `public.alerts` merged with
  /// the authenticated user's `public.user_alert_states` and any brand-new
  /// in-session hazard reports.
  Future<List<AlertItem>> fetchAlerts({int limit = 50}) async {
    final client = _tryGetClient();
    final readIds = <String>{..._sessionReadIds};
    final dismissedIds = <String>{..._sessionDismissedIds};
    final dbAlerts = <AlertItem>[];
    final seenReportIds = <String>{};

    if (client != null) {
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId != null) {
        try {
          final stateRows = await client
              .from('user_alert_states')
              .select('alert_id, is_read, is_dismissed')
              .eq('user_id', currentUserId);

          for (final dynamic raw in (stateRows as List<dynamic>)) {
            if (raw is Map<String, dynamic>) {
              final alertId = raw['alert_id']?.toString();
              if (alertId == null || alertId.isEmpty) continue;
              if (raw['is_read'] == true) {
                readIds.add(alertId);
              }
              if (raw['is_dismissed'] == true) {
                dismissedIds.add(alertId);
              }
            }
          }
        } catch (e) {
          debugPrint('Warning: Failed to fetch user_alert_states: $e');
        }
      }

      try {
        final rawAlerts = await client
            .from('alerts')
            .select()
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(limit);

        for (final dynamic raw in (rawAlerts as List<dynamic>)) {
          if (raw is Map<String, dynamic>) {
            final id = raw['id']?.toString() ?? '';
            final isDismissed = dismissedIds.contains(id);
            final isRead = readIds.contains(id);
            final item = AlertItem.fromAlertRow(
              raw,
              isRead: isRead,
              isDismissed: isDismissed,
            );
            if (item.reportId != null && item.reportId!.isNotEmpty) {
              seenReportIds.add(item.reportId!);
            }
            if (!item.isDismissed) {
              dbAlerts.add(item);
            }
          }
        }
      } catch (e) {
        debugPrint('Warning: Failed to fetch alerts from Supabase: $e');
      }
    }

    // Merge any in-session submitted hazard reports not yet returned from `public.alerts`
    final merged = <AlertItem>[...dbAlerts];
    for (final sessionReport in HazardReportService.sessionReports) {
      if (sessionReport.status != 'active' || sessionReport.location == null) {
        continue;
      }
      final repId = sessionReport.reportId;
      if (repId != null && repId.isNotEmpty && seenReportIds.contains(repId)) {
        continue;
      }
      final derived = AlertItem.fromHazardReport(sessionReport);
      if (dismissedIds.contains(derived.id)) continue;
      merged.add(derived.copyWith(isRead: readIds.contains(derived.id)));
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final result = merged.length > limit ? merged.sublist(0, limit) : merged;

    unreadCountNotifier.value = result.where((a) => !a.isRead).length;
    return result;
  }

  /// Marks a single alert as read for the current user in `public.user_alert_states`.
  Future<void> markAsRead(String alertId) async {
    _sessionReadIds.add(alertId);

    final client = _tryGetClient();
    final currentUserId = client?.auth.currentUser?.id;
    if (client == null || currentUserId == null || !_isUuid(alertId)) return;

    try {
      await client.from('user_alert_states').upsert(
        {
          'user_id': currentUserId,
          'alert_id': alertId,
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,alert_id',
      );
    } catch (e) {
      debugPrint('Warning: Failed to mark alert as read: $e');
    }
  }

  /// Marks multiple alerts as read in a single batch upsert.
  Future<void> markAllAsRead(Iterable<String> alertIds) async {
    final ids = alertIds.toSet();
    if (ids.isEmpty) return;

    _sessionReadIds.addAll(ids);
    unreadCountNotifier.value = 0;

    final client = _tryGetClient();
    final currentUserId = client?.auth.currentUser?.id;
    if (client == null || currentUserId == null) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = ids
        .where(_isUuid)
        .map((id) => <String, dynamic>{
              'user_id': currentUserId,
              'alert_id': id,
              'is_read': true,
              'read_at': nowIso,
            })
        .toList();
    if (rows.isEmpty) return;

    try {
      await client
          .from('user_alert_states')
          .upsert(rows, onConflict: 'user_id,alert_id');
    } catch (e) {
      debugPrint('Warning: Failed to mark all alerts as read: $e');
    }
  }

  /// Dismisses an alert for the current user (`is_dismissed = true` in `public.user_alert_states`).
  Future<void> dismissAlert(String alertId) async {
    _sessionDismissedIds.add(alertId);
    _sessionReadIds.add(alertId);

    final client = _tryGetClient();
    final currentUserId = client?.auth.currentUser?.id;
    if (client == null || currentUserId == null || !_isUuid(alertId)) return;

    try {
      await client.from('user_alert_states').upsert(
        {
          'user_id': currentUserId,
          'alert_id': alertId,
          'is_read': true,
          'is_dismissed': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,alert_id',
      );
    } catch (e) {
      debugPrint('Warning: Failed to dismiss alert: $e');
    }
  }

  /// Restores a previously dismissed alert (`is_dismissed = false`).
  Future<void> restoreDismissedAlert(String alertId) async {
    _sessionDismissedIds.remove(alertId);

    final client = _tryGetClient();
    final currentUserId = client?.auth.currentUser?.id;
    if (client == null || currentUserId == null || !_isUuid(alertId)) return;

    try {
      await client.from('user_alert_states').upsert(
        {
          'user_id': currentUserId,
          'alert_id': alertId,
          'is_read': true,
          'is_dismissed': false,
        },
        onConflict: 'user_id,alert_id',
      );
    } catch (e) {
      debugPrint('Warning: Failed to restore dismissed alert: $e');
    }
  }
}

