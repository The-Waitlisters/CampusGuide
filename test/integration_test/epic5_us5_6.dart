// US-5.6: The system supports indoor directions between different buildings.
//         Indoor and outdoor navigation segments are seamlessly connected.
//         Routes between SGW and Loyola are supported.
//         Transitions between buildings are clearly indicated.
//         The full route is understandable and continuous.
//
// Uses real JSON assets (H.json → Hall, LB.json → J.W. McConnell Library).
// Both buildings are on the SGW campus and have complete navGraph data.
//
// Key room IDs (from H.json / LB.json):
//   Hall floor 1 — 'Hall_F1_room_71' (label H-110)
//   LB   floor 2 — '204'             (label 204)
//
// MultiBuildingRouteScreen phases:
//   indoorStart → navigate H-110 to Hall exit
//   outdoor     → walk from Hall to LB
//   indoorEnd   → navigate from LB entrance to room 204
//
// No mocks. Both IndoorMaps are loaded via loadIndoorMapForBuilding() so the
// same production routing code that a real user sees drives the test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/data/indoor_map_data.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/screens/multi_building_route_screen.dart';

import 'helpers.dart';

// ── Real buildings ─────────────────────────────────────────────────────────────

final _kHBuilding = CampusBuilding(
  id: 'hall-building',
  name: 'H',
  fullName: 'Henry F. Hall Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

final _kLBBuilding = CampusBuilding(
  id: 'lb-building',
  name: 'LB',
  fullName: 'J.W. McConnell Library Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.6: multi-building route — Hall (H-110) → LB (room 204), '
    'three-phase bar, indoor/outdoor segments connected, '
    'transitions clearly indicated, route continuous',
    (tester) async {
      // ── Load real indoor maps from JSON assets ─────────────────────────────
      // loadIndoorMapForBuilding reads H.json and LB.json from the asset bundle
      // and builds full IndoorMap objects (rooms, navGraphs, verticalLinks).

      final hMap  = await loadIndoorMapForBuilding(_kHBuilding);
      final lbMap = await loadIndoorMapForBuilding(_kLBBuilding);

      expect(hMap,  isNotNull, reason: 'H.json must load');
      expect(lbMap, isNotNull, reason: 'LB.json must load');

      await pause(1); // maps loaded — observe before pumping UI

      // ── Pump the screen with real maps and real room IDs ──────────────────
      // startRoomId: 'Hall_F1_room_71' is H-110 on floor 1 of Hall.
      // endRoomId:   '204' is room 204 on floor 2 of the Library building.

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBuildingRouteScreen(
            startBuilding: _kHBuilding,
            endBuilding:   _kLBBuilding,
            startRoomId:   'Hall_F1_room_71', // H-110
            endRoomId:     '204',             // LB floor 2
            startIndoorMap: hMap!,
            endIndoorMap:   lbMap!,
            transportModeLabel: 'Walk',
            outdoorDuration: '~5 min walk',
            outdoorDistance: '350 m',
          ),
        ),
      );

      // Wait for _computeRoutes() to finish and _loading to become false.
      // _computeRoutes() is in-memory pathfinding (no network), but setState
      // is async so we pump until the loading indicator disappears.
      await pumpFor(tester, const Duration(seconds: 3));
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Loading indicator must be gone before assertions start',
      );
      await pause(1); // observe phase 1 (indoor start)

      // ─── AC: Full route is understandable — three-phase bar visible ────────

      expect(find.text('H'),    findsOneWidget,
          reason: 'Phase bar must show start-building chip "H"');
      expect(find.text('Walk'), findsOneWidget,
          reason: 'Phase bar must show transport-mode chip "Walk"');
      expect(find.text('LB'),   findsOneWidget,
          reason: 'Phase bar must show end-building chip "LB"');

      // Arrows between the three chips.
      expect(find.byIcon(Icons.chevron_right), findsWidgets,
          reason: 'Phase bar must show chevron arrows between chips');

      // ─── AC: Indoor phase 1 — navigate to Hall exit ────────────────────────

      // Phase title identifies the start building and instructs the user to
      // head to the exit.
      expect(
        find.textContaining('Navigate to exit'),
        findsOneWidget,
        reason: 'Phase 1 title must say "Navigate to exit"',
      );
      expect(
        find.textContaining('Henry F. Hall Building'),
        findsOneWidget,
        reason: 'Phase 1 must reference the start building by full name',
      );

      // A floor-plan canvas is shown so the user can see the route.
      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: 'Phase 1 must display a floor-plan canvas',
      );

      // ─── AC: Transition out of start building clearly indicated ─────────────

      expect(
        find.textContaining("I've exited"),
        findsOneWidget,
        reason: 'Phase 1 continue button must say "I\'ve exited …"',
      );
      await pause(1);

      // ─── AC: Outdoor segment shown — walk within SGW campus ─────────────────

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe outdoor phase

      // Phase title describes the walk to the destination building.
      expect(
        find.textContaining('Walk to'),
        findsOneWidget,
        reason: 'Outdoor phase title must describe the walk to the LB',
      );

      // Same-campus route: walking icon (not transit).
      // Two instances: phase-bar chip icon + large outdoor-phase body icon.
      expect(
        find.byIcon(Icons.directions_walk),
        findsWidgets,
        reason: 'Same-campus route must show the walking icon',
      );

      // Pre-computed duration and distance are displayed.
      expect(
        find.textContaining('~5 min walk'),
        findsOneWidget,
        reason: 'Outdoor duration must be shown in the outdoor phase',
      );
      expect(
        find.textContaining('350 m'),
        findsOneWidget,
        reason: 'Outdoor distance must be shown in the outdoor phase',
      );

      // ─── AC: Transition into destination building clearly indicated ──────────

      expect(
        find.textContaining("I've arrived at"),
        findsOneWidget,
        reason: 'Outdoor continue button must confirm arrival at LB',
      );
      await pause(1);

      // ─── AC: Indoor phase 3 — navigate inside LB to room 204 ───────────────

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe indoor end phase

      // Phase title directs the user inside the destination building.
      expect(
        find.textContaining('Navigate inside'),
        findsOneWidget,
        reason: 'Phase 3 title must say "Navigate inside"',
      );

      // Floor-plan canvas for LB must be shown.
      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: 'Phase 3 must display a floor-plan canvas for LB',
      );

      // ─── AC: Indoor and outdoor segments seamlessly connected ─────────────
      // Completed phases (H indoor, outdoor) show check-circle icons.

      expect(
        find.byIcon(Icons.check_circle),
        findsWidgets,
        reason: 'Completed phases must show check-circle icons in the phase bar',
      );

      // ─── AC: Full route continuous — done button ends navigation ────────────

      expect(
        find.textContaining('Done'),
        findsOneWidget,
        reason: 'Phase 3 final button must say "Done — arrived at destination"',
      );

      await pause(2); // final visual pause
    },
  );
}
