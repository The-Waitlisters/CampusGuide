import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/course_schedule_entry.dart';

void main() {
  group('CourseScheduleEntry', () {
    test('dayAndTime combines day and time', () {
      const entry = CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LEC H',
        dayText: 'Mon - Wed',
        timeText: '08:45 - 10:00',
        room: 'H-937',
        campus: 'SGW',
        buildingCode: 'H',
      );

      expect(entry.dayAndTime, 'Mon - Wed • 08:45 - 10:00');
    });

    test('displayTitle returns course code when section is empty', () {
      const entry = CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: '',
        dayText: 'Mon',
        timeText: '08:45 - 10:00',
        room: 'H-937',
        campus: 'SGW',
        buildingCode: 'H',
      );

      expect(entry.displayTitle, 'SOEN 363');
    });

    test('displayTitle returns course code and section when section exists', () {
      const entry = CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LEC H',
        dayText: 'Mon',
        timeText: '08:45 - 10:00',
        room: 'H-937',
        campus: 'SGW',
        buildingCode: 'H',
      );

      expect(entry.displayTitle, 'SOEN 363 — LEC H');
    });

    test('hasRoom is true when room has non-whitespace text', () {
      const entry = CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LEC H',
        dayText: 'Mon',
        timeText: '08:45 - 10:00',
        room: ' H-937 ',
        campus: 'SGW',
        buildingCode: 'H',
      );

      expect(entry.hasRoom, isTrue);
    });

    test('hasRoom is false when room is empty or whitespace', () {
      const entry = CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LEC H',
        dayText: 'Mon',
        timeText: '08:45 - 10:00',
        room: '   ',
        campus: 'SGW',
        buildingCode: 'H',
      );

      expect(entry.hasRoom, isFalse);
    });
  });
}