import 'package:gs_mobile/data/br_holidays.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/data/work_schedule.dart';
import 'package:intl/intl.dart';

const weekDayFullLabels = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

const payrollStartDay = 24;
const payrollCloseDay = 23;

/// Folha da GS: do dia 24 ao dia 23 do mês seguinte.
({DateTime from, DateTime to}) payrollPeriodFor(DateTime day) {
  final today = dateOnly(day);
  final from = today.day >= payrollStartDay
      ? DateTime(today.year, today.month, payrollStartDay)
      : DateTime(today.year, today.month - 1, payrollStartDay);
  final to = DateTime(from.year, from.month + 1, payrollCloseDay);
  return (from: from, to: to);
}

const atHomeLabel = 'Em casa';

class HoursDayRow {
  const HoursDayRow({
    required this.date,
    required this.weekdayLabel,
    required this.holiday,
    required this.holidayName,
    required this.place,
    required this.workedMinutes,
    required this.extraMinutes,
    required this.nightMinutes,
    this.overtimePercent,
    this.scheduleLabel = '',
  });

  final DateTime date;
  final String weekdayLabel;
  final bool holiday;
  final String holidayName;
  final String place;
  final int workedMinutes;
  final int extraMinutes;
  final int nightMinutes;
  final double? overtimePercent;
  final String scheduleLabel;

  String get holidayLabel => holiday
      ? (holidayName.isEmpty ? 'Sim' : 'Sim · $holidayName')
      : 'Não';
}

class HoursReport {
  const HoursReport({
    required this.technicianName,
    required this.from,
    required this.to,
    required this.days,
  });

  final String technicianName;
  final DateTime from;
  final DateTime to;
  final List<HoursDayRow> days;

  int get totalWorkedMinutes =>
      days.fold(0, (sum, day) => sum + day.workedMinutes);

  int get totalExtraMinutes =>
      days.fold(0, (sum, day) => sum + day.extraMinutes);

  int get totalNightMinutes =>
      days.fold(0, (sum, day) => sum + day.nightMinutes);
}

List<DateTime> daysInRange(DateTime from, DateTime to) {
  var start = dateOnly(from);
  var end = dateOnly(to);
  if (end.isBefore(start)) {
    final swap = start;
    start = end;
    end = swap;
  }
  final days = <DateTime>[];
  for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
    days.add(day);
    if (days.length >= 400) break;
  }
  return days;
}

/// RDOs do dia que contam horas para o técnico (para o admin acertar o relógio).
List<({SavedOs os, SavedRdo rdo})> rdosForTechnicianDay({
  required String technicianName,
  required Set<String> viewerIds,
  required Iterable<SavedOs> orders,
  required DateTime day,
}) {
  final out = <({SavedOs os, SavedRdo rdo})>[];
  for (final os in orders) {
    if (os.status == OsStatus.rascunho) continue;
    for (final rdo in os.rdos) {
      if (!isSameDay(rdo.date, day)) continue;
      if (!rdoHoursBelongToTechnician(
        os: os,
        rdo: rdo,
        technicianName: technicianName,
        viewerIds: viewerIds,
      )) {
        continue;
      }
      out.add((os: os, rdo: rdo));
    }
  }
  out.sort((a, b) => a.os.number.compareTo(b.os.number));
  return out;
}

HoursReport buildHoursReport({
  required String technicianName,
  required Set<String> viewerIds,
  required Iterable<SavedOs> orders,
  required DateTime from,
  required DateTime to,
  List<WorkSchedulePeriod> schedules = const [],
}) {
  final span = daysInRange(from, to);
  final rows = <HoursDayRow>[];
  for (final day in span) {
    final holiday = brazilHoliday(day);
    final clients = <String>{};
    final dayRdos = <SavedRdo>[];
    for (final os in orders) {
      if (os.status == OsStatus.rascunho) continue;
      SavedRdo? rdo;
      for (final entry in os.rdos) {
        if (isSameDay(entry.date, day)) {
          rdo = entry;
          break;
        }
      }
      if (rdo == null) continue;
      if (!rdoHoursBelongToTechnician(
        os: os,
        rdo: rdo,
        technicianName: technicianName,
        viewerIds: viewerIds,
      )) {
        continue;
      }
      dayRdos.add(rdo);
      final client = os.rdo.client.trim();
      final site = os.rdo.site.trim();
      if (client.isNotEmpty) {
        clients.add(client);
      } else if (site.isNotEmpty) {
        clients.add(site);
      } else {
        clients.add('OS ${os.number}');
      }
    }
    final hours = dayHoursFromRdos(dayRdos);
    clients.removeWhere((item) => item.isEmpty);
    final schedule = scheduleForDay(schedules, day);
    final dayRule = schedule?.ruleForDate(day);
    rows.add(
      HoursDayRow(
        date: day,
        weekdayLabel: weekDayFullLabels[day.weekday - 1],
        holiday: holiday.isHoliday,
        holidayName: holiday.name,
        place: clients.isEmpty
            ? (hours.workedMinutes > 0
                ? 'Campo (sem cliente no cadastro)'
                : atHomeLabel)
            : clients.join(' / '),
        workedMinutes: hours.workedMinutes,
        extraMinutes: extraMinutesForDay(
          workedMinutes: hours.workedMinutes,
          day: day,
          holiday: holiday.isHoliday,
          dailyLimitOverride: dayRule?.limitMinutes,
        ),
        nightMinutes: hours.nightMinutes,
        overtimePercent: dayRule?.overtimePercent,
        scheduleLabel: schedule?.label ?? '',
      ),
    );
  }
  return HoursReport(
    technicianName: technicianName,
    from: span.isEmpty ? dateOnly(from) : span.first,
    to: span.isEmpty ? dateOnly(to) : span.last,
    days: rows,
  );
}

String hoursReportFileStem(HoursReport report) {
  final who = report.technicianName
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
  final fmt = DateFormat('ddMMyy');
  final safe = who.isEmpty ? 'tecnico' : who;
  return 'Horas_${safe}_${fmt.format(report.from)}_${fmt.format(report.to)}';
}

String hoursReportCsv(HoursReport report) {
  final dayFmt = DateFormat('dd/MM/yyyy');
  final lines = <String>[
    'Técnico;${_csv(report.technicianName)}',
    'Período;${dayFmt.format(report.from)};${dayFmt.format(report.to)}',
    '',
    'Data;Dia da semana;Feriado;Cliente;Horas trabalhadas;Horas extras;% extra;Carga;Adicional noturno',
    for (final day in report.days)
      [
        dayFmt.format(day.date),
        _csv(day.weekdayLabel),
        _csv(day.holidayLabel),
        _csv(day.place),
        formatWorkedHours(day.workedMinutes),
        formatWorkedHours(day.extraMinutes),
        day.overtimePercent == null
            ? ''
            : '${day.overtimePercent!.toStringAsFixed(day.overtimePercent! % 1 == 0 ? 0 : 1)}%',
        _csv(day.scheduleLabel),
        formatWorkedHours(day.nightMinutes),
      ].join(';'),
    [
      'Total',
      '',
      '',
      '',
      formatWorkedHours(report.totalWorkedMinutes),
      formatWorkedHours(report.totalExtraMinutes),
      '',
      '',
      formatWorkedHours(report.totalNightMinutes),
    ].join(';'),
  ];
  return '\uFEFF${lines.join('\r\n')}';
}

String _csv(String value) {
  final text = value.replaceAll(';', ',');
  if (text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
