// US-2.5: Choose a transportation mode (Walk, Bike, Drive, Transit, Shuttle)

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
  late dynamic sgwStart;   // first SGW building (one end of campus)
  late dynamic sgwEnd;     // last SGW building (other end of campus)
  late dynamic loyolaEnd;  // first Loyola building

  setUpAll(() async {
    await loadEnv();
    buildings = await DataParser().getBuildingInfoFromJSON();
    final sgw = buildings.where((b) => b.campus == Campus.sgw).toList();
    sgwStart  = sgw.first;
    sgwEnd    = sgw.last;
    loyolaEnd = buildings.firstWhere((b) => b.campus == Campus.loyola);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 5));
    await pause(2);
  }

  Future<void> setStartAndDestination(
    WidgetTester tester,
    dynamic state,
    dynamic start,
    dynamic dest,
  ) async {
    state.simulateBuildingTap(start);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(1);

    await tester.tap(find.text('Set as Start'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(1);

    state.simulateBuildingTap(dest);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(1);

    await tester.tap(find.text('Set as Destination'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Wait for the initial route HTTP call to resolve
    await pumpFor(tester, const Duration(seconds: 10));
    await pause(2);
  }

  // ─── Chips hidden before any selection ───────────────────────────────────────

  testWidgets(
    'US-2.5: mode chips are not shown before a start building is selected',
    (tester) async {
      await pumpApp(tester);
      expect(find.text('Walk'),    findsNothing);
      expect(find.text('Shuttle'), findsNothing);
      await pause(2);
    },
  );

  // ─── Same-campus: all modes in one session (SGW first → SGW last) ────────────
  //
  // Uses the first and last buildings in the SGW list to maximise the distance
  // between start and destination, giving the API something meaningful to route.

  testWidgets(
    'US-2.5: same-campus (SGW → SGW) — chips visible, Walk default, mode switching',
    (tester) async {
      await pumpApp(tester);
      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwStart, sgwEnd);

      // ── All chips visible ───────────────────────────────────────────────────
      expect(find.text('Walk'),    findsOneWidget);
      expect(find.text('Bike'),    findsOneWidget);
      expect(find.text('Drive'),   findsOneWidget);
      expect(find.text('Transit'), findsOneWidget);
      expect(find.text('Shuttle'), findsOneWidget);
      await pause(2);

      // ── Walk selected by default ────────────────────────────────────────────
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

      // ── Drive: triggers loading, resolves to route or Retry ─────────────────
      await tester.tap(find.text('Drive'));
      await tester.pump(); // one frame — loading starts before the HTTP call resolves
      await pause(2);      // observe loading indicator
      expect(find.text('Loading directions...'), findsOneWidget,
          reason: 'Switching to Drive must immediately show loading');

      await pumpFor(tester, const Duration(seconds: 10));
      await pause(2); // observe Drive route result

      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Drive'),
        findsOneWidget,
        reason: 'Drive chip must be selected after tapping it',
      );
      final driveHasRoute = find.textContaining(' · ').evaluate().isNotEmpty;
      final driveHasError = find.text('Retry').evaluate().isNotEmpty;
      expect(driveHasRoute || driveHasError, isTrue,
          reason: 'Drive must show a route summary or Retry after resolving');
      await pause(2);

      // ── Bike: triggers loading, resolves to route or Retry ──────────────────
      await tester.tap(find.text('Bike'));
      await tester.pump();
      await pause(2); // observe loading indicator
      expect(find.text('Loading directions...'), findsOneWidget,
          reason: 'Switching to Bike must immediately show loading');

      await pumpFor(tester, const Duration(seconds: 10));
      await pause(2); // observe Bike route result

      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Bike'),
        findsOneWidget,
        reason: 'Bike chip must be selected after tapping it',
      );
      final bikeHasRoute = find.textContaining(' · ').evaluate().isNotEmpty;
      final bikeHasError = find.text('Retry').evaluate().isNotEmpty;
      expect(bikeHasRoute || bikeHasError, isTrue,
          reason: 'Bike must show a route summary or Retry after resolving');
      await pause(2);

      // ── Transit: triggers loading, resolves ─────────────────────────────────
      await tester.tap(find.text('Transit'));
      await tester.pump();
      await pause(2); // observe loading indicator
      expect(find.text('Loading directions...'), findsOneWidget,
          reason: 'Switching to Transit must immediately show loading');

      await pumpFor(tester, const Duration(seconds: 10));
      await pause(2); // observe Transit route result

      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Transit'),
        findsOneWidget,
        reason: 'Transit chip must be selected after tapping it',
      );
      await pause(2);

      // ── Shuttle (within campus): no API call, shows placeholder ────────────
      await tester.tap(find.text('Shuttle'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe shuttle placeholder

      expect(find.text('Loading directions...'), findsNothing,
          reason: 'Shuttle must not call the Directions API within campus');
      expect(find.textContaining('Shuttle'), findsWidgets,
          reason: 'Shuttle must show a shuttle-related message');

      expect(
        find.byWidgetPredicate((w) =>
            w is ChoiceChip &&
            w.selected == true &&
            w.label is Text &&
            (w.label as Text).data == 'Shuttle'),
        findsOneWidget,
        reason: 'Shuttle chip must be selected after tapping it',
      );
      await pause(2);
    },
  );

  // ─── Cross-campus: Shuttle is the default (SGW first → Loyola first) ─────────

  testWidgets(
    'US-2.5: cross-campus (SGW → Loyola) — Shuttle selected by default',
    (tester) async {
      await pumpApp(tester);
      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwStart, loyolaEnd);

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

  // ─── Cross-campus Transit: polyline uses the transit line color ───────────────

  testWidgets(
    'US-2.5: cross-campus (SGW → Loyola) Transit mode shows a route with a distinct color',
    (tester) async {
      await pumpApp(tester);
      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwStart, loyolaEnd);

      // Switch to Transit
      await tester.tap(find.text('Transit'));
      await tester.pump();
      await pause(2); // observe loading indicator
      expect(find.text('Loading directions...'), findsOneWidget,
          reason: 'Switching to Transit must immediately show loading');

      await pumpFor(tester, const Duration(seconds: 10));
      await pause(2); // observe Transit route result

      final hasRoute = find.textContaining(' · ').evaluate().isNotEmpty;
      final hasError = find.text('Retry').evaluate().isNotEmpty;
      expect(hasRoute || hasError, isTrue,
          reason: 'Transit must show a route summary or Retry after resolving');

      // The polyline color must differ from the walk/drive default blue
      final Polyline? polyline = state.testPolyline as Polyline?;
      expect(polyline, isNotNull,
          reason: 'Transit mode must produce a polyline on the map');
      expect(
        polyline!.color,
        isNot(equals(const Color(0xFF1A73E8))),
        reason: 'Transit polyline must use the transit line color, not the default blue',
      );
      await pause(2);
    },
  );
}
