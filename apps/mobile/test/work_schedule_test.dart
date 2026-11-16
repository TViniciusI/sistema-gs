import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/hours_report.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/work_hours.dart';
import 'package:gs_mobile/data/work_schedule.dart';

void main() {
  test('scheduleForDay pega o período mais recente que cobre o dia', () {
    final periods = [
      WorkSchedulePeriod(
        id: '1',
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 11, 30),
        hoursPerDay: 8,
        overtimePercent: 50,
        label: '6x1',
      ),
      WorkSchedulePeriod(
        id: '2',
        start: DateTime(2026, 12, 1),
        hoursPerDay: 12,
        overtimePercent: 100,
        label: 'plantão',
      ),
    ];
    expect(
      scheduleForDay(periods, DateTime(2026, 11, 15))!.ruleForDate(
        DateTime(2026, 11, 15),
      ).hours,
      8,
    );
    expect(
      scheduleForDay(periods, DateTime(2026, 12, 5))!.ruleForDate(
        DateTime(2026, 12, 5),
      ).hours,
      12,
    );
    expect(scheduleForDay(periods, DateTime(2025, 12, 1)), isNull);
  });

  test('cada weekday tem horas e % próprios; domingo não força 100% extra', () {
    final sunday = DateTime(2026, 12, 6); // domingo
    final period = WorkSchedulePeriod(
      id: 'p',
      start: DateTime(2026, 12, 1),
      weekdays: [
        const WorkDayRule(hours: 8, overtimePercent: 50), // seg
        const WorkDayRule(hours: 8, overtimePercent: 50),
        const WorkDayRule(hours: 8, overtimePercent: 50),
        const WorkDayRule(hours: 8, overtimePercent: 50),
        const WorkDayRule(hours: 8, overtimePercent: 50),
        const WorkDayRule(hours: 4, overtimePercent: 50), // sáb
        const WorkDayRule(hours: 8, overtimePercent: 0), // dom: 8h sem extra%
      ],
    );
    expect(period.ruleForDate(sunday).hours, 8);
    expect(period.ruleForDate(sunday).overtimePercent, 0);
    expect(
      extraMinutesForDay(
        workedMinutes: 8 * 60,
        day: sunday,
        holiday: false,
        dailyLimitOverride: period.limitMinutesFor(sunday),
      ),
      0,
    );
    expect(
      extraMinutesForDay(
        workedMinutes: 10 * 60,
        day: sunday,
        holiday: false,
        dailyLimitOverride: period.limitMinutesFor(sunday),
      ),
      2 * 60,
    );
    // Sem escala: domingo ainda conta tudo como extra.
    expect(
      extraMinutesForDay(
        workedMinutes: 8 * 60,
        day: sunday,
        holiday: false,
      ),
      8 * 60,
    );
  });

  test('relatório usa regra do dia da semana da escala', () {
    final sunday = DateTime(2026, 12, 6);
    final os = SavedOs(
      id: 'os1',
      number: '001/26',
      ownerEmail: 'a@b.com',
      createdAt: sunday,
      files: const [],
      technicianName: 'Felipe Souza',
      technicianEmails: const ['felipe@gssolucoestec.com.br'],
      status: OsStatus.emAndamento,
      rdos: [
        SavedRdo(
          id: 'r1',
          date: sunday,
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: '',
          notes: '',
          files: const [],
          createdAt: sunday,
          responsibleName: 'Felipe Souza',
        ),
      ],
    );
    final report = buildHoursReport(
      technicianName: 'Felipe Souza',
      viewerIds: assignmentIdsFor(
        email: 'felipe@gssolucoestec.com.br',
        login: 'felipe',
        aliases: const ['Felipe Souza'],
      ),
      orders: [os],
      from: sunday,
      to: sunday,
      schedules: [
        WorkSchedulePeriod(
          id: 'p',
          start: DateTime(2026, 12, 1),
          label: 'escala',
          weekdays: [
            const WorkDayRule(hours: 8, overtimePercent: 50),
            const WorkDayRule(hours: 8, overtimePercent: 50),
            const WorkDayRule(hours: 8, overtimePercent: 50),
            const WorkDayRule(hours: 8, overtimePercent: 50),
            const WorkDayRule(hours: 8, overtimePercent: 50),
            const WorkDayRule(hours: 4, overtimePercent: 50),
            const WorkDayRule(hours: 8, overtimePercent: 0),
          ],
        ),
      ],
    );
    expect(report.days.single.workedMinutes, 8 * 60);
    expect(report.days.single.extraMinutes, 0);
    expect(report.days.single.overtimePercent, 0);
  });

  test('JSON antigo sem weekdays vira 7 dias iguais', () {
    final period = WorkSchedulePeriod.fromJson({
      'id': 'old',
      'start': '2026-11-01',
      'hoursPerDay': 12,
      'overtimePercent': 100,
      'label': 'plantão',
    });
    expect(period.weekdays.length, 7);
    expect(period.weekdays.every((d) => d.hours == 12), isTrue);
    expect(period.weekdays.every((d) => d.overtimePercent == 100), isTrue);
  });
}
