import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/services/concordia_api.dart';
import 'package:proj/services/schedule_lookup.dart';

import 'schedule_lookup_test.mocks.dart';

@GenerateMocks([ConcordiaApiService])
void main() {
  late MockConcordiaApiService mockApi;
  late ScheduleLookupService service;

  setUp(() {
    mockApi = MockConcordiaApiService();
    service = ScheduleLookupService(
      api: mockApi,
    );
  });

  group('ScheduleLookupService.searchCourse', () {
    test('returns empty list for invalid query', () async {
      final List<CourseScheduleEntry> result = await service.searchCourse('hello world');

      expect(result, isEmpty);
      verifyNever(mockApi.fetchSchedule(
        subject: anyNamed('subject'),
        catalog: anyNamed('catalog'),
      ));
    });

    test('parses valid query with spaces and lowercase', () async {
      when(mockApi.fetchSchedule(
        subject: 'SOEN',
        catalog: '363',
      )).thenAnswer((_) async => <dynamic>[]);

      final List<CourseScheduleEntry> result = await service.searchCourse('  soen   363  ');

      expect(result, isEmpty);
      verify(mockApi.fetchSchedule(
        subject: 'SOEN',
        catalog: '363',
      )).called(1);
    });

    test('maps API result into CourseScheduleEntry', () async {
      when(mockApi.fetchSchedule(
        subject: 'SOEN',
        catalog: '363',
      )).thenAnswer((_) async => <dynamic>[
        <String, dynamic>{
          'subject': 'SOEN',
          'catalog': '363',
          'section': 'H',
          'componentCode': 'LEC',
          'roomCode': 'H-937',
          'buildingCode': 'H',
          'room': '937',
          'locationCode': 'SGW',
          'classStartTime': '8.45',
          'classEndTime': '10.00',
          'mondays': 'Y',
          'tuesdays': 'N',
          'wednesdays': 'Y',
          'thursdays': 'N',
          'fridays': 'N',
          'saturdays': 'N',
          'sundays': 'N',
        },
      ]);

      final List<CourseScheduleEntry> result = await service.searchCourse('SOEN 363');

      expect(result, hasLength(1));

      final CourseScheduleEntry entry = result.first;
      expect(entry.courseCode, 'SOEN 363');
      expect(entry.section, 'LEC H');
      expect(entry.dayText, 'Mon - Wed');
      expect(entry.timeText, '08:45 - 10:00');
      expect(entry.room, 'H-937');
      expect(entry.campus, 'SGW');
      expect(entry.buildingCode, 'H');
      expect(entry.rawSource, contains('SOEN'));
    });

    test('uses buildingCode plus room when roomCode is empty', () async {
      when(mockApi.fetchSchedule(
        subject: 'COMP',
        catalog: '248',
      )).thenAnswer((_) async => <dynamic>[
        <String, dynamic>{
          'subject': 'COMP',
          'catalog': '248',
          'section': 'AA',
          'componentCode': 'LAB',
          'roomCode': '',
          'buildingCode': 'H',
          'room': '831',
          'locationCode': 'SGW',
          'classStartTime': '13.15',
          'classEndTime': '15.55',
          'mondays': 'N',
          'tuesdays': 'Y',
          'wednesdays': 'N',
          'thursdays': 'Y',
          'fridays': 'N',
          'saturdays': 'N',
          'sundays': 'N',
        },
      ]);

      final List<CourseScheduleEntry> result = await service.searchCourse('COMP 248');

      expect(result, hasLength(1));
      expect(result.single.room, 'H831');
      expect(result.single.dayText, 'Tue - Thu');
      expect(result.single.timeText, '13:15 - 15:55');
    });

    test('returns empty list when API returns empty list', () async {
      when(mockApi.fetchSchedule(
        subject: 'SOEN',
        catalog: '363',
      )).thenAnswer((_) async => <dynamic>[]);

      final List<CourseScheduleEntry> result = await service.searchCourse('SOEN 363');

      expect(result, isEmpty);
    });

    test('keeps raw time when format has no dot', () async {
      when(mockApi.fetchSchedule(
        subject: 'SOEN',
        catalog: '363',
      )).thenAnswer((_) async => <dynamic>[
        <String, dynamic>{
          'subject': 'SOEN',
          'catalog': '363',
          'section': 'H',
          'componentCode': 'LEC',
          'roomCode': 'H-937',
          'buildingCode': 'H',
          'room': '937',
          'locationCode': 'SGW',
          'classStartTime': '845',
          'classEndTime': '',
          'mondays': 'Y',
          'tuesdays': 'N',
          'wednesdays': 'N',
          'thursdays': 'N',
          'fridays': 'N',
          'saturdays': 'N',
          'sundays': 'N',
        },
      ]);

      final List<CourseScheduleEntry> result = await service.searchCourse('SOEN 363');

      expect(result, hasLength(1));
      expect(result.single.timeText, '845 - ');
    });

    test('returns empty dayText when no day flags are Y', () async {
      when(mockApi.fetchSchedule(
        subject: 'SOEN',
        catalog: '363',
      )).thenAnswer((_) async => <dynamic>[
        <String, dynamic>{
          'subject': 'SOEN',
          'catalog': '363',
          'section': 'H',
          'componentCode': 'LEC',
          'roomCode': 'H-937',
          'buildingCode': 'H',
          'room': '937',
          'locationCode': 'SGW',
          'classStartTime': '8.45',
          'classEndTime': '10.00',
          'mondays': 'N',
          'tuesdays': 'N',
          'wednesdays': 'N',
          'thursdays': 'N',
          'fridays': 'N',
          'saturdays': 'N',
          'sundays': 'N',
        },
      ]);

      final List<CourseScheduleEntry> result = await service.searchCourse('SOEN 363');

      expect(result, hasLength(1));
      expect(result.single.dayText, '');
    });
  });
}