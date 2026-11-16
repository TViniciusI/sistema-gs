import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/br_holidays.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/os/os_hub_page.dart';
import 'package:intl/intl.dart';

class WeekAgendaPanel extends StatefulWidget {
  const WeekAgendaPanel({super.key, required this.onlyMine});

  final bool onlyMine;

  @override
  State<WeekAgendaPanel> createState() => _WeekAgendaPanelState();
}

class _WeekAgendaPanelState extends State<WeekAgendaPanel> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = startOfWeek(DateTime.now());
  }

  List<SavedOs> get _orders {
    final user = AuthSession.instance.user;
    return agendaOrdersFor(
      orders: FieldStore.instance.items,
      onlyMine: widget.onlyMine,
      viewerIds: user == null ? const <String>{} : assigneeKeysFor(user),
    );
  }

  void _shiftWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
    });
  }

  void _openOs(SavedOs os) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OsHubPage(osId: os.id)),
    );
  }

  void _openDay(DateTime day, List<AgendaDayJob> jobs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GsTheme.paper,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${weekDayLabels[day.weekday - 1].replaceAll('.', '')}, ${DateFormat('dd/MM/yyyy').format(day)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 12),
              if (jobs.isEmpty)
                const Text(
                  'Nenhum serviço neste dia.',
                  style: TextStyle(color: Color(0xFF5C6570)),
                )
              else
                for (final job in jobs)
                  _DayJobTile(day: day, job: job, onOpen: () {
                    Navigator.pop(context);
                    _openOs(job.os);
                  }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        FieldStore.instance,
        AuthSession.instance,
      ]),
      builder: (context, _) {
        final days = daysOfWeek(_weekStart);
        final end = days.last;
        final range =
            '${DateFormat('dd/MM').format(_weekStart)} — ${DateFormat('dd/MM').format(end)}';
        final team = !widget.onlyMine;
        final user = AuthSession.instance.user;
        final hours = weekHoursByTechnician(
          orders: _orders,
          weekStart: _weekStart,
          viewerName: team || user == null
              ? null
              : user.name.trim().isNotEmpty
                    ? user.name.trim()
                    : user.login.trim(),
          viewerIds: team || user == null
              ? const <String>{}
              : assigneeKeysFor(user),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                team ? 'Agenda da equipe' : 'Agenda da semana',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Semana anterior',
              onPressed: () => _shiftWeek(-1),
              icon: const Icon(Icons.chevron_left, color: GsTheme.navy),
            ),
            IconButton(
              tooltip: 'Semana seguinte',
              onPressed: () => _shiftWeek(1),
              icon: const Icon(Icons.chevron_right, color: GsTheme.navy),
            ),
          ],
        ),
        Text(
          team
              ? 'Distribuição das OS na semana $range — o técnico vê só as suas no aplicativo.'
              : 'Seus serviços na semana $range. O escritório usa as horas do RDO para DSR e extra.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.35,
            color: Color(0xFF5C6570),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final vertical = constraints.maxWidth < 640;
            if (vertical) {
              return Column(
                children: [
                  for (var i = 0; i < days.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _DayCell(
                      day: days[i],
                      label: weekDayLabels[i],
                      jobs: agendaJobsOnDay(
                        _orders,
                        days[i],
                        weekStart: _weekStart,
                      ),
                      today: isSameDay(days[i], DateTime.now()),
                      horizontal: true,
                      onOpenDay: _openDay,
                      onOpenOs: _openOs,
                    ),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _DayCell(
                      day: days[i],
                      label: weekDayLabels[i],
                      jobs: agendaJobsOnDay(
                        _orders,
                        days[i],
                        weekStart: _weekStart,
                      ),
                      today: isSameDay(days[i], DateTime.now()),
                      horizontal: false,
                      onOpenDay: _openDay,
                      onOpenOs: _openOs,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        if (hours.isNotEmpty) ...[
          const SizedBox(height: 14),
          _HoursCard(rows: hours, team: team),
        ],
      ],
    );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.label,
    required this.jobs,
    required this.today,
    required this.horizontal,
    required this.onOpenDay,
    required this.onOpenOs,
  });

  final DateTime day;
  final String label;
  final List<AgendaDayJob> jobs;
  final bool today;
  final bool horizontal;
  final void Function(DateTime day, List<AgendaDayJob> jobs) onOpenDay;
  final ValueChanged<SavedOs> onOpenOs;

  @override
  Widget build(BuildContext context) {
    final header =
        '$label ${DateFormat('dd/MM').format(day)}';
    final body = jobs.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '—',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF9AA3AD),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final job in jobs.take(3)) ...[
                _JobChip(job: job, onTap: () => onOpenOs(job.os)),
                const SizedBox(height: 6),
              ],
              if (jobs.length > 3)
                Text(
                  '+${jobs.length - 3}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
            ],
          );

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => onOpenDay(day, jobs),
        child: Container(
          constraints: BoxConstraints(minHeight: horizontal ? 56 : 96),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: today ? GsTheme.navy : const Color(0x331A2330),
              width: today ? 1.6 : 1,
            ),
          ),
          child: horizontal
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 86,
                      child: Text(
                        header,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: today ? GsTheme.navy : const Color(0xFF5C6570),
                        ),
                      ),
                    ),
                    Expanded(child: body),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      header,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: today ? GsTheme.navy : const Color(0xFF5C6570),
                      ),
                    ),
                    const SizedBox(height: 8),
                    body,
                  ],
                ),
        ),
      ),
    );
  }
}

class _JobChip extends StatelessWidget {
  const _JobChip({required this.job, required this.onTap});

  final AgendaDayJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GsTheme.navy,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OS ${job.os.number}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              if (job.place.isNotEmpty)
                Text(
                  job.place,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD7DEE6),
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayJobTile extends StatelessWidget {
  const _DayJobTile({
    required this.day,
    required this.job,
    required this.onOpen,
  });

  final DateTime day;
  final AgendaDayJob job;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final extra = extraMinutesForDay(
      workedMinutes: job.workedMinutes,
      day: day,
      holiday: brazilHoliday(day).isHoliday,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'OS ${job.os.number}',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: GsTheme.navy,
        ),
      ),
      subtitle: Text(
        [
          if (job.place.isNotEmpty) job.place,
          if (job.who.isNotEmpty) job.who,
          if (job.rdo != null)
            rdoClockRange(job.rdo!.clockIn, job.rdo!.clockOut),
          if (job.workedMinutes > 0) formatWorkedHours(job.workedMinutes),
          if (extra > 0) 'extra ${formatWorkedHours(extra)}',
          if (job.nightMinutes > 0)
            'noturno ${formatWorkedHours(job.nightMinutes)}',
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onOpen,
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.rows, required this.team});

  final List<TechnicianWeekHours> rows;
  final bool team;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold(0, (sum, row) => sum + row.workedMinutes);
    final extra = rows.fold(0, (sum, row) => sum + row.extraMinutes);
    final night = rows.fold(0, (sum, row) => sum + row.nightMinutes);
    final dsr = rows.fold(0, (sum, row) => sum + row.dsrMinutes);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            team ? 'Horas da equipe nesta semana' : 'Suas horas nesta semana',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: GsTheme.navy,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            team
                ? 'Entrada e saída do RDO de cada técnico presente no dia (não só quem assinou), menos 1h de almoço. Extra depois de 8h no dia (sábado depois de 4h; domingo e feriado o dia todo). Das 22h às 05h conta adicional noturno. Admin acerta horários em Funcionários → Analisar horas.'
                : 'Entrada e saída do RDO, menos 1h de almoço. Extra depois de 8h no dia (sábado depois de 4h; domingo e feriado o dia todo). Das 22h às 05h conta adicional noturno.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF5C6570),
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                [
                  row.name,
                  formatWorkedHours(row.workedMinutes),
                  if (row.extraMinutes > 0)
                    'extra ${formatWorkedHours(row.extraMinutes)}',
                  if (row.nightMinutes > 0)
                    'noturno ${formatWorkedHours(row.nightMinutes)}',
                  if (row.sundayMinutes > 0)
                    'domingo ${formatWorkedHours(row.sundayMinutes)}',
                  if (row.dsrMinutes > 0)
                    'DSR ${formatWorkedHours(row.dsrMinutes)}',
                  if (row.weeklyOvertimeMinutes > 0)
                    'acima de 44h ${formatWorkedHours(row.weeklyOvertimeMinutes)}',
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: GsTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            'Total ${formatWorkedHours(total)}'
            '${extra > 0 ? ' · extra ${formatWorkedHours(extra)}' : ''}'
            '${night > 0 ? ' · noturno ${formatWorkedHours(night)}' : ''}'
            '${dsr > 0 ? ' · DSR ${formatWorkedHours(dsr)}' : ''}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: GsTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}
