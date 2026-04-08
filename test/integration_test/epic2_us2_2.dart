// US-2.2: Show directions on the map (using Google API)

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

  testWidgets('US-2.2: directions generated automatically when start + destination are set',
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
    await pumpFor(tester, const Duration(seconds: 5));

    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
    final buildingA = sgwBuildings[0];
    final buildingB = sgwBuildings[1];
    final buildingC = sgwBuildings[2];

    // ── AC: No card shown when nothing is selected ────────────────────────────

    expect(find.text('Directions'), findsNothing,
        reason: 'DirectionsCard must be hidden until a start is set');

    // ── AC: UI shows start building; prompts for destination ─────────────────

    state.simulateBuildingTap(buildingA);
    await pumpFor(tester, const Duration(seconds: 2));

    await tester.tap(find.text('Set as Start'));
    await pumpFor(tester, const Duration(seconds: 2));

    final buildingAName = buildingA.fullName ?? buildingA.name;
    expect(find.textContaining('Start:'), findsOneWidget,
        reason: 'DirectionsCard must display a start label');
    expect(find.textContaining(buildingAName as String), findsWidgets,
        reason: 'DirectionsCard must display the selected start building name');
    expect(find.textContaining('Destination: Not set'), findsOneWidget,
        reason: 'Destination label must read "Not set" until one is chosen');
    expect(find.text('Select a destination to see a route.'), findsOneWidget,
        reason: 'Card must prompt for a destination when only start is set');

    // ── AC: Loading indicator appears automatically — no button needed ────────

    state.simulateBuildingTap(buildingB);
    await pumpFor(tester, const Duration(seconds: 2));

    await tester.tap(find.text('Set as Destination'));
    await tester.pump(); // one frame to capture loading state
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Loading directions...'), findsOneWidget,
        reason: 'A loading indicator must appear automatically — no button press needed');

    // ── AC: Route summary or error shown after request settles ────────────────

    await pumpFor(tester, const Duration(seconds: 10)); // keep UI live while HTTP resolves

    final buildingBName = buildingB.fullName ?? buildingB.name;
    expect(find.textContaining('Start:'), findsOneWidget,
        reason: 'Start label must remain visible after route loads');
    expect(find.textContaining(buildingAName as String), findsWidgets,
        reason: 'Start building name must remain visible after route loads');
    expect(find.textContaining('Destination:'), findsOneWidget,
        reason: 'Destination label must be visible after route loads');
    expect(find.textContaining(buildingBName as String), findsWidgets,
        reason: 'Destination building name must be visible after route loads');

    final hasRoute = find.textContaining(' · ').evaluate().isNotEmpty;
    final hasError = find.text('Retry').evaluate().isNotEmpty;
    expect(hasRoute || hasError, isTrue,
        reason: 'Card must show a route summary (valid key) or Retry (no key) — never silent');

    await pumpFor(tester, const Duration(seconds: 3)); // observe result

    // ── AC: Retry re-triggers the directions request ──────────────────────────

    if (hasError) {
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Loading directions...'), findsOneWidget,
          reason: 'Tapping Retry must re-trigger the directions request');

      await pumpFor(tester, const Duration(seconds: 10));
    }

    // ── AC: Changing destination triggers a new request automatically ─────────

    state.simulateBuildingTap(buildingC);
    await pumpFor(tester, const Duration(seconds: 2));

    await tester.tap(find.text('Set as Destination'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Loading directions...'), findsOneWidget,
        reason: 'Changing destination must automatically trigger a new route request');

    await pumpFor(tester, const Duration(seconds: 10));
    await pumpFor(tester, const Duration(seconds: 2)); // observe result

    // ── AC: Changing start building triggers a new request automatically ──────

    state.simulateBuildingTap(buildingB);
    await pumpFor(tester, const Duration(seconds: 2));

    await tester.tap(find.text('Set as Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Loading directions...'), findsOneWidget,
        reason: 'Changing start building must automatically trigger a new route request');

    await pumpFor(tester, const Duration(seconds: 10));
    await pumpFor(tester, const Duration(seconds: 3)); // observe result

    // ── AC: Cancelling hides the card entirely ────────────────────────────────

    await tester.tap(find.byIcon(Icons.close));
    await pumpFor(tester, const Duration(seconds: 2));

    expect(find.text('Directions'), findsNothing,
        reason: 'Cancelling must hide the DirectionsCard entirely');
    await pumpFor(tester, const Duration(seconds: 2));
  });
}
