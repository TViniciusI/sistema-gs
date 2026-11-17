import 'package:gs_mobile/data/br_holidays.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/work_hours.dart';
import 'package:gs_mobile/data/work_schedule.dart';
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
    this.extraDayMinutes,
  });

  final String name;
  final List<int> dayMinutes;
  final List<int> nightDayMinutes;
  final List<int>? extraDayMinutes;

  int get workedMinutes => dayMinutes.fold(0, (sum, value) => sum + value);

  int get extraMinutes {
    final preset = extraDayMinutes;
    if (preset != null) {
      return preset.fold(0, (sum, value) => sum + value);
    }
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
  Map<String, List<WorkSchedulePeriod>> schedulesByName = const {},
  /// Nomes do quadro (StaffStore) para não perder técnico só no e-mail da OS.
  Iterable<String> rosterNames = const [],
}) {
  final days = daysOfWeek(weekStart);
  final minutes = <String, List<int>>{};
  final nights = <String, List<int>>{};
  final personal = viewerName?.trim() ?? '';
  final roster = [
    for (final name in rosterNames)
      if (name.trim().isNotEmpty && name.trim() != '-') name.trim(),
  ];

  void setHours(String name, int index, DayWorkHours hours) {
    final key = name.trim().isEmpty ? 'Equipe' : name.trim();
    minutes.putIfAbsent(key, () => List<int>.filled(7, 0));
    nights.putIfAbsent(key, () => List<int>.filled(7, 0));
    // Soma se a pessoa já tiver horas no mesmo dia (várias OS).
    minutes[key]![index] += hours.workedMinutes;
    nights[key]![index] += hours.nightMinutes;
  }

  List<WorkSchedulePeriod> schedulesOf(String name) {
    final direct = schedulesByName[name];
    if (direct != null) return direct;
    final key = personFirstKey(name);
    if (key.isEmpty) return const [];
    for (final entry in schedulesByName.entries) {
      if (personFirstKey(entry.key) == key) return entry.value;
    }
    return const [];
  }

  String canonicalName(String raw) {
    final key = personFirstKey(raw);
    if (key.isEmpty) return raw.trim();
    for (final known in roster) {
      if (personFirstKey(known) == key) return known;
    }
    for (final existing in minutes.keys) {
      if (personFirstKey(existing) == key) return existing;
    }
    return raw.trim();
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
    // Equipe: presentes na OS + quem assinou + quadro Staff (e-mail).
    final byWho = <String, List<SavedRdo>>{};
    void credit(String raw, SavedRdo rdo) {
      final name = canonicalName(raw);
      if (name.isEmpty || name == '-') return;
      byWho.putIfAbsent(name, () => []).add(rdo);
    }

    for (final job in jobs) {
      if (job.rdo == null) continue;
      final rdo = job.rdo!;
      final seenKeys = <String>{};
      for (final raw in presentTeamForRdo(
        job.os,
        rdo,
        signedBy: rdo.responsibleName,
      )) {
        final key = personFirstKey(raw);
        if (key.isNotEmpty) seenKeys.add(key);
        credit(raw, rdo);
      }
      for (final raw in roster) {
        final key = personFirstKey(raw);
        if (key.isEmpty || seenKeys.contains(key)) continue;
        if (!rdoHoursBelongToTechnician(
          os: job.os,
          rdo: rdo,
          technicianName: raw,
          viewerIds: const {},
        )) {
          continue;
        }
        seenKeys.add(key);
        credit(raw, rdo);
      }
    }
    for (final entry in byWho.entries) {
      // Evita contar o mesmo RDO 2x se credit() duplicou referência.
      final unique = <String, SavedRdo>{};
      for (final rdo in entry.value) {
        unique.putIfAbsent(rdo.id, () => rdo);
      }
      setHours(entry.key, i, dayHoursFromRdos(unique.values));
    }
  }
  final rows = [
    for (final entry in minutes.entries)
      TechnicianWeekHours(
        name: entry.key,
        dayMinutes: entry.value,
        nightDayMinutes: nights[entry.key] ?? List<int>.filled(7, 0),
        extraDayMinutes: [
          for (var i = 0; i < days.length; i++)
            extraMinutesForDay(
              workedMinutes: entry.value[i],
              day: days[i],
              holiday: brazilHoliday(days[i]).isHoliday,
              dailyLimitOverride: () {
                final schedule =
                    scheduleForDay(schedulesOf(entry.key), days[i]);
                return schedule?.limitMinutesFor(days[i]);
              }(),
            ),
        ],
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
