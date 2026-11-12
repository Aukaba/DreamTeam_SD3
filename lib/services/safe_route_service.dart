import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hazard_report_service.dart';

/// Supported travel modes for route planning and turn-by-turn navigation.
enum RouteTravelMode {
  walking,
  cycling,
  driving;

  String get label {
    switch (this) {
      case RouteTravelMode.walking:
        return 'Walking';
      case RouteTravelMode.cycling:
        return 'Cycling';
      case RouteTravelMode.driving:
        return 'Driving';
    }
  }

  String get dbValue {
    switch (this) {
      case RouteTravelMode.walking:
        return 'walking';
      case RouteTravelMode.cycling:
        return 'cycling';
      case RouteTravelMode.driving:
        return 'driving';
    }
  }

  IconData get icon {
    switch (this) {
      case RouteTravelMode.walking:
        return Icons.directions_walk_rounded;
      case RouteTravelMode.cycling:
        return Icons.directions_bike_rounded;
      case RouteTravelMode.driving:
        return Icons.directions_car_rounded;
    }
  }

  String get valhallaCosting {
    switch (this) {
      case RouteTravelMode.walking:
        return 'pedestrian';
      case RouteTravelMode.cycling:
        return 'bicycle';
      case RouteTravelMode.driving:
        return 'auto';
    }
  }

  String get fossgisServer {
    switch (this) {
      case RouteTravelMode.walking:
        return 'routed-foot';
      case RouteTravelMode.cycling:
        return 'routed-bike';
      case RouteTravelMode.driving:
        return 'routed-car';
    }
  }

  String get fossgisProfile {
    switch (this) {
      case RouteTravelMode.walking:
        return 'foot';
      case RouteTravelMode.cycling:
        return 'bike';
      case RouteTravelMode.driving:
        return 'car';
    }
  }

  double get averageSpeedMps {
    switch (this) {
      case RouteTravelMode.walking:
        return 1.35;
      case RouteTravelMode.cycling:
        return 4.20;
      case RouteTravelMode.driving:
        return 8.50;
    }
  }

  static RouteTravelMode fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'cycling':
      case 'bicycle':
      case 'bike':
        return RouteTravelMode.cycling;
      case 'driving':
      case 'car':
      case 'auto':
        return RouteTravelMode.driving;
      case 'walking':
      case 'pedestrian':
      case 'foot':
      default:
        return RouteTravelMode.walking;
    }
  }
}

/// Standardized turn-by-turn maneuver types across Valhalla and OSRM.
enum ManeuverType {
  depart,
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  roundabout,
  merge,
  arrive;

  IconData get icon {
    switch (this) {
      case ManeuverType.depart:
        return Icons.my_location_rounded;
      case ManeuverType.straight:
        return Icons.straight_rounded;
      case ManeuverType.slightLeft:
        return Icons.turn_slight_left_rounded;
      case ManeuverType.left:
        return Icons.turn_left_rounded;
      case ManeuverType.sharpLeft:
        return Icons.turn_sharp_left_rounded;
      case ManeuverType.slightRight:
        return Icons.turn_slight_right_rounded;
      case ManeuverType.right:
        return Icons.turn_right_rounded;
      case ManeuverType.sharpRight:
        return Icons.turn_sharp_right_rounded;
      case ManeuverType.uTurn:
        return Icons.u_turn_left_rounded;
      case ManeuverType.roundabout:
        return Icons.roundabout_right_rounded;
      case ManeuverType.merge:
        return Icons.merge_rounded;
      case ManeuverType.arrive:
        return Icons.flag_rounded;
    }
  }

  static ManeuverType fromName(String? raw) {
    for (final value in ManeuverType.values) {
      if (value.name == raw) return value;
    }
    return ManeuverType.straight;
  }
}

/// Overall safety classification for a route candidate or saved route.
enum RouteRiskLevel {
  safe,
  low,
  moderate,
  high;

  String get dbValue => name;

  String get badgeLabel {
    switch (this) {
      case RouteRiskLevel.safe:
        return 'Safe';
      case RouteRiskLevel.low:
        return 'Low risk';
      case RouteRiskLevel.moderate:
        return 'Moderate risk';
      case RouteRiskLevel.high:
        return 'High risk';
    }
  }

  static RouteRiskLevel fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'low':
        return RouteRiskLevel.low;
      case 'moderate':
      case 'medium':
        return RouteRiskLevel.moderate;
      case 'high':
      case 'critical':
        return RouteRiskLevel.high;
      case 'safe':
      default:
        return RouteRiskLevel.safe;
    }
  }
}

/// Single turn-by-turn navigation step along a [RouteCandidate].
class RouteStep {
  final int index;
  final String instruction;
  final String streetName;
  final double distanceMeters;
  final int durationSeconds;
  final ManeuverType maneuverType;
  final LatLng location;
  final int startPolylineIndex;
  final int endPolylineIndex;

  const RouteStep({
    required this.index,
    required this.instruction,
    required this.streetName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    required this.location,
    required this.startPolylineIndex,
    required this.endPolylineIndex,
  });

  String get formattedDistance =>
      SafeRouteService.formatDistance(distanceMeters);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'index': index,
      'instruction': instruction,
      'street_name': streetName,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'maneuver_type': maneuverType.name,
      'lat': location.latitude,
      'lng': location.longitude,
      'start_idx': startPolylineIndex,
      'end_idx': endPolylineIndex,
    };
  }

  factory RouteStep.fromJson(Map<String, dynamic> json, {int fallbackIndex = 0}) {
    return RouteStep(
      index: (json['index'] as num?)?.toInt() ?? fallbackIndex,
      instruction: json['instruction']?.toString() ?? 'Continue straight',
      streetName: json['street_name']?.toString() ?? '',
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      maneuverType: ManeuverType.fromName(json['maneuver_type']?.toString()),
      location: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      startPolylineIndex: (json['start_idx'] as num?)?.toInt() ?? 0,
      endPolylineIndex: (json['end_idx'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents a hazard's proximity and risk impact relative to a specific route.
class RouteHazardExposure {
  final HazardReportData hazard;
  final double distanceFromRouteMeters;
  final double avoidanceRadiusMeters;
  final double severityWeight;

  const RouteHazardExposure({
    required this.hazard,
    required this.distanceFromRouteMeters,
    required this.avoidanceRadiusMeters,
    required this.severityWeight,
  });

  bool get isOnRoute => distanceFromRouteMeters <= avoidanceRadiusMeters;
  bool get isNearCorridor =>
      distanceFromRouteMeters <= avoidanceRadiusMeters * 1.8;
}

/// Evaluated road route candidate with geometry, turn-by-turn steps, and hazard metrics.
class RouteCandidate {
  final String id;
  final String provider;
  final String summary;
  final List<LatLng> polyline;
  final List<RouteStep> steps;
  final double distanceMeters;
  final int durationSeconds;
  final int trafficDelaySeconds;
  final List<RouteHazardExposure> hazardsOnRoute;
  final List<RouteHazardExposure> hazardsNearCorridor;
  final double hazardPenaltyScore;
  final RouteRiskLevel riskLevel;
  final bool usedHazardExclusion;

  const RouteCandidate({
    required this.id,
    required this.provider,
    required this.summary,
    required this.polyline,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
    this.trafficDelaySeconds = 0,
    this.hazardsOnRoute = const <RouteHazardExposure>[],
    this.hazardsNearCorridor = const <RouteHazardExposure>[],
    this.hazardPenaltyScore = 0.0,
    this.riskLevel = RouteRiskLevel.safe,
    this.usedHazardExclusion = false,
  });

  String get formattedDistance =>
      SafeRouteService.formatDistance(distanceMeters);
  String get formattedDuration =>
      SafeRouteService.formatDuration(durationSeconds);
  String get distanceAndTimeLabel => '$formattedDistance · $formattedDuration';

  /// Human-readable traffic delay label (e.g. "+3 min delay", "+<1m delay").
  String get trafficDelayLabel {
    if (trafficDelaySeconds <= 0) return '';
    final mins = (trafficDelaySeconds / 60).round();
    if (mins <= 0) return '+<1m delay';
    return '+$mins min delay';
  }

  /// Whether this candidate experiences noticeable traffic congestion (>= 60s).
  bool get hasTrafficDelay => trafficDelaySeconds >= 60;

  /// Combined safety-weighted cost: prioritizes hazard avoidance, shorter distance,
  /// and penalizes real-time traffic congestion.
  double get safetyWeightedCost =>
      hazardPenaltyScore + distanceMeters + (trafficDelaySeconds * 1.5);

  RouteCandidate copyWith({
    String? id,
    String? provider,
    String? summary,
    List<LatLng>? polyline,
    List<RouteStep>? steps,
    double? distanceMeters,
    int? durationSeconds,
    int? trafficDelaySeconds,
    List<RouteHazardExposure>? hazardsOnRoute,
    List<RouteHazardExposure>? hazardsNearCorridor,
    double? hazardPenaltyScore,
    RouteRiskLevel? riskLevel,
    bool? usedHazardExclusion,
  }) {
    return RouteCandidate(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      summary: summary ?? this.summary,
      polyline: polyline ?? this.polyline,
      steps: steps ?? this.steps,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      trafficDelaySeconds: trafficDelaySeconds ?? this.trafficDelaySeconds,
      hazardsOnRoute: hazardsOnRoute ?? this.hazardsOnRoute,
      hazardsNearCorridor: hazardsNearCorridor ?? this.hazardsNearCorridor,
      hazardPenaltyScore: hazardPenaltyScore ?? this.hazardPenaltyScore,
      riskLevel: riskLevel ?? this.riskLevel,
      usedHazardExclusion: usedHazardExclusion ?? this.usedHazardExclusion,
    );
  }
}

/// Complete output of [SafeRouteService.findSafeRoute], including primary and alternative routes.
class PlannedRouteResult {
  final LatLng origin;
  final String originLabel;
  final LatLng destination;
  final String destinationLabel;
  final RouteTravelMode travelMode;
  final bool avoidHazards;
  final RouteCandidate primaryRoute;
  final List<RouteCandidate> alternatives;
  final List<HazardReportData> corridorHazards;
  final int hazardsAvoided;
  final String? savedRouteId;

  const PlannedRouteResult({
    required this.origin,
    required this.originLabel,
    required this.destination,
    required this.destinationLabel,
    required this.travelMode,
    required this.avoidHazards,
    required this.primaryRoute,
    required this.alternatives,
    required this.corridorHazards,
    required this.hazardsAvoided,
    this.savedRouteId,
  });

  PlannedRouteResult withSelectedCandidate(RouteCandidate candidate) {
    final directHazardCount = alternatives.isEmpty
        ? candidate.hazardsOnRoute.length
        : alternatives
            .map((c) => c.hazardsOnRoute.length)
            .reduce(math.max);
    return PlannedRouteResult(
      origin: origin,
      originLabel: originLabel,
      destination: destination,
      destinationLabel: destinationLabel,
      travelMode: travelMode,
      avoidHazards: avoidHazards,
      primaryRoute: candidate,
      alternatives: alternatives,
      corridorHazards: corridorHazards,
      hazardsAvoided:
          math.max(0, directHazardCount - candidate.hazardsOnRoute.length),
      savedRouteId: savedRouteId,
    );
  }

  PlannedRouteResult copyWith({String? savedRouteId}) {
    return PlannedRouteResult(
      origin: origin,
      originLabel: originLabel,
      destination: destination,
      destinationLabel: destinationLabel,
      travelMode: travelMode,
      avoidHazards: avoidHazards,
      primaryRoute: primaryRoute,
      alternatives: alternatives,
      corridorHazards: corridorHazards,
      hazardsAvoided: hazardsAvoided,
      savedRouteId: savedRouteId ?? this.savedRouteId,
    );
  }
}

/// Persisted route record backed by `public.saved_routes` with local cache fallback.
class SavedRouteRecord {
  final String id;
  final String? userId;
  final String title;
  final String originLabel;
  final LatLng origin;
  final String destinationLabel;
  final LatLng destination;
  final RouteTravelMode travelMode;
  final bool avoidHazards;
  final double distanceMeters;
  final int durationSeconds;
  final int hazardCount;
  final RouteRiskLevel riskLevel;
  final String routeSummary;
  final List<LatLng> polyline;
  final List<RouteStep> steps;
  final bool isFavorite;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedRouteRecord({
    required this.id,
    this.userId,
    required this.title,
    required this.originLabel,
    required this.origin,
    required this.destinationLabel,
    required this.destination,
    this.travelMode = RouteTravelMode.walking,
    this.avoidHazards = true,
    required this.distanceMeters,
    required this.durationSeconds,
    this.hazardCount = 0,
    this.riskLevel = RouteRiskLevel.safe,
    this.routeSummary = '',
    this.polyline = const <LatLng>[],
    this.steps = const <RouteStep>[],
    this.isFavorite = true,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get distanceAndTimeLabel =>
      '${SafeRouteService.formatDistance(distanceMeters)} · ${SafeRouteService.formatDuration(durationSeconds)}';

  factory SavedRouteRecord.fromJson(Map<String, dynamic> json) {
    final rawPoly = json['route_polyline'];
    final parsedPoly = <LatLng>[];
    bool hasCorruptedCoordinate = false;
    if (rawPoly is List) {
      for (final pt in rawPoly) {
        double? lat;
        double? lng;
        if (pt is List && pt.length >= 2) {
          lat = (pt[0] as num?)?.toDouble();
          lng = (pt[1] as num?)?.toDouble();
        } else if (pt is Map) {
          lat = (pt['lat'] as num?)?.toDouble();
          lng = (pt['lng'] as num?)?.toDouble();
        }
        if (lat != null && lng != null) {
          if (!lat.isFinite ||
              !lng.isFinite ||
              lat < -90.0 ||
              lat > 90.0 ||
              lng < -180.0 ||
              lng > 180.0) {
            hasCorruptedCoordinate = true;
            break;
          }
          parsedPoly.add(LatLng(lat, lng));
        }
      }
    }
    if (hasCorruptedCoordinate) {
      parsedPoly.clear();
    }

    final rawSteps = json['route_steps'];
    final parsedSteps = <RouteStep>[];
    if (rawSteps is List) {
      for (int i = 0; i < rawSteps.length; i++) {
        final item = rawSteps[i];
        if (item is Map<String, dynamic>) {
          parsedSteps.add(RouteStep.fromJson(item, fallbackIndex: i));
        } else if (item is Map) {
          parsedSteps.add(
            RouteStep.fromJson(Map<String, dynamic>.from(item), fallbackIndex: i),
          );
        }
      }
    }

    return SavedRouteRecord(
      id: json['id']?.toString() ?? generateUuidV4(),
      userId: json['user_id']?.toString(),
      title: json['title']?.toString() ?? 'Saved Route',
      originLabel: json['origin_label']?.toString() ?? 'Origin',
      origin: LatLng(
        (json['origin_lat'] as num?)?.toDouble() ?? 10.3157,
        (json['origin_lng'] as num?)?.toDouble() ?? 123.8854,
      ),
      destinationLabel: json['destination_label']?.toString() ?? 'Destination',
      destination: LatLng(
        (json['destination_lat'] as num?)?.toDouble() ?? 10.3157,
        (json['destination_lng'] as num?)?.toDouble() ?? 123.8854,
      ),
      travelMode: RouteTravelMode.fromString(json['travel_mode']?.toString()),
      avoidHazards: json['avoid_hazards'] as bool? ?? true,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      hazardCount: (json['hazard_count'] as num?)?.toInt() ?? 0,
      riskLevel: RouteRiskLevel.fromString(json['risk_level']?.toString()),
      routeSummary: json['route_summary']?.toString() ?? '',
      polyline: parsedPoly,
      steps: parsedSteps,
      isFavorite: json['is_favorite'] as bool? ?? true,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toDbPayload(String ownerUserId) {
    // Downsample stored polyline to max 160 points to keep JSONB compact
    final compactPoly = SafeRouteService.downsamplePolyline(polyline, maxPoints: 160)
        .map((pt) => <double>[
              double.parse(pt.latitude.toStringAsFixed(6)),
              double.parse(pt.longitude.toStringAsFixed(6)),
            ])
        .toList();

    return <String, dynamic>{
      'id': id,
      'user_id': ownerUserId,
      'title': title.trim(),
      'origin_label': originLabel.trim(),
      'origin_lat': origin.latitude,
      'origin_lng': origin.longitude,
      'destination_label': destinationLabel.trim(),
      'destination_lat': destination.latitude,
      'destination_lng': destination.longitude,
      'travel_mode': travelMode.dbValue,
      'avoid_hazards': avoidHazards,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'hazard_count': hazardCount,
      'risk_level': riskLevel.dbValue,
      'route_summary': routeSummary.trim().isEmpty ? null : routeSummary.trim(),
      'route_polyline': compactPoly,
      'route_steps': steps.map((s) => s.toJson()).toList(),
      'is_favorite': isFavorite,
      if (lastUsedAt != null)
        'last_used_at': lastUsedAt!.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalCacheJson() {
    return <String, dynamic>{
      ...toDbPayload(userId ?? ''),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Dynamically re-evaluates this saved route's risk level against live active hazards.
  SavedRouteRecord withLiveHazards(List<HazardReportData> activeHazards) {
    if (polyline.length < 2) return this;
    final candidate = SafeRouteService.evaluateCandidateAgainstHazards(
      RouteCandidate(
        id: id,
        provider: 'saved',
        summary: routeSummary,
        polyline: polyline,
        steps: steps,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      ),
      activeHazards,
    );
    return SavedRouteRecord(
      id: id,
      userId: userId,
      title: title,
      originLabel: originLabel,
      origin: origin,
      destinationLabel: destinationLabel,
      destination: destination,
      travelMode: travelMode,
      avoidHazards: avoidHazards,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      hazardCount: candidate.hazardsOnRoute.length,
      riskLevel: candidate.riskLevel,
      routeSummary: routeSummary,
      polyline: polyline,
      steps: steps,
      isFavorite: isFavorite,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Converts a cached [SavedRouteRecord] into an immediate [PlannedRouteResult]
  /// (used as an instant preview or offline fallback while refreshing live road routing).
  PlannedRouteResult toCachedPlannedResult({
    List<HazardReportData> activeHazards = const <HazardReportData>[],
  }) {
    final effectivePoly =
        polyline.length >= 2 ? polyline : <LatLng>[origin, destination];
    final effectiveSteps = steps.isNotEmpty
        ? steps
        : <RouteStep>[
            RouteStep(
              index: 0,
              instruction: 'Head toward $destinationLabel',
              streetName: routeSummary,
              distanceMeters: distanceMeters,
              durationSeconds: durationSeconds,
              maneuverType: ManeuverType.depart,
              location: origin,
              startPolylineIndex: 0,
              endPolylineIndex: effectivePoly.length - 1,
            ),
            RouteStep(
              index: 1,
              instruction: 'Arrive at $destinationLabel',
              streetName: destinationLabel,
              distanceMeters: 0,
              durationSeconds: 0,
              maneuverType: ManeuverType.arrive,
              location: destination,
              startPolylineIndex: effectivePoly.length - 1,
              endPolylineIndex: effectivePoly.length - 1,
            ),
          ];

    final evaluated = SafeRouteService.evaluateCandidateAgainstHazards(
      RouteCandidate(
        id: 'saved_$id',
        provider: 'saved',
        summary: routeSummary.isNotEmpty
            ? routeSummary
            : '$originLabel → $destinationLabel',
        polyline: effectivePoly,
        steps: effectiveSteps,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      ),
      activeHazards,
    );

    return PlannedRouteResult(
      origin: origin,
      originLabel: originLabel,
      destination: destination,
      destinationLabel: destinationLabel,
      travelMode: travelMode,
      avoidHazards: avoidHazards,
      primaryRoute: evaluated,
      alternatives: <RouteCandidate>[evaluated],
      corridorHazards: activeHazards,
      hazardsAvoided: 0,
      savedRouteId: id,
    );
  }
}

/// Snapshot of user's live position projected onto an active navigation polyline.
class PolylineSnapResult {
  final LatLng snappedPoint;
  final int segmentIndex;
  final double distanceFromRouteMeters;
  final double remainingDistanceMeters;
  final double bearingDegrees;

  const PolylineSnapResult({
    required this.snappedPoint,
    required this.segmentIndex,
    required this.distanceFromRouteMeters,
    required this.remainingDistanceMeters,
    required this.bearingDegrees,
  });
}

/// Hazard-aware routing, turn-by-turn instruction parser, and Supabase persistence service.
class SafeRouteService {
  static const String _localSavedRoutesKey = 'saferoute_saved_routes_cache_v1';
  static const double _earthRadiusMeters = 6371000.0;

  final http.Client _httpClient;
  final SupabaseClient? _explicitSupabase;
  final HazardReportService _hazardReportService;
  final String? _tomTomApiKey;

  SafeRouteService({
    http.Client? httpClient,
    SupabaseClient? supabaseClient,
    HazardReportService? hazardReportService,
    String? tomtomApiKey,
  })  : _httpClient = httpClient ?? http.Client(),
        _explicitSupabase = supabaseClient,
        _hazardReportService = hazardReportService ??
            HazardReportService(client: supabaseClient),
        _tomTomApiKey = tomtomApiKey;

  String get tomtomApiKey {
    final directKey = _tomTomApiKey;
    if (directKey != null && directKey.trim().isNotEmpty) {
      final clean = directKey.trim().replaceAll('"', '').replaceAll("'", '');
      if (clean != 'YOUR_TOMTOM_API_KEY_HERE') return clean;
    }
    try {
      final key = dotenv.env['TOMTOM_API_KEY'];
      if (key != null && key.trim().isNotEmpty) {
        final clean = key.trim().replaceAll('"', '').replaceAll("'", '');
        if (clean != 'YOUR_TOMTOM_API_KEY_HERE') return clean;
      }
    } catch (_) {}
    return '';
  }

  SupabaseClient? _tryGetSupabase() {
    if (_explicitSupabase != null) return _explicitSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _tryGetSupabase()?.auth.currentUser;

  // ---------------------------------------------------------------------------
  // FORMATTING & GEOMETRY HELPERS
  // ---------------------------------------------------------------------------

  static String formatDistance(double meters) {
    if (!meters.isFinite || meters <= 0) {
      return '0 m';
    }
    if (meters < 1000) {
      if (meters >= 100) {
        return '${((meters / 10).round() * 10)} m';
      }
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '1 min';
    final minutes = (seconds / 60.0).ceil().clamp(1, 99999);
    if (minutes < 60) {
      return '$minutes min';
    }
    final hrs = minutes ~/ 60;
    final remMins = minutes % 60;
    if (remMins == 0) return '$hrs hr';
    return '$hrs hr $remMins min';
  }

  /// Decodes a Valhalla / OSRM encoded polyline string (default precision `1e6` for Valhalla).
  /// Uses pure integer arithmetic instead of bitwise shifts/NOT (`~`, `<<`, `>>`) so
  /// negative coordinate deltas decode identically on 64-bit Dart VM and Dart Web (JS),
  /// where bitwise `~` produces unsigned 32-bit values (`0xFFFFFFFF`).
  static List<LatLng> decodePolyline(String encoded, {int precision = 6}) {
    if (encoded.isEmpty) return const <LatLng>[];
    final points = <LatLng>[];
    final double factor = math.pow(10.0, precision).toDouble();
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int multiplier = 1;
      int result = 0;
      do {
        if (index >= len) return points;
        b = encoded.codeUnitAt(index++) - 63;
        final int chunk = b >= 32 ? (b - 32) : b;
        result += chunk * multiplier;
        multiplier *= 32;
      } while (b >= 32);
      final int dlat = result.isOdd ? -((result + 1) ~/ 2) : (result ~/ 2);
      lat += dlat;

      multiplier = 1;
      result = 0;
      do {
        if (index >= len) return points;
        b = encoded.codeUnitAt(index++) - 63;
        final int chunk = b >= 32 ? (b - 32) : b;
        result += chunk * multiplier;
        multiplier *= 32;
      } while (b >= 32);
      final int dlng = result.isOdd ? -((result + 1) ~/ 2) : (result ~/ 2);
      lng += dlng;

      final double decodedLat = lat / factor;
      final double decodedLng = lng / factor;
      if (decodedLat.isFinite &&
          decodedLng.isFinite &&
          decodedLat >= -90.0 &&
          decodedLat <= 90.0 &&
          decodedLng >= -180.0 &&
          decodedLng <= 180.0) {
        points.add(LatLng(decodedLat, decodedLng));
      }
    }
    return points;
  }

  /// Downsamples a dense polyline while strictly preserving start and end coordinates.
  static List<LatLng> downsamplePolyline(
    List<LatLng> polyline, {
    int maxPoints = 160,
  }) {
    if (polyline.length <= maxPoints || maxPoints < 2) return polyline;
    final result = <LatLng>[polyline.first];
    final step = (polyline.length - 1) / (maxPoints - 1);
    for (int i = 1; i < maxPoints - 1; i++) {
      result.add(polyline[(i * step).round()]);
    }
    result.add(polyline.last);
    return result;
  }

  /// Computes hazard avoidance radius (meters) and penalty weight from report category/severity.
  static ({double avoidanceRadiusMeters, double severityWeight})
      hazardMetricsForReport(HazardReportData report) {
    final catLower = report.category.toLowerCase();
    final secLower = report.securityLevel.toLowerCase();

    double radius = 65.0;
    if (catLower.contains('flood') ||
        catLower.contains('fire') ||
        catLower.contains('blocked')) {
      radius = 100.0;
    } else if (secLower.contains('high') ||
        secLower.contains('critical') ||
        catLower.contains('accident') ||
        catLower.contains('fallen')) {
      radius = 85.0;
    } else if (secLower.contains('low')) {
      radius = 45.0;
    }

    double weight = 65.0;
    if (secLower.contains('high') ||
        secLower.contains('critical') ||
        catLower.contains('flood') ||
        catLower.contains('fire') ||
        catLower.contains('blocked')) {
      weight = 120.0;
    } else if (secLower.contains('low')) {
      weight = 30.0;
    }

    return (avoidanceRadiusMeters: radius, severityWeight: weight);
  }

  /// Exact perpendicular distance in meters from [point] to line segment [a]-[b].
  static double pointToSegmentDistanceMeters(
    LatLng point,
    LatLng a,
    LatLng b,
  ) {
    final latRad = point.latitude * math.pi / 180.0;
    final cosLat = math.cos(latRad);

    double toX(double lng) =>
        (lng - point.longitude) * (math.pi / 180.0) * cosLat * _earthRadiusMeters;
    double toY(double lat) =>
        (lat - point.latitude) * (math.pi / 180.0) * _earthRadiusMeters;

    final ax = toX(a.longitude);
    final ay = toY(a.latitude);
    final bx = toX(b.longitude);
    final by = toY(b.latitude);

    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;

    double t = 0.0;
    if (lenSq > 1e-9) {
      // Projection of origin (0,0) onto segment A->B: t = -(A · (B - A)) / |B - A|^2
      t = (-(ax * dx + ay * dy) / lenSq).clamp(0.0, 1.0);
    }

    final projX = ax + t * dx;
    final projY = ay + t * dy;
    return math.sqrt(projX * projX + projY * projY);
  }

  /// Minimum perpendicular distance in meters from [point] to [polyline].
  static double pointToPolylineDistanceMeters(
    LatLng point,
    List<LatLng> polyline,
  ) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return const Distance().distance(point, polyline.first);
    }
    double minDist = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = pointToSegmentDistanceMeters(point, polyline[i], polyline[i + 1]);
      if (d < minDist) {
        minDist = d;
      }
    }
    return minDist;
  }

  /// Projects [position] onto [polyline] for real-time turn-by-turn tracking,
  /// off-route detection, remaining distance calculation, and heading bearing.
  static PolylineSnapResult locateAlongPolyline(
    LatLng position,
    List<LatLng> polyline,
  ) {
    if (polyline.isEmpty) {
      return PolylineSnapResult(
        snappedPoint: position,
        segmentIndex: 0,
        distanceFromRouteMeters: 0,
        remainingDistanceMeters: 0,
        bearingDegrees: 0,
      );
    }
    if (polyline.length == 1) {
      final d = const Distance().distance(position, polyline.first);
      return PolylineSnapResult(
        snappedPoint: polyline.first,
        segmentIndex: 0,
        distanceFromRouteMeters: d,
        remainingDistanceMeters: d,
        bearingDegrees: 0,
      );
    }

    final latRad = position.latitude * math.pi / 180.0;
    final cosLat = math.cos(latRad);
    double toX(double lng) =>
        (lng - position.longitude) * (math.pi / 180.0) * cosLat * _earthRadiusMeters;
    double toY(double lat) =>
        (lat - position.latitude) * (math.pi / 180.0) * _earthRadiusMeters;

    int bestSegment = 0;
    double bestDist = double.infinity;
    double bestT = 0.0;

    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final ax = toX(a.longitude);
      final ay = toY(a.latitude);
      final bx = toX(b.longitude);
      final by = toY(b.latitude);
      final dx = bx - ax;
      final dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      final t = lenSq > 1e-9 ? (-(ax * dx + ay * dy) / lenSq).clamp(0.0, 1.0) : 0.0;
      final px = ax + t * dx;
      final py = ay + t * dy;
      final dist = math.sqrt(px * px + py * py);
      if (dist < bestDist) {
        bestDist = dist;
        bestSegment = i;
        bestT = t;
      }
    }

    final segStart = polyline[bestSegment];
    final segEnd = polyline[bestSegment + 1];
    final snapped = LatLng(
      segStart.latitude + (segEnd.latitude - segStart.latitude) * bestT,
      segStart.longitude + (segEnd.longitude - segStart.longitude) * bestT,
    );

    const distCalc = Distance();
    double remaining = distCalc.distance(snapped, segEnd);
    for (int j = bestSegment + 1; j < polyline.length - 1; j++) {
      remaining += distCalc.distance(polyline[j], polyline[j + 1]);
    }

    final bearing = _bearingDegrees(segStart, segEnd);

    return PolylineSnapResult(
      snappedPoint: snapped,
      segmentIndex: bestSegment,
      distanceFromRouteMeters: bestDist,
      remainingDistanceMeters: remaining,
      bearingDegrees: bearing,
    );
  }

  static double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    return (brng + 360.0) % 360.0;
  }

  /// Generates a closed GeoJSON polygon ring `[[lon, lat], ...]` around [center]
  /// for Valhalla's graph-level `exclude_polygons` hazard avoidance.
  static List<List<double>> buildHazardExclusionPolygon(
    LatLng center,
    double radiusMeters, {
    int vertices = 8,
  }) {
    final ring = <List<double>>[];
    final latRad = center.latitude * math.pi / 180.0;
    const metersPerDegLat = 111320.0;
    final metersPerDegLon = (111320.0 * math.cos(latRad)).abs().clamp(1.0, 111320.0);

    for (int i = 0; i < vertices; i++) {
      final angle = (2.0 * math.pi * i) / vertices;
      final dLat = (radiusMeters * math.sin(angle)) / metersPerDegLat;
      final dLon = (radiusMeters * math.cos(angle)) / metersPerDegLon;
      ring.add(<double>[
        double.parse((center.longitude + dLon).toStringAsFixed(6)),
        double.parse((center.latitude + dLat).toStringAsFixed(6)),
      ]);
    }
    if (ring.isNotEmpty) {
      ring.add(<double>[ring.first[0], ring.first[1]]);
    }
    return ring;
  }

  /// Scores a [RouteCandidate] against all active hazards in the corridor.
  static RouteCandidate evaluateCandidateAgainstHazards(
    RouteCandidate candidate,
    List<HazardReportData> hazards,
  ) {
    if (candidate.polyline.isEmpty || hazards.isEmpty) {
      return candidate.copyWith(
        hazardsOnRoute: const <RouteHazardExposure>[],
        hazardsNearCorridor: const <RouteHazardExposure>[],
        hazardPenaltyScore: 0.0,
        riskLevel: RouteRiskLevel.safe,
      );
    }

    final onRoute = <RouteHazardExposure>[];
    final nearCorridor = <RouteHazardExposure>[];
    double penalty = 0.0;

    for (final hazard in hazards) {
      final loc = hazard.location;
      if (loc == null || hazard.status != 'active') continue;
      final metrics = hazardMetricsForReport(hazard);
      final dist = pointToPolylineDistanceMeters(loc, candidate.polyline);
      final radius = metrics.avoidanceRadiusMeters;
      final weight = metrics.severityWeight;

      if (dist <= radius) {
        final closenessFactor = 2.5 - 1.5 * (dist / radius).clamp(0.0, 1.0);
        penalty += weight * closenessFactor * 100.0;
        final exposure = RouteHazardExposure(
          hazard: hazard,
          distanceFromRouteMeters: dist,
          avoidanceRadiusMeters: radius,
          severityWeight: weight,
        );
        onRoute.add(exposure);
        nearCorridor.add(exposure);
      } else if (dist <= radius * 1.8) {
        final bufferFactor = 1.0 - ((dist - radius) / (0.8 * radius)).clamp(0.0, 1.0);
        penalty += weight * bufferFactor * 12.0;
        nearCorridor.add(
          RouteHazardExposure(
            hazard: hazard,
            distanceFromRouteMeters: dist,
            avoidanceRadiusMeters: radius,
            severityWeight: weight,
          ),
        );
      }
    }

    onRoute.sort(
      (a, b) => a.distanceFromRouteMeters.compareTo(b.distanceFromRouteMeters),
    );
    nearCorridor.sort(
      (a, b) => a.distanceFromRouteMeters.compareTo(b.distanceFromRouteMeters),
    );

    RouteRiskLevel risk = RouteRiskLevel.safe;
    if (onRoute.any((e) => e.severityWeight >= 110.0) || onRoute.length >= 2) {
      risk = RouteRiskLevel.high;
    } else if (onRoute.isNotEmpty) {
      risk = RouteRiskLevel.moderate;
    } else if (nearCorridor.length > onRoute.length) {
      risk = RouteRiskLevel.low;
    }

    return candidate.copyWith(
      hazardsOnRoute: onRoute,
      hazardsNearCorridor: nearCorridor,
      hazardPenaltyScore: penalty,
      riskLevel: risk,
    );
  }

  // ---------------------------------------------------------------------------
  // CORRIDOR HAZARD DISCOVERY (SUPABASE RPC + REPORT SERVICE MERGE)
  // ---------------------------------------------------------------------------

  Future<List<HazardReportData>> fetchCorridorHazards(
    LatLng origin,
    LatLng destination,
  ) async {
    final latSpan = (origin.latitude - destination.latitude).abs();
    final lngSpan = (origin.longitude - destination.longitude).abs();
    final padLat = math.max(0.016, latSpan * 0.45);
    final padLng = math.max(0.016, lngSpan * 0.45);

    final minLat = math.min(origin.latitude, destination.latitude) - padLat;
    final maxLat = math.max(origin.latitude, destination.latitude) + padLat;
    final minLng = math.min(origin.longitude, destination.longitude) - padLng;
    final maxLng = math.max(origin.longitude, destination.longitude) + padLng;

    final mergedById = <String, HazardReportData>{};
    final unkeyed = <HazardReportData>[];
    const distCalc = Distance();

    void addIfInCorridor(HazardReportData report) {
      final loc = report.location;
      if (loc == null || report.status != 'active') return;
      if (loc.latitude < minLat ||
          loc.latitude > maxLat ||
          loc.longitude < minLng ||
          loc.longitude > maxLng) {
        return;
      }
      final id = report.reportId?.trim();
      if (id != null && id.isNotEmpty) {
        mergedById.putIfAbsent(id, () => report);
      } else {
        final isDup = unkeyed.any(
          (u) =>
              u.location != null &&
              u.category == report.category &&
              distCalc.distance(u.location!, loc) < 15.0,
        );
        if (!isDup) unkeyed.add(report);
      }
    }

    // 1. Always include active in-session reports immediately
    for (final sessionReport in HazardReportService.sessionReports) {
      addIfInCorridor(sessionReport);
    }

    // 2. Query indexed Postgres corridor RPC (`get_active_hazards_in_corridor`)
    final sb = _tryGetSupabase();
    bool rpcSucceeded = false;
    if (sb != null) {
      try {
        final dynamic rows = await sb.rpc(
          'get_active_hazards_in_corridor',
          params: <String, dynamic>{
            'p_min_lat': minLat,
            'p_max_lat': maxLat,
            'p_min_lng': minLng,
            'p_max_lng': maxLng,
            'p_max_age_days': 30,
          },
        );
        if (rows is List) {
          rpcSucceeded = true;
          for (final item in rows) {
            if (item is Map<String, dynamic>) {
              addIfInCorridor(HazardReportData.fromReportRow(item));
            } else if (item is Map) {
              addIfInCorridor(
                HazardReportData.fromReportRow(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Corridor RPC fallback to ReportTable select: $e');
      }
    }

    // 3. Fallback to HazardReportService.fetchReports when RPC is unavailable or mocked in tests
    if (!rpcSucceeded) {
      try {
        final fetched = await _hazardReportService.fetchReports(
          limit: 150,
          activeOnly: true,
        );
        for (final r in fetched) {
          addIfInCorridor(r);
        }
      } catch (e) {
        debugPrint('HazardReportService fallback error: $e');
      }
    }

    return <HazardReportData>[...mergedById.values, ...unkeyed];
  }

  // ---------------------------------------------------------------------------
  // PRIMARY HAZARD-PRIORITIZED ROUTING ENGINE
  // ---------------------------------------------------------------------------

  Future<PlannedRouteResult> findSafeRoute({
    required LatLng origin,
    required String originLabel,
    required LatLng destination,
    required String destinationLabel,
    RouteTravelMode travelMode = RouteTravelMode.walking,
    bool avoidHazards = true,
  }) async {
    final corridorHazards = await fetchCorridorHazards(origin, destination);
    final rawCandidates = <RouteCandidate>[];

    // 1. Fetch baseline road candidates (Valhalla + FOSSGIS OSRM + TomTom in parallel)
    final baselineTasks = <Future<List<RouteCandidate>>>[
      _fetchValhallaCandidates(
        origin: origin,
        destination: destination,
        travelMode: travelMode,
      ),
      _fetchOsrmCandidates(
        origin: origin,
        destination: destination,
        travelMode: travelMode,
      ),
    ];

    if (tomtomApiKey.isNotEmpty) {
      baselineTasks.add(
        _fetchTomTomCandidates(
          origin: origin,
          destination: destination,
          travelMode: travelMode,
        ),
      );
    }

    final baselineFutures = await Future.wait<List<RouteCandidate>>(baselineTasks);

    for (final list in baselineFutures) {
      rawCandidates.addAll(list);
    }

    // Evaluate baseline candidates to inspect whether direct roads hit hazards
    final evaluatedBaseline = rawCandidates
        .map((c) => evaluateCandidateAgainstHazards(c, corridorHazards))
        .toList();

    final bool anyHazardInCorridor = corridorHazards.isNotEmpty;
    final bool allBaselineHitHazards = evaluatedBaseline.isEmpty ||
        evaluatedBaseline.every((c) => c.hazardsOnRoute.isNotEmpty);
    final bool fastestHitsHazards = evaluatedBaseline.isNotEmpty &&
        evaluatedBaseline.first.hazardsOnRoute.isNotEmpty;

    // 2. Graph-level hazard avoidance via Valhalla `exclude_polygons`
    if (avoidHazards &&
        anyHazardInCorridor &&
        (fastestHitsHazards || allBaselineHitHazards)) {
      final excludablePolygons = _selectExcludablePolygons(
        origin: origin,
        destination: destination,
        corridorHazards: corridorHazards,
        referenceRoutes: evaluatedBaseline,
      );

      if (excludablePolygons.isNotEmpty) {
        final safeValhalla = await _fetchValhallaCandidates(
          origin: origin,
          destination: destination,
          travelMode: travelMode,
          excludePolygons: excludablePolygons,
          providerTag: 'valhalla-safe',
        );
        rawCandidates.addAll(safeValhalla);
      }
    }

    // 3. Score all gathered candidates so far
    var scored = _deduplicateCandidates(
      rawCandidates
          .map((c) => evaluateCandidateAgainstHazards(c, corridorHazards))
          .toList(),
    );

    // 4. Lateral waypoint detour fallback if best route STILL hits hazards (e.g. OSRM-only mode)
    if (avoidHazards &&
        scored.isNotEmpty &&
        scored.every((c) => c.hazardsOnRoute.isNotEmpty)) {
      final worstExposure = scored.first.hazardsOnRoute.first;
      final hazardPoint = worstExposure.hazard.location;
      if (hazardPoint != null) {
        final detourWaypoints = _computeLateralDetourWaypoints(
          origin: origin,
          destination: destination,
          hazardCenter: hazardPoint,
          offsetMeters: math.max(220.0, worstExposure.avoidanceRadiusMeters * 2.6),
        );
        final detourResults = await Future.wait<List<RouteCandidate>>(
          detourWaypoints.map(
            (via) => _fetchOsrmCandidates(
              origin: origin,
              destination: destination,
              viaPoint: via,
              travelMode: travelMode,
              providerTag: 'osrm-detour',
            ),
          ),
        );
        for (final list in detourResults) {
          rawCandidates.addAll(list);
        }
        scored = _deduplicateCandidates(
          rawCandidates
              .map((c) => evaluateCandidateAgainstHazards(c, corridorHazards))
              .toList(),
        );
      }
    }

    // 5. Offline / all-providers-unavailable graceful fallback
    if (scored.isEmpty) {
      final fallback = evaluateCandidateAgainstHazards(
        _buildOfflineFallbackRoute(
          origin: origin,
          originLabel: originLabel,
          destination: destination,
          destinationLabel: destinationLabel,
          travelMode: travelMode,
          avoidHazards: avoidHazards,
          corridorHazards: corridorHazards,
        ),
        corridorHazards,
      );
      scored = <RouteCandidate>[fallback];
    }

    // 6. Rank candidates according to `avoidHazards` preference
    final ranked = rankCandidates(scored, avoidHazards: avoidHazards);
    final primary = ranked.first;

    // Calculate how many hazards were avoided relative to the fastest direct road route
    final fastestDirect = List<RouteCandidate>.from(scored)
      ..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    final directHazardCount =
        fastestDirect.isNotEmpty ? fastestDirect.first.hazardsOnRoute.length : 0;
    final hazardsAvoided =
        math.max(0, directHazardCount - primary.hazardsOnRoute.length);

    return PlannedRouteResult(
      origin: origin,
      originLabel: originLabel,
      destination: destination,
      destinationLabel: destinationLabel,
      travelMode: travelMode,
      avoidHazards: avoidHazards,
      primaryRoute: primary,
      alternatives: ranked.take(3).toList(),
      corridorHazards: corridorHazards,
      hazardsAvoided: hazardsAvoided,
    );
  }

  /// Ranks evaluated candidates: prioritizes hazard-free roads when [avoidHazards] is true,
  /// or fastest travel time when [avoidHazards] is false.
  static List<RouteCandidate> rankCandidates(
    List<RouteCandidate> candidates, {
    required bool avoidHazards,
  }) {
    if (candidates.length <= 1) return List<RouteCandidate>.from(candidates);

    final shortestDistance =
        candidates.map((c) => c.distanceMeters).reduce(math.min);
    final maxReasonableDetour =
        math.max(shortestDistance * 3.8, shortestDistance + 6000.0);

    final sorted = List<RouteCandidate>.from(candidates);
    if (!avoidHazards) {
      sorted.sort((a, b) {
        final cmpDur = a.durationSeconds.compareTo(b.durationSeconds);
        if (cmpDur != 0) return cmpDur;
        final cmpCost = a.safetyWeightedCost.compareTo(b.safetyWeightedCost);
        if (cmpCost != 0) return cmpCost;
        return a.distanceMeters.compareTo(b.distanceMeters);
      });
      return sorted;
    }

    sorted.sort((a, b) {
      final aReasonable = a.distanceMeters <= maxReasonableDetour;
      final bReasonable = b.distanceMeters <= maxReasonableDetour;

      // Strictly prefer reasonable hazard-free roads over any road with active hazards
      if (a.hazardsOnRoute.isEmpty && b.hazardsOnRoute.isNotEmpty && aReasonable) {
        return -1;
      }
      if (b.hazardsOnRoute.isEmpty && a.hazardsOnRoute.isNotEmpty && bReasonable) {
        return 1;
      }

      // Otherwise compare safety-weighted cost (hazard penalty + road distance + traffic delay)
      final cmpCost = a.safetyWeightedCost.compareTo(b.safetyWeightedCost);
      if (cmpCost != 0) return cmpCost;
      return a.durationSeconds.compareTo(b.durationSeconds);
    });

    return sorted;
  }

  List<List<List<double>>> _selectExcludablePolygons({
    required LatLng origin,
    required LatLng destination,
    required List<HazardReportData> corridorHazards,
    required List<RouteCandidate> referenceRoutes,
  }) {
    const distCalc = Distance();
    final scoredHazards =
        <({HazardReportData report, double radius, double priority})>[];

    for (final h in corridorHazards) {
      final loc = h.location;
      if (loc == null || h.status != 'active') continue;
      final metrics = hazardMetricsForReport(h);
      final radius = metrics.avoidanceRadiusMeters;

      // Do not build an exclusion polygon that traps the origin or destination inside it
      if (distCalc.distance(origin, loc) <= radius + 35.0 ||
          distCalc.distance(destination, loc) <= radius + 35.0) {
        continue;
      }

      double minRouteDist = distCalc.distance(origin, loc);
      for (final r in referenceRoutes) {
        final d = pointToPolylineDistanceMeters(loc, r.polyline);
        if (d < minRouteDist) minRouteDist = d;
      }

      // Higher priority for hazards directly intersecting or close to candidate roads
      final proximityBoost = math.max(0.0, 1500.0 - minRouteDist);
      scoredHazards.add((
        report: h,
        radius: radius,
        priority: metrics.severityWeight * 10.0 + proximityBoost,
      ));
    }

    scoredHazards.sort((a, b) => b.priority.compareTo(a.priority));

    // Cap at 14 polygons so GET query URL stays compact (< 3 KB) across browsers
    return scoredHazards
        .take(14)
        .map((item) => buildHazardExclusionPolygon(item.report.location!, item.radius))
        .toList();
  }

  List<LatLng> _computeLateralDetourWaypoints({
    required LatLng origin,
    required LatLng destination,
    required LatLng hazardCenter,
    required double offsetMeters,
  }) {
    final latRad = hazardCenter.latitude * math.pi / 180.0;
    const metersPerDegLat = 111320.0;
    final metersPerDegLon =
        (111320.0 * math.cos(latRad)).abs().clamp(1.0, 111320.0);

    final dx = (destination.longitude - origin.longitude) * metersPerDegLon;
    final dy = (destination.latitude - origin.latitude) * metersPerDegLat;
    final len = math.sqrt(dx * dx + dy * dy);
    final ux = len > 1.0 ? -dy / len : 0.0;
    final uy = len > 1.0 ? dx / len : 1.0;

    return <LatLng>[
      LatLng(
        hazardCenter.latitude + (uy * offsetMeters) / metersPerDegLat,
        hazardCenter.longitude + (ux * offsetMeters) / metersPerDegLon,
      ),
      LatLng(
        hazardCenter.latitude - (uy * offsetMeters) / metersPerDegLat,
        hazardCenter.longitude - (ux * offsetMeters) / metersPerDegLon,
      ),
    ];
  }

  List<RouteCandidate> _deduplicateCandidates(List<RouteCandidate> list) {
    final unique = <RouteCandidate>[];
    for (final c in list) {
      if (c.polyline.length < 2) continue;
      final dupIdx = unique.indexWhere((existing) {
        final sameDist = (existing.distanceMeters - c.distanceMeters).abs() < 25.0;
        final sameHazards =
            existing.hazardsOnRoute.length == c.hazardsOnRoute.length;
        if (!sameDist || !sameHazards) return false;
        final midA = existing.polyline[existing.polyline.length ~/ 2];
        final midB = c.polyline[c.polyline.length ~/ 2];
        return const Distance().distance(midA, midB) < 35.0;
      });
      if (dupIdx == -1) {
        unique.add(c);
      } else if (c.trafficDelaySeconds > 0 || c.provider.contains('tomtom')) {
        // Upgrade duplicate with live traffic telemetry
        unique[dupIdx] = c;
      }
    }
    return unique;
  }

  // ---------------------------------------------------------------------------
  // VALHALLA ROUTING CLIENT (SUPPORTS GRAPH-LEVEL `exclude_polygons`)
  // ---------------------------------------------------------------------------

  Future<List<RouteCandidate>> _fetchValhallaCandidates({
    required LatLng origin,
    required LatLng destination,
    required RouteTravelMode travelMode,
    List<List<List<double>>> excludePolygons = const <List<List<double>>>[],
    String providerTag = 'valhalla',
  }) async {
    try {
      final payload = <String, dynamic>{
        'locations': <Map<String, double>>[
          <String, double>{'lat': origin.latitude, 'lon': origin.longitude},
          <String, double>{
            'lat': destination.latitude,
            'lon': destination.longitude,
          },
        ],
        'costing': travelMode.valhallaCosting,
        'alternates': 2,
        'directions_options': <String, String>{
          'units': 'kilometers',
          'language': 'en-US',
        },
        if (excludePolygons.isNotEmpty) 'exclude_polygons': excludePolygons,
      };

      final encodedJson = Uri.encodeQueryComponent(json.encode(payload));
      final uri = Uri.parse(
        'https://valhalla1.openstreetmap.de/route?json=$encodedJson',
      );

      final response =
          await _httpClient.get(uri).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return const <RouteCandidate>[];

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return const <RouteCandidate>[];

      final results = <RouteCandidate>[];
      final primaryTrip = decoded['trip'];
      if (primaryTrip is Map<String, dynamic>) {
        final parsed = _parseValhallaTrip(
          primaryTrip,
          id: '${providerTag}_0',
          provider: providerTag,
          usedHazardExclusion: excludePolygons.isNotEmpty,
        );
        if (parsed != null) results.add(parsed);
      }

      final alternates = decoded['alternates'];
      if (alternates is List) {
        for (int i = 0; i < alternates.length; i++) {
          final alt = alternates[i];
          if (alt is Map<String, dynamic> &&
              alt['trip'] is Map<String, dynamic>) {
            final parsed = _parseValhallaTrip(
              alt['trip'] as Map<String, dynamic>,
              id: '${providerTag}_alt_$i',
              provider: providerTag,
              usedHazardExclusion: excludePolygons.isNotEmpty,
            );
            if (parsed != null) results.add(parsed);
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('Valhalla routing note ($providerTag): $e');
      return const <RouteCandidate>[];
    }
  }

  RouteCandidate? _parseValhallaTrip(
    Map<String, dynamic> trip, {
    required String id,
    required String provider,
    required bool usedHazardExclusion,
  }) {
    final legs = trip['legs'];
    if (legs is! List || legs.isEmpty) return null;

    final fullPolyline = <LatLng>[];
    final allSteps = <RouteStep>[];
    final majorStreets = <String>[];
    double totalLengthKm = 0.0;
    double totalTimeSec = 0.0;

    for (final rawLeg in legs) {
      if (rawLeg is! Map<String, dynamic>) continue;
      final shapeStr = rawLeg['shape']?.toString() ?? '';
      final legPoly = decodePolyline(shapeStr, precision: 6);
      if (legPoly.isEmpty) continue;

      final polyOffset = fullPolyline.isEmpty ? 0 : fullPolyline.length - 1;
      if (fullPolyline.isEmpty) {
        fullPolyline.addAll(legPoly);
      } else {
        fullPolyline.addAll(legPoly.skip(1));
      }

      final legSummary = rawLeg['summary'];
      if (legSummary is Map<String, dynamic>) {
        totalLengthKm += (legSummary['length'] as num?)?.toDouble() ?? 0.0;
        totalTimeSec += (legSummary['time'] as num?)?.toDouble() ?? 0.0;
      }

      final maneuvers = rawLeg['maneuvers'];
      if (maneuvers is List) {
        for (final m in maneuvers) {
          if (m is! Map<String, dynamic>) continue;
          final beginIdx =
              ((m['begin_shape_index'] as num?)?.toInt() ?? 0) + polyOffset;
          final endIdx =
              ((m['end_shape_index'] as num?)?.toInt() ?? beginIdx) + polyOffset;
          final clampedBegin = beginIdx.clamp(0, fullPolyline.length - 1);
          final clampedEnd = endIdx.clamp(clampedBegin, fullPolyline.length - 1);

          final rawStreets = m['street_names'];
          String street = '';
          if (rawStreets is List && rawStreets.isNotEmpty) {
            street = rawStreets.first.toString().trim();
            if (street.isNotEmpty &&
                street.length > 2 &&
                !majorStreets.contains(street)) {
              majorStreets.add(street);
            }
          }

          final rawInstruction =
              m['instruction']?.toString().trim() ?? 'Continue straight';
          final cleanInstruction = rawInstruction.endsWith('.')
              ? rawInstruction.substring(0, rawInstruction.length - 1)
              : rawInstruction;

          final stepLengthMeters =
              ((m['length'] as num?)?.toDouble() ?? 0.0) * 1000.0;
          final stepTimeSeconds =
              ((m['time'] as num?)?.toDouble() ?? 0.0).round();
          final valhallaType = (m['type'] as num?)?.toInt() ?? 8;

          allSteps.add(
            RouteStep(
              index: allSteps.length,
              instruction: cleanInstruction,
              streetName: street,
              distanceMeters: stepLengthMeters,
              durationSeconds: stepTimeSeconds,
              maneuverType: _mapValhallaManeuverType(valhallaType),
              location: fullPolyline[clampedBegin],
              startPolylineIndex: clampedBegin,
              endPolylineIndex: clampedEnd,
            ),
          );
        }
      }
    }

    if (fullPolyline.length < 2) return null;

    final summary = majorStreets.isNotEmpty
        ? 'Via ${majorStreets.take(2).join(', ')}'
        : 'Recommended road route';

    return RouteCandidate(
      id: id,
      provider: provider,
      summary: summary,
      polyline: fullPolyline,
      steps: allSteps,
      distanceMeters: totalLengthKm * 1000.0,
      durationSeconds: totalTimeSec.round(),
      usedHazardExclusion: usedHazardExclusion,
    );
  }

  static ManeuverType _mapValhallaManeuverType(int type) {
    switch (type) {
      case 1:
      case 2:
      case 3:
        return ManeuverType.depart;
      case 4:
      case 5:
      case 6:
        return ManeuverType.arrive;
      case 9:
      case 23:
        return ManeuverType.slightRight;
      case 10:
        return ManeuverType.right;
      case 11:
        return ManeuverType.sharpRight;
      case 12:
      case 13:
        return ManeuverType.uTurn;
      case 14:
        return ManeuverType.sharpLeft;
      case 15:
        return ManeuverType.left;
      case 16:
      case 24:
        return ManeuverType.slightLeft;
      case 25:
        return ManeuverType.merge;
      case 26:
      case 27:
        return ManeuverType.roundabout;
      default:
        return ManeuverType.straight;
    }
  }

  // ---------------------------------------------------------------------------
  // FOSSGIS / PROJECT-OSRM ROUTING CLIENT
  // ---------------------------------------------------------------------------

  Future<List<RouteCandidate>> _fetchOsrmCandidates({
    required LatLng origin,
    required LatLng destination,
    LatLng? viaPoint,
    required RouteTravelMode travelMode,
    String providerTag = 'osrm',
  }) async {
    final coords = viaPoint != null
        ? '${origin.longitude},${origin.latitude};${viaPoint.longitude},${viaPoint.latitude};${destination.longitude},${destination.latitude}'
        : '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';

    final urls = <Uri>[
      Uri.parse(
        'https://routing.openstreetmap.de/${travelMode.fossgisServer}/route/v1/${travelMode.fossgisProfile}/$coords?overview=full&geometries=geojson&steps=true&alternatives=${viaPoint == null ? 'true' : 'false'}',
      ),
      Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson&steps=true&alternatives=${viaPoint == null ? 'true' : 'false'}',
      ),
    ];

    for (final uri in urls) {
      try {
        final response =
            await _httpClient.get(uri).timeout(const Duration(seconds: 6));
        if (response.statusCode != 200) continue;

        final decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic> || decoded['code'] != 'Ok') {
          continue;
        }
        final routes = decoded['routes'];
        if (routes is! List || routes.isEmpty) continue;

        final candidates = <RouteCandidate>[];
        for (int i = 0; i < routes.length; i++) {
          final r = routes[i];
          if (r is Map<String, dynamic>) {
            final parsed = _parseOsrmRoute(
              r,
              id: '${providerTag}_$i',
              provider: providerTag,
              travelMode: travelMode,
            );
            if (parsed != null) candidates.add(parsed);
          }
        }
        if (candidates.isNotEmpty) return candidates;
      } catch (e) {
        debugPrint('OSRM endpoint fallback ($uri): $e');
      }
    }
    return const <RouteCandidate>[];
  }

  RouteCandidate? _parseOsrmRoute(
    Map<String, dynamic> route, {
    required String id,
    required String provider,
    required RouteTravelMode travelMode,
  }) {
    final geom = route['geometry'];
    if (geom is! Map<String, dynamic>) return null;
    final coords = geom['coordinates'];
    if (coords is! List || coords.length < 2) return null;

    final polyline = <LatLng>[];
    for (final pt in coords) {
      if (pt is List && pt.length >= 2) {
        final lng = (pt[0] as num?)?.toDouble();
        final lat = (pt[1] as num?)?.toDouble();
        if (lat != null && lng != null) {
          polyline.add(LatLng(lat, lng));
        }
      }
    }
    if (polyline.length < 2) return null;

    final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final rawDuration = (route['duration'] as num?)?.toDouble() ?? 0.0;
    // Adjust duration if demo OSRM driving server was used as fallback for walking/cycling
    final durationSeconds = rawDuration > 0
        ? rawDuration.round()
        : (distanceMeters / travelMode.averageSpeedMps).round();

    final steps = <RouteStep>[];
    int cursorIdx = 0;
    final legs = route['legs'];
    if (legs is List) {
      for (final leg in legs) {
        if (leg is! Map<String, dynamic>) continue;
        final rawSteps = leg['steps'];
        if (rawSteps is! List) continue;

        for (final s in rawSteps) {
          if (s is! Map<String, dynamic>) continue;
          final maneuver =
              (s['maneuver'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
          final mType = maneuver['type']?.toString() ?? 'continue';
          final mMod = maneuver['modifier']?.toString() ?? '';
          final streetName = s['name']?.toString().trim() ?? '';
          final stepDist = (s['distance'] as num?)?.toDouble() ?? 0.0;
          final stepDur = ((s['duration'] as num?)?.toDouble() ?? 0.0).round();

          LatLng stepLoc = polyline[cursorIdx.clamp(0, polyline.length - 1)];
          final rawLoc = maneuver['location'];
          if (rawLoc is List && rawLoc.length >= 2) {
            final lon = (rawLoc[0] as num?)?.toDouble();
            final lat = (rawLoc[1] as num?)?.toDouble();
            if (lat != null && lon != null) {
              stepLoc = LatLng(lat, lon);
            }
          }

          int stepCoordCount = 1;
          final stepGeom = s['geometry'];
          if (stepGeom is Map<String, dynamic> &&
              stepGeom['coordinates'] is List) {
            stepCoordCount = math.max(
              1,
              (stepGeom['coordinates'] as List).length - 1,
            );
          }
          final startIdx = cursorIdx.clamp(0, polyline.length - 1);
          final endIdx =
              (cursorIdx + stepCoordCount).clamp(startIdx, polyline.length - 1);
          cursorIdx = endIdx;

          final mappedType = _mapOsrmManeuver(mType, mMod);
          final instruction = _buildOsrmInstruction(
            mType,
            mMod,
            streetName,
            travelMode,
          );

          steps.add(
            RouteStep(
              index: steps.length,
              instruction: instruction,
              streetName: streetName,
              distanceMeters: stepDist,
              durationSeconds: stepDur,
              maneuverType: mappedType,
              location: stepLoc,
              startPolylineIndex: startIdx,
              endPolylineIndex: endIdx,
            ),
          );
        }
      }
    }

    final rawSummary = route['summary']?.toString().trim() ?? '';
    final summary =
        rawSummary.isNotEmpty ? 'Via $rawSummary' : 'Recommended road route';

    return RouteCandidate(
      id: id,
      provider: provider,
      summary: summary,
      polyline: polyline,
      steps: steps,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  static ManeuverType _mapOsrmManeuver(String type, String modifier) {
    final t = type.toLowerCase();
    final m = modifier.toLowerCase();
    if (t == 'depart') return ManeuverType.depart;
    if (t == 'arrive') return ManeuverType.arrive;
    if (t.contains('roundabout') || t == 'rotary') {
      return ManeuverType.roundabout;
    }
    if (t == 'merge') return ManeuverType.merge;
    if (m.contains('uturn')) return ManeuverType.uTurn;
    if (m == 'sharp left') return ManeuverType.sharpLeft;
    if (m == 'left') return ManeuverType.left;
    if (m == 'slight left') return ManeuverType.slightLeft;
    if (m == 'sharp right') return ManeuverType.sharpRight;
    if (m == 'right') return ManeuverType.right;
    if (m == 'slight right') return ManeuverType.slightRight;
    return ManeuverType.straight;
  }

  static String _buildOsrmInstruction(
    String type,
    String modifier,
    String street,
    RouteTravelMode mode,
  ) {
    final verb = mode == RouteTravelMode.walking
        ? 'Walk'
        : (mode == RouteTravelMode.cycling ? 'Ride' : 'Drive');
    final target = street.isNotEmpty ? ' onto $street' : '';
    final onTarget = street.isNotEmpty ? ' on $street' : '';
    final t = type.toLowerCase();
    final m = modifier.toLowerCase();

    if (t == 'depart') {
      return '$verb${m.isNotEmpty ? ' $m' : ''}$onTarget'.trim();
    }
    if (t == 'arrive') {
      return street.isNotEmpty
          ? 'Arrive at destination near $street'
          : 'Arrive at your destination';
    }
    if (t.contains('roundabout') || t == 'rotary') {
      return 'Enter roundabout and continue$target';
    }
    if (m.contains('uturn')) {
      return 'Make a U-turn$target';
    }
    if (m.contains('left') || m.contains('right')) {
      final capMod = m[0].toUpperCase() + m.substring(1);
      if (m.startsWith('slight') || m.startsWith('sharp')) {
        return 'Turn $m$target';
      }
      return 'Turn $m$target'
          .replaceFirst('Turn Left', 'Turn left')
          .replaceFirst('Turn Right', 'Turn right')
          .isEmpty
          ? capMod
          : 'Turn $m$target';
    }
    return street.isNotEmpty ? 'Continue onto $street' : 'Continue straight';
  }

  // ---------------------------------------------------------------------------
  // TOMTOM ROUTING CLIENT (REAL-TIME TRAFFIC DELAY & CONGESTION AWARE)
  // ---------------------------------------------------------------------------

  Future<List<RouteCandidate>> _fetchTomTomCandidates({
    required LatLng origin,
    required LatLng destination,
    required RouteTravelMode travelMode,
    String providerTag = 'tomtom-live-traffic',
  }) async {
    final key = tomtomApiKey;
    if (key.isEmpty) return const <RouteCandidate>[];

    String modeParam;
    switch (travelMode) {
      case RouteTravelMode.driving:
        modeParam = 'car';
        break;
      case RouteTravelMode.cycling:
        modeParam = 'bicycle';
        break;
      case RouteTravelMode.walking:
        modeParam = 'pedestrian';
        break;
    }

    final uri = Uri.parse(
      'https://api.tomtom.com/routing/1/calculateRoute/'
      '${origin.latitude},${origin.longitude}:${destination.latitude},${destination.longitude}/json'
      '?key=$key&traffic=true&travelMode=$modeParam&maxAlternatives=2&instructionsType=text',
    );

    try {
      final response = await _httpClient
          .get(
            uri,
            headers: const {'User-Agent': 'SafeRoute-App/1.0 (Flutter)'},
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) {
        return const <RouteCandidate>[];
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const <RouteCandidate>[];
      }

      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return const <RouteCandidate>[];
      }

      final results = <RouteCandidate>[];
      for (var i = 0; i < routes.length; i++) {
        final r = routes[i];
        if (r is! Map<String, dynamic>) continue;
        final cand = _parseTomTomRoute(
          r,
          index: i,
          travelMode: travelMode,
          providerTag: providerTag,
        );
        if (cand != null) {
          results.add(cand);
        }
      }
      return results;
    } catch (_) {
      return const <RouteCandidate>[];
    }
  }

  RouteCandidate? _parseTomTomRoute(
    Map<String, dynamic> routeJson, {
    required int index,
    required RouteTravelMode travelMode,
    required String providerTag,
  }) {
    final summary = routeJson['summary'] as Map<String, dynamic>? ?? {};
    final lengthMeters = (summary['lengthInMeters'] as num?)?.toDouble() ?? 0.0;
    final travelTimeSeconds =
        (summary['travelTimeInSeconds'] as num?)?.toInt() ?? 0;
    final trafficDelaySeconds =
        (summary['trafficDelayInSeconds'] as num?)?.toInt() ?? 0;

    final legs = routeJson['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return null;
    final firstLeg = legs[0] as Map<String, dynamic>? ?? {};
    final rawPoints = firstLeg['points'] as List<dynamic>?;
    if (rawPoints == null || rawPoints.length < 2) return null;

    final polyline = <LatLng>[];
    for (final pt in rawPoints) {
      if (pt is Map<String, dynamic>) {
        final lat = (pt['latitude'] as num?)?.toDouble();
        final lng = (pt['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          polyline.add(LatLng(lat, lng));
        }
      }
    }
    if (polyline.length < 2) return null;

    final guidance = routeJson['guidance'] as Map<String, dynamic>? ?? {};
    final rawInstructions = guidance['instructions'] as List<dynamic>? ?? [];

    final steps = <RouteStep>[];
    final streetNames = <String>{};

    for (var i = 0; i < rawInstructions.length; i++) {
      final item = rawInstructions[i] as Map<String, dynamic>?;
      if (item == null) continue;

      final instructionMsg = item['message']?.toString() ?? 'Continue';
      final street = item['street']?.toString() ?? '';
      if (street.isNotEmpty) streetNames.add(street);

      final ptMap = item['point'] as Map<String, dynamic>?;
      final stepLat = (ptMap?['latitude'] as num?)?.toDouble() ??
          polyline.first.latitude;
      final stepLng = (ptMap?['longitude'] as num?)?.toDouble() ??
          polyline.first.longitude;

      final maneuverStr = item['maneuver']?.toString() ?? '';
      final maneuverType = _parseTomTomManeuver(maneuverStr);

      final pointIdx = (item['pointIndex'] as num?)?.toInt() ?? 0;
      final clampedIdx = pointIdx.clamp(0, polyline.length - 1);

      final stepDuration = (item['travelTimeInSeconds'] as num?)?.toInt() ?? 0;
      final nextInstruction = (i + 1 < rawInstructions.length)
          ? rawInstructions[i + 1] as Map<String, dynamic>?
          : null;
      final nextOffset =
          (nextInstruction?['routeOffsetInMeters'] as num?)?.toDouble();
      final currOffset =
          (item['routeOffsetInMeters'] as num?)?.toDouble() ?? 0.0;
      final stepDist = (nextOffset != null && nextOffset >= currOffset)
          ? (nextOffset - currOffset)
          : 0.0;

      final nextPointIdx =
          (nextInstruction?['pointIndex'] as num?)?.toInt() ?? polyline.length - 1;

      steps.add(
        RouteStep(
          index: i,
          instruction: instructionMsg,
          streetName: street,
          distanceMeters: stepDist,
          durationSeconds: stepDuration,
          maneuverType: maneuverType,
          location: LatLng(stepLat, stepLng),
          startPolylineIndex: clampedIdx,
          endPolylineIndex: nextPointIdx.clamp(clampedIdx, polyline.length - 1),
        ),
      );
    }

    String routeSummary;
    if (streetNames.isNotEmpty) {
      final names = streetNames.take(2).toList();
      routeSummary = 'Via ${names.join(", ")}';
    } else {
      routeSummary = index == 0
          ? 'Main road (live traffic)'
          : 'Alternative route ${index + 1}';
    }

    return RouteCandidate(
      id: 'tomtom_${DateTime.now().microsecondsSinceEpoch}_$index',
      provider: providerTag,
      summary: routeSummary,
      polyline: polyline,
      steps: steps,
      distanceMeters: lengthMeters,
      durationSeconds: travelTimeSeconds,
      trafficDelaySeconds: trafficDelaySeconds,
    );
  }

  static ManeuverType _parseTomTomManeuver(String maneuver) {
    final m = maneuver.toUpperCase();
    if (m.contains('DEPART')) return ManeuverType.depart;
    if (m.contains('ARRIVE')) return ManeuverType.arrive;
    if (m.contains('SHARP_LEFT')) return ManeuverType.sharpLeft;
    if (m.contains('BEAR_LEFT') || m.contains('SLIGHT_LEFT')) {
      return ManeuverType.slightLeft;
    }
    if (m.contains('LEFT')) return ManeuverType.left;
    if (m.contains('SHARP_RIGHT')) return ManeuverType.sharpRight;
    if (m.contains('BEAR_RIGHT') || m.contains('SLIGHT_RIGHT')) {
      return ManeuverType.slightRight;
    }
    if (m.contains('RIGHT')) return ManeuverType.right;
    if (m.contains('UTURN') || m.contains('U_TURN')) return ManeuverType.uTurn;
    if (m.contains('ROUNDABOUT')) return ManeuverType.roundabout;
    if (m.contains('MERGE') || m.contains('MOTORWAY')) return ManeuverType.merge;
    return ManeuverType.straight;
  }

  RouteCandidate _buildOfflineFallbackRoute({
    required LatLng origin,
    required String originLabel,
    required LatLng destination,
    required String destinationLabel,
    required RouteTravelMode travelMode,
    required bool avoidHazards,
    required List<HazardReportData> corridorHazards,
  }) {
    const distCalc = Distance();
    List<LatLng> poly = <LatLng>[origin, destination];

    if (avoidHazards && corridorHazards.isNotEmpty) {
      for (final h in corridorHazards) {
        if (h.location == null) continue;
        final metrics = hazardMetricsForReport(h);
        if (pointToSegmentDistanceMeters(h.location!, origin, destination) <=
            metrics.avoidanceRadiusMeters) {
          final detours = _computeLateralDetourWaypoints(
            origin: origin,
            destination: destination,
            hazardCenter: h.location!,
            offsetMeters: metrics.avoidanceRadiusMeters * 2.2,
          );
          // Pick whichever detour waypoint stays farthest from all hazards
          LatLng bestVia = detours.first;
          double bestClearance = -1;
          for (final via in detours) {
            final trial = <LatLng>[origin, via, destination];
            double minClearance = double.infinity;
            for (final other in corridorHazards) {
              if (other.location == null) continue;
              final c = pointToPolylineDistanceMeters(other.location!, trial);
              if (c < minClearance) minClearance = c;
            }
            if (minClearance > bestClearance) {
              bestClearance = minClearance;
              bestVia = via;
            }
          }
          poly = <LatLng>[origin, bestVia, destination];
          break;
        }
      }
    }

    double totalDist = 0.0;
    for (int i = 0; i < poly.length - 1; i++) {
      totalDist += distCalc.distance(poly[i], poly[i + 1]);
    }
    final totalSec =
        math.max(60, (totalDist / travelMode.averageSpeedMps).round());

    final steps = <RouteStep>[
      RouteStep(
        index: 0,
        instruction: 'Head from $originLabel toward $destinationLabel',
        streetName: originLabel,
        distanceMeters: poly.length == 3
            ? distCalc.distance(poly[0], poly[1])
            : totalDist,
        durationSeconds: poly.length == 3 ? (totalSec ~/ 2) : totalSec,
        maneuverType: ManeuverType.depart,
        location: origin,
        startPolylineIndex: 0,
        endPolylineIndex: 1,
      ),
      if (poly.length == 3)
        RouteStep(
          index: 1,
          instruction: 'Continue along safe detour toward $destinationLabel',
          streetName: destinationLabel,
          distanceMeters: distCalc.distance(poly[1], poly[2]),
          durationSeconds: totalSec - (totalSec ~/ 2),
          maneuverType: ManeuverType.slightRight,
          location: poly[1],
          startPolylineIndex: 1,
          endPolylineIndex: 2,
        ),
      RouteStep(
        index: poly.length == 3 ? 2 : 1,
        instruction: 'Arrive at $destinationLabel',
        streetName: destinationLabel,
        distanceMeters: 0,
        durationSeconds: 0,
        maneuverType: ManeuverType.arrive,
        location: destination,
        startPolylineIndex: poly.length - 1,
        endPolylineIndex: poly.length - 1,
      ),
    ];

    return RouteCandidate(
      id: 'offline_fallback',
      provider: 'fallback',
      summary: poly.length == 3
          ? 'Offline safe detour route'
          : 'Offline direct route',
      polyline: poly,
      steps: steps,
      distanceMeters: totalDist,
      durationSeconds: totalSec,
      usedHazardExclusion: poly.length == 3,
    );
  }

  // ---------------------------------------------------------------------------
  // SAVED ROUTES & NAVIGATION SESSIONS (SUPABASE + LOCAL CACHE)
  // ---------------------------------------------------------------------------

  Future<List<SavedRouteRecord>> fetchSavedRoutes({
    List<HazardReportData>? activeHazards,
  }) async {
    final hazards = activeHazards ??
        await _hazardReportService.fetchReports(limit: 120, activeOnly: true);
    final sb = _tryGetSupabase();
    final user = sb?.auth.currentUser;

    if (sb != null && user != null) {
      try {
        final dynamic rows = await sb
            .from('saved_routes')
            .select()
            .eq('user_id', user.id)
            .order('updated_at', ascending: false)
            .limit(30);
        if (rows is List) {
          final parsed = rows
              .whereType<Map>()
              .map(
                (r) => SavedRouteRecord.fromJson(
                  Map<String, dynamic>.from(r),
                ).withLiveHazards(hazards),
              )
              .toList();
          await _writeLocalSavedRoutes(parsed);
          return parsed;
        }
      } catch (e) {
        debugPrint('Warning: fetchSavedRoutes DB query fell back to cache: $e');
      }
    }

    final cached = await _readLocalSavedRoutes();
    return cached.map((r) => r.withLiveHazards(hazards)).toList();
  }

  Future<SavedRouteRecord> savePlannedRoute({
    required PlannedRouteResult planned,
    String? customTitle,
  }) async {
    final defaultTitle =
        '${_shortenPlace(planned.originLabel)} to ${_shortenPlace(planned.destinationLabel)}';
    final effectiveTitle =
        (customTitle != null && customTitle.trim().isNotEmpty)
            ? customTitle.trim()
            : defaultTitle;

    final now = DateTime.now();
    final sb = _tryGetSupabase();
    final user = sb?.auth.currentUser;
    final routeId = planned.savedRouteId ?? generateUuidV4();

    final record = SavedRouteRecord(
      id: routeId,
      userId: user?.id,
      title: effectiveTitle,
      originLabel: planned.originLabel,
      origin: planned.origin,
      destinationLabel: planned.destinationLabel,
      destination: planned.destination,
      travelMode: planned.travelMode,
      avoidHazards: planned.avoidHazards,
      distanceMeters: planned.primaryRoute.distanceMeters,
      durationSeconds: planned.primaryRoute.durationSeconds,
      hazardCount: planned.primaryRoute.hazardsOnRoute.length,
      riskLevel: planned.primaryRoute.riskLevel,
      routeSummary: planned.primaryRoute.summary,
      polyline: planned.primaryRoute.polyline,
      steps: planned.primaryRoute.steps,
      isFavorite: true,
      lastUsedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    if (sb != null && user != null) {
      try {
        final inserted = await sb
            .from('saved_routes')
            .upsert(record.toDbPayload(user.id))
            .select()
            .single();
        final persisted = SavedRouteRecord.fromJson(inserted);
        await _upsertLocalSavedRoute(persisted);
        return persisted;
      } catch (e) {
        debugPrint('Warning: savePlannedRoute persisted to local cache: $e');
      }
    }

    await _upsertLocalSavedRoute(record);
    return record;
  }

  Future<void> renameSavedRoute(String id, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    final sb = _tryGetSupabase();
    final user = sb?.auth.currentUser;
    if (sb != null && user != null) {
      try {
        await sb
            .from('saved_routes')
            .update(<String, dynamic>{'title': trimmed})
            .eq('id', id)
            .eq('user_id', user.id);
      } catch (e) {
        debugPrint('Warning: renameSavedRoute DB error: $e');
      }
    }

    final existing = await _readLocalSavedRoutes();
    final updated = existing.map((r) {
      if (r.id != id) return r;
      return SavedRouteRecord(
        id: r.id,
        userId: r.userId,
        title: trimmed,
        originLabel: r.originLabel,
        origin: r.origin,
        destinationLabel: r.destinationLabel,
        destination: r.destination,
        travelMode: r.travelMode,
        avoidHazards: r.avoidHazards,
        distanceMeters: r.distanceMeters,
        durationSeconds: r.durationSeconds,
        hazardCount: r.hazardCount,
        riskLevel: r.riskLevel,
        routeSummary: r.routeSummary,
        polyline: r.polyline,
        steps: r.steps,
        isFavorite: r.isFavorite,
        lastUsedAt: r.lastUsedAt,
        createdAt: r.createdAt,
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _writeLocalSavedRoutes(updated);
  }

  Future<void> deleteSavedRoute(String id) async {
    final sb = _tryGetSupabase();
    final user = sb?.auth.currentUser;
    if (sb != null && user != null) {
      try {
        await sb
            .from('saved_routes')
            .delete()
            .eq('id', id)
            .eq('user_id', user.id);
      } catch (e) {
        debugPrint('Warning: deleteSavedRoute DB error: $e');
      }
    }
    final existing = await _readLocalSavedRoutes();
    existing.removeWhere((r) => r.id == id);
    await _writeLocalSavedRoutes(existing);
  }

  Future<String?> startNavigationSession(PlannedRouteResult planned) async {
    final sb = _tryGetSupabase();
    final user = sb?.auth.currentUser;
    if (sb == null || user == null) return null;

    try {
      if (planned.savedRouteId != null && planned.savedRouteId!.isNotEmpty) {
        unawaited(
          sb
              .from('saved_routes')
              .update(<String, dynamic>{
                'last_used_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', planned.savedRouteId!)
              .eq('user_id', user.id)
              .then((_) {}, onError: (_) {}),
        );
      }

      final inserted = await sb
          .from('navigation_sessions')
          .insert(<String, dynamic>{
            'user_id': user.id,
            if (planned.savedRouteId != null &&
                planned.savedRouteId!.isNotEmpty)
              'saved_route_id': planned.savedRouteId,
            'origin_label': planned.originLabel,
            'origin_lat': planned.origin.latitude,
            'origin_lng': planned.origin.longitude,
            'destination_label': planned.destinationLabel,
            'destination_lat': planned.destination.latitude,
            'destination_lng': planned.destination.longitude,
            'travel_mode': planned.travelMode.dbValue,
            'avoid_hazards': planned.avoidHazards,
            'distance_meters': planned.primaryRoute.distanceMeters,
            'duration_seconds': planned.primaryRoute.durationSeconds,
            'hazards_avoided': planned.hazardsAvoided,
            'hazards_on_route': planned.primaryRoute.hazardsOnRoute.length,
            'status': 'active',
          })
          .select('id')
          .maybeSingle();

      return inserted?['id']?.toString();
    } catch (e) {
      debugPrint('Warning: startNavigationSession DB error: $e');
      return null;
    }
  }

  Future<void> recordNavigationReroute(
    String? sessionId, {
    required int rerouteCount,
    required int hazardsAvoided,
    required int hazardsOnRoute,
  }) async {
    if (sessionId == null || sessionId.isEmpty) return;
    final sb = _tryGetSupabase();
    final user = sb?.auth.currentUser;
    if (sb == null || user == null) return;

    try {
      await sb
          .from('navigation_sessions')
          .update(<String, dynamic>{
            'reroute_count': rerouteCount,
            'hazards_avoided': hazardsAvoided,
            'hazards_on_route': hazardsOnRoute,
          })
          .eq('id', sessionId)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('Warning: recordNavigationReroute DB error: $e');
    }
  }

  Future<void> finishNavigationSession(
    String? sessionId, {
    required bool completed,
  }) async {
    if (sessionId == null || sessionId.isEmpty) return;
    final sb = _tryGetSupabase();
    final user = sb?.auth.currentUser;
    if (sb == null || user == null) return;

    try {
      await sb
          .from('navigation_sessions')
          .update(<String, dynamic>{
            'status': completed ? 'completed' : 'cancelled',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', sessionId)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('Warning: finishNavigationSession DB error: $e');
    }
  }

  static String _shortenPlace(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Place';
    if (trimmed.toLowerCase() == 'your current location' ||
        trimmed.toLowerCase() == 'current location') {
      return 'Current Location';
    }
    final firstSegment = trimmed.split(',').first.trim();
    return firstSegment.length > 36
        ? '${firstSegment.substring(0, 33)}...'
        : firstSegment;
  }

  Future<List<SavedRouteRecord>> _readLocalSavedRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localSavedRoutesKey);
      if (raw == null || raw.isEmpty) return <SavedRouteRecord>[];
      final decoded = json.decode(raw);
      if (decoded is! List) return <SavedRouteRecord>[];
      return decoded
          .whereType<Map>()
          .map((m) => SavedRouteRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return <SavedRouteRecord>[];
    }
  }

  Future<void> _writeLocalSavedRoutes(List<SavedRouteRecord> routes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localSavedRoutesKey,
        json.encode(routes.take(30).map((r) => r.toLocalCacheJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _upsertLocalSavedRoute(SavedRouteRecord route) async {
    final existing = await _readLocalSavedRoutes();
    existing.removeWhere((r) => r.id == route.id);
    existing.insert(0, route);
    await _writeLocalSavedRoutes(existing);
  }
}
