import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/campus_building.dart';
import '../models/indoor_map.dart';
import '../models/floor.dart';
import '../models/room.dart';
import 'floor_plan_editor_loader.dart';

/// Loads indoor map data for a building (TASK-5.1.1).
/// Tries floor-plan-editor JSON from `assets/indoor/<building>.json` first (see docs/indoor-floor-plan-editor.md).
Future<IndoorMap?> loadIndoorMapForBuilding(CampusBuilding building) async {
  await Future.delayed(const Duration(milliseconds: 150));

  // Map building name → safe asset key (no slashes or spaces)
  const _assetKeys = {
    'H': 'H',
    'VL/VE': 'VE',
    'MB': 'MB',
    'CC': 'CC',
    'LB': 'LB',
  };

  final assetName = _assetKeys[building.name];
  if (assetName == null) return null;

  final assetKey = 'assets/indoor/$assetName.json';
  try {
    final s = await rootBundle.loadString(assetKey);
    final j = jsonDecode(s) as Map<String, dynamic>;
    final floors = FloorPlanEditorLoader.parseMultiFloor(
      j,
      imageAssetPrefix: 'assets/indoor/${assetName}',
    );
    if (floors.isNotEmpty) {
      return IndoorMap(building: building, floors: floors);
    }
  } catch (_) {
    // Asset not found or parse error
  }

  return null;
}

/// Sample floors and rooms for Henry F. Hall Building.
final List<Floor> _henryHallFloors = [
  Floor(
    level: 1,
    label: 'Floor 1',
    rooms: [
      Room(id: 'H-101', name: 'H-101', boundary: _rect(0.1, 0.2, 0.25, 0.45)),
      Room(id: 'H-102', name: 'H-102', boundary: _rect(0.28, 0.2, 0.43, 0.45)),
      Room(id: 'H-103', name: 'H-103', boundary: _rect(0.46, 0.2, 0.61, 0.45)),
      Room(id: 'H-104', name: 'H-104', boundary: _rect(0.63, 0.2, 0.78, 0.45)),
      Room(id: 'H-105', name: 'H-105', boundary: _rect(0.8, 0.2, 0.95, 0.45)),
      Room(id: 'H-110', name: 'H-110', boundary: _rect(0.1, 0.5, 0.35, 0.85)),
      Room(id: 'H-120', name: 'H-120', boundary: _rect(0.4, 0.5, 0.65, 0.85)),
      Room(id: 'H-130', name: 'H-130', boundary: _rect(0.7, 0.5, 0.95, 0.85)),
    ],
  ),
  Floor(
    level: 2,
    label: 'Floor 2',
    rooms: [
      Room(id: 'H-201', name: 'H-201', boundary: _rect(0.1, 0.15, 0.3, 0.5)),
      Room(id: 'H-202', name: 'H-202', boundary: _rect(0.33, 0.15, 0.53, 0.5)),
      Room(id: 'H-203', name: 'H-203', boundary: _rect(0.56, 0.15, 0.76, 0.5)),
      Room(id: 'H-204', name: 'H-204', boundary: _rect(0.79, 0.15, 0.95, 0.5)),
      Room(id: 'H-210', name: 'H-210', boundary: _rect(0.1, 0.55, 0.4, 0.9)),
      Room(id: 'H-220', name: 'H-220', boundary: _rect(0.45, 0.55, 0.75, 0.9)),
      Room(id: 'H-230', name: 'H-230', boundary: _rect(0.8, 0.55, 0.95, 0.9)),
    ],
  ),
  Floor(
    level: 3,
    label: 'Floor 3',
    rooms: [
      Room(id: 'H-301', name: 'H-301', boundary: _rect(0.1, 0.2, 0.28, 0.48)),
      Room(id: 'H-302', name: 'H-302', boundary: _rect(0.31, 0.2, 0.49, 0.48)),
      Room(id: 'H-303', name: 'H-303', boundary: _rect(0.52, 0.2, 0.7, 0.48)),
      Room(id: 'H-304', name: 'H-304', boundary: _rect(0.73, 0.2, 0.95, 0.48)),
      Room(id: 'H-310', name: 'H-310', boundary: _rect(0.1, 0.53, 0.45, 0.88)),
      Room(id: 'H-320', name: 'H-320', boundary: _rect(0.5, 0.53, 0.95, 0.88)),
    ],
  ),
];

List<Offset> _rect(double left, double top, double right, double bottom) {
  return [
    Offset(left, top),
    Offset(right, top),
    Offset(right, bottom),
    Offset(left, bottom),
  ];
}
