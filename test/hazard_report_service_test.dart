import 'dart:typed_data';
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

  group('Hazard Resolution Submission & Status Validation Tests (Comments 3, 9, 16)', () {
    test('submitHazardResolutionReport throws ArgumentError on empty reportId or bytes', () async {
      final service = HazardReportService();
      expect(
        () => service.submitHazardResolutionReport(
          reportId: '',
          category: HazardCategories.accident,
          title: 'Accident',
          description: '',
          securityLevel: HazardSecurityLevels.high,
          locationAddress: 'Cebu City',
          resolutionImageBytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => service.submitHazardResolutionReport(
          reportId: 'valid-report-id',
          category: HazardCategories.accident,
          title: 'Accident',
          description: '',
          securityLevel: HazardSecurityLevels.high,
          locationAddress: 'Cebu City',
          resolutionImageBytes: Uint8List(0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('submitHazardResolutionReport throws StateError and aborts without inserting when upload fails (Comment 3)', () async {
      final service = HazardReportService();
      // Without a valid Supabase client / storage upload, uploadHazardPhoto returns null,
      // which must fail submission rather than inserting a pending record with local:// (Comment 3)
      expect(
        () => service.submitHazardResolutionReport(
          reportId: 'hazard-without-upload-123',
          category: HazardCategories.flood,
          title: 'Flooded Underpass',
          description: 'Water drained',
          securityLevel: HazardSecurityLevels.medium,
          locationAddress: 'Mambaling, Cebu City',
          resolutionImageBytes: Uint8List.fromList([137, 80, 78, 71]),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        HazardReportService.hasPendingResolution('hazard-without-upload-123'),
        isFalse,
      );
    });

    test('HazardReportStatuses only counts active and resolved as accepted for user reports', () {
      expect(HazardReportStatuses.isAcceptedForUserReports('active'), isTrue);
      expect(HazardReportStatuses.isAcceptedForUserReports('resolved'), isTrue);
      expect(HazardReportStatuses.isAcceptedForUserReports('pending'), isFalse);
      expect(HazardReportStatuses.isAcceptedForUserReports('rejected'), isFalse);
      expect(HazardReportStatuses.isAcceptedForUserReports('archived'), isFalse);
      expect(HazardReportStatuses.isAcceptedForUserReports(null), isFalse);
    });

    test('parses hazard_resolution_reports rows accurately', () {
      final row = {
        'id': 'res-101',
        'report_id': 'rep-777',
        'reported_by': 'usr-555',
        'hazard_category': 'Road damage',
        'detected_hazard': 'Repaired Pothole',
        'hazard_description': 'Asphalt patch completed',
        'severity_level': 'High',
        'location_address': 'Gorordo Ave, Cebu City',
        'latitude': 10.3200,
        'longitude': 123.8950,
        'original_image_url': 'https://example.com/orig.jpg',
        'resolution_image_url': 'https://example.com/res.jpg',
        'resolution_note': 'Road is now clear',
        'status': 'pending',
        'created_at': '2026-11-09T12:00:00Z',
      };

      final data = HazardResolutionReportData.fromRow(row);
      expect(data.id, 'res-101');
      expect(data.reportId, 'rep-777');
      expect(data.reportedBy, 'usr-555');
      expect(data.hazardCategory, HazardCategories.roadDamage);
      expect(data.detectedHazard, 'Repaired Pothole');
      expect(data.hazardDescription, 'Asphalt patch completed');
      expect(data.severityLevel, HazardSecurityLevels.high);
      expect(data.locationAddress, 'Gorordo Ave, Cebu City');
      expect(data.location, const LatLng(10.3200, 123.8950));
      expect(data.originalImageUrl, 'https://example.com/orig.jpg');
      expect(data.resolutionImageUrl, 'https://example.com/res.jpg');
      expect(data.resolutionNote, 'Road is now clear');
      expect(data.status, 'pending');
      expect(data.pointsAwarded, 1);
    });

    test('accepts both approved and resolved statuses for +1 safety point', () {
      expect(HazardResolutionReportData.isAcceptedStatus('approved'), isTrue);
      expect(HazardResolutionReportData.isAcceptedStatus('resolved'), isTrue);
      expect(HazardResolutionReportData.isAcceptedStatus('RESOLVED'), isTrue);
      expect(HazardResolutionReportData.isAcceptedStatus('pending'), isFalse);
      expect(HazardResolutionReportData.isAcceptedStatus('rejected'), isFalse);

      final resolvedRow = HazardResolutionReportData.fromRow({
        'id': 'res-202',
        'report_id': 'rep-888',
        'reported_by': 'usr-123',
        'hazard_category': 'Flood',
        'detected_hazard': 'Drained Road',
        'severity_level': 'High',
        'location_address': 'Colon St, Cebu City',
        'resolution_image_url': 'https://example.com/res2.jpg',
        'status': 'resolved',
        'points_awarded': 1,
        'created_at': '2026-11-12T10:00:00Z',
      });

      expect(resolvedRow.status, 'approved');
      expect(resolvedRow.pointsAwarded, 1);
      expect(
        HazardResolutionReportData.isAcceptedStatus(resolvedRow.status),
        isTrue,
      );
    });

    test('deduplicates active reports within same category and 4-decimal grid', () {
      final now = DateTime.now();
      final deduped = HazardReportService.deduplicateActiveByLocation([
        HazardReportData(
          reportId: 'dup-a',
          category: 'Flood',
          securityLevel: 'High',
          title: 'Flood Report A',
          description: '',
          address: 'Cebu',
          location: const LatLng(10.315712, 123.885412),
          status: 'active',
          timestamp: now,
        ),
        HazardReportData(
          reportId: 'dup-b',
          category: ' flood ',
          securityLevel: 'Medium',
          title: 'Flood Report B (GPS drift ~4m)',
          description: '',
          address: 'Cebu',
          location: const LatLng(10.315741, 123.885441),
          status: 'active',
          timestamp: now.subtract(const Duration(minutes: 1)),
        ),
        HazardReportData(
          reportId: 'diff-cat',
          category: 'Fire',
          securityLevel: 'High',
          title: 'Fire at same spot',
          description: '',
          address: 'Cebu',
          location: const LatLng(10.315712, 123.885412),
          status: 'active',
          timestamp: now,
        ),
        HazardReportData(
          reportId: 'diff-loc',
          category: 'Flood',
          securityLevel: 'Low',
          title: 'Flood 200m away',
          description: '',
          address: 'Cebu',
          location: const LatLng(10.317500, 123.885412),
          status: 'active',
          timestamp: now,
        ),
      ]);

      expect(
        deduped.map((r) => r.reportId).toList(),
        <String?>['dup-a', 'diff-cat', 'diff-loc'],
      );
    });
  });
}
