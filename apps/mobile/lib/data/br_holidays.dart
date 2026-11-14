import 'package:gs_mobile/data/week_agenda.dart';

class HolidayInfo {
  const HolidayInfo({required this.isHoliday, this.name = ''});

  final bool isHoliday;
  final String name;

  String get label => isHoliday
      ? (name.isEmpty ? 'Sim' : 'Sim · $name')
      : 'Não';
}

DateTime easterSunday(int year) {
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

Map<DateTime, String> brazilHolidaysForYear(int year) {
  final easter = easterSunday(year);
  return {
    DateTime(year, 1, 1): 'Confraternização Universal',
    dateOnly(easter.subtract(const Duration(days: 48))): 'Carnaval',
    dateOnly(easter.subtract(const Duration(days: 47))): 'Carnaval',
    dateOnly(easter.subtract(const Duration(days: 2))): 'Sexta-feira Santa',
    DateTime(year, 4, 21): 'Tiradentes',
    DateTime(year, 5, 1): 'Dia do Trabalho',
    dateOnly(easter.add(const Duration(days: 60))): 'Corpus Christi',
    DateTime(year, 9, 7): 'Independência do Brasil',
    DateTime(year, 10, 12): 'Nossa Senhora Aparecida',
    DateTime(year, 11, 2): 'Finados',
    DateTime(year, 11, 15): 'Proclamação da República',
    DateTime(year, 11, 20): 'Consciência Negra',
    DateTime(year, 12, 25): 'Natal',
  };
}

HolidayInfo brazilHoliday(DateTime day) {
  final date = dateOnly(day);
  final name = brazilHolidaysForYear(date.year)[date];
  if (name == null) return const HolidayInfo(isHoliday: false);
  return HolidayInfo(isHoliday: true, name: name);
}
