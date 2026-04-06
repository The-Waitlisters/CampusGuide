import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/nav_graph.dart';
import 'package:proj/models/room.dart';

import 'package:proj/models/vertical_link.dart';
import 'package:proj/services/indoor_multifloor_route.dart';

// TESTS
void main() {
  group('buildRoute — transition instruction for escalator', () {
    test('explicit escalator link produces "escalator" in instructions', () {
      // waypointId contains "escalator" → _detectConnectorKind fires on the
      // from-node and produces the right mode string.
      final f1 = _simpleFloor(level: 1, roomId: 'R1',
          waypointId: 'escalator_bottom');
      final f2 = _simpleFloor(level: 2, roomId: 'R2',
          waypointId: 'escalator_top');
      final map = IndoorMap(
        building: _building(),
        floors: [f1, f2],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'escalator_bottom',
            toFloor: 2, toNodeId: 'escalator_top',
            kind: VerticalLinkKind.escalator,
          ),
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      final transDir = route!.directions
          .firstWhere((d) => d.startsWith('Take the'));
      expect(transDir, contains('escalator'));
    });
  });

  // ── buildRoute edge cases ──────────────────────────────────────────────────
  group('buildRoute — nonexistent floor levels', () {
    test('returns null when startFloorLevel does not exist in map', () {
      final map = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'R1', waypointId: 'elev1'),
          _simpleFloor(level: 2, roomId: 'R2', waypointId: 'elev2'),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'elev1',
            toFloor: 2, toNodeId: 'elev2',
            kind: VerticalLinkKind.elevator,
          ),
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 99, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      expect(route, isNull);
    });

    test('returns null when destinationFloorLevel does not exist in map', () {
      final map = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'R1', waypointId: 'elev1'),
          _simpleFloor(level: 2, roomId: 'R2', waypointId: 'elev2'),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'elev1',
            toFloor: 2, toNodeId: 'elev2',
            kind: VerticalLinkKind.elevator,
          ),
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 99, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      expect(route, isNull);
    });
  });

  group('buildRoute — room disconnected from vertical connector', () {
    test('returns null when start room has no path to any vertical connector', () {
      // Floor 1 has two disconnected components: R1 alone, and elev1 reachable
      // from R_other. R1 cannot reach elev1 so the global graph has no path.
      final isolated = NavNode(id: 'R1', type: 'room', x: 0, y: 0, name: 'R1');
      final other = NavNode(id: 'R_other', type: 'room', x: 0.5, y: 0, name: 'other');
      final elev1 = NavNode(id: 'elev1', type: 'hallway_waypoint', x: 0.6, y: 0);
      final g1 = NavGraph(
        nodes: [isolated, other, elev1],
        edges: [NavEdge(from: 'R_other', to: 'elev1', weight: 10)],
        // R1 has no edges → disconnected
      );
      final elev2 = NavNode(id: 'elev2', type: 'hallway_waypoint', x: 0, y: 0);
      final dest = NavNode(id: 'R2', type: 'room', x: 0.1, y: 0, name: 'R2');
      final g2 = NavGraph(
        nodes: [elev2, dest],
        edges: [NavEdge(from: 'elev2', to: 'R2', weight: 10)],
      );
      final map = IndoorMap(
        building: _building(),
        floors: [
          Floor(
            level: 1,
            label: 'F1',
            rooms: [
              Room(id: 'R1', name: 'R1', boundary: _fakeBoundary(0, 0)),
              Room(id: 'R_other', name: 'other', boundary: _fakeBoundary(0.5, 0)),
            ],
            navGraph: g1,
          ),
          Floor(
            level: 2,
            label: 'F2',
            rooms: [Room(id: 'R2', name: 'R2', boundary: _fakeBoundary(0.1, 0))],
            navGraph: g2,
          ),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'elev1',
            toFloor: 2, toNodeId: 'elev2',
            kind: VerticalLinkKind.elevator,
          ),
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      expect(route, isNull);
    });
  });

  // ── Three-floor route ──────────────────────────────────────────────────────
  group('buildRoute — three-floor route', () {
    late IndoorMap threeFloorMap;

    setUp(() {
      threeFloorMap = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'R1', waypointId: 'elev1'),
          _simpleFloor(level: 2, roomId: 'R2', waypointId: 'elev2'),
          _simpleFloor(level: 3, roomId: 'R3', waypointId: 'elev3'),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'elev1',
            toFloor: 2, toNodeId: 'elev2',
            kind: VerticalLinkKind.elevator,
          ),
          const VerticalLink(
            fromFloor: 2, fromNodeId: 'elev2',
            toFloor: 3, toNodeId: 'elev3',
            kind: VerticalLinkKind.elevator,
          ),
        ],
      );
    });

    test('produces three segments for a floor 1 → 3 route', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: threeFloorMap,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 3, destinationRoomId: 'R3',
        preference: VerticalPreference.either,
      );
      expect(route, isNotNull);
      expect(route!.segments.length, 3);
      expect(route.segments[0].floorLevel, 1);
      expect(route.segments[1].floorLevel, 2);
      expect(route.segments[2].floorLevel, 3);
    });

    test('middle segment has a non-null transitionInstruction', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: threeFloorMap,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 3, destinationRoomId: 'R3',
        preference: VerticalPreference.either,
      );
      expect(route!.segments[0].transitionInstruction, isNotNull);
      expect(route.segments[1].transitionInstruction, isNotNull);
    });

    test('last segment has null transitionInstruction', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: threeFloorMap,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 3, destinationRoomId: 'R3',
        preference: VerticalPreference.either,
      );
      expect(route!.segments.last.transitionInstruction, isNull);
    });

    test('directions include floor labels for all three floors', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: threeFloorMap,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 3, destinationRoomId: 'R3',
        preference: VerticalPreference.either,
      );
      final dirs = route!.directions;
      expect(dirs.any((d) => d.startsWith('Floor 1:')), isTrue);
      expect(dirs.any((d) => d.startsWith('Floor 2:')), isTrue);
      expect(dirs.any((d) => d.startsWith('Floor 3:')), isTrue);
    });

    test('last direction is "Arrive at destination." for three-floor route', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: threeFloorMap,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 3, destinationRoomId: 'R3',
        preference: VerticalPreference.either,
      );
      expect(route!.directions.last, 'Arrive at destination.');
    });
  });

  // ── floorForRoom — duplicate room id ───────────────────────────────────────
  group('floorForRoom — duplicate room id across floors', () {
    test('returns the level of the first floor that contains the room', () {
      final map = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'sharedRoom'),
          _simpleFloor(level: 2, roomId: 'sharedRoom'),
        ],
      );
      // First floor wins — documents current find-first behaviour.
      expect(
        IndoorMultifloorRoutePlanner.floorForRoom(map, 'sharedRoom'),
        1,
      );
    });
  });

  // ── NavGraph — withAutoConnections already-connected room ─────────────────
  group('NavGraph.withAutoConnections — already-connected room', () {
    test('room already connected to waypoint still gets an auto-edge without error', () {
      // The existing edge connects R1 → W1 explicitly.
      // withAutoConnections should add a second roomToWaypoint edge, but
      // Dijkstra still finds the correct (lighter) path without throwing.
      final r1 = const NavNode(id: 'R1', type: 'room', x: 0.0, y: 0.0);
      final w1 = const NavNode(id: 'W1', type: 'hallway_waypoint', x: 0.1, y: 0.0);
      final w2 = const NavNode(id: 'W2', type: 'hallway_waypoint', x: 0.9, y: 0.0);
      final base = NavGraph(
        nodes: [r1, w1, w2],
        edges: [
          const NavEdge(from: 'R1', to: 'W1', weight: 10),
          const NavEdge(from: 'W1', to: 'W2', weight: 800),
        ],
      );
      final g = base.withAutoConnections(pixelScale: 1000);
      // Path must still resolve correctly despite the duplicate edge.
      final path = g.findPath('R1', 'W2');
      expect(path, isNotNull);
      expect(path!.first, 'R1');
      expect(path.last, 'W2');
    });
  });

  // ── NavGraph — Dijkstra with cycle ────────────────────────────────────────
  group('NavGraph.findPath — graph with cycle', () {
    test('finds shortest path and does not loop when graph contains a cycle', () {
      // A –10– B –10– C –10– A  (cycle), with a shortcut B –5– D
      final g = NavGraph(
        nodes: [
          const NavNode(id: 'A', type: 'room', x: 0, y: 0),
          const NavNode(id: 'B', type: 'room', x: 1, y: 0),
          const NavNode(id: 'C', type: 'room', x: 1, y: 1),
          const NavNode(id: 'D', type: 'room', x: 2, y: 0),
        ],
        edges: [
          const NavEdge(from: 'A', to: 'B', weight: 10),
          const NavEdge(from: 'B', to: 'C', weight: 10),
          const NavEdge(from: 'C', to: 'A', weight: 10),
          const NavEdge(from: 'B', to: 'D', weight: 5),
        ],
      );
      final path = g.findPath('A', 'D');
      expect(path, ['A', 'B', 'D']);
    });
  });
  // ── floorForRoom ────────────────────────────────────────────────────────────
  group('floorForRoom', () {
    test('returns correct floor level when room exists', () {
      final map = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'roomA'),
          _simpleFloor(level: 2, roomId: 'roomB'),
        ],
      );
      expect(IndoorMultifloorRoutePlanner.floorForRoom(map, 'roomA'), 1);
      expect(IndoorMultifloorRoutePlanner.floorForRoom(map, 'roomB'), 2);
    });

    test('returns null when room does not exist in any floor', () {
      final map = IndoorMap(
          building: _building(),
          floors: [_simpleFloor(level: 1, roomId: 'roomA')]);
      expect(
          IndoorMultifloorRoutePlanner.floorForRoom(map, 'nonexistent'), isNull);
    });

    test('returns null for empty floors list', () {
      final map = IndoorMap(building: _building(), floors: []);
      expect(IndoorMultifloorRoutePlanner.floorForRoom(map, 'x'), isNull);
    });

    test('returns floor for nav-graph-only node (no matching Room)', () {
      final entryNode = NavNode(
        id: 'Entrance/Exit stairs',
        type: 'building_entry_exit',
        x: 0,
        y: 0,
        name: 'Entrance/Exit stairs',
      );
      final roomNode =
          NavNode(id: 'roomA', type: 'room', x: 100, y: 0, name: 'roomA');
      final graph = NavGraph(
        nodes: [entryNode, roomNode],
        edges: [
          NavEdge(from: 'Entrance/Exit stairs', to: 'roomA', weight: 10),
        ],
      );
      final floor = Floor(
        level: 2,
        label: 'Floor 2',
        rooms: [
          Room(id: 'roomA', name: 'roomA', boundary: _fakeBoundary(0.5, 0.5)),
        ],
        navGraph: graph,
      );
      final map = IndoorMap(building: _building(), floors: [floor]);
      expect(
        IndoorMultifloorRoutePlanner.floorForRoom(map, 'Entrance/Exit stairs'),
        2,
      );
    });
  });

  // ── Single-floor routing ─────────────────────────────────────────────────────
  group('buildRoute — same floor', () {
    late IndoorMap map;

    setUp(() {
      final h = 0.025;
      final nodeA =
      NavNode(id: 'A', type: 'room', x: 0, y: 0, name: 'Room A');
      final nodeB =
      NavNode(id: 'B', type: 'room', x: 100, y: 0, name: 'Room B');
      final wp =
      NavNode(id: 'wp', type: 'hallway_waypoint', x: 50, y: 0);
      final graph = NavGraph(nodes: [nodeA, nodeB, wp], edges: [
        NavEdge(from: 'A', to: 'wp', weight: 50),
        NavEdge(from: 'wp', to: 'B', weight: 50),
      ]);
      map = IndoorMap(
        building: _building(),
        floors: [
          Floor(
              level: 1,
              label: 'F1',
              rooms: [
                Room(id: 'A', name: 'Room A', boundary: [
                  Offset(nodeA.x - h,nodeA.y - h),
                  Offset(nodeA.x + h, nodeA.y - h),
                  Offset(nodeA.x + h, nodeA.y + h),
                  Offset(nodeA.x - h, nodeA.y + h),
                ]),
                Room(id: 'B', name: 'Room B', boundary: [
                  Offset(nodeB.x - h,nodeB.y - h),
                  Offset(nodeB.x + h, nodeB.y - h),
                  Offset(nodeB.x + h, nodeB.y + h),
                  Offset(nodeB.x - h, nodeB.y + h),
                ]),
              ],
              navGraph: graph)
        ],
      );
    });

    test('returns a route with one segment on the correct floor', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1,
        startRoomId: 'A',
        destinationFloorLevel: 1,
        destinationRoomId: 'B',
        preference: VerticalPreference.either,
      );
      expect(route, isNotNull);
      expect(route!.segments.length, 1);
      expect(route.segments.first.floorLevel, 1);
    });

    test('path includes start and destination nodes', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1,
        startRoomId: 'A',
        destinationFloorLevel: 1,
        destinationRoomId: 'B',
        preference: VerticalPreference.either,
      );
      final ids = route!.segments.first.nodeIds;
      expect(ids.first, 'A');
      expect(ids.last, 'B');
    });

    test('start == destination returns single-node route', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1,
        startRoomId: 'A',
        destinationFloorLevel: 1,
        destinationRoomId: 'A',
        preference: VerticalPreference.either,
      );
      expect(route, isNotNull);
      expect(route!.segments.length, 1);
      expect(route.segments.first.nodeIds, ['A']);
    });

    test('last direction is "Arrive at destination."', () {
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1,
        startRoomId: 'A',
        destinationFloorLevel: 1,
        destinationRoomId: 'B',
        preference: VerticalPreference.either,
      );
      expect(route!.directions.last, 'Arrive at destination.');
    });
  });

  // ── Multi-floor routing via explicit verticalLinks ───────────────────────────
  group('buildRoute — multifloor with explicit verticalLinks', () {
    IndoorMap _mapWithLink(VerticalLink link) {
      return IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'R1', waypointId: 'elev1'),
          _simpleFloor(level: 2, roomId: 'R2', waypointId: 'elev2'),
        ],
        verticalLinks: [link],
      );
    }

    test('routes across floors via elevator link', () {
      final map = _mapWithLink(const VerticalLink(
        fromFloor: 1, fromNodeId: 'elev1',
        toFloor: 2,   toNodeId: 'elev2',
        kind: VerticalLinkKind.elevator,
      ));
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      expect(route, isNotNull);
      expect(route!.segments.length, 2);
      expect(route.segments[0].floorLevel, 1);
      expect(route.segments[1].floorLevel, 2);
    });

    test('transition instruction mentions elevator', () {
      // Use named nodes so _detectConnectorKind fires
      final f1 = _simpleFloor(
          level: 1, roomId: 'R1', waypointId: 'f1 elevator');
      final f2 = _simpleFloor(
          level: 2, roomId: 'R2', waypointId: 'f2 elevator');
      final map = IndoorMap(
        building: _building(),
        floors: [f1, f2],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'f1 elevator',
            toFloor: 2,   toNodeId: 'f2 elevator',
            kind: VerticalLinkKind.elevator,
          )
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      final transDir = route!.directions
          .firstWhere((d) => d.startsWith('Take the'));
      expect(transDir, contains('elevator'));
    });

    test('transition instruction mentions stairs', () {
      final f1 = _simpleFloor(
          level: 1, roomId: 'R1', waypointId: 'staircase_1');
      final f2 = _simpleFloor(
          level: 2, roomId: 'R2', waypointId: 'staircase_2');
      final map = IndoorMap(
        building: _building(),
        floors: [f1, f2],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'staircase_1',
            toFloor: 2,   toNodeId: 'staircase_2',
            kind: VerticalLinkKind.stairs,
          )
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      final transDir = route!.directions
          .firstWhere((d) => d.startsWith('Take the'));
      expect(transDir, contains('stairs'));
    });

    test('transition instruction mentions escalator', () {
      final f1 = _simpleFloor(
          level: 1, roomId: 'R1', waypointId: 'escalator_up');
      final f2 = _simpleFloor(
          level: 2, roomId: 'R2', waypointId: 'escalator_top');
      final map = IndoorMap(
        building: _building(),
        floors: [f1, f2],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'escalator_up',
            toFloor: 2,   toNodeId: 'escalator_top',
            kind: VerticalLinkKind.escalator,
          )
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      final transDir = route!.directions
          .firstWhere((d) => d.startsWith('Take the'));
      expect(transDir, contains('escalator'));
    });

    test('transition instruction falls back to "vertical connector" '
        'when connector kind is unknown', () {
      // waypoint IDs have no elevator/stair/escalator keyword
      final map = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'R1', waypointId: 'wp1'),
          _simpleFloor(level: 2, roomId: 'R2', waypointId: 'wp2'),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'wp1',
            toFloor: 2,   toNodeId: 'wp2',
            kind: VerticalLinkKind.stairs,
          )
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      final transDir = route!.directions
          .firstWhere((d) => d.startsWith('Take the'));
      expect(transDir, contains('vertical connector'));
    });

    test('bidirectional link allows routing in both directions', () {
      final map = _mapWithLink(const VerticalLink(
        fromFloor: 1, fromNodeId: 'elev1',
        toFloor: 2,   toNodeId: 'elev2',
        kind: VerticalLinkKind.elevator,
      ));
      final up = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      final down = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 2, startRoomId: 'R2',
        destinationFloorLevel: 1, destinationRoomId: 'R1',
        preference: VerticalPreference.either,
      );
      expect(up, isNotNull);
      expect(down, isNotNull);
    });

    test('oneWay link blocks reverse direction', () {
      final map = _mapWithLink(const VerticalLink(
        fromFloor: 1, fromNodeId: 'elev1',
        toFloor: 2,   toNodeId: 'elev2',
        kind: VerticalLinkKind.stairs,
        oneWay: true,
      ));
      final forward = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      final reverse = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 2, startRoomId: 'R2',
        destinationFloorLevel: 1, destinationRoomId: 'R1',
        preference: VerticalPreference.either,
      );
      expect(forward, isNotNull,
          reason: 'forward direction should succeed');
      expect(reverse, isNull,
          reason: 'reverse direction must be blocked for oneWay link');
    });
  });

  // ── VerticalPreference filtering ─────────────────────────────────────────────
  group('buildRoute — VerticalPreference filtering', () {
    IndoorMap _mapWithBothKinds() {
      final f1 = _simpleFloor(level: 1, roomId: 'R1', waypointId: 'elev1');
      final f2 = _simpleFloor(level: 2, roomId: 'R2', waypointId: 'elev2');
      // Add a stair node on each floor alongside the existing waypoint
      final f1Stair = NavNode(
          id: 'stair1', type: 'hallway_waypoint', x: 50, y: 0);
      final f2Stair = NavNode(
          id: 'stair2', type: 'hallway_waypoint', x: 50, y: 0);
      // Rebuild floors with extra stair nodes connected
      final g1 = NavGraph(nodes: [
        ...f1.navGraph!.nodes,
        f1Stair
      ], edges: [
        ...f1.navGraph!.edges,
        NavEdge(from: 'R1', to: 'stair1', weight: 5),
      ]);
      final g2 = NavGraph(nodes: [
        ...f2.navGraph!.nodes,
        f2Stair
      ], edges: [
        ...f2.navGraph!.edges,
        NavEdge(from: 'R2', to: 'stair2', weight: 5),
      ]);
      return IndoorMap(
        building: _building(),
        floors: [
          Floor(
              level: 1,
              label: 'F1',
              rooms: [Room(id: 'R1', name: 'R1', boundary:
              [Offset(f1Stair.x - 0.025, f1Stair.y - 0.025),
              Offset(f1Stair.x + 0.025, f1Stair.y - 0.025),
              Offset(f1Stair.x - 0.025, f1Stair.y +0.025),
              Offset(f1Stair.x + 0.025, f1Stair.y + 0.025)
              ]
              )],
              navGraph: g1),
          Floor(
              level: 2,
              label: 'F2',
              rooms: [Room(id: 'R2', name: 'R2', boundary:
              [Offset(f2Stair.x - 0.025, f2Stair.y - 0.025),
              Offset(f2Stair.x + 0.025, f2Stair.y - 0.025),
              Offset(f2Stair.x - 0.025, f2Stair.y +0.025),
              Offset(f1Stair.x + 0.025, f2Stair.y + 0.025)
              ]
              )],
              navGraph: g2),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'elev1',
            toFloor: 2,   toNodeId: 'elev2',
            kind: VerticalLinkKind.elevator,
          ),
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'stair1',
            toFloor: 2,   toNodeId: 'stair2',
            kind: VerticalLinkKind.stairs,
          ),
        ],
      );
    }

    test('elevatorOnly preference uses elevator, not stairs', () {
      final map = _mapWithBothKinds();
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.elevatorOnly,
      );
      expect(route, isNotNull);
      // The path must go through the elevator waypoints, not stair waypoints
      final allNodeIds =
      route!.segments.expand((s) => s.nodeIds).toList();
      expect(allNodeIds, contains('elev1'));
      expect(allNodeIds, isNot(contains('stair1')));
    });

    test('stairsOnly preference uses stairs, not elevator', () {
      final map = _mapWithBothKinds();
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.stairsOnly,
      );
      expect(route, isNotNull);
      final allNodeIds =
      route!.segments.expand((s) => s.nodeIds).toList();
      expect(allNodeIds, contains('stair1'));
      expect(allNodeIds, isNot(contains('elev1')));
    });

    test('elevatorOnly returns null when only stairs available', () {
      final map = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'R1', waypointId: 'stair1'),
          _simpleFloor(level: 2, roomId: 'R2', waypointId: 'stair2'),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'stair1',
            toFloor: 2,   toNodeId: 'stair2',
            kind: VerticalLinkKind.stairs,
          )
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.elevatorOnly,
      );
      expect(route, isNull);
    });

    test('stairsOnly accepts escalator links', () {
      final map = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'R1', waypointId: 'esc1'),
          _simpleFloor(level: 2, roomId: 'R2', waypointId: 'esc2'),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'esc1',
            toFloor: 2,   toNodeId: 'esc2',
            kind: VerticalLinkKind.escalator,
          )
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.stairsOnly,
      );
      expect(route, isNotNull);
    });

    test('stairsOnly returns null when only elevator available', () {
      final map = IndoorMap(
        building: _building(),
        floors: [
          _simpleFloor(level: 1, roomId: 'R1', waypointId: 'elev1'),
          _simpleFloor(level: 2, roomId: 'R2', waypointId: 'elev2'),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'elev1',
            toFloor: 2,   toNodeId: 'elev2',
            kind: VerticalLinkKind.elevator,
          )
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.stairsOnly,
      );
      expect(route, isNull);
    });
  });


  // ── Floors with null navGraph ────────────────────────────────────────────────
  group('buildRoute — floors without navGraph', () {
    test('skips floors with null navGraph', () {
      // Floor 1 has no graph; floor 2 has one but start is on floor 1 → no path
      final emptyFloor =
      Floor(level: 1, label: 'F1', rooms: [], navGraph: null);
      final map = IndoorMap(
        building: _building(),
        floors: [
          emptyFloor,
          _simpleFloor(level: 2, roomId: 'R2'),
        ],
        verticalLinks: [
          const VerticalLink(
            fromFloor: 1, fromNodeId: 'x',
            toFloor: 2,   toNodeId: 'wp',
            kind: VerticalLinkKind.elevator,
          )
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'R1',
        destinationFloorLevel: 2, destinationRoomId: 'R2',
        preference: VerticalPreference.either,
      );
      // start node doesn't exist in global graph → null
      expect(route, isNull);
    });
  });

  // ── Directions content ────────────────────────────────────────────────────────
  group('buildRoute — directions format', () {
    test('directions list is non-empty for valid route', () {
      final h = 0.025;
      final nodeA = NavNode(id: 'A', type: 'room', x: 0, y: 0, name: 'A');
      final nodeB = NavNode(id: 'B', type: 'room', x: 50, y: 0, name: 'B');
      final graph =
      NavGraph(nodes: [nodeA, nodeB], edges: [
        NavEdge(from: 'A', to: 'B', weight: 50)
      ]);
      final map = IndoorMap(
        building: _building(),
        floors: [
          Floor(
              level: 1,
              label: 'F1',
              rooms: [
                Room(id: 'A', name: 'Room A', boundary: [
                  Offset(nodeA.x - h,nodeA.y - h),
                  Offset(nodeA.x + h, nodeA.y - h),
                  Offset(nodeA.x + h, nodeA.y + h),
                  Offset(nodeA.x - h, nodeA.y + h),
                ]),
                Room(id: 'B', name: 'Room B', boundary: [
                  Offset(nodeB.x - h,nodeB.y - h),
                  Offset(nodeB.x + h, nodeB.y - h),
                  Offset(nodeB.x + h, nodeB.y + h),
                  Offset(nodeB.x - h, nodeB.y + h),
                ]),
              ],
              navGraph: graph)
        ],
      );
      final route = IndoorMultifloorRoutePlanner.buildRoute(
        map: map,
        startFloorLevel: 1, startRoomId: 'A',
        destinationFloorLevel: 1, destinationRoomId: 'B',
        preference: VerticalPreference.either,
      );
      expect(route!.directions, isNotEmpty);
    });

    test('multifloor directions include both floor instructions and transition',
            () {
          final map = IndoorMap(
            building: _building(),
            floors: [
              _simpleFloor(level: 1, roomId: 'R1', waypointId: 'elev1'),
              _simpleFloor(level: 2, roomId: 'R2', waypointId: 'elev2'),
            ],
            verticalLinks: [
              const VerticalLink(
                fromFloor: 1, fromNodeId: 'elev1',
                toFloor: 2,   toNodeId: 'elev2',
                kind: VerticalLinkKind.elevator,
              )
            ],
          );
          final route = IndoorMultifloorRoutePlanner.buildRoute(
            map: map,
            startFloorLevel: 1, startRoomId: 'R1',
            destinationFloorLevel: 2, destinationRoomId: 'R2',
            preference: VerticalPreference.either,
          );
          final dirs = route!.directions;
          expect(dirs.any((d) => d.startsWith('Floor 1:')), isTrue);
          expect(dirs.any((d) => d.startsWith('Floor 2:')), isTrue);
          expect(dirs.any((d) => d.startsWith('Take the')), isTrue);
          expect(dirs.last, 'Arrive at destination.');
        });
  });
}
/// Builds a trivial one-room, one-waypoint floor with a single edge.
Floor _simpleFloor({
  required int level,
  required String roomId,
  String roomName = '',
  String waypointId = 'wp',
}) {
  final room = NavNode(
      id: roomId, type: 'room', x: 0, y: 0, name: roomName);
  final wp =
  NavNode(id: waypointId, type: 'hallway_waypoint', x: 10, y: 0);
  final graph = NavGraph(
    nodes: [room, wp],
    edges: [
      NavEdge(from: roomId, to: waypointId, weight: 10),
    ],
  );
  return Floor(
      level: level,
      label: 'F$level',
      rooms: [Room(id: roomId, name: roomName.isNotEmpty ? roomName : roomId, boundary:
      [
        Offset(room.x -  0.025, room.y -  0.025),
        Offset(room.x +  0.025, room.y -  0.025),
        Offset(room.x -  0.025, room.y +  0.025),
        Offset(room.x +  0.025, room.y +  0.025),
      ]
      )],
      navGraph: graph);
}

CampusBuilding _building() => CampusBuilding(
  id: 'b1',
  name: 'Test',
  campus: Campus.sgw,
  boundary: const [], fullName: '', description: '',
);
List<Offset> _fakeBoundary(double cx, double cy) {
  const h = 0.025;
  return [
    Offset(cx - h, cy - h),
    Offset(cx + h, cy - h),
    Offset(cx + h, cy + h),
    Offset(cx - h, cy + h),
  ];
}