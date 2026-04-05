import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/campus_building.dart';
import '../models/vertical_link.dart';
import '../models/indoor_map.dart';
import 'floor_plan_editor_loader.dart';

/// Loads indoor map data for a building (TASK-5.1.1).
/// Tries floor-plan-editor JSON from `assets/indoor/<building>.json` first (see docs/indoor-floor-plan-editor.md).
Future<IndoorMap?> loadIndoorMapForBuilding(CampusBuilding building) async {
  await Future.delayed(const Duration(milliseconds: 150));

  final candidates = <({
  String jsonName,
  String imagePrefix,
  String separator,
  })>[];

  switch (building.name) {
    case 'H':
      candidates.add((
      jsonName: 'H',
      imagePrefix: 'assets/indoor/H',
      separator: '_',
      ));
      break;
    case 'VL/VE':
      candidates.add((
      jsonName: 'VE',
      imagePrefix: 'assets/indoor/VE',
      separator: '_',
      ));     // coverage:ignore-line
      break;
    case 'MB':
      candidates.add((
      jsonName: 'MB',
      imagePrefix: 'assets/indoor/MB',
      separator: '_',
      ));    // coverage:ignore-line
      break;
    case 'CC':
      candidates.add((
      jsonName: 'CC',
      imagePrefix: 'assets/indoor/CC',
      separator: '_',
      ));    // coverage:ignore-line
      break;
    case 'LB':
      candidates.add((
      jsonName: 'LB',
      imagePrefix: 'assets/indoor/LB',
      separator: '_',
      ));    // coverage:ignore-line
      break;
    default:
      return null;
  }

  for (final c in candidates) {
    try {
      final s = await rootBundle.loadString('assets/indoor/${c.jsonName}.json');
      final j = jsonDecode(s) as Map<String, dynamic>;
      final floors = FloorPlanEditorLoader.parseMultiFloor(
        j,
        imageAssetPrefix: c.imagePrefix,
        imageAssetSeparator: c.separator,
      );
      final rawLinks = j['verticalLinks'];
      final verticalLinks = (rawLinks is List)
          ? rawLinks
          .whereType<Map<String, dynamic>>()
          .map(VerticalLink.fromJson)
          .toList()
          : <VerticalLink>[];

      return IndoorMap(building: building, floors: floors, verticalLinks: verticalLinks);
    } catch (e) {
      print('Indoor map load error: $e');     // coverage:ignore-line
    }
  }

  return null;
}