import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_schedule_entry.dart';

/// Persists a user's saved schedule to Firestore at
/// `users/{uid}/schedule/{docId}`.
class ScheduleRepository {
  final FirebaseFirestore _db;

  ScheduleRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('schedule');

  Future<List<CourseScheduleEntry>> loadEntries(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs
        .map((d) => CourseScheduleEntry.fromMap(d.data()).copyWithId(d.id))
        .toList();
  }

  /// Saves [entry] and returns a copy with the Firestore [id] set.
  Future<CourseScheduleEntry> addEntry(
      String uid, CourseScheduleEntry entry) async {
    final ref = await _col(uid).add(entry.toMap());
    return entry.copyWithId(ref.id);
  }

  Future<void> removeEntry(String uid, String docId) async {
    await _col(uid).doc(docId).delete();
  }
}
