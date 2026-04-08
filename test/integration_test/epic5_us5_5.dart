// US-5.5: The system detects when start and destination rooms are on different
//         floors. Routes include stairs or elevators as needed. Floor transitions
//         are clearly indicated to the user. The correct floor map is displayed
//         at each step. The user understands when and where to change floors.

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

const _kRoom110 = Room(id: 'H-110', name: 'H-110', boundary: <Offset>[]);
const _kRoom210 = Room(id: 'H-210', name: 'H-210', boundary: <Offset>[]);

// ── Navigation graphs ─────────────────────────────────────────────────────────
//
// Floor 1 corridor:   H-110 ──(50)── w1 ──(50)── stair_f1
// Floor 2 corridor:   stair_f2 ──(50)── w2 ──(50)── H-210
//
// stair_f1 / stair_f2 are named "Staircase" so:
//   • The step text just before transition reads
//     "Proceed to Staircase on floor 1."
//   • The transition instruction reads
//     "Take the stairs from floor 1 to floor 2."
//     (because _detectConnectorKind sees "stair" inside "Staircase")

final _kNavGraph1 = NavGraph(
  nodes: const [
    NavNode(id: 'H-110',    type: 'room',             x: 0.10, y: 0.50),
    NavNode(id: 'w1',       type: 'hallway_waypoint',  x: 0.40, y: 0.50),
    NavNode(id: 'stair_f1', type: 'stair_landing',     x: 0.70, y: 0.50,
            name: 'Staircase'),
  ],
  edges: const [
    NavEdge(from: 'H-110', to: 'w1',       weight: 50),
    NavEdge(from: 'w1',    to: 'stair_f1', weight: 50),
  ],
);

final _kNavGraph2 = NavGraph(
  nodes: const [
    NavNode(id: 'stair_f2', type: 'stair_landing',     x: 0.30, y: 0.50,
            name: 'Staircase'),
    NavNode(id: 'w2',       type: 'hallway_waypoint',  x: 0.60, y: 0.50),
    NavNode(id: 'H-210',    type: 'room',             x: 0.90, y: 0.50),
  ],
  edges: const [
    NavEdge(from: 'stair_f2', to: 'w2',    weight: 50),
    NavEdge(from: 'w2',       to: 'H-210', weight: 50),
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
      rooms: const [_kRoom210],
      imagePath: 'assets/indoor/H_2.png',
      imageAspectRatio: 1.0,
      navGraph: _kNavGraph2,
    ),
  ],
  verticalLinks: const [
    VerticalLink(
      fromFloor: 1, fromNodeId: 'stair_f1',
      toFloor:   2, toNodeId:   'stair_f2',
      kind: VerticalLinkKind.stairs,
    ),
  ],
);

Future<IndoorMap?> _mockLoader(CampusBuilding _) async => _kIndoorMap;

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Taps a room row in the ListView (scoped away from RouteControls chips).
Future<void> _tapRoom(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ListView),
      matching: find.text(name),
    ).first,
  );
  await pumpFor(tester, const Duration(milliseconds: 300));
}

/// Opens the floor dropdown and taps [floorLabel].
Future<void> _switchFloor(WidgetTester tester, String floorLabel) async {
  await tester.tap(find.byType(DropdownButton<int>));
  await pumpFor(tester, const Duration(milliseconds: 300));
  await tester.tap(find.text(floorLabel).last);
  await pumpFor(tester, const Duration(milliseconds: 300));
}

/// Taps the "Next Step" button once and pumps frames.
Future<void> _nextStep(WidgetTester tester) async {
  await tester.tap(find.text('Next Step'));
  await pumpFor(tester, const Duration(milliseconds: 300));
}

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.5: multi-floor route detected, floor transitions indicated, '
    'correct floor shown at each step',
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
      await pause(1); // observe loaded screen — floor 1

      // ─── Set H-110 (floor 1) as start ────────────────────────────────────────

      expect(find.text('H-110'), findsOneWidget);
      await _tapRoom(tester, 'H-110');
      await pause(1);

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── Switch to floor 2 and set H-210 as destination ──────────────────────

      await _switchFloor(tester, 'Floor 2');
      await pause(1);

      expect(find.text('H-210'), findsOneWidget);
      await _tapRoom(tester, 'H-210');
      await pause(1);

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe multi-floor route

      // ─── AC: System detects start and destination are on different floors ─────

      // A valid cross-floor route must be found and step count shown.
      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'A route must be found between H-110 (floor 1) and H-210 (floor 2)',
      );

      // ─── AC: Route includes stairs — floor-transition direction in list ────────

      // The directions list must contain the staircase transition text.
      expect(
        find.textContaining('Take the stairs from floor 1 to floor 2'),
        findsWidgets,
        reason: 'Directions must include the floor-transition instruction',
      );

      // ─── AC: Correct floor map displayed — starts on floor 1 ─────────────────

      // After routing, _syncUiToActiveSegment sets the display to segment 0's
      // floor (floor 1). The dropdown must show "Floor 1".
      expect(
        find.text('Floor 1'),
        findsOneWidget,
        reason: 'Floor dropdown must show Floor 1 at the start of the route',
      );
      expect(
        find.text('Floor 2'),
        findsNothing,
        reason: 'Floor 2 must NOT be shown as the active floor at route start',
      );
      await pause(1);

      // ─── AC: Initial step text describes navigation on floor 1 ───────────────

      // At node index 0 (H-110), the next node is w1.
      // Step text: "Proceed to w1 on floor 1."
      expect(
        find.textContaining('on floor 1'),
        findsWidgets,
        reason: 'Initial step text must refer to floor 1 navigation',
      );
      await pause(1);

      // ─── AC: User understands when to change floors — tap towards staircase ──

      // Tap 1 — advance to w1. Step text: "Proceed to Staircase on floor 1."
      await _nextStep(tester);
      await pause(1);

      expect(
        find.text('Proceed to Staircase on floor 1.'),
        findsOneWidget,
        reason: 'Step text must instruct the user to proceed to the Staircase',
      );

      // ─── AC: Transition instruction is clearly shown at floor boundary ────────

      // Tap 2 — advance to stair_f1 (end of floor-1 segment).
      // Step text becomes the transition instruction.
      await _nextStep(tester);
      await pause(1);

      expect(
        find.text('Take the stairs from floor 1 to floor 2.'),
        findsOneWidget,
        reason: 'Step text must show the floor-transition instruction at the '
            'staircase node',
      );

      // Dropdown still shows Floor 1 — the physical floor hasn't changed yet.
      expect(
        find.text('Floor 1'),
        findsOneWidget,
        reason: 'Floor 1 is still active while the user is at the staircase',
      );
      await pause(1);

      // ─── AC: Correct floor map displayed — switches to floor 2 after stairs ──

      // Tap 3 — cross the floor boundary.
      // _goToNextStep advances to segment 1; _syncUiToActiveSegment switches
      // _selectedFloorLevel to 2.
      await _nextStep(tester);
      await pause(1);

      expect(
        find.text('Floor 2'),
        findsOneWidget,
        reason: 'Floor dropdown must switch to Floor 2 after advancing past the '
            'staircase',
      );
      expect(
        find.text('Floor 1'),
        findsNothing,
        reason: 'Floor 1 must no longer be shown as active after the floor '
            'transition',
      );

      // ─── AC: Step text describes navigation on floor 2 after transition ───────

      expect(
        find.textContaining('on floor 2'),
        findsWidgets,
        reason: 'Step text must reference floor 2 after the floor transition',
      );
      await pause(1);

      // ─── AC: Route completes on floor 2 — "Arrive at destination." shown ─────

      // Tap 4 and Tap 5 — walk to H-210.
      await _nextStep(tester);
      await _nextStep(tester);
      await pause(1);

      expect(
        find.text('Arrive at destination.'),
        findsOneWidget,
        reason: '"Arrive at destination." must appear at the final step',
      );

      // "Next Step" button must now be disabled (no more steps).
      final nextBtn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Next Step'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        nextBtn.onPressed,
        isNull,
        reason: '"Next Step" button must be disabled after the last step',
      );

      await pause(2); // final visual pause
    },
  );
}
