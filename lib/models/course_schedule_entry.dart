class CourseScheduleEntry {
  final String courseCode;
  final String section;
  final String dayText;
  final String timeText;
  final String room;
  final String campus;
  final String buildingCode;
  final String? rawSource;

  const CourseScheduleEntry({
    required this.courseCode,
    required this.section,
    required this.dayText,
    required this.timeText,
    required this.room,
    required this.campus,
    required this.buildingCode,
    this.rawSource,
  });

  String get dayAndTime {
    return '$dayText • $timeText';
  }

  String get displayTitle {
    if (section.isEmpty) {
      return courseCode;
    }

    return '$courseCode — $section';
  }

  bool get hasRoom {
    return room.trim().isNotEmpty;
  }
}