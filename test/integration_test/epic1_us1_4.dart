// US-1.4: Show the building the user is currently located in

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

  testWidgets('US-1.4: in-building detection and highlight', (tester) async {

    // ── Step 1: Load the map ─────────────────────────────────────────────────

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
    await pause(4); // observe map with building polygons rendered

    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);
    final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);

    final insideSgw = polygonCenter(sgwBuilding.boundary);
    final insideLoyola = polygonCenter(loyolaBuilding.boundary);
    final boundaryPoint = sgwBuilding.boundary.first;

    // ── Step 2: Show location working ────────────────────────────────────────

    // Demo 1: Inside an SGW building — building turns blue, name appears
    state.simulateGpsLocation(insideSgw);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(4); // observe SGW building highlighted in blue

    // Demo 2: Switch to Loyola and simulate being inside a Loyola building
    state.simulateCampusChange(Campus.loyola);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(4); // wait for camera animation to visually settle at Loyola

    state.simulateGpsLocation(insideLoyola);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await pause(4); // observe Loyola building highlighted in blue

    // Demo 3: Off-campus nearby — marker visible but no building highlighted
    state.simulateCampusChange(Campus.sgw);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(4); // wait for camera animation to visually settle at SGW

    state.simulateGpsLocation(const LatLng(45.4990, -73.5790));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await pause(4); // observe marker on screen with no building highlighted

    // ── Step 3: Assert the ACs ───────────────────────────────────────────────

    // AC: Inside a building → building is highlighted and named
    state.simulateGpsLocation(insideSgw);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2); // observe blue highlight

    final expectedName =
        (sgwBuilding.fullName as String?)?.isNotEmpty == true
            ? sgwBuilding.fullName as String
            : sgwBuilding.name as String;
    expect(find.text(expectedName), findsOneWidget,
        reason: 'GPS status card must show the building name when inside');
    expect(
      (state.testPolygons as Set).any((p) =>
          p.polygonId.value == sgwBuilding.id &&
          p.fillColor == const Color(0x803197F6)),
      isTrue,
      reason: 'The current building polygon must be highlighted blue',
    );
    await pause(2);

    // AC: Far from all buildings → UI indicates "Not in a building"
    state.simulateGpsLocation(const LatLng(0, 0));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2); // observe card reverts

    expect(find.text('Not in a building'), findsOneWidget,
        reason: 'GPS status card must show "Not in a building" when far away');
    await pause(2);

    // AC: Hysteresis — on the building boundary, user stays shown as inside
    state.simulateGpsLocation(insideSgw); // enter the building first
    await pumpFor(tester, const Duration(milliseconds: 300));
    state.simulateGpsLocation(boundaryPoint); // step to the boundary edge
    await pumpFor(tester, const Duration(milliseconds: 300));
    await pause(2); // observe that the building stays highlighted

    expect(
      find.text('Not in a building').evaluate().isEmpty,
      isTrue,
      reason: 'Hysteresis must keep user shown as inside when on the boundary',
    );
    await pause(2);
  });
}
