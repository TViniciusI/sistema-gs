import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/models.dart';

SavedClient _vibraClient() {
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

List<OsCalibrationSlot> _osSlots() => [
  for (var i = 0; i < 12; i++)
    OsCalibrationSlot(
      id: 'v$i',
      kind: CalibrationKind.volumetric.name,
      certificateNumber: 'GS-VOL-2026-${(96 + i).toString().padLeft(4, '0')}',
    ),
  for (var i = 0; i < 4; i++)
    OsCalibrationSlot(
      id: 't$i',
      kind: CalibrationKind.temperature.name,
      certificateNumber: 'GS-TEMP-2026-${(40 + i).toString().padLeft(4, '0')}',
    ),
  for (var i = 0; i < 4; i++)
    OsCalibrationSlot(
      id: 'd$i',
      kind: CalibrationKind.density.name,
      certificateNumber: 'GS-DENS-2026-${(40 + i).toString().padLeft(4, '0')}',
    ),
];

Iterable<OsCalibrationSlot> _ofKind(
  List<OsCalibrationSlot> slots,
  CalibrationKind kind,
) => slots.where((s) => calibrationKindFrom(s.kind) == kind);

void main() {
  test(
    'planilha VIBRA: mesmo medidor em 3 produtos preenche os 12 certificados',
    () {
      final client = _vibraClient();
      final refreshed = refreshOsCalibrationSlots(
        slots: _osSlots(),
        client: client,
        installLocation: 'BASPA',
      );

      final vols = _ofKind(refreshed, CalibrationKind.volumetric).toList();
      expect(vols.every((s) => !s.needsCadastro), isTrue);
      final meterProduct = {
        for (final s in vols)
          '${s.serialNumber.trim()}|${s.product.trim().toLowerCase()}',
      };
      expect(meterProduct.length, 12);
      expect(
        vols.where((s) => s.serialNumber == '1407E10100').map((s) => s.product),
        containsAll(['Hidratado', 'Anidro', 'Gasolina A']),
      );

      // PT100 e densímetro têm o mesmo texto de N/S por ilha: um não bloqueia o outro.
      final temps = _ofKind(refreshed, CalibrationKind.temperature).toList();
      final dens = _ofKind(refreshed, CalibrationKind.density).toList();
      expect(temps.every((s) => !s.needsCadastro), isTrue);
      expect(dens.every((s) => !s.needsCadastro), isTrue);
      expect({for (final s in temps) s.serialNumber}.length, 4);
      expect({for (final s in dens) s.serialNumber}.length, 4);
    },
  );

  test(
    'puxar N/S troca N/S velho que não existe no cadastro (sem certificado)',
    () {
      final client = _vibraClient();
      final slots = _osSlots();
      slots[0] = slots[0].copyWith(
        equipmentTag: 'FIQ 1',
        presetTag: 'FIQ 1',
        serialNumber: '2408-51647U-1-2',
      );
      final refreshed = refreshOsCalibrationSlots(
        slots: slots,
        client: client,
        installLocation: 'BASPA',
        onlyFillEmptySerial: true,
      );
      final vols = _ofKind(refreshed, CalibrationKind.volumetric).toList();
      expect(vols.any((s) => s.serialNumber == '2408-51647U-1-2'), isFalse);
      expect(vols.every((s) => !s.needsCadastro), isTrue);
      expect(
        {for (final s in vols) '${s.serialNumber}|${s.product}'}.length,
        12,
      );
    },
  );

  test('puxar N/S mantém N/S fora do cadastro quando já há certificado', () {
    final client = _vibraClient();
    final slots = _osSlots();
    slots[0] = slots[0].copyWith(
      jobId: 'job-96',
      equipmentTag: 'FT 9',
      serialNumber: 'MANUAL-1',
    );
    final refreshed = refreshOsCalibrationSlots(
      slots: slots,
      client: client,
      onlyFillEmptySerial: true,
      jobs: [
        CalibrationJob(
          id: 'job-96',
          number: 'GS-VOL-2026-0096',
          kind: CalibrationKind.volumetric,
          createdAt: DateTime(2026, 10, 1),
          serialNumber: 'MANUAL-1',
        ),
      ],
    );
    expect(refreshed[0].serialNumber, 'MANUAL-1');
  });

  test('cadastro VIBRA gravado enxuto volta com os 36 instrumentos', () {
    final client = _vibraClient();
    expect(client.equipment.length, 36);
    final restored = SavedClient.fromJson(client.toJson(slim: true));
    expect(restored.equipment.length, 36);
    final products = {
      for (final item in restored.equipment)
        if (item.serialNumber == '1407E10100') item.product,
    };
    expect(products, containsAll(['Hidratado', 'Anidro', 'Gasolina A']));
  });
}
