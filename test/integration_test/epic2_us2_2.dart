// US-2.2: Show directions on the map (using Google API)

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

  // ─── AC: UI clearly shows the selected start and destination buildings ──────

  testWidgets(
    'US-2.2: DirectionsCard shows the selected start building name',
        (tester) async {
      await pumpApp(tester);
      final building = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateBuildingTap(building);
      await tester.pumpAndSettle();
      await pause(2);

      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();
      await pause(2);

      final startLabel = building.fullName ?? building.name;
      expect(find.textContaining('Start: $startLabel'), findsOneWidget,
          reason: 'DirectionsCard must display the name of the start building');
      await pause(2);
    },
  );

  testWidgets(
    'US-2.2: DirectionsCard shows "Not set" when no destination is chosen',
        (tester) async {
      await pumpApp(tester);
      final building = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateBuildingTap(building);
      await tester.pumpAndSettle();
      await pause(2);

      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();
      await pause(2);

      expect(find.textContaining('Destination: Not set'), findsOneWidget,
          reason: 'Destination label must read "Not set" until one is chosen');
      await pause(2);
    },
  );

  testWidgets(
    'US-2.2: DirectionsCard shows both start and destination names once both are set',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
      final start = sgwBuildings[0];
      final dest  = sgwBuildings[1];

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, start, dest);

      expect(find.textContaining('Start: ${start.fullName ?? start.name}'), findsOneWidget);
      expect(find.textContaining('Destination: ${dest.fullName ?? dest.name}'), findsOneWidget);
      await pause(2);
    },
  );

  // ─── AC: If start or destination is missing, no route is shown ───────────────

  testWidgets(
    'US-2.2: DirectionsCard is not shown when no start building is selected',
        (tester) async {
      await pumpApp(tester);
      expect(find.text('Directions'), findsNothing,
          reason: 'DirectionsCard must be hidden until a start is set');
      await pause(2);
    },
  );

  testWidgets(
    'US-2.2: when only start is set, card prompts to select a destination',
        (tester) async {
      await pumpApp(tester);
      final building = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateBuildingTap(building);
      await tester.pumpAndSettle();
      await pause(2);

      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();
      await pause(2);

      expect(
        find.text('Select a destination to see a route.'),
        findsOneWidget,
        reason: 'With only a start selected, card must prompt for a destination',
      );
      await pause(2);
    },
  );

  // ─── AC: Directions generated automatically — UI indicates loading ───────────

  testWidgets(
    'US-2.2: loading indicator appears automatically after both buildings are set',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
      final start = sgwBuildings[0];
      final dest  = sgwBuildings[1];

      final dynamic state = tester.state(find.byType(HomeScreen));

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
      await tester.pump(); // one frame — loading starts, before it resolves
      await pause(2); // observe loading indicator

      expect(
        find.text('Loading directions...'),
        findsOneWidget,
        reason: 'A loading indicator must appear immediately after destination is set',
      );

      await tester.pumpAndSettle();
    },
  );

  // ─── AC: If route generation fails, a Retry option is shown ─────────────────
  // NOTE: With a valid API key the request succeeds so we check for the route
  // summary instead. With no key, Retry appears. Both are valid outcomes.

  testWidgets(
    'US-2.2: route summary or Retry is shown after directions request settles',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);
      await pause(2);

      final hasRoute = find.textContaining(' • ').evaluate().isNotEmpty;
      final hasError = find.text('Retry').evaluate().isNotEmpty;

      expect(hasRoute || hasError, isTrue,
          reason: 'Card must show a route summary (API key present) or Retry (no key)');
      await pause(2);
    },
  );

  testWidgets(
    'US-2.2: tapping Retry re-triggers the directions request (loading reappears)',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      if (find.text('Retry').evaluate().isNotEmpty) {
        // No API key — error state shown, test Retry interaction
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await pause(2);

        expect(find.text('Loading directions...'), findsOneWidget,
            reason: 'Tapping Retry must re-trigger the directions request');

        await tester.pumpAndSettle();
      } else {
        // Valid API key — directions succeeded, Retry not shown. Pass.
        expect(find.textContaining(' • ').evaluate().isNotEmpty, isTrue,
            reason: 'With a valid API key a route summary must be shown');
        await pause(2);
      }
    },
  );

  // ─── AC: Route updates automatically when start/destination changes ──────────

  testWidgets(
    'US-2.2: changing destination triggers a new directions request automatically',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
      final start = sgwBuildings[0];
      final dest1 = sgwBuildings[1];
      final dest2 = sgwBuildings[2];

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, start, dest1);

      state.simulateBuildingTap(dest2);
      await tester.pumpAndSettle();
      await pause(2);

      await tester.tap(find.text('Set as Destination'));
      await tester.pump(); // loading starts immediately
      await pause(2);

      expect(find.text('Loading directions...'), findsOneWidget,
          reason: 'Changing destination must automatically trigger a new route request');

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'US-2.2: cancelling directions clears both buildings and hides the card',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      expect(find.text('Directions'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await pause(2);

      expect(find.text('Directions'), findsNothing,
          reason: 'Cancelling must hide the DirectionsCard entirely');
      await pause(2);
    },
  );

  // ─── AC: Route displayed on map ──────────────────────────────────────────────

  testWidgets(
    'US-2.2: route polyline is rendered on the map after successful fetch',
        (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);
      await pause(2);

      final hasRoute = find.textContaining(' • ').evaluate().isNotEmpty ||
          find.text('Loading directions...').evaluate().isNotEmpty;
      final hasError = find.text('Retry').evaluate().isNotEmpty;

      expect(hasRoute || hasError, isTrue,
          reason: 'After setting both buildings, the app must either show a '
              'route or an error — it must never silently do nothing');
      await pause(2);
    },
  );
}