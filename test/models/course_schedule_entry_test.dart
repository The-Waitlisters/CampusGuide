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

    test('toJson includes all fields when rawSource is set', () {
      const entry = CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LEC H',
        dayText: 'Mon - Wed',
        timeText: '08:45 - 10:00',
        room: 'H-937',
        campus: 'SGW',
        buildingCode: 'H',
        rawSource: 'some raw html',
      );

      final json = entry.toJson();

      expect(json['courseCode'], 'SOEN 363');
      expect(json['section'], 'LEC H');
      expect(json['dayText'], 'Mon - Wed');
      expect(json['timeText'], '08:45 - 10:00');
      expect(json['room'], 'H-937');
      expect(json['campus'], 'SGW');
      expect(json['buildingCode'], 'H');
      expect(json['rawSource'], 'some raw html');
    });

    test('toJson omits rawSource key when rawSource is null', () {
      const entry = CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LEC H',
        dayText: 'Mon',
        timeText: '08:45 - 10:00',
        room: 'H-937',
        campus: 'SGW',
        buildingCode: 'H',
      );

      expect(entry.toJson().containsKey('rawSource'), isFalse);
    });

    test('fromJson round-trips through toJson', () {
      const original = CourseScheduleEntry(
        courseCode: 'COMP 248',
        section: 'CC',
        dayText: 'Tue - Thu',
        timeText: '13:15 - 14:30',
        room: 'MB-S1.401',
        campus: 'SGW',
        buildingCode: 'MB',
        rawSource: 'raw',
      );

      final decoded = CourseScheduleEntry.fromJson(original.toJson());

      expect(decoded.courseCode, original.courseCode);
      expect(decoded.section, original.section);
      expect(decoded.dayText, original.dayText);
      expect(decoded.timeText, original.timeText);
      expect(decoded.room, original.room);
      expect(decoded.campus, original.campus);
      expect(decoded.buildingCode, original.buildingCode);
      expect(decoded.rawSource, original.rawSource);
    });

    test('fromJson handles missing rawSource (null)', () {
      final json = {
        'courseCode': 'SOEN 363',
        'section': 'LEC H',
        'dayText': 'Mon',
        'timeText': '08:45',
        'room': 'H-937',
        'campus': 'SGW',
        'buildingCode': 'H',
      };

      final entry = CourseScheduleEntry.fromJson(json);
      expect(entry.rawSource, isNull);
    });
  });
}