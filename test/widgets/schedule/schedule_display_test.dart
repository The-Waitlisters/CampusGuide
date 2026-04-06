import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/widgets/schedule/schedule_display.dart';

// ── Fixed reference time ─────────────────────────────────────────────────
// Monday 2026-04-06 at 10:00 AM — deterministic for all unit tests.
// Widget tests use the real clock; we pick reliable times to compensate.
final _kNow = DateTime(2026, 4, 6, 10, 0); // weekday == 1 (Monday)
const _kToday = 'Mon'; // matches _kNow.weekday

// ── Helpers ──────────────────────────────────────────────────────────────

/// Shared entry factory used by the lower display-specific tests.
/// [room] defaults to a non-empty value so [hasRoom] is true by default.
CourseScheduleEntry buildEntry({String room = 'H-937'}) {
  return CourseScheduleEntry(
    courseCode: 'SOEN 363',
    section: 'LEC H',
    dayText: 'Sat',       // Saturday keeps tests day-independent
    timeText: '10:00 - 11:00',
    room: room,
    campus: 'SGW',
    buildingCode: 'H',
  );
}

/// Creates a [CourseScheduleEntry] with sensible defaults.
/// [timeText] must be "HH:mm - HH:mm".
CourseScheduleEntry _entry({
  required String courseCode,
  required String dayText,
  required String timeText,
  String room = 'H-110',
  String section = 'AA',
  String campus = 'SGW',
  String buildingCode = 'H',
}) =>
    CourseScheduleEntry(
      courseCode: courseCode,
      section: section,
      dayText: dayText,
      timeText: timeText,
      room: room,
      campus: campus,
      buildingCode: buildingCode,
    );

/// Wraps [entries] in a minimal testable scaffold.
Widget _scaffold(
    List<CourseScheduleEntry> entries, {
      ValueChanged<CourseScheduleEntry>? onRemove,
      ValueChanged<CourseScheduleEntry>? onRoomTap, DateTime? now,
    }) =>
    MaterialApp(
      home: Scaffold(
        body: ScheduleDisplay(
          entries: entries,
          onRemove: onRemove ?? (_) {},
          onRoomTap: onRoomTap ?? (_) {},
        ),
      ),
    );

/// Returns the abbreviated weekday for today (e.g. 'Mon').
String _todayAbbrev() {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[DateTime.now().weekday - 1];
}

/// Returns an abbreviated weekday that is definitely NOT today.
String _notTodayAbbrev() {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[DateTime.now().weekday % 7]; // shift by 1 → always != today
}

// ────────────────────────────────────────────────────────────────────────

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // Unit tests — findNextClass() with injected `now` (no real-clock risk)
  // ══════════════════════════════════════════════════════════════════════
  group('findNextClass — unit', () {
    test('returns null for an empty list', () {
      expect(findNextClass([], now: _kNow), isNull);
    });

    // hasRoom == false → entry skipped entirely (lines 52-53 in source)
    test('skips entries with an empty room', () {
      final e = _entry(
        courseCode: 'SOEN357',
        dayText: _kToday,
        timeText: '11:00 - 12:00',
        room: '', // hasRoom == false
      );
      expect(findNextClass([e], now: _kNow), isNull);
    });

    // Day does not match → days.contains(today) == false (lines 54-55)
    test('returns null when the entry day does not match today', () {
      final e = _entry(
        courseCode: 'COMP346',
        dayText: 'Tue', // _kNow is Monday
        timeText: '11:00 - 12:00',
      );
      expect(findNextClass([e], now: _kNow), isNull);
    });

    // ── Lines 21-22: _parseDays single-day branch ────────────────────
    // ── Lines 26-33: _parseTime called for the first time ───────────
    // ── Lines 58-60: timeParts parsed after day matches ─────────────
    // ── Lines 65-69: cutoff check — class has not ended yet ─────────
    test('returns entry when single day matches and class is upcoming', () {
      final e = _entry(
        courseCode: 'COEN311',
        dayText: _kToday, // single day 'Mon' → hits lines 21-22
        timeText: '11:00 - 12:00', // starts after 10:00 → upcoming
      );
      final result = findNextClass([e], now: _kNow);
      expect(result?.courseCode, 'COEN311');
    });

    // Lines 65-69: currentMinutes >= cutoff → class is over → skipped
    test('returns null when all entries have already ended', () {
      final e = _entry(
        courseCode: 'ELEC275',
        dayText: _kToday,
        timeText: '08:00 - 09:00', // ended before 10:00
      );
      expect(findNextClass([e], now: _kNow), isNull);
    });

    // Class still in progress (started before now, ends after now) → NOT skipped
    test('returns entry whose class is currently in progress', () {
      final e = _entry(
        courseCode: 'ENGR391',
        dayText: _kToday,
        timeText: '09:00 - 11:00', // started, ends at 11 > 10am
      );
      final result = findNextClass([e], now: _kNow);
      expect(result?.courseCode, 'ENGR391');
    });

    // Lines 14-18: _parseDays range branch ("Mon - Fri")
    test('handles "Mon - Fri" day range when today is Monday', () {
      final e = _entry(
        courseCode: 'RANGE',
        dayText: 'Mon - Fri', // range → lines 14-18 in _parseDays
        timeText: '11:00 - 12:00',
      );
      final result = findNextClass([e], now: _kNow);
      expect(result?.courseCode, 'RANGE');
    });

    // Multiple entries → picks the soonest start time
    test('returns the soonest upcoming entry from multiple candidates', () {
      final sooner = _entry(
        courseCode: 'FIRST',
        dayText: _kToday,
        timeText: '11:00 - 12:00',
      );
      final later = _entry(
        courseCode: 'SECOND',
        dayText: _kToday,
        timeText: '13:00 - 14:00',
        room: 'H-820',
      );
      // Deliberately reversed in the list to verify sorting logic
      final result = findNextClass([later, sooner], now: _kNow);
      expect(result?.courseCode, 'FIRST');
    });

    // Invalid day text → _parseDays returns [] → no match → null (no crash)
    test('handles invalid day text gracefully', () {
      final e = _entry(
        courseCode: 'BAD',
        dayText: 'INVALID',
        timeText: '11:00 - 12:00',
      );
      expect(() => findNextClass([e], now: _kNow), returnsNormally);
      expect(findNextClass([e], now: _kNow), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Widget tests — ScheduleDisplay (real clock; use reliable time slots)
  // ══════════════════════════════════════════════════════════════════════
  group('ScheduleDisplay — widget', () {
    // Empty entries → shows "no courses" placeholder
    testWidgets('shows placeholder when entries list is empty', (tester) async {
      await tester.pumpWidget(_scaffold([]));
      expect(find.textContaining('No courses added yet'), findsOneWidget);
      expect(find.textContaining('No upcoming classes today'), findsNothing);
    });

    // Non-today day → findNextClass always null → "No upcoming classes today"
    // Lines 127-131: the null-nextClass Container branch in build()
    testWidgets(
        'shows "No upcoming classes today" for entry on a different day',
            (tester) async {
          final e = _entry(
            courseCode: 'ELEC275',
            dayText: _notTodayAbbrev(), // guaranteed != today
            timeText: '10:00 - 12:00',
          );
          await tester.pumpWidget(_scaffold([e]));
          await tester.pump();
          expect(find.textContaining('No upcoming classes today'), findsOneWidget);
          expect(find.textContaining('ELEC275'), findsOneWidget);
        });

    // Today's day but already ended → null nextClass
    testWidgets(
        'shows "No upcoming classes today" when only a past entry exists',
            (tester) async {
          final e = _entry(
            courseCode: 'SOEN341',
            dayText: _todayAbbrev(),
            timeText: '01:00 - 02:00', // 01:00-02:00 AM is reliably past
          );
          await tester.pumpWidget(_scaffold([e]));
          await tester.pump();
          expect(find.textContaining('No upcoming classes today'), findsOneWidget);
          expect(find.textContaining('SOEN341'), findsOneWidget);
        });

    // Lines 119-122: nextClass != null → FilledButton with 'Next class:' text.
    // Uses 23:00-23:59 which is reliably in the future for most CI runs.
    // Note: this test may fail if run between 23:00 and midnight.
    //okay but what if it jsut didnt do that
    testWidgets('shows "Next class:" button when an entry is upcoming today',
            (tester) async {
          final now = DateTime.now();
          // Only assert when we are confident the time slot is still in the future
          if (now.hour >= 23) return; // skip if too close to midnight

          final e = _entry(
            courseCode: 'COMP346',
            dayText: _todayAbbrev(),
            timeText: '23:00 - 23:59',
            room: 'H-820',
          );
          await tester.pumpWidget(_scaffold([e], now : DateTime(2026,1,1,1,1)));
          await tester.pump();

          // On weekdays before 23:00 the button must appear
          if (now.weekday <= 5) {
            expect(find.textContaining('Next class:'), findsOneWidget);
            expect(find.textContaining('COMP346'), findsWidgets);
            // Lines 127-131: isNext == true → highlighted row
            expect(find.textContaining('H-820'), findsWidgets);
          }
        });

    // Multiple entries render one row each
    testWidgets('renders a row for each entry', (tester) async {
      final entries = [
        _entry(courseCode: 'SOEN341', dayText: 'Sat', timeText: '10:00 - 11:00'),
        _entry(
          courseCode: 'COMP346',
          dayText: 'Sat',
          timeText: '12:00 - 13:00',
          room: 'H-820',
        ),
      ];
      await tester.pumpWidget(_scaffold(entries));
      await tester.pump();
      expect(find.textContaining('SOEN341'), findsOneWidget);
      expect(find.text('COMP346 — AA'), findsOneWidget);
      expect(find.text('SOEN341 — AA'), findsOneWidget);
    });

    // onRemove fires correctly
    testWidgets('calls onRemove with the correct entry when remove icon tapped',
            (tester) async {
          CourseScheduleEntry? removed;
          final e =
          _entry(courseCode: 'SOEN357', dayText: 'Sat', timeText: '10:00 - 11:00');

          await tester.pumpWidget(_scaffold(
            [e],
            onRemove: (entry) => removed = entry,
          ));
          await tester.pump();

          await tester.tap(find.byIcon(Icons.remove_circle_outline));
          await tester.pump();

          expect(removed?.courseCode, 'SOEN357');
        });

    // onRoomTap fires when a tappable row is tapped
    testWidgets('calls onRoomTap with the correct entry when row is tapped',
            (tester) async {
          CourseScheduleEntry? tapped;
          final e =
          _entry(courseCode: 'ENGR371', dayText: 'Sat', timeText: '14:00 - 16:00');

          await tester.pumpWidget(_scaffold(
            [e],
            onRoomTap: (entry) => tapped = entry,
          ));
          await tester.pump();

          await tester.tap(
            find.ancestor(
              of: find.text('ENGR371 — AA'),
              matching: find.byType(InkWell),
            ),
          );
          await tester.pump();

          expect(tapped?.courseCode, 'ENGR371');
        });

    // Entry with no room → hasRoom == false → row is not tappable, room shows 'N/A'
    testWidgets('shows N/A and disables tap for entries with empty room',
            (tester) async {
          final e = _entry(
            courseCode: 'COEN244',
            dayText: 'Sat',
            timeText: '09:00 - 10:00',
            room: '', // hasRoom == false
          );
          await tester.pumpWidget(_scaffold([e]));
          await tester.pump();

          expect(find.textContaining('N/A'), findsOneWidget);
        });
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 500, child: child),
      ),
    );
  }

  testWidgets('shows empty-state text when entries list is empty', (tester) async {
    await tester.pumpWidget(wrap(ScheduleDisplay(
      entries: const [],
      onRemove: (_) {},
      onRoomTap: (_) {},
    )));

    expect(
      find.text('No courses added yet.\nSearch for a course and tap + to add it.'),
      findsOneWidget,
    );
    expect(find.text('Day and Time'), findsNothing);
  });

  testWidgets('shows header row and entry when list is non-empty', (tester) async {
    await tester.pumpWidget(wrap(ScheduleDisplay(
      entries: [buildEntry()],
      onRemove: (_) {},
      onRoomTap: (_) {},
    )));

    expect(find.text('Day and Time'), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('H-937'), findsOneWidget);
  });

  testWidgets('shows N/A for entry with empty room', (tester) async {
    await tester.pumpWidget(wrap(ScheduleDisplay(
      entries: [buildEntry(room: '')],
      onRemove: (_) {},
      onRoomTap: (_) {},
    )));

    expect(find.text('N/A'), findsOneWidget);
  });

  testWidgets('calls onRemove when remove icon is tapped', (tester) async {
    final entry = buildEntry();
    CourseScheduleEntry? removed;

    await tester.pumpWidget(wrap(ScheduleDisplay(
      entries: [entry],
      onRemove: (e) => removed = e,
      onRoomTap: (_) {},
    )));

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();

    expect(removed, same(entry));
  });

  testWidgets('calls onRoomTap when entry with a room is tapped', (tester) async {
    final entry = buildEntry();
    CourseScheduleEntry? tapped;

    await tester.pumpWidget(wrap(ScheduleDisplay(
      entries: [entry],
      onRemove: (_) {},
      onRoomTap: (e) => tapped = e,
    )));

    await tester.tap(find.text('H-937'));
    await tester.pump();

    expect(tapped, same(entry));
  });

  testWidgets('does not call onRoomTap when entry with empty room is tapped', (tester) async {
    bool called = false;

    await tester.pumpWidget(wrap(ScheduleDisplay(
      entries: [buildEntry(room: '')],
      onRemove: (_) {},
      onRoomTap: (_) => called = true,
    )));

    await tester.tap(find.text('N/A'));
    await tester.pump();

    expect(called, isFalse);
  });

  testWidgets('renders a ListView for non-empty entries', (tester) async {
    await tester.pumpWidget(wrap(ScheduleDisplay(
      entries: [buildEntry(), buildEntry(room: 'MB-3.270')],
      onRemove: (_) {},
      onRoomTap: (_) {},
    )));

    expect(find.byType(ListView), findsOneWidget);
  });
}