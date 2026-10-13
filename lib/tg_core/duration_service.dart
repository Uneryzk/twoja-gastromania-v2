import 'package:twoja_gastromania/tg_core/tg_clock.dart';

/// Day-based duration math in Europe/Warsaw civil time.
///
/// Every paid duration is a whole number of days. "N days" means the same
/// Warsaw wall-clock time N calendar days later, so a 7-day window that crosses
/// the March / October DST switch is 167 h or 169 h long, never off by a day.
///
/// Warsaw follows the EU rule: CEST (UTC+2) from the last Sunday of March
/// 01:00 UTC to the last Sunday of October 01:00 UTC, CET (UTC+1) otherwise.
/// Results are returned as local [DateTime]s (same instants), so existing
/// comparisons and formatting keep working.
class DurationService {
  DurationService._();

  static const String timeZone = 'Europe/Warsaw';

  static DateTime _lastSundayUtc(int year, int month) {
    final last = DateTime.utc(year, month + 1, 0);
    return DateTime.utc(year, month, last.day - (last.weekday % 7));
  }

  /// Warsaw UTC offset at [instant].
  static Duration warsawOffset(DateTime instant) {
    final u = instant.toUtc();
    final dstStart = _lastSundayUtc(u.year, 3).add(const Duration(hours: 1));
    final dstEnd = _lastSundayUtc(u.year, 10).add(const Duration(hours: 1));
    final dst = !u.isBefore(dstStart) && u.isBefore(dstEnd);
    return Duration(hours: dst ? 2 : 1);
  }

  /// Warsaw wall-clock fields of [instant], carried in a UTC-tagged [DateTime]
  /// (only the fields are meaningful).
  static DateTime toWarsawWall(DateTime instant) {
    final u = instant.toUtc();
    return u.add(warsawOffset(u));
  }

  /// Instant for a Warsaw wall-clock time. Non-existent spring-forward times
  /// move forward by the gap; ambiguous autumn times resolve to the first one.
  static DateTime fromWarsawWall(int year, int month, int day, [int hour = 0, int minute = 0, int second = 0]) {
    final wall = DateTime.utc(year, month, day, hour, minute, second);
    for (final h in const [2, 1]) {
      final offset = Duration(hours: h);
      final cand = wall.subtract(offset);
      if (warsawOffset(cand) == offset) return cand.toLocal();
    }
    return wall.subtract(const Duration(hours: 1)).toLocal();
  }

  /// Warsaw midnight of the Warsaw calendar day containing [instant].
  static DateTime dayStart(DateTime instant) {
    final w = toWarsawWall(instant);
    return fromWarsawWall(w.year, w.month, w.day);
  }

  /// Same Warsaw wall-clock time [days] calendar days later (negative = earlier).
  static DateTime addDays(DateTime instant, int days) {
    final w = toWarsawWall(instant);
    final out = fromWarsawWall(w.year, w.month, w.day + days, w.hour, w.minute, w.second)
        .add(Duration(milliseconds: w.millisecond, microseconds: w.microsecond));
    return instant.isUtc ? out.toUtc() : out;
  }

  /// End of a [durationDays]-day period starting at [start].
  static DateTime endOf(DateTime start, int durationDays) => addDays(start, durationDays);

  /// Warsaw calendar dates between [from] and [to] (positive when [to] is later).
  static int calendarDaysBetween(DateTime from, DateTime to) {
    final a = toWarsawWall(from), b = toWarsawWall(to);
    return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }

  /// Whole days left until [endsAt], rounded up; 0 when it has ended.
  static int daysLeft(DateTime endsAt, {DateTime? now}) {
    final t = now ?? TGClock.now();
    if (!endsAt.isAfter(t)) return 0;
    var k = calendarDaysBetween(t, endsAt);
    while (k > 0 && addDays(t, k).isAfter(endsAt)) {
      k--;
    }
    return addDays(t, k).isAtSameMomentAs(endsAt) ? k : k + 1;
  }

  /// Hours left (rounded up, at least 1) while [endsAt] is in the future.
  static int hoursLeft(DateTime endsAt, {DateTime? now}) {
    final t = now ?? TGClock.now();
    final minutes = endsAt.difference(t).inMinutes;
    if (minutes <= 0) return 0;
    return ((minutes + 59) ~/ 60).clamp(1, 24);
  }

  /// True in the final 24 hours before [endsAt].
  static bool endsWithin24h(DateTime endsAt, {DateTime? now}) {
    final t = now ?? TGClock.now();
    return endsAt.isAfter(t) && endsAt.difference(t) <= const Duration(hours: 24);
  }

  /// Warsaw calendar days since [endedAt] (0 = ended today).
  static int daysAgo(DateTime endedAt, {DateTime? now}) {
    final t = now ?? TGClock.now();
    final d = calendarDaysBetween(endedAt, t);
    return d < 0 ? 0 : d;
  }
}
