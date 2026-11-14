import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_bundle_pdf.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/models.dart';

CalibrationJob _job({
  required String number,
  required CalibrationKind kind,
  required String location,
}) {
  return CalibrationJob(
    id: number,
    number: number,
    kind: kind,
    createdAt: DateTime(2026, 9, 10),
    installLocation: location,
    osNumber: '047/26',
    clientName: 'Cliente Teste',
  );
}

void main() {
  test('agrupa por local e ordena tipos e números', () {
    final jobs = [
      _job(
        number: 'GS-VOL-2026-0003',
        kind: CalibrationKind.volumetric,
        location: 'Plataforma 2',
      ),
      _job(
        number: 'GS-TEMP-2026-0001',
        kind: CalibrationKind.temperature,
        location: 'Plataforma 1',
      ),
      _job(
        number: 'GS-VOL-2026-0001',
        kind: CalibrationKind.volumetric,
        location: 'Plataforma 1',
      ),
      _job(
        number: 'GS-DEN-2026-0002',
        kind: CalibrationKind.density,
        location: 'Plataforma 1',
      ),
      _job(
        number: 'GS-VOL-2026-0002',
        kind: CalibrationKind.volumetric,
        location: 'Plataforma 1',
      ),
    ];

    final groups = groupJobsForCertificateBundle(jobs);
    expect(groups.map((g) => g.location), ['Plataforma 1', 'Plataforma 2']);

    final p1 = groups.first;
    final kinds = p1.byKind.keys.toList()
      ..sort(
        (a, b) =>
            calibrationBundleKindOrder(a).compareTo(calibrationBundleKindOrder(b)),
      );
    expect(kinds, [
      CalibrationKind.volumetric,
      CalibrationKind.temperature,
      CalibrationKind.density,
    ]);
    expect(
      p1.byKind[CalibrationKind.volumetric]!.map((j) => j.number).toList(),
      ['GS-VOL-2026-0001', 'GS-VOL-2026-0002'],
    );
  });

  test('nome do arquivo do livro', () {
    expect(
      calibrationBundleFileName(
        osNumber: '047/26',
        requester: 'DTC Rio Verde',
      ),
      'Book_Certificado_Calibracao_DTC_Rio_Verde_047-26.pdf',
    );
  });

  test('In Loco / tag do preset não viram local da instalação no book', () {
    final jobs = [
      CalibrationJob(
        id: 'a',
        number: 'GS-VOL-2026-0001',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 10),
        installLocation: 'In Loco',
        presetTag: 'FIQ 5B',
        site: 'AREA RURAL, RIO VERDE/GO, CEP: 75913899',
      ),
      CalibrationJob(
        id: 'b',
        number: 'GS-VOL-2026-0002',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 10),
        // Poluído: local = tag do preset (bug antigo).
        installLocation: 'FIQ 5B',
        presetTag: 'FIQ 5B',
      ),
      CalibrationJob(
        id: 'c',
        number: 'GS-VOL-2026-0003',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 10),
        installLocation: 'ILHA 5B',
        presetTag: 'FIQ 5B',
      ),
      CalibrationJob(
        id: 'd',
        number: 'GS-VOL-2026-0004',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 10),
        installLocation: 'Plataforma 1',
        presetTag: 'FIQ 1',
      ),
    ];
    final groups = groupJobsForCertificateBundle(jobs);
    // FIQ 5B (mesmo com In Loco / local poluído) vira ILHA 5B; FIQ 1 sozinho
    // não inventa ilha (falta letra) e mantém Plataforma 1.
    expect(
      groups.map((g) => g.location).toList(),
      ['ILHA 5B', 'Plataforma 1'],
    );
    expect(
      groups.first.byKind[CalibrationKind.volumetric]!.map((j) => j.number),
      ['GS-VOL-2026-0001', 'GS-VOL-2026-0002', 'GS-VOL-2026-0003'],
    );
  });

  test('sem cadastro: FIQ/FT ainda separa ILHA no book (não Sem local)', () {
    final jobs = [
      CalibrationJob(
        id: 'a',
        number: 'GS-VOL-2026-0005',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 11, 14),
        clientName: 'VIBRA ENERGIA S.A - BASPA',
        site: 'Avenida Almirante Delamare, 1335',
        installLocation: 'BASPA',
        presetTag: 'FIQ 5B',
        equipmentTag: 'FT 5B',
        serialNumber: '1346E10136',
      ),
      CalibrationJob(
        id: 'b',
        number: 'GS-TEMP-2026-0003',
        kind: CalibrationKind.temperature,
        createdAt: DateTime(2026, 11, 14),
        clientName: 'VIBRA ENERGIA S.A - BASPA',
        site: 'Avenida Almirante Delamare, 1335',
        installLocation: '',
        presetTag: 'FIQ 3A',
        equipmentTag: 'TE 3A',
        serialNumber: 'PLACT - ILHA 3A',
      ),
      CalibrationJob(
        id: 'c',
        number: 'GS-VOL-2026-0003',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 11, 14),
        clientName: 'VIBRA ENERGIA S.A - BASPA',
        site: 'Avenida Almirante Delamare, 1335',
        installLocation: 'In Loco',
        presetTag: 'FIQ 3A',
        equipmentTag: 'FT 3A',
        serialNumber: '1407E10100',
      ),
    ];
    expect(inferInstallLocationFromInstrumentLabels(jobs[0]), 'ILHA 5B');
    expect(inferInstallLocationFromInstrumentLabels(jobs[1]), 'ILHA 3A');
    expect(inferInstallLocationFromInstrumentLabels(jobs[2]), 'ILHA 3A');
    expect(
      resolveCertificateInstallLocation(jobs[0]),
      'ILHA 5B',
    );
    final groups = groupJobsForCertificateBundle(jobs);
    expect(groups.map((g) => g.location).toList(), ['ILHA 3A', 'ILHA 5B']);
    expect(groups, isNot(contains(predicate((g) {
      return g is CalibrationBundleLocationGroup &&
          g.location == 'Sem local do sistema';
    }))));
  });

  test('N/S com espaço extra e BASPA no job separam ILHA 3A/5B no book', () {
    final client = SavedClient(
      id: 'baspa',
      name: 'VIBRA ENERGIA S.A - BASPA',
      requester: 'VIBRA - BASPA',
      sites: const ['BASPA'],
      updatedAt: DateTime(2026, 11, 14),
      systems: const [
        ClientSystem(
          id: 'sys-3a',
          systemType: 'Sistema de Descarregamento',
          installLocation: 'ILHA 3A',
          assemblyTag: 'FIQ 3A',
          kind: ClientAssemblyKind.preset,
          instruments: [
            ClientInstrument(
              id: 'm3',
              role: ClientInstrumentRole.meter,
              tag: 'FT 3A',
              serialNumber: '1407E10100',
            ),
            ClientInstrument(
              id: 't3',
              role: ClientInstrumentRole.pt100,
              tag: 'TE 3A',
              // Planilha real: dois espaços antes do 3A.
              serialNumber: 'PLACT - ILHA  3A',
            ),
          ],
        ),
        ClientSystem(
          id: 'sys-5b',
          systemType: 'Sistema de Descarregamento',
          installLocation: 'ILHA 5B',
          assemblyTag: 'FIQ 5B',
          kind: ClientAssemblyKind.preset,
          instruments: [
            ClientInstrument(
              id: 'm5',
              role: ClientInstrumentRole.meter,
              tag: 'FT 5B',
              serialNumber: '1346E10136',
            ),
            ClientInstrument(
              id: 't5',
              role: ClientInstrumentRole.pt100,
              tag: 'TE 5B',
              serialNumber: 'PLACT - ILHA  5B',
            ),
          ],
        ),
      ],
    );

    // Ordem de envio da OS (5B depois 3A misturados) — o book deve separar.
    final jobs = [
      CalibrationJob(
        id: 't5',
        number: 'GS-TEMP-2026-0005',
        kind: CalibrationKind.temperature,
        createdAt: DateTime(2026, 11, 14),
        clientId: client.id,
        clientName: client.name,
        site: 'Avenida Almirante Delamare, 1335',
        installLocation: 'BASPA', // site da OS, não a ilha
        presetTag: 'FIQ 5B',
        equipmentTag: 'TE 5B',
        // Técnico / sync normalizou o espaço — ainda tem que achar a ilha.
        serialNumber: 'PLACT - ILHA 5B',
      ),
      CalibrationJob(
        id: 'v3',
        number: 'GS-VOL-2026-0003',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 11, 14),
        clientId: client.id,
        clientName: client.name,
        site: 'Avenida Almirante Delamare, 1335',
        installLocation: 'BASPA',
        presetTag: 'FIQ 3A',
        equipmentTag: 'FT 3A',
        serialNumber: '1407E10100',
      ),
      CalibrationJob(
        id: 't3',
        number: 'GS-TEMP-2026-0003',
        kind: CalibrationKind.temperature,
        createdAt: DateTime(2026, 11, 14),
        clientId: client.id,
        clientName: client.name,
        site: 'Avenida Almirante Delamare, 1335',
        installLocation: '',
        presetTag: 'FIQ 3A',
        equipmentTag: 'TE 3A',
        serialNumber: 'PLACT - ILHA 3A',
      ),
      CalibrationJob(
        id: 'v5',
        number: 'GS-VOL-2026-0005',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 11, 14),
        clientId: client.id,
        clientName: client.name,
        site: 'Avenida Almirante Delamare, 1335',
        installLocation: 'In Loco',
        presetTag: 'FIQ 5B',
        equipmentTag: 'FT 5B',
        serialNumber: '1346E10136',
      ),
    ];

    expect(
      resolveCertificateInstallLocation(jobs[0], client: client),
      'ILHA 5B',
    );
    expect(
      resolveCertificateInstallLocation(jobs[1], client: client),
      'ILHA 3A',
    );
    expect(
      resolveCertificateInstallLocation(jobs[2], client: client),
      'ILHA 3A',
    );
    expect(
      resolveCertificateInstallLocation(jobs[3], client: client),
      'ILHA 5B',
    );

    final prepared = [
      for (final job in jobs)
        job.copyWith(
          installLocation: resolveCertificateInstallLocation(job, client: client),
        ),
    ];
    final groups = groupJobsForCertificateBundle(prepared);
    expect(groups.map((g) => g.location).toList(), ['ILHA 3A', 'ILHA 5B']);
    expect(
      groups.first.byKind[CalibrationKind.volumetric]!.map((j) => j.number),
      ['GS-VOL-2026-0003'],
    );
    expect(
      groups.last.byKind[CalibrationKind.volumetric]!.map((j) => j.number),
      ['GS-VOL-2026-0005'],
    );
  });

  test('local do book vem do cadastro do sistema, não do preset', () {
    final client = SavedClient(
      id: 'baspa',
      name: 'BASPA',
      updatedAt: DateTime(2026, 10, 29),
      systems: const [
        ClientSystem(
          id: 'sys-5b',
          systemType: 'Sistema de Descarregamento',
          installLocation: 'ILHA 5B',
          assemblyTag: 'FIQ 5B',
          kind: ClientAssemblyKind.preset,
          instruments: [
            ClientInstrument(
              id: 'm1',
              role: ClientInstrumentRole.meter,
              tag: 'FT 5B',
              serialNumber: 'SN-5B',
              product: 'S10',
            ),
          ],
        ),
      ],
    );
    final job = CalibrationJob(
      id: 'a',
      number: 'GS-VOL-2026-0100',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 10, 29),
      clientId: 'baspa',
      clientName: 'BASPA',
      installLocation: 'FIQ 5B',
      presetTag: 'FIQ 5B',
      equipmentTag: 'FT 5B',
      serialNumber: 'SN-5B',
      systemId: 'sys-5b',
    );
    expect(catalogSystemInstallLocation(job, client), 'ILHA 5B');
    expect(resolveCertificateInstallLocation(job, client: client), 'ILHA 5B');
    expect(calibrationBundleLocationLabel(job.copyWith(installLocation: 'ILHA 5B')), 'ILHA 5B');
  });

  test('local do sistema vence BASPA gravado no certificado', () {
    final job = CalibrationJob(
      id: 'x',
      number: 'GS-VOL-2026-0001',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 11, 4),
      installLocation: 'BASPA',
      presetTag: 'FIQ 4A',
      serialNumber: 'SN-4A',
    );
    expect(
      resolveCertificateInstallLocation(job, systemLocal: 'ILHA 4A'),
      'ILHA 4A',
    );
    expect(
      groupJobsForCertificateBundle([
        job.copyWith(installLocation: 'ILHA 4A'),
        job.copyWith(
          id: 'y',
          number: 'GS-VOL-2026-0002',
          installLocation: 'ILHA 3A',
          serialNumber: 'SN-3A',
          presetTag: 'FIQ 3A',
        ),
      ]).map((g) => g.location).toList(),
      ['ILHA 3A', 'ILHA 4A'],
    );
  });

  test('book separa ILHA 3A/4A/5B; TAG repetida não cola tudo no 5B', () {
    final client = SavedClient(
      id: 'baspa',
      name: 'VIBRA BASPA',
      updatedAt: DateTime(2026, 11, 4),
      systems: const [
        ClientSystem(
          id: 'sys-5b',
          systemType: 'Sistema de Descarregamento',
          installLocation: 'ILHA 5B',
          assemblyTag: 'FIQ 5B',
          kind: ClientAssemblyKind.preset,
          instruments: [
            ClientInstrument(
              id: 'm5',
              role: ClientInstrumentRole.meter,
              tag: 'FT',
              serialNumber: 'SN-5B',
              product: 'S10',
            ),
          ],
        ),
        ClientSystem(
          id: 'sys-3a',
          systemType: 'Sistema de Descarregamento',
          installLocation: 'ILHA 3A',
          assemblyTag: 'FIQ 3A',
          kind: ClientAssemblyKind.preset,
          instruments: [
            ClientInstrument(
              id: 'm3',
              role: ClientInstrumentRole.meter,
              tag: 'FT',
              serialNumber: 'SN-3A',
              product: 'S10',
            ),
          ],
        ),
        ClientSystem(
          id: 'sys-4a',
          systemType: 'Sistema de Descarregamento',
          installLocation: 'ILHA 4A',
          assemblyTag: 'FIQ 4A',
          kind: ClientAssemblyKind.preset,
          instruments: [
            ClientInstrument(
              id: 'm4',
              role: ClientInstrumentRole.meter,
              tag: 'FT',
              serialNumber: 'SN-4A',
              product: 'S10',
            ),
          ],
        ),
      ],
      equipment: const [
        ClientEquipment(
          id: 'e5',
          tag: 'FT',
          serialNumber: 'SN-5B',
          installLocation: 'ILHA 5B',
          systemId: 'sys-5b',
        ),
        ClientEquipment(
          id: 'e3',
          tag: 'FT',
          serialNumber: 'SN-3A',
          installLocation: 'ILHA 3A',
          systemId: 'sys-3a',
        ),
        ClientEquipment(
          id: 'e4',
          tag: 'FT',
          serialNumber: 'SN-4A',
          installLocation: 'ILHA 4A',
          systemId: 'sys-4a',
        ),
      ],
    );

    CalibrationJob island({
      required String id,
      required String number,
      required String systemId,
      required String local,
      required String serial,
      required String preset,
    }) {
      return CalibrationJob(
        id: id,
        number: number,
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 11, 4),
        clientId: 'baspa',
        clientName: 'VIBRA BASPA',
        // Poluído como no bug: tudo “ILHA 5B” ou tag de preset.
        installLocation: 'ILHA 5B',
        presetTag: preset,
        equipmentTag: 'FT',
        serialNumber: serial,
        systemId: systemId,
        fluid: 'S10',
      );
    }

    final j5 = island(
      id: '5',
      number: 'GS-VOL-2026-0005',
      systemId: 'sys-5b',
      local: 'ILHA 5B',
      serial: 'SN-5B',
      preset: 'FIQ 5B',
    );
    final j3 = island(
      id: '3',
      number: 'GS-VOL-2026-0003',
      systemId: 'sys-3a',
      local: 'ILHA 3A',
      serial: 'SN-3A',
      preset: 'FIQ 3A',
    );
    final j4 = island(
      id: '4',
      number: 'GS-VOL-2026-0004',
      systemId: 'sys-4a',
      local: 'ILHA 4A',
      serial: 'SN-4A',
      preset: 'FIQ 4A',
    );

    expect(resolveCertificateInstallLocation(j5, client: client), 'ILHA 5B');
    expect(resolveCertificateInstallLocation(j3, client: client), 'ILHA 3A');
    expect(resolveCertificateInstallLocation(j4, client: client), 'ILHA 4A');
    // TAG “FT” em 3 ilhas: sem N/S/systemId não escolhe a primeira.
    expect(
      catalogSystemInstallLocation(
        j3.copyWith(systemId: '', serialNumber: '', presetTag: ''),
        client,
      ),
      isNull,
    );

    final groups = groupJobsForCertificateBundle([
      j5.copyWith(installLocation: resolveCertificateInstallLocation(j5, client: client)),
      j3.copyWith(installLocation: resolveCertificateInstallLocation(j3, client: client)),
      j4.copyWith(installLocation: resolveCertificateInstallLocation(j4, client: client)),
    ]);
    expect(groups.map((g) => g.location).toList(), [
      'ILHA 3A',
      'ILHA 4A',
      'ILHA 5B',
    ]);
  });
}
