import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/week_agenda.dart';

void main() {
  test('horas da equipe incluem todos os presentes, não só quem assinou', () {
    final monday = DateTime(2026, 11, 9); // segunda
    final os = SavedOs(
      id: 'os-team',
      number: '047/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: monday,
      files: const [],
      technicianName: 'Cleber Guimarães, Felipe Souza, André Nascimento',
      technicianEmails: const [
        'cleber@gssolucoestec.com.br',
        'felipe@gssolucoestec.com.br',
        'andre@gssolucoestec.com.br',
      ],
      status: OsStatus.emAndamento,
      rdo: const RdoData(client: 'VIBRA'),
      rdos: [
        SavedRdo(
          id: 'r1',
          date: monday,
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: 'Campo',
          notes: '',
          files: const [],
          createdAt: monday,
          responsibleName: 'André Nascimento',
          absentNames: const ['Cleber Guimarães'],
        ),
      ],
    );

    final rows = weekHoursByTechnician(
      orders: [os],
      weekStart: startOfWeek(monday),
    );
    final names = {for (final row in rows) row.name};
    expect(names, contains('Felipe Souza'));
    expect(names, contains('André Nascimento'));
    expect(names, isNot(contains('Cleber Guimarães')));
    // Não deve ficar só o assinante.
    expect(names.length, greaterThanOrEqualTo(2));
    for (final row in rows) {
      if (row.name == 'Felipe Souza' || row.name == 'André Nascimento') {
        expect(row.dayMinutes[0], 8 * 60);
      }
    }
  });

  test('assinante do RDO entra mesmo fora da lista da OS', () {
    final monday = DateTime(2026, 11, 9);
    final os = SavedOs(
      id: 'os-signer-only',
      number: '048/26',
      ownerEmail: 'administrativo@gssolucoestec.com.br',
      createdAt: monday,
      files: const [],
      technicianName: 'Cleber Guimarães',
      technicianEmails: const ['cleber@gssolucoestec.com.br'],
      status: OsStatus.emAndamento,
      rdo: const RdoData(client: 'VIBRA'),
      rdos: [
        SavedRdo(
          id: 'r-signer',
          date: monday,
          clockIn: '08:00',
          lunchStart: '12:00',
          lunchEnd: '13:00',
          clockOut: '17:00',
          description: 'Campo',
          notes: '',
          files: const [],
          createdAt: monday,
          responsibleName: 'Felipe Souza',
        ),
      ],
    );

    final rows = weekHoursByTechnician(
      orders: [os],
      weekStart: startOfWeek(monday),
    );
    final names = {for (final row in rows) row.name};
    expect(names, contains('Cleber Guimarães'));
    expect(names, contains('Felipe Souza'));
    expect(names.length, 2);
  });
}
