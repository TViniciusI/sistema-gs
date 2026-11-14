import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_bundle_pdf.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/models.dart';

SavedClient _baspa() {
  final file = File('tool/GS_Calibracao_VIBRA_BASPA.xlsx');
  final parsed = parseClientWorkbook(file.readAsBytesSync());
  final systems = systemsFromEquipment([
    for (final row in parsed.instruments) row.equipment,
  ]);
  return SavedClient(
    id: 'vibra',
    name: 'VIBRA ENERGIA S.A - BASPA',
    cnpj: '34274233005910',
    systems: systems,
    equipment: flattenClientSystems(systems),
    updatedAt: DateTime(2026, 10, 1),
  );
}

void main() {
  test('BASPA: vol/temp/dens de cada ilha resolvem local e separam no book', () {
    final client = _baspa();
    final locs = {
      for (final s in client.resolvedSystems) s.installLocation.trim(),
    }..removeWhere((e) => e.isEmpty);
    expect(locs.length, greaterThanOrEqualTo(3), reason: 'ilhas=$locs');

    final jobs = <CalibrationJob>[];
    var n = 0;
    for (final system in client.resolvedSystems) {
      final local = system.installLocation.trim();
      if (local.isEmpty) continue;
      for (final meter in system.meters) {
        if (meter.serialNumber.trim().isEmpty) continue;
        n++;
        jobs.add(
          CalibrationJob(
            id: 'v$n',
            number: 'GS-VOL-2026-${n.toString().padLeft(4, '0')}',
            kind: CalibrationKind.volumetric,
            createdAt: DateTime(2026, 9, 12),
            clientId: client.id,
            clientName: client.name,
            installLocation: '', // como no bug: job sem local
            presetTag: system.assemblyTag,
            equipmentTag: meter.tag,
            serialNumber: meter.serialNumber,
            systemId: system.id,
            fluid: meter.product,
          ),
        );
      }
      for (final pt in system.pt100s) {
        if (pt.serialNumber.trim().isEmpty) continue;
        n++;
        jobs.add(
          CalibrationJob(
            id: 't$n',
            number: 'GS-TEMP-2026-${n.toString().padLeft(4, '0')}',
            kind: CalibrationKind.temperature,
            createdAt: DateTime(2026, 9, 12),
            clientId: client.id,
            clientName: client.name,
            installLocation: '',
            presetTag: system.assemblyTag,
            equipmentTag: pt.tag,
            serialNumber: pt.serialNumber,
            systemId: system.id,
          ),
        );
      }
      for (final dens in system.densimeters) {
        if (dens.serialNumber.trim().isEmpty) continue;
        n++;
        jobs.add(
          CalibrationJob(
            id: 'd$n',
            number: 'GS-DENS-2026-${n.toString().padLeft(4, '0')}',
            kind: CalibrationKind.density,
            createdAt: DateTime(2026, 9, 12),
            clientId: client.id,
            clientName: client.name,
            installLocation: '',
            presetTag: system.assemblyTag,
            equipmentTag: dens.tag,
            serialNumber: dens.serialNumber,
            systemId: system.id,
          ),
        );
      }
    }
    expect(jobs, isNotEmpty);

    for (final job in jobs) {
      final local = resolveCertificateInstallLocation(job, client: client);
      expect(
        local,
        isNotEmpty,
        reason: '${job.number} ${job.kind} sn=${job.serialNumber}',
      );
      expect(local.toLowerCase(), isNot(equals('sem local do sistema')));
      final system = systemForCertificate(
        job,
        systems: client.resolvedSystems,
        equipment: client.equipment,
      );
      expect(system, isNotNull, reason: job.number);
      expect(system!.installLocation.trim(), local);
    }

    // Sem ClientStore: agrupa pelo local já resolvido (como prepare faria com client).
    final prepared = [
      for (final job in jobs)
        job.copyWith(
          installLocation: resolveCertificateInstallLocation(job, client: client),
        ),
    ];
    final groups = groupJobsForCertificateBundle(prepared);
    final names = groups.map((g) => g.location).toList();
    expect(names, isNot(contains('Sem local do sistema')));
    expect(names.length, greaterThanOrEqualTo(3), reason: '$names');
  });

  test('TAG repetida entre ilhas não anula N/S único (bug Sem local)', () {
    const systems = [
      ClientSystem(
        id: 'sys-5b',
        installLocation: 'ILHA 5B',
        assemblyTag: 'FIQ 5B',
        instruments: [
          ClientInstrument(
            id: 'm5',
            role: ClientInstrumentRole.meter,
            tag: 'FT',
            serialNumber: 'SN-5B',
          ),
          ClientInstrument(
            id: 't5',
            role: ClientInstrumentRole.pt100,
            tag: 'TE',
            serialNumber: 'PT-5B',
          ),
        ],
      ),
      ClientSystem(
        id: 'sys-3a',
        installLocation: 'ILHA 3A',
        assemblyTag: 'FIQ 3A',
        instruments: [
          ClientInstrument(
            id: 'm3',
            role: ClientInstrumentRole.meter,
            tag: 'FT',
            serialNumber: 'SN-3A',
          ),
          ClientInstrument(
            id: 't3',
            role: ClientInstrumentRole.pt100,
            tag: 'TE',
            serialNumber: 'PT-3A',
          ),
        ],
      ),
    ];
    final vol = CalibrationJob(
      id: 'v',
      number: 'GS-VOL-2026-0001',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 11, 13),
      installLocation: '',
      equipmentTag: 'FT',
      serialNumber: 'SN-3A',
      presetTag: 'FIQ 3A',
    );
    final temp = CalibrationJob(
      id: 't',
      number: 'GS-TEMP-2026-0001',
      kind: CalibrationKind.temperature,
      createdAt: DateTime(2026, 11, 13),
      installLocation: '',
      equipmentTag: 'TE',
      serialNumber: 'PT-3A',
      presetTag: 'FIQ 3A',
    );
    expect(
      systemForCertificate(vol, systems: systems, equipment: const [])?.id,
      'sys-3a',
    );
    expect(
      systemForCertificate(temp, systems: systems, equipment: const [])?.id,
      'sys-3a',
    );
    expect(
      resolveCertificateInstallLocation(
        vol,
        systemLocal:
            systemForCertificate(vol, systems: systems, equipment: const [])!
                .installLocation,
      ),
      'ILHA 3A',
    );
  });
}
