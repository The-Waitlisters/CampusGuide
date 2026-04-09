// US-5.1: User can view the indoor map of a selected building, switch floors,
//         see rooms clearly, select rooms by tap or search, mark start /
//         destination, and the UI clearly indicates the selection state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/screens/indoor_map_screen.dart';

import 'helpers.dart';

// ── Real Hall building ─────────────────────────────────────────────────────────
// Uses the real H.json so production room positions drive the test.
// H-110 is at normalised position (0.262, 0.636) on floor 1.
// H-120 is at normalised position (0.424, 0.442) on floor 1.

final _kBuilding = CampusBuilding(
  id: 'hall-building',
  name: 'H',
  fullName: 'Henry F. Hall Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

// Normalised map positions derived from H.json (imageWidth=2000, imageHeight=2000).
const _kH110 = (nx: 0.262, ny: 0.636);
const _kH120 = (nx: 0.424, ny: 0.442);

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.1: indoor map — view, floor switch, map-tap-select, search-select, '
    'start / destination marking, selection indicator',
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

      // ─── AC: building name is shown in the AppBar ────────────────────────────

      expect(find.text('Henry F. Hall Building'), findsOneWidget,
          reason: 'AppBar must show the building name');
      await pause(1);

      // ─── AC: no room selected yet — hint text shown ──────────────────────────

      expect(
        find.text('Tap a room on the map or in the list to select it'),
        findsOneWidget,
        reason: 'Hint must be shown when nothing is selected',
      );
      await pause(1);

      // ─── AC: switch to floor 2 via dropdown ─────────────────────────────────

      await tester.tap(find.byType(DropdownButton<int>));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      await tester.tap(find.text('Floor 2').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe floor 2

      // Switch back to floor 1 for the rest of the test.
      await tester.tap(find.byType(DropdownButton<int>));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Floor 1').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: select H-110 by tapping its position on the map ────────────────
      // Find the InteractiveViewer (the floor-plan canvas) and tap at the
      // normalised position of H-110.

      final mapRect = tester.getRect(find.byType(InteractiveViewer).first);
      await tester.tapAt(Offset(
        mapRect.left + _kH110.nx * mapRect.width,
        mapRect.top  + _kH110.ny * mapRect.height,
      ));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe selection

      expect(find.textContaining('Selected: H-110'), findsOneWidget,
          reason: 'RouteControls must show "Selected: H-110" after map tap');

      // ─── AC: Set H-110 as the start room ────────────────────────────────────

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe start chip

      // A green start chip must appear in RouteControls.
      expect(
        tester
            .widgetList<Icon>(find.byIcon(Icons.play_circle))
            .any((i) => i.color == Colors.green),
        isTrue,
        reason: 'A green play_circle icon must appear when a start room is set',
      );
      await pause(1);

      // Confirm H-110 is marked as start in the list by filtering to it.
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'H-110');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(1);

      final h110InList = find.descendant(
        of: find.byType(ListView),
        matching: find.text('H-110'),
      );
      expect(h110InList, findsOneWidget,
          reason: 'H-110 must appear in the filtered list');
      final startListTile = tester.widget<ListTile>(
        find.ancestor(of: h110InList, matching: find.byType(ListTile)),
      );
      final startLeading = startListTile.leading as Icon;
      expect(startLeading.icon, Icons.play_circle,
          reason: 'H-110 leading must be play_circle when it is the start');
      expect(startLeading.color, Colors.green,
          reason: 'H-110 start icon must be green');

      // Clear search.
      await tester.enterText(searchField, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: select H-120 by typing in the search field ─────────────────────

      await tester.enterText(searchField, 'H-120');
      // Dismiss the keyboard so it does not cover the room list.
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(1); // observe filtered results

      // H-120 must appear in the filtered list.
      final h120InSearch = find.descendant(
        of: find.byType(ListView),
        matching: find.text('H-120'),
      );
      expect(h120InSearch, findsOneWidget,
          reason: 'H-120 must appear when searching "H-120"');

      // Tap H-120 in the list — search clears automatically.
      await tester.tap(h120InSearch);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe selection

      expect(find.textContaining('Selected: H-120'), findsOneWidget,
          reason: 'RouteControls must show "Selected: H-120" after search-select');

      // Search field must be cleared after selection.
      final textField = tester.widget<TextField>(searchField);
      expect(textField.controller?.text ?? '', isEmpty,
          reason: 'Search field must be cleared after selecting a room');
      await pause(1);

      // ─── AC: Set H-120 as the destination room ───────────────────────────────

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe destination chip

      // Search for H-120 to verify its icon in the list.
      await tester.enterText(searchField, 'H-120');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(1);

      final h120InList = find.descendant(
        of: find.byType(ListView),
        matching: find.text('H-120'),
      );
      expect(h120InList, findsOneWidget);
      final destListTile = tester.widget<ListTile>(
        find.ancestor(of: h120InList, matching: find.byType(ListTile)),
      );
      final destLeading = destListTile.leading as Icon;
      expect(destLeading.icon, Icons.flag,
          reason: 'H-120 leading must be flag when it is the destination');
      expect(destLeading.color, Colors.blue,
          reason: 'H-120 destination icon must be blue');

      await tester.enterText(searchField, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: UI shows both start and destination chips ───────────────────────

      expect(find.byIcon(Icons.play_circle), findsWidgets,
          reason: 'Start chip must be visible');
      expect(find.byIcon(Icons.flag), findsWidgets,
          reason: 'Destination chip must be visible');
      expect(find.byIcon(Icons.arrow_forward), findsWidgets,
          reason: 'Arrow between start and destination must be visible');
      await pause(2); // final visual pause
    },
  );
}
