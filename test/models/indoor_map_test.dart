import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/room.dart';

CampusBuilding _building() => CampusBuilding(
      id: 'h',
      name: 'H',
      campus: Campus.sgw,
      boundary: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)],
      fullName: 'Hall',
      description: null,
    );

Floor _floor(int level) => Floor(
      level: level,
      label: 'Floor $level',
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
  test('floorLevels returns sorted levels', () {
    final map = IndoorMap(
      building: _building(),
      floors: [_floor(9), _floor(1), _floor(5)],
    );
    expect(map.floorLevels, [1, 5, 9]);
  });

  test('getFloorByLevel returns matching floor', () {
    final f8 = _floor(8);
    final map = IndoorMap(building: _building(), floors: [f8, _floor(9)]);
    expect(map.getFloorByLevel(8), same(f8));
  });

  test('getFloorByLevel returns null for missing level', () {
    final map = IndoorMap(building: _building(), floors: [_floor(8)]);
    expect(map.getFloorByLevel(99), isNull);
  });
}
