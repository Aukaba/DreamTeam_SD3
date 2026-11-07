import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/map_screen.dart';
import 'package:dreamteam_sd3/services/gemini_hazard_service.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';

void main() {
  setUp(() {
    HazardReportService.clearSessionReports();
  });

  group('UUIDv4 Generator Tests', () {
    test('generates valid RFC 4122 version 4 UUID', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      for (int i = 0; i < 20; i++) {
        final id = generateUuidV4();
        expect(id.length, 36);
        expect(uuidRegex.hasMatch(id), isTrue, reason: 'Failed for UUID: $id');
      }
    });

    test('generates unique UUIDs on subsequent calls', () {
      final id1 = generateUuidV4();
      final id2 = generateUuidV4();
      expect(id1, isNot(equals(id2)));
    });
  });

  group('HazardReportService Category Cleaner & Row Parsing Tests', () {
    test('cleans emojis from categories to match Supabase ReportTable', () {
      expect(HazardReportService.cleanCategory('🚧 Road damage'), 'Road damage');
      expect(HazardReportService.cleanCategory('🌳 Fallen tree'), 'Fallen tree');
      expect(HazardReportService.cleanCategory('🌊 Flood'), 'Flood');
      expect(HazardReportService.cleanCategory('🚗 Accident'), 'Accident');
      expect(HazardReportService.cleanCategory('🔥 Fire'), 'Fire');
      expect(
        HazardReportService.cleanCategory('💡 Broken streetlight'),
        'Broken streetlight',
      );
      expect(
        HazardReportService.cleanCategory('🚫 Blocked road'),
        'Blocked road',
      );
      expect(HazardReportService.cleanCategory('⚠️ Other'), 'Other');
      expect(HazardReportService.cleanCategory('Road damage'), 'Road damage');
    });

    test('parses ReportTable rows accurately into HazardReportData', () {
      final row = {
        'reportID': 'rep-001',
        'hazard_category': 'Broken streetlight',
        'detected_hazard': 'Dark Corner Streetlight Out',
        'description': 'Streetlight completely out near pedestrian crossing.',
        'severity_level': 'High',
        'confidence': 96,
        'location_address': 'Osmena Blvd, Cebu City',
        'latitude': 10.3102,
        'longitude': 123.8914,
        'image_url': 'https://example.com/photo.jpg',
        'status': 'active',
        'created_at': '2026-11-05T17:19:52Z',
      };

      final parsed = HazardReportData.fromReportRow(row);
      expect(parsed.reportId, 'rep-001');
      expect(parsed.category, HazardCategories.brokenStreetlight);
      expect(parsed.securityLevel, HazardSecurityLevels.high);
      expect(parsed.title, 'Dark Corner Streetlight Out');
      expect(
        parsed.description,
        'Streetlight completely out near pedestrian crossing.',
      );
      expect(parsed.status, 'active');
      expect(parsed.address, 'Osmena Blvd, Cebu City');
      expect(parsed.location, const LatLng(10.3102, 123.8914));
      expect(parsed.confidence, 96);
    });

    test('session reports recorded from modals are returned and deduplicated by fetchReports', () async {
      final service = HazardReportService();
      final report = HazardReportData(
        reportId: 'home-modal-report-1',
        category: HazardCategories.roadDamage,
        securityLevel: HazardSecurityLevels.medium,
        title: 'Deep Pothole on Escario',
        description: 'Large pothole near crosswalk',
        address: 'Escario St, Cebu City',
        location: const LatLng(10.3168, 123.8891),
        timestamp: DateTime.now(),
      );

      HazardReportService.recordSubmittedReport(report);
      HazardReportService.recordSubmittedReport(
        report.copyWith(title: 'Updated Deep Pothole on Escario'),
      );

      final fetched = await service.fetchReports();
      expect(fetched.length, 1);
      expect(fetched.first.reportId, 'home-modal-report-1');
      expect(fetched.first.title, 'Updated Deep Pothole on Escario');
    });
  });

  group('MapScreen Hazard Category Classification Tests', () {
    test('broken streetlight maps to Safety (3) rather than Roadwork (1)', () {
      final emojiResult =
          MapScreen.classifyHazardForMap(HazardCategories.brokenStreetlight);
      expect(emojiResult.filterCategoryIndex, 3);
      expect(emojiResult.icon, Icons.lightbulb_outline_rounded);

      final dbResult = MapScreen.classifyHazardForMap('Broken streetlight');
      expect(dbResult.filterCategoryIndex, 3);
      expect(dbResult.icon, Icons.lightbulb_outline_rounded);
    });

    test('maps roadwork, flooding, and safety categories explicitly', () {
      expect(
        MapScreen.classifyHazardForMap(HazardCategories.fallenTree),
        (filterCategoryIndex: 1, icon: Icons.construction_rounded),
      );
      expect(
        MapScreen.classifyHazardForMap(HazardCategories.roadDamage),
        (filterCategoryIndex: 1, icon: Icons.construction_rounded),
      );
      expect(
        MapScreen.classifyHazardForMap(HazardCategories.blockedRoad),
        (filterCategoryIndex: 1, icon: Icons.construction_rounded),
      );
      expect(
        MapScreen.classifyHazardForMap(HazardCategories.flood),
        (filterCategoryIndex: 2, icon: Icons.water_drop_rounded),
      );
      expect(
        MapScreen.classifyHazardForMap(HazardCategories.accident),
        (filterCategoryIndex: 3, icon: Icons.warning_amber_rounded),
      );
      expect(
        MapScreen.classifyHazardForMap(HazardCategories.fire),
        (filterCategoryIndex: 3, icon: Icons.warning_amber_rounded),
      );
      expect(
        MapScreen.classifyHazardForMap(HazardCategories.other),
        (filterCategoryIndex: 3, icon: Icons.warning_amber_rounded),
      );
    });
  });
}
