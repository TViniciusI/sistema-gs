import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/models.dart';

ClientInstrument _meter(String id, String tag, String serial) =>
    ClientInstrument(
      id: id,
      role: ClientInstrumentRole.meter,
      equipmentType: 'Medidor',
      tag: tag,
      serialNumber: serial,
      manufacturer: 'Daniel Measurement',
      model: 'Turbina',
    );

ClientSystem _preset(String id, String preset, List<ClientInstrument> meters) =>
    ClientSystem(
      id: id,
      systemType: 'Sistema de Carregamento',
      installLocation: 'Plataforma de Carregamento',
      tag: 'Ilha 1',
      kind: ClientAssemblyKind.preset,
      manufacturer: 'Daniel Measurement',
      model: 'DL6000',
      assemblyTag: preset,
      meterCount: meters.length,
      instruments: meters,
    ).syncedCounts();

/// Ilha 1 da Babet: 3 presets sem N/S, o 1º com 2 medidores.
List<ClientSystem> _island() => [
  _preset('p01', 'P01', [
    _meter('ga', 'GA', 'GA - Gaso A - P01'),
    _meter('aa', 'AA', 'AA - Anidro - P01'),
  ]),
  _preset('p02', 'P02', [_meter('ha', 'HA', 'HA - Hidratado - P02')]),
  _preset('p03', 'P03', [
    _meter('da', 'DA', 'DA - S10 - P03'),
    _meter('ba', 'BA', 'BA - B100 - P03'),
  ]),
];

List<ClientSystem> _applySlots(
  List<ClientSystem> systems,
  Iterable<OsCalibrationSlot> slots,
) {
  var out = systems;
  for (final slot in slots) {
    out = mergeClientSystems(
      out,
      systemsFromEquipment(equipmentFromOsSlot(slot)),
    );
  }
  return out;
}

void main() {
  test('certificados da OS não regravam o 1º preset da ilha', () {
    final systems = _island();
    var n = 0;
    final slots = [
      for (final item in flattenClientSystems(systems))
        OsCalibrationSlot.fromEquipment(
          id: 'slot-${n++}',
          kind: 'volumetric',
          certificateNumber: 'GS-VOL-2026-${n.toString().padLeft(4, '0')}',
          equipment: item,
        ),
    ];

    final after = _applySlots(systems, slots);

    expect(after, hasLength(3));
    final p01 = after.firstWhere((s) => s.id == 'p01');
    expect(p01.assemblyTag, 'P01');
    expect(p01.serialNumber, isEmpty);
    expect(p01.meters.map((m) => m.tag), ['GA', 'AA']);
    expect(after.firstWhere((s) => s.id == 'p02').meters, hasLength(1));
    expect(after.firstWhere((s) => s.id == 'p03').meters, hasLength(2));
    expect(
      jsonEncode([for (final s in after) s.toJson()]),
      jsonEncode([for (final s in systems) s.toJson()]),
    );
  });

  test('instrumento novo na OS entra só no preset dele', () {
    final systems = _island();
    const slot = OsCalibrationSlot(
      id: 'novo',
      kind: 'volumetric',
      certificateNumber: 'GS-VOL-2026-0999',
      serialNumber: 'XX - Novo - P03',
      equipmentTag: 'XX',
      equipmentType: 'Medidor',
      systemId: 'p03',
      systemTag: 'Ilha 1',
      assemblyKind: 'preset',
      presetTag: 'P03',
      instrumentRole: 'meter',
    );

    final after = _applySlots(systems, [slot]);

    expect(after, hasLength(3));
    expect(after.firstWhere((s) => s.id == 'p01').meters, hasLength(2));
    final p03 = after.firstWhere((s) => s.id == 'p03');
    expect(p03.meters.map((m) => m.tag), ['DA', 'BA', 'XX']);
    expect(p03.serialNumber, isEmpty);
  });
}
