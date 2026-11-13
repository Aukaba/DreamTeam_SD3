import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cebu_landmark_service.dart';
import 'hazard_report_service.dart';

/// Timeframe windows supported on the full Admin Analytics screen.
enum AnalyticsTimeframe {
  sevenDays('7D', 'Last 7 days'),
  thirtyDays('30D', 'Last 30 days'),
  allTime('ALL', 'All time');

  final String shortLabel;
  final String displayLabel;

  const AnalyticsTimeframe(this.shortLabel, this.displayLabel);
}

/// Normalized hazard severity buckets matching SafeRoute routing risk weights.
enum HazardSeverityBucket {
  high('High'),
  medium('Medium'),
  low('Low');

  final String label;
  const HazardSeverityBucket(this.label);

  static HazardSeverityBucket parse(String? raw) {
    final norm = raw?.trim().toLowerCase() ?? '';
    if (norm.contains('high') ||
        norm.contains('critical') ||
        norm.contains('severe')) {
      return HazardSeverityBucket.high;
    }
    if (norm.contains('med') || norm.contains('mod')) {
      return HazardSeverityBucket.medium;
    }
    return HazardSeverityBucket.low;
  }
}

/// Aggregated statistics for a single hazard category (e.g., Flooding, Road Blockage).
class HazardCategoryStat {
  final String category;
  final int totalCount;
  final int activeCount;
  final int resolvedCount;
  final int highSeverityCount;
  final double share;

  const HazardCategoryStat({
    required this.category,
    required this.totalCount,
    required this.activeCount,
    required this.resolvedCount,
    required this.highSeverityCount,
    required this.share,
  });
}

/// Real hotspot area ranked by active & high-severity hazards from `location_address`.
class HazardHotspotStat {
  final String areaLabel;
  final int totalCount;
  final int activeCount;
  final int highSeverityCount;
  final String topCategory;

  const HazardHotspotStat({
    required this.areaLabel,
    required this.totalCount,
    required this.activeCount,
    required this.highSeverityCount,
    required this.topCategory,
  });
}

/// Single day bucket for the 7-day intake vs. resolution velocity chart.
class DailyTrendBucket {
  final DateTime date;
  final String dayLabel;
  final int reportedCount;
  final int resolvedCount;

  const DailyTrendBucket({
    required this.date,
    required this.dayLabel,
    required this.reportedCount,
    required this.resolvedCount,
  });
}

/// Comprehensive operational and safety analytics computed from `ReportTable`
/// and `hazard_resolution_reports`.
class AdminSafetyAnalytics {
  final AnalyticsTimeframe timeframe;
  final DateTime generatedAt;

  // Live current operational snapshot (always across current active/pending queues)
  final int totalReportsAllTime;
  final int activeHazardsCount;
  final int activeHighCount;
  final int activeMediumCount;
  final int activeLowCount;
  final int pendingReportsCount;
  final int pendingResolutionProofsCount;
  final int resolvedReportsAllTime;
  final int rejectedOrArchivedAllTime;

  // Scoped metrics (respecting selected [timeframe])
  final int scopedReportsCount;
  final int scopedActiveCount;
  final int scopedPendingCount;
  final int scopedResolvedCount;
  final int scopedRejectedCount;

  // Actionable health & SLA turnaround metrics
  final double resolutionRate;
  final bool hasResolutionDenominator;
  final double signalApprovalRate;
  final bool hasSignalDenominator;
  final int? medianVerifyMinutes;
  final double? medianResolutionHours;

  // AI detection confidence distribution (from Gemini hazard analysis)
  final int? averageAiConfidence;
  final int highConfidenceCount;
  final int mediumConfidenceCount;
  final int lowConfidenceCount;

  // Community resolution proof breakdown (hazard_resolution_reports)
  final int resolutionProofsApproved;
  final int resolutionProofsPending;
  final int resolutionProofsRejected;

  // Ranked lists & 7-day velocity
  final List<HazardCategoryStat> topCategories;
  final List<HazardHotspotStat> topHotspots;
  final List<DailyTrendBucket> last7DaysTrend;

  const AdminSafetyAnalytics({
    required this.timeframe,
    required this.generatedAt,
    required this.totalReportsAllTime,
    required this.activeHazardsCount,
    required this.activeHighCount,
    required this.activeMediumCount,
    required this.activeLowCount,
    required this.pendingReportsCount,
    required this.pendingResolutionProofsCount,
    required this.resolvedReportsAllTime,
    required this.rejectedOrArchivedAllTime,
    required this.scopedReportsCount,
    required this.scopedActiveCount,
    required this.scopedPendingCount,
    required this.scopedResolvedCount,
    required this.scopedRejectedCount,
    required this.resolutionRate,
    required this.hasResolutionDenominator,
    required this.signalApprovalRate,
    required this.hasSignalDenominator,
    required this.medianVerifyMinutes,
    required this.medianResolutionHours,
    required this.averageAiConfidence,
    required this.highConfidenceCount,
    required this.mediumConfidenceCount,
    required this.lowConfidenceCount,
    required this.resolutionProofsApproved,
    required this.resolutionProofsPending,
    required this.resolutionProofsRejected,
    required this.topCategories,
    required this.topHotspots,
    required this.last7DaysTrend,
  });

  factory AdminSafetyAnalytics.empty({
    AnalyticsTimeframe timeframe = AnalyticsTimeframe.allTime,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    return AdminSafetyAnalytics.fromRawData(
      reports: const <Map<String, dynamic>>[],
      resolutions: const <Map<String, dynamic>>[],
      timeframe: timeframe,
      now: current,
    );
  }

  int get totalActionQueue =>
      pendingReportsCount + pendingResolutionProofsCount;

  int get resolutionRatePercent =>
      hasResolutionDenominator ? (resolutionRate * 100).round() : 0;

  int get signalApprovalPercent =>
      hasSignalDenominator ? (signalApprovalRate * 100).round() : 0;

  int get sevenDayReportedTotal => last7DaysTrend.fold<int>(
        0,
        (sum, b) => sum + b.reportedCount,
      );

  int get sevenDayResolvedTotal => last7DaysTrend.fold<int>(
        0,
        (sum, b) => sum + b.resolvedCount,
      );

  String get overallRiskLabel {
    if (activeHazardsCount == 0) return 'All Clear';
    if (activeHighCount >= 3 || activeHazardsCount >= 10) {
      return 'High Alert';
    }
    if (activeHighCount >= 1 || activeMediumCount >= 3) {
      return 'Elevated Risk';
    }
    return 'Low Risk';
  }

  String get formattedMedianVerify {
    final mins = medianVerifyMinutes;
    if (mins == null) return '—';
    if (mins < 60) return '${mins}m';
    final hours = mins / 60.0;
    if (hours < 24) return '${hours.toStringAsFixed(1)}h';
    final days = hours / 24.0;
    return '${days.toStringAsFixed(1)}d';
  }

  String get formattedMedianClear {
    final hours = medianResolutionHours;
    if (hours == null) return '—';
    if (hours < 1.0) {
      final mins = (hours * 60).round().clamp(1, 59);
      return '${mins}m';
    }
    if (hours < 24.0) return '${hours.toStringAsFixed(1)}h';
    final days = hours / 24.0;
    return '${days.toStringAsFixed(1)}d';
  }

  /// Builds complete analytics deterministically from raw Supabase rows.
  factory AdminSafetyAnalytics.fromRawData({
    required List<Map<String, dynamic>> reports,
    List<Map<String, dynamic>> resolutions = const <Map<String, dynamic>>[],
    AnalyticsTimeframe timeframe = AnalyticsTimeframe.allTime,
    DateTime? now,
  }) {
    final current = (now ?? DateTime.now()).toLocal();
    final todayStart = DateTime(current.year, current.month, current.day);

    DateTime? cutoff;
    if (timeframe == AnalyticsTimeframe.sevenDays) {
      cutoff = todayStart.subtract(const Duration(days: 6));
    } else if (timeframe == AnalyticsTimeframe.thirtyDays) {
      cutoff = todayStart.subtract(const Duration(days: 29));
    }

    int activeAll = 0;
    int activeHigh = 0;
    int activeMedium = 0;
    int activeLow = 0;
    int pendingReports = 0;
    int fallbackPendingResolutions = 0;
    int resolvedAll = 0;
    int rejectedOrArchivedAll = 0;

    int scopedTotal = 0;
    int scopedActive = 0;
    int scopedPending = 0;
    int scopedResolved = 0;
    int scopedRejected = 0;

    final List<int> verifyMinutesList = <int>[];
    final List<double> resolutionHoursList = <double>[];
    final List<int> confidenceValues = <int>[];
    int highConf = 0;
    int medConf = 0;
    int lowConf = 0;

    final Map<String, _CategoryAccumulator> categoryAcc =
        <String, _CategoryAccumulator>{};
    final Map<String, _HotspotAccumulator> hotspotAcc =
        <String, _HotspotAccumulator>{};
    final Set<String> seenActiveIncidentKeys = <String>{};
    final Set<String> seenScopedActiveKeys = <String>{};

    // Prepare 7-day trend buckets ([today - 6] through [today])
    final List<DateTime> trendDates = List<DateTime>.generate(
      7,
      (i) => todayStart.subtract(Duration(days: 6 - i)),
    );
    final List<int> dailyReported = List<int>.filled(7, 0);
    final List<int> dailyResolved = List<int>.filled(7, 0);

    for (final row in reports) {
      final status = HazardReportStatuses.normalize(
        row['status']?.toString(),
        defaultStatus: HazardReportStatuses.pending,
      );
      final severity = HazardSeverityBucket.parse(
        row['severity_level']?.toString(),
      );
      final createdAt = _parseLocalDateTime(row['created_at']);
      final verifiedAt = _parseLocalDateTime(row['verified_at']);
      final resolvedAt = _parseLocalDateTime(row['resolved_at']);
      final double? lat = _parseCoordinate(row['latitude']);
      final double? lng = _parseCoordinate(row['longitude']);

      String? activeSpotKey;
      if (status == HazardReportStatuses.active && lat != null && lng != null) {
        final rawCat =
            (row['hazard_category']?.toString().trim().isNotEmpty == true)
                ? row['hazard_category'].toString()
                : (row['detected_hazard']?.toString() ?? 'Other');
        activeSpotKey = HazardReportService.duplicateLocationKey(
          category: rawCat,
          latitude: lat,
          longitude: lng,
        );
      }

      // All-time / live queue counts (deduplicated per active spot on map)
      if (status == HazardReportStatuses.active) {
        final bool isUniqueActiveIncident =
            activeSpotKey == null || seenActiveIncidentKeys.add(activeSpotKey);
        if (isUniqueActiveIncident) {
          activeAll++;
          switch (severity) {
            case HazardSeverityBucket.high:
              activeHigh++;
              break;
            case HazardSeverityBucket.medium:
              activeMedium++;
              break;
            case HazardSeverityBucket.low:
              activeLow++;
              break;
          }
        }
        final resStatus =
            row['resolution_status']?.toString().trim().toLowerCase() ?? '';
        if (resStatus == 'pending') {
          fallbackPendingResolutions++;
        }
      } else if (status == HazardReportStatuses.pending) {
        pendingReports++;
      } else if (status == HazardReportStatuses.resolved) {
        resolvedAll++;
      } else if (status == HazardReportStatuses.rejected ||
          status == HazardReportStatuses.archived) {
        rejectedOrArchivedAll++;
      }

      // 7-day daily intake & clearance velocity
      if (createdAt != null) {
        final createdDay =
            DateTime(createdAt.year, createdAt.month, createdAt.day);
        final dayIdx = createdDay.difference(trendDates.first).inDays;
        if (dayIdx >= 0 && dayIdx < 7) {
          dailyReported[dayIdx]++;
        }
      }
      if (status == HazardReportStatuses.resolved) {
        final effectiveResolvedAt = resolvedAt ?? verifiedAt ?? createdAt;
        if (effectiveResolvedAt != null) {
          final resolvedDay = DateTime(
            effectiveResolvedAt.year,
            effectiveResolvedAt.month,
            effectiveResolvedAt.day,
          );
          final resIdx = resolvedDay.difference(trendDates.first).inDays;
          if (resIdx >= 0 && resIdx < 7) {
            dailyResolved[resIdx]++;
          }
        }
      }

      // Scoped timeframe filtering
      final inScope = cutoff == null ||
          (createdAt != null && !createdAt.isBefore(cutoff));
      if (!inScope) continue;

      final bool isUniqueScopedActive = status == HazardReportStatuses.active &&
          (activeSpotKey == null || seenScopedActiveKeys.add(activeSpotKey));

      scopedTotal++;
      if (status == HazardReportStatuses.active) {
        if (isUniqueScopedActive) {
          scopedActive++;
        }
      } else if (status == HazardReportStatuses.pending) {
        scopedPending++;
      } else if (status == HazardReportStatuses.resolved) {
        scopedResolved++;
      } else if (status == HazardReportStatuses.rejected) {
        scopedRejected++;
      }

      // Verification turnaround SLA (only reports with verified_at >= created_at)
      if (createdAt != null && verifiedAt != null) {
        final diffMins = verifiedAt.difference(createdAt).inMinutes;
        if (diffMins >= 0) {
          verifyMinutesList.add(diffMins);
        }
      }

      // Resolution duration SLA
      if (status == HazardReportStatuses.resolved &&
          createdAt != null &&
          resolvedAt != null) {
        final diffMinutes = resolvedAt.difference(createdAt).inMinutes;
        if (diffMinutes >= 0) {
          resolutionHoursList.add(diffMinutes / 60.0);
        }
      }

      // AI Gemini confidence distribution
      final rawConf = row['confidence'];
      final int? conf = rawConf is num
          ? rawConf.round()
          : int.tryParse(rawConf?.toString() ?? '');
      if (conf != null && conf >= 0 && conf <= 100) {
        confidenceValues.add(conf);
        if (conf >= 80) {
          highConf++;
        } else if (conf >= 50) {
          medConf++;
        } else {
          lowConf++;
        }
      }

      // Category aggregation (ignore rejected/archived spam from hazard category demand)
      if (status != HazardReportStatuses.rejected &&
          status != HazardReportStatuses.archived) {
        final categoryLabel = _normalizeCategory(
          row['hazard_category']?.toString(),
          fallback: row['detected_hazard']?.toString(),
        );
        final catEntry = categoryAcc.putIfAbsent(
          categoryLabel.toLowerCase(),
          () => _CategoryAccumulator(categoryLabel),
        );
        catEntry.total++;
        if (isUniqueScopedActive) {
          catEntry.active++;
          if (severity == HazardSeverityBucket.high) {
            catEntry.highSeverity++;
          }
        }
        if (status == HazardReportStatuses.resolved) catEntry.resolved++;

        // Barangay hotspot aggregation
        final areaLabel = extractBarangayLabel(
          row['location_address']?.toString(),
          latitude: lat,
          longitude: lng,
        );
        if (areaLabel != null) {
          final spot = hotspotAcc.putIfAbsent(
            areaLabel.toLowerCase(),
            () => _HotspotAccumulator(areaLabel),
          );
          spot.total++;
          if (isUniqueScopedActive) {
            spot.active++;
            if (severity == HazardSeverityBucket.high) {
              spot.highSeverity++;
            }
            spot.activeCategoryCounts[categoryLabel] =
                (spot.activeCategoryCounts[categoryLabel] ?? 0) + 1;
          }
          spot.categoryCounts[categoryLabel] =
              (spot.categoryCounts[categoryLabel] ?? 0) + 1;
        }
      }
    }

    // Resolution proofs from `hazard_resolution_reports`
    int proofsPendingAllTime = 0;
    int proofsApproved = 0;
    int proofsPending = 0;
    int proofsRejected = 0;
    for (final res in resolutions) {
      final resStatus = res['status']?.toString().trim().toLowerCase() ?? '';
      if (resStatus == 'pending') {
        proofsPendingAllTime++;
      }

      if (cutoff != null) {
        final proofTimestamp =
            _parseLocalDateTime(res['verified_at']) ??
            _parseLocalDateTime(res['created_at']);
        if (proofTimestamp == null || proofTimestamp.isBefore(cutoff)) {
          continue;
        }
      }

      if (resStatus == 'pending') {
        proofsPending++;
      } else if (resStatus == 'approved' || resStatus == 'resolved') {
        proofsApproved++;
      } else if (resStatus == 'rejected') {
        proofsRejected++;
      }
    }

    final int effectivePendingProofs =
        math.max(proofsPendingAllTime, fallbackPendingResolutions);

    // Ratios & Medians
    final int resDenom = scopedActive + scopedResolved;
    final double resRate = resDenom > 0 ? scopedResolved / resDenom : 0.0;

    final int sigDenom = scopedActive + scopedResolved + scopedRejected;
    final double sigRate =
        sigDenom > 0 ? (scopedActive + scopedResolved) / sigDenom : 0.0;

    final int? medVerify = _medianInt(verifyMinutesList);
    final double? medResHours = _medianDouble(resolutionHoursList);
    final int? avgConf = confidenceValues.isNotEmpty
        ? (confidenceValues.reduce((a, b) => a + b) / confidenceValues.length)
            .round()
        : null;

    // Sort categories by Active first, then Total
    final int categoryDenominator = categoryAcc.values.fold<int>(
      0,
      (sum, c) => sum + c.total,
    );
    final List<HazardCategoryStat> sortedCategories = categoryAcc.values
        .map(
          (c) => HazardCategoryStat(
            category: c.displayLabel,
            totalCount: c.total,
            activeCount: c.active,
            resolvedCount: c.resolved,
            highSeverityCount: c.highSeverity,
            share:
                categoryDenominator > 0 ? c.total / categoryDenominator : 0.0,
          ),
        )
        .toList()
      ..sort((a, b) {
        final activeCmp = b.activeCount.compareTo(a.activeCount);
        if (activeCmp != 0) return activeCmp;
        final totalCmp = b.totalCount.compareTo(a.totalCount);
        if (totalCmp != 0) return totalCmp;
        return a.category.compareTo(b.category);
      });

    // Sort hotspots by Active first, then active High-severity, then Total
    final List<HazardHotspotStat> sortedHotspots = hotspotAcc.values
        .map((h) {
          String topCat = 'Hazard';
          int topCatCount = -1;
          final Map<String, int> countsToRank =
              h.active > 0 && h.activeCategoryCounts.isNotEmpty
                  ? h.activeCategoryCounts
                  : h.categoryCounts;
          countsToRank.forEach((cat, count) {
            if (count > topCatCount) {
              topCatCount = count;
              topCat = cat;
            }
          });
          return HazardHotspotStat(
            areaLabel: h.displayLabel,
            totalCount: h.total,
            activeCount: h.active,
            highSeverityCount: h.highSeverity,
            topCategory: topCat,
          );
        })
        .toList()
      ..sort((a, b) {
        final activeCmp = b.activeCount.compareTo(a.activeCount);
        if (activeCmp != 0) return activeCmp;
        final highCmp = b.highSeverityCount.compareTo(a.highSeverityCount);
        if (highCmp != 0) return highCmp;
        return b.totalCount.compareTo(a.totalCount);
      });

    const weekdayAbbr = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final List<DailyTrendBucket> trendBuckets = List<DailyTrendBucket>.generate(
      7,
      (i) {
        final d = trendDates[i];
        return DailyTrendBucket(
          date: d,
          dayLabel: weekdayAbbr[d.weekday - 1],
          reportedCount: dailyReported[i],
          resolvedCount: dailyResolved[i],
        );
      },
    );

    return AdminSafetyAnalytics(
      timeframe: timeframe,
      generatedAt: current,
      totalReportsAllTime: reports.length,
      activeHazardsCount: activeAll,
      activeHighCount: activeHigh,
      activeMediumCount: activeMedium,
      activeLowCount: activeLow,
      pendingReportsCount: pendingReports,
      pendingResolutionProofsCount: effectivePendingProofs,
      resolvedReportsAllTime: resolvedAll,
      rejectedOrArchivedAllTime: rejectedOrArchivedAll,
      scopedReportsCount: scopedTotal,
      scopedActiveCount: scopedActive,
      scopedPendingCount: scopedPending,
      scopedResolvedCount: scopedResolved,
      scopedRejectedCount: scopedRejected,
      resolutionRate: resRate,
      hasResolutionDenominator: resDenom > 0,
      signalApprovalRate: sigRate,
      hasSignalDenominator: sigDenom > 0,
      medianVerifyMinutes: medVerify,
      medianResolutionHours: medResHours,
      averageAiConfidence: avgConf,
      highConfidenceCount: highConf,
      mediumConfidenceCount: medConf,
      lowConfidenceCount: lowConf,
      resolutionProofsApproved: proofsApproved,
      resolutionProofsPending: proofsPending,
      resolutionProofsRejected: proofsRejected,
      topCategories: sortedCategories,
      topHotspots: sortedHotspots,
      last7DaysTrend: trendBuckets,
    );
  }

  /// Supplemental downtown/urban Cebu City barangays not listed as standalone
  /// centroids in [CebuLandmarkService.landmarks].
  static const Map<String, ({double lat, double lng, String name})>
      _supplementalBarangays = {
    'kalubihan': (lat: 10.2972, lng: 123.8982, name: 'Barangay Kalubihan'),
    'santo nino': (lat: 10.2943, lng: 123.9016, name: 'Barangay Santo Niño'),
    'san antonio': (lat: 10.3005, lng: 123.8998, name: 'Barangay San Antonio'),
    'day-as': (lat: 10.3045, lng: 123.9005, name: 'Barangay Day-as'),
    'cogon ramos': (lat: 10.3075, lng: 123.8988, name: 'Barangay Cogon Ramos'),
    'kamagayan': (lat: 10.3025, lng: 123.8972, name: 'Barangay Kamagayan'),
    'san roque': (lat: 10.2958, lng: 123.9045, name: 'Barangay San Roque'),
    'kalunasan': (lat: 10.3300, lng: 123.8780, name: 'Barangay Kalunasan'),
    'luz': (lat: 10.3185, lng: 123.9055, name: 'Barangay Luz'),
    'hipodromo': (lat: 10.3155, lng: 123.9095, name: 'Barangay Hipodromo'),
    'carreta': (lat: 10.3085, lng: 123.9115, name: 'Barangay Carreta'),
    'duljo fatima': (lat: 10.2895, lng: 123.8830, name: 'Barangay Duljo Fatima'),
    'inayawan': (lat: 10.2755, lng: 123.8565, name: 'Barangay Inayawan'),
    'cogon pardo': (lat: 10.2810, lng: 123.8580, name: 'Barangay Cogon Pardo'),
    'bulacao': (lat: 10.2715, lng: 123.8480, name: 'Barangay Bulacao'),
    'pari-an': (lat: 10.3002, lng: 123.9032, name: 'Barangay Pari-an'),
    't. padilla': (lat: 10.3036, lng: 123.9052, name: 'Barangay T. Padilla'),
    'pahina san nicolas': (
      lat: 10.2932,
      lng: 123.8910,
      name: 'Barangay Pahina San Nicolas',
    ),
  };

  static const Map<String, String> _barangayCanonicalAliases = {
    'camputhaw': 'Barangay Kamputhaw',
    'kamputhaw': 'Barangay Kamputhaw',
    'quiot': 'Barangay Quiot Pardo',
    'quiot pardo': 'Barangay Quiot Pardo',
    'bayanihan quiot': 'Barangay Quiot Pardo',
    'bayanihan': 'Barangay Quiot Pardo',
    'pardo': 'Barangay Poblacion Pardo',
    'poblacion pardo': 'Barangay Poblacion Pardo',
    'sambag 1': 'Barangay Sambag I',
    'sambag i': 'Barangay Sambag I',
    'sambag 2': 'Barangay Sambag II',
    'sambag ii': 'Barangay Sambag II',
    'san nicolas': 'Barangay San Nicolas Proper',
    'san nicolas proper': 'Barangay San Nicolas Proper',
    'lorega': 'Barangay Lorega San Miguel',
    'lorega san miguel': 'Barangay Lorega San Miguel',
    'sta cruz': 'Barangay Santa Cruz',
    'sta. cruz': 'Barangay Santa Cruz',
    'santa cruz': 'Barangay Santa Cruz',
    'sto nino': 'Barangay Santo Niño',
    'sto. nino': 'Barangay Santo Niño',
    'santo nino': 'Barangay Santo Niño',
    'santo niño': 'Barangay Santo Niño',
    'banawa': 'Barangay Guadalupe',
    'panagdait': 'Barangay Kasambagan',
    'it park lahug': 'Barangay Lahug',
    'duljo': 'Barangay Duljo Fatima',
    'barrio luz': 'Barangay Luz',
  };

  static final RegExp _streetOrBuildingRegex = RegExp(
    r'\b(street|st\.?|avenue|ave\.?|road|rd\.?|boulevard|blvd\.?|highway|hwy\.?|drive|dr\.?|lane|ln\.?|alley|ext\.?|extension|bridge|flyover|underpass|expressway|rotunda|corner|junction|mall|market|hospital|school|university|college|church|terminal|port|plaza|park|center|centre|bldg\.?|building)\b',
    caseSensitive: false,
  );

  static final RegExp _cityOrMunicipalityRegex = RegExp(
    r'(\bcity\b|^(cebu|mandaue|lapu-lapu|talisay|consolacion|liloan|minglanilla|cordova|compostela|naga|carcar|danao|toledo|san fernando|central visayas|region vii|philippines)$)',
    caseSensitive: false,
  );

  /// Extracts a normalized barangay name (`Barangay <Name>`) from
  /// [rawAddress] and/or falls back to the nearest barangay centroid for
  /// `[latitude, longitude]`. Street-only addresses, placeholders, and
  /// unmappable raw coordinate pairs return `null`.
  static String? extractBarangayLabel(
    String? rawAddress, {
    double? latitude,
    double? longitude,
  }) {
    final trimmed = rawAddress?.trim() ?? '';
    final lower = trimmed.toLowerCase();
    final bool isPlaceholder = trimmed.isEmpty ||
        lower == 'current location' ||
        lower == 'unknown location' ||
        lower == 'unknown' ||
        lower == 'selected location' ||
        RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(trimmed);

    if (!isPlaceholder) {
      final segments = trimmed
          .split(',')
          .map((s) => s.trim())
          .where((s) {
            if (s.isEmpty) return false;
            final sLower = s.toLowerCase();
            if (sLower == 'philippines' ||
                sLower == 'central visayas' ||
                sLower == 'region vii' ||
                sLower == 'region 7' ||
                sLower == 'cebu' ||
                sLower == 'cebu province') {
              return false;
            }
            if (RegExp(r'^\d{4,5}$').hasMatch(s)) return false;
            return true;
          })
          .toList();

      // 1. Explicit "Barangay ..." / "Brgy. ..." prefix in any segment
      for (final seg in segments) {
        final match = RegExp(
          r'^(?:brgy\.?|barangay)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(seg);
        if (match != null) {
          final body = match.group(1)?.trim() ?? '';
          if (body.isNotEmpty) {
            return _canonicalizeBarangay(body);
          }
        }
      }

      // 2. Match known Metro Cebu barangays (right-to-left so barangay wins over street)
      for (var i = segments.length - 1; i >= 0; i--) {
        final seg = segments[i];
        if (_isCityOrProvinceSegment(seg) || _looksLikeStreetOrBuilding(seg)) {
          continue;
        }
        final matched = _matchKnownBarangaySegment(seg);
        if (matched != null) {
          return matched;
        }
      }

      // 3. City-anchored segment immediately preceding "<City>" (supports any barangay)
      for (var i = 1; i < segments.length; i++) {
        if (_isCityOrProvinceSegment(segments[i])) {
          final candidate = segments[i - 1];
          if (!_isCityOrProvinceSegment(candidate) &&
              !_looksLikeStreetOrBuilding(candidate) &&
              !_looksLikeHouseOrLotPrefix(candidate)) {
            return _canonicalizeBarangay(candidate);
          }
        }
      }
    }

    // 4. Coordinate fallback against known barangay centroids when address text omits barangay
    if (latitude != null && longitude != null) {
      return _nearestBarangayByCoordinates(latitude, longitude);
    }

    return null;
  }

  /// Legacy alias kept for backwards compatibility; delegates to
  /// [extractBarangayLabel].
  static String? extractAreaLabel(String? rawAddress) =>
      extractBarangayLabel(rawAddress);

  static bool _isCityOrProvinceSegment(String segment) =>
      _cityOrMunicipalityRegex.hasMatch(segment.trim());

  static bool _looksLikeStreetOrBuilding(String segment) =>
      _streetOrBuildingRegex.hasMatch(segment.trim());

  static bool _looksLikeHouseOrLotPrefix(String segment) =>
      segment.trim().length <= 2 ||
      RegExp(r'^(#?\d+[a-zA-Z]?|blk\b|lot\b|phase\b|purok\b)', caseSensitive: false)
          .hasMatch(segment.trim());

  static final Map<String, String> _knownBarangayLookup =
      _buildKnownBarangayLookup();

  static Map<String, String> _buildKnownBarangayLookup() {
    final map = <String, String>{};
    map.addAll(_barangayCanonicalAliases);
    for (final entry in _supplementalBarangays.entries) {
      map.putIfAbsent(entry.key, () => entry.value.name);
    }
    for (final landmark in CebuLandmarkService.landmarks) {
      if (landmark.category != LandmarkCategory.barangay) continue;
      final canonical = _canonicalizeBarangay(landmark.name);
      final nameKey = _stripBarangayPrefix(landmark.name).toLowerCase();
      if (nameKey.isNotEmpty) {
        map.putIfAbsent(nameKey, () => canonical);
      }
      for (final alias in landmark.aliases) {
        final aliasKey = _stripBarangayPrefix(alias).toLowerCase();
        if (aliasKey.isNotEmpty) {
          map.putIfAbsent(aliasKey, () => canonical);
        }
      }
    }
    return Map<String, String>.unmodifiable(map);
  }

  static String? _matchKnownBarangaySegment(String segment) {
    final cleanedKey = _stripBarangayPrefix(segment).toLowerCase();
    if (cleanedKey.isEmpty) return null;
    return _knownBarangayLookup[cleanedKey];
  }

  static String _stripBarangayPrefix(String raw) {
    var out = raw.trim();
    out = out.replaceFirst(
      RegExp(r'^(?:brgy\.?|barangay)\s+', caseSensitive: false),
      '',
    );
    // Strip trailing parenthetical synonym like "Camputhaw (Kamputhaw)"
    out = out.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '');
    return out.trim();
  }

  static String _canonicalizeBarangay(String raw) {
    final stripped = _stripBarangayPrefix(raw);
    final lower = stripped.toLowerCase();
    final aliasHit = _barangayCanonicalAliases[lower];
    if (aliasHit != null) return aliasHit;

    final suppHit = _supplementalBarangays[lower];
    if (suppHit != null) return suppHit.name;

    final titled = _titleCasePreserveRoman(stripped);
    if (titled.isEmpty) return 'Barangay Unknown';
    return 'Barangay $titled';
  }

  static String _titleCasePreserveRoman(String input) {
    final words = input.trim().split(RegExp(r'\s+'));
    return words.where((w) => w.isNotEmpty).map((w) {
      final upper = w.toUpperCase();
      if (upper == 'I' || upper == 'II' || upper == 'III' || upper == 'IV') {
        return upper;
      }
      if (w.length == 1) return w.toUpperCase();
      // Preserve hyphenated parts such as "Day-as" or "San-Nicolas"
      if (w.contains('-')) {
        return w.split('-').map((part) {
          if (part.isEmpty) return '';
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        }).join('-');
      }
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  static String? _nearestBarangayByCoordinates(double lat, double lng) {
    String? bestName;
    double bestMeters = 3500.0; // Max 3.5 km centroid match

    for (final landmark in CebuLandmarkService.landmarks) {
      if (landmark.category != LandmarkCategory.barangay) continue;
      final dist = _haversineMeters(
        lat,
        lng,
        landmark.location.latitude,
        landmark.location.longitude,
      );
      if (dist < bestMeters) {
        bestMeters = dist;
        bestName = _canonicalizeBarangay(landmark.name);
      }
    }

    for (final entry in _supplementalBarangays.values) {
      final dist = _haversineMeters(lat, lng, entry.lat, entry.lng);
      if (dist < bestMeters) {
        bestMeters = dist;
        bestName = entry.name;
      }
    }

    return bestName;
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static String _normalizeCategory(String? raw, {String? fallback}) {
    String candidate = (raw ?? '').trim();
    if (candidate.isEmpty) {
      candidate = (fallback ?? '').trim();
    }
    if (candidate.isEmpty) return 'Other Hazard';

    // Title-case words consistently so "flooding" and "Flooding" merge cleanly
    final words = candidate.split(RegExp(r'\s+'));
    return words.map((w) {
      if (w.isEmpty) return '';
      if (w.length == 1) return w.toUpperCase();
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  static DateTime? _parseLocalDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString().trim())?.toLocal();
  }

  static double? _parseCoordinate(dynamic value) {
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    if (value is String) {
      final d = double.tryParse(value.trim());
      if (d != null && d.isFinite) return d;
    }
    return null;
  }

  static int? _medianInt(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2.0).round();
  }

  static double? _medianDouble(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }
}

/// Container holding raw fetched rows so the Admin Analytics screen can
/// recompute metrics across timeframes instantaneously without extra queries.
class AdminAnalyticsRawSnapshot {
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> resolutions;

  const AdminAnalyticsRawSnapshot({
    required this.reports,
    required this.resolutions,
  });

  AdminSafetyAnalytics compute({
    AnalyticsTimeframe timeframe = AnalyticsTimeframe.allTime,
    DateTime? now,
  }) {
    return AdminSafetyAnalytics.fromRawData(
      reports: reports,
      resolutions: resolutions,
      timeframe: timeframe,
      now: now,
    );
  }
}

class AdminAnalyticsService {
  const AdminAnalyticsService();

  Future<AdminAnalyticsRawSnapshot> fetchRawSnapshot({
    SupabaseClient? clientOverride,
  }) async {
    final client = clientOverride ?? Supabase.instance.client;

    final Future<dynamic> reportsFuture = client
        .from('ReportTable')
        .select(
          'reportID, hazard_category, detected_hazard, severity_level, '
          'confidence, latitude, longitude, location_address, status, '
          'resolution_status, resolution_count, created_at, verified_at, resolved_at',
        )
        .order('created_at', ascending: false)
        .limit(2000);

    Future<dynamic> fetchResolutionsSafe() async {
      try {
        return await client
            .from('hazard_resolution_reports')
            .select(
              'id, report_id, hazard_category, status, created_at, verified_at',
            )
            .order('created_at', ascending: false)
            .limit(2000);
      } catch (e) {
        debugPrint('Warning: resolution analytics query skipped: $e');
        return const <dynamic>[];
      }
    }

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      reportsFuture,
      fetchResolutionsSafe(),
    ]);

    final List<Map<String, dynamic>> reportRows = <Map<String, dynamic>>[];
    final dynamic rawReports = results[0];
    if (rawReports is List) {
      for (final row in rawReports) {
        if (row is Map<String, dynamic>) {
          reportRows.add(row);
        }
      }
    }

    final List<Map<String, dynamic>> resolutionRows = <Map<String, dynamic>>[];
    final dynamic rawRes = results[1];
    if (rawRes is List) {
      for (final row in rawRes) {
        if (row is Map<String, dynamic>) {
          resolutionRows.add(row);
        }
      }
    }

    return AdminAnalyticsRawSnapshot(
      reports: reportRows,
      resolutions: resolutionRows,
    );
  }

  Future<AdminSafetyAnalytics> fetchAnalytics({
    AnalyticsTimeframe timeframe = AnalyticsTimeframe.allTime,
    SupabaseClient? clientOverride,
  }) async {
    final snapshot = await fetchRawSnapshot(clientOverride: clientOverride);
    return snapshot.compute(timeframe: timeframe);
  }
}

class _CategoryAccumulator {
  final String displayLabel;
  int total = 0;
  int active = 0;
  int resolved = 0;
  int highSeverity = 0;

  _CategoryAccumulator(this.displayLabel);
}

class _HotspotAccumulator {
  final String displayLabel;
  int total = 0;
  int active = 0;
  int highSeverity = 0;
  final Map<String, int> activeCategoryCounts = <String, int>{};
  final Map<String, int> categoryCounts = <String, int>{};

  _HotspotAccumulator(this.displayLabel);
}
