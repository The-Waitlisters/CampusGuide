import 'package:flutter_test/flutter_test.dart';
import 'package:proj/data/building_data.dart';
import 'package:proj/models/campus_building.dart';

void main() {
  test('All buildings have a short name for pop-up display', () {
    for (final CampusBuilding building in campusBuildings) {
      expect(
        building.name.trim().isNotEmpty,
        true,
        reason: 'Building name should not be empty',
      );
    }
  });

  test('Buildings with full names have valid pop-up titles', () {
    final buildingsWithFullNames = campusBuildings.where(
      (b) => b.fullName != null,
    );

    for (final building in buildingsWithFullNames) {
      expect(
        building.fullName!.trim().isNotEmpty,
        true,
        reason: 'Full name should not be empty when provided',
      );
    }
  });

  test('Building descriptions are safe for pop-up rendering', () {
    for (final building in campusBuildings) {
      final description = building.description;

      if (description != null) {
        expect(
          description.trim().isNotEmpty,
          true,
          reason: 'Description should not be empty when provided',
        );
      }
    }
  });

  test('Pop-up information access does not throw for any building', () {
    for (final building in campusBuildings) {
      expect(() {
        building.name;
        building.fullName;
        building.description;
      }, returnsNormally);
    }
  });
}
