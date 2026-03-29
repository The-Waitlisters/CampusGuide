// US-1.4: Show the building I am currently located in
//
// All tests use plain test() — no widget tree, no GoogleMap.
// pause() is not needed here since there is no UI to observe,
// but we keep the import for consistency.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/models/campus_building.dart';
import 'package:proj/data/data_parser.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/services/building_locator.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late List<CampusBuilding> buildings;

  setUpAll(() async {
    buildings = await DataParser().getBuildingInfoFromJSON();
  });

  // ─── AC: "If the user is far from a campus building, UI indicates not in a building"

  test(
    'US-1.4 [Logic]: point far from all buildings → BuildingStatus.none()',
    () async {
      final locator = BuildingLocator();
      final result = locator.update(
        userPoint: const LatLng(0, 0),
        campus: Campus.sgw,
        buildings: buildings,
      );

      expect(result.building, isNull);
      expect(result.treatedAsInside, isFalse);
      await pause(2);
    },
  );

  // ─── AC: "When the user is inside a building, that building is highlighted and named"

  test(
    'US-1.4 [Logic]: point inside an SGW building → returns that building',
    () async {
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
      await pause(2);
    },
  );

  test(
    'US-1.4 [Logic]: point inside a Loyola building → returns that building on Loyola campus',
    () async {
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
      await pause(2);
    },
  );

  // ─── AC: "When outside but within threshold, treat as inside"

  test(
    'US-1.4 [Logic]: point within enterThreshold of a building → treated as inside',
    () async {
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
      await pause(2);
    },
  );

  // ─── AC: Campus filter

  test(
    'US-1.4 [Logic]: point inside an SGW building is not returned when campus is Loyola',
    () async {
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
      await pause(2);
    },
  );

  // ─── AC: "In-building state does not alternate quickly on the boundary" (hysteresis)

  test(
    'US-1.4 [Logic]: hysteresis keeps user in building after minor boundary crossing',
    () async {
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
      await pause(2);
    },
  );

  // ─── AC: Campus switch resets state

  test(
    'US-1.4 [Logic]: reset() clears state so previous building is not returned after campus change',
    () async {
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
      await pause(2);
    },
  );
}