// US-5.6: The system supports indoor directions between different buildings.
//         Indoor and outdoor navigation segments are seamlessly connected.
//         Routes between SGW and Loyola are supported.
//         Transitions between buildings are clearly indicated.
//         The full route is understandable and continuous.
//
// MultiBuildingRouteScreen manages three phases:
//   1. indoorStart  — navigate from start room to building exit
//   2. outdoor      — walk/transit between buildings
//   3. indoorEnd    — navigate from building entry to destination room
//
// The test pumps the screen directly with stub IndoorMaps so no network,
// Firebase or HomeScreen plumbing is required.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/nav_graph.dart';
import 'package:proj/models/room.dart';
import 'package:proj/screens/multi_building_route_screen.dart';

import 'helpers.dart';

// ── Buildings ─────────────────────────────────────────────────────────────────
//
// SGW  — Henry F. Hall Building (H)
// Loyola — VL/VE Building (VL)
//
// Different campuses → _isCrossCampus = true → shuttle bus tip shown.

final _kStartBuilding = CampusBuilding(
  id: 'sgw-H',
  name: 'H',
  fullName: 'Henry F. Hall Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

final _kEndBuilding = CampusBuilding(
  id: 'loy-VL',
  name: 'VL',
  fullName: 'VL/VE Building',
  campus: Campus.loyola,
  description: '',
  boundary: const [],
);

// ── Rooms ─────────────────────────────────────────────────────────────────────

const _kRoomH110  = Room(id: 'H-110',   name: 'H-110',   boundary: <Offset>[]);
const _kRoomVL110 = Room(id: 'VL-110',  name: 'VL-110',  boundary: <Offset>[]);

// ── NavGraphs ─────────────────────────────────────────────────────────────────
//
// Start building (H):
//   H-110 ──(50)── entry_w ──(50)── entry_exit (building_entry_exit)
//
//   MultiBuildingRoutePlanner.findEntryExitNode() finds 'entry_exit' because
//   its type is 'building_entry_exit'.  The screen then routes:
//     startRoom='H-110'  →  exit='entry_exit'  →  indoor segment computed.
//
// End building (VL):
//   entry_node (building_entry_exit) ──(50)── vl_w ──(50)── VL-110
//
//   Entry node found by findEntryExitNode(); end indoor segment is:
//     entry='entry_node'  →  destRoom='VL-110'.

final _kStartNavGraph = NavGraph(
  nodes: const [
    NavNode(id: 'H-110',      type: 'room',                 x: 0.10, y: 0.50),
    NavNode(id: 'entry_w',    type: 'hallway_waypoint',      x: 0.45, y: 0.50),
    NavNode(id: 'entry_exit', type: 'building_entry_exit',   x: 0.80, y: 0.50),
  ],
  edges: const [
    NavEdge(from: 'H-110',    to: 'entry_w',    weight: 50),
    NavEdge(from: 'entry_w',  to: 'entry_exit', weight: 50),
  ],
);

final _kEndNavGraph = NavGraph(
  nodes: const [
    NavNode(id: 'entry_node', type: 'building_entry_exit',   x: 0.20, y: 0.50),
    NavNode(id: 'vl_w',       type: 'hallway_waypoint',      x: 0.55, y: 0.50),
    NavNode(id: 'VL-110',     type: 'room',                 x: 0.90, y: 0.50),
  ],
  edges: const [
    NavEdge(from: 'entry_node', to: 'vl_w',    weight: 50),
    NavEdge(from: 'vl_w',       to: 'VL-110',  weight: 50),
  ],
);

// ── IndoorMaps ────────────────────────────────────────────────────────────────

final _kStartMap = IndoorMap(
  building: _kStartBuilding,
  floors: [
    Floor(
      level: 1,
      label: 'Floor 1',
      rooms: const [_kRoomH110],
      imagePath: 'assets/indoor/H_1.png',
      imageAspectRatio: 1.0,
      navGraph: _kStartNavGraph,
    ),
  ],
);

final _kEndMap = IndoorMap(
  building: _kEndBuilding,
  floors: [
    Floor(
      level: 1,
      label: 'Floor 1',
      rooms: const [_kRoomVL110],
      imagePath: 'assets/indoor/H_1.png', // reuse any asset for rendering
      imageAspectRatio: 1.0,
      navGraph: _kEndNavGraph,
    ),
  ],
);

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.6: multi-building route — indoor/outdoor segments, SGW↔Loyola '
    'supported, transitions indicated, full route continuous',
    (tester) async {
      // ── Pump MultiBuildingRouteScreen directly with stub data ────────────────
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBuildingRouteScreen(
            startBuilding: _kStartBuilding,
            endBuilding: _kEndBuilding,
            startRoomId: 'H-110',
            endRoomId: 'VL-110',
            startIndoorMap: _kStartMap,
            endIndoorMap: _kEndMap,
            transportModeLabel: 'Walk',
            // Inject outdoor info so the outdoor phase shows duration.
            outdoorDuration: '~8 min walk',
            outdoorDistance: '650 m',
          ),
        ),
      );

      // _computeRoutes() is synchronous (no awaits) — one pump resolves it.
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(1); // observe initial indoorStart phase

      // ─── AC: Full route is understandable — three-phase bar always visible ───

      // Phase bar must show all three segments of the journey.
      expect(find.text('H'),    findsOneWidget,
          reason: 'Start-building chip must show "H"');
      expect(find.text('Walk'), findsOneWidget,
          reason: 'Transport-mode chip must show "Walk"');
      expect(find.text('VL'),   findsOneWidget,
          reason: 'End-building chip must show "VL"');

      // Phase bar arrows connect the three chips.
      expect(find.byIcon(Icons.chevron_right), findsWidgets,
          reason: 'Arrows between phase chips must be visible');

      // ─── AC: Indoor navigation in start building shown in phase 1 ────────────

      // Phase title: "Navigate to exit — Henry F. Hall Building"
      expect(
        find.textContaining('Navigate to exit'),
        findsOneWidget,
        reason: 'Phase 1 title must direct user to the building exit',
      );
      expect(
        find.textContaining('Henry F. Hall Building'),
        findsOneWidget,
        reason: 'Phase 1 must reference the start building by name',
      );

      // The indoor route for the start building is displayed (floor plan
      // canvas and direction steps).
      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: 'Floor plan canvas must be shown in the indoor start phase',
      );
      expect(
        find.textContaining('Floor 1'),
        findsWidgets,
        reason: 'Floor-level label must appear in the indoor route directions',
      );
      await pause(1);

      // ─── AC: Transition out of start building clearly indicated ──────────────

      // The continue button explicitly tells the user they are exiting the building.
      expect(
        find.textContaining("I've exited"),
        findsOneWidget,
        reason: 'Phase 1 continue button must say "I\'ve exited …"',
      );

      // ─── AC: Outdoor segment shown — SGW → Loyola (cross-campus) ─────────────

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe outdoor phase

      // Phase title: "Walk to VL/VE Building"
      expect(
        find.textContaining('Walk to'),
        findsOneWidget,
        reason: 'Outdoor phase title must describe the journey',
      );
      expect(
        find.textContaining('VL/VE Building'),
        findsWidgets,
        reason: 'Outdoor phase must reference the destination building',
      );

      // Cross-campus route: transit icon is shown (not just walking).
      expect(
        find.byIcon(Icons.directions_transit),
        findsOneWidget,
        reason: 'SGW → Loyola is cross-campus, so the transit icon must appear',
      );

      // ─── AC: Routes between SGW and Loyola supported — shuttle tip shown ─────

      expect(
        find.textContaining('shuttle bus'),
        findsOneWidget,
        reason:
            'Cross-campus routes must mention the Concordia shuttle bus option',
      );

      // ─── AC: Outdoor duration and distance are shown ──────────────────────────

      expect(
        find.textContaining('~8 min walk'),
        findsOneWidget,
        reason: 'Outdoor duration must be displayed in the outdoor phase',
      );
      expect(
        find.textContaining('650 m'),
        findsOneWidget,
        reason: 'Outdoor distance must be displayed in the outdoor phase',
      );
      await pause(1);

      // ─── AC: Transition into destination building clearly indicated ───────────

      // The outdoor continue button names the destination building.
      expect(
        find.textContaining("I've arrived at"),
        findsOneWidget,
        reason: 'Outdoor continue button must confirm arrival at end building',
      );
      expect(
        find.textContaining('VL/VE Building'),
        findsWidgets,
        reason: 'Outdoor continue button must name the destination building',
      );

      // ─── AC: Indoor navigation in destination building shown in phase 3 ───────

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe indoorEnd phase

      // Phase title: "Navigate inside — VL/VE Building"
      expect(
        find.textContaining('Navigate inside'),
        findsOneWidget,
        reason: 'Phase 3 title must direct user inside the destination building',
      );
      expect(
        find.textContaining('VL/VE Building'),
        findsWidgets,
        reason: 'Phase 3 must reference the destination building by name',
      );

      // Indoor floor plan canvas must be shown for the end building.
      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: 'Floor plan canvas must be shown in the indoor end phase',
      );

      // ─── AC: Indoor and outdoor segments seamlessly connected ─────────────────
      // The start-building chip (H) is now marked as completed (✓ icon).
      // The outdoor chip is also done. Only indoorEnd is still active.

      expect(
        find.byIcon(Icons.check_circle),
        findsWidgets,
        reason:
            'Completed phases must show a check-circle icon in the phase bar',
      );

      // ─── AC: Full route continuous — done button completes navigation ─────────

      expect(
        find.textContaining('Done'),
        findsOneWidget,
        reason: 'Phase 3 final button must say "Done — arrived at destination"',
      );

      await pause(2); // final visual pause
    },
  );
}
