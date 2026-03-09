import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/campus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/room.dart';

CampusBuilding _building() => CampusBuilding(
      id: 'h',
      name: 'H',
      campus: Campus.sgw,
      boundary: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)],
      fullName: 'Hall Building',
      description: null,
    );

Floor _floor(int level, {String? label}) => Floor(
      level: level,
      label: label ?? 'Floor $level',
      rooms: [
        Room(
          id: 'r$level',
          name: 'Room $level',
          boundary: const [
            Offset(0, 0),
            Offset(0.1, 0),
            Offset(0.1, 0.1),
            Offset(0, 0.1),
          ],
        ),
      ],
    );

void main() {
  group('US-5.1: IndoorMap', () {
    test('floorLevels returns empty list when no floors', () {
      final map = IndoorMap(building: _building(), floors: const []);
      expect(map.floorLevels, isEmpty);
    });

    test('floorLevels returns sorted ascending levels', () {
      final map = IndoorMap(
        building: _building(),
        floors: [_floor(9), _floor(1), _floor(5)],
      );
      expect(map.floorLevels, [1, 5, 9]);
    });

    test('floorLevels returns single level correctly', () {
      final map = IndoorMap(building: _building(), floors: [_floor(8)]);
      expect(map.floorLevels, [8]);
    });

    test('getFloorByLevel returns the matching floor', () {
      final f8 = _floor(8, label: '8th');
      final map = IndoorMap(building: _building(), floors: [f8, _floor(9)]);
      expect(map.getFloorByLevel(8)?.label, '8th');
    });

    test('getFloorByLevel returns null for a missing level', () {
      final map = IndoorMap(building: _building(), floors: [_floor(8)]);
      expect(map.getFloorByLevel(99), isNull);
    });

    test('getFloorByLevel returns null for empty floor list', () {
      final map = IndoorMap(building: _building(), floors: const []);
      expect(map.getFloorByLevel(1), isNull);
    });

    test('building reference is stored correctly', () {
      final b = _building();
      final map = IndoorMap(building: b, floors: const []);
      expect(map.building, same(b));
    });
  });
}
