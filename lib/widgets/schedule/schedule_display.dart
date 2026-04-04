import 'package:flutter/material.dart';
import 'package:proj/models/course_schedule_entry.dart';

/// Maps abbreviated day names to weekday numbers (DateTime.monday = 1 .. DateTime.sunday = 7).
const _kDayMap = {
  'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4,
  'Fri': 5, 'Sat': 6, 'Sun': 7,
};

/// Returns all weekday numbers covered by [dayText].
/// Handles single days ("Wed") and ranges ("Mon - Fri").
List<int> _parseDays(String dayText) {
  final parts = dayText.split('-').map((s) => s.trim()).toList();
  if (parts.length == 2) {
    final start = _kDayMap[parts[0]];
    final end = _kDayMap[parts[1]];
    if (start != null && end != null) {
      return List.generate(end - start + 1, (i) => start + i);
    }
  }
  final single = _kDayMap[parts[0].trim()];
  return single != null ? [single] : [];
}

/// Parses "HH:mm" into a [Duration] from midnight.
Duration? _parseTime(String t) {
  final trimmed = t.trim();
  final colonIdx = trimmed.indexOf(':');
  if (colonIdx < 0) return null;
  final h = int.tryParse(trimmed.substring(0, colonIdx));
  final m = int.tryParse(trimmed.substring(colonIdx + 1));
  if (h == null || m == null) return null;
  return Duration(hours: h, minutes: m);
}

/// Finds the next upcoming class from [entries] relative to [now].
/// Returns null if nothing is upcoming today.
CourseScheduleEntry? findNextClass(
    List<CourseScheduleEntry> entries, {
      DateTime? now,
    }) {
  final current = now ?? DateTime.now();
  final todayWeekday = current.weekday; // 1=Mon .. 7=Sun
  final currentMinutes = Duration(
    hours: current.hour,
    minutes: current.minute,
  );

  CourseScheduleEntry? best;
  Duration? bestStart;

  for (final entry in entries) {
    if (!entry.hasRoom) continue;
    final days = _parseDays(entry.dayText);
    if (!days.contains(todayWeekday)) continue;

    // timeText is "HH:mm - HH:mm"
    final timeParts = entry.timeText.split('-');
    if (timeParts.isEmpty) continue;
    final start = _parseTime(timeParts[0]);
    if (start == null) continue;

    // Class must not have ended yet (use end time if available)
    Duration? end;
    if (timeParts.length >= 2) end = _parseTime(timeParts[1]);
    final cutoff = end ?? start;
    if (currentMinutes >= cutoff) continue;

    if (bestStart == null || start < bestStart) {
      best = entry;
      bestStart = start;
    }
  }

  return best;
}

class ScheduleDisplay extends StatelessWidget {
  final List<CourseScheduleEntry> entries;
  final ValueChanged<CourseScheduleEntry> onRemove;
  final ValueChanged<CourseScheduleEntry> onRoomTap;

  const ScheduleDisplay({
    super.key,
    required this.entries,
    required this.onRemove,
    required this.onRoomTap,
  });

  static BoxDecoration _containerDecoration(BuildContext context) => BoxDecoration(
    border: Border.all(color: Colors.grey.shade300),
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _containerDecoration(context),
        child: const Text(
          'No courses added yet.\nSearch for a course and tap + to add it.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      );
    }

    // To test with a fake date, replace null with e.g. DateTime(2026, 4, 1, 10, 0)
    const DateTime? testNow = null;
    final nextClass = findNextClass(entries, now: testNow);

    return Column(
      children: [
        // "Navigate to Next Class" button
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: nextClass != null
              ? SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC0392B),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.directions),
              label: Text(
                'Next class: ${nextClass.courseCode}  •  ${nextClass.room}  ${nextClass.timeText}',
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => onRoomTap(nextClass),
            ),
          )
              : Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'No upcoming classes today',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Table
        Expanded(
          child: Container(
            decoration: _containerDecoration(context),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Day and Time',
                          style: TextStyle(
                            color: Color(0xFFC0392B),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Room',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      final CourseScheduleEntry entry = entries[index];
                      final bool isNext = nextClass != null &&
                          entry.room == nextClass.room &&
                          entry.dayAndTime == nextClass.dayAndTime;

                      return Material(
                        color: isNext
                            ? const Color(0xFFFFF3F3)
                            : Colors.transparent,
                        child: InkWell(
                          onTap:
                          entry.hasRoom ? () => onRoomTap(entry) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.displayTitle,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFC0392B),
                                        ),
                                      ),
                                      Text(
                                        entry.dayAndTime,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.room.isEmpty ? 'N/A' : entry.room,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: entry.hasRoom
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => onRemove(entry),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                  ),
                                  color: Colors.grey,
                                  tooltip: 'Remove from schedule',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}