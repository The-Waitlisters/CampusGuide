import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/campus_building.dart';
import '../models/indoor_map.dart';
import 'floor_plan_editor_loader.dart';

class FloorOverlayConfig {
  const FloorOverlayConfig({
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotationDeg = 0.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  final double scaleX;
  final double scaleY;
  final double rotationDeg;
  final double offsetX;
  final double offsetY;
}

FloorOverlayConfig? getFloorOverlayConfig(String buildingName) {
  switch (buildingName) {
    case 'H':
      return const FloorOverlayConfig(
        scaleX: 0.75,
        scaleY: 0.75,
        rotationDeg: -57.0,
        offsetX: 0.0,
        offsetY: 0.0,
      );
    case 'MB':
      return const FloorOverlayConfig(
        scaleX: 1.0,
        scaleY: 1.0,
        rotationDeg: 0.0,
        offsetX: 0.0,
        offsetY: 0.0,
      );
    default:
      return null;
  }
}

/// Loads indoor map data for a building (TASK-5.1.1).
/// Tries floor-plan-editor JSON from `assets/indoor/<building>.json` first (see docs/indoor-floor-plan-editor.md).
Future<IndoorMap?> loadIndoorMapForBuilding(CampusBuilding building) async {
  await Future.delayed(const Duration(milliseconds: 150));

  // Map building name → safe asset key (no slashes or spaces)
  const assetKeys = {
    'H': 'H',
    'VL/VE': 'VE',
    'MB': 'MB',
    'CC': 'CC',
    'LB': 'LB',
  };

  final assetName = assetKeys[building.name];
  if (assetName == null) return null;

  final assetKey = 'assets/indoor/$assetName.json';
  try {
    final s = await rootBundle.loadString(assetKey);
    final j = jsonDecode(s) as Map<String, dynamic>;
    final floors = FloorPlanEditorLoader.parseMultiFloor(
      j,
      imageAssetPrefix: 'assets/indoor/$assetName',
    );
    if (floors.isNotEmpty) {
      return IndoorMap(building: building, floors: floors);
    }
  } catch (_) {
    // Asset not found or parse error
  }

  return null;
}

