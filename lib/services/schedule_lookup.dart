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
    // coverage:ignore-start
    if (result is! List) {
      return <CourseScheduleEntry>[];
    }
    // coverage:ignore-end

    return result.map<CourseScheduleEntry>((dynamic item) {
      final map = item as Map<String, dynamic>;

      final String subject = _str(map, 'subject');
      final String catalog = _str(map, 'catalog');
      final String section = _str(map, 'section');
      final String componentCode = _str(map, 'componentCode');

      final String roomCode = _str(map, 'roomCode');
      final String buildingCode = _str(map, 'buildingCode');

      final String room = roomCode.isNotEmpty
          ? roomCode
          : '$buildingCode${_str(map, 'room')}'.trim();

      final String campus = _str(map, 'locationCode');

      final String startTime = _formatConcordiaTime(_str(map, 'classStartTime'),);
      final String endTime = _formatConcordiaTime(_str(map, 'classEndTime'),);

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

    if (_str(map, 'mondays') == 'Y') { days.add('Mon'); }
    if (_str(map, 'tuesdays') == 'Y') { days.add('Tue'); }
    if (_str(map, 'wednesdays') == 'Y') { days.add('Wed'); }
    if (_str(map, 'thursdays') == 'Y') { days.add('Thu'); }
    // coverage:ignore-start
    if (_str(map, 'fridays') == 'Y') { days.add('Fri'); }
    if (_str(map, 'saturdays') == 'Y') { days.add('Sat'); }
    if (_str(map, 'sundays') == 'Y') { days.add('Sun'); }
    // coverage:ignore-end

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

  String _str(Map<String, dynamic> map, String key) {
    return '${map[key] ?? ''}'.trim();
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