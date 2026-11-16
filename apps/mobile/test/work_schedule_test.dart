import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/hours_report.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';
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
    expect(scheduleForDay(periods, DateTime(2026, 11, 15))?.hoursPerDay, 8);
    expect(scheduleForDay(periods, DateTime(2026, 12, 5))?.hoursPerDay, 12);
    expect(scheduleForDay(periods, DateTime(2025, 12, 1)), isNull);
  });

  test('extra usa horas/dia da carga cadastrada', () {
    final day = DateTime(2026, 12, 2); // terça
    expect(
      extraMinutesForDay(
        workedMinutes: 10 * 60,
        day: day,
        holiday: false,
        dailyLimitOverride: 8 * 60,
      ),
      2 * 60,
    );
    expect(
      extraMinutesForDay(
        workedMinutes: 12 * 60,
        day: day,
        holiday: false,
        dailyLimitOverride: 12 * 60,
      ),
      0,
    );
  });

  test('relatório aplica % extra e limite do período', () {
    final day = DateTime(2026, 12, 3);
    final os = SavedOs(
      id: 'os1',
      number: '001/26',
      ownerEmail: 'a@b.com',
      createdAt: day,
      files: const [],
      technicianName: 'Felipe Souza',
      technicianEmails: const ['felipe@gssolucoestec.com.br'],
      status: OsStatus.emAndamento,
      rdos: [
        SavedRdo(
          id: 'r1',
          date: day,
          clockIn: '07:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '19:00',
          description: '',
          notes: '',
          files: const [],
          createdAt: day,
          responsibleName: 'Felipe Souza',
        ),
      ],
    );
    // presença 07–19 = 12h − 1h almoço = 11h; limite 8h → 3h extra
    final report = buildHoursReport(
      technicianName: 'Felipe Souza',
      viewerIds: assignmentIdsFor(
        email: 'felipe@gssolucoestec.com.br',
        login: 'felipe',
        aliases: const ['Felipe Souza'],
      ),
      orders: [os],
      from: day,
      to: day,
      schedules: [
        WorkSchedulePeriod(
          id: 'p',
          start: DateTime(2026, 12, 1),
          hoursPerDay: 8,
          overtimePercent: 50,
          label: '6x1',
        ),
      ],
    );
    expect(report.days.single.workedMinutes, 11 * 60);
    expect(report.days.single.extraMinutes, 3 * 60);
    expect(report.days.single.overtimePercent, 50);
    expect(report.days.single.scheduleLabel, '6x1');
  });
}
