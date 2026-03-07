import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/services/schedule_lookup.dart';
import 'package:proj/widgets/home/search_overlay.dart';
import 'package:proj/widgets/schedule/schedule_overlay.dart';

import 'schedule_overlay_test.mocks.dart';

@GenerateMocks([ScheduleLookupService])
void main() {
  late MockScheduleLookupService mockLookup;

  setUp(() {
    mockLookup = MockScheduleLookupService();
  });

  CourseScheduleEntry buildEntry() {
    return const CourseScheduleEntry(
      courseCode: 'SOEN 363',
      section: 'LEC H',
      dayText: 'Mon - Wed',
      timeText: '08:45 - 10:00',
      room: 'H-937',
      campus: 'SGW',
      buildingCode: 'H',
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('calls onClose when back button is pressed', (WidgetTester tester) async {
    int closeCount = 0;

    await tester.pumpWidget(
      wrap(
        ScheduleOverlay(
          onClose: () {
            closeCount++;
          },
          onRoomSelected: (_) {},
          lookupService: mockLookup,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(closeCount, 1);
  });

  testWidgets('shows empty state initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        ScheduleOverlay(
          onClose: () {},
          onRoomSelected: (_) {},
          lookupService: mockLookup,
        ),
      ),
    );

    expect(find.text('No schedule results yet.'), findsOneWidget);
  });

  testWidgets('clears results and does not search when query is blank', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        ScheduleOverlay(
          onClose: () {},
          onRoomSelected: (_) {},
          lookupService: mockLookup,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    verifyNever(mockLookup.searchCourse(any));
    expect(find.text('No schedule results yet.'), findsOneWidget);
  });

  testWidgets('shows loading then results on successful search', (WidgetTester tester) async {
    final Completer<List<CourseScheduleEntry>> completer = Completer<List<CourseScheduleEntry>>();

    when(mockLookup.searchCourse('SOEN 363')).thenAnswer((_) {
      return completer.future;
    });

    await tester.pumpWidget(
      wrap(
        ScheduleOverlay(
          onClose: () {},
          onRoomSelected: (_) {},
          lookupService: mockLookup,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'SOEN 363');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(<CourseScheduleEntry>[buildEntry()]);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('H-937'), findsOneWidget);
    verify(mockLookup.searchCourse('SOEN 363')).called(1);
  });

  testWidgets('shows error message when search throws', (WidgetTester tester) async {
    when(mockLookup.searchCourse('SOEN 363')).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      wrap(
        ScheduleOverlay(
          onClose: () {},
          onRoomSelected: (_) {},
          lookupService: mockLookup,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'SOEN 363');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Could not load course schedule.'), findsOneWidget);
  });

  testWidgets('forwards selected room entry through onRoomSelected', (WidgetTester tester) async {
    final CourseScheduleEntry entry = buildEntry();
    CourseScheduleEntry? selected;

    when(mockLookup.searchCourse('SOEN 363')).thenAnswer((_) async {
      return <CourseScheduleEntry>[entry];
    });

    await tester.pumpWidget(
      wrap(
        ScheduleOverlay(
          onClose: () {},
          onRoomSelected: (CourseScheduleEntry value) {
            selected = value;
          },
          lookupService: mockLookup,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'SOEN 363');
    await tester.pumpAndSettle();

    await tester.tap(find.text('H-937'));
    await tester.pump();

    expect(selected, same(entry));
  });

  testWidgets('submits search from keyboard action too', (WidgetTester tester) async {
    when(mockLookup.searchCourse('SOEN 363')).thenAnswer((_) async {
      return <CourseScheduleEntry>[buildEntry()];
    });

    await tester.pumpWidget(
      wrap(
        ScheduleOverlay(
          onClose: () {},
          onRoomSelected: (_) {},
          lookupService: mockLookup,
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'SOEN 363');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    verify(mockLookup.searchCourse('SOEN 363')).called(greaterThanOrEqualTo(1));
  });

  testWidgets('menu button builds schedule item and calls onMenuSelected', (WidgetTester tester) async {
    String? selectedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchOverlay(
            controller: TextEditingController(),
            showResults: false,
            results: const <CampusBuilding>[],
            onChanged: (_) {},
            onClear: () {},
            onMenuSelected: (String value) {
              selectedValue = value;
            },
            onTapField: () {},
            onSelectResult: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsOneWidget);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(selectedValue, 'schedule');
  });
}