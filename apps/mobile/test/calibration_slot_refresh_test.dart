import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/features/os/calibration_slots_group.dart';

void main() {
  test('medidor com 3 produtos vira 3 calibrações na OS', () {
    final client = SavedClient(
      id: 'c-multi',
      name: 'VIBRA',
      cnpj: '1',
      equipment: const [
        ClientEquipment(
          id: 'm-1',
          systemType: 'Carregamento',
          equipmentType: 'Medidor',
          instrumentRole: 'meter',
          quantity: 1,
          installLocation: 'Plataforma 1',
          tag: 'FT 5B',
          serialNumber: '1346E10136',
          product: 'Diesel S10, Diesel S500, Gasolina',
        ),
        ClientEquipment(
          id: 'm-2',
          systemType: 'Carregamento',
          equipmentType: 'Medidor',
          instrumentRole: 'meter',
          quantity: 1,
          installLocation: 'Plataforma 1',
          tag: 'FT 6',
          serialNumber: '999',
          product: 'Etanol',
        ),
      ],
      updatedAt: DateTime(2026, 10, 3),
    );
    final pool = clientEquipmentForCalibration(
      equipment: client.equipment,
      kind: CalibrationKind.volumetric,
      usedIds: const {},
      perProduct: true,
    );
    expect(pool.length, 4);

    final slots = [
      for (var i = 0; i < 5; i++)
        OsCalibrationSlot(
          id: 's$i',
          kind: 'volumetric',
          certificateNumber: 'GS-VOL-2026-01$i',
        ),
    ];
    final filled = refreshOsCalibrationSlots(slots: slots, client: client);
    final m1 = [
      for (final s in filled)
        if (s.serialNumber == '1346E10136') s.product,
    ]..sort();
    expect(m1, ['Diesel S10', 'Diesel S500', 'Gasolina']);
    expect(filled.where((s) => s.serialNumber == '999').length, 1);
    expect(filled.where((s) => s.serialNumber.isEmpty).length, 1);

    final again = refreshOsCalibrationSlots(slots: filled, client: client);
    expect(
      [for (final s in again) '${s.serialNumber}|${s.product}'],
      [for (final s in filled) '${s.serialNumber}|${s.product}'],
    );
  });

  test('aponta certificados da mesma OS com o mesmo medidor', () {
    CalibrationJob job(String id, String tag, String serial, String fluid) =>
        CalibrationJob(
          id: id,
          number: id,
          kind: CalibrationKind.volumetric,
          createdAt: DateTime(2026, 9, 3),
          equipmentTag: tag,
          serialNumber: serial,
          fluid: fluid,
        );
    final jobs = {
      's24': job('0024', 'FT 7.1', '002-01-508', 'Gasolina'),
      's28': job('0028', 'FT 7.1', '002-01-508', 'Gasolina'),
      's35': job('0135', 'FT 7.1', '002-01-709', 'Gasolina'),
      'v1': job('V1', 'FT 5B', '1346E10136', 'Diesel S10'),
      'v2': job('V2', 'FT 5B', '1346E10136', 'Diesel S500'),
    };
    final slots = [
      for (final entry in jobs.entries)
        OsCalibrationSlot(
          id: entry.key,
          kind: 'volumetric',
          certificateNumber: entry.value.number,
        ),
    ];
    final same = calibrationSlotsSharingMeter(slots, (s) => jobs[s.id]);
    expect(same['s24'], ['0028']);
    expect(same['s28'], ['0024']);
    expect(same.containsKey('s35'), isFalse);
    expect(same.containsKey('v1'), isFalse);
  });

  test('PT100 com o mesmo N/S de lote não é medidor repetido', () {
    CalibrationJob job(String id, String tag) => CalibrationJob(
          id: id,
          number: id,
          kind: CalibrationKind.temperature,
          createdAt: DateTime(2026, 9, 3),
          equipmentTag: tag,
          serialNumber: '41327/1',
        );
    final jobs = {
      't2': job('GS-TEMP-2026-0002', 'TE 1'),
      't3': job('GS-TEMP-2026-0003', 'TE 1'),
      't9': job('GS-TEMP-2026-0009', 'TE 2'),
    };
    final slots = [
      for (final entry in jobs.entries)
        OsCalibrationSlot(
          id: entry.key,
          kind: 'temperature',
          certificateNumber: entry.value.number,
        ),
    ];
    expect(calibrationSlotsSharingMeter(slots, (s) => jobs[s.id]), isEmpty);
  });

  test('refresh fills all temperature slots from distinct PT100s', () {
    final client = SavedClient(
      id: 'c1',
      name: 'PHOENIX',
      cnpj: '09158456000159',
      equipment: [
        for (var i = 1; i <= 10; i++)
          ClientEquipment(
            id: 'pt-$i',
            systemId: 'sys-$i',
            systemType: 'Sistema de Carregamento',
            equipmentType: 'PT100',
            instrumentRole: 'PT100',
            assemblyKind: 'Preset',
            presetTag: 'FIQ ${(i + 1) ~/ 2}',
            presetSerial: '001-01-400',
            tag: 'TE $i',
            serialNumber: '44900/$i',
            manufacturer: 'CEX',
            model: 'M$i',
            workingPrinciple: 'Termorresistência',
          ),
        for (var i = 1; i <= 10; i++)
          ClientEquipment(
            id: 'm-$i',
            systemId: 'sys-$i',
            systemType: 'Sistema de Carregamento',
            equipmentType: 'Medidor Tipo Turbina',
            instrumentRole: 'Medidor',
            assemblyKind: 'Preset',
            presetTag: 'FIQ ${(i + 1) ~/ 2}',
            tag: 'FT $i',
            serialNumber: '002-01-$i',
          ),
      ],
      updatedAt: DateTime.now(),
    );

    final slots = [
      for (var i = 0; i < 10; i++)
        OsCalibrationSlot(
          id: 't$i',
          kind: CalibrationKind.temperature.name,
          certificateNumber:
              'GS-TEMP-2026-${(i + 1).toString().padLeft(4, '0')}',
        ),
      for (var i = 0; i < 10; i++)
        OsCalibrationSlot(
          id: 'v$i',
          kind: CalibrationKind.volumetric.name,
          certificateNumber:
              'GS-VOL-2026-${(i + 1).toString().padLeft(4, '0')}',
        ),
    ];

    final refreshed = refreshOsCalibrationSlots(slots: slots, client: client);

    final temps = refreshed.where(
      (s) => calibrationKindFrom(s.kind) == CalibrationKind.temperature,
    );
    final vols = refreshed.where(
      (s) => calibrationKindFrom(s.kind) == CalibrationKind.volumetric,
    );

    expect(temps.every((s) => !s.needsCadastro), isTrue);
    expect(temps.every((s) => s.serialNumber.trim().isNotEmpty), isTrue);
    expect(temps.every((s) => s.equipmentTag.startsWith('TE')), isTrue);
    expect(vols.every((s) => !s.needsCadastro), isTrue);
    expect(vols.every((s) => s.equipmentTag.startsWith('FT')), isTrue);

    // Sem misturar PT100 em vazão nem medidor em temperatura.
    expect(temps.every((s) => s.equipmentId.startsWith('pt-')), isTrue);
    expect(vols.every((s) => s.equipmentId.startsWith('m-')), isTrue);
  });

  test('slot confirmado vazio não trava o refresh do cadastro', () {
    final client = SavedClient(
      id: 'c1',
      name: 'Cliente',
      cnpj: '00000000000191',
      equipment: [
        ClientEquipment(
          id: 'm-1',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 1',
          serialNumber: 'SN-1',
        ),
      ],
      updatedAt: DateTime.now(),
    );
    final slots = [
      OsCalibrationSlot(
        id: 'v1',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0001',
        dataCheck: 'confirmed',
      ),
    ];
    expect(slots.first.needsCadastro, isTrue);
    expect(slots.first.locksCatalogRefresh, isFalse);
    final refreshed = refreshOsCalibrationSlots(slots: slots, client: client);
    expect(refreshed.first.needsCadastro, isFalse);
    expect(refreshed.first.equipmentTag, 'FT 1');
  });

  test('certificado preenchido preenche slot pendente da OS', () {
    final slots = [
      OsCalibrationSlot(
        id: 'v1',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0033',
      ),
    ];
    final jobs = [
      CalibrationJob(
        id: 'job-1',
        number: 'GS-VOL-2026-0033',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 16),
        equipmentTag: 'FT 4',
        serialNumber: '2412-52258U',
        calibrationSlotId: 'v1',
      ),
    ];
    final enriched = enrichOsSlotsFromCalibrationJobs(slots: slots, jobs: jobs);
    expect(enriched.first.needsCadastro, isFalse);
    expect(enriched.first.equipmentTag, 'FT 4');
    expect(enriched.first.serialNumber, '2412-52258U');
    expect(enriched.first.jobId, 'job-1');
  });

  test('local do sistema não usa endereço nem In Loco nem tag do preset', () {
    const site =
        'AREA RURAL BAIRRO AREA RURAL DE RIO VERDE, RIO VERDE/GO, CEP: 75913899';
    expect(looksLikePostalAddress(site), isTrue);
    expect(isGenericServicePlace('In Loco'), isTrue);
    expect(isUsefulSystemLocal('Carregamento Rodoviário', site: site), isTrue);

    final job = CalibrationJob(
      id: 'j1',
      number: 'GS-VOL-2026-0001',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 17),
      site: site,
      installLocation: 'In Loco',
      presetTag: 'FIQ 5B',
      systemType: '',
    );
    // Tag do preset não é local da instalação.
    expect(calibrationSystemLocal(job), '');
    expect(installLocationLooksLikePresetTag(job.copyWith(installLocation: 'FIQ 5B')), isTrue);
    expect(
      calibrationSystemLocal(job, systemLocal: 'ILHA 5B'),
      'ILHA 5B',
    );
    expect(
      calibrationSystemLocal(job, systemLocal: 'Plataforma 1'),
      'Plataforma 1',
    );
  });

  test('agrupa certificados relacionados do mesmo medidor', () {
    final meter = CalibrationJob(
      id: 'v1',
      number: 'GS-VOL-2026-0066',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 17),
      presetTag: 'Plact 2',
      equipmentTag: 'FT 2',
    );
    final temp = CalibrationJob(
      id: 't1',
      number: 'GS-TEMP-2026-0010',
      kind: CalibrationKind.temperature,
      createdAt: DateTime(2026, 9, 17),
      presetTag: 'Plact 2',
      equipmentTag: 'TE 2',
    );
    final other = CalibrationJob(
      id: 'v2',
      number: 'GS-VOL-2026-0067',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 17),
      presetTag: 'Plact 3',
      equipmentTag: 'FT 3',
    );
    final related = relatedCalibrationJobsForMeter(meter, [meter, temp, other]);
    expect(related.map((j) => j.number).toList(), [
      'GS-VOL-2026-0066',
      'GS-TEMP-2026-0010',
    ]);
  });

  test('refresh forçado do cadastro atualiza local e TAG', () {
    final client = SavedClient(
      id: 'c1',
      name: 'Cliente',
      cnpj: '00.000.000/0001-00',
      requester: 'DTC RIO VERDE',
      updatedAt: DateTime(2026, 9, 17),
      equipment: [
        ClientEquipment(
          id: 'eq1',
          systemType: 'Sistema de Carregamento',
          installLocation: 'Plataforma 7',
          tag: 'FT 7',
          serialNumber: 'SN-7',
          presetTag: 'FIQ 7',
          manufacturer: 'ZYLIX',
          model: 'TRB',
          equipmentType: 'Medidor Tipo Turbina',
        ),
      ],
    );
    final job = CalibrationJob(
      id: 'j1',
      number: 'GS-VOL-2026-0001',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 17),
      clientId: 'c1',
      equipmentId: 'eq1',
      equipmentTag: 'FT OLD',
      serialNumber: 'SN-7',
      installLocation: 'In Loco',
      manufacturer: 'OLD',
    );
    final refreshed = refreshCalibrationJobFromCatalog(job, client: client);
    expect(refreshed.equipmentTag, 'FT 7');
    expect(refreshed.installLocation, 'Plataforma 7');
    expect(refreshed.presetTag, 'FIQ 7');
    expect(refreshed.serviceRequester, 'DTC RIO VERDE');
    expect(refreshed.manufacturer, 'ZYLIX');
  });

  test('pull forçado sobrescreve slot confirmado editado manualmente', () {
    final client = SavedClient(
      id: 'c1',
      name: 'Cliente',
      updatedAt: DateTime(2026, 9, 23),
      equipment: const [
        ClientEquipment(
          id: 'eq1',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT CORRETO',
          serialNumber: 'SERIAL-CORRETO',
          presetSerial: 'PRESET-CORRETO',
          product: 'S10',
          manufacturer: 'Metroval',
          model: 'MV',
          installLocation: 'Plataforma 2',
        ),
      ],
    );
    final refreshed = refreshOsCalibrationSlots(
      slots: const [
        OsCalibrationSlot(
          id: 'v1',
          kind: 'volumetric',
          certificateNumber: 'GS-VOL-2026-0010',
          equipmentId: 'eq1',
          equipmentTag: 'TAG MANUAL ERRADA',
          serialNumber: 'SERIAL-ERRADO',
          presetSerial: 'PRESET-ERRADO',
          product: 'PRODUTO ERRADO',
          manufacturer: 'FABRICANTE ERRADO',
          model: 'MODELO ERRADO',
          installLocation: 'LOCAL ERRADO',
          dataCheck: 'confirmed',
        ),
      ],
      client: client,
      forceCatalog: true,
    ).single;

    expect(refreshed.equipmentTag, 'FT CORRETO');
    expect(refreshed.serialNumber, 'SERIAL-CORRETO');
    expect(refreshed.presetSerial, 'PRESET-CORRETO');
    expect(refreshed.product, 'S10');
    expect(refreshed.manufacturer, 'Metroval');
    expect(refreshed.model, 'MV');
    expect(refreshed.installLocation, 'Plataforma 2');
  });

  test('pull forçado troca equipmentId velho pela TAG do Excel', () {
    final client = SavedClient(
      id: 'c1',
      name: 'Phoenix',
      updatedAt: DateTime(2026, 9, 23),
      equipment: const [
        ClientEquipment(
          id: 'eq-errado',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 7.2',
          serialNumber: 'SN-ANIDRO',
          product: 'Anidro',
        ),
        ClientEquipment(
          id: 'eq-certo',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 4.2',
          serialNumber: 'SN-B100',
          product: 'B100',
        ),
      ],
    );
    final refreshed = refreshOsCalibrationSlots(
      slots: const [
        OsCalibrationSlot(
          id: 'v1',
          kind: 'volumetric',
          certificateNumber: 'GS-VOL-2026-0015',
          equipmentId: 'eq-errado',
          equipmentTag: 'FT 4.2',
          serialNumber: 'SN-ANIDRO',
          product: 'Anidro',
          dataCheck: 'confirmed',
        ),
      ],
      client: client,
      forceCatalog: true,
    ).single;

    expect(refreshed.equipmentId, 'eq-certo');
    expect(refreshed.equipmentTag, 'FT 4.2');
    expect(refreshed.product, 'B100');
    expect(refreshed.serialNumber, 'SN-B100');
  });

  test('refresh do cadastro preserva pontos conferências e padrões', () {
    final point = FlowPoint(
      id: 'p1',
      flowRate: 100,
      verification: const [
        VolumeRun(id: 'v1', objectVolume: 1000, standardVolume: 999.8),
      ],
      conferences: [
        ConferenceAttempt(
          id: 'c1',
          createdAt: DateTime(2026, 9, 23),
          runs: const [
            VolumeRun(id: 'c1-r1', objectVolume: 1000, standardVolume: 1000.1),
          ],
        ),
      ],
    );
    const genericPoint = GenericPoint(
      id: 'g1',
      cycles: [GenericCycle(standard: 10, instrument: 10.1)],
      conferences: [GenericCycle(standard: 10, instrument: 10.0)],
    );
    const standard = CalibrationStandard(id: 'std1', tag: 'CV-1000');
    final job = CalibrationJob(
      id: 'j1',
      number: 'GS-VOL-2026-0010',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 23),
      equipmentId: 'eq1',
      equipmentTag: 'TAG ERRADA',
      serialNumber: 'SERIAL-ERRADO',
      fluid: 'PRODUTO ERRADO',
      points: [point],
      genericPoints: const [genericPoint],
      standards: const [standard],
    );
    final client = SavedClient(
      id: 'c1',
      name: 'Cliente',
      updatedAt: DateTime(2026, 9, 23),
      equipment: const [
        ClientEquipment(
          id: 'eq1',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 10',
          serialNumber: 'SERIAL-CORRETO',
          presetSerial: 'PRESET-CORRETO',
          product: 'S500',
        ),
      ],
    );

    final refreshed = refreshCalibrationJobFromCatalog(job, client: client);

    expect(refreshed.equipmentTag, 'FT 10');
    expect(refreshed.serialNumber, 'SERIAL-CORRETO');
    expect(refreshed.presetSerial, 'PRESET-CORRETO');
    expect(refreshed.fluid, 'S500');
    expect(refreshed.points, same(job.points));
    expect(refreshed.points.single.conferences, same(point.conferences));
    expect(refreshed.genericPoints, same(job.genericPoints));
    expect(
      refreshed.genericPoints.single.conferences,
      same(genericPoint.conferences),
    );
    expect(refreshed.standards, same(job.standards));
  });

  test('label ready uses job even when slot still needsCadastro', () {
    final slot = OsCalibrationSlot(
      id: 'v2',
      kind: CalibrationKind.volumetric.name,
      certificateNumber: 'GS-VOL-2026-0067',
    );
    expect(slot.needsCadastro, isTrue);
    expect(calibrationSlotReadyForLabel(slot), isFalse);
    expect(calibrationSlotIsOrphanWithoutJob(slot), isTrue);

    final job = CalibrationJob(
      id: 'job-2',
      number: 'GS-VOL-2026-0067',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 16),
      equipmentTag: 'FT 9',
      serialNumber: 'SN-9',
    );
    expect(calibrationSlotReadyForLabel(slot, job: job), isTrue);
    expect(calibrationSlotIsOrphanWithoutJob(slot, job: job), isFalse);
    expect(osCalibrationSlotDetailLine(slot, job: job), contains('TAG FT 9'));
  });

  test('certificado de outra OS não contamina slot (Phoenix ≠ Rio Verde)', () {
    final phoenixSlots = [
      OsCalibrationSlot(
        id: 'phx-v1',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0031',
        jobId: 'rv-job',
      ),
    ];
    final jobs = [
      CalibrationJob(
        id: 'rv-job',
        number: 'GS-VOL-2026-0031',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 8, 4),
        osId: 'os-rio-verde',
        osNumber: '042/26',
        equipmentTag: 'Plact 7',
        presetTag: 'FIQ 7',
        fluid: 'Etanol anidro',
        serialNumber: '2408-51647U-1-13',
        calibrationSlotId: 'rv-slot',
      ),
      CalibrationJob(
        id: 'phx-job',
        number: 'GS-VOL-2026-0025',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 2),
        osId: 'os-phoenix',
        osNumber: '043/26',
        equipmentTag: 'FT 7.2',
        presetTag: 'FIQ 3.1',
        fluid: 'Anidro',
        serialNumber: '002-01-533',
        calibrationSlotId: 'phx-v1',
      ),
    ];

    final enriched = enrichOsSlotsFromCalibrationJobs(
      slots: phoenixSlots,
      jobs: jobs,
      osId: 'os-phoenix',
      osNumber: '043/26',
    );
    // Desvincula o job de Rio Verde; não copia Plact 7 para a Phoenix.
    expect(enriched.first.jobId, isNot(equals('rv-job')));
    expect(enriched.first.equipmentTag, isNot(equals('Plact 7')));
    expect(enriched.first.serialNumber, isNot(equals('2408-51647U-1-13')));
    // O job da própria Phoenix (mesmo slot) continua válido.
    expect(enriched.first.jobId, 'phx-job');
    expect(enriched.first.equipmentTag, 'FT 7.2');

    final scoped = calibrationJobsForOs(
      jobs,
      osId: 'os-phoenix',
      osNumber: '043/26',
      slotIds: ['phx-v1'],
    );
    expect(scoped.map((j) => j.id).toList(), ['phx-job']);
    expect(
      calibrationJobBelongsToOs(
        jobs.first,
        osId: 'os-phoenix',
        osNumber: '043/26',
        slotId: 'phx-v1',
      ),
      isFalse,
    );
  });

  test('job da mesma OS com slotId antigo continua vinculado', () {
    final slots = [
      OsCalibrationSlot(
        id: 'slot-novo',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0010',
        jobId: 'job-1',
      ),
    ];
    final jobs = [
      CalibrationJob(
        id: 'job-1',
        number: 'GS-VOL-2026-0010',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 18),
        osId: 'os-045',
        osNumber: '045/26',
        equipmentTag: 'FT 1',
        serialNumber: 'SN-1',
        calibrationSlotId: 'slot-antigo',
      ),
    ];
    final enriched = enrichOsSlotsFromCalibrationJobs(
      slots: slots,
      jobs: jobs,
      osId: 'os-045',
      osNumber: '045/26',
    );
    expect(enriched.first.jobId, 'job-1');
    expect(enriched.first.equipmentTag, 'FT 1');
    expect(enriched.first.serialNumber, 'SN-1');
  });

  test('não reutiliza N/S já usado em outro slot da OS', () {
    final client = SavedClient(
      id: 'c1',
      name: 'Cliente',
      cnpj: '00000000000191',
      updatedAt: DateTime(2026, 9, 18),
      equipment: [
        ClientEquipment(
          id: 'm-1',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 1',
          serialNumber: '002-01-588',
          presetTag: 'FIQ 2',
          product: 'Hidratado',
        ),
        ClientEquipment(
          id: 'm-2',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 2',
          serialNumber: '002-01-713',
          presetTag: 'FIQ 2',
          product: 'Hidratado',
        ),
      ],
    );
    final slots = [
      OsCalibrationSlot(
        id: 'v1',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0004',
        equipmentId: 'm-1',
        equipmentTag: 'FT 1',
        serialNumber: '002-01-588',
        presetTag: 'FIQ 2',
        product: 'Hidratado',
      ),
      OsCalibrationSlot(
        id: 'v2',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0006',
        // Slot vazio — não pode herdar o N/S do anterior.
      ),
    ];
    final refreshed = refreshOsCalibrationSlots(slots: slots, client: client);
    expect(refreshed[0].serialNumber, '002-01-588');
    expect(refreshed[1].serialNumber, isNot(equals('002-01-588')));
    expect(refreshed[1].serialNumber, '002-01-713');
    expect(refreshed[1].equipmentTag, 'FT 2');
  });

  test('certificado preenchido sobrescreve TAG/N/S contaminados do slot', () {
    final slots = [
      OsCalibrationSlot(
        id: 'v1',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0003',
        equipmentTag: 'FT 6.2',
        serialNumber: '002-01-679',
        product: 'B100',
        presetTag: 'FIQ 4.1',
      ),
    ];
    final jobs = [
      CalibrationJob(
        id: 'job-1',
        number: 'GS-VOL-2026-0003',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 18),
        osId: 'os-045',
        osNumber: '045/26',
        equipmentTag: 'FT 1',
        serialNumber: '002-01-604',
        fluid: 'Hidratado',
        presetTag: 'FIQ 1',
        calibrationSlotId: 'v1',
      ),
    ];
    final enriched = enrichOsSlotsFromCalibrationJobs(
      slots: slots,
      jobs: jobs,
      osId: 'os-045',
      osNumber: '045/26',
    );
    expect(enriched.first.equipmentTag, 'FT 1');
    expect(enriched.first.serialNumber, '002-01-604');
    // Produto do slot (lápis) não é sobrescrito pelo fluido do job.
    expect(enriched.first.product, 'B100');
    expect(enriched.first.presetTag, 'FIQ 1');
  });

  test('cadastro aplica produto do Excel no fluido do certificado', () {
    final job = CalibrationJob(
      id: 'j1',
      number: 'GS-VOL-2026-0026',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 18),
      fluid: 'Gasolina',
      presetTag: 'FIQ 1.1',
      equipmentTag: 'FT 3.1',
    );
    final equipment = ClientEquipment(
      id: 'eq1',
      tag: 'FT 3.1',
      serialNumber: '002-01-707',
      presetTag: 'FIQ 1.1',
      product: 'S500',
      equipmentType: 'Medidor',
      instrumentRole: 'Medidor',
    );
    final next = applyClientEquipmentToCalibrationJob(job, equipment);
    expect(next.fluid, 'S500');
    expect(next.presetTag, 'FIQ 1.1');
  });

  test('lista mostra o fluido do certificado; o lápis da OS sincroniza', () {
    final slot = OsCalibrationSlot(
      id: 'v1',
      kind: CalibrationKind.volumetric.name,
      certificateNumber: 'GS-VOL-2026-0026',
      product: 'S500',
      presetTag: 'FIQ 1.1',
      equipmentTag: 'FT 3.4',
    );
    final job = CalibrationJob(
      id: 'job-26',
      number: 'GS-VOL-2026-0026',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 19),
      fluid: 'Gasolina',
      presetTag: 'FIQ 1.1',
      equipmentTag: 'FT 3.4',
    );
    expect(osCalibrationSlotDetailLine(slot, job: job), contains('Gasolina'));
    final synced = applyOsSlotInstrumentToCalibrationJob(job, slot);
    expect(synced.fluid, 'S500');
    expect(osCalibrationSlotDetailLine(slot, job: synced), contains('S500'));
  });

  test('N/S do preset nunca vira N/S do medidor', () {
    const equipment = ClientEquipment(
      id: 'm-1',
      equipmentType: 'Medidor',
      instrumentRole: 'Medidor',
      presetTag: 'FIQ 3.1',
      presetSerial: 'PRESET-LEFT',
      tag: 'FT 3.1',
      serialNumber: '',
      product: 'S500',
    );
    final slot = OsCalibrationSlot.fromEquipment(
      id: 'v1',
      kind: CalibrationKind.volumetric.name,
      certificateNumber: 'GS-VOL-2026-0064',
      equipment: equipment,
    );
    expect(slot.serialNumber, isEmpty);
    expect(slot.presetSerial, 'PRESET-LEFT');
    expect(slot.equipmentTag, 'FT 3.1');
  });

  test('refresh usa produto do Excel mesmo em slot confirmado', () {
    final client = SavedClient(
      id: 'c1',
      name: 'Phoenix',
      equipment: const [
        ClientEquipment(
          id: 'm-1',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 4.2',
          serialNumber: 'METER-RIGHT',
          presetTag: 'FIQ 4.2',
          presetSerial: 'PRESET-LEFT',
          product: 'B100',
        ),
      ],
      updatedAt: DateTime(2026, 9, 22),
    );
    final refreshed = refreshOsCalibrationSlots(
      slots: [
        OsCalibrationSlot(
          id: 'v1',
          kind: CalibrationKind.volumetric.name,
          certificateNumber: 'GS-VOL-2026-0066',
          equipmentId: 'm-1',
          equipmentTag: 'FT 4.2',
          serialNumber: 'PRESET-LEFT',
          presetTag: 'FIQ 4.2',
          presetSerial: 'PRESET-LEFT',
          product: 'Anidro',
          dataCheck: 'confirmed',
        ),
      ],
      client: client,
    );
    expect(refreshed.single.product, 'B100');
    expect(refreshed.single.serialNumber, 'METER-RIGHT');
    expect(refreshed.single.presetSerial, 'PRESET-LEFT');
  });

  test('job concluído com TAG/N/S fica em com cadastro', () {
    final slot = OsCalibrationSlot(
      id: 'v1',
      kind: CalibrationKind.volumetric.name,
      certificateNumber: 'GS-VOL-2026-0064',
    );
    final job = CalibrationJob(
      id: 'job-64',
      number: slot.certificateNumber,
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 22),
      status: CalibrationJobStatus.done,
      equipmentTag: 'FT 3.1',
      serialNumber: 'METER-31',
    );
    final groups = groupCalibrationSlotsByKind(
      [slot],
      isCadastroPending: (item) => calibrationSlotNeedsCadastro(item, job: job),
    );
    expect(groups.single.withCadastro.length, 1);
    expect(groups.single.cadastroPendente, isEmpty);
  });

  test('job órfão sem OS nem slot não entra em outra OS pelo número', () {
    final job = CalibrationJob(
      id: 'orphan',
      number: 'GS-VOL-2026-0066',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 22),
      equipmentTag: 'Plact 1',
      serialNumber: 'FOREIGN',
    );
    expect(
      calibrationJobsForOs(
        [job],
        osId: 'os-043',
        osNumber: '043/26',
        slotIds: ['slot-043'],
      ),
      isEmpty,
    );
  });

  test('órfão com N/S duplicado é limpo no refresh', () {
    final slots = [
      OsCalibrationSlot(
        id: 'v1',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0004',
        jobId: 'job-4',
        equipmentTag: 'FT 2',
        serialNumber: '002-01-588',
        product: 'Hidratado',
      ),
      OsCalibrationSlot(
        id: 'v2',
        kind: CalibrationKind.volumetric.name,
        certificateNumber: 'GS-VOL-2026-0006',
        equipmentTag: 'FT 2',
        serialNumber: '002-01-588',
        product: 'Hidratado',
      ),
    ];
    final jobs = [
      CalibrationJob(
        id: 'job-4',
        number: 'GS-VOL-2026-0004',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 18),
        serialNumber: '002-01-588',
        equipmentTag: 'FT 2',
        fluid: 'Hidratado',
      ),
    ];
    final cleared = clearDuplicateOrphanSlotSerials(slots, jobs: jobs);
    expect(cleared[0].serialNumber, '002-01-588');
    expect(cleared[1].serialNumber, isEmpty);
    expect(cleared[1].product, isEmpty);
  });

  test('puxar cadastro com produto vazio NÃO apaga fluido do certificado', () {
    final job = CalibrationJob(
      id: 'job-rv',
      number: 'GS-VOL-2026-0010',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 8, 4),
      fluid: 'Gasolina',
      equipmentTag: 'FT 8.1',
      serialNumber: '002-01-721',
      equipmentId: 'eq1',
    );
    const emptyProduct = ClientEquipment(
      id: 'eq1',
      equipmentType: 'Medidor',
      instrumentRole: 'Medidor',
      tag: 'FT 8.1',
      serialNumber: '002-01-721',
      product: '',
    );
    final wiped = applyClientEquipmentToCalibrationJob(
      job,
      emptyProduct,
      overwriteIdentity: true,
    );
    expect(wiped.fluid, 'Gasolina');
    expect(wiped.equipmentTag, 'FT 8.1');
  });

  test('puxar cadastro com produto válido atualiza fluido', () {
    final job = CalibrationJob(
      id: 'job-rv',
      number: 'GS-VOL-2026-0015',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 1),
      fluid: 'Anidro',
      equipmentTag: 'FT 4.2',
      equipmentId: 'eq-b100',
    );
    const excel = ClientEquipment(
      id: 'eq-b100',
      equipmentType: 'Medidor',
      instrumentRole: 'Medidor',
      tag: 'FT 4.2',
      serialNumber: 'SN-B100',
      product: 'B100',
    );
    final next = applyClientEquipmentToCalibrationJob(
      job,
      excel,
      overwriteIdentity: true,
    );
    expect(next.fluid, 'B100');
    expect(next.serialNumber, 'SN-B100');
  });

  test('merge slot: Excel sem produto preserva produto do slot', () {
    final merged = mergeSlotWithEquipment(
      slot: const OsCalibrationSlot(
        id: 'v1',
        kind: 'volumetric',
        certificateNumber: 'GS-VOL-2026-0028',
        product: 'Anidro',
        equipmentTag: 'FT 8.1',
      ),
      equipment: const ClientEquipment(
        id: 'eq1',
        equipmentType: 'Medidor',
        instrumentRole: 'Medidor',
        tag: 'FT 8.1',
        serialNumber: '002-01-677',
        product: '',
      ),
    );
    expect(merged.product, 'Anidro');
    expect(merged.serialNumber, '002-01-677');
  });

  test('recupera fluid vazio do slot sem tocar o que já tem valor', () {
    final empty = CalibrationJob(
      id: 'job-rv',
      number: 'GS-VOL-2026-0010',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 8, 4),
      fluid: '',
      equipmentTag: 'FT 8.1',
      serialNumber: '002-01-721',
    );
    const slot = OsCalibrationSlot(
      id: 'v1',
      kind: 'volumetric',
      certificateNumber: 'GS-VOL-2026-0010',
      product: 'Gasolina',
      equipmentTag: 'FT 8.1',
      serialNumber: '002-01-721',
    );
    final restored = restoreEmptyFluidFromSources(empty, slot: slot);
    expect(restored.fluid, 'Gasolina');

    final kept = restoreEmptyFluidFromSources(
      empty.copyWith(fluid: 'Anidro'),
      slot: slot,
    );
    expect(kept.fluid, 'Anidro');
  });

  test('slot sobressalente não herda medidor do cadastro ao criar job', () {
    final os = SavedOs(
      id: 'os-043',
      number: '043/26',
      createdAt: DateTime(2026, 9, 24),
      ownerEmail: 'tec@gs.com',
      files: const [],
      calibrationSlots: const [
        OsCalibrationSlot(
          id: 'slot-orphan',
          kind: 'volumetric',
          certificateNumber: 'GS-VOL-2026-0060',
        ),
      ],
    );
    final slot = os.calibrationSlots.first;
    expect(slot.needsCadastro, isTrue);
    expect(calibrationSlotIsOrphanWithoutJob(slot), isTrue);

    final job = jobFromOsCalibrationSlot(
      os: os,
      slot: slot,
      technicianName: 'Técnico',
    );
    expect(job.number, 'GS-VOL-2026-0060');
    expect(job.equipmentTag, isEmpty);
    expect(job.serialNumber, isEmpty);
    expect(job.equipmentId, isEmpty);
    expect(job.presetTag, isEmpty);
  });

  test('applyCalibrationJobToOsSlot alinha nº do slot ao do certificado', () {
    const slot = OsCalibrationSlot(
      id: 'slot-b',
      kind: 'volumetric',
      certificateNumber: 'GS-VOL-2026-0060',
    );
    final job = CalibrationJob(
      id: 'job-b',
      number: 'GS-VOL-2026-0146',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 24),
      calibrationSlotId: 'slot-b',
    );
    final synced = applyCalibrationJobToOsSlot(slot, job);
    expect(synced.certificateNumber, 'GS-VOL-2026-0146');
    expect(synced.jobId, 'job-b');
  });

  test('PDF e lista não misturam medidores; divergência com a OS aparece', () {
    const slot = OsCalibrationSlot(
      id: 'v3',
      kind: 'volumetric',
      certificateNumber: 'GS-VOL-2026-0003',
      equipmentTag: 'FT 1',
      serialNumber: '002-01-604',
      presetTag: 'FIQ 1',
      product: 'Gasolina',
      manufacturer: 'ZYLIX',
      model: 'TRB-9000',
    );
    final job = CalibrationJob(
      id: 'job-3',
      number: 'GS-VOL-2026-0003',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 8, 31),
      equipmentTag: 'FT 2',
      serialNumber: '002-01-588',
      presetTag: 'FIQ 2',
      fluid: 'Hidratado',
      equipmentId: 'meter-588',
      systemId: 'sys-fiq-2',
      calibrationSlotId: 'v3',
    );
    final printed = calibrationJobForCertificatePrint(job, slot: slot);
    expect(printed.equipmentTag, 'FT 2');
    expect(printed.serialNumber, '002-01-588');
    expect(printed.presetTag, 'FIQ 2');
    expect(printed.fluid, 'Hidratado');
    expect(osCalibrationSlotDetailLine(slot, job: job), contains('N/S 002-01-588'));
    expect(osCalibrationSlotDetailLine(slot, job: job), contains('Difere da OS'));
    expect(calibrationSlotJobMismatch(slot, job), [
      'TAG FT 1',
      'N/S 002-01-604',
      'Preset FIQ 1',
    ]);

    final fixed = applyOsSlotInstrumentToCalibrationJob(job, slot);
    expect(calibrationSlotJobMismatch(slot, fixed), isEmpty);
    final printedFixed = calibrationJobForCertificatePrint(fixed, slot: slot);
    expect(printedFixed.equipmentTag, 'FT 1');
    expect(printedFixed.serialNumber, '002-01-604');
    expect(printedFixed.presetTag, 'FIQ 1');

    final listed = calibrationJobForCertificatePrint(
      job.copyWith(equipmentTag: '', presetTag: '', serialNumber: ''),
      slot: slot,
    );
    expect(listed.equipmentTag, 'FT 1');
    expect(listed.serialNumber, '002-01-604');
    expect(listed.presetTag, 'FIQ 1');
  });

  test('PDF não pega a primeira plataforma do mesmo local', () {
    final job = CalibrationJob(
      id: 'job-3',
      number: 'GS-VOL-2026-0003',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 8, 31),
      equipmentTag: 'FT 1',
      serialNumber: '002-01-604',
      presetTag: 'FIQ 1',
      installLocation: 'Plataforma 1',
      systemId: 'sys-2',
    );
    final systems = [
      ClientSystem(
        id: 'sys-2',
        systemType: 'Sistema de Carregamento',
        installLocation: 'Plataforma 1',
        assemblyTag: 'FIQ 2',
        instruments: const [
          ClientInstrument(
            id: 'm588',
            tag: 'FT 2',
            serialNumber: '002-01-588',
            manufacturer: 'ZYLIX',
            model: 'TRB-9000',
          ),
          ClientInstrument(
            id: 'te2',
            role: ClientInstrumentRole.pt100,
            tag: 'TE 2',
            serialNumber: '41327/1',
          ),
        ],
      ),
      ClientSystem(
        id: 'sys-1',
        systemType: 'Sistema de Carregamento',
        installLocation: 'Plataforma 1',
        assemblyTag: 'FIQ 1',
        instruments: const [
          ClientInstrument(
            id: 'm604',
            tag: 'FT 1',
            serialNumber: '002-01-604',
            manufacturer: 'ZYLIX',
            model: 'TRB-9000',
          ),
          ClientInstrument(
            id: 'te1',
            role: ClientInstrumentRole.pt100,
            tag: 'TE 1',
            serialNumber: '41327/2',
          ),
        ],
      ),
    ];
    final system = systemForCertificate(
      job,
      systems: systems,
      equipment: const [],
    );
    expect(system?.id, 'sys-1');
    expect(system?.assemblyTag, 'FIQ 1');
    expect(meterForCertificate(system, job)?.serialNumber, '002-01-604');
    expect(meterForCertificate(system, job)?.tag, 'FT 1');
  });

  test('cadastro não troca o N/S 604 pelo medidor 588 do mesmo local', () {
    final client = SavedClient(
      id: 'phoenix',
      name: 'PHOENIX',
      updatedAt: DateTime(2026, 9, 1),
      equipment: const [
        ClientEquipment(
          id: 'meter-604',
          systemId: 'sys-1',
          systemType: 'Sistema de Carregamento',
          installLocation: 'Plataforma 1',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 1',
          serialNumber: '002-01-604',
          presetTag: 'FIQ 1',
          product: 'Gasolina',
        ),
        ClientEquipment(
          id: 'meter-588',
          systemId: 'sys-2',
          systemType: 'Sistema de Carregamento',
          installLocation: 'Plataforma 1',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 2',
          serialNumber: '002-01-588',
          presetTag: 'FIQ 2',
          product: 'Hidratado',
        ),
      ],
    );
    final job = CalibrationJob(
      id: 'job-3',
      number: 'GS-VOL-2026-0003',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 8, 31),
      equipmentTag: 'FT 1',
      serialNumber: '002-01-604',
      presetTag: 'FIQ 1',
      fluid: 'Gasolina',
      equipmentId: 'meter-588',
      installLocation: 'Plataforma 1',
      systemType: 'Sistema de Carregamento',
    );
    const slot = OsCalibrationSlot(
      id: 'v3',
      kind: 'volumetric',
      certificateNumber: 'GS-VOL-2026-0003',
      equipmentTag: 'FT 1',
      serialNumber: '002-01-604',
      presetTag: 'FIQ 1',
      product: 'Gasolina',
    );
    final filled = fillCalibrationJobInstrumentFromClient(
      job,
      client,
      slot: slot,
    );
    expect(filled.serialNumber, '002-01-604');
    expect(filled.equipmentTag, 'FT 1');
    expect(filled.presetTag, 'FIQ 1');
    expect(filled.equipmentId, isNot('meter-588'));
  });

  test('json local do cliente não duplica instrumentos que já estão no sistema', () {
    final client = SavedClient(
      id: 'c1',
      name: 'Vibra',
      updatedAt: DateTime(2026, 9, 1),
      systems: const [
        ClientSystem(
          id: 'sys-1',
          systemType: 'Carregamento',
          installLocation: 'Plataforma 1',
          assemblyTag: 'FIQ 1',
          instruments: [
            ClientInstrument(
              id: 'm1',
              tag: 'FT 1',
              serialNumber: '002-01-604',
              equipmentType: 'Medidor',
            ),
          ],
        ),
      ],
    );
    final full = client.toJson();
    final slim = client.toJson(slim: true);
    expect(full.containsKey('equipment'), isTrue);
    expect(slim.containsKey('equipment'), isFalse);
    final restored = SavedClient.fromJson(slim);
    expect(restored.equipment, isNotEmpty);
    expect(restored.equipment.first.serialNumber, '002-01-604');
    expect(restored.equipment.first.tag, 'FT 1');
  });

  test('puxar N/S vazio não troca certificado que já tem série', () {
    final client = SavedClient(
      id: 'phoenix',
      name: 'PHOENIX',
      updatedAt: DateTime(2026, 9, 1),
      equipment: const [
        ClientEquipment(
          id: 'meter-588',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 2',
          serialNumber: '002-01-588',
          presetTag: 'FIQ 2',
          product: 'Hidratado',
        ),
        ClientEquipment(
          id: 'meter-604',
          equipmentType: 'Medidor',
          instrumentRole: 'Medidor',
          tag: 'FT 1',
          serialNumber: '002-01-604',
          presetTag: 'FIQ 1',
          product: 'Gasolina',
        ),
      ],
    );
    final refreshed = refreshOsCalibrationSlots(
      slots: const [
        OsCalibrationSlot(
          id: 'v3',
          kind: 'volumetric',
          certificateNumber: 'GS-VOL-2026-0003',
          equipmentId: 'meter-588',
          equipmentTag: 'FT 1',
          serialNumber: '002-01-604',
          presetTag: 'FIQ 1',
          product: 'Gasolina',
        ),
        OsCalibrationSlot(
          id: 'v-empty',
          kind: 'volumetric',
          certificateNumber: 'GS-VOL-2026-0099',
        ),
      ],
      client: client,
      onlyFillEmptySerial: true,
    );
    expect(refreshed[0].serialNumber, '002-01-604');
    expect(refreshed[0].equipmentTag, 'FT 1');
    expect(refreshed[0].product, 'Gasolina');
    expect(refreshed[1].serialNumber, isNot('002-01-604'));
  });
}
