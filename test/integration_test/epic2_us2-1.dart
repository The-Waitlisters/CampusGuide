// US-2.1: Be able to select a start and destination building
//         (either by clicking on the building or by typing its name)
//
// Completed sub-tasks covered:
//   TASK-2.1.1 — set selected building as start/destination
//   TASK-2.1.2 — building name input field for start/destination (search)
//   TASK-2.1.3 — cancel/close the UI for directions
//   TASK-2.1.4 — exit building selection without choosing start or destination
//
// NOT covered (TASK-2.1.5 still open):
//   "Enable use of current building position as Start location"
//   → requires simulateGpsLocation + UI hook to set GPS building as start.
//     Add a test here once TASK-2.1.5 is merged.
//
// Test strategy:
//   - Pump HomeScreen with testMapControllerCompleter (no GoogleMap crash).
//   - Use simulateBuildingTap() to trigger the building info modal (same path
//     as tapping a search result), which renders the Set as Start /
//     Set as Destination buttons.
//   - Use the search overlay to cover the "type building name" AC.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/data/data_parser.dart';



void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late List buildings;

  setUpAll(() async {
    buildings = await DataParser().getBuildingInfoFromJSON();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  // ─── AC: User can select a building on the map to be the "start" building ───

  testWidgets(
    'US-2.1: tapping a building shows a "Set as Start" button',
        (tester) async {
      await pumpApp(tester);
      final building = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateBuildingTap(building);
      await tester.pumpAndSettle();

      expect(find.text('Set as Start'), findsOneWidget,
          reason: 'Tapping a building must offer "Set as Start"');
    },
  );

  testWidgets(
    'US-2.1: pressing "Set as Start" makes that building the start in the DirectionsCard',
        (tester) async {
      await pumpApp(tester);
      final building = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateBuildingTap(building);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();

      final label = building.fullName ?? building.name;
      expect(find.textContaining('Start: $label'), findsOneWidget,
          reason: 'DirectionsCard must show the selected start building');
    },
  );

  // ─── AC: Once a start is selected, user can select a destination building ───

  testWidgets(
    'US-2.1: after setting start, tapping another building shows "Set as Destination"',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
      final start = sgwBuildings[0];
      final dest  = sgwBuildings[1];

      final dynamic state = tester.state(find.byType(HomeScreen));

      // Set start
      state.simulateBuildingTap(start);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();

      // Tap a different building
      state.simulateBuildingTap(dest);
      await tester.pumpAndSettle();

      expect(find.text('Set as Destination'), findsOneWidget,
          reason: 'After start is set, tapping a building must offer "Set as Destination"');
    },
  );

  testWidgets(
    'US-2.1: pressing "Set as Destination" shows both buildings in the DirectionsCard',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
      final start = sgwBuildings[0];
      final dest  = sgwBuildings[1];

      final dynamic state = tester.state(find.byType(HomeScreen));

      state.simulateBuildingTap(start);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();

      state.simulateBuildingTap(dest);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as Destination'));
      await tester.pumpAndSettle();

      final startLabel = start.fullName ?? start.name;
      final destLabel  = dest.fullName  ?? dest.name;
      expect(find.textContaining('Start: $startLabel'), findsOneWidget);
      expect(find.textContaining('Destination: $destLabel'), findsOneWidget);
    },
  );

  // ─── AC: User can type in the name of a destination building ────────────────

  testWidgets(
    'US-2.1: typing a building name in the search field shows matching results',
        (tester) async {
      await pumpApp(tester);
      final building = buildings.firstWhere((b) => b.campus == Campus.sgw);

      await tester.enterText(find.byType(TextField), building.name.toLowerCase());
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text(building.name), findsWidgets,
          reason: 'Typing a building name must show it in the search results');
    },
  );

  testWidgets(
    'US-2.1: selecting a search result after setting start triggers destination selection',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
      final start = sgwBuildings[0];
      final dest  = sgwBuildings[1];

      final dynamic state = tester.state(find.byType(HomeScreen));

      // Set start via tap
      state.simulateBuildingTap(start);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();

      // Search for destination by name
      await tester.enterText(find.byType(TextField), dest.name.toLowerCase());
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Select the result — triggers _onBuildingTapped which shows Set as Destination
      await tester.tap(find.text(dest.name).first);
      await tester.pumpAndSettle();

      expect(find.text('Set as Destination'), findsOneWidget,
          reason: 'Selecting a search result with a start already set must '
              'offer "Set as Destination"');
    },
  );

  // ─── AC: User can cancel without selecting a destination ────────────────────

  testWidgets(
    'US-2.1: pressing the cancel (X) button on DirectionsCard clears the selection',
        (tester) async {
      await pumpApp(tester);
      final building = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateBuildingTap(building);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();

      // DirectionsCard is visible
      expect(find.text('Directions'), findsOneWidget);

      // Tap the X button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // DirectionsCard should be gone
      expect(find.text('Directions'), findsNothing,
          reason: 'Cancelling must remove the DirectionsCard');
    },
  );

  testWidgets(
    'US-2.1: closing the building detail modal without choosing does not set a start',
        (tester) async {
      await pumpApp(tester);
      final building = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateBuildingTap(building);
      await tester.pumpAndSettle();

      // Dismiss the modal by tapping the barrier — without pressing any button
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // DirectionsCard must not appear — no start was set
      expect(find.text('Directions'), findsNothing,
          reason: 'Dismissing the modal without choosing must not set a start building');
    },
  );
}