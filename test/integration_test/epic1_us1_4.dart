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

  testWidgets('US-1.4: GPS location detects the building the user is in',
      (tester) async {
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 5));
    await pause(2);

    final dynamic state = tester.state(find.byType(HomeScreen));
    final buildings = List.from(state.buildingsPresent as List);
    final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);

    final insideSgw = polygonCenter(sgwBuilding.boundary);

    state.simulateGpsLocation(insideSgw);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(2);

    final expectedName =
        (sgwBuilding.fullName as String?)?.isNotEmpty == true
            ? sgwBuilding.fullName as String
            : sgwBuilding.name as String;

    expect(
      find.text(expectedName),
      findsOneWidget,
      reason: 'GPS status card must show the building name when inside',
    );
    expect(
      (state.testPolygons as Set).any((p) =>
          p.polygonId.value == sgwBuilding.id &&
          p.fillColor == const Color(0x803197F6)),
      isTrue,
      reason: 'The current building polygon must be highlighted blue',
    );
    await pause(2);
  });
}
