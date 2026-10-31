import 'package:flutter_test/flutter_test.dart';
import 'package:dreamteam_sd3/services/location_service.dart';

void main() {
  test('LocationService default coordinates test', () {
    expect(LocationService.defaultLocation.latitude, 10.3157);
    expect(LocationService.defaultLocation.longitude, 123.8920);
  });
}
