import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/multi_building_route.dart';
import 'package:proj/models/nav_graph.dart';
import 'package:proj/models/room.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';
import 'package:proj/services/indoor_multifloor_route.dart';
import 'package:proj/services/multi_building_route_planner.dart';

void main() {
  group('MultiBuildingRoutePlanner.planRoute', () {
    test('returns null when start building indoor map is unavailable', () async {
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => b.name == 'A' ? null : _makeMap(b),
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
      );

      expect(route, isNull);
    });

    test('returns null when end building indoor map is unavailable', () async {
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => b.name == 'B' ? null : _makeMap(b),
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
      );

      expect(route, isNull);
    });

    test('returns null when start room does not exist in building', () async {
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMap(b),
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'NONEXISTENT',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
      );

      expect(route, isNull);
    });

    test('returns null when destination room does not exist in building', () async {
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMap(b),
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'NONEXISTENT',
      );

      expect(route, isNull);
    });

    test('produces a valid multi-building route for same-campus buildings', () async {
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMap(b),
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
      );

      expect(route, isNotNull);
      expect(route!.isCrossCampus, isFalse);
      expect(route.segments.length, 5);

      expect(route.segments[0].type, MultiBuildingSegmentType.indoor);
      expect(route.segments[0].building?.name, 'A');

      expect(route.segments[1].type, MultiBuildingSegmentType.transition);
      expect(route.segments[1].instruction, contains('Exit'));

      expect(route.segments[2].type, MultiBuildingSegmentType.outdoor);
      expect(route.segments[2].instruction, contains('Walk'));
      expect(route.segments[2].durationText, isNotNull);

      expect(route.segments[3].type, MultiBuildingSegmentType.transition);
      expect(route.segments[3].instruction, contains('Enter'));

      expect(route.segments[4].type, MultiBuildingSegmentType.indoor);
      expect(route.segments[4].building?.name, 'B');
    });

    test('detects cross-campus route (SGW to Loyola)', () async {
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMap(b),
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(), // SGW
        startRoomId: 'R1',
        endBuilding: _buildingLoyola(),
        endRoomId: 'R2',
      );

      expect(route, isNotNull);
      expect(route!.isCrossCampus, isTrue);
      final outdoorSeg = route.segments.firstWhere(
        (s) => s.type == MultiBuildingSegmentType.outdoor,
      );
      expect(outdoorSeg.instruction, contains('Travel'));
    });

    test('uses directions client when provided', () async {
      final mockClient = _MockDirectionsClient();
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMap(b),
        directionsClient: mockClient,
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
      );

      expect(route, isNotNull);
      expect(mockClient.callCount, 1);
      final outdoorSeg = route!.segments.firstWhere(
        (s) => s.type == MultiBuildingSegmentType.outdoor,
      );
      expect(outdoorSeg.durationText, '5 min');
      expect(outdoorSeg.distanceText, '400 m');
      expect(outdoorSeg.outdoorPolyline, isNotEmpty);
    });

    test('directions client uses Metro strategy for cross-campus outdoor leg',
        () async {
      final mockClient = _MockDirectionsClient();
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMap(b),
        directionsClient: mockClient,
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingLoyola(),
        endRoomId: 'R2',
      );

      expect(route, isNotNull);
      expect(mockClient.callCount, 1);
      final outdoorSeg = route!.segments.firstWhere(
        (s) => s.type == MultiBuildingSegmentType.outdoor,
      );
      expect(outdoorSeg.instruction, contains('Travel'));
      expect(outdoorSeg.durationText, '5 min');
      expect(outdoorSeg.outdoorPolyline, isNotEmpty);
    });

    test('falls back to estimate when directions client throws', () async {
      final failClient = _FailingDirectionsClient();
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMap(b),
        directionsClient: failClient,
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
      );

      expect(route, isNotNull);
      final outdoorSeg = route!.segments.firstWhere(
        (s) => s.type == MultiBuildingSegmentType.outdoor,
      );
      expect(outdoorSeg.durationText, startsWith('~'));
      expect(outdoorSeg.outdoorPolyline, isNull);
    });

    test('uses building_entry_exit node when available', () async {
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMapWithEntryExit(b),
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
      );

      expect(route, isNotNull);
      expect(route!.segments[0].type, MultiBuildingSegmentType.indoor);
      expect(route.segments[0].indoorRoute, isNotNull);
    });

    test('allDirections produces a non-empty list', () async {
      final planner = MultiBuildingRoutePlanner(
        mapLoader: (b) async => _makeMap(b),
      );

      final route = await planner.planRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
      );

      expect(route, isNotNull);
      final dirs = route!.allDirections;
      expect(dirs, isNotEmpty);
      expect(dirs.any((d) => d.contains('Walk')), isTrue);
    });
  });

  group('MultiBuildingRoutePlanner.findEntryExitNode', () {
    test('prefers building_entry_exit when present', () {
      final entry = NavNode(
          id: 'main_exit',
          type: 'building_entry_exit',
          x: 0,
          y: 0,
          name: '');
      final legacy = NavNode(
          id: 'Entrance/Exit',
          type: 'room',
          x: 1,
          y: 1,
          name: 'Entrance/Exit');
      final g = NavGraph(
        nodes: [entry, legacy],
        edges: [NavEdge(from: 'main_exit', to: 'Entrance/Exit', weight: 1)],
      );
      final floor = Floor(
        level: 1,
        label: '1',
        rooms: const [],
        navGraph: g,
      );
      final map = IndoorMap(building: _buildingA(), floors: [floor]);
      expect(MultiBuildingRoutePlanner.findEntryExitNode(map), 'main_exit');
    });

    test('falls back to id/label containing entrance and exit', () {
      final legacy = NavNode(
          id: 'Entrance/Exit',
          type: 'room',
          x: 0,
          y: 0,
          name: 'Entrance/Exit');
      final g = NavGraph(
        nodes: [legacy],
        edges: const [],
      );
      final floor = Floor(
        level: 1,
        label: '1',
        rooms: const [],
        navGraph: g,
      );
      final map = IndoorMap(building: _buildingA(), floors: [floor]);
      expect(MultiBuildingRoutePlanner.findEntryExitNode(map), 'Entrance/Exit');
    });

    test('falls back to stair_landing when no entry markers', () {
      final stair = NavNode(
          id: 'st1', type: 'stair_landing', x: 0, y: 0, name: '');
      final g = NavGraph(nodes: [stair], edges: const []);
      final floor = Floor(
        level: 1,
        label: '1',
        rooms: const [],
        navGraph: g,
      );
      final map = IndoorMap(building: _buildingA(), floors: [floor]);
      expect(MultiBuildingRoutePlanner.findEntryExitNode(map), 'st1');
    });

    test('falls back to elevator_door when no stairs', () {
      final el = NavNode(
          id: 'ev1', type: 'elevator_door', x: 0, y: 0, name: '');
      final g = NavGraph(nodes: [el], edges: const []);
      final floor = Floor(
        level: 1,
        label: '1',
        rooms: const [],
        navGraph: g,
      );
      final map = IndoorMap(building: _buildingA(), floors: [floor]);
      expect(MultiBuildingRoutePlanner.findEntryExitNode(map), 'ev1');
    });

    test('returns null when graph has no exit hints', () {
      final room = NavNode(
          id: 'r1', type: 'room', x: 0.5, y: 0.5, name: 'Office');
      final g = NavGraph(nodes: [room], edges: const []);
      final floor = Floor(
        level: 1,
        label: '1',
        rooms: const [],
        navGraph: g,
      );
      final map = IndoorMap(building: _buildingA(), floors: [floor]);
      expect(MultiBuildingRoutePlanner.findEntryExitNode(map), isNull);
    });
  });

  group('MultiBuildingRoute model', () {
    test('allDirections includes indoor route directions when present', () {
      final route = MultiBuildingRoute(
        startBuilding: _buildingA(),
        startRoomId: 'R1',
        endBuilding: _buildingB(),
        endRoomId: 'R2',
        isCrossCampus: false,
        segments: [
          MultiBuildingSegment(
            type: MultiBuildingSegmentType.indoor,
            instruction: 'Navigate inside A',
            building: _buildingA(),
            indoorRoute: IndoorRoute(
              segments: const [],
              directions: ['Floor 1: go to wp1.', 'Arrive.'],
            ),
          ),
          const MultiBuildingSegment(
            type: MultiBuildingSegmentType.transition,
            instruction: 'Exit Building A',
          ),
          const MultiBuildingSegment(
            type: MultiBuildingSegmentType.outdoor,
            instruction: 'Walk to B',
            durationText: '3 min',
            distanceText: '200 m',
          ),
          const MultiBuildingSegment(
            type: MultiBuildingSegmentType.transition,
            instruction: 'Enter Building B',
          ),
          MultiBuildingSegment(
            type: MultiBuildingSegmentType.indoor,
            instruction: 'Navigate inside B',
            building: _buildingB(),
          ),
        ],
      );

      final dirs = route.allDirections;
      expect(dirs, contains('In A: Navigate inside A'));
      expect(dirs, contains('Floor 1: go to wp1.'));
      expect(dirs, contains('Walk to B'));
      expect(dirs, contains('3 min - 200 m'));
      expect(dirs, contains('Exit Building A'));
      expect(dirs, contains('Enter Building B'));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CampusBuilding _buildingA() => CampusBuilding(
      id: 'a1',
      name: 'A',
      fullName: 'Building A',
      description: '',
      campus: Campus.sgw,
      boundary: const [
        LatLng(45.4973, -73.5789),
        LatLng(45.4974, -73.5789),
        LatLng(45.4974, -73.5788),
        LatLng(45.4973, -73.5788),
      ],
    );

CampusBuilding _buildingB() => CampusBuilding(
      id: 'b1',
      name: 'B',
      fullName: 'Building B',
      description: '',
      campus: Campus.sgw,
      boundary: const [
        LatLng(45.4975, -73.5785),
        LatLng(45.4976, -73.5785),
        LatLng(45.4976, -73.5784),
        LatLng(45.4975, -73.5784),
      ],
    );

CampusBuilding _buildingLoyola() => CampusBuilding(
      id: 'c1',
      name: 'C',
      fullName: 'Building C',
      description: '',
      campus: Campus.loyola,
      boundary: const [
        LatLng(45.4582, -73.6405),
        LatLng(45.4583, -73.6405),
        LatLng(45.4583, -73.6404),
        LatLng(45.4582, -73.6404),
      ],
    );

IndoorMap _makeMap(CampusBuilding b) {
  final floor = _simpleFloor(level: 1, roomId: b.name == 'A' ? 'R1' : 'R2');
  return IndoorMap(building: b, floors: [floor]);
}

IndoorMap _makeMapWithEntryExit(CampusBuilding b) {
  final roomId = b.name == 'A' ? 'R1' : 'R2';
  final entryNode =
      NavNode(id: 'entry_${b.name}', type: 'building_entry_exit', x: 0.5, y: 0.9, name: 'Main Entrance');
  final roomNode = NavNode(id: roomId, type: 'room', x: 0.5, y: 0.1, name: roomId);
  final wp = NavNode(id: 'wp_${b.name}', type: 'hallway_waypoint', x: 0.5, y: 0.5);

  final graph = NavGraph(
    nodes: [roomNode, wp, entryNode],
    edges: [
      NavEdge(from: roomId, to: 'wp_${b.name}', weight: 10),
      NavEdge(from: 'wp_${b.name}', to: 'entry_${b.name}', weight: 10),
    ],
  );

  final floor = Floor(
    level: 1,
    label: 'Floor 1',
    rooms: [
      Room(id: roomId, name: roomId, boundary: _fakeBoundary(0.5, 0.1)),
      Room(id: 'entry_${b.name}', name: 'Main Entrance', boundary: _fakeBoundary(0.5, 0.9)),
    ],
    navGraph: graph,
  );

  return IndoorMap(building: b, floors: [floor]);
}

Floor _simpleFloor({required int level, required String roomId}) {
  final room = NavNode(id: roomId, type: 'room', x: 0.5, y: 0.5, name: roomId);
  final wp = NavNode(id: 'wp_$level', type: 'hallway_waypoint', x: 0.6, y: 0.5);
  final graph = NavGraph(
    nodes: [room, wp],
    edges: [NavEdge(from: roomId, to: 'wp_$level', weight: 10)],
  );
  return Floor(
    level: level,
    label: 'Floor $level',
    rooms: [Room(id: roomId, name: roomId, boundary: _fakeBoundary(0.5, 0.5))],
    navGraph: graph,
  );
}

List<Offset> _fakeBoundary(double cx, double cy) {
  const h = 0.025;
  return [
    Offset(cx - h, cy - h),
    Offset(cx + h, cy - h),
    Offset(cx + h, cy + h),
    Offset(cx - h, cy + h),
  ];
}

class _MockDirectionsClient implements DirectionsClient {
  int callCount = 0;

  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) async {
    callCount++;
    return const RouteResult(
      legs: [
        RouteLeg(
          polylinePoints: [
            LatLng(45.497, -73.578),
            LatLng(45.498, -73.577),
          ],
          legMode: LegMode.walking,
          durationSeconds: 300,
          durationText: '5 min',
          distanceText: '400 m',
        ),
      ],
      durationText: '5 min',
      distanceText: '400 m',
    );
  }
}

class _FailingDirectionsClient implements DirectionsClient {
  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) async {
    throw Exception('Network error');
  }
}
