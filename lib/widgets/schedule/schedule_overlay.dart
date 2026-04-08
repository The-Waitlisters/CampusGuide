import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/services/next_class_service.dart';
import 'package:proj/services/schedule_repository.dart';
import 'package:proj/widgets/schedule/schedule_display.dart';
import 'package:proj/widgets/schedule/schedule_results_list.dart';
import 'package:proj/widgets/schedule/schedule_search_bar.dart';
import '../../services/schedule_lookup.dart';

class ScheduleOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<CourseScheduleEntry> onRoomSelected;
  final ValueChanged<CourseScheduleEntry> onNextClassNavigation;

  /// Called when "Get Directions" is tapped but no upcoming class is found.
  final ValueChanged<String> onNextClassError;

  final ScheduleLookupService lookupService;

  /// Injected repository — defaults to the real Firestore implementation.
  final ScheduleRepository? scheduleRepository;

  /// Injected current time for testing; uses [DateTime.now()] when null.
  final DateTime? testCurrentTime;

  const ScheduleOverlay({
    super.key,
    required this.onClose,
    required this.onRoomSelected,
    required this.onNextClassNavigation,
    required this.onNextClassError,
    required this.lookupService,
    this.scheduleRepository,
    this.testCurrentTime,
  });

  @override
  State<ScheduleOverlay> createState() => _ScheduleOverlayState();
}

class _ScheduleOverlayState extends State<ScheduleOverlay> {
  late final TextEditingController _searchController;
  List<CourseScheduleEntry> _filteredEntries = <CourseScheduleEntry>[];
  final List<CourseScheduleEntry> _addedEntries = <CourseScheduleEntry>[];
  bool _isLoading = false;
  bool _isLoadingSchedule = false;
  String? _errorMessage;

  ScheduleRepository get _repo =>
      widget.scheduleRepository ?? ScheduleRepository();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadSavedEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEntries() async {
    final uid = _uid;
    if (uid == null) return;

    setState(() => _isLoadingSchedule = true);
    try {
      final entries = await _repo.loadEntries(uid);
      if (mounted) {
        setState(() {
          _addedEntries
            ..clear()
            ..addAll(entries);
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSchedule = false);
    }
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

      if (!mounted) return;

      setState(() {
        _filteredEntries = <CourseScheduleEntry>[];
        _isLoading = false;
        _errorMessage = 'Could not load course schedule.';
      });
    }
  }

  Future<void> _addEntry(CourseScheduleEntry entry) async {
    final uid = _uid;
    if (uid != null) {
      final saved = await _repo.addEntry(uid, entry);
      if (mounted) setState(() => _addedEntries.add(saved));
    } else {
      // Guest mode: keep in memory only (no Firestore)
      if (mounted) setState(() => _addedEntries.add(entry));
    }
  }

  Future<void> _removeEntry(CourseScheduleEntry entry) async {
    final uid = _uid;
    if (uid != null && entry.id != null) {
      await _repo.removeEntry(uid, entry.id!);
    }
    if (mounted) setState(() => _addedEntries.remove(entry));
  }

  void _onGetDirectionsToNextClass() {
    final next = NextClassService.findNext(
      _addedEntries,
      now: widget.testCurrentTime,
    );

    if (next == null) {
      widget.onNextClassError(
        'No upcoming class found for today. '
        'Make sure your courses are added to My Schedule.',
      );
    } else {
      widget.onNextClassNavigation(next);
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
                      icon: const Icon(Icons.arrow_back, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ScheduleSearchBar(
                  controller: _searchController,
                  onChanged: _searchCourses,
                  onSubmitted: _searchCourses,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Column(
                    children: [
                      // ── Search results / loading / error ──────────────────
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
                                    color: Colors.red, fontSize: 16),
                              ),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          fit: _addedEntries.isEmpty
                              ? FlexFit.tight
                              : FlexFit.loose,
                          child: ScheduleResultsList(
                            results: _filteredEntries,
                            onResultTap: widget.onRoomSelected,
                            onResultAdd: _addEntry,
                          ),
                        ),

                      // ── My Schedule ───────────────────────────────────────
                      if (_isLoadingSchedule)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_addedEntries.isNotEmpty) ...[
                        const Divider(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'My Schedule',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: ScheduleDisplay(
                            entries: _addedEntries,
                            onRemove: _removeEntry,
                            onRoomTap: widget.onRoomSelected,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            key: const Key('next_class_button'),
                            onPressed: _onGetDirectionsToNextClass,
                            icon: const Icon(Icons.directions),
                            label:
                                const Text('Get Directions to Next Class'),
                          ),
                        ),
                      ],
                    ],
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
