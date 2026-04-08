// US-5.4: Indoor points of interest are displayed on the indoor map.
//         Different types of points of interest use distinct icons.
//         Points of interest correspond to the selected floor.
//         Points of interest are clearly distinguishable from rooms.
//         The map remains readable when points of interest are shown.
//
// Two POI mechanisms are tested together:
//
//  A) IndoorPoi overlay — user-defined POIs (cafeteria, library …) are rendered
//     as Icon widgets directly on the floor-plan canvas via a Positioned layer.
//
//  B) NavNode type icons — navigation nodes such as elevators and staircases
//     are already present in the room list; they must use distinct leading icons
//     (Icons.elevator / Icons.stairs) instead of the generic meeting-room icon.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/indoor_poi.dart';
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
//
// Floor 1 — one regular room + one elevator node + one staircase node.
// Floor 2 — one regular room only.

const _kRoom110   = Room(id: 'H-110',      name: 'H-110',    boundary: <Offset>[]);
const _kElevator  = Room(id: 'elevator_1', name: 'Elevator', boundary: <Offset>[]);
const _kStairs    = Room(id: 'stairs_1',   name: 'Stairs',   boundary: <Offset>[]);
const _kRoom210   = Room(id: 'H-210',      name: 'H-210',    boundary: <Offset>[]);

// ── NavGraph — floor 1 ────────────────────────────────────────────────────────
//
// Node types drive the leading icon in the room list:
//   'elevator_door'  → Icons.elevator
//   'stair_landing'  → Icons.stairs
//   'room'           → Icons.meeting_room_outlined
//
// No edges needed — routing is not under test here.

final _kNavGraph1 = NavGraph(
  nodes: const [
    NavNode(id: 'H-110',      type: 'room',          x: 0.20, y: 0.50),
    NavNode(id: 'elevator_1', type: 'elevator_door',  x: 0.50, y: 0.50),
    NavNode(id: 'stairs_1',   type: 'stair_landing',  x: 0.80, y: 0.50),
  ],
  edges: const [],
);

// ── IndoorPoi data ────────────────────────────────────────────────────────────
//
// Floor 1: cafeteria (orange restaurant icon).
// Floor 2: library   (purple book icon).
//
// Each type is exclusive to one floor so floor-specificity is unambiguous.

const _kCafeteria = IndoorPoi(
  id:   'poi-cafeteria-1',
  name: 'Cafeteria',
  type: IndoorPoiType.cafeteria,
  x: 0.60,
  y: 0.35,
);

const _kLibrary = IndoorPoi(
  id:   'poi-library-2',
  name: 'Library',
  type: IndoorPoiType.library,
  x: 0.50,
  y: 0.50,
);

// ── Stub map ──────────────────────────────────────────────────────────────────

final _kIndoorMap = IndoorMap(
  building: _kBuilding,
  floors: [
    Floor(
      level: 1,
      label: 'Floor 1',
      rooms: const [_kRoom110, _kElevator, _kStairs],
      imagePath: 'assets/indoor/H_1.png',
      imageAspectRatio: 1.0,
      navGraph: _kNavGraph1,
      pois: const [_kCafeteria],
    ),
    const Floor(
      level: 2,
      label: 'Floor 2',
      rooms: [_kRoom210],
      imagePath: 'assets/indoor/H_2.png',
      imageAspectRatio: 1.0,
      pois: [_kLibrary],
    ),
  ],
);

Future<IndoorMap?> _mockLoader(CampusBuilding _) async => _kIndoorMap;

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.4: POIs shown on map with distinct icons, floor-specific, '
    'distinguishable from rooms, map readable',
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

      // ─── AC: IndoorPoi icons displayed on the indoor map (floor 1) ───────────

      // Cafeteria POI must be visible as an overlay Icon on the floor plan.
      expect(
        find.byIcon(IndoorPoiType.cafeteria.icon),
        findsOneWidget,
        reason: 'Cafeteria icon must appear on the floor-plan canvas for floor 1',
      );
      await pause(1);

      // ─── AC: Different types of POIs use distinct icons ──────────────────────

      // Verify at the model level: each enum value maps to a unique icon.
      final allIcons = IndoorPoiType.values.map((t) => t.icon).toList();
      final uniqueIcons = allIcons.toSet();
      expect(
        uniqueIcons.length,
        equals(allIcons.length),
        reason: 'Every IndoorPoiType must map to a distinct icon',
      );

      // NavNode type icons in the room list must also be distinct from each
      // other and from the regular room icon.
      expect(Icons.elevator == Icons.stairs, isFalse);
      expect(Icons.elevator == Icons.meeting_room_outlined, isFalse);
      expect(Icons.stairs   == Icons.meeting_room_outlined, isFalse);

      // ─── AC: NavNode POIs use distinct icons in the room list ────────────────

      // Elevator entry in the room list must use Icons.elevator.
      final elevatorTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Elevator'),
          matching: find.byType(ListTile),
        ),
      );
      final elevLeading = elevatorTile.leading as Icon;
      expect(
        elevLeading.icon,
        Icons.elevator,
        reason: 'Elevator node must use Icons.elevator in the room list',
      );

      // Stairs entry must use Icons.stairs.
      final stairsTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Stairs'),
          matching: find.byType(ListTile),
        ),
      );
      final stairsLeading = stairsTile.leading as Icon;
      expect(
        stairsLeading.icon,
        Icons.stairs,
        reason: 'Staircase node must use Icons.stairs in the room list',
      );

      // ─── AC: POIs are clearly distinguishable from regular rooms ─────────────

      // Regular room H-110 must use the generic meeting-room icon.
      final roomTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('H-110'),
          matching: find.byType(ListTile),
        ),
      );
      final roomLeading = roomTile.leading as Icon;
      expect(
        roomLeading.icon,
        Icons.meeting_room_outlined,
        reason: 'Regular room must use Icons.meeting_room_outlined',
      );

      // Elevator icon ≠ room icon → elevator is distinguishable.
      expect(
        elevLeading.icon == roomLeading.icon,
        isFalse,
        reason: 'Elevator icon must differ from the regular room icon',
      );
      // Stairs icon ≠ room icon → stairs are distinguishable.
      expect(
        stairsLeading.icon == roomLeading.icon,
        isFalse,
        reason: 'Stairs icon must differ from the regular room icon',
      );
      // Cafeteria POI icon ≠ room list icon → POI overlay is distinguishable.
      expect(
        IndoorPoiType.cafeteria.icon == Icons.meeting_room_outlined,
        isFalse,
        reason: 'Cafeteria POI icon must differ from the regular room icon',
      );
      await pause(1);

      // ─── AC: POIs correspond to the selected floor (floor 1 check) ──────────

      // Library is on floor 2 — must NOT appear while floor 1 is active.
      expect(
        find.byIcon(IndoorPoiType.library.icon),
        findsNothing,
        reason: 'Library icon must NOT appear on floor 1',
      );

      // ─── AC: Map remains readable when POIs are shown ────────────────────────

      // The floor-plan Image must still be present behind the POI layer.
      expect(
        find.byType(Image),
        findsWidgets,
        reason: 'Floor plan image must still be visible when POIs are shown',
      );
      // The room list must still be accessible.
      expect(
        find.text('H-110'),
        findsOneWidget,
        reason: 'Room list must remain readable when POIs are shown',
      );
      // The zoomable canvas must be present.
      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: 'InteractiveViewer must still be rendered when POIs are shown',
      );
      await pause(1);

      // ─── AC: POIs correspond to the selected floor (floor 2 check) ──────────

      // Switch to floor 2.
      await tester.tap(find.byType(DropdownButton<int>));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Floor 2').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe floor 2

      // Library POI must now appear.
      expect(
        find.byIcon(IndoorPoiType.library.icon),
        findsOneWidget,
        reason: 'Library icon must appear after switching to floor 2',
      );

      // Floor 1 POIs must be gone.
      expect(
        find.byIcon(IndoorPoiType.cafeteria.icon),
        findsNothing,
        reason: 'Cafeteria icon must NOT appear on floor 2',
      );

      // Room list and floor plan still readable on floor 2.
      expect(find.text('H-210'), findsOneWidget,
          reason: 'Room list must remain readable on floor 2');
      expect(find.byType(Image), findsWidgets,
          reason: 'Floor plan image must still be visible on floor 2');

      await pause(2); // final visual pause
    },
  );
}
