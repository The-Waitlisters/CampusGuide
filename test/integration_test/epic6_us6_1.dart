// US-6.1: Outdoor points of interest near the user are displayed.
//         Distances are computed from the user's location to each POI.
//         Two filter modes: show nearest X (count) and show within range (km).
//         UI controls provided for X and range.
//         Results are shown as a list sorted nearest-first.
//         When GPS is unavailable the campus centre is used as the fallback.
//
// Uses the real HomeScreen (Google Map + live building data).
// No mocked POIs — real Google Places API is called after the user configures
// the filter and taps Apply, exactly as in normal app usage.
//
// Flow:
//   1. App launches → map renders with SGW campus buildings
//   2. User taps the "Points of Interest" FAB → PoiOptionMenu appears
//   3. User inspects nearest-X and distance sliders, selects a category
//   4. User taps Apply → real Google Places API called
//   5. User taps "Show results" → Results panel appears

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/widgets/home/results.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-6.1: map loads → POI FAB opens filter menu → '
    'nearest-X and distance sliders visible → category selected → '
    'Apply fetches real POIs → Show results displays results panel',
    (tester) async {
      await loadEnv();

      // ── 1. Launch the real app with HomeScreen ────────────────────────────────
      await tester.pumpWidget(
        CampusGuideApp(
          home: HomeScreen(
            testMapControllerCompleter: Completer<GoogleMapController>(),
            // SGW campus centre — so the Places API searches in Montreal,
            // not at LatLng(0,0) which is the default when GPS is unavailable.
            testStartLocation: const LatLng(45.4972, -73.5785),
          ),
        ),
      );

      // Initial pump: let the widget tree build and _initDependencies() fire.
      await pumpFor(tester, const Duration(seconds: 3));

      // Get state reference — same ritual as epic1/2 tests.
      // ignore: unused_local_variable
      final dynamic state = tester.state(find.byType(HomeScreen));

      // Wait for buildings to load from JSON and polygons to be built.
      await pumpFor(tester, const Duration(seconds: 5));

      // Give the native Google Maps Android view time to render map tiles.
      await pause(4); // observe the campus map with building outlines

      // ─── AC: Map is loaded and campus UI is visible ──────────────────────────

      expect(
        find.byKey(const Key('campus_toggle')),
        findsOneWidget,
        reason: 'Campus toggle must be visible — map has loaded',
      );
      expect(
        find.text('SGW'),
        findsOneWidget,
        reason: 'SGW campus label must be shown on launch',
      );
      await pause(1);

      // ─── AC: "Points of Interest" FAB is visible on the map screen ───────────

      expect(
        find.text('Points of Interest'),
        findsOneWidget,
        reason: '"Points of Interest" FAB must be visible on the map screen',
      );
      await pause(1);

      // ── 2. Open the POI filter menu ───────────────────────────────────────────

      await tester.tap(find.text('Points of Interest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe the filter panel opening

      // ─── AC: PoiOptionMenu appears with a clear header ───────────────────────

      expect(
        find.text('Points of interest filter'),
        findsOneWidget,
        reason: 'Filter panel must appear after tapping the POI FAB',
      );

      // ── 3. Verify the nearest-X and distance sliders ──────────────────────────
      //
      // AC: UI controls provided for X (count) and range (km).

      expect(
        find.text('Set nearby points of interest per selected category'),
        findsOneWidget,
        reason: '"Nearest X" count-slider section must be labelled',
      );
      expect(
        find.text('Set radius (km)'),
        findsOneWidget,
        reason: '"Within range" distance-slider section must be labelled',
      );

      // Both controls must be Slider widgets so the user can drag them.
      expect(
        find.byType(Slider),
        findsNWidgets(2),
        reason: 'Two sliders must be present: one for count, one for radius',
      );
      await pause(1);

      // ─── AC: Category checkboxes present ─────────────────────────────────────

      expect(find.text('Restaurants'), findsOneWidget,
          reason: 'Restaurants category checkbox must be present');
      expect(find.text('Cafes'),       findsOneWidget,
          reason: 'Cafes category checkbox must be present');
      expect(find.text('Parks'),       findsOneWidget,
          reason: 'Parks category checkbox must be present');
      expect(find.text('Parking'),     findsOneWidget,
          reason: 'Parking category checkbox must be present');
      expect(find.text('Fast Food'),   findsOneWidget,
          reason: 'Fast Food category checkbox must be present');
      expect(find.text('Night Clubs'), findsOneWidget,
          reason: 'Night Clubs category checkbox must be present');

      // ─── AC: Sort and action buttons present ──────────────────────────────────

      expect(find.text('Sort by'),      findsOneWidget,
          reason: '"Sort by" section must be labelled');
      expect(find.text('Apply'),        findsOneWidget,
          reason: 'Apply button must be present');
      expect(find.text('Reset'),        findsOneWidget,
          reason: 'Reset button must be present');
      expect(find.text('Show results'), findsOneWidget,
          reason: '"Show results" button must be present');
      await pause(1);

      // ── 4. Select a category and configure sliders ───────────────────────────
      //
      // Checkboxes are standalone Checkbox widgets (not CheckboxListTile), so
      // we tap the Checkbox widget itself — tapping the adjacent text does nothing.
      // Slider[0] = nearbyCount (max 20, 5 divisions), Slider[1] = distance (max 5 km).

      // Tick the "Restaurants" checkbox — it is the first Checkbox in the tree.
      await tester.tap(find.byType(Checkbox).first);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe Restaurants checkbox checked

      // Move "nearby count" slider to ~60 % of its track → snaps to ≈ 12 results.
      final Rect nearbySliderRect =
          tester.getRect(find.byType(Slider).first);
      await tester.tapAt(Offset(
        nearbySliderRect.left + nearbySliderRect.width * 0.6,
        nearbySliderRect.center.dy,
      ));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe nearby-count slider moved

      // Move "distance" slider to ~40 % of its track → snaps to ≈ 2 km radius.
      final Rect distanceSliderRect =
          tester.getRect(find.byType(Slider).last);
      await tester.tapAt(Offset(
        distanceSliderRect.left + distanceSliderRect.width * 0.4,
        distanceSliderRect.center.dy,
      ));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe distance slider moved

      // Select "Popularity" from the Sort-by DropdownMenu.
      // The DropdownMenu renders as a text field — tap it to open the menu,
      // then tap the "Popularity" entry that appears in the overlay.
      await tester.tap(find.text('Select...').first);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Popularity').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe Popularity selected

      // Tap Apply — fires the real Google Places API call with selected filters.
      await tester.tap(find.text('Apply'));
      await pumpFor(tester, const Duration(seconds: 5)); // wait for API response
      await pause(2); // observe POI markers appearing on the map

      // ── 5. Show the results panel ─────────────────────────────────────────────

      // "Show results" hides the filter menu and opens the results panel.
      await tester.tap(find.text('Show results'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe the results panel

      // ─── AC: Results panel is displayed ──────────────────────────────────────

      expect(
        find.byType(Results),
        findsOneWidget,
        reason: 'Results panel must appear after tapping "Show results"',
      );

      // ─── AC: List shown when POIs exist; empty state when none ───────────────
      //
      // In a live emulator with a valid API key the Places API returns nearby
      // restaurants; in an offline CI environment it may return nothing.
      // Either outcome is valid — the UI must react correctly to both.

      final hasList  = find.byType(ListView).evaluate().isNotEmpty;
      final hasEmpty = find.text('No matching results').evaluate().isNotEmpty;

      expect(
        hasList || hasEmpty,
        isTrue,
        reason: 'Results panel must show either a POI list or "No matching results"',
      );

      if (hasList) {
        // At least one distance label must appear alongside each POI.
        expect(
          find.textContaining(' m').evaluate().isNotEmpty ||
              find.textContaining('km').evaluate().isNotEmpty,
          isTrue,
          reason: 'Distance to each POI must be shown in the results list',
        );
      }

      await pause(5); // observe results panel for 5 seconds

      // Close the results panel — tap the X button — so the map is visible again.
      await tester.tap(find.byIcon(Icons.close));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(3); // observe the map with POI markers
    },
  );
}
