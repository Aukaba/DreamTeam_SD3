import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/services/hazard_report_service.dart';

void main() {
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

  group('HazardReportService Category Cleaner Tests', () {
    test('cleans emojis from categories to match Supabase ReportTable', () {
      expect(HazardReportService.cleanCategory('🚧 Road damage'), 'Road damage');
      expect(HazardReportService.cleanCategory('🌳 Fallen tree'), 'Fallen tree');
      expect(HazardReportService.cleanCategory('🌊 Flood'), 'Flood');
      expect(HazardReportService.cleanCategory('🚗 Accident'), 'Accident');
      expect(HazardReportService.cleanCategory('🔥 Fire'), 'Fire');
      expect(HazardReportService.cleanCategory('💡 Broken streetlight'), 'Broken streetlight');
      expect(HazardReportService.cleanCategory('🚫 Blocked road'), 'Blocked road');
      expect(HazardReportService.cleanCategory('⚠️ Other'), 'Other');
      expect(HazardReportService.cleanCategory('Road damage'), 'Road damage');
    });
  });
}

