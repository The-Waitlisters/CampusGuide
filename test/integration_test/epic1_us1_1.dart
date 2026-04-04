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
    await pause(2); // let the emulator visually catch up
  }

  // ─── AC: App loads with a valid default campus ───────────────────────────────

  testWidgets(
    'US-1.1: campus_label E2E widget is present on launch',
        (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('campus_label')), findsOneWidget);
      await pause(2);
    },
  );

  testWidgets(
    'US-1.1: default campus is either sgw or loyola — never invalid',
        (tester) async {
      await pumpApp(tester);
      final hasSgw = find.text('campus:sgw').evaluate().isNotEmpty;
      final hasLoyola = find.text('campus:loyola').evaluate().isNotEmpty;
      expect(hasSgw || hasLoyola, isTrue,
          reason: 'A valid default campus must be shown on launch');
      expect(hasSgw && hasLoyola, isFalse,
          reason: 'Only one campus can be active at a time');
      await pause(2);
    },
  );

  // ─── AC: Campus toggle is visible with both options ──────────────────────────

  testWidgets(
    'US-1.1: campus toggle widget is visible with SGW and Loyola options',
        (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('campus_toggle')), findsOneWidget);
      expect(find.text('SGW'), findsOneWidget);
      expect(find.text('Loyola'), findsOneWidget);
      await pause(2);
    },
  );

  // ─── AC: Switching campus updates the label ──────────────────────────────────

  testWidgets(
    'US-1.1: switching to Loyola updates campus_label to loyola',
        (tester) async {
      await pumpApp(tester);

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.simulateCampusChange(Campus.loyola);
      await tester.pumpAndSettle();
      await pause(2); // observe the campus switch to Loyola

      expect(find.text('campus:loyola'), findsOneWidget);
      await pause(2);
    },
  );

  testWidgets(
    'US-1.1: switching back to SGW updates campus_label to sgw',
        (tester) async {
      await pumpApp(tester);

      final dynamic state = tester.state(find.byType(HomeScreen));

      state.simulateCampusChange(Campus.loyola);
      await tester.pumpAndSettle();
      await pause(2); // observe switch to Loyola

      state.simulateCampusChange(Campus.sgw);
      await tester.pumpAndSettle();
      await pause(2); // observe switch back to SGW

      expect(find.text('campus:sgw'), findsOneWidget);
      await pause(2);
    },
  );

  // ─── AC: Buildings are present on the map after launch ───────────────────────

  testWidgets(
    'US-1.1: building polygons are rendered on the map after launch',
        (tester) async {
      await pumpApp(tester);

      final dynamic state = tester.state(find.byType(HomeScreen));
      expect(
        (state.testPolygons as Set).isNotEmpty,
        isTrue,
        reason: 'At least one campus building polygon must be rendered on the map',
      );
      await pause(2);
    },
  );

  testWidgets(
    'US-1.1: building polygons survive a round-trip campus switch',
        (tester) async {
      await pumpApp(tester);

      final dynamic state = tester.state(find.byType(HomeScreen));

      state.simulateCampusChange(Campus.loyola);
      await tester.pumpAndSettle();
      await pause(2); // observe switch to Loyola

      state.simulateCampusChange(Campus.sgw);
      await tester.pumpAndSettle();
      await pause(2); // observe switch back to SGW

      expect(
        (state.testPolygons as Set).isNotEmpty,
        isTrue,
        reason: 'Polygons must not be lost after switching campus back and forth',
      );
      await pause(2);
    },
  );
}