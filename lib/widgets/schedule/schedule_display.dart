import 'package:flutter/material.dart';

import '../../models/course_schedule_entry.dart';

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
      return const Center(
        child: Text(
          'No courses added yet.\nSearch for a course and tap + to add it.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text('Day and Time', style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 80, child: Text('Room', style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 40),
            ],
          ),
        ),
        const Divider(height: 1),

        // Entry list
        Expanded(
          child: Scrollbar(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final entry = entries[i];
                final roomText = entry.room.isEmpty ? 'N/A' : entry.room;
                final tappable = entry.room.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      // Day/time + course info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.displayTitle),
                            Text(
                              entry.dayAndTime,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      // Room
                      SizedBox(
                        width: 80,
                        child: GestureDetector(
                          onTap: tappable ? () => onRoomTap(entry) : null,
                          child: Text(
                            roomText,
                            style: TextStyle(
                              color: tappable ? Colors.blue : null,
                              decoration: tappable ? TextDecoration.underline : null,
                            ),
                          ),
                        ),
                      ),
                      // Remove button
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => onRemove(entry),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
