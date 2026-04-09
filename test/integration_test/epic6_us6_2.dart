// US-6.2: Walking route from a user's location to an outdoor POI.
//
// Uses the real HomeScreen (Google Map + live building data + live Places API).
// Mirrors the US-6.1 flow to reach the results panel, then taps the first
// result and sets it as a destination so the Directions API computes a route.
//
// Flow:
//   1. App launches → map renders with SGW campus (testStartLocation = SGW)
//   2. User taps the "Points of Interest" FAB → PoiOptionMenu appears
//   3. User ticks Restaurants, sets sliders, selects Popularity, taps Apply
//   4. Real Places API returns nearby restaurants
//   5. User taps "Show results" → Results panel appears
//   6. User taps the first result → POI detail bottom sheet opens
//   7. User taps "Set as Destination" → Directions API called
//   8. DirectionsCard appears with route summary (duration + distance)

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
    'US-6.2: map loads → POI filter → Apply fetches real POIs → '
    'Show results → tap first result → Set as Destination → '
    'DirectionsCard shows route to POI',
    (tester) async {
      await loadEnv();

      // ── 1. Launch the real app with HomeScreen ────────────────────────────────
      await tester.pumpWidget(
        CampusGuideApp(
          home: HomeScreen(
            testMapControllerCompleter: Completer<GoogleMapController>(),
            // SGW campus centre — so the Places API searches in Montreal.
            testStartLocation: const LatLng(45.4972, -73.5785),
          ),
        ),
      );

      await pumpFor(tester, const Duration(seconds: 3));
      await pumpFor(tester, const Duration(seconds: 5));
      await pause(4); // observe the campus map

      // ─── AC: Map loaded ───────────────────────────────────────────────────────

      expect(find.byKey(const Key('campus_toggle')), findsOneWidget);
      expect(find.text('SGW'), findsOneWidget);
      await pause(1);

      // ── 2. Open the POI filter menu ───────────────────────────────────────────

      expect(find.text('Points of Interest'), findsOneWidget);
      await tester.tap(find.text('Points of Interest'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      expect(
        find.text('Points of interest filter'),
        findsOneWidget,
        reason: 'Filter panel must appear after tapping the POI FAB',
      );

      // ── 3. Configure the filter ───────────────────────────────────────────────

      // Tick the "Restaurants" checkbox (first Checkbox in the tree).
      await tester.tap(find.byType(Checkbox).first);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // Move nearby-count slider to ~60 % → snaps to ≈ 12 results.
      final Rect nearbySliderRect = tester.getRect(find.byType(Slider).first);
      await tester.tapAt(Offset(
        nearbySliderRect.left + nearbySliderRect.width * 0.6,
        nearbySliderRect.center.dy,
      ));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // Move distance slider to ~40 % → snaps to ≈ 2 km radius.
      final Rect distanceSliderRect = tester.getRect(find.byType(Slider).last);
      await tester.tapAt(Offset(
        distanceSliderRect.left + distanceSliderRect.width * 0.4,
        distanceSliderRect.center.dy,
      ));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // Select "Popularity" from the Sort-by DropdownMenu.
      await tester.tap(find.text('Select...').first);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Popularity').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ── 4. Apply → real Places API call ──────────────────────────────────────

      await tester.tap(find.text('Apply'));
      await pumpFor(tester, const Duration(seconds: 5));
      await pause(2);

      // ── 5. Open the results panel ─────────────────────────────────────────────

      await tester.tap(find.text('Show results'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2);

      expect(
        find.byType(Results),
        findsOneWidget,
        reason: 'Results panel must appear after tapping "Show results"',
      );

      final hasList  = find.byType(ListView).evaluate().isNotEmpty;
      final hasEmpty = find.text('No matching results').evaluate().isNotEmpty;
      expect(hasList || hasEmpty, isTrue);

      await pause(3); // observe the results list

      // ── 6. Tap the first result → POI detail bottom sheet ────────────────────
      //
      // Only navigate if there are real results — skip gracefully if the API
      // returned nothing (e.g. offline CI environment).

      if (!hasList) return;

      await tester.tap(find.byType(ListTile).first);
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe the POI detail sheet

      // ─── AC: POI detail sheet opens ───────────────────────────────────────────

      expect(
        find.text('Set as Destination'),
        findsOneWidget,
        reason: '"Set as Destination" must appear in the POI detail sheet',
      );

      // ── 7. Set as Destination → Directions API called ────────────────────────

      await tester.tap(find.text('Set as Destination'));
      await pumpFor(tester, const Duration(seconds: 5)); // wait for route

      // Close the Results panel so the map and DirectionsCard are visible.
      // Use .first — a second Icons.close exists on the DirectionsCard.
      await tester.tap(find.byIcon(Icons.close).first);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe the map with the route polyline

      // ─── AC: DirectionsCard appears with route summary ────────────────────────

      expect(
        find.text('Walk'),
        findsOneWidget,
        reason: 'Walk mode chip must be visible in the DirectionsCard',
      );

      // Duration or distance must appear — confirms route was computed.
      final hasRouteInfo =
          find.textContaining('min').evaluate().isNotEmpty ||
          find.textContaining(' m').evaluate().isNotEmpty ||
          find.textContaining('km').evaluate().isNotEmpty;

      expect(
        hasRouteInfo,
        isTrue,
        reason: 'Route duration or distance must be shown in the DirectionsCard',
      );

      await pause(3); // final visual pause — observe the route on the map
    },
  );
}
