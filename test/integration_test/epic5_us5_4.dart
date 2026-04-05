// US-5.4: Indoor points of interest displayed on the indoor map

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/data/data_parser.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/screens/indoor_map_screen.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late CampusBuilding mbBuilding; // MB has Stairs, Elevators, WC on floor 1
  late CampusBuilding lbBuilding; // LB has 4 floors — good for floor-switching tests

  setUpAll(() async {
    final buildings = await DataParser().getBuildingInfoFromJSON();
    mbBuilding = buildings.firstWhere((b) => b.name == 'MB');
    lbBuilding = buildings.firstWhere((b) => b.name == 'LB');
  });

  /// Pumps IndoorMapScreen for [building] and waits for the data to load.
  Future<void> pumpIndoorMap(WidgetTester tester, CampusBuilding building) async {
    await tester.pumpWidget(MaterialApp(home: IndoorMapScreen(building: building)));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await pause(2);
  }

  // ─── AC: Indoor POIs are displayed on the indoor map ─────────────────────────

  testWidgets(
    'US-5.4: elevator POI appears in the indoor room list for MB',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      expect(find.textContaining('Elevator'), findsWidgets,
          reason: 'At least one Elevator POI must be visible in the indoor map list');
      await pause(2);
    },
  );

  testWidgets(
    'US-5.4: staircase POI appears in the indoor room list for MB',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      expect(find.textContaining('Stairs'), findsWidgets,
          reason: 'At least one Staircase POI must be visible in the indoor map list');
      await pause(2);
    },
  );

  testWidgets(
    'US-5.4: washroom POI appears in the indoor room list for MB',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      // "WC" is the label used in the floor data
      expect(find.textContaining('WC'), findsWidgets,
          reason: 'At least one washroom (WC) POI must be visible in the indoor map list');
      await pause(2);
    },
  );

  // ─── AC: Different POI types use distinct icons ───────────────────────────────

  testWidgets(
    'US-5.4: elevator POI uses a distinct icon (not the generic meeting-room icon)',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      // Find the ListTile for any Elevator entry
      final elevatorTile = find.ancestor(
        of: find.textContaining('Elevator'),
        matching: find.byType(ListTile),
      ).first;

      // The leading icon must NOT be the generic room icon
      expect(
        find.descendant(
          of: elevatorTile,
          matching: find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.meeting_room_outlined,
          ),
        ),
        findsNothing,
        reason: 'Elevator POI must not use the generic meeting-room icon',
      );

      // And a dedicated elevator icon must be present somewhere in the tile
      expect(
        find.descendant(
          of: elevatorTile,
          matching: find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.elevator,
          ),
        ),
        findsOneWidget,
        reason: 'Elevator POI must use Icons.elevator',
      );
      await pause(2);
    },
  );

  testWidgets(
    'US-5.4: staircase POI uses a distinct icon (not the generic meeting-room icon)',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      final stairsTile = find.ancestor(
        of: find.textContaining('Stairs'),
        matching: find.byType(ListTile),
      ).first;

      expect(
        find.descendant(
          of: stairsTile,
          matching: find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.meeting_room_outlined,
          ),
        ),
        findsNothing,
        reason: 'Staircase POI must not use the generic meeting-room icon',
      );

      expect(
        find.descendant(
          of: stairsTile,
          matching: find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.stairs,
          ),
        ),
        findsOneWidget,
        reason: 'Staircase POI must use Icons.stairs',
      );
      await pause(2);
    },
  );

  testWidgets(
    'US-5.4: washroom POI uses a distinct icon (not the generic meeting-room icon)',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      final wcTile = find.ancestor(
        of: find.text('WC'),
        matching: find.byType(ListTile),
      ).first;

      expect(
        find.descendant(
          of: wcTile,
          matching: find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.meeting_room_outlined,
          ),
        ),
        findsNothing,
        reason: 'Washroom POI must not use the generic meeting-room icon',
      );

      expect(
        find.descendant(
          of: wcTile,
          matching: find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.wc,
          ),
        ),
        findsOneWidget,
        reason: 'Washroom POI must use Icons.wc',
      );
      await pause(2);
    },
  );

  // ─── AC: POIs correspond to the selected floor ───────────────────────────────

  testWidgets(
    'US-5.4: switching floors updates the displayed room and POI list',
    (tester) async {
      await pumpIndoorMap(tester, lbBuilding); // LB has 4 distinct floors

      // Count rooms on the first loaded floor
      final firstFloorCount = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .length;

      // Open the floor selector and pick a different floor
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await pause(1); // observe dropdown open

      // Select the second floor option (skip the first which is already active)
      final dropdownItems = find.byType(DropdownMenuItem<int>);
      expect(dropdownItems, findsWidgets,
          reason: 'Floor dropdown must list multiple floors for LB');

      // Tap the second available floor item
      await tester.tap(dropdownItems.at(1));
      await tester.pumpAndSettle();
      await pause(2); // observe floor change

      final secondFloorCount = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .length;

      expect(secondFloorCount, isNot(equals(firstFloorCount)),
          reason: 'Switching floors must update the room/POI list — '
              'different floors have different room counts');
      await pause(2);
    },
  );

  testWidgets(
    'US-5.4: indoor map screen shows a floor selector with multiple floors for LB',
    (tester) async {
      await pumpIndoorMap(tester, lbBuilding);

      expect(find.byType(DropdownButton<int>), findsOneWidget,
          reason: 'A floor selector must be visible');

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownMenuItem<int>), findsWidgets,
          reason: 'Floor dropdown must show multiple floors');
      await pause(2);
    },
  );

  // ─── AC: POIs are clearly distinguishable from regular rooms ─────────────────

  testWidgets(
    'US-5.4: regular numbered rooms and elevator POIs use different leading icons',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      // A plain numbered room like "1.1.01" should have meeting_room icon
      final numberedRoomTile = find.ancestor(
        of: find.text('1.1.01'),
        matching: find.byType(ListTile),
      );
      expect(numberedRoomTile, findsOneWidget,
          reason: 'A numbered room must be present in the MB floor 1 list');

      final roomHasGenericIcon = find.descendant(
        of: numberedRoomTile,
        matching: find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.meeting_room_outlined,
        ),
      ).evaluate().isNotEmpty;

      final elevatorTile = find.ancestor(
        of: find.textContaining('Elevator').first,
        matching: find.byType(ListTile),
      );

      final elevatorHasGenericIcon = find.descendant(
        of: elevatorTile,
        matching: find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.meeting_room_outlined,
        ),
      ).evaluate().isNotEmpty;

      expect(roomHasGenericIcon, isTrue,
          reason: 'Regular numbered rooms must use the generic meeting-room icon');
      expect(elevatorHasGenericIcon, isFalse,
          reason: 'Elevator POI must NOT use the generic meeting-room icon — '
              'it must be distinguishable');
      await pause(2);
    },
  );

  // ─── AC: Map remains readable when POIs are shown ────────────────────────────

  testWidgets(
    'US-5.4: indoor map screen renders without error when POIs are present',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      // The screen must not be in a loading or error state
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'Indoor map must have finished loading');
      expect(find.text('No indoor map available'), findsNothing);
      expect(find.text('No indoor map for this building'), findsNothing);

      // The floor plan canvas and room list must both be present
      expect(find.byType(InteractiveViewer), findsOneWidget,
          reason: 'The zoomable floor plan canvas must be rendered');
      expect(find.byType(ListView), findsOneWidget,
          reason: 'The room/POI list must be rendered alongside the map');
      await pause(2);
    },
  );

  testWidgets(
    'US-5.4: indoor map floor plan image and room list are both visible for MB',
    (tester) async {
      await pumpIndoorMap(tester, mbBuilding);

      // CustomPaint is the overlay painter on top of the floor plan
      expect(find.byType(CustomPaint), findsWidgets,
          reason: 'The floor plan overlay (room/POI indicators) must be rendered');

      // Room list must contain at least the known POIs
      expect(find.byType(ListTile), findsWidgets,
          reason: 'Room/POI list tiles must be visible');
      await pause(2);
    },
  );
}