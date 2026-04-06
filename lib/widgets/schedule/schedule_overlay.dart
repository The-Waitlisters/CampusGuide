import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/widgets/schedule/schedule_display.dart';
import 'package:proj/widgets/schedule/schedule_results_list.dart';
import 'package:proj/widgets/schedule/schedule_search_bar.dart';
import '../../services/auth/user_profile_service.dart';
import '../../services/schedule_lookup.dart';

enum _ScheduleTab { search, mySchedule }

class ScheduleOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<CourseScheduleEntry> onRoomSelected;
  final ScheduleLookupService lookupService;
  final String? uid;
  final UserProfileService? profileService;

  const ScheduleOverlay({
    super.key,
    required this.onClose,
    required this.onRoomSelected,
    required this.lookupService,
    this.uid,
    this.profileService,
  });

  @override
  State<ScheduleOverlay> createState() {
    return _ScheduleOverlayState();
  }
}

class _ScheduleOverlayState extends State<ScheduleOverlay> {
  late final TextEditingController _searchController;
  List<CourseScheduleEntry> _filteredEntries = <CourseScheduleEntry>[];
  List<CourseScheduleEntry> _scheduledEntries = <CourseScheduleEntry>[];
  bool _isLoading = false;
  String? _errorMessage;
  _ScheduleTab _activeTab = _ScheduleTab.search;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadSchedule();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToSchedule(CourseScheduleEntry entry) {
    final bool alreadyAdded = _scheduledEntries.any(
          (CourseScheduleEntry e) =>
      e.dayAndTime == entry.dayAndTime && e.room == entry.room,
    );

    if (alreadyAdded) return;

    setState(() {
      _scheduledEntries = [..._scheduledEntries, entry];
    });
    _persistSchedule();
  }

  void _removeFromSchedule(CourseScheduleEntry entry) {
    setState(() {
      _scheduledEntries = _scheduledEntries
          .where(
            (CourseScheduleEntry e) =>
        !(e.dayAndTime == entry.dayAndTime && e.room == entry.room),
      )
          .toList();
    });
    _persistSchedule();
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

  Future<void> _loadSchedule() async {
    final uid = widget.uid;
    if (uid == null) return;

    final entries = await (widget.profileService ?? UserProfileService())
        .loadSchedule(uid: uid);

    if (!mounted) return;
    setState(() => _scheduledEntries = entries);
  }

  Future<void> _persistSchedule() async {
    final uid = widget.uid;
    if (uid == null) return;

    await (widget.profileService ?? UserProfileService())
        .saveSchedule(uid: uid, entries: _scheduledEntries);
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
                Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Search',
                        isActive: _activeTab == _ScheduleTab.search,
                        onTap: () =>
                            setState(() => _activeTab = _ScheduleTab.search),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TabButton(
                        label: _scheduledEntries.isEmpty
                            ? 'My Schedule'
                            : 'My Schedule (${_scheduledEntries.length})',
                        isActive: _activeTab == _ScheduleTab.mySchedule,
                        onTap: () => setState(
                              () => _activeTab = _ScheduleTab.mySchedule,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_activeTab == _ScheduleTab.search) ...[
                  ScheduleSearchBar(
                    controller: _searchController,
                    onChanged: _searchCourses,
                    onSubmitted: _searchCourses,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
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
                        onResultTap: widget.onRoomSelected,
                        onAddToSchedule: _addToSchedule,
                      ),
                    ),
                ] else
                  Expanded(
                    child: ScheduleDisplay(
                      entries: _scheduledEntries,
                      onRemove: _removeFromSchedule,
                      onRoomTap: widget.onRoomSelected,
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

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFC0392B) : Colors.white,
          border: Border.all(color: const Color(0xFFC0392B)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFFC0392B),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}