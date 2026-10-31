import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/services/cebu_landmark_service.dart';

void main() {
  group('CebuLandmarkService Comprehensive Search Tests', () {
    const userLocation = LatLng(10.3157, 123.8890); // Near Capitol Site

    test('Search by exact landmark name', () {
      final results = CebuLandmarkService.search('Ayala Center', userLocation: userLocation);
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, contains('Ayala Center Cebu'));
      expect(results.first.category, LandmarkCategory.shopping);
    });

    test('Search is case-insensitive and trims whitespace', () {
      final results = CebuLandmarkService.search('   mAgElLaN   ');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.id, 'magellans_cross');
    });

    test('Search by alias or keyword', () {
      final airportResults = CebuLandmarkService.search('airport');
      expect(airportResults.isNotEmpty, isTrue);
      expect(airportResults.first.id, 'mcia');

      final fuenteResults = CebuLandmarkService.search('fuente');
      expect(fuenteResults.isNotEmpty, isTrue);
      expect(fuenteResults.any((r) => r.id == 'fuente_osmena'), isTrue);

      final itParkResults = CebuLandmarkService.search('bpo');
      expect(itParkResults.isNotEmpty, isTrue);
      expect(itParkResults.first.id, 'cebu_it_park');
    });

    // -------------------------------------------------------------------------
    // BARANGAY LEVEL TESTS
    // -------------------------------------------------------------------------
    test('Search finds Cebu barangays correctly', () {
      final guadalupe = CebuLandmarkService.searchLocal('Guadalupe');
      expect(guadalupe.isNotEmpty, isTrue);
      expect(guadalupe.first.category, LandmarkCategory.barangay);
      expect(guadalupe.first.categoryLabel, 'BARANGAY');
      expect(guadalupe.first.name, contains('Guadalupe'));

      final lahug = CebuLandmarkService.searchLocal('Lahug');
      expect(lahug.isNotEmpty, isTrue);
      expect(lahug.any((r) => r.category == LandmarkCategory.barangay), isTrue);

      final tisa = CebuLandmarkService.searchLocal('Tisa');
      expect(tisa.isNotEmpty, isTrue);
      expect(tisa.any((r) => r.category == LandmarkCategory.barangay), isTrue);

      final mabolo = CebuLandmarkService.searchLocal('Mabolo');
      expect(mabolo.isNotEmpty, isTrue);
      expect(mabolo.any((r) => r.category == LandmarkCategory.barangay), isTrue);
    });

    // -------------------------------------------------------------------------
    // STREET LEVEL TESTS
    // -------------------------------------------------------------------------
    test('Search finds major Cebu streets and avenues', () {
      final colon = CebuLandmarkService.searchLocal('Colon Street');
      expect(colon.isNotEmpty, isTrue);
      expect(colon.first.category, LandmarkCategory.street);
      expect(colon.first.categoryLabel, 'STREET');

      final vRama = CebuLandmarkService.searchLocal('V. Rama');
      expect(vRama.isNotEmpty, isTrue);
      expect(vRama.first.category, LandmarkCategory.street);

      final escario = CebuLandmarkService.searchLocal('Escario');
      expect(escario.isNotEmpty, isTrue);
      expect(escario.any((r) => r.category == LandmarkCategory.street), isTrue);

      final osmena = CebuLandmarkService.searchLocal('Osmeña Boulevard');
      expect(osmena.isNotEmpty, isTrue);
      expect(osmena.any((r) => r.category == LandmarkCategory.street), isTrue);
    });

    // -------------------------------------------------------------------------
    // LOCAL SHOPS, EATERIES, AND PUBLIC MARKETS TESTS
    // -------------------------------------------------------------------------
    test('Search finds local shops, eateries, bakeries, and markets', () {
      final carbon = CebuLandmarkService.searchLocal('Carbon Market');
      expect(carbon.isNotEmpty, isTrue);
      expect(carbon.first.category, LandmarkCategory.shop);
      expect(carbon.first.categoryLabel, 'SHOP / EATERY');

      final taboan = CebuLandmarkService.searchLocal('Taboan');
      expect(taboan.isNotEmpty, isTrue);
      expect(taboan.first.category, LandmarkCategory.shop);

      final lechon = CebuLandmarkService.searchLocal('House of Lechon');
      expect(lechon.isNotEmpty, isTrue);
      expect(lechon.first.category, LandmarkCategory.shop);

      final bakeshop = CebuLandmarkService.searchLocal('Julies Bakeshop');
      expect(bakeshop.isNotEmpty, isTrue);
      expect(bakeshop.first.category, LandmarkCategory.shop);

      final coffee = CebuLandmarkService.searchLocal('Bos Coffee');
      expect(coffee.isNotEmpty, isTrue);
      expect(coffee.first.category, LandmarkCategory.shop);
    });

    test('Search results are sorted by proximity to userLocation', () {
      // User is at Capitol Site (10.3157, 123.8890)
      final results = CebuLandmarkService.search('Hospital', userLocation: userLocation);
      expect(results.length, greaterThanOrEqualTo(2));
      final firstDist = const Distance().distance(userLocation, results[0].location);
      final secondDist = const Distance().distance(userLocation, results[1].location);
      expect(firstDist, lessThanOrEqualTo(secondDist));
    });

    test('Empty or blank search query returns empty list', () {
      expect(CebuLandmarkService.search(''), isEmpty);
      expect(CebuLandmarkService.search('    '), isEmpty);
      expect(CebuLandmarkService.searchLocal(''), isEmpty);
    });

    test('Non-matching query returns empty list', () {
      final results = CebuLandmarkService.searchLocal('xyzNonExistentPlace123');
      expect(results, isEmpty);
    });

    test('Online search finds businesses and buildings dynamically', () async {
      final results = await CebuLandmarkService.searchOnline(
        'Cebu Institute of Technology',
        userLocation: userLocation,
      );
      if (results.isNotEmpty) {
        expect(results.first.name, contains('Cebu Institute of Technology'));
        expect(results.first.address.isNotEmpty, isTrue);
        expect(results.first.location.latitude, isNotNull);
        expect(results.first.location.longitude, isNotNull);
      }
    });

    test('Online search finds Bayanihan neighbourhood', () async {
      final results = await CebuLandmarkService.searchOnline(
        'Bayanihan',
        userLocation: userLocation,
      );
      if (results.isNotEmpty) {
        expect(results.any((r) => r.name.toLowerCase().contains('bayanihan')), isTrue);
      }
    });

    test('All landmark items have valid coordinates and icons', () {
      for (final landmark in CebuLandmarkService.landmarks) {
        expect(landmark.name.isNotEmpty, isTrue);
        expect(landmark.address.isNotEmpty, isTrue);
        expect(landmark.location.latitude, inInclusiveRange(9.5, 11.5)); // Cebu latitude range
        expect(landmark.location.longitude, inInclusiveRange(123.0, 124.5)); // Cebu longitude range
        expect(landmark.icon, isNotNull);
        expect(landmark.color, isNotNull);
        expect(landmark.categoryLabel.isNotEmpty, isTrue);
      }
    });
  });
}
