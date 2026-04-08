import 'dart:async';
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

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    await pause(2);
  }

  // ─── AC: User is able to switch between SGW and Loyola using UI controls ─────

  testWidgets(
    'US-1.3: switching to Loyola sets campus to loyola',
        (tester) async {
      await pumpApp(tester);
      final dynamic state = tester.state(find.byType(HomeScreen));

      state.simulateCampusChange(Campus.loyola);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe switch to Loyola

      expect(find.text('campus:loyola'), findsOneWidget);
      await pause(2);
    },
  );

  testWidgets(
    'US-1.3: switching back to SGW sets campus to sgw',
        (tester) async {
      await pumpApp(tester);
      final dynamic state = tester.state(find.byType(HomeScreen));

      state.simulateCampusChange(Campus.loyola);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe switch to Loyola

      state.simulateCampusChange(Campus.sgw);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe switch back to SGW

      expect(find.text('campus:sgw'), findsOneWidget);
      await pause(2);
    },
  );

  // ─── Tap detection respects the active campus ────────────────────────────────

  testWidgets(
    'US-1.3: tapping an SGW building while on Loyola shows "Not part of campus"',
        (tester) async {
      await pumpApp(tester);
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateCampusChange(Campus.loyola);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe campus switch to Loyola

      (state as HomeScreenState).handleMapTap(polygonCenter(sgwBuilding.boundary));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe "Not part of campus" sheet

      expect(find.text('Not part of campus'), findsOneWidget);
      await pause(2);
    },
  );

  testWidgets(
    'US-1.3: tapping a Loyola building while on Loyola opens its detail sheet',
        (tester) async {
      await pumpApp(tester);
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateCampusChange(Campus.loyola);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe campus switch to Loyola

      (state as HomeScreenState).handleMapTap(polygonCenter(loyolaBuilding.boundary));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe building detail sheet

      expect(find.textContaining(loyolaBuilding.name), findsOneWidget);
      await pause(2);
    },
  );
}
