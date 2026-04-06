import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/data/floor_plan_editor_loader.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/room.dart';
import 'package:proj/models/vertical_link.dart';
import 'package:proj/screens/indoor_map_screen.dart';

CampusBuilding _building({String name = 'NOOP', String? fullName}) =>
    CampusBuilding(
      id: 'test',
      name: name,
      campus: Campus.sgw,
      boundary: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)],
      fullName: fullName,
      description: null,
    );

// Two rooms connected via waypoints — path exists.
const _singleFloorJson = '''
{"imageWidth": 200, "imageHeight": 200,
 "nodes": [
   {"id": "r1", "type": "room", "x": 50, "y": 50, "label": "H-801", "floor": 8},
   {"id": "r2", "type": "room", "x": 150, "y": 100, "label": "H-802", "floor": 8},
   {"id": "wp1", "type": "hallway_waypoint", "x": 75, "y": 75, "label": ""},
   {"id": "wp2", "type": "hallway_waypoint", "x": 125, "y": 75, "label": ""}
 ],
 "edges": [{"source": "wp1", "target": "wp2", "weight": 50}]}
''';

// Two rooms, no edges — path is null.
const _disconnectedJson = '''
{"imageWidth": 200, "imageHeight": 200,
 "nodes": [
   {"id": "r1", "type": "room", "x": 50, "y": 50, "label": "H-801", "floor": 8},
   {"id": "r2", "type": "room", "x": 150, "y": 100, "label": "H-802", "floor": 8}
 ],
 "edges": []}
''';

// Two floors.
const _multiFloorJson = '''
{"floors": [
  {"level": 8, "label": "8th Floor", "imageWidth": 200, "imageHeight": 200,
   "nodes": [{"id": "r1", "type": "room", "x": 50, "y": 50, "label": "H-801"}], "edges": []},
  {"level": 9, "label": "9th Floor", "imageWidth": 200, "imageHeight": 200,
   "nodes": [{"id": "r2", "type": "room", "x": 50, "y": 50, "label": "H-901"}], "edges": []}
]}
''';
// Two floors connected by an explicit elevator link for multi-floor route
const _multiFloorRoutableJson = '''
{
  "floors": [
    {
      "level": 1, "label": "Floor 1",
      "imageWidth": 200, "imageHeight": 200,
      "nodes": [
        {"id": "r1",   "type": "room",             "x": 20,  "y": 100, "label": "Room 1"},
        {"id": "elev1","type": "hallway_waypoint",  "x": 100, "y": 100, "label": "elevator"}
      ],
      "edges": [{"source": "r1", "target": "elev1", "weight": 80}]
    },
    {
      "level": 2, "label": "Floor 2",
      "imageWidth": 200, "imageHeight": 200,
      "nodes": [
        {"id": "r2",   "type": "room",             "x": 180, "y": 100, "label": "Room 2"},
        {"id": "elev2","type": "hallway_waypoint",  "x": 100, "y": 100, "label": "elevator"}
      ],
      "edges": [{"source": "r2", "target": "elev2", "weight": 80}]
    }
  ]
}
''';
// A floor whose node id is NOT in its navGraph
const _missingNodeJson = '''
{
  "imageWidth": 200, "imageHeight": 200,
  "nodes": [
    {"id": "r1", "type": "room", "x": 50, "y": 50, "label": "Room 1", "floor": 1},
    {"id": "r2", "type": "room", "x": 150, "y": 50, "label": "Room 2", "floor": 1}
  ],
  "edges": [{"source": "r1", "target": "r2", "weight": 100}]
}
''';

IndoorMap _parseMap(
    CampusBuilding b,
    String rawJson, {
      String? imageAssetPrefix,
    }) {
  final j = jsonDecode(rawJson) as Map<String, dynamic>;
  final floors = FloorPlanEditorLoader.parseMultiFloor(
    j,
    imageAssetPrefix: imageAssetPrefix,
  );
  return IndoorMap(building: b, floors: floors);
}

IndoorMap _multiFloorMap(CampusBuilding b) {
  final j = jsonDecode(_multiFloorRoutableJson) as Map<String, dynamic>;
  final floors = FloorPlanEditorLoader.parseMultiFloor(j);
  return IndoorMap(
    building: b,
    floors: floors,
    verticalLinks: [
      const VerticalLink(
        fromFloor: 1,
        fromNodeId: 'elev1',
        toFloor: 2,
        toNodeId: 'elev2',
        kind: VerticalLinkKind.elevator,
      ),
    ],
  );
}

Widget _wrap(CampusBuilding b,
    {Future<IndoorMap?> Function(CampusBuilding)? mapLoader}) =>
    MaterialApp(
      home: IndoorMapScreen(
        building: b,
        mapLoader: mapLoader ?? (_) async => null,
      ),
    );

Widget _wrapNavigable(
    CampusBuilding b, {
      Future<IndoorMap?> Function(CampusBuilding)? mapLoader,
    }) => MaterialApp(
  home: Builder(
    builder: (ctx) => TextButton(
      onPressed: () => Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => IndoorMapScreen(
            building: b,
            mapLoader: mapLoader ?? (_) async => null,
          ),
        ),
      ),
      child: const Text('Go'),
    ),
  ),
);

Future<void> _selectRoom(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  group('IndoorMapScreen', () {
    testWidgets('loading then error when no map', (tester) async {
      await tester.pumpWidget(_wrap(_building()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await _settle(tester);
      expect(find.text('No indoor map for this building'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('loader exception shows error and Back', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _building(),
          mapLoader: (_) async => throw Exception('load failed'),
        ),
      );
      await _settle(tester);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Back button pops', (tester) async {
      await tester.pumpWidget(_wrapNavigable(_building()));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('shows map, dropdown, search, room list when loaded', (
        tester,
        ) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('H-801'), findsWidgets);
      expect(find.text('H-802'), findsWidgets);
      expect(
        find.text('Tap a room on the map or in the list to select it'),
        findsOneWidget,
      );
    });

    testWidgets('search filters room list', (tester) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '801');
      await tester.pump();
      expect(find.text('H-801'), findsWidgets);
    });

    testWidgets('tap room shows Set Start / Set Dest', (tester) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      expect(find.text('Set Start'), findsOneWidget);
      expect(find.text('Set Dest'), findsOneWidget);
    });

    testWidgets('Set Start then Set Dest shows step count', (tester) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      await tester.tap(find.text('H-802').last);
      await tester.pump();
      await tester.tap(find.text('Set Dest'));
      await tester.pump();
      expect(find.textContaining('steps'), findsOneWidget);
    });

    testWidgets('clear route removes chips and close button', (tester) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('long press opens bottom sheet; Set as Start sets start', (
        tester,
        ) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.longPress(find.text('H-801').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Set as Start'), findsOneWidget);
      expect(find.text('Set as Destination'), findsOneWidget);
      await tester.tap(find.text('Set as Start'));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.play_circle), findsWidgets);
    });

    testWidgets('long press then Set as Destination sets destination', (
        tester,
        ) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.longPress(find.text('H-802').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Set as Destination'));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.flag), findsWidgets);
    });

    testWidgets('disconnected graph shows No route found', (tester) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _disconnectedJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      await tester.tap(find.text('H-802').last);
      await tester.pump();
      await tester.tap(find.text('Set Dest'));
      await tester.pump();
      expect(find.text('No route found'), findsOneWidget);
    });

    testWidgets('floor dropdown changes floor and room list', (tester) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _multiFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      expect(find.text('H-801'), findsWidgets);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('9th Floor').last);
      await tester.pump();
      await tester.pump();
      expect(find.text('H-901'), findsWidgets);
    });

    testWidgets('switching floor updates navGraph and room list', (
        tester,
        ) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _multiFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('9th Floor').last);
      await tester.pump();
      await tester.pump();
      expect(find.text('H-901'), findsWidgets);
    });

    testWidgets('tap room from list clears search (fromSearch path)', (
        tester,
        ) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '801');
      await tester.pump();
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, isEmpty);
    });

    testWidgets('map with imagePath builds image (errorBuilder in test)', (
        tester,
        ) async {
      final b = _building(name: 'H');
      final map = _parseMap(
        b,
        _multiFloorJson,
        imageAssetPrefix: 'assets/indoor/H',
      );
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
      expect(find.text('H-801'), findsWidgets);
    });

    testWidgets('tap on map selects room', (tester) async {
      final b = _building(name: 'H');
      final map = _parseMap(b, _singleFloorJson);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      final mapGesture = find
          .descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(GestureDetector),
      )
          .first;
      await tester.ensureVisible(mapGesture);
      final box = tester.getRect(mapGesture);
      final r1NormX = 50 / 200.0;
      final r1NormY = 50 / 200.0;
      final tapX = box.left + box.width * r1NormX;
      final tapY = box.top + box.height * r1NormY;
      await tester.tapAt(Offset(tapX, tapY));
      await tester.pump();
      expect(find.text('Set Start'), findsOneWidget);
    });

    testWidgets(
      'initialDestinationRoomId selects destination room by full id',
          (WidgetTester tester) async {
        final CampusBuilding b = _building(name: 'H');
        final IndoorMap map = _parseMap(b, _multiFloorJson);

        await tester.pumpWidget(
          MaterialApp(
            home: IndoorMapScreen(
              building: b,
              mapLoader: (_) async => map,
              initialDestinationRoomId: 'H-901',
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('H-901'), findsWidgets);
      },
    );

  });
  group('_onFloorChanged — with active route', () {
    // Sets up a two-floor route then switches floors

    testWidgets('switching to a floor that has a route segment updates _path',
            (tester) async {
          final b = _building();
          final map = _multiFloorMap(b);
          await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
          await _settle(tester);

          // Set Room 1 (floor 1) as start.
          await _selectRoom(tester, 'Room 1');
          await tester.tap(find.text('Set Start'));
          await tester.pump();

          // Switch to floor 2 and set Room 2 as destination.
          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pump();
          await tester.tap(find.text('Floor 2').last);
          await tester.pump();
          await _selectRoom(tester, 'Room 2');
          await tester.tap(find.text('Set Dest'));
          await tester.pump();

          // A route should exist now.
          expect(find.textContaining('steps'), findsOneWidget);

          // Switch back to floor 1
          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pump();
          await tester.tap(find.text('Floor 1').last);
          await tester.pump();
          expect(find.textContaining('steps'), findsOneWidget);
        });

    testWidgets(
        'switching to a floor with no route segment sets _path to null',
            (tester) async {
          final b = _building();
          // Three-floor map: route only spans floors 1–2, floor 3 has no segment.
          const threeFloorJson = '''
{
  "floors": [
    {
      "level": 1, "label": "Floor 1",
      "imageWidth": 200, "imageHeight": 200,
      "nodes": [
        {"id": "r1",   "type": "room",            "x": 20,  "y": 100, "label": "Room 1"},
        {"id": "elev1","type": "hallway_waypoint", "x": 100, "y": 100, "label": "elevator"}
      ],
      "edges": [{"source": "r1", "target": "elev1", "weight": 80}]
    },
    {
      "level": 2, "label": "Floor 2",
      "imageWidth": 200, "imageHeight": 200,
      "nodes": [
        {"id": "r2",   "type": "room",            "x": 180, "y": 100, "label": "Room 2"},
        {"id": "elev2","type": "hallway_waypoint", "x": 100, "y": 100, "label": "elevator"}
      ],
      "edges": [{"source": "r2", "target": "elev2", "weight": 80}]
    },
    {
      "level": 3, "label": "Floor 3",
      "imageWidth": 200, "imageHeight": 200,
      "nodes": [
        {"id": "r3", "type": "room", "x": 100, "y": 100, "label": "Room 3"}
      ],
      "edges": []
    }
  ]
}
''';
          final j = jsonDecode(threeFloorJson) as Map<String, dynamic>;
          final floors = FloorPlanEditorLoader.parseMultiFloor(j);
          final map = IndoorMap(
            building: b,
            floors: floors,
            verticalLinks: [
              const VerticalLink(
                fromFloor: 1,
                fromNodeId: 'elev1',
                toFloor: 2,
                toNodeId: 'elev2',
                kind: VerticalLinkKind.elevator,
              ),
            ],
          );
          await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
          await _settle(tester);

          await _selectRoom(tester, 'Room 1');
          await tester.tap(find.text('Set Start'));
          await tester.pump();

          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pump();
          await tester.tap(find.text('Floor 2').last);
          await tester.pump();
          await _selectRoom(tester, 'Room 2');
          await tester.tap(find.text('Set Dest'));
          await tester.pump();

          // Route spans floors 1 and 2 only. Switch to floor 3 — no segment →
          // _path becomes null, so "No route found" should not appear (the route
          // object still exists) but the step count chip disappears.
          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pump();
          await tester.tap(find.text('Floor 3').last);
          await tester.pump();

          // _path is null on floor 3 so the steps chip is gone.
          expect(find.textContaining('steps'), findsNothing);
        });
  });

  // ── _computePath error branches ───────────────────────────────────────────

  group('_computePath — node missing from navGraph', () {
    // To hit these branches we need a Room whose id exists in the Room list
    // but NOT as a NavNode in the floor's navGraph.  We do this by building
    // an IndoorMap manually with a room that has a different id from the node.

    testWidgets('start room id not in navGraph clears route', (tester) async {
      final b = _building();
      final j = jsonDecode(_missingNodeJson) as Map<String, dynamic>;
      final floors = FloorPlanEditorLoader.parseMultiFloor(j);

      // Replace r1's Room id with something the navGraph does not know about.
      final originalFloor = floors.first;
      final patchedRooms = [
        Room(id: 'ghost_r1', name: 'Ghost Room', boundary: originalFloor.rooms.first.boundary),
        ...originalFloor.rooms.skip(1),
      ];
      final patchedFloor = Floor(
        level: originalFloor.level,
        label: originalFloor.label,
        rooms: patchedRooms,
        navGraph: originalFloor.navGraph,
      );
      final map = IndoorMap(building: b, floors: [patchedFloor]);

      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);

      // Select the ghost room (it appears in the list) and set as start.
      await _selectRoom(tester, 'Ghost Room');
      await tester.tap(find.text('Set Start'));
      await tester.pump();

      // Select r2 as destination — this triggers _computePath where startGraph does not contain 'ghost_r1'
      await _selectRoom(tester, 'Room 2');
      await tester.tap(find.text('Set Dest'));
      await tester.pump();

      // _route and _path are null, so "No route found" is shown.
      expect(find.text('No route found'), findsOneWidget);
    });

    testWidgets('destination room id not in navGraph clears route',
            (tester) async {
          final b = _building();
          final j = jsonDecode(_missingNodeJson) as Map<String, dynamic>;
          final floors = FloorPlanEditorLoader.parseMultiFloor(j);

          final originalFloor = floors.first;
          final patchedRooms = [
            originalFloor.rooms.first,
            Room(id: 'ghost_r2', name: 'Ghost Dest', boundary: originalFloor.rooms.last.boundary),
          ];
          final patchedFloor = Floor(
            level: originalFloor.level,
            label: originalFloor.label,
            rooms: patchedRooms,
            navGraph: originalFloor.navGraph,
          );
          final map = IndoorMap(building: b, floors: [patchedFloor]);

          await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
          await _settle(tester);

          await _selectRoom(tester, 'Room 1');
          await tester.tap(find.text('Set Start'));
          await tester.pump();

          // Set the ghost room as destination → destGraph.nodeById returns null.
          await _selectRoom(tester, 'Ghost Dest');
          await tester.tap(find.text('Set Dest'));
          await tester.pump();

          expect(find.text('No route found'), findsOneWidget);
        });
  });

  // ── _currentStepText branches ─────────────────────────────────────────────

  group('_currentStepText — transition and arrive branches', () {
    testWidgets(
        'at segment end with transitionInstruction shows transition text',
            (tester) async {
          final b = _building();
          final map = _multiFloorMap(b);
          await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
          await _settle(tester);

          await _selectRoom(tester, 'Room 1');
          await tester.tap(find.text('Set Start'));
          await tester.pump();

          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pump();
          await tester.tap(find.text('Floor 2').last);
          await tester.pump();
          await _selectRoom(tester, 'Room 2');
          await tester.tap(find.text('Set Dest'));
          await tester.pump();

          // Advance through all nodes in segment 0 until we reach the transition.
          // Tap "Next Step" repeatedly until the transition instruction appears.
          var found = false;
          for (var i = 0; i < 10; i++) {
            final nextBtn = find.widgetWithText(FilledButton, 'Next Step');
            if (tester.widget<FilledButton>(nextBtn).onPressed == null) break;
            await tester.tap(nextBtn);
            await tester.pump();
            if (find.textContaining('Take the').evaluate().isNotEmpty) {
              found = true;
              break;
            }
          }
          expect(found, isTrue,
              reason: 'Expected transition instruction to appear');
        });

    testWidgets('at last segment end shows "Arrive at destination."',
            (tester) async {
          final b = _building();
          final map = _multiFloorMap(b);
          await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
          await _settle(tester);

          await _selectRoom(tester, 'Room 1');
          await tester.tap(find.text('Set Start'));
          await tester.pump();

          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pump();
          await tester.tap(find.text('Floor 2').last);
          await tester.pump();
          await _selectRoom(tester, 'Room 2');
          await tester.tap(find.text('Set Dest'));
          await tester.pump();

          // Advance until Next Step is disabled (we've arrived).
          for (var i = 0; i < 20; i++) {
            final nextBtn = find.widgetWithText(FilledButton, 'Next Step');
            if (tester.widget<FilledButton>(nextBtn).onPressed == null) break;
            await tester.tap(nextBtn);
            await tester.pump();
          }
          expect(find.text('Arrive at destination.'), findsWidgets);
        });
  });

  // ── _goToNextStep ─────────────────────────────────────────────────────────

  group('_goToNextStep', () {
    testWidgets('Next Step advances node index within a segment', (tester) async {
      final b = _building();
      final map = _multiFloorMap(b);
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);

      await _selectRoom(tester, 'Room 1');
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.tap(find.text('Floor 2').last);
      await tester.pump();
      await _selectRoom(tester, 'Room 2');
      await tester.tap(find.text('Set Dest'));
      await tester.pump();

      await tester.tap(find.text('Next Step'));
      await tester.pump();
      expect(find.text('Next Step'), findsOneWidget);
    });

    testWidgets('Next Step advances to next segment when at segment end',
            (tester) async {
          final b = _building();
          final map = _multiFloorMap(b);
          await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
          await _settle(tester);

          await _selectRoom(tester, 'Room 1');
          await tester.tap(find.text('Set Start'));
          await tester.pump();
          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pump();
          await tester.tap(find.text('Floor 2').last);
          await tester.pump();
          await _selectRoom(tester, 'Room 2');
          await tester.tap(find.text('Set Dest'));
          await tester.pump();

          // Advance until the floor label in the step text changes to floor 2,
          // which means _activeSegmentIndex incremented and _syncUiToActiveSegment ran.
          var onFloor2 = false;
          for (var i = 0; i < 15; i++) {
            final nextBtn = find.widgetWithText(FilledButton, 'Next Step');
            if (tester.widget<FilledButton>(nextBtn).onPressed == null) break;
            await tester.tap(nextBtn);
            await tester.pump();
            if (find.textContaining('floor 2').evaluate().isNotEmpty) {
              onFloor2 = true;
              break;
            }
          }
          expect(onFloor2, isTrue,
              reason: 'Expected step text to reference floor 2 after segment advance');
        });
  });

  // ── _setVerticalPreference ────────────────────────────────────────────────

  group('_setVerticalPreference via ChoiceChip', () {
    Future<void> setupRoute(WidgetTester tester, IndoorMap map) async {
      final b = _building();
      await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
      await _settle(tester);
      await _selectRoom(tester, 'Room 1');
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.tap(find.text('Floor 2').last);
      await tester.pump();
      await _selectRoom(tester, 'Room 2');
      await tester.tap(find.text('Set Dest'));
      await tester.pump();
    }

    testWidgets('tapping Elevator chip sets elevatorOnly preference',
            (tester) async {
          final map = _multiFloorMap(_building());
          await setupRoute(tester, map);

          await tester.tap(find.widgetWithText(ChoiceChip, 'Elevator'));
          await tester.pump();

          final chip = tester.widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Elevator'));
          expect(chip.selected, isTrue);
        });

    testWidgets('tapping Stairs chip sets stairsOnly preference',
            (tester) async {
          final map = _multiFloorMap(_building());
          await setupRoute(tester, map);

          await tester.tap(find.widgetWithText(ChoiceChip, 'Stairs'));
          await tester.pump();

          final chip = tester.widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Stairs'));
          expect(chip.selected, isTrue);
        });

    testWidgets('tapping Any chip after Elevator restores either preference',
            (tester) async {
          final map = _multiFloorMap(_building());
          await setupRoute(tester, map);

          // First switch to Elevator.
          await tester.tap(find.widgetWithText(ChoiceChip, 'Elevator'));
          await tester.pump();
          // Then back to Any.
          await tester.tap(find.widgetWithText(ChoiceChip, 'Any'));
          await tester.pump();

          final chip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Any'));
          expect(chip.selected, isTrue);
        });

    testWidgets(
        'switching to stairsOnly when only elevator available shows No route found',
            (tester) async {
          final map = _multiFloorMap(_building());
          await setupRoute(tester, map);

          expect(find.textContaining('steps'), findsOneWidget);

          await tester.tap(find.widgetWithText(ChoiceChip, 'Stairs'));
          await tester.pump();

          expect(find.text('No route found'), findsOneWidget);
        });
  });
  testWidgets('shows map screen with empty floors list', (tester) async {
    final b = _building(name: 'H');
    final map = IndoorMap(building: b, floors: []);
    await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
    await _settle(tester);
    expect(find.byType(Scaffold), findsOneWidget);
  });
  testWidgets('initialDestinationRoomId with unknown id is silently ignored', (tester) async {
    final b = _building(name: 'H');
    final map = _parseMap(b, _singleFloorJson);
    await tester.pumpWidget(MaterialApp(
      home: IndoorMapScreen(
        building: b,
        mapLoader: (_) async => map,
        initialDestinationRoomId: 'DOES-NOT-EXIST',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('H-801'), findsWidgets);
    expect(find.text('Set Dest'), findsNothing);
  });
  testWidgets('initialDestinationRoomId matches via stripped prefix', (tester) async {
    final b = _building(name: 'H');
    final map = _parseMap(b, _singleFloorJson);
    await tester.pumpWidget(MaterialApp(
      home: IndoorMapScreen(
        building: b,
        mapLoader: (_) async => map,
        initialDestinationRoomId: 'H-r1',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
  });
  testWidgets('inaccessible room shows "Not accessible" subtitle', (tester) async {
    final b = _building(name: 'H');
    final j = jsonDecode(_singleFloorJson) as Map<String, dynamic>;
    final floors = FloorPlanEditorLoader.parseMultiFloor(j);
    final original = floors.first;
    final patchedRooms = [
      Room(
        id: original.rooms.first.id,
        name: original.rooms.first.name,
        boundary: original.rooms.first.boundary,
        accessible: false,
      ),
      ...original.rooms.skip(1),
    ];
    final patchedFloor = Floor(
      level: original.level,
      label: original.label,
      rooms: patchedRooms,
      navGraph: original.navGraph,
    );
    final map = IndoorMap(building: b, floors: [patchedFloor]);
    await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
    await _settle(tester);
    expect(find.text('Not accessible'), findsOneWidget);
  });
  testWidgets('destination room shows blue flag icon in list', (tester) async {
    final b = _building(name: 'H');
    final map = _parseMap(b, _singleFloorJson);
    await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
    await _settle(tester);
    await tester.tap(find.text('H-801').last);
    await tester.pump();
    await tester.tap(find.text('Set Dest'));
    await tester.pump();
    expect(find.byIcon(Icons.flag), findsWidgets);
  });

  testWidgets('selected-only room shows primary color icon', (tester) async {
    final b = _building(name: 'H');
    final map = _parseMap(b, _singleFloorJson);
    await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
    await _settle(tester);
    await tester.tap(find.text('H-801').last);
    await tester.pump();
    expect(find.byIcon(Icons.meeting_room_outlined), findsWidgets);
  });
  testWidgets('route status is empty when only start is set', (tester) async {
    final b = _building(name: 'H');
    final map = _parseMap(b, _singleFloorJson);
    await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
    await _settle(tester);
    await tester.tap(find.text('H-801').last);
    await tester.pump();
    await tester.tap(find.text('Set Start'));
    await tester.pump();
    expect(find.textContaining('steps'), findsNothing);
    expect(find.text('No route found'), findsNothing);
  });
  testWidgets('appBar shows fullName when provided', (tester) async {
    final b = _building(name: 'H', fullName: 'Hall Building');
    final map = _parseMap(b, _singleFloorJson);
    await tester.pumpWidget(_wrap(b, mapLoader: (_) async => map));
    await _settle(tester);
    expect(find.text('Hall Building'), findsOneWidget);
  });
}