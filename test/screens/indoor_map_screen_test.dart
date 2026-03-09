import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/screens/indoor_map_screen.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

CampusBuilding _building({String name = 'NOOP', String? fullName}) =>
    CampusBuilding(
      id: 'test',
      name: name,
      campus: Campus.sgw,
      boundary: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)],
      fullName: fullName,
      description: null,
    );

/// Two rooms connected via two waypoints — Dijkstra finds a path between them.
const _singleFloorJson = '''
{
  "imageWidth": 200,
  "imageHeight": 200,
  "nodes": [
    {"id": "r1", "type": "room", "x": 50,  "y": 50,  "label": "H-801", "floor": 8},
    {"id": "r2", "type": "room", "x": 150, "y": 100, "label": "H-802", "floor": 8},
    {"id": "wp1", "type": "hallway_waypoint", "x": 75,  "y": 75, "label": ""},
    {"id": "wp2", "type": "hallway_waypoint", "x": 125, "y": 75, "label": ""}
  ],
  "edges": [{"source": "wp1", "target": "wp2", "weight": 50}]
}
''';

/// Two rooms with no waypoints / edges — Dijkstra returns null for any route.
const _disconnectedJson = '''
{
  "imageWidth": 200,
  "imageHeight": 200,
  "nodes": [
    {"id": "r1", "type": "room", "x": 50,  "y": 50,  "label": "H-801", "floor": 8},
    {"id": "r2", "type": "room", "x": 150, "y": 100, "label": "H-802", "floor": 8}
  ],
  "edges": []
}
''';

/// Two-floor map.
const _multiFloorJson = '''
{
  "floors": [
    {
      "level": 8, "label": "8th Floor",
      "imageWidth": 200, "imageHeight": 200,
      "nodes": [
        {"id": "r1", "type": "room", "x": 50, "y": 50, "label": "H-801"},
        {"id": "wp1", "type": "hallway_waypoint", "x": 100, "y": 75, "label": ""}
      ],
      "edges": []
    },
    {
      "level": 9, "label": "9th Floor",
      "imageWidth": 200, "imageHeight": 200,
      "nodes": [
        {"id": "r2", "type": "room", "x": 50, "y": 50, "label": "H-901"},
        {"id": "wp2", "type": "hallway_waypoint", "x": 100, "y": 75, "label": ""}
      ],
      "edges": []
    }
  ]
}
''';

void _mockAsset(String assetKey, String content) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? msg) async {
    if (msg == null) return null;
    final key = utf8.decode(msg.buffer.asUint8List());
    if (key == assetKey) {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
    }
    return null;
  });
}

void _clearMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}

Widget _wrap(CampusBuilding b) => MaterialApp(home: IndoorMapScreen(building: b));

/// Pushes the screen so that Navigator.pop() can succeed in tests.
Widget _wrapNavigable(CampusBuilding b) => MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
                builder: (_) => IndoorMapScreen(building: b)),
          ),
          child: const Text('Go'),
        ),
      ),
    );

/// Waits for [loadIndoorMapForBuilding] to complete (real async: both the
/// 150 ms delay and the rootBundle.loadString binary-messenger round-trip),
/// then pumps to render the updated widget tree.
///
/// Using [tester.runAsync] avoids the cursor-blink animation infinite-loop
/// that would make [pumpAndSettle] time out on screens that contain a [TextField].
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(); // render with loaded / error state
  await tester.pump(); // drain any remaining microtasks
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  tearDown(_clearMock);

  // ── Loading state ───────────────────────────────────────────────────────────
  group('loading state', () {
    testWidgets('shows CircularProgressIndicator on first frame', (tester) async {
      await tester.pumpWidget(_wrap(_building()));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await _settle(tester); // drain the pending timer
    });

    testWidgets('shows building fullName in AppBar while loading', (tester) async {
      await tester.pumpWidget(
          _wrap(_building(name: 'NOOP', fullName: 'Hall Building')));
      await tester.pump();
      expect(find.text('Hall Building'), findsOneWidget);
      await _settle(tester);
    });
  });

  // ── Error / no-map state ────────────────────────────────────────────────────
  group('error state (unknown building)', () {
    testWidgets('shows error message', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'NOOP')));
      await _settle(tester);
      expect(find.text('No indoor map for this building'), findsOneWidget);
    });

    testWidgets('shows Back button', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'NOOP')));
      await _settle(tester);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('uses building name in AppBar when fullName is null',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'MYBUILDING')));
      await _settle(tester);
      expect(find.text('MYBUILDING'), findsAtLeastNWidgets(1));
    });

    testWidgets('uses fullName in AppBar when provided', (tester) async {
      await tester.pumpWidget(
          _wrap(_building(name: 'NOOP', fullName: 'Hall Building')));
      await _settle(tester);
      expect(find.text('Hall Building'), findsAtLeastNWidgets(1));
    });

    testWidgets('Back button pops the route', (tester) async {
      await tester.pumpWidget(_wrapNavigable(_building(name: 'NOOP')));
      await tester.tap(find.text('Go'));
      await _settle(tester);
      expect(find.text('Back'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Go'), findsOneWidget);
    });
  });

  // ── Loaded state — single floor ────────────────────────────────────────────
  group('loaded state — single floor', () {
    setUp(() => _mockAsset('assets/indoor/H.json', _singleFloorJson));

    testWidgets('shows floor dropdown', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
    });

    testWidgets('shows search TextField', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows rooms in list', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      expect(find.text('H-801'), findsAtLeastNWidgets(1));
      expect(find.text('H-802'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows hint text when no room is selected yet', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      expect(
        find.text('Tap a room on the map or in the list to select it'),
        findsOneWidget,
      );
    });

    testWidgets('entering text in search field filters room list',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '801');
      await tester.pump();
      expect(find.text('H-801'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping a room shows Set Start / Set Dest buttons',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      expect(find.text('Set Start'), findsOneWidget);
      expect(find.text('Set Dest'), findsOneWidget);
    });

    testWidgets('tapping a room from search clears the search controller',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '801');
      await tester.pump();
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text ?? '', isEmpty);
    });

    testWidgets('Set Start marks room with play_circle icon', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      expect(find.byIcon(Icons.play_circle), findsWidgets);
    });

    testWidgets('Set Dest marks room with flag icon', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Dest'));
      await tester.pump();
      expect(find.byIcon(Icons.flag), findsWidgets);
    });

    testWidgets('setting start + destination shows route step count',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
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

    testWidgets('close (clear route) button removes start/dest chips',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      // Close button should be visible once a route item is set
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('long press opens bottom sheet with room actions',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.longPress(find.text('H-801').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // sheet animation
      expect(find.text('Set as Start'), findsOneWidget);
      expect(find.text('Set as Destination'), findsOneWidget);
    });

    testWidgets('Set as Start from bottom sheet sets the start room',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.longPress(find.text('H-801').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Set as Start'));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.play_circle), findsWidgets);
    });

    testWidgets('Set as Destination from bottom sheet sets destination room',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.longPress(find.text('H-801').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Set as Destination'));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.flag), findsWidgets);
    });

    testWidgets('inline icon buttons in trailing row are present when room selected',
        (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      // Trailing row should have both inline icon buttons
      expect(find.byIcon(Icons.play_circle), findsWidgets);
      expect(find.byIcon(Icons.flag), findsWidgets);
    });
  });

  // ── Disconnected graph (no route found) ────────────────────────────────────
  group('loaded state — disconnected graph', () {
    setUp(() => _mockAsset('assets/indoor/H.json', _disconnectedJson));

    testWidgets('shows No route found when path is null', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      // Set start
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      // Set destination
      await tester.tap(find.text('H-802').last);
      await tester.pump();
      await tester.tap(find.text('Set Dest'));
      await tester.pump();
      expect(find.text('No route found'), findsOneWidget);
    });
  });

  // ── Multi-floor map ─────────────────────────────────────────────────────────
  group('loaded state — multi-floor', () {
    setUp(() => _mockAsset('assets/indoor/H.json', _multiFloorJson));

    testWidgets('dropdown shows all floor labels on open', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('8th Floor'), findsAtLeastNWidgets(1));
      expect(find.text('9th Floor'), findsAtLeastNWidgets(1));
    });

    testWidgets('switching floors updates the room list', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      // Floor 8 shown first
      expect(find.text('H-801'), findsAtLeastNWidgets(1));
      // Switch to floor 9
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('9th Floor').last);
      await tester.pump();
      await tester.pump();
      expect(find.text('H-901'), findsAtLeastNWidgets(1));
    });

    testWidgets('switching floors clears any active path', (tester) async {
      await tester.pumpWidget(_wrap(_building(name: 'H')));
      await _settle(tester);
      // Set a start room on floor 8
      await tester.tap(find.text('H-801').last);
      await tester.pump();
      await tester.tap(find.text('Set Start'));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      // Switch floors
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('9th Floor').last);
      await tester.pump();
      await tester.pump();
      // Path cleared — close button gone
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}
