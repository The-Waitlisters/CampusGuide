// US-5.3: User can enable an accessibility option for indoor directions.
//         Routes avoid stairs when accessibility mode is enabled.
//         Elevators and ramps are prioritized when available.
//         If no accessible route exists, the user is informed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/nav_graph.dart';
import 'package:proj/models/room.dart';
import 'package:proj/models/vertical_link.dart';
import 'package:proj/screens/indoor_map_screen.dart';

import 'helpers.dart';

// ── Test building ─────────────────────────────────────────────────────────────

final _kBuilding = CampusBuilding(
  id: 'test-H',
  name: 'H',
  fullName: 'Henry F. Hall Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

// ── Rooms ─────────────────────────────────────────────────────────────────────
//
// Floor 1 — start room only.
// Floor 2 — two destinations:
//   H-210: reachable via elevator ONLY.
//   H-220: reachable via stairs  ONLY.
//
// This lets the test verify:
//   • With "Any"      → both rooms reachable.
//   • With "Elevator" → H-210 reachable, H-220 NOT reachable ("No route found").
//   • No-accessible-route case covered without changing the building.

const _kRoom110 = Room(id: 'H-110', name: 'H-110', boundary: <Offset>[]);
const _kRoom210 = Room(id: 'H-210', name: 'H-210', boundary: <Offset>[]);
const _kRoom220 = Room(id: 'H-220', name: 'H-220', boundary: <Offset>[]);

// ── Navigation graphs ─────────────────────────────────────────────────────────
//
// Floor 1 layout:
//   H-110 ──(50)── elevator_f1
//   H-110 ──(50)── stairs_f1
//
// Floor 2 layout:
//   elevator_f2 ──(50)── H-210   (elevator side)
//   stairs_f2   ──(50)── H-220   (stairs side)
//
// The two sides of floor 2 are NOT connected to each other, so H-210 and
// H-220 are each reachable from floor 1 by one transport mode only.

final _kNavGraph1 = NavGraph(
  nodes: const [
    NavNode(id: 'H-110',       type: 'room',          x: 0.50, y: 0.50),
    NavNode(id: 'elevator_f1', type: 'elevator_door',  x: 0.30, y: 0.50),
    NavNode(id: 'stairs_f1',   type: 'stair_landing',  x: 0.70, y: 0.50),
  ],
  edges: const [
    NavEdge(from: 'H-110', to: 'elevator_f1', weight: 50),
    NavEdge(from: 'H-110', to: 'stairs_f1',   weight: 50),
  ],
);

final _kNavGraph2 = NavGraph(
  nodes: const [
    NavNode(id: 'elevator_f2', type: 'elevator_door',  x: 0.30, y: 0.50),
    NavNode(id: 'H-210',       type: 'room',          x: 0.20, y: 0.50),
    NavNode(id: 'stairs_f2',   type: 'stair_landing',  x: 0.70, y: 0.50),
    NavNode(id: 'H-220',       type: 'room',          x: 0.80, y: 0.50),
  ],
  edges: const [
    NavEdge(from: 'elevator_f2', to: 'H-210', weight: 50),
    NavEdge(from: 'stairs_f2',   to: 'H-220', weight: 50),
    // The two halves of floor 2 are intentionally NOT connected.
  ],
);

// ── Stub map ──────────────────────────────────────────────────────────────────

final _kIndoorMap = IndoorMap(
  building: _kBuilding,
  floors: [
    Floor(
      level: 1,
      label: 'Floor 1',
      rooms: const [_kRoom110],
      imagePath: 'assets/indoor/H_1.png',
      imageAspectRatio: 1.0,
      navGraph: _kNavGraph1,
    ),
    Floor(
      level: 2,
      label: 'Floor 2',
      rooms: const [_kRoom210, _kRoom220],
      imagePath: 'assets/indoor/H_2.png',
      imageAspectRatio: 1.0,
      navGraph: _kNavGraph2,
    ),
  ],
  // Explicit vertical links — elevator connects elevator nodes, stairs connect
  // stair nodes. _inferVerticalLinks automatically adds both directions.
  verticalLinks: const [
    VerticalLink(
      fromFloor: 1, fromNodeId: 'elevator_f1',
      toFloor:   2, toNodeId:   'elevator_f2',
      kind: VerticalLinkKind.elevator,
    ),
    VerticalLink(
      fromFloor: 1, fromNodeId: 'stairs_f1',
      toFloor:   2, toNodeId:   'stairs_f2',
      kind: VerticalLinkKind.stairs,
    ),
  ],
);

Future<IndoorMap?> _mockLoader(CampusBuilding _) async => _kIndoorMap;

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Taps a room row inside the ListView (not a chip in RouteControls).
Future<void> _tapRoom(WidgetTester tester, String roomName) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ListView),
      matching: find.text(roomName),
    ).first,
  );
  await pumpFor(tester, const Duration(milliseconds: 300));
}

/// Opens the floor dropdown and selects [floorLabel].
Future<void> _switchFloor(WidgetTester tester, String floorLabel) async {
  await tester.tap(find.byType(DropdownButton<int>));
  await pumpFor(tester, const Duration(milliseconds: 300));
  await tester.tap(find.text(floorLabel).last);
  await pumpFor(tester, const Duration(milliseconds: 300));
}

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.3: accessibility mode uses elevator, avoids stairs, '
    'informs user when no accessible route exists',
    (tester) async {
      // ── Pump the screen ──────────────────────────────────────────────────────
      await tester.pumpWidget(
        MaterialApp(
          home: IndoorMapScreen(
            building: _kBuilding,
            mapLoader: _mockLoader,
          ),
        ),
      );

      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(1); // observe loaded screen

      // ─── Set H-110 (floor 1) as start ────────────────────────────────────────

      expect(find.text('H-110'), findsOneWidget,
          reason: 'H-110 must appear on floor 1');

      await _tapRoom(tester, 'H-110');
      await pause(1);

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe start chip

      // ─── Switch to floor 2 and set H-210 (elevator-only) as destination ──────

      await _switchFloor(tester, 'Floor 2');
      await pause(1); // observe floor 2

      expect(find.text('H-210'), findsOneWidget,
          reason: 'H-210 must appear on floor 2');
      expect(find.text('H-220'), findsOneWidget,
          reason: 'H-220 must appear on floor 2');

      await _tapRoom(tester, 'H-210');
      await pause(1);

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe initial route (Any preference)

      // Default "Any" preference — elevator path to H-210 exists.
      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'A route must exist from H-110 to H-210 with "Any" preference',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear when a valid route exists',
      );

      // ─── AC: Elevators prioritised — "Elevator" mode still finds H-210 ───────

      await tester.tap(find.text('Elevator'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe elevator-only route

      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Elevator route to H-210 must still be found in accessibility mode',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear — elevator reaches H-210',
      );

      // ─── AC: Routes avoid stairs when accessibility mode is enabled ───────────
      // ─── AC: User informed when no accessible route exists ────────────────────
      //
      // H-220 is only reachable via stairs. With "Elevator" preference active,
      // the stair link is filtered → no path → "No route found".

      await _switchFloor(tester, 'Floor 2');
      await pause(1); // back to floor 2 to select H-220

      await _tapRoom(tester, 'H-220');
      await pause(1);

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe no-route state

      expect(
        find.text('No route found'),
        findsOneWidget,
        reason:
            '"No route found" must appear: H-220 is stair-only but elevator '
            'mode is active',
      );
      expect(
        find.textContaining('steps'),
        findsNothing,
        reason: 'Step count must NOT appear when no accessible path exists',
      );

      // ─── Switching back to "Any" restores the route ───────────────────────────

      await tester.tap(find.text('Any'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe restored route

      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Route to H-220 via stairs must be restored when "Any" is selected',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must disappear once a valid route is available',
      );

      await pause(1); // final visual pause
    },
  );
}
