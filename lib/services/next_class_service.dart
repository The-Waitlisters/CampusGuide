import '../models/course_schedule_entry.dart';

/// Finds the next upcoming class from a list of schedule entries.
///
/// "Upcoming" means: the class runs today AND its start time is after [now].
/// If multiple entries qualify, the one starting soonest is returned.
class NextClassService {
  const NextClassService._();

  static CourseScheduleEntry? findNext(
    List<CourseScheduleEntry> entries, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final todayAbbr = _dayAbbr(current.weekday);
    final currentMinutes = current.hour * 60 + current.minute;

    CourseScheduleEntry? best;
    int bestMinutes = -1;

    for (final entry in entries) {
      if (!entry.dayText.contains(todayAbbr)) continue;

      final startMinutes = _parseStartMinutes(entry.timeText);
      if (startMinutes == null) continue;
      if (startMinutes <= currentMinutes) continue;

      if (best == null || startMinutes < bestMinutes) {
        best = entry;
        bestMinutes = startMinutes;
      }
    }

    return best;
  }

  static String _dayAbbr(int weekday) {
    switch (weekday) {
      case DateTime.monday:    return 'Mon';
      case DateTime.tuesday:   return 'Tue';
      case DateTime.wednesday: return 'Wed';
      case DateTime.thursday:  return 'Thu';
      case DateTime.friday:    return 'Fri';
      case DateTime.saturday:  return 'Sat';
      case DateTime.sunday:    return 'Sun';
      default:                 return '';
    }
  }

  /// Parses the start time from a string like "16:15 - 17:30"
  /// and returns the total minutes since midnight, or null on failure.
  static int? _parseStartMinutes(String timeText) {
    final parts = timeText.split(' - ');
    if (parts.isEmpty) return null;
    final timeParts = parts[0].trim().split(':');
    if (timeParts.length < 2) return null;
    final hours   = int.tryParse(timeParts[0].trim());
    final minutes = int.tryParse(timeParts[1].trim());
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }
}
