// US-5.3: User can enable an accessibility option for indoor directions.
//         Routes respect the selected vertical preference (Any / Elevator / Stairs).
//         The preference can be toggled and the route updates automatically.

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

// ── Real Hall building ─────────────────────────────────────────────────────────
// Uses the real H.json so production routing drives the test.
//
// Normalised positions from H.json (imageWidth = imageHeight = 2000):
//   Floor 1 — H-110  nx=0.262  ny=0.636
//   Floor 2 — H-231  nx=0.391  ny=0.225
//
// H has both elevator and stair vertical links between floors, so all three
// preference modes (Any / Elevator / Stairs) produce a valid route.

final _kBuilding = CampusBuilding(
  id: 'hall-building',
  name: 'H',
  fullName: 'Henry F. Hall Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

const _kH110  = (nx: 0.262, ny: 0.636); // floor 1
const _kH231  = (nx: 0.391, ny: 0.225); // floor 2

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.3: accessibility preference chips (Any / Elevator / Stairs) '
    'all produce valid multi-floor routes in the real Hall building',
    (tester) async {
      // ── Pump the screen with the real loader ──────────────────────────────────
      await tester.pumpWidget(
        MaterialApp(
          home: IndoorMapScreen(building: _kBuilding),
        ),
      );

      // Wait for the real JSON asset to load and parse.
      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2); // observe loaded screen

      expect(find.text('Henry F. Hall Building'), findsOneWidget,
          reason: 'AppBar must show the building name');

      // Helper: get the map canvas rect.
      Rect mapRect() =>
          tester.getRect(find.byType(InteractiveViewer).first);

      // Helper: tap at a normalised position on the current floor plan.
      Future<void> tapMap(({double nx, double ny}) pos) async {
        final r = mapRect();
        await tester.tapAt(Offset(
          r.left + pos.nx * r.width,
          r.top  + pos.ny * r.height,
        ));
        await pumpFor(tester, const Duration(milliseconds: 300));
      }

      // Helper: open floor dropdown and select a floor.
      Future<void> switchFloor(String floorLabel) async {
        await tester.tap(find.byType(DropdownButton<int>));
        await pumpFor(tester, const Duration(milliseconds: 300));
        await tester.tap(find.text(floorLabel).last);
        await pumpFor(tester, const Duration(milliseconds: 300));
      }

      // ─── Set H-110 (floor 1) as start via map tap ────────────────────────────

      await tapMap(_kH110);
      await pause(1); // observe H-110 selected

      expect(find.textContaining('Selected: H-110'), findsOneWidget,
          reason: 'RouteControls must show "Selected: H-110" after map tap');

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe start chip

      // ─── Switch to floor 2 and set H-231 as destination via map tap ──────────

      await switchFloor('Floor 2');
      await pause(1); // observe floor 2 map

      await tapMap(_kH231);
      await pause(1); // observe H-231 selected

      expect(find.textContaining('Selected: H-231'), findsOneWidget,
          reason: 'RouteControls must show "Selected: H-231" after map tap on floor 2');

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe route with default "Any" preference

      // ─── AC: Default "Any" preference — multi-floor route exists ─────────────

      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'A route must exist from H-110 to H-231 with "Any" preference',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear for a valid route',
      );

      // ─── AC: "Elevator" preference — elevator link is used ───────────────────

      await tester.tap(find.text('Elevator'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe elevator-preference route

      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Elevator route to H-231 must be found (Hall has an elevator)',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear — elevator reaches floor 2',
      );

      // ─── AC: "Stairs" preference — stair link is used ────────────────────────

      await tester.tap(find.text('Stairs'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe stairs-preference route

      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Stairs route to H-231 must be found (Hall has stairs)',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear — stairs reach floor 2',
      );

      // ─── AC: Toggling back to "Any" keeps the route ───────────────────────────

      await tester.tap(find.text('Any'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe restored "Any" route

      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Route must still appear after switching back to "Any"',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear with "Any" preference',
      );

      await pause(1); // final visual pause
    },
  );

  // ── Mock test: no route available ─────────────────────────────────────────────
  //
  // Two rooms on a single floor with NO edges between them and NO hallway
  // waypoints. withAutoConnections is a no-op (it only links rooms to their
  // nearest waypoint — nothing to link here), so pathfinding finds no path.
  //
  // This verifies the AC: "If no accessible route exists, the user is informed."

  const _kRoomA = Room(id: 'A-101', name: 'A-101', boundary: <Offset>[]);
  const _kRoomB = Room(id: 'B-101', name: 'B-101', boundary: <Offset>[]);

  final _kIsolatedMap = IndoorMap(
    building: CampusBuilding(
      id: 'mock-isolated',
      name: 'X',
      fullName: 'Isolated Building',
      campus: Campus.sgw,
      description: '',
      boundary: const [],
    ),
    floors: [
      Floor(
        level: 1,
        label: 'Floor 1',
        rooms: const [_kRoomA, _kRoomB],
        imagePath: 'assets/indoor/H_1.png',
        imageAspectRatio: 1.0,
        navGraph: NavGraph(
          // Two room nodes placed far apart, no edges, no waypoints.
          // withAutoConnections is a no-op without waypoints.
          nodes: const [
            NavNode(id: 'A-101', type: 'room', x: 0.10, y: 0.50),
            NavNode(id: 'B-101', type: 'room', x: 0.90, y: 0.50),
          ],
          edges: const [],
        ),
      ),
    ],
  );

  testWidgets(
    'US-5.3: "No route found" is shown when start and destination are '
    'disconnected (mock building with no edges)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IndoorMapScreen(
            building: _kIsolatedMap.building,
            mapLoader: (_) async => _kIsolatedMap,
          ),
        ),
      );

      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(1); // observe loaded screen

      // Select A-101 from the room list as start.
      await tester.tap(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('A-101'),
        ).first,
      );
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      expect(find.textContaining('Selected: A-101'), findsOneWidget,
          reason: 'RouteControls must show "Selected: A-101"');

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // Select B-101 from the room list as destination.
      await tester.tap(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('B-101'),
        ).first,
      );
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      expect(find.textContaining('Selected: B-101'), findsOneWidget,
          reason: 'RouteControls must show "Selected: B-101"');

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe no-route state

      // No path exists between A-101 and B-101 — the UI must say so.
      expect(
        find.text('No route found'),
        findsOneWidget,
        reason: '"No route found" must appear when no path exists',
      );
      expect(
        find.textContaining('steps'),
        findsNothing,
        reason: 'Step count must NOT appear when no path exists',
      );

      await pause(1); // final visual pause
    },
  );
}
