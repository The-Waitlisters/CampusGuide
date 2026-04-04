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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await pause(2);
  }

  // ─── AC: Tapping outside campus shows "Not part of campus" ──────────────────

  testWidgets(
    'US-1.5: tapping outside campus shows "Not part of campus" sheet',
        (tester) async {
      await pumpApp(tester);
      final state = tester.state(find.byType(HomeScreen)) as HomeScreenState;

      state.handleMapTap(const LatLng(0, 0));
      await tester.pumpAndSettle();
      await pause(2); // observe "Not part of campus" sheet

      expect(find.text('Not part of campus'), findsOneWidget);
      await pause(2);
    },
  );

  // ─── AC: Tapping a building opens a popup with the building's info ────────────

  testWidgets(
    'US-1.5: tapping an SGW building opens a detail sheet with the building name',
        (tester) async {
      await pumpApp(tester);
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final state = tester.state(find.byType(HomeScreen)) as HomeScreenState;
      state.handleMapTap(polygonCenter(sgwBuilding.boundary));
      await tester.pumpAndSettle();
      await pause(2); // observe building detail sheet

      expect(find.textContaining(sgwBuilding.name), findsOneWidget,
          reason: 'Building short name must appear in the detail sheet');
      await pause(2);
    },
  );

  testWidgets(
    'US-1.5: building detail sheet shows the full building name',
        (tester) async {
      await pumpApp(tester);
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final sgwBuilding = buildings.firstWhere(
              (b) => b.campus == Campus.sgw && (b.fullName ?? '').trim().isNotEmpty);

      final state = tester.state(find.byType(HomeScreen)) as HomeScreenState;
      state.handleMapTap(polygonCenter(sgwBuilding.boundary));
      await tester.pumpAndSettle();
      await pause(2); // observe full name in sheet

      expect(find.textContaining(sgwBuilding.fullName!), findsOneWidget,
          reason: 'Full building name must appear in the detail sheet');
      await pause(2);
    },
  );

  testWidgets(
    'US-1.5: building detail sheet contains Opening Hours, Departments, and Services sections',
        (tester) async {
      await pumpApp(tester);
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final state = tester.state(find.byType(HomeScreen)) as HomeScreenState;
      state.handleMapTap(polygonCenter(sgwBuilding.boundary));
      await tester.pumpAndSettle();
      await pause(2); // observe sheet sections

      expect(find.text('Opening Hours:'), findsOneWidget);
      expect(find.text('Departments:'), findsOneWidget);
      expect(find.text('Services:'), findsOneWidget);
      await pause(2);
    },
  );

  // ─── Campus name in popup ─────────────────────────────────────────────────────

  testWidgets(
    'US-1.5: campus name appears in the building info popup',
        (tester) async {
      await pumpApp(tester);
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final sgwBuilding = buildings.firstWhere((b) => b.campus == Campus.sgw);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateBuildingTap(sgwBuilding);
      await tester.pumpAndSettle();
      await pause(2); // observe campus name in popup

      expect(find.textContaining('SGW'), findsWidgets,
          reason: 'Campus name must be shown in the building info popup');
      await pause(2);
    },
  );

  // ─── Loyola building ──────────────────────────────────────────────────────────

  testWidgets(
    'US-1.5: tapping a Loyola building (while on Loyola) opens its detail sheet',
        (tester) async {
      await pumpApp(tester);
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateCampusChange(Campus.loyola);
      await tester.pumpAndSettle();
      await pause(2); // observe campus switch to Loyola

      (state as HomeScreenState).handleMapTap(polygonCenter(loyolaBuilding.boundary));
      await tester.pumpAndSettle();
      await pause(2); // observe Loyola building detail sheet

      expect(find.textContaining(loyolaBuilding.name), findsOneWidget);
      await pause(2);
    },
  );
}