import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/nav_graph.dart';

void main() {

  NavNode room(String id, double x, double y) =>
      NavNode(id: id, type: 'room', x: x, y: y, name: id);

  NavNode waypoint(String id, double x, double y) =>
      NavNode(id: id, type: 'hallway_waypoint', x: x, y: y);

  group('US-5.1: NavNode', () {
    test('isRoom is true for room type', () {
      const n = NavNode(id: 'r1', type: 'room', x: 0, y: 0);
      expect(n.isRoom, true);
    });

    test('isRoom is true for stair_landing type', () {
      const n = NavNode(id: 'n1', type: 'stair_landing', x: 0, y: 0);
      expect(n.isRoom, true);
    });

    test('isRoom is true for elevator_door type', () {
      const n = NavNode(id: 'n1', type: 'elevator_door', x: 0, y: 0);
      expect(n.isRoom, true);
    });

    test('isRoom is true for building_entry_exit type', () {
      const n = NavNode(id: 'n1', type: 'building_entry_exit', x: 0, y: 0);
      expect(n.isRoom, true);
    });

    test('isRoom is false for hallway_waypoint type', () {
      const n = NavNode(id: 'w1', type: 'hallway_waypoint', x: 0, y: 0);
      expect(n.isRoom, false);
    });

    test('isWaypoint is true for hallway_waypoint type', () {
      const n = NavNode(id: 'w1', type: 'hallway_waypoint', x: 0, y: 0);
      expect(n.isWaypoint, true);
    });

    test('isWaypoint is true for doorway type', () {
      const n = NavNode(id: 'w1', type: 'doorway', x: 0, y: 0);
      expect(n.isWaypoint, true);
    });

    test('isWaypoint is false for room type', () {
      const n = NavNode(id: 'r1', type: 'room', x: 0, y: 0);
      expect(n.isWaypoint, false);
    });

    test('name defaults to empty string', () {
      const n = NavNode(id: 'r1', type: 'room', x: 0, y: 0);
      expect(n.name, '');
    });
  });

  // ---------------------------------------------------------------------------

  group('US-5.1: NavGraph — lookup', () {
    late NavGraph graph;

    setUp(() {
      graph = NavGraph(
        nodes: [room('A', 0.1, 0.1), room('B', 0.5, 0.5), room('C', 0.9, 0.9)],
        edges: [
          const NavEdge(from: 'A', to: 'B', weight: 100),
          const NavEdge(from: 'B', to: 'C', weight: 100),
        ],
      );
    });

    test('nodeById returns correct node', () {
      expect(graph.nodeById('B')?.id, 'B');
    });

    test('nodeById returns null for unknown id', () {
      expect(graph.nodeById('Z'), isNull);
    });
  });

  // ---------------------------------------------------------------------------

  group('US-5.1: NavGraph — Dijkstra pathfinding', () {
    // Linear: A –100– W1 –100– W2 –100– B
    late NavGraph graph;

    setUp(() {
      graph = NavGraph(
        nodes: [
          room('A', 0.1, 0.5),
          waypoint('W1', 0.3, 0.5),
          waypoint('W2', 0.6, 0.5),
          room('B', 0.9, 0.5),
        ],
        edges: [
          const NavEdge(from: 'A', to: 'W1', weight: 100),
          const NavEdge(from: 'W1', to: 'W2', weight: 100),
          const NavEdge(from: 'W2', to: 'B', weight: 100),
        ],
      );
    });

    test('findPath returns correct ordered path', () {
      final path = graph.findPath('A', 'B');
      expect(path, ['A', 'W1', 'W2', 'B']);
    });

    test('findPath returns single-element list when start equals destination', () {
      final path = graph.findPath('A', 'A');
      expect(path, ['A']);
    });

    test('findPath returns null for unknown source node', () {
      expect(graph.findPath('Z', 'B'), isNull);
    });

    test('findPath returns null for unknown destination node', () {
      expect(graph.findPath('A', 'Z'), isNull);
    });

    test('findPath returns null when no route exists', () {
      // Isolated node with no edges
      final isolated = NavGraph(
        nodes: [room('A', 0.1, 0.1), room('B', 0.9, 0.9)],
        edges: [],
      );
      expect(isolated.findPath('A', 'B'), isNull);
    });

    test('findPath chooses shorter path over longer one', () {
      // A –50– W –50– B  (direct 100) vs A –200– C –200– B (detour 400)
      final g = NavGraph(
        nodes: [
          room('A', 0.0, 0.5),
          waypoint('W', 0.5, 0.5),
          waypoint('C', 0.5, 0.0),
          room('B', 1.0, 0.5),
        ],
        edges: [
          const NavEdge(from: 'A', to: 'W', weight: 50),
          const NavEdge(from: 'W', to: 'B', weight: 50),
          const NavEdge(from: 'A', to: 'C', weight: 200),
          const NavEdge(from: 'C', to: 'B', weight: 200),
        ],
      );
      final path = g.findPath('A', 'B');
      expect(path, ['A', 'W', 'B']);
    });

    test('graph is undirected — path works in reverse', () {
      final forward = graph.findPath('A', 'B');
      final backward = graph.findPath('B', 'A');
      expect(forward, isNotNull);
      expect(backward, isNotNull);
      expect(backward, forward!.reversed.toList());
    });
  });

  // ---------------------------------------------------------------------------

  group('US-5.1: NavGraph — withAutoConnections', () {
    test('connects isolated room to nearest waypoint', () {
      final g = NavGraph(
        nodes: [
          room('R1', 0.1, 0.5),
          waypoint('W1', 0.3, 0.5),
          waypoint('W2', 0.7, 0.5),
        ],
        edges: [
          const NavEdge(from: 'W1', to: 'W2', weight: 400),
        ],
      ).withAutoConnections(pixelScale: 1000);

      // Room R1 should now be reachable from W2 via W1
      final path = g.findPath('R1', 'W2');
      expect(path, isNotNull);
      expect(path!.first, 'R1');
      expect(path.last, 'W2');
    });

    test('two rooms can find path through shared waypoints after auto-connect', () {
      final g = NavGraph(
        nodes: [
          room('R1', 0.1, 0.5),
          room('R2', 0.9, 0.5),
          waypoint('W1', 0.3, 0.5),
          waypoint('W2', 0.7, 0.5),
        ],
        edges: [
          const NavEdge(from: 'W1', to: 'W2', weight: 400),
        ],
      ).withAutoConnections(pixelScale: 1000);

      final path = g.findPath('R1', 'R2');
      expect(path, isNotNull);
      expect(path!.first, 'R1');
      expect(path.last, 'R2');
    });

    test('returns same graph when no waypoints exist', () {
      final g = NavGraph(
        nodes: [room('R1', 0.1, 0.5), room('R2', 0.9, 0.5)],
        edges: [const NavEdge(from: 'R1', to: 'R2', weight: 800)],
      ).withAutoConnections();

      expect(g.findPath('R1', 'R2'), ['R1', 'R2']);
    });

    test('connects orphan waypoint to nearest connected waypoint', () {
      final g = NavGraph(
        nodes: [
          room('R1', 0.1, 0.5),
          waypoint('W1', 0.3, 0.5),
          waypoint('W2', 0.7, 0.5),
          waypoint('W_orphan', 0.5, 0.5),
        ],
        edges: [
          const NavEdge(from: 'W1', to: 'W2', weight: 400),
        ],
      ).withAutoConnections(pixelScale: 1000);

      final path = g.findPath('R1', 'W_orphan');
      expect(path, isNotNull);
      expect(path!.first, 'R1');
      expect(path!.last, 'W_orphan');
    });
  });
}
