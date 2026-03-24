import 'package:flutter/material.dart';
import 'package:proj/models/course_schedule_entry.dart';

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

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: const Text(
          'No courses added yet.\nSearch for a course and tap + to add it.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (BuildContext context, int index) {
                  final CourseScheduleEntry entry = entries[index];

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: entry.hasRoom ? () => onRoomTap(entry) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                entry.dayAndTime,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.35,
                                ),
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
                              icon: const Icon(Icons.remove_circle_outline),
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
          ),
        ],
      ),
    );
  }
}