import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hazard_report_service.dart';
import 'safe_route_service.dart';

/// Represents a user's level progression based on earned report points.
///
/// Leveling rules:
/// - Each submitted report counts as 1 report.
/// - Points awarded per report by severity:
///   Low = 1 pt, Medium = 2 pts, High = 3 pts.
/// - Level 1 requires 20 points to level up.
/// - Each subsequent level requires 1/4 (25%) more points than the previous level:
///   Level 1 -> 20 pts, Level 2 -> 25 pts (+5), Level 3 -> 31 pts, Level 4 -> 39 pts, etc.
class LevelProgressData {
  final int level;
  final int currentLevelPoints;
  final int nextLevelRequiredPoints;
  final int totalPoints;

  const LevelProgressData({
    required this.level,
    required this.currentLevelPoints,
    required this.nextLevelRequiredPoints,
    required this.totalPoints,
  });

  /// Returns the points required to complete [level] and advance to `level + 1`.
  /// Level 1 requires 20 points; each subsequent level adds 1/4 (25%) of the previous requirement.
  static int pointsRequiredForLevel(int level) {
    int required = 20;
    for (int l = 1; l < level; l++) {
      required = required + (required / 4.0).round();
    }
    return required;
  }

  /// Computes level progression from [totalPoints].
  factory LevelProgressData.fromTotalPoints(int totalPoints) {
    final safeTotal = totalPoints < 0 ? 0 : totalPoints;
    int remaining = safeTotal;
    int level = 1;
    int required = 20;

    while (remaining >= required) {
      remaining -= required;
      level += 1;
      required = required + (required / 4.0).round();
    }

    return LevelProgressData(
      level: level,
      currentLevelPoints: remaining,
      nextLevelRequiredPoints: required,
      totalPoints: safeTotal,
    );
  }

  double get progressFraction {
    if (nextLevelRequiredPoints <= 0) return 0.0;
    return (currentLevelPoints / nextLevelRequiredPoints).clamp(0.0, 1.0);
  }

  int get pointsRemainingToNextLevel =>
      (nextLevelRequiredPoints - currentLevelPoints)
          .clamp(0, nextLevelRequiredPoints);

  String get badgeLabel {
    if (level >= 5) return 'Hero';
    switch (level) {
      case 4:
        return 'Guard';
      case 3:
        return 'Scout';
      case 2:
        return 'Watcher';
      case 1:
      default:
        return 'Rookie';
    }
  }

  String get contributorTitle => 'Level $level · Safety $badgeLabel';
}

/// Ranked entry on the community leaderboard.
class LeaderboardUserEntry {
  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final int reportCount;
  final int safetyPoints;
  final int savedRoutesCount;
  final int allTimePoints;
  final int allTimeReports;
  final LevelProgressData levelProgress;
  final int daysActive;
  final bool isCurrentUser;

  const LeaderboardUserEntry({
    required this.userId,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    required this.reportCount,
    required this.safetyPoints,
    required this.savedRoutesCount,
    required this.allTimePoints,
    required this.allTimeReports,
    required this.levelProgress,
    required this.daysActive,
    required this.isCurrentUser,
  });

  String get initials {
    final cleaned = displayName.trim();
    if (cleaned.isEmpty) return 'SR';
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory LeaderboardUserEntry.fromRpcRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    final uid = row['user_id']?.toString() ?? '';
    final reportCount = (row['report_count'] as num?)?.toInt() ?? 0;
    final safetyPoints = (row['safety_points'] as num?)?.toInt() ?? 0;
    final savedRoutesCount = (row['saved_routes_count'] as num?)?.toInt() ?? 0;
    final allTimePoints =
        (row['all_time_points'] as num?)?.toInt() ?? safetyPoints;
    final allTimeReports =
        (row['all_time_reports'] as num?)?.toInt() ?? reportCount;
    final daysActive = (row['days_active'] as num?)?.toInt() ?? 1;

    final computedLevel = LevelProgressData.fromTotalPoints(allTimePoints);

    final rawName = row['display_name']?.toString().trim() ?? '';
    final rawUsername = row['username']?.toString().trim() ?? '';
    final displayName = rawName.isNotEmpty
        ? rawName
        : (rawUsername.isNotEmpty ? rawUsername : 'SafeRoute Member');

    return LeaderboardUserEntry(
      userId: uid,
      displayName: displayName,
      username: rawUsername.isNotEmpty ? rawUsername : 'user',
      avatarUrl: row['avatar_url']?.toString(),
      reportCount: reportCount,
      safetyPoints: safetyPoints,
      savedRoutesCount: savedRoutesCount,
      allTimePoints: allTimePoints,
      allTimeReports: allTimeReports,
      levelProgress: computedLevel,
      daysActive: daysActive < 1 ? 1 : daysActive,
      isCurrentUser: currentUserId != null &&
          currentUserId.isNotEmpty &&
          uid == currentUserId,
    );
  }
}

/// Summary of the signed-in user's gamification and activity metrics for Profile screen.
class UserGamificationStats {
  final int reportCount;
  final int totalPoints;
  final int savedRoutesCount;
  final int daysActive;
  final LevelProgressData levelProgress;

  const UserGamificationStats({
    required this.reportCount,
    required this.totalPoints,
    required this.savedRoutesCount,
    required this.daysActive,
    required this.levelProgress,
  });

  factory UserGamificationStats.fromCounts({
    required int reportCount,
    required int totalPoints,
    required int savedRoutesCount,
    int daysActive = 1,
  }) {
    return UserGamificationStats(
      reportCount: reportCount,
      totalPoints: totalPoints,
      savedRoutesCount: savedRoutesCount,
      daysActive: daysActive < 1 ? 1 : daysActive,
      levelProgress: LevelProgressData.fromTotalPoints(totalPoints),
    );
  }
}

/// Service that queries leaderboard rankings and user level/point stats from Supabase.
class LeaderboardService {
  final SupabaseClient? _explicitClient;
  final HazardReportService _hazardReportService;
  final SafeRouteService _safeRouteService;

  LeaderboardService({
    SupabaseClient? client,
    HazardReportService? hazardReportService,
    SafeRouteService? safeRouteService,
  })  : _explicitClient = client,
        _hazardReportService = hazardReportService ?? HazardReportService(client: client),
        _safeRouteService = safeRouteService ?? SafeRouteService(supabaseClient: client);

  SupabaseClient? _tryGetClient() {
    if (_explicitClient != null) return _explicitClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Fetches all leaderboard entries from Supabase (`public.get_leaderboard`),
  /// supporting both `'all'` (All Time) and `'week'` (This Week) timeframes.
  Future<List<LeaderboardUserEntry>> fetchLeaderboard({
    bool isWeekly = false,
  }) async {
    final client = _tryGetClient();
    final currentUserId = client?.auth.currentUser?.id;

    if (client != null) {
      try {
        final dynamic response = await client.rpc(
          'get_leaderboard',
          params: <String, dynamic>{
            'p_timeframe': isWeekly ? 'week' : 'all',
          },
        );

        if (response is List && response.isNotEmpty) {
          final entries = response
              .whereType<Map>()
              .map(
                (r) => LeaderboardUserEntry.fromRpcRow(
                  Map<String, dynamic>.from(r),
                  currentUserId: currentUserId,
                ),
              )
              .toList();
          return entries;
        }
      } catch (e) {
        debugPrint('Warning: get_leaderboard RPC fallback: $e');
      }

      // Direct table aggregation fallback if RPC is unavailable
      try {
        final cutoff = isWeekly
            ? DateTime.now().subtract(const Duration(days: 7))
            : DateTime.fromMillisecondsSinceEpoch(0);

        final dynamic rawReports = await client
            .from('ReportTable')
            .select('user_id, severity_level, points_awarded, status, created_at')
            .not('user_id', 'is', null)
            .inFilter(
              'status',
              const <String>[
                HazardReportStatuses.active,
                HazardReportStatuses.resolved,
              ],
            );

        final Map<String, int> windowReports = <String, int>{};
        final Map<String, int> windowPoints = <String, int>{};
        final Map<String, int> allReports = <String, int>{};
        final Map<String, int> allPoints = <String, int>{};

        if (rawReports is List) {
          for (final item in rawReports.whereType<Map>()) {
            final uid = item['user_id']?.toString();
            if (uid == null || uid.isEmpty) continue;
            if (!HazardReportStatuses.isAcceptedForUserReports(
              item['status']?.toString(),
            )) {
              continue;
            }
            final pts = (item['points_awarded'] as num?)?.toInt() ??
                HazardReportService.calculateSeverityPoints(
                  item['severity_level']?.toString(),
                );
            final createdAt = DateTime.tryParse(
                  item['created_at']?.toString() ?? '',
                ) ??
                DateTime.now();

            allReports[uid] = (allReports[uid] ?? 0) + 1;
            allPoints[uid] = (allPoints[uid] ?? 0) + pts;

            if (!createdAt.isBefore(cutoff)) {
              windowReports[uid] = (windowReports[uid] ?? 0) + 1;
              windowPoints[uid] = (windowPoints[uid] ?? 0) + pts;
            }
          }
        }

        final entries = <LeaderboardUserEntry>[];
        for (final uid in allReports.keys) {
          final totalPts = allPoints[uid] ?? 0;
          final isMe = currentUserId != null && uid == currentUserId;
          entries.add(
            LeaderboardUserEntry(
              userId: uid,
              displayName: isMe ? 'You' : 'Contributor ${uid.substring(0, 4)}',
              username: 'user',
              reportCount: windowReports[uid] ?? 0,
              safetyPoints: windowPoints[uid] ?? 0,
              savedRoutesCount: 0,
              allTimePoints: totalPts,
              allTimeReports: allReports[uid] ?? 0,
              levelProgress: LevelProgressData.fromTotalPoints(totalPts),
              daysActive: 1,
              isCurrentUser: isMe,
            ),
          );
        }
        if (entries.isNotEmpty) {
          return entries;
        }
      } catch (e) {
        debugPrint('Warning: Direct leaderboard fallback error: $e');
      }
    }

    // Session / offline fallback using only accepted ('active' or 'resolved') reports
    final acceptedSessionReports = HazardReportService.sessionReports
        .where((r) => HazardReportStatuses.isAcceptedForUserReports(r.status))
        .toList();
    int myReportCount = acceptedSessionReports.length;
    int myPoints = 0;
    for (final r in acceptedSessionReports) {
      myPoints += r.pointsAwarded;
    }

    return <LeaderboardUserEntry>[
      LeaderboardUserEntry(
        userId: currentUserId ?? 'local-user',
        displayName: 'You',
        username: 'you',
        reportCount: myReportCount,
        safetyPoints: myPoints,
        savedRoutesCount: 0,
        allTimePoints: myPoints,
        allTimeReports: myReportCount,
        levelProgress: LevelProgressData.fromTotalPoints(myPoints),
        daysActive: 1,
        isCurrentUser: true,
      ),
    ];
  }

  /// Sorts [entries] according to the selected leaderboard category tab:
  /// - `0`: Safety Points (`safetyPoints` DESC, then `reportCount` DESC)
  /// - `1`: Reports (`reportCount` DESC, then `safetyPoints` DESC)
  /// - `2`: Routes (`savedRoutesCount` DESC, then `safetyPoints` DESC)
  static List<LeaderboardUserEntry> sortEntriesForCategory(
    List<LeaderboardUserEntry> entries,
    int categoryIndex,
  ) {
    final sorted = List<LeaderboardUserEntry>.from(entries);
    sorted.sort((a, b) {
      int cmp;
      switch (categoryIndex) {
        case 1:
          cmp = b.reportCount.compareTo(a.reportCount);
          if (cmp == 0) cmp = b.safetyPoints.compareTo(a.safetyPoints);
          break;
        case 2:
          cmp = b.savedRoutesCount.compareTo(a.savedRoutesCount);
          if (cmp == 0) cmp = b.safetyPoints.compareTo(a.safetyPoints);
          break;
        case 0:
        default:
          cmp = b.safetyPoints.compareTo(a.safetyPoints);
          if (cmp == 0) cmp = b.reportCount.compareTo(a.reportCount);
          break;
      }
      if (cmp != 0) return cmp;
      if (a.isCurrentUser != b.isCurrentUser) {
        return a.isCurrentUser ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return sorted;
  }

  /// Fetches the signed-in user's live gamification stats (report count, total points,
  /// saved routes count, days active, and level progression) for the Profile screen.
  /// Only accepted (`active` or `resolved`) reports are counted.
  Future<UserGamificationStats> fetchCurrentUserGamificationStats() async {
    final userReports = await _hazardReportService.fetchUserReports();
    final acceptedReports = userReports
        .where((r) => HazardReportStatuses.isAcceptedForUserReports(r.status))
        .toList();
    final savedRoutes = await _safeRouteService.fetchSavedRoutes();

    final int reportCount = acceptedReports.length;
    int totalPoints = 0;
    for (final r in acceptedReports) {
      totalPoints += r.pointsAwarded;
    }
    final int savedRoutesCount = savedRoutes.length;

    int daysActive = 1;
    final client = _tryGetClient();
    final currentUser = client?.auth.currentUser;
    if (currentUser != null) {
      final createdAt = DateTime.tryParse(currentUser.createdAt);
      if (createdAt != null) {
        daysActive = DateTime.now().difference(createdAt).inDays + 1;
        if (daysActive < 1) daysActive = 1;
      }
    }

    return UserGamificationStats.fromCounts(
      reportCount: reportCount,
      totalPoints: totalPoints,
      savedRoutesCount: savedRoutesCount,
      daysActive: daysActive,
    );
  }
}

