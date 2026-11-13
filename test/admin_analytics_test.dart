import 'package:dreamteam_sd3/admin_screens/admin_dashboard_screen.dart';
import 'package:dreamteam_sd3/admin_screens/admin_settings_screens.dart';
import 'package:dreamteam_sd3/services/admin_analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AdminAnalyticsRawSnapshot buildSampleSnapshot(DateTime anchor) {
    final now = anchor;
    return AdminAnalyticsRawSnapshot(
      reports: <Map<String, dynamic>>[
        // Active High flooding on Colon Street (verified in 20m)
        {
          'reportID': 'r1',
          'hazard_category': 'flooding',
          'detected_hazard': 'Knee-deep Flood',
          'severity_level': 'High',
          'confidence': 94,
          'location_address':
              'Colon Street, Kalubihan, Cebu City, Central Visayas, 6000, Philippines',
          'status': 'active',
          'created_at': now.subtract(const Duration(hours: 5)).toIso8601String(),
          'verified_at':
              now.subtract(const Duration(hours: 4, minutes: 40)).toIso8601String(),
        },
        // Active Medium Flooding on Colon Street (verified in 40m)
        {
          'reportID': 'r2',
          'hazard_category': 'Flooding',
          'detected_hazard': 'Waterlogging',
          'severity_level': 'Medium',
          'confidence': 82,
          'location_address': 'Colon Street, Cebu City, Philippines',
          'status': 'active',
          'created_at': now.subtract(const Duration(days: 1, hours: 3)).toIso8601String(),
          'verified_at':
              now.subtract(const Duration(days: 1, hours: 2, minutes: 20)).toIso8601String(),
        },
        // Active Low Roadwork on Gorordo Ave
        {
          'reportID': 'r3',
          'hazard_category': 'Roadwork',
          'detected_hazard': 'Lane Cone Obstruction',
          'severity_level': 'Low',
          'confidence': 68,
          'location_address': 'Gorordo Avenue, Kamputhaw, Cebu City',
          'status': 'active',
          'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
          'verified_at':
              now.subtract(const Duration(days: 1, hours: 23, minutes: 50)).toIso8601String(),
        },
        // Pending report (needs triage) - should NOT add noise if generic address
        {
          'reportID': 'r4',
          'hazard_category': 'Accident',
          'detected_hazard': 'Minor Collision',
          'severity_level': 'High',
          'confidence': 75,
          'location_address': 'Current location',
          'status': 'pending',
          'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        // Resolved Accident (within 7d, resolved in 4 hours)
        {
          'reportID': 'r5',
          'hazard_category': 'Accident',
          'detected_hazard': 'Stalled Truck',
          'severity_level': 'High',
          'confidence': 91,
          'location_address': 'Osmena Boulevard, Capitol Site, Cebu City',
          'status': 'resolved',
          'created_at': now.subtract(const Duration(days: 3, hours: 6)).toIso8601String(),
          'verified_at':
              now.subtract(const Duration(days: 3, hours: 5, minutes: 30)).toIso8601String(),
          'resolved_at':
              now.subtract(const Duration(days: 3, hours: 2)).toIso8601String(),
        },
        // Older resolved Pothole (14 days ago -> excluded from 7d, included in 30d/all)
        {
          'reportID': 'r6',
          'hazard_category': 'Pothole',
          'detected_hazard': 'Deep Pothole',
          'severity_level': 'Medium',
          'confidence': 42,
          'location_address': '10.3157, 123.8854', // raw coords ignored for hotspot
          'status': 'resolved',
          'created_at': now.subtract(const Duration(days: 14, hours: 8)).toIso8601String(),
          'verified_at':
              now.subtract(const Duration(days: 14, hours: 7)).toIso8601String(),
          'resolved_at':
              now.subtract(const Duration(days: 14)).toIso8601String(),
        },
        // Rejected report
        {
          'reportID': 'r7',
          'hazard_category': 'Other',
          'detected_hazard': 'Blurred Photo',
          'severity_level': 'Low',
          'confidence': 20,
          'location_address': 'Banilad Road, Cebu City',
          'status': 'rejected',
          'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
      ],
      resolutions: <Map<String, dynamic>>[
        {'id': 'res1', 'report_id': 'r5', 'status': 'approved'},
        {'id': 'res2', 'report_id': 'r1', 'status': 'pending'},
        {'id': 'res3', 'report_id': 'r2', 'status': 'rejected'},
      ],
    );
  }

  group('AdminSafetyAnalytics Unit Tests', () {
    test('computes severity distribution, SLAs, categories, hotspots, and 7d velocity', () {
      final anchor = DateTime(2026, 11, 13, 15, 0);
      final snapshot = buildSampleSnapshot(anchor);
      final analytics = snapshot.compute(
        timeframe: AnalyticsTimeframe.allTime,
        now: anchor,
      );

      // Live active severity breakdown
      expect(analytics.activeHazardsCount, 3);
      expect(analytics.activeHighCount, 1);
      expect(analytics.activeMediumCount, 1);
      expect(analytics.activeLowCount, 1);
      expect(analytics.overallRiskLabel, 'Elevated Risk');

      // Triage & clearance queue
      expect(analytics.pendingReportsCount, 1);
      expect(analytics.pendingResolutionProofsCount, 1);
      expect(analytics.totalActionQueue, 2);

      // Resolution rate: 2 resolved / (3 active + 2 resolved) = 40%
      expect(analytics.resolutionRatePercent, 40);
      // Signal approval: 5 valid / (5 valid + 1 rejected) = 83%
      expect(analytics.signalApprovalPercent, 83);

      // Verify turnaround minutes: [20, 40, 10, 30, 60] -> sorted [10,20,30,40,60] -> median 30m
      expect(analytics.medianVerifyMinutes, 30);
      expect(analytics.formattedMedianVerify, '30m');
      // Resolution hours: [4.0, 8.0] -> median 6.0h
      expect(analytics.medianResolutionHours, closeTo(6.0, 0.01));
      expect(analytics.formattedMedianClear, '6.0h');

      // Categories merge "flooding" + "Flooding" and sort by active first
      expect(analytics.topCategories.first.category, 'Flooding');
      expect(analytics.topCategories.first.activeCount, 2);
      expect(analytics.topCategories.first.totalCount, 2);

      // Hotspots extract Colon Street cleanly, ignore "Current location" & raw coords
      expect(analytics.topHotspots.first.areaLabel, 'Colon Street');
      expect(analytics.topHotspots.first.activeCount, 2);
      expect(analytics.topHotspots.first.totalCount, 2);
      expect(
        analytics.topHotspots.any((h) => h.areaLabel.contains('10.3157')),
        isFalse,
      );
      expect(
        analytics.topHotspots.any((h) => h.areaLabel == 'Current location'),
        isFalse,
      );

      // AI confidence buckets (>=80: 3, 50..79: 2, <50: 2)
      expect(analytics.highConfidenceCount, 3);
      expect(analytics.mediumConfidenceCount, 2);
      expect(analytics.lowConfidenceCount, 2);

      // 7-day trend always has 7 buckets
      expect(analytics.last7DaysTrend.length, 7);
      expect(analytics.sevenDayReportedTotal, 6);
      expect(analytics.sevenDayResolvedTotal, 1);

      // Scoped 7D excludes 14-day-old pothole report
      final sevenDay = snapshot.compute(
        timeframe: AnalyticsTimeframe.sevenDays,
        now: anchor,
      );
      expect(sevenDay.scopedReportsCount, 6);
      expect(sevenDay.scopedResolvedCount, 1);
    });

    test(
      'deduplicates active hazards by 4-decimal (lat, lng, category) and filters resolution proofs by timeframe',
      () {
        final anchor = DateTime(2026, 11, 13, 15, 0);
        final snapshot = AdminAnalyticsRawSnapshot(
          reports: <Map<String, dynamic>>[
            // Primary active Flooding on Colon Street
            {
              'reportID': 'd1',
              'hazard_category': 'flooding',
              'detected_hazard': 'Flooding',
              'severity_level': 'High',
              'confidence': 92,
              'latitude': 10.29811,
              'longitude': 123.89811,
              'location_address': 'Colon Street, Cebu City',
              'status': 'active',
              'created_at':
                  anchor.subtract(const Duration(hours: 2)).toIso8601String(),
            },
            // Duplicate active Flooding within same 4-decimal grid (10.2981, 123.8981)
            {
              'reportID': 'd2',
              'hazard_category': 'Flooding',
              'detected_hazard': 'Waterlogging',
              'severity_level': 'High',
              'confidence': 85,
              'latitude': 10.29814,
              'longitude': 123.89814,
              'location_address': 'Colon Street, Cebu City',
              'status': 'active',
              'created_at':
                  anchor.subtract(const Duration(hours: 1)).toIso8601String(),
            },
            // Distinct coordinate active Flooding on Mango Avenue
            {
              'reportID': 'd3',
              'hazard_category': 'Flooding',
              'detected_hazard': 'Street Flood',
              'severity_level': 'Medium',
              'confidence': 80,
              'latitude': 10.3105,
              'longitude': 123.8912,
              'location_address': 'General Maxilom Avenue, Cebu City',
              'status': 'active',
              'created_at':
                  anchor.subtract(const Duration(hours: 3)).toIso8601String(),
            },
            // Same coordinates as d1/d2, but different category (Roadwork) -> counts separately
            {
              'reportID': 'd4',
              'hazard_category': 'Roadwork',
              'detected_hazard': 'Road Excavation',
              'severity_level': 'Low',
              'confidence': 70,
              'latitude': 10.29812,
              'longitude': 123.89812,
              'location_address': 'Colon Street, Cebu City',
              'status': 'active',
              'created_at':
                  anchor.subtract(const Duration(hours: 4)).toIso8601String(),
            },
            // Active report with missing coordinates -> still counts normally
            {
              'reportID': 'd5',
              'hazard_category': 'Pothole',
              'detected_hazard': 'Deep Pothole',
              'severity_level': 'Low',
              'confidence': 65,
              'location_address': 'Gorordo Avenue, Cebu City',
              'status': 'active',
              'resolution_status': 'pending',
              'created_at':
                  anchor.subtract(const Duration(hours: 5)).toIso8601String(),
            },
            // Active report carrying fallback resolution_status='pending'
            {
              'reportID': 'd6',
              'hazard_category': 'Other',
              'detected_hazard': 'Debris',
              'severity_level': 'Low',
              'confidence': 60,
              'latitude': 10.3201,
              'longitude': 123.9055,
              'location_address': 'Banilad Road, Cebu City',
              'status': 'active',
              'resolution_status': 'pending',
              'created_at':
                  anchor.subtract(const Duration(days: 10)).toIso8601String(),
            },
          ],
          resolutions: <Map<String, dynamic>>[
            // Recent approved proof (2 days ago -> in 7D, 30D, ALL)
            {
              'id': 'p1',
              'report_id': 'd1',
              'status': 'approved',
              'created_at':
                  anchor.subtract(const Duration(days: 2)).toIso8601String(),
              'verified_at':
                  anchor.subtract(const Duration(days: 2)).toIso8601String(),
            },
            // Older rejected proof (20 days ago -> in 30D and ALL, excluded from 7D)
            {
              'id': 'p2',
              'report_id': 'd3',
              'status': 'rejected',
              'created_at':
                  anchor.subtract(const Duration(days: 20)).toIso8601String(),
              'verified_at':
                  anchor.subtract(const Duration(days: 20)).toIso8601String(),
            },
            // Older pending proof (45 days ago -> in ALL only, excluded from 7D/30D card,
            // yet live pendingResolutionProofsCount keeps max(all-time proofs, fallback))
            {
              'id': 'p3',
              'report_id': 'd4',
              'status': 'pending',
              'created_at':
                  anchor.subtract(const Duration(days: 45)).toIso8601String(),
            },
          ],
        );

        final allTime = snapshot.compute(
          timeframe: AnalyticsTimeframe.allTime,
          now: anchor,
        );

        // d1 & d2 collapse into 1 active incident -> 5 unique active hazards total
        expect(allTime.activeHazardsCount, 5);
        expect(allTime.activeHighCount, 1); // d1+d2 combined once
        expect(allTime.activeMediumCount, 1); // d3
        expect(allTime.activeLowCount, 3); // d4, d5, d6

        final floodingStat =
            allTime.topCategories.firstWhere((c) => c.category == 'Flooding');
        expect(floodingStat.activeCount, 2); // (d1/d2) + d3

        final colonHotspot =
            allTime.topHotspots.firstWhere((h) => h.areaLabel == 'Colon Street');
        expect(colonHotspot.activeCount, 2); // (d1/d2 flooding) + d4 roadwork

        // Live queue takes max(proofsPendingAllTime=1, fallbackPendingResolutions=2) = 2
        expect(allTime.pendingResolutionProofsCount, 2);
        expect(allTime.resolutionProofsApproved, 1);
        expect(allTime.resolutionProofsPending, 1);
        expect(allTime.resolutionProofsRejected, 1);

        // Switching to 7D filters Resolution Proofs card counts while preserving live queue
        final sevenDays = snapshot.compute(
          timeframe: AnalyticsTimeframe.sevenDays,
          now: anchor,
        );
        expect(sevenDays.pendingResolutionProofsCount, 2);
        expect(sevenDays.resolutionProofsApproved, 1);
        expect(sevenDays.resolutionProofsPending, 0);
        expect(sevenDays.resolutionProofsRejected, 0);

        final thirtyDays = snapshot.compute(
          timeframe: AnalyticsTimeframe.thirtyDays,
          now: anchor,
        );
        expect(thirtyDays.resolutionProofsApproved, 1);
        expect(thirtyDays.resolutionProofsPending, 0);
        expect(thirtyDays.resolutionProofsRejected, 1);
      },
    );
  });

  group('Admin Analytics UI Widget Tests', () {
    testWidgets(
      'AdminDashboardScreen renders Hazard operations card across viewports without overflow',
      (tester) async {
        final snapshot = buildSampleSnapshot(DateTime.now());

        for (final size in const [
          Size(390, 844),
          Size(430, 932),
          Size(1280, 900),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            MaterialApp(
              home: AdminDashboardScreen(
                analyticsLoader: () async => snapshot,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Hazard operations.'), findsOneWidget);
          expect(find.text('Cleared Rate'), findsOneWidget);
          expect(find.text('Review Queue'), findsOneWidget);
          expect(find.text('Median Verify'), findsNothing);
          expect(find.text('Top Hazard Categories'), findsOneWidget);
          expect(find.textContaining('Top hotspot: Colon Street'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'AdminAnalyticsScreen renders practical analytics and switches timeframe windows',
      (tester) async {
        final snapshot = buildSampleSnapshot(DateTime.now());

        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AdminAnalyticsScreen(
              initialSnapshot: snapshot,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Analytics Overview'), findsOneWidget);
        expect(find.text('Active Hazards on Map'), findsOneWidget);
        expect(find.text('Pending Review Queue'), findsOneWidget);
        expect(find.text('Cleared Rate'), findsOneWidget);
        expect(find.text('Clearance Time'), findsOneWidget);
        expect(find.textContaining('Median verify'), findsNothing);
        expect(find.text('7-Day Incident & Clearance Trend'), findsOneWidget);
        expect(find.text('Top Hazard Hotspots by Area'), findsOneWidget);
        expect(find.text('AI Screening & Community Clearances'), findsOneWidget);
        expect(find.text('Colon Street'), findsOneWidget);

        // All-time shows 2 cleared of 5 (40%)
        expect(find.text('40%'), findsOneWidget);

        // Switch timeframe to Last 7 days -> 1 cleared of 4 (25%)
        await tester.tap(find.text('Last 7 days'));
        await tester.pumpAndSettle();
        expect(find.text('25%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
