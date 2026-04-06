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

  Map<String, dynamic> toJson() => {
    'courseCode': courseCode,
    'section': section,
    'dayText': dayText,
    'timeText': timeText,
    'room': room,
    'campus': campus,
    'buildingCode': buildingCode,
    if (rawSource != null) 'rawSource': rawSource,
  };

  factory CourseScheduleEntry.fromJson(Map<String, dynamic> json) {
    return CourseScheduleEntry(
      courseCode: json['courseCode'] as String,
      section: json['section'] as String,
      dayText: json['dayText'] as String,
      timeText: json['timeText'] as String,
      room: json['room'] as String,
      campus: json['campus'] as String,
      buildingCode: json['buildingCode'] as String,
      rawSource: json['rawSource'] as String?,
    );
  }
}

