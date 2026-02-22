import 'package:flutter_test/flutter_test.dart';

import 'package:proj/data/data_parser.dart';
import 'package:proj/models/campus_building.dart';

void main() {
  test('All buildings have a short name for pop-up display', () async {
    TestWidgetsFlutterBinding.ensureInitialized();


    final allBuildings = await DataParser().getBuildingInfoFromJSON();
    
    for (final CampusBuilding building in allBuildings) {
      expect(
        building.name.trim().isNotEmpty,
        true,
        reason: 'Building name should not be empty',
      );
    }
  });

  test('Buildings with full names have valid pop-up titles', () async {
    TestWidgetsFlutterBinding.ensureInitialized();


    final allBuildings = await DataParser().getBuildingInfoFromJSON();
    final buildingsWithFullNames = allBuildings.where(
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

  test('Building descriptions are safe for pop-up rendering', () async {
    TestWidgetsFlutterBinding.ensureInitialized();


    final allBuildings = await DataParser().getBuildingInfoFromJSON();
    for (final building in allBuildings) {
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

  test('Pop-up information access does not throw for any building', () async {
    TestWidgetsFlutterBinding.ensureInitialized();


    final allBuildings = await DataParser().getBuildingInfoFromJSON();
    for (final building in allBuildings) {
      expect(() {
        building.name;
        building.fullName;
        building.description;
      }, returnsNormally);
    }
  });
}
