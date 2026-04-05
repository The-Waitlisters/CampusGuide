import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/nav_graph.dart';
import 'package:proj/models/room.dart';
import 'package:proj/models/vertical_link.dart';
import 'package:proj/screens/multi_building_route_screen.dart';

void main() {
  Future<void> pushScreen(WidgetTester tester) async {
    await tester.tap(find.text('Placeholder'));
    await tester.pumpAndSettle();
  }

  group('MultiBuildingRouteScreen — 3-phase navigation', () {
    testWidgets('renders phase bar with 3 phases', (tester) async {
      await tester.pumpWidget(_buildApp());
      await pushScreen(tester);

      expect(find.text('H'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('MB'), findsOneWidget);
    });

    testWidgets('starts in indoor-start phase', (tester) async {
      await tester.pumpWidget(_buildApp());
      await pushScreen(tester);

      expect(find.textContaining('exit'), findsWidgets);
    });

    testWidgets('continue button advances to outdoor phase', (tester) async {
      await tester.pumpWidget(_buildApp());
      await pushScreen(tester);

      final continueBtn = find.byKey(const Key('phase_continue_button'));
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Walk from'), findsOneWidget);
    });

    testWidgets('continue button advances to indoor-end phase', (tester) async {
      await tester.pumpWidget(_buildApp());
      await pushScreen(tester);

      final btn = find.byKey(const Key('phase_continue_button'));
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Navigate inside'), findsOneWidget);
    });

    testWidgets('done button pops the screen', (tester) async {
      await tester.pumpWidget(_buildApp());
      await pushScreen(tester);

      final btn = find.byKey(const Key('phase_continue_button'));
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Placeholder'), findsOneWidget);
    });

    testWidgets('close button pops the screen', (tester) async {
      await tester.pumpWidget(_buildApp());
      await pushScreen(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Placeholder'), findsOneWidget);
    });

    testWidgets('shows cross-campus shuttle advisory', (tester) async {
      await tester.pumpWidget(_buildApp(crossCampus: true));
      await pushScreen(tester);

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('crosses campuses'), findsOneWidget);
    });

    testWidgets('shows outdoor duration and distance', (tester) async {
      await tester.pumpWidget(_buildApp(
        outdoorDuration: '7 min',
        outdoorDistance: '500 m',
      ));
      await pushScreen(tester);

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      await tester.pumpAndSettle();

      expect(find.text('7 min'), findsOneWidget);
      expect(find.text('500 m'), findsOneWidget);
    });

    testWidgets('phase title uses short name when fullName is null',
        (tester) async {
      await tester.pumpWidget(_buildApp(shortNames: true));
      await pushScreen(tester);
      expect(find.textContaining('Navigate to exit — H'), findsOneWidget);
    });

    testWidgets('outdoor phase shows map when polyline provided',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        outdoorPolyline: const [
          LatLng(45.4973, -73.5789),
          LatLng(45.4975, -73.5785),
        ],
      ));
      await pushScreen(tester);

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      await tester.pumpAndSettle();

      expect(find.byType(GoogleMap), findsOneWidget);
    });
  });

  group('MultiBuildingRouteScreen — with indoor routes', () {
    testWidgets('indoor route view shows floor plan and directions',
        (tester) async {
      await tester.pumpWidget(_buildAppWithEntryExit());
      await pushScreen(tester);

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.textContaining('Floor'), findsWidgets);
    });

    testWidgets('multi-segment start route shows Next step button',
        (tester) async {
      await tester.pumpWidget(_buildAppWithMultiFloor());
      await pushScreen(tester);

      expect(find.textContaining('Next step'), findsOneWidget);
    });

    testWidgets('tapping Next step advances segment then completes phase',
        (tester) async {
      await tester.pumpWidget(_buildAppWithMultiFloor());
      await pushScreen(tester);

      final btn = find.byKey(const Key('phase_continue_button'));

      await tester.tap(btn);
      await tester.pumpAndSettle();

      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Walk from'), findsOneWidget);
    });

    testWidgets('indoor end phase with route shows floor view',
        (tester) async {
      await tester.pumpWidget(_buildAppWithEntryExit());
      await pushScreen(tester);

      final btn = find.byKey(const Key('phase_continue_button'));
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Navigate inside'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('floor chips are rendered for multi-segment routes',
        (tester) async {
      await tester.pumpWidget(_buildAppWithMultiFloor());
      await pushScreen(tester);

      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('tapping floor chip selects that segment', (tester) async {
      await tester.pumpWidget(_buildAppWithMultiFloor());
      await pushScreen(tester);

      final chips = find.byType(ChoiceChip);
      if (chips.evaluate().length > 1) {
        await tester.tap(chips.last);
        await tester.pumpAndSettle();
      }
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('indoor end phase Next step when end building is multi-floor',
        (tester) async {
      await tester.pumpWidget(_buildAppWithBothMultiFloor());
      await pushScreen(tester);

      final btn = find.byKey(const Key('phase_continue_button'));
      // Indoor start has 2 segments: first tap advances segment, second completes phase.
      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      // Outdoor -> indoor end
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Navigate inside'), findsOneWidget);
      expect(find.textContaining('Next step'), findsOneWidget);
    });

    testWidgets('outdoor phase without polyline shows no map', (tester) async {
      await tester.pumpWidget(_buildAppWithEntryExit());
      await pushScreen(tester);

      final btn = find.byKey(const Key('phase_continue_button'));
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(GoogleMap), findsNothing);
    });

    testWidgets('indoor fallback when maps have no floors', (tester) async {
      await tester.pumpWidget(_buildAppWithEmptyFloors());
      await pushScreen(tester);

      expect(find.textContaining('Head to the exit'), findsOneWidget);
    });

    testWidgets('outdoor phase duration only (no distance)', (tester) async {
      await tester.pumpWidget(_buildAppWithEntryExit(
        outdoorDuration: '3 min',
      ));
      await pushScreen(tester);

      final btn = find.byKey(const Key('phase_continue_button'));
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('3 min'), findsOneWidget);
    });

    testWidgets('full 3 phase navigation with indoor routes pops',
        (tester) async {
      await tester.pumpWidget(_buildAppWithEntryExit());
      await pushScreen(tester);

      final btn = find.byKey(const Key('phase_continue_button'));
      // indoor start -> outdoor
      await tester.tap(btn);
      await tester.pumpAndSettle();
      // outdoor -> indoor end
      await tester.tap(btn);
      await tester.pumpAndSettle();
      // indoor end -> pop
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Placeholder'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  bool crossCampus = false,
  String? outdoorDuration,
  String? outdoorDistance,
  List<LatLng>? outdoorPolyline,
  bool shortNames = false,
}) {
  final startBuilding = CampusBuilding(
    id: 'h1',
    name: 'H',
    fullName: shortNames ? null : 'Hall Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4973, -73.5789),
      LatLng(45.4974, -73.5789),
      LatLng(45.4974, -73.5788),
      LatLng(45.4973, -73.5788),
    ],
  );

  final endBuilding = CampusBuilding(
    id: 'mb1',
    name: 'MB',
    fullName: shortNames ? null : 'MB Building',
    description: '',
    campus: crossCampus ? Campus.loyola : Campus.sgw,
    boundary: const [
      LatLng(45.4975, -73.5785),
      LatLng(45.4976, -73.5785),
      LatLng(45.4976, -73.5784),
      LatLng(45.4975, -73.5784),
    ],
  );

  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            child: const Text('Placeholder'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBuildingRouteScreen(
                    startBuilding: startBuilding,
                    endBuilding: endBuilding,
                    startRoomId: 'R_H',
                    endRoomId: 'R_MB',
                    startIndoorMap: _makeMap(startBuilding, 'R_H'),
                    endIndoorMap: _makeMap(endBuilding, 'R_MB'),
                    transportModeLabel: 'Walk',
                    outdoorDuration: outdoorDuration,
                    outdoorDistance: outdoorDistance,
                    outdoorPolyline: outdoorPolyline,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Builds an app where start/end maps have an entry/exit node so _computeRoutes
/// produces real IndoorRoutes (covers _buildIndoorRouteView, _IndoorFloorView, painter).
Widget _buildAppWithEntryExit({
  String? outdoorDuration,
  String? outdoorDistance,
  List<LatLng>? outdoorPolyline,
}) {
  final startBuilding = CampusBuilding(
    id: 'h1',
    name: 'H',
    fullName: 'Hall Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4973, -73.5789),
      LatLng(45.4974, -73.5789),
      LatLng(45.4974, -73.5788),
      LatLng(45.4973, -73.5788),
    ],
  );

  final endBuilding = CampusBuilding(
    id: 'mb1',
    name: 'MB',
    fullName: 'MB Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4975, -73.5785),
      LatLng(45.4976, -73.5785),
      LatLng(45.4976, -73.5784),
      LatLng(45.4975, -73.5784),
    ],
  );

  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            child: const Text('Placeholder'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBuildingRouteScreen(
                    startBuilding: startBuilding,
                    endBuilding: endBuilding,
                    startRoomId: 'R_H',
                    endRoomId: 'R_MB',
                    startIndoorMap:
                        _makeMapWithEntryExit(startBuilding, 'R_H'),
                    endIndoorMap: _makeMapWithEntryExit(endBuilding, 'R_MB'),
                    transportModeLabel: 'Walk',
                    outdoorDuration: outdoorDuration,
                    outdoorDistance: outdoorDistance,
                    outdoorPolyline: outdoorPolyline,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Multi-floor map to exercise multi-segment indoor routing and "Next step".
Widget _buildAppWithMultiFloor() {
  final startBuilding = CampusBuilding(
    id: 'h1',
    name: 'H',
    fullName: 'Hall Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4973, -73.5789),
      LatLng(45.4974, -73.5789),
      LatLng(45.4974, -73.5788),
      LatLng(45.4973, -73.5788),
    ],
  );

  final endBuilding = CampusBuilding(
    id: 'mb1',
    name: 'MB',
    fullName: 'MB Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4975, -73.5785),
      LatLng(45.4976, -73.5785),
      LatLng(45.4976, -73.5784),
      LatLng(45.4975, -73.5784),
    ],
  );

  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            child: const Text('Placeholder'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBuildingRouteScreen(
                    startBuilding: startBuilding,
                    endBuilding: endBuilding,
                    startRoomId: 'R_H',
                    endRoomId: 'R_MB',
                    startIndoorMap: _makeMultiFloorMap(startBuilding, 'R_H'),
                    endIndoorMap:
                        _makeMapWithEntryExit(endBuilding, 'R_MB'),
                    transportModeLabel: 'Walk',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Both start and end use multi-floor maps so indoor-end can show "Next step".
Widget _buildAppWithBothMultiFloor() {
  final startBuilding = CampusBuilding(
    id: 'h1',
    name: 'H',
    fullName: 'Hall Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4973, -73.5789),
      LatLng(45.4974, -73.5789),
      LatLng(45.4974, -73.5788),
      LatLng(45.4973, -73.5788),
    ],
  );

  final endBuilding = CampusBuilding(
    id: 'mb1',
    name: 'MB',
    fullName: 'MB Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4975, -73.5785),
      LatLng(45.4976, -73.5785),
      LatLng(45.4976, -73.5784),
      LatLng(45.4975, -73.5784),
    ],
  );

  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            child: const Text('Placeholder'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBuildingRouteScreen(
                    startBuilding: startBuilding,
                    endBuilding: endBuilding,
                    startRoomId: 'R_H',
                    endRoomId: 'R_MB',
                    startIndoorMap: _makeMultiFloorMap(startBuilding, 'R_H'),
                    endIndoorMap: _makeMultiFloorMap(endBuilding, 'R_MB'),
                    transportModeLabel: 'Walk',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Widget _buildAppWithEmptyFloors() {
  final startBuilding = CampusBuilding(
    id: 'h1',
    name: 'H',
    fullName: 'Hall Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4973, -73.5789),
      LatLng(45.4974, -73.5789),
      LatLng(45.4974, -73.5788),
      LatLng(45.4973, -73.5788),
    ],
  );

  final endBuilding = CampusBuilding(
    id: 'mb1',
    name: 'MB',
    fullName: 'MB Building',
    description: '',
    campus: Campus.sgw,
    boundary: const [
      LatLng(45.4975, -73.5785),
      LatLng(45.4976, -73.5785),
      LatLng(45.4976, -73.5784),
      LatLng(45.4975, -73.5784),
    ],
  );

  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            child: const Text('Placeholder'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MultiBuildingRouteScreen(
                    startBuilding: startBuilding,
                    endBuilding: endBuilding,
                    startRoomId: 'R_H',
                    endRoomId: 'R_MB',
                    startIndoorMap: IndoorMap(building: startBuilding, floors: []),
                    endIndoorMap: IndoorMap(building: endBuilding, floors: []),
                    transportModeLabel: 'Walk',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

IndoorMap _makeMap(CampusBuilding b, String roomId) {
  final room =
      NavNode(id: roomId, type: 'room', x: 0.5, y: 0.5, name: roomId);
  final wp = NavNode(
      id: 'wp_${b.name}', type: 'hallway_waypoint', x: 0.6, y: 0.5);
  final graph = NavGraph(
    nodes: [room, wp],
    edges: [NavEdge(from: roomId, to: 'wp_${b.name}', weight: 10)],
  );
  final floor = Floor(
    level: 1,
    label: 'Floor 1',
    rooms: [
      Room(id: roomId, name: roomId, boundary: _fakeBoundary(0.5, 0.5))
    ],
    navGraph: graph,
  );
  return IndoorMap(building: b, floors: [floor]);
}

IndoorMap _makeMapWithEntryExit(CampusBuilding b, String roomId) {
  final entryNode = NavNode(
      id: 'entry_${b.name}',
      type: 'building_entry_exit',
      x: 0.5,
      y: 0.9,
      name: 'Main Entrance');
  final roomNode =
      NavNode(id: roomId, type: 'room', x: 0.5, y: 0.1, name: roomId);
  final wp = NavNode(
      id: 'wp_${b.name}', type: 'hallway_waypoint', x: 0.5, y: 0.5);

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
      Room(
          id: roomId, name: roomId, boundary: _fakeBoundary(0.5, 0.1)),
      Room(
          id: 'entry_${b.name}',
          name: 'Main Entrance',
          boundary: _fakeBoundary(0.5, 0.9)),
    ],
    navGraph: graph,
  );

  return IndoorMap(building: b, floors: [floor]);
}

/// Two floors with a vertical link so the planner produces a multi-segment route.
IndoorMap _makeMultiFloorMap(CampusBuilding b, String roomId) {
  final roomNode =
      NavNode(id: roomId, type: 'room', x: 0.3, y: 0.3, name: roomId);
  final stairF1 = NavNode(
      id: 'stair_f1_${b.name}',
      type: 'stair_landing',
      x: 0.5,
      y: 0.5,
      name: 'Stairs');

  final graph1 = NavGraph(
    nodes: [roomNode, stairF1],
    edges: [
      NavEdge(from: roomId, to: 'stair_f1_${b.name}', weight: 10),
    ],
  );

  final floor1 = Floor(
    level: 8,
    label: 'Floor 8',
    rooms: [
      Room(id: roomId, name: roomId, boundary: _fakeBoundary(0.3, 0.3)),
    ],
    navGraph: graph1,
  );

  final exitNode = NavNode(
      id: 'entry_${b.name}',
      type: 'building_entry_exit',
      x: 0.5,
      y: 0.9,
      name: 'Main Exit');
  final stairF0 = NavNode(
      id: 'stair_f0_${b.name}',
      type: 'stair_landing',
      x: 0.5,
      y: 0.5,
      name: 'Stairs');

  final graph0 = NavGraph(
    nodes: [stairF0, exitNode],
    edges: [
      NavEdge(from: 'stair_f0_${b.name}', to: 'entry_${b.name}', weight: 10),
    ],
  );

  final floor0 = Floor(
    level: 1,
    label: 'Floor 1',
    rooms: [
      Room(
          id: 'entry_${b.name}',
          name: 'Main Exit',
          boundary: _fakeBoundary(0.5, 0.9)),
    ],
    navGraph: graph0,
  );

  return IndoorMap(
    building: b,
    floors: [floor0, floor1],
    verticalLinks: [
      VerticalLink(
        fromFloor: 8,
        fromNodeId: 'stair_f1_${b.name}',
        toFloor: 1,
        toNodeId: 'stair_f0_${b.name}',
        kind: VerticalLinkKind.stairs,
        oneWay: false,
      ),
    ],
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
