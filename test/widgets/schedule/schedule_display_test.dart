import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/widgets/schedule/schedule_display.dart';

void main() {
  CourseScheduleEntry buildEntry({String room = 'H-937'}) {
    return CourseScheduleEntry(
      courseCode: 'SOEN 363',
      section: 'LEC H',
      dayText: 'Mon - Wed',
      timeText: '08:45 - 10:00',
      room: room,
      campus: 'SGW',
      buildingCode: 'H',
    );
  }

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

  testWidgets('renders a Scrollbar and ListView for non-empty entries', (tester) async {
    await tester.pumpWidget(wrap(ScheduleDisplay(
      entries: [buildEntry(), buildEntry(room: 'MB-3.270')],
      onRemove: (_) {},
      onRoomTap: (_) {},
    )));

    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}