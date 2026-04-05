// US-2.4: Directions between SGW and Loyola

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

  late List buildings;

  setUpAll(() async {
    buildings = await DataParser().getBuildingInfoFromJSON();
  });

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

  Future<void> setStartAndDestination(
    WidgetTester tester,
    dynamic state,
    dynamic start,
    dynamic dest,
  ) async {
    state.simulateBuildingTap(start);
    await tester.pumpAndSettle();
    await pause(2);

    await tester.tap(find.text('Set as Start'));
    await tester.pumpAndSettle();
    await pause(2);

    state.simulateBuildingTap(dest);
    await tester.pumpAndSettle();
    await pause(2);

    await tester.tap(find.text('Set as Destination'));
    await tester.pumpAndSettle();
    await pause(2);
  }

  // ─── AC: Same-campus routing works as before ─────────────────────────────────

  testWidgets(
    'US-2.4: same-campus route (SGW → SGW) shows loading or result — not shuttle placeholder',
    (tester) async {
      await pumpApp(tester);
      final sgwBuildings = buildings.where((b) => b.campus == Campus.sgw).toList();

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuildings[0], sgwBuildings[1]);

      expect(
        find.textContaining('SGW ↔ Loyola'),
        findsNothing,
        reason: 'Same-campus route must not show the shuttle/cross-campus message',
      );

      final hasLoading = find.text('Loading directions...').evaluate().isNotEmpty;
      final hasRoute   = find.textContaining(' • ').evaluate().isNotEmpty;
      final hasError   = find.text('Retry').evaluate().isNotEmpty;
      expect(hasLoading || hasRoute || hasError, isTrue,
          reason: 'Same-campus route must show loading, a route summary, or an error');
      await pause(2);
    },
  );

  // ─── AC: SGW → Loyola route is generated ─────────────────────────────────────

  testWidgets(
    'US-2.4: cross-campus route (SGW → Loyola) shows DirectionsCard with both buildings',
    (tester) async {
      await pumpApp(tester);
      final sgwBuilding    = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuilding, loyolaBuilding);

      expect(find.text('Directions'), findsOneWidget,
          reason: 'DirectionsCard must be visible for an SGW → Loyola route');
      expect(
        find.textContaining('Start: ${sgwBuilding.fullName ?? sgwBuilding.name}'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Destination: ${loyolaBuilding.fullName ?? loyolaBuilding.name}'),
        findsOneWidget,
      );
      await pause(2);
    },
  );

  // ─── AC: Loyola → SGW route is generated ─────────────────────────────────────

  testWidgets(
    'US-2.4: cross-campus route (Loyola → SGW) shows DirectionsCard with both buildings',
    (tester) async {
      await pumpApp(tester);
      final sgwBuilding    = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, loyolaBuilding, sgwBuilding);

      expect(find.text('Directions'), findsOneWidget,
          reason: 'DirectionsCard must be visible for a Loyola → SGW route');
      expect(
        find.textContaining('Start: ${loyolaBuilding.fullName ?? loyolaBuilding.name}'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Destination: ${sgwBuilding.fullName ?? sgwBuilding.name}'),
        findsOneWidget,
      );
      await pause(2);
    },
  );

  // ─── AC: UI indicates cross-campus (SGW ↔ Loyola) ────────────────────────────

  testWidgets(
    'US-2.4: SGW → Loyola route shows SGW ↔ Loyola indicator',
    (tester) async {
      await pumpApp(tester);
      final sgwBuilding    = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, sgwBuilding, loyolaBuilding);

      expect(
        find.textContaining('SGW ↔ Loyola'),
        findsOneWidget,
        reason: 'Cross-campus route must show an SGW ↔ Loyola indicator in the UI',
      );
      await pause(2);
    },
  );

  testWidgets(
    'US-2.4: Loyola → SGW route also shows SGW ↔ Loyola indicator',
    (tester) async {
      await pumpApp(tester);
      final sgwBuilding    = buildings.firstWhere((b) => b.campus == Campus.sgw);
      final loyolaBuilding = buildings.firstWhere((b) => b.campus == Campus.loyola);

      final dynamic state = tester.state(find.byType(HomeScreen));
      await setStartAndDestination(tester, state, loyolaBuilding, sgwBuilding);

      expect(
        find.textContaining('SGW ↔ Loyola'),
        findsOneWidget,
        reason: 'Reversed cross-campus route must also show the SGW ↔ Loyola indicator',
      );
      await pause(2);
    },
  );
}