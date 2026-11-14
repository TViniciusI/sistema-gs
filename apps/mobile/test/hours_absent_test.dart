import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/hours_report.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';

void main() {
  test('ausente no RDO não recebe horas mesmo destinário da OS', () {
    final day = DateTime(2026, 9, 24);
    final os = SavedOs(
      id: 'os-babet',
      number: '017/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: day,
      files: const [],
      technicianName: 'Cleber Guimarães, André Nascimento',
      technicianEmails: const [
        'cleber@gssolucoestec.com.br',
        'andre@gssolucoestec.com.br',
      ],
      status: OsStatus.emAndamento,
      rdo: const RdoData(client: 'Vibra Energia - BABET'),
      rdos: [
        SavedRdo(
          id: 'r1',
          date: day,
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: 'Serviço',
          notes: '',
          files: const [],
          createdAt: day,
          responsibleName: 'André Nascimento',
          absentNames: const ['Cleber Guimarães'],
        ),
      ],
    );
    final cleberIds = assignmentIdsFor(
      email: 'cleber@gssolucoestec.com.br',
      login: 'cleber',
      aliases: const ['Cleber Guimarães'],
    );
    final andreIds = assignmentIdsFor(
      email: 'andre@gssolucoestec.com.br',
      login: 'andre',
      aliases: const ['André Nascimento'],
    );

    expect(
      rdoHoursBelongToTechnician(
        os: os,
        rdo: os.rdos.first,
        technicianName: 'Cleber Guimarães',
        viewerIds: cleberIds,
      ),
      isFalse,
    );
    expect(
      rdoHoursBelongToTechnician(
        os: os,
        rdo: os.rdos.first,
        technicianName: 'André Nascimento',
        viewerIds: andreIds,
      ),
      isTrue,
    );

    final cleber = buildHoursReport(
      technicianName: 'Cleber Guimarães',
      viewerIds: cleberIds,
      orders: [os],
      from: day,
      to: day,
    );
    expect(cleber.days.single.workedMinutes, 0);
    expect(cleber.days.single.place, atHomeLabel);

    final andre = buildHoursReport(
      technicianName: 'André Nascimento',
      viewerIds: andreIds,
      orders: [os],
      from: day,
      to: day,
    );
    expect(andre.days.single.workedMinutes, 8 * 60);
  });

  test('ausente vence mesmo se o nome ainda estiver como responsável', () {
    final day = DateTime(2026, 9, 25);
    final rdo = SavedRdo(
      id: 'r2',
      date: day,
      clockIn: '08:00',
      lunchStart: '',
      lunchEnd: '',
      clockOut: '16:00',
      description: '',
      notes: '',
      files: const [],
      createdAt: day,
      responsibleName: 'Cleber Guimarães',
      absentNames: const ['Cleber Guimarães'],
    );
    final os = SavedOs(
      id: 'os-2',
      number: '018/26',
      ownerEmail: 'cleber@gssolucoestec.com.br',
      createdAt: day,
      files: const [],
      technicianName: 'Cleber Guimarães',
      technicianEmails: const ['cleber@gssolucoestec.com.br'],
      status: OsStatus.emAndamento,
      rdos: [rdo],
    );
    final ids = assignmentIdsFor(
      email: 'cleber@gssolucoestec.com.br',
      login: 'cleber',
    );
    expect(
      rdoHoursBelongToTechnician(
        os: os,
        rdo: rdo,
        technicianName: 'Cleber Guimarães',
        viewerIds: ids,
      ),
      isFalse,
    );
  });
}
