import 'package:flutter_test/flutter_test.dart';
import 'package:proj/data/shuttle_schedule.dart';
import 'package:proj/models/campus.dart';

void main() {
  group('ShuttleScheduleData.departuresFor', () {
    test('returns SGW Mon-Thu list on Monday', () {
      final deps = ShuttleScheduleData.departuresFor(Campus.sgw, DateTime.monday);
      expect(deps, isNotEmpty);
      expect(deps.first, 570); // 09:30
    });

    test('returns SGW Friday list on Friday', () {
      final deps = ShuttleScheduleData.departuresFor(Campus.sgw, DateTime.friday);
      expect(deps, isNotEmpty);
      expect(deps.first, 585); // 09:45
    });

    test('returns Loyola Mon-Thu list on Wednesday', () {
      final deps = ShuttleScheduleData.departuresFor(Campus.loyola, DateTime.wednesday);
      expect(deps, isNotEmpty);
      expect(deps.first, 555); // 09:15
    });

    test('returns Loyola Friday list on Friday', () {
      final deps = ShuttleScheduleData.departuresFor(Campus.loyola, DateTime.friday);
      expect(deps, isNotEmpty);
      expect(deps.first, 555); // 09:15
    });
  });

  group('ShuttleScheduleData.isInService', () {
    // April 4 2026 = Saturday, April 5 2026 = Sunday
    // March 30 2026 = Monday

    test('returns false on Saturday', () {
      final saturday = DateTime(2026, 4, 4, 10, 0);
      expect(saturday.weekday, DateTime.saturday);
      expect(ShuttleScheduleData.isInService(saturday), isFalse);
    });

    test('returns false on Sunday', () {
      final sunday = DateTime(2026, 4, 5, 10, 0);
      expect(sunday.weekday, DateTime.sunday);
      expect(ShuttleScheduleData.isInService(sunday), isFalse);
    });

    test('returns true during service hours on a weekday', () {
      // Monday 10:00 = 600 min; last SGW Mon-Thu departure = 1110 (18:30)
      final monday10am = DateTime(2026, 3, 30, 10, 0);
      expect(monday10am.weekday, DateTime.monday);
      expect(ShuttleScheduleData.isInService(monday10am), isTrue);
    });

    test('returns false before first departure on a weekday', () {
      // Monday 08:00 = 480 min; first SGW Mon-Thu departure = 570 (09:30)
      final monday8am = DateTime(2026, 3, 30, 8, 0);
      expect(monday8am.weekday, DateTime.monday);
      expect(ShuttleScheduleData.isInService(monday8am), isFalse);
    });

    test('returns false after last departure on a weekday', () {
      // Monday 23:00 = 1380 min > 1110 (last departure)
      final mondayEvening = DateTime(2026, 3, 30, 23, 0);
      expect(ShuttleScheduleData.isInService(mondayEvening), isFalse);
    });
  });

  group('ShuttleScheduleData.minutesUntilNextDeparture', () {
    test('returns null on Saturday', () {
      final saturday = DateTime(2026, 4, 4, 10, 0);
      final mins = ShuttleScheduleData.minutesUntilNextDeparture(
        campus: Campus.sgw,
        now: saturday,
      );
      expect(mins, isNull);
    });

    test('returns null on Sunday', () {
      final sunday = DateTime(2026, 4, 5, 10, 0);
      final mins = ShuttleScheduleData.minutesUntilNextDeparture(
        campus: Campus.loyola,
        now: sunday,
      );
      expect(mins, isNull);
    });

    test('returns minutes until next departure when before first departure', () {
      // SGW Monday 09:00 = 540 min; first departure = 570 (09:30) → 30 min wait
      final monday9am = DateTime(2026, 3, 30, 9, 0);
      expect(monday9am.weekday, DateTime.monday);
      final mins = ShuttleScheduleData.minutesUntilNextDeparture(
        campus: Campus.sgw,
        now: monday9am,
      );
      expect(mins, 30);
    });

    test('returns minutes until next departure mid-schedule', () {
      // SGW Monday 10:31 = 631 min; next departure after 630 is 645 → 14 min wait
      final monday1031 = DateTime(2026, 3, 30, 10, 31);
      final mins = ShuttleScheduleData.minutesUntilNextDeparture(
        campus: Campus.sgw,
        now: monday1031,
      );
      expect(mins, 14); // 645 - 631
    });

    test('returns null when past the last departure', () {
      // SGW Monday 19:00 = 1140 min; last SGW Mon-Thu departure = 1110 (18:30)
      final monday7pm = DateTime(2026, 3, 30, 19, 0);
      final mins = ShuttleScheduleData.minutesUntilNextDeparture(
        campus: Campus.sgw,
        now: monday7pm,
      );
      expect(mins, isNull);
    });

    test('returns minutes until next departure for Loyola on Friday', () {
      // Loyola Friday 09:00 = 540 min; first Loyola Friday departure = 555 (09:15) → 15 min
      final friday9am = DateTime(2026, 4, 3, 9, 0);
      expect(friday9am.weekday, DateTime.friday);
      final mins = ShuttleScheduleData.minutesUntilNextDeparture(
        campus: Campus.loyola,
        now: friday9am,
      );
      expect(mins, 15);
    });
  });
}
