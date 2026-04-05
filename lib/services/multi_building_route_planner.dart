import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/indoor_map_data.dart';
import '../models/campus_building.dart';
import '../models/indoor_map.dart';
import '../models/multi_building_route.dart';
import '../services/indoor_multifloor_route.dart';
import '../utilities/polygon_helper.dart';
import 'directions/transport_mode_strategy.dart';

typedef IndoorMapLoader = Future<IndoorMap?> Function(CampusBuilding building);

class MultiBuildingRoutePlanner {
  final DirectionsClient? directionsClient;
  final IndoorMapLoader mapLoader;

  MultiBuildingRoutePlanner({
    this.directionsClient,
    IndoorMapLoader? mapLoader,
  }) : mapLoader = mapLoader ?? loadIndoorMapForBuilding;

  Future<MultiBuildingRoute?> planRoute({
    required CampusBuilding startBuilding,
    required String startRoomId,
    required CampusBuilding endBuilding,
    required String endRoomId,
    VerticalPreference verticalPreference = VerticalPreference.either,
  }) async {
    final isCrossCampus = startBuilding.campus != endBuilding.campus;

    final startMap = await mapLoader(startBuilding);
    final endMap = await mapLoader(endBuilding);

    if (startMap == null || endMap == null) return null;

    final startFloor = IndoorMultifloorRoutePlanner.floorForRoom(startMap, startRoomId);
    final endFloor = IndoorMultifloorRoutePlanner.floorForRoom(endMap, endRoomId);
    if (startFloor == null || endFloor == null) return null;

    final startExitNodeId = findEntryExitNode(startMap) ?? startRoomId;
    // Defensive: [findEntryExitNode] ids always resolve via [floorForRoom].
    final startExitFloor = IndoorMultifloorRoutePlanner.floorForRoom(
            startMap, startExitNodeId) ??
        startMap.floorLevels.first; // coverage:ignore-line

    final endEntryNodeId = findEntryExitNode(endMap) ?? endRoomId;
    final endEntryFloor =
        IndoorMultifloorRoutePlanner.floorForRoom(endMap, endEntryNodeId) ??
            endMap.floorLevels.first; // coverage:ignore-line

    final segments = <MultiBuildingSegment>[];

    // --- Segment 1: Indoor in start building (start room → exit) ---
    IndoorRoute? startIndoorRoute;
    if (startRoomId != startExitNodeId) {
      startIndoorRoute = IndoorMultifloorRoutePlanner.buildRoute(
        map: startMap,
        startFloorLevel: startFloor,
        startRoomId: startRoomId,
        destinationFloorLevel: startExitFloor,
        destinationRoomId: startExitNodeId,
        preference: verticalPreference,
      );
    }

    final startBldgName = startBuilding.fullName ?? startBuilding.name;
    segments.add(MultiBuildingSegment(
      type: MultiBuildingSegmentType.indoor,
      building: startBuilding,
      indoorRoute: startIndoorRoute,
      instruction: startIndoorRoute != null
          ? 'Navigate to the exit of $startBldgName'
          : 'Start at $startBldgName',
    ));

    // --- Segment 2: Transition — exit start building ---
    segments.add(MultiBuildingSegment(
      type: MultiBuildingSegmentType.transition,
      instruction: 'Exit $startBldgName',
    ));

    // --- Segment 3: Outdoor walking/transit between buildings ---
    final startCenter = polygonCenter(startBuilding.boundary);
    final endCenter = polygonCenter(endBuilding.boundary);
    final endBldgName = endBuilding.fullName ?? endBuilding.name;

    String? durationText;
    String? distanceText;
    List<LatLng>? polylinePoints;

    if (directionsClient != null) {
      try {
        final mode = isCrossCampus ? MetroStrategy() : WalkStrategy();
        final result = await directionsClient!.getRoute(
          origin: startCenter,
          destination: endCenter,
          mode: mode,
        );
        polylinePoints = result.polylinePoints;
        durationText = result.durationText;
        distanceText = result.distanceText;
      } catch (_) {
        // Fallback: estimate walking
        final estMinutes = _estimateWalkingMinutes(startCenter, endCenter);
        durationText = '~$estMinutes min walk';
      }
    } else {
      final estMinutes = _estimateWalkingMinutes(startCenter, endCenter);
      durationText = '~$estMinutes min walk';
    }

    final modeLabel = isCrossCampus ? 'Travel' : 'Walk';
    segments.add(MultiBuildingSegment(
      type: MultiBuildingSegmentType.outdoor,
      instruction: '$modeLabel from $startBldgName to $endBldgName',
      outdoorPolyline: polylinePoints,
      durationText: durationText,
      distanceText: distanceText,
    ));

    // --- Segment 4: Transition — enter destination building ---
    segments.add(MultiBuildingSegment(
      type: MultiBuildingSegmentType.transition,
      instruction: 'Enter $endBldgName',
    ));

    // --- Segment 5: Indoor in destination building (entry → destination room) ---
    IndoorRoute? endIndoorRoute;
    if (endEntryNodeId != endRoomId) {
      endIndoorRoute = IndoorMultifloorRoutePlanner.buildRoute(
        map: endMap,
        startFloorLevel: endEntryFloor,
        startRoomId: endEntryNodeId,
        destinationFloorLevel: endFloor,
        destinationRoomId: endRoomId,
        preference: verticalPreference,
      );
    }

    segments.add(MultiBuildingSegment(
      type: MultiBuildingSegmentType.indoor,
      building: endBuilding,
      indoorRoute: endIndoorRoute,
      instruction: endIndoorRoute != null
          ? 'Navigate to your destination in $endBldgName'
          : 'Arrive at $endBldgName',
    ));

    return MultiBuildingRoute(
      startBuilding: startBuilding,
      startRoomId: startRoomId,
      endBuilding: endBuilding,
      endRoomId: endRoomId,
      segments: segments,
      isCrossCampus: isCrossCampus,
    );
  }

  /// Main door / stairs-in from outside — lowest floors first.
  ///
  /// 1) Explicit `building_entry_exit` (Hall, LB, …)
  /// 2) Legacy data: id/label containing both "entrance" and "exit" (e.g. MB `Entrance/Exit`)
  /// 3) Typed `stair_landing` / `elevator_door` on the lowest level that has one
  static String? findEntryExitNode(IndoorMap map) {
    final sortedFloors = map.floors.toList()
      ..sort((a, b) => a.level.compareTo(b.level));

    for (final floor in sortedFloors) {
      final graph = floor.navGraph;
      if (graph == null) continue;
      for (final node in graph.nodes) {
        if (node.type == 'building_entry_exit') return node.id;
      }
    }

    for (final floor in sortedFloors) {
      final graph = floor.navGraph;
      if (graph == null) continue;
      for (final node in graph.nodes) {
        final key = node.name.isNotEmpty ? node.name : node.id;
        final k = key.toLowerCase();
        if (k.contains('entrance') && k.contains('exit')) return node.id;
      }
    }

    for (final floor in sortedFloors) {
      final graph = floor.navGraph;
      if (graph == null) continue;
      for (final node in graph.nodes) {
        if (node.type == 'stair_landing' || node.type == 'elevator_door') {
          return node.id;
        }
      }
    }
    return null;
  }

  static int _estimateWalkingMinutes(LatLng a, LatLng b) {
    // ~5 km/h walking speed, ~83 m/min
    const metersPerMinute = 83.0;
    final dlat = (a.latitude - b.latitude) * 111320;
    final dlng = (a.longitude - b.longitude) * 78710; // rough at ~45°N
    final dist = (dlat * dlat + dlng * dlng);
    final meters = dist > 0 ? _sqrt(dist) : 0.0;
    final minutes = (meters / metersPerMinute).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v;
    for (var i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }
}
