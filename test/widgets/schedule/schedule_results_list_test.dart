import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/widgets/schedule/schedule_results_list.dart';

void main() {
  CourseScheduleEntry buildEntry(String code, String room) {
    return CourseScheduleEntry(
      courseCode: code,
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
        body: SizedBox(
          height: 500,
          child: child,
        ),
      ),
    );
  }

  testWidgets('shows empty state when results are empty', (tester) async {
    await tester.pumpWidget(
      wrap(
        ScheduleResultsList(
          results: const <CourseScheduleEntry>[],
          onResultTap: (_) {},
          onAddToSchedule: (CourseScheduleEntry value) {  },
        ),
      ),
    );

    expect(find.text('No schedule results yet.'), findsOneWidget);
    expect(find.text('Day and Time'), findsNothing);
  });

  testWidgets('shows header and list items when results exist', (tester) async {
    final results = <CourseScheduleEntry>[
      buildEntry('SOEN 363', 'H-937'),
      buildEntry('COMP 248', 'H-831'),
    ];

    await tester.pumpWidget(
      wrap(
        ScheduleResultsList(
          results: results,
          onResultTap: (_) {},
        ),
      ),
    );

    expect(find.text('Day and Time'), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('H-937'), findsOneWidget);
    expect(find.text('H-831'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('calls onResultTap with tapped entry', (tester) async {
    final entry = buildEntry('SOEN 363', 'H-937');
    CourseScheduleEntry? tapped;

    await tester.pumpWidget(
      wrap(
        ScheduleResultsList(
          results: <CourseScheduleEntry>[entry],
          onResultTap: (value) {
            tapped = value;
          },
        ),
      ),
    );

    await tester.tap(find.text('H-937'));
    await tester.pump();

    expect(tapped, same(entry));
  });
}