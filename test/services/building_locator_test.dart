import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/services/building_locator.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';

void main() {
  group('US-1.4: BuildingLocator', () {
    final mockBuilding = CampusBuilding(
      id: 'EV',
      name: 'EV Building',
      campus: Campus.sgw,
      boundary: const [
        LatLng(45.4950, -73.5790),
        LatLng(45.4960, -73.5790),
        LatLng(45.4960, -73.5770),
        LatLng(45.4950, -73.5770),
      ],
    );

    final buildings = [mockBuilding];

    test('Detects building when user is inside boundary', () {
      final locator = BuildingLocator();

      final status = locator.update(
        userPoint: const LatLng(45.4955, -73.5780),
        campus: Campus.sgw,
        buildings: buildings,
      );

      expect(status.building, isNotNull);
      expect(status.building!.id, 'EV');
      expect(status.treatedAsInside, true);
    });

    test('Returns none when user is far from all buildings', () {
      final locator = BuildingLocator();

      final status = locator.update(
        userPoint: const LatLng(45.0, -73.0),
        campus: Campus.sgw,
        buildings: buildings,
      );

      expect(status.building, isNull);
      expect(status.treatedAsInside, false);
    });

    test('Does not select buildings from another campus', () {
      final locator = BuildingLocator();

      final status = locator.update(
        userPoint: const LatLng(45.4955, -73.5780),
        campus: Campus.loyola,
        buildings: buildings,
      );

      expect(status.building, isNull);
    });

    test('Hysteresis keeps building when slightly outside boundary', () {
      final locator = BuildingLocator(
        enterThresholdMeters: 15,
        exitThresholdMeters: 25,
      );

      // Step 1: Enter building
      locator.update(
        userPoint: const LatLng(45.4955, -73.5780),
        campus: Campus.sgw,
        buildings: buildings,
      );

      // Step 2: Slightly outside boundary (within exit threshold)
      final status = locator.update(
        userPoint: const LatLng(45.4962, -73.5780),
        campus: Campus.sgw,
        buildings: buildings,
      );

      expect(status.building, isNotNull);
      expect(status.building!.id, 'EV');
      expect(status.treatedAsInside, true);
    });
  });
}
