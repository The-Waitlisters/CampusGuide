class CourseScheduleEntry {
  final String? id; // Firestore document ID; null for unsaved entries
  final String courseCode;
  final String section;
  final String dayText;
  final String timeText;
  final String room;
  final String campus;
  final String buildingCode;
  final String? rawSource;

  const CourseScheduleEntry({
    this.id,
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

  CourseScheduleEntry copyWithId(String newId) => CourseScheduleEntry(
        id: newId,
        courseCode: courseCode,
        section: section,
        dayText: dayText,
        timeText: timeText,
        room: room,
        campus: campus,
        buildingCode: buildingCode,
        rawSource: rawSource,
      );

  Map<String, dynamic> toMap() => {
        'courseCode': courseCode,
        'section': section,
        'dayText': dayText,
        'timeText': timeText,
        'room': room,
        'campus': campus,
        'buildingCode': buildingCode,
      };

  factory CourseScheduleEntry.fromMap(Map<String, dynamic> map) =>
      CourseScheduleEntry(
        courseCode: map['courseCode'] as String? ?? '',
        section: map['section'] as String? ?? '',
        dayText: map['dayText'] as String? ?? '',
        timeText: map['timeText'] as String? ?? '',
        room: map['room'] as String? ?? '',
        campus: map['campus'] as String? ?? '',
        buildingCode: map['buildingCode'] as String? ?? '',
      );
}
