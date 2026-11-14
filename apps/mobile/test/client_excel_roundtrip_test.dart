import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/models.dart';

String _row(ClientEquipment m, List<ClientEquipment> all) {
  final pt = all.where(
    (e) =>
        e.systemId == m.systemId &&
        clientInstrumentRoleFrom(e.instrumentRole) == ClientInstrumentRole.pt100,
  );
  return [
    m.installLocation,
    m.presetTag,
    m.presetSerial,
    m.tag,
    m.serialNumber,
    m.product,
    pt.isEmpty ? '' : pt.first.tag,
    pt.isEmpty ? '' : pt.first.serialNumber,
  ].join(' | ');
}

List<String> _meterRows(SavedClient client) {
  final all = client.equipment;
  return [
    for (final m in all)
      if (clientInstrumentRoleFrom(m.instrumentRole) ==
          ClientInstrumentRole.meter)
        _row(m, all),
  ]..sort();
}

void main() {
  test('baixar e importar o Excel do cliente não muda nenhum instrumento', () {
    final raw = jsonDecode(
      File('tool/GS_cliente_phoenix_nuvem.json').readAsStringSync(),
    );
    final client = SavedClient.fromJson(Map<String, dynamic>.from(raw as Map));
    final bytes = buildClientExcelTemplate(clients: [client]);
    final parsed = parseClientWorkbook(bytes);
    final systems = systemsFromEquipment([
      for (final row in parsed.instruments) row.equipment,
    ]);
    final back = client.copyWith(
      systems: systems,
      equipment: flattenClientSystems(systems),
    );
    expect(back.resolvedSystems.length, client.resolvedSystems.length);
    expect(_meterRows(back), _meterRows(client));
  });

  test('reimportar o Excel mantém os ids que as OS e certificados usam', () {
    final raw = jsonDecode(
      File('tool/GS_cliente_phoenix_nuvem.json').readAsStringSync(),
    );
    final client = SavedClient.fromJson(Map<String, dynamic>.from(raw as Map));
    final bytes = buildClientExcelTemplate(clients: [client]);
    final parsed = parseClientWorkbook(bytes);
    final systems = keepCatalogIds(
      client.resolvedSystems,
      systemsFromEquipment([
        for (final row in parsed.instruments) row.equipment,
      ]),
    );
    final back = client.copyWith(
      systems: systems,
      equipment: flattenClientSystems(systems),
    );
    String identity(ClientEquipment e) =>
        '${e.id}|${e.systemId}|${e.installLocation}|${e.presetTag}|'
        '${e.tag}|${e.serialNumber}|${e.product}|${e.instrumentRole}';
    final before = [for (final e in client.equipment) identity(e)]..sort();
    final after = [for (final e in back.equipment) identity(e)]..sort();
    expect(after, before);
  });

  test('instrumento novo na planilha ganha id novo sem roubar o de outro', () {
    const old = [
      ClientSystem(
        id: 'sys-a',
        installLocation: 'Plataforma 1',
        assemblyTag: 'FIQ 1',
        kind: ClientAssemblyKind.preset,
        instruments: [
          ClientInstrument(id: 'm-a', tag: 'FT 1', serialNumber: '604'),
        ],
      ),
    ];
    const incoming = [
      ClientSystem(
        id: 'sys-new1',
        installLocation: 'Plataforma 1',
        assemblyTag: 'FIQ 1',
        kind: ClientAssemblyKind.preset,
        instruments: [
          ClientInstrument(id: 'n1', tag: 'FT 1', serialNumber: '604'),
        ],
      ),
      ClientSystem(
        id: 'sys-new2',
        installLocation: 'Plataforma 2',
        assemblyTag: 'FIQ 1',
        kind: ClientAssemblyKind.preset,
        instruments: [
          ClientInstrument(id: 'n2', tag: 'FT 1', serialNumber: '711'),
        ],
      ),
    ];
    final out = keepCatalogIds(old, incoming);
    expect(out[0].id, 'sys-a');
    expect(out[0].instruments.single.id, 'm-a');
    expect(out[1].id, 'sys-new2');
    expect(out[1].instruments.single.id, 'n2');
  });
}
