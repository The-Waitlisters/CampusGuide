// US-5.2: Directions are generated only when both start and destination rooms
//         are selected. The shortest available path is displayed on the indoor
//         map. The route updates automatically when the start or destination
//         room changes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/screens/indoor_map_screen.dart';

import 'helpers.dart';

// ── Real Hall building ─────────────────────────────────────────────────────────
// Uses the real H.json so production routing drives the test.
//
// Normalised positions from H.json (imageWidth = imageHeight = 2000):
//   H-110  nx=0.262  ny=0.636
//   H-112  nx=0.457  ny=0.669
//   H-114  nx=0.454  ny=0.539

final _kBuilding = CampusBuilding(
  id: 'hall-building',
  name: 'H',
  fullName: 'Henry F. Hall Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

const _kH110 = (nx: 0.262, ny: 0.636);
const _kH112 = (nx: 0.457, ny: 0.669);
const _kH114 = (nx: 0.454, ny: 0.539);

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.2: route generated only when both rooms set, path displayed, '
    'updates on start/dest change, clears on Clear',
    (tester) async {
      // ── Pump the screen with the real loader ──────────────────────────────────
      await tester.pumpWidget(
        MaterialApp(
          home: IndoorMapScreen(building: _kBuilding),
        ),
      );

      // Wait for the real JSON asset to load and parse.
      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2); // observe loaded screen

      expect(find.text('Henry F. Hall Building'), findsOneWidget,
          reason: 'AppBar must show the building name');

      // Helper: get the map canvas rect.
      Rect mapRect() =>
          tester.getRect(find.byType(InteractiveViewer).first);

      // Helper: tap at a normalised position on the floor plan.
      Future<void> tapMap(({double nx, double ny}) pos) async {
        final r = mapRect();
        await tester.tapAt(Offset(
          r.left + pos.nx * r.width,
          r.top  + pos.ny * r.height,
        ));
        await pumpFor(tester, const Duration(milliseconds: 300));
      }

      // ─── AC: No directions shown when only the start room is selected ─────────

      await tapMap(_kH110);
      await pause(1); // observe H-110 selected

      expect(find.textContaining('Selected: H-110'), findsOneWidget,
          reason: 'RouteControls must show "Selected: H-110" after map tap');

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe start chip, no route yet

      // Only start is set → neither route steps nor "No route found" must appear.
      expect(
        find.textContaining('steps'),
        findsNothing,
        reason: 'Step count must NOT appear when destination is unset',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear when destination is unset',
      );

      // ─── AC: Route appears once both start and destination are set ────────────

      await tapMap(_kH112);
      await pause(1); // observe H-112 selected

      expect(find.textContaining('Selected: H-112'), findsOneWidget,
          reason: 'RouteControls must show "Selected: H-112" after map tap');

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe the route

      // H-110 → H-112 is routable — a step count must now appear.
      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Step count must appear when a valid route exists',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear for a valid route',
      );

      // ─── AC: Route updates automatically when the start room changes ──────────

      await tapMap(_kH114);
      await pause(1); // observe H-114 selected

      expect(find.textContaining('Selected: H-114'), findsOneWidget,
          reason: 'RouteControls must show "Selected: H-114" after map tap');

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe updated route

      // H-114 → H-112 is also routable — steps must still be shown.
      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Step count must still appear after start changes to H-114',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear for the updated route',
      );

      // The start chip must now identify H-114.
      expect(
        find.textContaining('H-114'),
        findsWidgets,
        reason: 'H-114 must appear in the start chip after being set as start',
      );
      await pause(1);

      // ─── AC: Route updates automatically when the destination room changes ─────

      await tapMap(_kH110);
      await pause(1); // observe H-110 selected

      expect(find.textContaining('Selected: H-110'), findsOneWidget,
          reason: 'RouteControls must show "Selected: H-110" after map tap');

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe updated route

      // H-114 → H-110 is also routable — steps must still show.
      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'Step count must still appear after destination changes to H-110',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must NOT appear for the updated route',
      );

      // The destination chip must now identify H-110.
      expect(
        find.textContaining('H-110'),
        findsWidgets,
        reason: 'H-110 must appear in the destination chip',
      );
      await pause(1);

      // ─── AC: Clearing the route removes the path display ─────────────────────

      await tester.tap(find.byIcon(Icons.close));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe cleared state

      expect(
        find.textContaining('steps'),
        findsNothing,
        reason: 'Step count must disappear after clearing the route',
      );
      expect(
        find.text('No route found'),
        findsNothing,
        reason: '"No route found" must not appear after clearing',
      );

      await pause(1); // final visual pause
    },
  );
}
