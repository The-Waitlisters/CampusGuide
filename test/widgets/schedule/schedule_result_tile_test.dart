import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/widgets/schedule/schedule_result_tile.dart';

void main() {
  CourseScheduleEntry buildEntry({required String room}) {
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
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders day/time and room', (tester) async {
    await tester.pumpWidget(
      wrap(
        ScheduleResultTile(
          entry: buildEntry(room: 'H-937'),
          onTap: () {},
          onAddToSchedule: () {  },
        ),
      ),
    );

    expect(find.text('Mon - Wed • 08:45 - 10:00'), findsOneWidget);
    expect(find.text('H-937'), findsOneWidget);
  });

  testWidgets('shows N/A when room is empty', (tester) async {
    await tester.pumpWidget(
      wrap(
        ScheduleResultTile(
          entry: buildEntry(room: ''),
          onTap: () {},
          onAddToSchedule: () {  },
        ),
      ),
    );

    expect(find.text('N/A'), findsOneWidget);
  });

  testWidgets('calls onTap when entry has room', (tester) async {
    int tapCount = 0;

    await tester.pumpWidget(
      wrap(
        ScheduleResultTile(
          entry: buildEntry(room: 'H-937'),
          onTap: () {
            tapCount++;
          },
          onAddToSchedule: () {  },
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('does not call onTap when entry has no room', (tester) async {
    int tapCount = 0;

    await tester.pumpWidget(
      wrap(
        ScheduleResultTile(
          entry: buildEntry(room: '   '),
          onTap: () {
            tapCount++;
          },
          onAddToSchedule: () {  },
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();

    expect(tapCount, 0);
  });
}