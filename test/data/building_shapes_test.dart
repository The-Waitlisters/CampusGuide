import 'package:flutter_test/flutter_test.dart';
import 'package:proj/data/building_data.dart';

void main() {
  test('All campus buildings have a boundary', () {
    for (final building in campusBuildings) {
      expect(
        building.boundary.isNotEmpty,
        true,
        reason: 'Building ${building.name} has no boundary',
      );
    }
  });

  test('All campus buildings have valid polygon shapes', () {
    for (final building in campusBuildings) {
      expect(
        building.boundary.length >= 3,
        true,
        reason: 'Building ${building.name} does not form a valid polygon',
      );
    }
  });

  test('All building boundary coordinates are valid', () {
    for (final building in campusBuildings) {
      for (final point in building.boundary) {
        expect(point.latitude.abs() <= 90, true);
        expect(point.longitude.abs() <= 180, true);
      }
    }
  });
}
