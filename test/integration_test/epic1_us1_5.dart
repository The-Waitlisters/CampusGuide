// US-1.5: Show building info when tapping on a building

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/models/campus.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('US-1.5: tap building, different building, then off-campus', (tester) async {

    // ── Load the map ─────────────────────────────────────────────────────────

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
    await pause(3); // observe map loaded with building polygons

    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();
    final buildingA = sgwBuildings[0];
    final buildingB = sgwBuildings[1];

    // ── Demo 1: Tap first SGW building ───────────────────────────────────────

    (state as HomeScreenState).handleMapTap(polygonCenter(buildingA.boundary));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(3); // observe detail sheet for first building

    expect(find.textContaining(buildingA.name as String), findsOneWidget,
        reason: 'Detail sheet must show the tapped building name');

    // ── Demo 2: Tap a different SGW building ─────────────────────────────────

    state.handleMapTap(polygonCenter(buildingB.boundary));
    await pumpFor(tester, const Duration(milliseconds: 500));
    state.handleMapTap(polygonCenter(buildingB.boundary));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(3); // observe detail sheet updates to second building

    expect(find.textContaining(buildingB.name as String), findsOneWidget,
        reason: 'Detail sheet must update to the newly tapped building');

    // ── Demo 3: Tap off-campus ────────────────────────────────────────────────

    state.handleMapTap(const LatLng(45.4990, -73.5790));
    await pumpFor(tester, const Duration(milliseconds: 500));
    state.handleMapTap(const LatLng(45.4990, -73.5790));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(3); // observe "Not part of campus" message

    expect(find.text('Not part of campus'), findsOneWidget,
        reason: 'Tapping off-campus must show "Not part of campus"');

    await pause(2);
  });
}
