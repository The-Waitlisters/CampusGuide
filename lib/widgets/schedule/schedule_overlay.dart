import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/widgets/schedule/schedule_results_list.dart';
import 'package:proj/widgets/schedule/schedule_search_bar.dart';
import '../../services/schedule_lookup.dart';

class ScheduleOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<CourseScheduleEntry> onRoomSelected;
  final ScheduleLookupService lookupService;

  const ScheduleOverlay({
    super.key,
    required this.onClose,
    required this.onRoomSelected,
    required this.lookupService,
  });

  @override
  State<ScheduleOverlay> createState() {
    return _ScheduleOverlayState();
  }
}

class _ScheduleOverlayState extends State<ScheduleOverlay> {
  late final TextEditingController _searchController;
  List<CourseScheduleEntry> _filteredEntries = <CourseScheduleEntry>[];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchCourses(String query) async {
    final String trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _filteredEntries = <CourseScheduleEntry>[];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<CourseScheduleEntry> results =
      await widget.lookupService.searchCourse(trimmed);

      if (!mounted) return;

      setState(() {
        _filteredEntries = results;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Schedule lookup failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (kIsWeb) {
        debugPrint(
          'Running in browser — if this is a CORS error, re-run with:\n'
              'flutter run -d chrome --web-browser-flag "--disable-web-security"',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _filteredEntries = <CourseScheduleEntry>[];
        _isLoading = false;
        _errorMessage = 'Could not load course schedule.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      child: SafeArea(
        child: Center(
          child: Container(
            width: 460,
            height: MediaQuery.of(context).size.height * 0.75,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            color: const Color(0xFFF5F5F5),
            child: Column(
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
                  onChanged: (String value) {
                    _searchCourses(value);
                  },
                  onSubmitted: (String value) {
                    _searchCourses(value);
                  },
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ScheduleResultsList(
                      results: _filteredEntries,
                      onResultTap: (CourseScheduleEntry entry) {
                        widget.onRoomSelected(entry);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}