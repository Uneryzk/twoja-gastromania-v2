/// Polish public holidays + business-day arithmetic for restaurant review SLAs.
///
/// Excludes Saturdays, Sundays and fixed / movable Polish holidays.
abstract final class PLBusinessDays {
  /// Fixed-date holidays (month, day). Easter-dependent dates are computed separately.
  static const List<(int, int)> fixedHolidays = [
    (1, 1), // Nowy Rok
    (1, 6), // Trzech Króli
    (5, 1), // Święto Pracy
    (5, 3), // Święto Konstytucji 3 Maja
    (8, 15), // Wniebowzięcie NMP
    (11, 1), // Wszystkich Świętych
    (11, 11), // Święto Niepodległości
    (12, 25), // Boże Narodzenie
    (12, 26), // Drugi dzień Świąt
  ];

  /// Easter Sunday (Gregorian / Anonymous Gregorian algorithm).
  static DateTime easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static Set<DateTime> holidaysForYear(int year) {
    final easter = easterSunday(year);
    final dates = <DateTime>{
      for (final (m, d) in fixedHolidays) DateTime(year, m, d),
      easter.add(const Duration(days: 1)), // Poniedziałek Wielkanocny
      easter.add(const Duration(days: 60)), // Boże Ciało
    };
    return dates.map(_dateOnly).toSet();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  static bool isHoliday(DateTime d) {
    final day = _dateOnly(d);
    return holidaysForYear(day.year).contains(day);
  }

  static bool isBusinessDay(DateTime d) => !isWeekend(d) && !isHoliday(d);

  /// Add [n] Polish business days to [from] (skips weekends + holidays).
  static DateTime addBusinessDays(DateTime from, int n) {
    if (n <= 0) return _dateOnly(from);
    var cursor = _dateOnly(from);
    var left = n;
    while (left > 0) {
      cursor = cursor.add(const Duration(days: 1));
      if (isBusinessDay(cursor)) left--;
    }
    return cursor;
  }

  /// Business days from [from] until [to] (0 if [to] is on/before [from]).
  static int businessDaysBetween(DateTime from, DateTime to) {
    var a = _dateOnly(from);
    final b = _dateOnly(to);
    if (!b.isAfter(a)) return 0;
    var n = 0;
    while (a.isBefore(b)) {
      a = a.add(const Duration(days: 1));
      if (isBusinessDay(a)) n++;
    }
    return n;
  }
}
