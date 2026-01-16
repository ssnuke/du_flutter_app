import 'package:intl/intl.dart';

class WeekSelection {
  final int year;
  final int week;
  final DateTime start;
  final DateTime end;
  const WeekSelection({
    required this.year,
    required this.week,
    required this.start,
    required this.end,
  });
}

int isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final diff = thursday.difference(
    firstThursday.add(Duration(days: 3 - ((firstThursday.weekday + 6) % 7))),
  );
  return 1 + (diff.inDays ~/ 7);
}

int isoWeekYear(DateTime date) {
  final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
  return thursday.year;
}

DateTime startOfIsoWeek(int isoYear, int isoWeek) {
  final jan4 = DateTime(isoYear, 1, 4);
  final jan4Thursday = jan4.add(Duration(days: 3 - ((jan4.weekday + 6) % 7)));
  final weekStart = jan4Thursday.add(Duration(days: (isoWeek - 1) * 7));
  final monday = weekStart.add(const Duration(days: -3));
  return DateTime(monday.year, monday.month, monday.day);
}

DateTime endOfIsoWeek(int isoYear, int isoWeek) {
  final start = startOfIsoWeek(isoYear, isoWeek);
  final sunday = start.add(const Duration(days: 6));
  return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
}

WeekSelection weekSelection(int isoYear, int isoWeek) {
  return WeekSelection(
    year: isoYear,
    week: isoWeek,
    start: startOfIsoWeek(isoYear, isoWeek),
    end: endOfIsoWeek(isoYear, isoWeek),
  );
}

int isoWeeksInYear(int isoYear) {
  final dec31 = DateTime(isoYear, 12, 31);
  final wd = ((dec31.weekday + 6) % 7) + 1;
  final isLeap = (isoYear % 4 == 0) && ((isoYear % 100 != 0) || (isoYear % 400 == 0));
  return (wd == 4 || (wd == 5 && isLeap)) ? 53 : 52;
}

String fmtYmd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);