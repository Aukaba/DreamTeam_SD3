import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

      // All-time / live queue counts
      if (status == HazardReportStatuses.active) {
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

      scopedTotal++;
      if (status == HazardReportStatuses.active) {
        scopedActive++;
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
        if (status == HazardReportStatuses.active) catEntry.active++;
        if (status == HazardReportStatuses.resolved) catEntry.resolved++;
        if (severity == HazardSeverityBucket.high) catEntry.highSeverity++;

        // Area hotspot aggregation
        final areaLabel = extractAreaLabel(row['location_address']?.toString());
        if (areaLabel != null) {
          final spot = hotspotAcc.putIfAbsent(
            areaLabel.toLowerCase(),
            () => _HotspotAccumulator(areaLabel),
          );
          spot.total++;
          if (status == HazardReportStatuses.active) spot.active++;
          if (severity == HazardSeverityBucket.high) spot.highSeverity++;
          spot.categoryCounts[categoryLabel] =
              (spot.categoryCounts[categoryLabel] ?? 0) + 1;
        }
      }
    }

    // Resolution proofs from `hazard_resolution_reports`
    int proofsApproved = 0;
    int proofsPending = 0;
    int proofsRejected = 0;
    for (final res in resolutions) {
      final resStatus = res['status']?.toString().trim().toLowerCase() ?? '';
      if (resStatus == 'pending') {
        proofsPending++;
      } else if (resStatus == 'approved' || resStatus == 'resolved') {
        proofsApproved++;
      } else if (resStatus == 'rejected') {
        proofsRejected++;
      }
    }

    final int effectivePendingProofs =
        resolutions.isNotEmpty ? proofsPending : fallbackPendingResolutions;

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

    // Sort hotspots by Active first, then High-severity, then Total
    final List<HazardHotspotStat> sortedHotspots = hotspotAcc.values
        .map((h) {
          String topCat = 'Hazard';
          int topCatCount = -1;
          h.categoryCounts.forEach((cat, count) {
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
      resolutionProofsPending: effectivePendingProofs,
      resolutionProofsRejected: proofsRejected,
      topCategories: sortedCategories,
      topHotspots: sortedHotspots,
      last7DaysTrend: trendBuckets,
    );
  }

  /// Extracts a clean street/barangay area label from a raw address string,
  /// filtering out generic placeholders and raw lat/lng pairs.
  static String? extractAreaLabel(String? rawAddress) {
    final trimmed = rawAddress?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (lower == 'current location' ||
        lower == 'unknown location' ||
        lower == 'unknown' ||
        lower == 'selected location') {
      return null;
    }

    // Ignore raw coordinate strings such as "10.3157, 123.8854"
    final coordPattern = RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$');
    if (coordPattern.hasMatch(trimmed)) return null;

    final segments = trimmed
        .split(',')
        .map((s) => s.trim())
        .where((s) {
          if (s.isEmpty) return false;
          final sLower = s.toLowerCase();
          if (sLower == 'philippines' ||
              sLower == 'central visayas' ||
              sLower == 'region vii' ||
              sLower == 'cebu') {
            return false;
          }
          // Skip standalone postal codes (e.g., "6000")
          if (RegExp(r'^\d{4,5}$').hasMatch(s)) return false;
          return true;
        })
        .toList();

    if (segments.isEmpty) {
      return trimmed.length > 36 ? '${trimmed.substring(0, 33)}...' : trimmed;
    }

    // Keep primary street/landmark segment; only append second segment when
    // the first is a short house/lot prefix (e.g., "12" or "Blk 2").
    final bool firstIsShortPrefix = segments[0].length <= 5 ||
        RegExp(r'^(#?\d+[a-zA-Z]?|blk\b|lot\b)', caseSensitive: false)
            .hasMatch(segments[0]);
    final picked = segments.length >= 2 && firstIsShortPrefix
        ? '${segments[0]}, ${segments[1]}'
        : segments.first;

    if (picked.length > 40) {
      return '${picked.substring(0, 37)}...';
    }
    return picked;
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

    final dynamic rawReports = await client
        .from('ReportTable')
        .select(
          'reportID, hazard_category, detected_hazard, severity_level, '
          'confidence, location_address, status, resolution_status, '
          'resolution_count, created_at, verified_at, resolved_at',
        );

    final List<Map<String, dynamic>> reportRows = <Map<String, dynamic>>[];
    if (rawReports is List) {
      for (final row in rawReports) {
        if (row is Map<String, dynamic>) {
          reportRows.add(row);
        }
      }
    }

    final List<Map<String, dynamic>> resolutionRows = <Map<String, dynamic>>[];
    try {
      final dynamic rawRes = await client
          .from('hazard_resolution_reports')
          .select('id, report_id, hazard_category, status, created_at, verified_at');
      if (rawRes is List) {
        for (final row in rawRes) {
          if (row is Map<String, dynamic>) {
            resolutionRows.add(row);
          }
        }
      }
    } catch (e) {
      debugPrint('Warning: resolution analytics query skipped: $e');
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
  final Map<String, int> categoryCounts = <String, int>{};

  _HotspotAccumulator(this.displayLabel);
}
