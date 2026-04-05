import 'package:flutter/material.dart';
import 'package:proj/models/course_schedule_entry.dart';

class ScheduleResultTile extends StatelessWidget {
  final CourseScheduleEntry entry;
  final VoidCallback onTap;
  final VoidCallback onAddToSchedule;

  const ScheduleResultTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onAddToSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.hasRoom ? onTap : null,
        borderRadius: BorderRadius.circular(8),
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
                    color: entry.hasRoom ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              IconButton(
                onPressed: onAddToSchedule,
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFFC0392B),
                tooltip: 'Add to schedule',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}