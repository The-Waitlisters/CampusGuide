import 'package:flutter/material.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/widgets/schedule/schedule_results_list.dart';
import 'package:proj/widgets/schedule/schedule_search_bar.dart';

class ScheduleOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<CourseScheduleEntry> onRoomSelected;

  const ScheduleOverlay({
    super.key,
    required this.onClose,
    required this.onRoomSelected,
  });

  @override
  State<ScheduleOverlay> createState() {
    return _ScheduleOverlayState();
  }
}

class _ScheduleOverlayState extends State<ScheduleOverlay> {
  late final TextEditingController _searchController;
  late final List<CourseScheduleEntry> _allEntries;
  List<CourseScheduleEntry> _filteredEntries = <CourseScheduleEntry>[];

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();

    _allEntries = <CourseScheduleEntry>[
      const CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LEC H',
        dayText: 'Mon - Wed',
        timeText: '8h45 to 10h15',
        room: 'H935',
        campus: 'SGW',
        buildingCode: 'H',
      ),
      const CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LAB X',
        dayText: 'Fri',
        timeText: '14h45 to 16h25',
        room: 'H831',
        campus: 'SGW',
        buildingCode: 'H',
      ),
      const CourseScheduleEntry(
        courseCode: 'SOEN 342',
        section: 'LEC AA',
        dayText: 'Tue',
        timeText: '17h45 to 20h15',
        room: 'H927',
        campus: 'SGW',
        buildingCode: 'H',
      ),
    ];

    _filteredEntries = List<CourseScheduleEntry>.from(_allEntries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterResults(String query) {
    final String normalizedQuery = query
        .toUpperCase()
        .replaceAll(' ', '')
        .trim();

    setState(() {
      if (normalizedQuery.isEmpty) {
        _filteredEntries = List<CourseScheduleEntry>.from(_allEntries);
        return;
      }

      _filteredEntries = _allEntries.where((CourseScheduleEntry entry) {
        final String normalizedCourseCode = entry.courseCode
            .toUpperCase()
            .replaceAll(' ', '');

        return normalizedCourseCode.contains(normalizedQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.25),
      child: SafeArea(
        child: Center(
          child: Container(
            width: 460,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            color: const Color(0xFFF5F5F5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ScheduleSearchBar(
                  controller: _searchController,
                  onChanged: _filterResults,
                ),
                const SizedBox(height: 24),
                ScheduleResultsList(
                  results: _filteredEntries,
                  onResultTap: (CourseScheduleEntry entry) {
                    widget.onRoomSelected(entry);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}