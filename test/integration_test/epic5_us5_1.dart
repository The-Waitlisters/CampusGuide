// US-5.1: User can view the indoor map of a selected building, switch floors,
//         see rooms clearly, select rooms by tap or search, mark start /
//         destination, and the UI clearly indicates the selection state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
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

// ── Stub rooms ────────────────────────────────────────────────────────────────

const _kRoom110 = Room(
  id: 'H-110',
  name: 'H-110',
  boundary: [
    Offset(0.1, 0.1),
    Offset(0.2, 0.1),
    Offset(0.2, 0.2),
    Offset(0.1, 0.2),
  ],
);

const _kRoom120 = Room(
  id: 'H-120',
  name: 'H-120',
  boundary: [
    Offset(0.3, 0.1),
    Offset(0.4, 0.1),
    Offset(0.4, 0.2),
    Offset(0.3, 0.2),
  ],
);

const _kRoom210 = Room(
  id: 'H-210',
  name: 'H-210',
  boundary: [
    Offset(0.1, 0.1),
    Offset(0.2, 0.1),
    Offset(0.2, 0.2),
    Offset(0.1, 0.2),
  ],
);

const _kRoom220 = Room(
  id: 'H-220',
  name: 'H-220',
  boundary: [
    Offset(0.3, 0.1),
    Offset(0.4, 0.1),
    Offset(0.4, 0.2),
    Offset(0.3, 0.2),
  ],
);

// ── Stub map ──────────────────────────────────────────────────────────────────

final _kIndoorMap = IndoorMap(
  building: _kBuilding,
  floors: [
    const Floor(
      level: 1,
      label: 'Floor 1',
      rooms: [_kRoom110, _kRoom120],
      imagePath: 'assets/indoor/H_1.png',
      imageAspectRatio: 1.0,
    ),
    const Floor(
      level: 2,
      label: 'Floor 2',
      rooms: [_kRoom210, _kRoom220],
      imagePath: 'assets/indoor/H_2.png',
      imageAspectRatio: 1.0,
    ),
  ],
);

Future<IndoorMap?> _mockLoader(CampusBuilding _) async => _kIndoorMap;

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.1: indoor map — view, floor switch, tap-select, search-select, '
    'start / destination marking, selection indicator',
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

      // Let the mock loader resolve and the widget rebuild.
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(1); // observe the loaded screen

      // ─── AC: building name is shown in the AppBar ────────────────────────────

      expect(find.text('Henry F. Hall Building'), findsOneWidget,
          reason: 'AppBar must show the building name');
      await pause(1);

      // ─── AC: rooms from floor 1 are displayed in the list ───────────────────

      expect(find.text('H-110'), findsOneWidget,
          reason: 'H-110 must be listed on floor 1');
      expect(find.text('H-120'), findsOneWidget,
          reason: 'H-120 must be listed on floor 1');
      await pause(1);

      // ─── AC: no room selected yet — hint text shown ──────────────────────────

      expect(
        find.text('Tap a room on the map or in the list to select it'),
        findsOneWidget,
        reason: 'Hint must be shown when nothing is selected',
      );

      // No green start or blue destination icons in the list yet.
      final greenPlayInitial = tester
          .widgetList<Icon>(find.byIcon(Icons.play_circle))
          .where((i) => i.color == Colors.green)
          .toList();
      expect(greenPlayInitial, isEmpty,
          reason: 'No start room should be set initially');

      final blueFlag = tester
          .widgetList<Icon>(find.byIcon(Icons.flag))
          .where((i) => i.color == Colors.blue)
          .toList();
      expect(blueFlag, isEmpty,
          reason: 'No destination should be set initially');
      await pause(1);

      // ─── AC: switch to floor 2 via dropdown ─────────────────────────────────

      await tester.tap(find.byType(DropdownButton<int>));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe the open dropdown

      // The menu renders duplicate items (one in appbar, one in menu); use .last.
      await tester.tap(find.text('Floor 2').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe floor 2

      expect(find.text('H-210'), findsOneWidget,
          reason: 'H-210 must appear after switching to floor 2');
      expect(find.text('H-220'), findsOneWidget,
          reason: 'H-220 must appear after switching to floor 2');

      // Floor 1 rooms should no longer be visible.
      expect(find.text('H-110'), findsNothing,
          reason: 'H-110 should not be listed on floor 2');
      await pause(1);

      // ─── AC: switch back to floor 1 ─────────────────────────────────────────

      await tester.tap(find.byType(DropdownButton<int>));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Floor 1').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: select a room by tapping its row in the list ───────────────────

      await tester.tap(find.text('H-110'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe selection

      // RouteControls must show "Selected: H-110".
      expect(find.textContaining('Selected: H-110'), findsOneWidget,
          reason: '"Selected: H-110" must appear in RouteControls');

      // The ListTile for H-110 must be visually selected (bold / highlighted).
      // Scope to the ListView to avoid matching any chip text in RouteControls.
      final h110InList = find.descendant(
        of: find.byType(ListView),
        matching: find.text('H-110'),
      );
      final selectedTile = find.ancestor(
        of: h110InList,
        matching: find.byType(ListTile),
      );
      expect(selectedTile, findsOneWidget);
      final listTile = tester.widget<ListTile>(selectedTile);
      expect(listTile.selected, isTrue,
          reason: 'ListTile.selected must be true for the selected room');
      await pause(1);

      // ─── AC: Set H-110 as the start room ────────────────────────────────────

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe start chip

      // The leading icon for H-110 must now be a green play_circle.
      // Scope to ListView so we don't accidentally find a chip in RouteControls.
      final h110InListAfterStart = find.descendant(
        of: find.byType(ListView),
        matching: find.text('H-110'),
      );
      final startListTile = tester.widget<ListTile>(
        find.ancestor(of: h110InListAfterStart, matching: find.byType(ListTile)),
      );
      final startLeading = startListTile.leading as Icon;
      expect(startLeading.icon, Icons.play_circle,
          reason: 'H-110 leading must be play_circle when it is the start room');
      expect(startLeading.color, Colors.green,
          reason: 'H-110 start icon must be green');

      // A green chip for the start room must appear in RouteControls.
      expect(find.byIcon(Icons.play_circle), findsWidgets);
      await pause(1);

      // ─── AC: select a room by typing in the search field ────────────────────

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'H-12');
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe filtered results

      // Only H-120 should match "H-12" on floor 1; H-110 should be hidden from
      // the room list. Scope to ListView to ignore any RouteControls chip text.
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('H-120')),
        findsOneWidget,
        reason: 'H-120 must appear in search results for "H-12"',
      );
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('H-110')),
        findsNothing,
        reason: 'H-110 must be filtered out of the room list when query is "H-12"',
      );
      await pause(1);

      // Tap H-120 in the filtered list — search field clears automatically.
      await tester.tap(find.text('H-120'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe new selection

      expect(find.textContaining('Selected: H-120'), findsOneWidget,
          reason: '"Selected: H-120" must appear after tapping from search');

      // Search field should be cleared.
      final textField = tester.widget<TextField>(searchField);
      expect(textField.controller?.text ?? '', isEmpty,
          reason: 'Search field must be cleared after selecting a room');

      // Both H-110 and H-120 are now visible in the room list again.
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('H-110')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('H-120')),
        findsOneWidget,
      );
      await pause(1);

      // ─── AC: Set H-120 as the destination room ───────────────────────────────

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe destination chip

      // H-120 leading must now be a blue flag.
      final h120InList = find.descendant(
        of: find.byType(ListView),
        matching: find.text('H-120'),
      );
      final destListTile = tester.widget<ListTile>(
        find.ancestor(of: h120InList, matching: find.byType(ListTile)),
      );
      final destLeading = destListTile.leading as Icon;
      expect(destLeading.icon, Icons.flag,
          reason: 'H-120 leading must be flag when it is the destination room');
      expect(destLeading.color, Colors.blue,
          reason: 'H-120 destination icon must be blue');
      await pause(1);

      // ─── AC: UI shows both start and destination chips ───────────────────────

      expect(find.byIcon(Icons.play_circle), findsWidgets,
          reason: 'Start chip must still be visible');
      expect(find.byIcon(Icons.flag), findsWidgets,
          reason: 'Destination chip must be visible');
      expect(find.byIcon(Icons.arrow_forward), findsWidgets,
          reason: 'Arrow between start and destination must be visible');
      await pause(1);

      // ─── AC: H-110 still marked as start on floor 1 ─────────────────────────

      final h110InListFinal = find.descendant(
        of: find.byType(ListView),
        matching: find.text('H-110'),
      );
      final startTileAfter = tester.widget<ListTile>(
        find.ancestor(of: h110InListFinal, matching: find.byType(ListTile)),
      );
      final startLeadingAfter = startTileAfter.leading as Icon;
      expect(startLeadingAfter.icon, Icons.play_circle,
          reason: 'H-110 must still be marked as start');
      await pause(2); // final visual pause
    },
  );
}
