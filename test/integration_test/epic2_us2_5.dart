// US-2.5: Choose a transportation mode (Walk, Bike, Drive, Transit, Shuttle)
//
// Tests marked [TODO] cover acceptance criteria that are not yet implemented.
// They are expected to fail until the feature is complete.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/data/data_parser.dart';

import 'helpers.dart';

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
    await pause(2);
  }

  Future<void> setStartAndDestination(
    WidgetTester tester,
    dynamic state,
    dynamic start,
    dynamic dest,
  ) async {
    state.simulateBuildingTap(start);
    await tester.pumpAndSettle();
    await pause(2);

    await tester.tap(find.text('Set as Start'));
    await tester.pumpAndSettle();
    await pause(2);

    state.simulateBuildingTap(dest);
    await tester.pumpAndSettle();
    await pause(2);

    await tester.tap(find.text('Set as Destination'));
    await tester.pumpAndSettle();
    await pause(2);
  }

  // ─── AC: Mode chips are visible ──────────────────────────────────────────────

  testWidgets(
    'US-2.5: Walk, Bike, Drive, Transit and Shuttle chips are all visible once both buildings are set',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      expect(find.text('Walk'),    findsOneWidget);
      expect(find.text('Bike'),    findsOneWidget);
      expect(find.text('Drive'),   findsOneWidget);
      expect(find.text('Transit'), findsOneWidget);
      expect(find.text('Shuttle'), findsOneWidget);
      await pause(2);
    },
  );

  testWidgets(
    'US-2.5: mode chips are not shown before a start building is selected',
    (tester) async {
      await pumpApp(tester);
      expect(find.text('Walk'),    findsNothing);
      expect(find.text('Shuttle'), findsNothing);
      await pause(2);
    },
  );

  // ─── AC: Walk default for same-campus ────────────────────────────────────────

  testWidgets(
    'US-2.5: Walk chip is selected by default for a same-campus (SGW → SGW) route',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Walk'),
        findsOneWidget,
        reason: 'Walk chip must be selected by default for same-campus routes',
      );
      await pause(2);
    },
  );

  // ─── AC: Shuttle default for cross-campus ────────────────────────────────────

  testWidgets(
    'US-2.5: Shuttle chip is selected by default for a cross-campus (SGW → Loyola) route',
    (tester) async {
      await pumpApp(tester);
      final sgwBuilding    = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuilding, loyolaBuilding);

      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Shuttle'),
        findsOneWidget,
        reason: 'Shuttle chip must be selected by default for cross-campus routes',
      );
      await pause(2);
    },
  );

  // ─── AC: Changing mode triggers a new route request ──────────────────────────

  testWidgets(
    'US-2.5: switching from Walk to Drive immediately triggers a new route request',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Drive'));
      await tester.pump(); // one frame — loading starts before the network call resolves
      await pause(2); // observe loading indicator

      expect(find.text('Loading directions...'), findsOneWidget,
          reason: 'Switching to Drive must immediately trigger a new route request');

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'US-2.5: switching from Walk to Transit immediately triggers a new route request',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Transit'));
      await tester.pump();
      await pause(2); // observe loading indicator

      expect(find.text('Loading directions...'), findsOneWidget,
          reason: 'Switching to Transit must immediately trigger a new route request');

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'US-2.5: switching from Walk to Shuttle replaces the route with a shuttle placeholder',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Shuttle'));
      await tester.pumpAndSettle();
      await pause(2); // observe shuttle placeholder

      // Shuttle does not call the Directions API — it shows a placeholder instead
      expect(find.text('Loading directions...'), findsNothing);
      expect(find.textContaining('Shuttle'), findsWidgets,
          reason: 'Switching to Shuttle must show a shuttle-related message');
      await pause(2);
    },
  );

  // ─── AC: Selected mode is clearly visible ────────────────────────────────────

  testWidgets(
    'US-2.5: tapping Drive makes the Drive chip appear selected',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Drive'));
      await tester.pumpAndSettle();
      await pause(2); // observe Drive chip selected

      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Drive'),
        findsOneWidget,
        reason: 'Drive chip must be visually selected after tapping it',
      );
      await pause(2);
    },
  );

  testWidgets(
    'US-2.5: tapping Bike makes the Bike chip appear selected',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Bike'));
      await tester.pumpAndSettle();
      await pause(2); // observe Bike chip selected

      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Bike'),
        findsOneWidget,
        reason: 'Bike chip must be visually selected after tapping it',
      );
      await pause(2);
    },
  );

  // ─── AC: Map updates / route or error shown after mode change ────────────────

  testWidgets(
    'US-2.5: after switching to Drive and waiting, a route summary or Retry is shown',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Drive'));
      await tester.pumpAndSettle();
      await pause(2); // observe Drive route result

      final hasRoute = find.textContaining(' • ').evaluate().isNotEmpty;
      final hasError = find.text('Retry').evaluate().isNotEmpty;
      expect(hasRoute || hasError, isTrue,
          reason: 'After switching to Drive the card must show a route summary or Retry');
      await pause(2);
    },
  );

  // ─── AC: Dotted line for Walk [TODO — not yet implemented] ───────────────────

  testWidgets(
    'US-2.5 [TODO]: Walk mode polyline uses a dotted line pattern',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);
      await pause(2);

      final Polyline? polyline = state.testPolyline as Polyline?;
      expect(polyline, isNotNull,
          reason: 'Walk mode must produce a polyline on the map');
      expect(
        polyline!.patterns.any((p) => p == PatternItem.dot),
        isTrue,
        reason: 'Walk mode polyline must use a dotted pattern',
      );
      await pause(2);
    },
  );

  // ─── AC: Distinct colors for Transit and Bike [TODO — not yet implemented] ───

  testWidgets(
    'US-2.5 [TODO]: Transit mode uses a distinct polyline color',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Transit'));
      await tester.pumpAndSettle();
      await pause(2);

      final Polyline? polyline = state.testPolyline as Polyline?;
      expect(polyline, isNotNull,
          reason: 'Transit mode must produce a polyline on the map');
      // Must differ from the default blue used for all modes today
      expect(
        polyline!.color,
        isNot(equals(const Color(0xFF1A73E8))),
        reason: 'Transit mode must use a color distinct from the default',
      );
      await pause(2);
    },
  );

  testWidgets(
    'US-2.5 [TODO]: Bike mode uses a distinct polyline color',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Bike'));
      await tester.pumpAndSettle();
      await pause(2);

      final Polyline? polyline = state.testPolyline as Polyline?;
      expect(polyline, isNotNull,
          reason: 'Bike mode must produce a polyline on the map');
      expect(
        polyline!.color,
        isNot(equals(const Color(0xFF1A73E8))),
        reason: 'Bike mode must use a color distinct from the default',
      );
      await pause(2);
    },
  );

  // ─── AC: Concordia burgundy for Shuttle [TODO — not yet implemented] ─────────

  testWidgets(
    'US-2.5 [TODO]: Shuttle chip uses Concordia burgundy as its indicator color',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      await tester.tap(find.text('Shuttle'));
      await tester.pumpAndSettle();
      await pause(2); // observe Shuttle chip color

      const concordiaBurgundy = Color(0xFF912338);
      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Shuttle' &&
            w.selectedColor == concordiaBurgundy),
        findsOneWidget,
        reason: 'Selected Shuttle chip must use Concordia burgundy',
      );
      await pause(2);
    },
  );
}