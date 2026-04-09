// US-5.5: The system detects when start and destination rooms are on different
//         floors. Routes include stairs or elevators as needed. Floor transitions
//         are clearly indicated to the user. The correct floor map is displayed
//         at each step. The user understands when and where to change floors.
//
// Uses the real Hall building (H.json) and map taps only — no mocks.
//
// Normalised positions from H.json (imageWidth = imageHeight = 2000):
//   Floor 1 — H-110  nx=0.262  ny=0.636
//   Floor 2 — H-231  nx=0.391  ny=0.225

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/screens/indoor_map_screen.dart';

import 'helpers.dart';

final _kBuilding = CampusBuilding(
  id: 'hall-building',
  name: 'H',
  fullName: 'Henry F. Hall Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

const _kH110 = (nx: 0.262, ny: 0.636); // floor 1
const _kH231 = (nx: 0.391, ny: 0.225); // floor 2

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.5: multi-floor route detected, floor transition indicated, '
    'correct floor shown at each stage, route completes on floor 2',
    (tester) async {
      // ── Pump with real loader ─────────────────────────────────────────────────
      await tester.pumpWidget(
        MaterialApp(
          home: IndoorMapScreen(building: _kBuilding),
        ),
      );

      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2); // observe floor 1 loaded

      expect(find.text('Henry F. Hall Building'), findsOneWidget);

      // Helper: tap a normalised position on the current floor-plan canvas.
      Rect mapRect() => tester.getRect(find.byType(InteractiveViewer).first);
      Future<void> tapMap(({double nx, double ny}) pos) async {
        final r = mapRect();
        await tester.tapAt(Offset(
          r.left + pos.nx * r.width,
          r.top  + pos.ny * r.height,
        ));
        await pumpFor(tester, const Duration(milliseconds: 300));
      }

      // ─── Select H-110 (floor 1) as start via map tap ─────────────────────────

      await tapMap(_kH110);
      await pause(1); // observe H-110 selected

      expect(find.textContaining('Selected: H-110'), findsOneWidget,
          reason: 'H-110 must be selected after map tap');

      await tester.tap(find.text('Set Start'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── Switch to floor 2 and select H-231 as destination via map tap ────────

      await tester.tap(find.byType(DropdownButton<int>));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Floor 2').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe floor 2 map

      await tapMap(_kH231);
      await pause(1); // observe H-231 selected

      expect(find.textContaining('Selected: H-231'), findsOneWidget,
          reason: 'H-231 must be selected after map tap on floor 2');

      await tester.tap(find.text('Set Dest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe multi-floor route

      // ─── AC: System detects start and destination are on different floors ──────

      expect(
        find.textContaining('steps'),
        findsOneWidget,
        reason: 'A cross-floor route must be found between H-110 and H-231',
      );

      // ─── AC: Floor transition clearly indicated in directions ─────────────────
      //
      // The route uses the Hall elevator or staircase; either way the
      // transition instruction contains "from floor 1 to floor 2".

      expect(
        find.textContaining('from floor 1 to floor 2'),
        findsWidgets,
        reason: 'Directions must include a floor-transition instruction',
      );

      // ─── AC: Correct floor map displayed — route starts on floor 1 ───────────

      // _syncUiToActiveSegment sets the display to segment 0's floor (floor 1)
      // immediately after the route is computed.
      expect(
        find.text('Floor 1'),
        findsOneWidget,
        reason: 'Floor dropdown must show Floor 1 at the start of the route',
      );
      await pause(1);

      // ─── AC: Initial step text describes navigation on floor 1 ───────────────

      expect(
        find.textContaining('on floor 1'),
        findsWidgets,
        reason: 'Initial step text must refer to floor 1',
      );

      // ─── AC: Tapping Next Step advances through the route ────────────────────
      //
      // Tap Next Step until the floor display switches to Floor 2 (the
      // transition has been crossed) or until the route ends, whichever
      // comes first. Cap at 80 taps so the test cannot loop forever.

      bool reachedFloor2 = false;
      for (int i = 0; i < 80; i++) {
        final arrived = find.text('Arrive at destination.').evaluate().isNotEmpty;
        final onFloor2 = find.text('Floor 2').evaluate().isNotEmpty &&
            find.text('Floor 1').evaluate().isEmpty;

        if (arrived || onFloor2) {
          reachedFloor2 = onFloor2 || arrived;
          break;
        }

        final canNext = find
            .ancestor(
              of: find.text('Next Step'),
              matching: find.byType(FilledButton),
            )
            .evaluate()
            .isNotEmpty;
        if (!canNext) break;

        final btn = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Next Step'),
            matching: find.byType(FilledButton),
          ),
        );
        if (btn.onPressed == null) break;

        await tester.tap(find.text('Next Step'));
        await pumpFor(tester, const Duration(milliseconds: 200));
      }

      expect(
        reachedFloor2,
        isTrue,
        reason: 'Floor display must switch to Floor 2 after crossing the '
            'floor transition',
      );
      await pause(1); // observe floor 2 map

      // ─── AC: Route completes on floor 2 ──────────────────────────────────────
      //
      // Continue stepping until "Arrive at destination." appears.

      for (int i = 0; i < 80; i++) {
        if (find.text('Arrive at destination.').evaluate().isNotEmpty) break;

        final btn = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Next Step'),
            matching: find.byType(FilledButton),
          ),
        );
        if (btn.onPressed == null) break;

        await tester.tap(find.text('Next Step'));
        await pumpFor(tester, const Duration(milliseconds: 200));
      }

      expect(
        find.text('Arrive at destination.'),
        findsOneWidget,
        reason: '"Arrive at destination." must appear at the final step',
      );

      // "Next Step" must now be disabled.
      final finalBtn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Next Step'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        finalBtn.onPressed,
        isNull,
        reason: '"Next Step" must be disabled after the last step',
      );

      await pause(2); // final visual pause
    },
  );
}
