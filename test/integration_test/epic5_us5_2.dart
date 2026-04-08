// US-5.2: Directions are generated only when both start and destination rooms
//         are selected. The shortest available path is displayed on the indoor
//         map. The route updates automatically when the start or destination
//         room changes. If no valid path exists, the user is informed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/nav_graph.dart';
import 'package:proj/models/room.dart';
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
// H-110, H-120, H-130 are connected via a hallway chain.
// H-140 is registered in the graph as a node but has NO edges → unreachable.

const _kRoom110 = Room(id: 'H-110', name: 'H-110', boundary: <Offset>[]);
const _kRoom120 = Room(id: 'H-120', name: 'H-120', boundary: <Offset>[]);
const _kRoom130 = Room(id: 'H-130', name: 'H-130', boundary: <Offset>[]);
const _kRoom140 = Room(id: 'H-140', name: 'H-140', boundary: <Offset>[]);

// ── Navigation graph ──────────────────────────────────────────────────────────
//
//   H-110 ──(50)── w1 ──(50)── H-120 ──(50)── w2 ──(50)── H-130
//   H-140  (isolated — no edges, path is impossible)
//
final _kNavGraph = NavGraph(
  nodes: const [
    NavNode(id: 'H-110', type: 'room',             x: 0.10, y: 0.50),
    NavNode(id: 'w1',    type: 'hallway_waypoint',  x: 0.25, y: 0.50),
    NavNode(id: 'H-120', type: 'room',             x: 0.40, y: 0.50),
    NavNode(id: 'w2',    type: 'hallway_waypoint',  x: 0.55, y: 0.50),
    NavNode(id: 'H-130', type: 'room',             x: 0.70, y: 0.50),
    NavNode(id: 'H-140', type: 'room',             x: 0.90, y: 0.90),
  ],
  edges: const [
    NavEdge(from: 'H-110', to: 'w1',    weight: 50),
    NavEdge(from: 'w1',    to: 'H-120', weight: 50),
    NavEdge(from: 'H-120', to: 'w2',    weight: 50),
    NavEdge(from: 'w2',    to: 'H-130', weight: 50),
    // H-140 intentionally has no edges.
  ],
);

// ── Stub map ──────────────────────────────────────────────────────────────────

final _kIndoorMap = IndoorMap(
  building: _kBuilding,
  floors: [
    Floor(
      level: 1,
      label: 'Floor 1',
      rooms: const [_kRoom110, _kRoom120, _kRoom130, _kRoom140],
      imagePath: 'assets/indoor/H_1.png',
      imageAspectRatio: 1.0,
      navGraph: _kNavGraph,
    ),
  ],
);

Future<IndoorMap?> _mockLoader(CampusBuilding _) async => _kIndoorMap;

// ── Helper ────────────────────────────────────────────────────────────────────

/// Taps a room row in the ListView (scoped away from RouteControls chips).
Future<void> _tapRoom(WidgetTester tester, String roomName) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ListView),
      matching: find.text(roomName),
    ).first,
  );
  await pumpFor(tester, const Duration(milliseconds: 300));
}

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.2: route generated only when both rooms set, path displayed, '
    'updates on start/dest change, no-path message shown',
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

      // All four rooms must appear in the list on load.
      expect(find.text('H-110'), findsOneWidget);
      expect(find.text('H-120'), findsOneWidget);
      expect(find.text('H-130'), findsOneWidget);
      expect(find.text('H-140'), findsOneWidget);

      // ─── AC: No directions shown when only the start room is selected ────────

      await _tapRoom(tester, 'H-110');
      await pause(1); // observe H-110 selected

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe start chip, no route yet

      // Destination is not set → neither "No route found" nor a step count
      // should be visible.
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear when destination is unset',
      );
      expect(
        find.textContaining('steps'),
        findsNothing,
        reason: 'Step count must NOT appear when destination is unset',
      );

      // ─── AC: Route appears (and path is displayed) once both are set ─────────

      await _tapRoom(tester, 'H-120');
      await pause(1); // observe H-120 selected

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe the route

      // H-110 → w1 → H-120 is reachable: a step count must now be visible.
      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Step count must appear when a valid route exists',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear when a valid path exists',
      );

      // ─── AC: Route updates automatically when the start room changes ─────────

      await _tapRoom(tester, 'H-130');
      await pause(1); // observe H-130 selected

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe updated route

      // H-130 → w2 → H-120 is also reachable — steps must still be shown.
      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Step count must still appear after start changes to H-130',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear for the updated valid route',
      );

      // The start chip must now identify H-130.
      expect(
        find.textContaining('H-130'),
        findsWidgets,
        reason: 'H-130 must appear in the start chip after being set as start',
      );
      await pause(1);

      // ─── AC: Route updates automatically when the destination room changes ───

      // H-110 now appears in RouteControls as the dest chip — _tapRoom scopes
      // the tap to the room list so the chip is not accidentally hit.
      await _tapRoom(tester, 'H-110');
      await pause(1); // observe H-110 selected

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe updated route

      // H-130 → w2 → H-120 → w1 → H-110 is reachable — steps must still show.
      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Step count must still appear after destination changes to H-110',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear for the updated valid route',
      );

      // The destination chip must now identify H-110.
      // (H-110 is also in the room list → findsWidgets is intentional.)
      expect(
        find.textContaining('H-110'),
        findsWidgets,
        reason: 'H-110 must appear in the destination chip',
      );
      await pause(1);

      // ─── AC: User is informed when no valid path exists ──────────────────────

      // H-140 is isolated (no graph edges) — selecting it as destination must
      // trigger the "No route found" message.
      await _tapRoom(tester, 'H-140');
      await pause(1); // observe H-140 selected

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe the no-route state

      expect(
        find.text('No route found'),
        findsOneWidget,
        reason: '"No route found" must appear when no path exists to H-140',
      );
      expect(
        find.textContaining('steps'),
        findsNothing,
        reason: 'Step count must NOT appear when no path is available',
      );

      await pause(1); // final visual pause
    },
  );
}
