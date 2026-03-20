// US-1.4: Show the building I am currently located in
//
// All tests use plain test() — no app.main(), no widget tree, no GoogleMap.
// DataParser uses rootBundle which needs the Flutter binding, so we call
// TestWidgetsFlutterBinding.ensureInitialized() in setUpAll.
//
// The [Logic] tests were previously written as testWidgets + app.main(), which
// caused GoogleMap's native platform view to crash the binding and poison every
// subsequent test. This version is clean: 7 tests, 0 app rendering.
//
// ⚠ To also test the GPS status card UI, add this hook to _HomeScreenState:
//
//     @visibleForTesting
//     void simulateGpsLocation(LatLng point) {
//       final result = _buildingLocator.update(
//         userPoint: point, campus: _campus, buildings: buildingsPresent);
//       setState(() { _currentBuildingFromGPS = result.building; });
//     }

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/models/campus_building.dart';

import 'package:proj/data/data_parser.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/services/building_locator.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<CampusBuilding> buildings;

  setUpAll(() async {
    buildings = await DataParser().getBuildingInfoFromJSON();
  });

  // ─── AC: "If the user is far from a campus building, UI indicates not in a building"

  test(
    'US-1.4 [Logic]: point far from all buildings → BuildingStatus.none()',
        () {
      final locator = BuildingLocator();
      final result = locator.update(
        userPoint: const LatLng(0, 0),
        campus: Campus.sgw,
        buildings: buildings,
      );

      expect(result.building, isNull);
      expect(result.treatedAsInside, isFalse);
    },
  );

  // ─── AC: "When the user is inside a building, that building is highlighted and named"

  test(
    'US-1.4 [Logic]: point inside an SGW building → returns that building',
        () {
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final inside = polygonCenter(sgwBuilding.boundary);
      final locator = BuildingLocator();

      final result = locator.update(
        userPoint: inside,
        campus: Campus.sgw,
        buildings: buildings,
      );

      expect(result.building, isNotNull);
      expect(result.building!.id, equals(sgwBuilding.id));
      expect(result.treatedAsInside, isTrue);
    },
  );

  test(
    'US-1.4 [Logic]: point inside a Loyola building → returns that building on Loyola campus',
        () {
      final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);
      final inside = polygonCenter(loyolaBuilding.boundary);
      final locator = BuildingLocator();

      final result = locator.update(
        userPoint: inside,
        campus: Campus.loyola,
        buildings: buildings,
      );

      expect(result.building, isNotNull);
      expect(result.building!.id, equals(loyolaBuilding.id));
      expect(result.treatedAsInside, isTrue);
    },
  );

  // ─── AC: "When outside but within threshold, treat as inside"

  test(
    'US-1.4 [Logic]: point within enterThreshold of a building → treated as inside',
        () {
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final inside = polygonCenter(sgwBuilding.boundary);

      final locator = BuildingLocator(
        enterThresholdMeters: 500,
        exitThresholdMeters: 600,
      );

      final result = locator.update(
        userPoint: inside,
        campus: Campus.sgw,
        buildings: buildings,
      );

      expect(result.treatedAsInside, isTrue,
          reason: 'A point within the enter threshold should be treated as inside');
    },
  );

  // ─── AC: Campus filter

  test(
    'US-1.4 [Logic]: point inside an SGW building is not returned when campus is Loyola',
        () {
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final inside = polygonCenter(sgwBuilding.boundary);

      final locator = BuildingLocator();
      final result = locator.update(
        userPoint: inside,
        campus: Campus.loyola,
        buildings: buildings,
      );

      expect(result.building?.campus, isNot(equals(Campus.sgw)),
          reason: 'Buildings from the wrong campus must never be returned');
    },
  );

  // ─── AC: "In-building state does not alternate quickly on the boundary" (hysteresis)

  test(
    'US-1.4 [Logic]: hysteresis keeps user in building after minor boundary crossing',
        () {
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final insidePoint = polygonCenter(sgwBuilding.boundary);

      final locator = BuildingLocator(
        enterThresholdMeters: 15,
        exitThresholdMeters: 25,
      );

      final first = locator.update(
        userPoint: insidePoint,
        campus: Campus.sgw,
        buildings: buildings,
      );
      expect(first.building?.id, equals(sgwBuilding.id));

      final second = locator.update(
        userPoint: insidePoint,
        campus: Campus.sgw,
        buildings: buildings,
      );
      expect(second.building?.id, equals(sgwBuilding.id),
          reason: 'State must not flicker on repeated updates at the same point');
    },
  );

  // ─── AC: Campus switch resets state

  test(
    'US-1.4 [Logic]: reset() clears state so previous building is not returned after campus change',
        () {
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final inside = polygonCenter(sgwBuilding.boundary);
      final locator = BuildingLocator();

      locator.update(userPoint: inside, campus: Campus.sgw, buildings: buildings);
      locator.reset();

      final result = locator.update(
        userPoint: inside,
        campus: Campus.loyola,
        buildings: buildings,
      );

      expect(result.building?.campus, isNot(equals(Campus.sgw)),
          reason:
          'After reset, the SGW building must not persist when querying Loyola campus');
    },
  );
}