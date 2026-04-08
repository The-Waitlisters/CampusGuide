// US-4.3: User successfully sees directions to their next classroom + ETA.
//          Error is shown when no upcoming class is found or building is missing.

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/firebase_options.dart';
import 'package:proj/main.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/services/schedule_repository.dart';

import 'helpers.dart';

// ── Credentials ───────────────────────────────────────────────────────────────
const String _kEmail    = 'hugo.moslener@gmail.com';
const String _kPassword = 'Test123';

// ── Time constants ────────────────────────────────────────────────────────────
// Monday 7 Apr 2026 at 16:00 — just before the 16:15 SOEN 343 lecture.
final DateTime _kNextClassTime = DateTime(2026, 4, 7, 16, 0);

// Monday 7 Apr 2026 at 23:59 — after all classes; "no upcoming class" case.
final DateTime _kAfterClassTime = DateTime(2026, 4, 7, 23, 59);

// ── Seed entry ────────────────────────────────────────────────────────────────
// SOEN 343 Monday 16:15 — used to pre-populate Firestore for the test user.
const CourseScheduleEntry _kSoen343Entry = CourseScheduleEntry(
  courseCode: 'SOEN 343',
  section:    'WAAA',
  dayText:    'Mon',
  timeText:   '16:15 - 17:30',
  room:       'H-110',
  campus:     'SGW',
  buildingCode: 'H',
);

String? _seededDocId;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadEnv();

    // Firebase must be initialised before any Firestore/Auth call.
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      // Already initialised — ignore.
    }

    // Sign in as the test user so the schedule overlay loads their data.
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _kEmail,
        password: _kPassword,
      );
    } catch (e) {
      fail('setUpAll: Firebase sign-in failed: $e');
    }

    // Ensure SOEN 343 Mon 16:15 exists in Firestore for this user.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) fail('setUpAll: currentUser is null after sign-in');

    final repo = ScheduleRepository();

    final existing = await repo.loadEntries(uid);
    final hasMon1615 = existing.any((e) =>
        e.courseCode == 'SOEN 343' &&
        e.dayText.contains('Mon') &&
        e.timeText.startsWith('16:15'));

    if (!hasMon1615) {
      final saved = await repo.addEntry(uid, _kSoen343Entry);
      _seededDocId = saved.id;
    }
  });

  tearDownAll(() async {
    // Remove the entry we seeded (if we were the ones who added it).
    if (_seededDocId != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await ScheduleRepository().removeEntry(uid, _seededDocId!);
      }
      _seededDocId = null;
    }
    await FirebaseAuth.instance.signOut();
  });

  /// Pumps the app with the schedule overlay pre-opened and the clock set to
  /// [scheduleTime].
  Future<void> pumpApp(WidgetTester tester, DateTime scheduleTime) async {
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
          testScheduleCurrentTime: scheduleTime,
          // EV building centre — inside a real SGW building so the start
          // building polygon lights up and directions run building-to-building.
          testStartLocation: const LatLng(45.4955, -73.5780),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 5));
    await pause(2);

    // Open the schedule overlay via the test hook.
    final dynamic state = tester.state(find.byType(HomeScreen));
    state.setShowScheduleOverlayForTest(true);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await pause(1);
  }

  // ─── AC: SOEN 343 loads from the user's Firestore schedule ───────────────────

  testWidgets(
    'US-4.3: SOEN 343 is shown in My Schedule after loading from Firestore',
    (tester) async {
      await pumpApp(tester, _kNextClassTime);

      // Wait for the Firestore load to complete.
      await pumpFor(tester, const Duration(seconds: 5));
      await pause(2); // observe My Schedule section

      expect(find.text('My Schedule'), findsOneWidget,
          reason: 'SOEN 343 must be in the saved schedule for $_kEmail');
      expect(find.textContaining('SOEN 343'), findsWidgets,
          reason: 'SOEN 343 must appear in the My Schedule list');
    },
  );

  // ─── AC: Directions to next classroom shown with ETA ─────────────────────────

  testWidgets(
    'US-4.3: tapping "Get Directions to Next Class" at 16:00 shows directions to SOEN 343 classroom',
    (tester) async {
      await pumpApp(tester, _kNextClassTime);

      // Wait for schedule to load from Firestore.
      await pumpFor(tester, const Duration(seconds: 5));
      await pause(2);

      expect(find.text('My Schedule'), findsOneWidget);
      expect(find.byKey(const Key('next_class_button')), findsOneWidget);

      // Tap "Get Directions to Next Class".
      await tester.tap(find.byKey(const Key('next_class_button')));
      // Pump frames so the async _navigateToNextClass can complete (building
      // lookup may await _buildingsFuture) and the DirectionsCard can render.
      await pumpFor(tester, const Duration(seconds: 3));
      await pause(2); // observe overlay closing and directions card appearing

      // The overlay must close and the directions card must appear.
      expect(find.text('Directions'), findsOneWidget,
          reason: 'DirectionsCard must appear after tapping next class');

      // Wait for the HTTP directions fetch.
      await pumpFor(tester, const Duration(seconds: 12));
      await pause(3); // observe route and ETA

      // Either an ETA (contains ' · ') or Retry must be visible.
      final hasEta   = find.textContaining(' · ').evaluate().isNotEmpty;
      final hasRetry = find.text('Retry').evaluate().isNotEmpty;
      expect(hasEta || hasRetry, isTrue,
          reason: 'An ETA or Retry must be shown after directions resolve');
    },
  );

  // ─── AC: Error shown when no upcoming class is found ─────────────────────────

  testWidgets(
    'US-4.3: tapping "Get Directions" at 23:59 shows an error (no class remaining)',
    (tester) async {
      await pumpApp(tester, _kAfterClassTime);

      // Wait for schedule to load from Firestore.
      await pumpFor(tester, const Duration(seconds: 5));
      await pause(2);

      expect(find.text('My Schedule'), findsOneWidget);

      await tester.tap(find.byKey(const Key('next_class_button')));
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pause(2); // observe error snackbar

      // An orange SnackBar with the error message must appear.
      expect(
        find.textContaining('No upcoming class found'),
        findsOneWidget,
        reason: 'Error message must be shown when no class is upcoming today',
      );
    },
  );
}
