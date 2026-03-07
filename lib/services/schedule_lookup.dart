import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/services/concordia_api.dart';

class ScheduleLookupService {
  final ConcordiaApiService api;

  const ScheduleLookupService({
    required this.api,
  });

  Future<List<CourseScheduleEntry>> searchCourse(String query) async {
    final parsed = _parseCourseQuery(query);

    if (parsed == null) {
      return <CourseScheduleEntry>[];
    }

    final result = await api.fetchSchedule(
      subject: parsed.subject,
      catalog: parsed.catalog,
    );

    return _mapScheduleResult(result);
  }

  _ParsedCourseQuery? _parseCourseQuery(String query) {
    final normalized = query
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final match = RegExp(r'^([A-Z]{3,4})\s*(\d{3,4})$').firstMatch(normalized);

    if (match == null) {
      return null;
    }

    return _ParsedCourseQuery(
      subject: match.group(1)!,
      catalog: match.group(2)!,
    );
  }

  List<CourseScheduleEntry> _mapScheduleResult(dynamic result) {
    if (result is! List) {
      return <CourseScheduleEntry>[];
    }

    return result.map<CourseScheduleEntry>((dynamic item) {
      final map = item as Map<String, dynamic>;

      final String subject = '${map['subject'] ?? ''}'.trim();
      final String catalog = '${map['catalog'] ?? ''}'.trim();
      final String section = '${map['section'] ?? ''}'.trim();
      final String componentCode = '${map['componentCode'] ?? ''}'.trim();

      final String roomCode = '${map['roomCode'] ?? ''}'.trim();
      final String buildingCode = '${map['buildingCode'] ?? ''}'.trim();
      final String room = roomCode.isNotEmpty
          ? roomCode
          : '${buildingCode}${map['room'] ?? ''}'.trim();

      final String campus = '${map['locationCode'] ?? ''}'.trim();

      final String startTime = _formatConcordiaTime(
        '${map['classStartTime'] ?? ''}',
      );
      final String endTime = _formatConcordiaTime(
        '${map['classEndTime'] ?? ''}',
      );

      return CourseScheduleEntry(
        courseCode: '$subject $catalog',
        section: '$componentCode $section'.trim(),
        dayText: _extractDayText(map),
        timeText: '$startTime - $endTime',
        room: room,
        campus: campus,
        buildingCode: buildingCode,
        rawSource: map.toString(),
      );
    }).toList();
  }

  String _extractDayText(Map<String, dynamic> map) {
    final List<String> days = <String>[];

    if ('${map['modays'] ?? ''}' == 'Y') {
      days.add('Mon');
    }
    if ('${map['tuesdays'] ?? ''}' == 'Y') {
      days.add('Tue');
    }
    if ('${map['wednesdays'] ?? ''}' == 'Y') {
      days.add('Wed');
    }
    if ('${map['thursdays'] ?? ''}' == 'Y') {
      days.add('Thu');
    }
    if ('${map['fridays'] ?? ''}' == 'Y') {
      days.add('Fri');
    }
    if ('${map['saturdays'] ?? ''}' == 'Y') {
      days.add('Sat');
    }
    if ('${map['sundays'] ?? ''}' == 'Y') {
      days.add('Sun');
    }

    return days.join(' - ');
  }

  String _formatConcordiaTime(String raw) {
    final String trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final List<String> parts = trimmed.split('.');

    if (parts.length < 2) {
      return trimmed;
    }

    final String hour = parts[0].padLeft(2, '0');
    final String minute = parts[1].padLeft(2, '0');

    return '$hour:$minute';
  }
}

class _ParsedCourseQuery {
  final String subject;
  final String catalog;

  const _ParsedCourseQuery({
    required this.subject,
    required this.catalog,
  });
}