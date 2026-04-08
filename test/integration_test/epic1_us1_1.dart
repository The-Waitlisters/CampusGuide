import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/models/campus.dart';
import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('US-1.1: full campus map flow', (tester) async {
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));

    final dynamic state = tester.state(find.byType(HomeScreen));

    // Wait for buildings to load, then give the map time to render polygons
    await pumpFor(tester, const Duration(seconds: 5));
    await pause(4); // let the Google Maps native view render the polygons

    // ─── AC: App loads with a valid default campus ──────────────────────────

    expect(find.byKey(const Key('campus_label')), findsOneWidget);
    await pause(2);

    // ─── AC: Default campus is valid ────────────────────────────────────────

    final hasSgw = find.text('campus:sgw').evaluate().isNotEmpty;
    final hasLoyola = find.text('campus:loyola').evaluate().isNotEmpty;
    expect(hasSgw || hasLoyola, isTrue,
        reason: 'A valid default campus must be shown on launch');
    expect(hasSgw && hasLoyola, isFalse,
        reason: 'Only one campus can be active at a time');
    await pause(2);

    // ─── AC: Campus toggle is visible with both options ─────────────────────

    expect(find.byKey(const Key('campus_toggle')), findsOneWidget);
    expect(find.text('SGW'), findsOneWidget);
    expect(find.text('Loyola'), findsOneWidget);
    await pause(2);

    // ─── AC: Switching campus updates the label ──────────────────────────────

    state.simulateCampusChange(Campus.loyola);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await pause(2); // observe the campus switch to Loyola

    expect(find.text('campus:loyola'), findsOneWidget);
    await pause(2);

    state.simulateCampusChange(Campus.sgw);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await pause(2); // observe switch back to SGW

    expect(find.text('campus:sgw'), findsOneWidget);
    await pause(2);

    // ─── AC: Buildings are present on the map after launch ───────────────────

    expect(
      (state.testPolygons as Set).isNotEmpty,
      isTrue,
      reason: 'At least one campus building polygon must be rendered on the map',
    );
    await pause(2);

    // ─── AC: Building polygons survive a round-trip campus switch ────────────

    state.simulateCampusChange(Campus.loyola);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await pause(2); // observe switch to Loyola

    state.simulateCampusChange(Campus.sgw);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await pause(2); // observe switch back to SGW

    expect(
      (state.testPolygons as Set).isNotEmpty,
      isTrue,
      reason: 'Polygons must not be lost after switching campus back and forth',
    );
    await pause(2);
  });
}
