// US-4.2: Courses and classrooms successfully fetched from Concordia's Open
//         Data API — Add Course to List for Scheduling

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:proj/firebase_options.dart';
import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/widgets/schedule/schedule_overlay.dart';

import 'helpers.dart';

// A well-known Concordia course that always has scheduled sections with rooms.
const String _kTestCourse = 'SOEN343';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadEnv();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 5));
    await pause(2);
  }

  /// Opens the schedule overlay via the test hook and waits for it to render.
  Future<dynamic> openScheduleOverlay(WidgetTester tester) async {
    final dynamic state = tester.state(find.byType(HomeScreen));
    state.setShowScheduleOverlayForTest(true);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(1);
    expect(find.byType(ScheduleOverlay), findsOneWidget,
        reason: 'ScheduleOverlay must be visible after setShowScheduleOverlayForTest(true)');
    return state;
  }

  // ─── AC: Courses fetched from the Concordia Open Data API ────────────────────

  testWidgets(
    'US-4.2: searching a valid course code returns schedule results from the API',
    (tester) async {
      await pumpApp(tester);
      await openScheduleOverlay(tester);

      // Type a course code into the search bar
      await tester.enterText(find.byKey(const Key('schedule_search_field')), _kTestCourse);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // Wait for the real HTTP call to the Concordia Open Data API
      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2); // observe results

      // The results list headers must appear
      expect(find.text('Day and Time'), findsOneWidget,
          reason: 'Results list must show the "Day and Time" column header');
      expect(find.text('Room'), findsOneWidget,
          reason: 'Results list must show the "Room" column header');

      // At least one result tile with day/time text must be visible
      expect(
        find.byType(ListTile).evaluate().isNotEmpty ||
            find.byKey(const Key('add_course_button')).evaluate().isNotEmpty,
        isTrue,
        reason: 'At least one schedule entry must be returned for $_kTestCourse',
      );
      await pause(2);
    },
  );

  // ─── AC: Add Course to List for Scheduling ────────────────────────────────────

  testWidgets(
    'US-4.2: tapping + on a search result adds it to the My Schedule list',
    (tester) async {
      await pumpApp(tester);
      await openScheduleOverlay(tester);

      // Search for the course
      await tester.enterText(find.byKey(const Key('schedule_search_field')), _kTestCourse);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // Wait for results to load
      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2); // observe results before adding

      // Tap the first "+ Add" button to add the top entry to the schedule
      final addButtons = find.byKey(const Key('add_course_button'));
      expect(addButtons, findsWidgets,
          reason: 'At least one + button must be shown in the results list');

      await tester.tap(addButtons.first);
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe My Schedule section appearing

      // The "My Schedule" section header must appear in the overlay
      expect(find.text('My Schedule'), findsOneWidget,
          reason: 'My Schedule section must appear after adding a course');

      // The course code must appear in the schedule display
      expect(find.textContaining('SOEN 343'), findsWidgets,
          reason: 'The added course must appear in the My Schedule list');

      await pause(2);
    },
  );

  // ─── AC: Remove a course from the schedule list ───────────────────────────────

  testWidgets(
    'US-4.2: tapping the remove button takes the course off the My Schedule list',
    (tester) async {
      await pumpApp(tester);
      await openScheduleOverlay(tester);

      // Search and add a course
      await tester.enterText(find.byKey(const Key('schedule_search_field')), _kTestCourse);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2);

      await tester.tap(find.byKey(const Key('add_course_button')).first);
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe added course

      expect(find.text('My Schedule'), findsOneWidget);

      // Tap the remove (−) button in the ScheduleDisplay
      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe course removed

      // The My Schedule section must disappear when the list is empty
      expect(find.text('My Schedule'), findsNothing,
          reason: 'My Schedule section must hide when all courses are removed');

      await pause(2);
    },
  );

  // ─── AC: Multiple courses can be added ───────────────────────────────────────

  testWidgets(
    'US-4.2: multiple entries from the same course can be added to the schedule',
    (tester) async {
      await pumpApp(tester);
      await openScheduleOverlay(tester);

      await tester.enterText(find.byKey(const Key('schedule_search_field')), _kTestCourse);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2);

      final addButtons = find.byKey(const Key('add_course_button'));
      final count = addButtons.evaluate().length;

      if (count >= 2) {
        // Add the first two entries
        await tester.tap(addButtons.at(0));
        await pumpFor(tester, const Duration(milliseconds: 300));
        await tester.tap(addButtons.at(1));
        await pumpFor(tester, const Duration(milliseconds: 300));
        await pause(2); // observe two entries in My Schedule

        expect(
          find.descendant(
            of: find.byType(Scrollbar),
            matching: find.byIcon(Icons.remove_circle_outline),
          ).evaluate().length,
          greaterThanOrEqualTo(2),
          reason: 'Both added entries must appear in the My Schedule list',
        );
      }

      await pause(2);
    },
  );
}
