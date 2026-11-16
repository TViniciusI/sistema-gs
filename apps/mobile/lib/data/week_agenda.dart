import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/work_hours.dart';
import 'package:gs_mobile/demo/auth.dart';

export 'package:gs_mobile/data/work_hours.dart';

const weeklyLimitMinutes = 44 * 60;

const weekDayLabels = ['SEG.', 'TER.', 'QUA.', 'QUI.', 'SEX.', 'SÁB.', 'DOM.'];

DateTime dateOnly(DateTime day) {
  final local = day.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool isSameDay(DateTime a, DateTime b) => dateOnly(a) == dateOnly(b);

DateTime startOfWeek(DateTime day) {
  final d = dateOnly(day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

List<DateTime> daysOfWeek(DateTime weekStart) {
  final start = dateOnly(weekStart);
  return [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
}

String osAgendaPlace(SavedOs os) {
  final site = os.rdo.site.trim();
  if (site.isNotEmpty) return site;
  return os.rdo.client.trim();
}

class AgendaDayJob {
  const AgendaDayJob({required this.os, this.rdo});

  final SavedOs os;
  final SavedRdo? rdo;

  String get place => osAgendaPlace(os);

  String get who {
    final responsible = rdo?.responsibleName.trim() ?? '';
    if (responsible.isNotEmpty) return responsible;
    return os.technicianLabel;
  }

  int get workedMinutes => rdo == null ? 0 : rdoWorkedMinutes(rdo!);

  int get nightMinutes => rdo == null ? 0 : rdoNightMinutes(rdo!);
}

DateTime? plannedAgendaDay(
  SavedOs os,
  DateTime weekStart, {
  DateTime? now,
}) {
  if (os.status == OsStatus.rascunho) return null;
  if (!os.canFillRdo) return null;
  if (os.rdos.any((entry) => rdoInWeek(entry, weekStart))) return null;
  final start = dateOnly(weekStart);
  final end = start.add(const Duration(days: 7));
  final begins = os.startDay;
  final today = dateOnly(now ?? DateTime.now());
  if (begins.isBefore(start)) {
    if (!today.isBefore(start) && today.isBefore(end)) return today;
    return start;
  }
  if (begins.isBefore(end)) return begins;
  return null;
}

String formatOsDay(DateTime day) {
  final d = dateOnly(day);
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

String osStartLabel(SavedOs os) => 'Início ${formatOsDay(os.startDay)}';

List<SavedOs> rdoTodayOsChoices(
  Iterable<SavedOs> fillable, {
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final started = [
    for (final os in fillable)
      if (!os.startDay.isAfter(today)) os,
  ];
  if (started.isEmpty) return List<SavedOs>.from(fillable);
  var latest = started.first.startDay;
  for (final os in started) {
    if (os.startDay.isAfter(latest)) latest = os.startDay;
  }
  return [
    for (final os in started)
      if (os.startDay == latest) os,
  ];
}

SavedOs? activeOsForRdoToday(
  Iterable<SavedOs> fillable, {
  DateTime? now,
}) {
  final choices = rdoTodayOsChoices(fillable, now: now);
  if (choices.length != 1) return null;
  return choices.first;
}

List<AgendaDayJob> agendaJobsOnDay(
  Iterable<SavedOs> orders,
  DateTime day, {
  DateTime? weekStart,
  DateTime? now,
}) {
  final jobs = <AgendaDayJob>[];
  final start = weekStart ?? startOfWeek(day);
  for (final os in orders) {
    if (os.status == OsStatus.rascunho) continue;
    SavedRdo? rdo;
    for (final entry in os.rdos) {
      if (isSameDay(entry.date, day)) {
        rdo = entry;
        break;
      }
    }
    if (rdo != null) {
      jobs.add(AgendaDayJob(os: os, rdo: rdo));
      continue;
    }
    final planned = plannedAgendaDay(os, start, now: now);
    if (planned != null && isSameDay(planned, day)) {
      jobs.add(AgendaDayJob(os: os));
    }
  }
  return jobs;
}

bool rdoInWeek(SavedRdo rdo, DateTime weekStart) {
  final start = dateOnly(weekStart);
  final end = start.add(const Duration(days: 7));
  final day = dateOnly(rdo.date);
  return !day.isBefore(start) && day.isBefore(end);
}

class TechnicianWeekHours {
  const TechnicianWeekHours({
    required this.name,
    required this.dayMinutes,
    this.nightDayMinutes = const [0, 0, 0, 0, 0, 0, 0],
  });

  final String name;
  final List<int> dayMinutes;
  final List<int> nightDayMinutes;

  int get workedMinutes => dayMinutes.fold(0, (sum, value) => sum + value);

  int get extraMinutes {
    var total = 0;
    for (var i = 0; i < dayMinutes.length; i++) {
      total += extraMinutesForWeekIndex(i, dayMinutes[i]);
    }
    return total;
  }

  int get nightMinutes => nightDayMinutes.fold(0, (sum, value) => sum + value);

  int get sundayMinutes => dayMinutes.length == 7 ? dayMinutes[6] : 0;

  int get weekdayMinutes {
    var total = 0;
    for (var i = 0; i < dayMinutes.length && i < 6; i++) {
      total += dayMinutes[i];
    }
    return total;
  }

  int get daysWorked {
    var count = 0;
    for (var i = 0; i < dayMinutes.length && i < 6; i++) {
      if (dayMinutes[i] > 0) count++;
    }
    return count;
  }

  int get dsrMinutes {
    if (sundayMinutes > 0) return 0;
    if (daysWorked == 0) return 0;
    return (weekdayMinutes / daysWorked).round();
  }

  int get weeklyOvertimeMinutes {
    final extra = workedMinutes - weeklyLimitMinutes;
    return extra < 0 ? 0 : extra;
  }
}

bool technicianLinkedToOs({
  required SavedOs os,
  required Set<String> viewerIds,
  required String nameKey,
}) {
  if (os.isAssignedToAny(viewerIds)) return true;
  if (nameKey.isEmpty) return false;
  for (final part in os.technicianName.split(',')) {
    if (personFirstKey(part) == nameKey) return true;
  }
  return personFirstKey(os.technicianEmail) == nameKey;
}

bool technicianLinkedToRdo(SavedRdo rdo, Set<String> viewerIds) {
  return personMatchesAnyId(rdo.responsibleName, viewerIds);
}

bool rdoHoursBelongToTechnician({
  required SavedOs os,
  required SavedRdo rdo,
  required String technicianName,
  required Set<String> viewerIds,
}) {
  final nameKey = personFirstKey(technicianName);
  // Ausente neste dia (desmarcado no RDO): nunca conta hora — nem se assinou
  // antes ou ainda está destinário da OS.
  for (final absent in rdo.absentNames) {
    if ((nameKey.isNotEmpty && personFirstKey(absent) == nameKey) ||
        personMatchesAnyId(absent, viewerIds)) {
      return false;
    }
  }
  final onOs = technicianLinkedToOs(
    os: os,
    viewerIds: viewerIds,
    nameKey: nameKey,
  );
  final onRdo = technicianLinkedToRdo(rdo, viewerIds);
  // Quem assinou o RDO do dia conta (e não está ausente).
  if (onRdo) return true;
  // Destinário da OS presente neste dia: em equipe o RDO costuma ser de um só,
  // mas quem não foi desmarcado trabalhou aquele dia.
  if (onOs) return true;
  return false;
}

List<TechnicianWeekHours> weekHoursByTechnician({
  required Iterable<SavedOs> orders,
  required DateTime weekStart,
  String? viewerName,
  Set<String> viewerIds = const {},
}) {
  final days = daysOfWeek(weekStart);
  final minutes = <String, List<int>>{};
  final nights = <String, List<int>>{};
  final personal = viewerName?.trim() ?? '';

  void setHours(String name, int index, DayWorkHours hours) {
    final key = name.trim().isEmpty ? 'Equipe' : name.trim();
    minutes.putIfAbsent(key, () => List<int>.filled(7, 0));
    nights.putIfAbsent(key, () => List<int>.filled(7, 0));
    minutes[key]![index] = hours.workedMinutes;
    nights[key]![index] = hours.nightMinutes;
  }

  for (var i = 0; i < days.length; i++) {
    final jobs = agendaJobsOnDay(
      orders,
      days[i],
      weekStart: weekStart,
    );
    if (personal.isNotEmpty) {
      final rdos = [
        for (final job in jobs)
          if (job.rdo != null &&
              rdoHoursBelongToTechnician(
                os: job.os,
                rdo: job.rdo!,
                technicianName: personal,
                viewerIds: viewerIds,
              ))
            job.rdo!,
      ];
      if (rdos.isNotEmpty) {
        setHours(personal, i, dayHoursFromRdos(rdos));
      }
      continue;
    }
    // Equipe: todos os presentes no RDO (não só quem assinou).
    // Antes só entrava job.who (= responsibleName) e sumiam os demais.
    final byWho = <String, List<SavedRdo>>{};
    for (final job in jobs) {
      if (job.rdo == null) continue;
      final rdo = job.rdo!;
      final present = presentTeamForRdo(
        job.os,
        rdo,
        signedBy: rdo.responsibleName,
      );
      for (final raw in present) {
        final name = raw.trim();
        if (name.isEmpty || name == '-') continue;
        byWho.putIfAbsent(name, () => []).add(rdo);
      }
    }
    for (final entry in byWho.entries) {
      setHours(entry.key, i, dayHoursFromRdos(entry.value));
    }
  }
  final rows = [
    for (final entry in minutes.entries)
      TechnicianWeekHours(
        name: entry.key,
        dayMinutes: entry.value,
        nightDayMinutes: nights[entry.key] ?? List<int>.filled(7, 0),
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return rows;
}

List<SavedOs> agendaOrdersFor({
  required Iterable<SavedOs> orders,
  required bool onlyMine,
  required Set<String> viewerIds,
}) {
  if (!onlyMine) {
    return [for (final os in orders) if (os.status != OsStatus.rascunho) os];
  }
  return [
    for (final os in orders)
      if (os.status != OsStatus.rascunho && os.isAssignedToAny(viewerIds)) os,
  ];
}
