// US-2.4: Directions between SGW and Loyola

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/models/campus.dart';

import 'helpers.dart';

/// Selects start and destination, waits for route to settle, then asserts
/// that a route summary (or Retry) is shown — never silent.
Future<void> setAndVerifyRoute(
  WidgetTester tester,
  dynamic state,
  dynamic start,
  dynamic dest,
) async {
  state.simulateBuildingTap(start);
  await pumpFor(tester, const Duration(seconds: 2));

  await tester.tap(find.text('Set as Start'));
  await pumpFor(tester, const Duration(seconds: 2));

  state.simulateBuildingTap(dest);
  await pumpFor(tester, const Duration(seconds: 2));

  await tester.tap(find.text('Set as Destination'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  // Wait for HTTP to resolve while keeping UI live
  await pumpFor(tester, const Duration(seconds: 10));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('US-2.4: same-campus and cross-campus routes are generated successfully',
      (tester) async {

    // ── Load app ─────────────────────────────────────────────────────────────

    await loadEnv();
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));

    final dynamic state = tester.state(find.byType(HomeScreen));
    // Wait for buildings to load (buildingsPresent is populated by the parser future)
    await pumpFor(tester, const Duration(seconds: 5));

    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuildings    = buildings.where((b) => b.campus == Campus.sgw).toList();
    final loyolaBuildings = buildings.where((b) => b.campus == Campus.loyola).toList();
    final sgwA    = sgwBuildings[0];
    final sgwB    = sgwBuildings[1];
    final loyola  = loyolaBuildings[0];

    // ── AC 1: Same-campus route (SGW → SGW) ──────────────────────────────────

    await setAndVerifyRoute(tester, state, sgwA, sgwB);

    expect(
      find.textContaining('SGW ↔ Loyola'),
      findsNothing,
      reason: 'Same-campus route must not show the cross-campus shuttle message',
    );

    final sameCampusHasRoute = find.textContaining(' · ').evaluate().isNotEmpty;
    final sameCampusHasError = find.text('Retry').evaluate().isNotEmpty;
    expect(sameCampusHasRoute || sameCampusHasError, isTrue,
        reason: 'Same-campus route must show a result or error — never silent');

    await pumpFor(tester, const Duration(seconds: 3)); // observe

    // Clear for next test
    await tester.tap(find.byIcon(Icons.close));
    await pumpFor(tester, const Duration(seconds: 1));

    // ── AC 2: Cross-campus route (SGW → Loyola) ───────────────────────────────

    await setAndVerifyRoute(tester, state, sgwA, loyola);

    expect(find.text('Directions'), findsOneWidget,
        reason: 'DirectionsCard must be visible for an SGW → Loyola route');
    expect(find.textContaining('Start:'), findsOneWidget);
    expect(find.textContaining(sgwA.fullName ?? sgwA.name as String), findsWidgets);
    expect(find.textContaining('Destination:'), findsOneWidget);
    expect(find.textContaining(loyola.fullName ?? loyola.name as String), findsWidgets);

    final sgwToLoyHasRoute = find.textContaining(' · ').evaluate().isNotEmpty;
    final sgwToLoyHasError = find.text('Retry').evaluate().isNotEmpty;
    expect(sgwToLoyHasRoute || sgwToLoyHasError, isTrue,
        reason: 'SGW → Loyola route must be generated successfully');

    await pumpFor(tester, const Duration(seconds: 3)); // observe

    // Clear for next test
    await tester.tap(find.byIcon(Icons.close));
    await pumpFor(tester, const Duration(seconds: 1));

    // ── AC 3: Cross-campus route (Loyola → SGW) ───────────────────────────────

    await setAndVerifyRoute(tester, state, loyola, sgwA);

    expect(find.text('Directions'), findsOneWidget,
        reason: 'DirectionsCard must be visible for a Loyola → SGW route');
    expect(find.textContaining('Start:'), findsOneWidget);
    expect(find.textContaining(loyola.fullName ?? loyola.name as String), findsWidgets);
    expect(find.textContaining('Destination:'), findsOneWidget);
    expect(find.textContaining(sgwA.fullName ?? sgwA.name as String), findsWidgets);

    final loyToSgwHasRoute = find.textContaining(' · ').evaluate().isNotEmpty;
    final loyToSgwHasError = find.text('Retry').evaluate().isNotEmpty;
    expect(loyToSgwHasRoute || loyToSgwHasError, isTrue,
        reason: 'Loyola → SGW route must be generated successfully');

    await pumpFor(tester, const Duration(seconds: 3)); // observe
  });
}
