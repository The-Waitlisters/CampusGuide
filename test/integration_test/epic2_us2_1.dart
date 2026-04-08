// US-2.1: Be able to select a start and destination building

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/services/directions/directions_controller.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';

import 'helpers.dart';

// ── Stub directions client ────────────────────────────────────────────────────
//
// Returns an empty but valid RouteResult so no real HTTP call is made.
// This prevents the "Directions API key missing" error from surfacing during
// tests that only need to verify start/destination selection, not routing.

class _StubDirectionsClient implements DirectionsClient {
  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) async {
    return const RouteResult(
      legs: [],
      durationText: '5 min',
      distanceText: '400 m',
    );
  }
}

Future<dynamic> _loadApp(WidgetTester tester) async {
  await loadEnv(); // load .env so any dotenv-based secrets are available
  await tester.pumpWidget(
    CampusGuideApp(
      home: HomeScreen(
        testMapControllerCompleter: Completer<GoogleMapController>(),
        testDirectionsController: DirectionsController(
          client: _StubDirectionsClient(),
        ),
      ),
    ),
  );
  final dynamic state = tester.state(find.byType(HomeScreen));
  await pumpFor(tester, const Duration(seconds: 5));
  await pause(2);
  return state;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Test 1: Set start + destination via map taps ────────────────────────────

  testWidgets('US-2.1 Test 1: select start and destination via map taps', (tester) async {
    final state = await _loadApp(tester);

    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
    final buildingA = sgwBuildings[0];
    final buildingB = sgwBuildings[1];

    state.simulateBuildingTap(buildingA);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    expect(find.text('Set as Start'), findsOneWidget);
    await tester.tap(find.text('Set as Start'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    final startLabelA = buildingA.fullName ?? buildingA.name;
    expect(find.textContaining('Start: $startLabelA'), findsOneWidget);

    state.simulateBuildingTap(buildingB);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    expect(find.text('Set as Destination'), findsOneWidget);
    await tester.tap(find.text('Set as Destination'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(3);

    final destLabelB = buildingB.fullName ?? buildingB.name;
    expect(find.textContaining('Start: $startLabelA'), findsOneWidget);
    expect(find.textContaining('Destination: $destLabelB'), findsOneWidget);
  });

  // ── Test 2: Search bar → Set as Start + Set as Destination ─────────────────

  testWidgets('US-2.1 Test 2: select start and destination via search bar', (tester) async {
    final state = await _loadApp(tester);

    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
    final buildingC = sgwBuildings[0];
    final buildingD = sgwBuildings[1];

    await tester.enterText(find.byType(TextField), buildingC.name.toLowerCase());
    await pumpFor(tester, const Duration(milliseconds: 400));
    await pause(2);

    await tester.tap(find.byType(ListTile).first);
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    expect(find.text('Set as Start'), findsOneWidget);
    await tester.tap(find.text('Set as Start'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    expect(find.textContaining('Start:'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), buildingD.name.toLowerCase());
    await pumpFor(tester, const Duration(milliseconds: 400));
    await pause(2);

    await tester.tap(find.byType(ListTile).first);
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    expect(find.text('Set as Destination'), findsOneWidget);
    await tester.tap(find.text('Set as Destination'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(3);

    expect(find.textContaining('Start:'), findsOneWidget);
    expect(find.textContaining('Destination:'), findsOneWidget);
  });

  // ── Test 3: GPS inside building → "Set Current building as starting point" ──

  testWidgets('US-2.1 Test 3: set start via current GPS building button', (tester) async {
    final state = await _loadApp(tester);

    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
    final buildingA = sgwBuildings[0];

    final gpsBuildingPoint = polygonCenter(buildingA.boundary);
    state.simulateGpsLocation(gpsBuildingPoint);
    state.setIsInBuildingForTest(true);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(3);

    expect(find.text('Set Current building as starting point'), findsOneWidget);
    await tester.tap(find.text('Set Current building as starting point'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(3);

    expect(find.textContaining('Start:'), findsOneWidget);
  });

  // ── Test 4: X button clears the selection ───────────────────────────────────

  testWidgets('US-2.1 Test 4: X button clears building selection', (tester) async {
    final state = await _loadApp(tester);

    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
    final buildingA = sgwBuildings[0];

    state.simulateBuildingTap(buildingA);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    expect(find.text('Set as Start'), findsOneWidget);
    await tester.tap(find.text('Set as Start'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    expect(find.textContaining('Start:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(3);

    expect(find.textContaining('Start:'), findsNothing,
        reason: 'Pressing X must clear the selection and hide the DirectionsCard');
  });
}
