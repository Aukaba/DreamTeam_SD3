import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:dreamteam_sd3/services/cebu_landmark_service.dart';

class StubHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) _handler;
  StubHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = await _handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

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

    test('Online search finds businesses and buildings deterministically with stub client', () async {
      final stubClient = StubHttpClient((request) async {
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response(
            jsonEncode([
              {
                'osm_id': 123456,
                'name': 'Cebu Institute of Technology - University',
                'display_name': 'Cebu Institute of Technology - University, N. Bacalso Ave, Cebu City, Philippines',
                'lat': '10.2944',
                'lon': '123.8811',
                'class': 'amenity',
                'type': 'university',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      final results = await CebuLandmarkService.searchOnline(
        'Cebu Institute of Technology',
        userLocation: userLocation,
        client: stubClient,
      );

      expect(results, isNotEmpty);
      expect(results.first.name, contains('Cebu Institute of Technology'));
      expect(results.first.address, contains('N. Bacalso Ave'));
      expect(results.first.location.latitude, closeTo(10.29, 0.05));
      expect(results.first.location.longitude, closeTo(123.88, 0.05));
      expect(results.first.category, LandmarkCategory.university);
    });

    test('Online search finds Bayanihan neighbourhood deterministically', () async {
      final stubClient = StubHttpClient((request) async {
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response(
            jsonEncode([
              {
                'osm_id': 654321,
                'name': 'Bayanihan',
                'display_name': 'Bayanihan, Quiot, Cebu City, Cebu, 6000, Philippines',
                'lat': '10.2980',
                'lon': '123.8650',
                'class': 'place',
                'type': 'neighbourhood',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      final results = await CebuLandmarkService.searchOnline(
        'Bayanihan',
        userLocation: userLocation,
        client: stubClient,
      );

      expect(results, isNotEmpty);
      expect(results.any((r) => r.name.toLowerCase().contains('bayanihan')), isTrue);
      expect(results.first.category, LandmarkCategory.barangay);
    });

    test('Online search falls back to Photon when Nominatim returns non-200 HTTP error', () async {
      final stubClient = StubHttpClient((request) async {
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response('Too Many Requests', 429);
        }
        if (request.url.host == 'photon.komoot.io') {
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'geometry': {
                    'coordinates': [123.8854, 10.3157],
                  },
                  'properties': {
                    'osm_id': 999888,
                    'name': 'Cebu Provincial Capitol',
                    'street': 'Osmeña Boulevard',
                    'city': 'Cebu City',
                    'osm_key': 'amenity',
                    'osm_value': 'townhall',
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 404);
      });

      final results = await CebuLandmarkService.searchOnline(
        'Capitol',
        userLocation: userLocation,
        client: stubClient,
      );

      expect(results, isNotEmpty);
      expect(results.first.name, 'Cebu Provincial Capitol');
      expect(results.first.category, LandmarkCategory.government);
    });

    test('Online search rejects results outside Cebu bounding box', () async {
      final stubClient = StubHttpClient((request) async {
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response(
            jsonEncode([
              {
                'osm_id': 111222,
                'name': 'Rizal Park Manila',
                'display_name': 'Rizal Park, Manila, Metro Manila, Philippines',
                'lat': '14.5826', // Manila coordinates (outside Cebu: 9.4-11.5)
                'lon': '120.9787',
                'class': 'leisure',
                'type': 'park',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'features': []}), 200);
      });

      final results = await CebuLandmarkService.searchOnline(
        'Rizal Park',
        userLocation: userLocation,
        client: stubClient,
      );

      expect(results, isEmpty);
    });

    test('All landmark items have valid coordinates and icons', () {
      for (final landmark in CebuLandmarkService.landmarks) {
        expect(landmark.name.isNotEmpty, isTrue);
        expect(landmark.address.isNotEmpty, isTrue);
        expect(landmark.location.latitude, inInclusiveRange(9.4, 11.5)); // Cebu latitude range
        expect(landmark.location.longitude, inInclusiveRange(123.0, 124.6)); // Cebu longitude range
        expect(landmark.icon, isNotNull);
        expect(landmark.color, isNotNull);
        expect(landmark.categoryLabel.isNotEmpty, isTrue);
      }
    });
  });
}
