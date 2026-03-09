import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/data/floor_plan_editor_loader.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/indoor_map.dart';
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

IndoorMap _parseMap(CampusBuilding b, String rawJson) {
  final j = jsonDecode(rawJson) as Map<String, dynamic>;
  final floors = FloorPlanEditorLoader.parseMultiFloor(j);
  return IndoorMap(building: b, floors: floors);
}

Widget _wrap(CampusBuilding b,
        {Future<IndoorMap?> Function(CampusBuilding)? mapLoader}) =>
    MaterialApp(
      home: IndoorMapScreen(
        building: b,
        mapLoader: mapLoader ?? (_) async => null,
      ),
    );

Widget _wrapNavigable(CampusBuilding b,
        {Future<IndoorMap?> Function(CampusBuilding)? mapLoader}) =>
    MaterialApp(
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
      await tester.pumpWidget(_wrap(
        _building(),
        mapLoader: (_) async => throw Exception('load failed'),
      ));
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

    testWidgets('shows map, dropdown, search, room list when loaded',
        (tester) async {
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

    testWidgets('long press opens bottom sheet; Set as Start sets start',
        (tester) async {
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

    testWidgets('long press then Set as Destination sets destination',
        (tester) async {
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

    testWidgets('switching floor updates navGraph and room list', (tester) async {
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

    testWidgets('tap room from list clears search (fromSearch path)',
        (tester) async {
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
  });
}
