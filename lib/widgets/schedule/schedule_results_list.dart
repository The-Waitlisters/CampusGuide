import 'package:flutter/material.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/widgets/schedule/schedule_result_tile.dart';

class ScheduleResultsList extends StatelessWidget {
  final List<CourseScheduleEntry> results;
  final ValueChanged<CourseScheduleEntry> onResultTap;

  const ScheduleResultsList({
    super.key,
    required this.results,
    required this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: const Text(
          'No schedule results yet.',
          style: TextStyle(
            fontSize: 16,
          ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade400,
                ),
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
              ],
            ),
          ),
          ...results.map(
                (CourseScheduleEntry entry) {
              return ScheduleResultTile(
                entry: entry,
                onTap: () {
                  onResultTap(entry);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}