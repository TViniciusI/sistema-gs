import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cnpj = '34.274.233/0025-71';

ClientSystem _ilha(String id, String tag) => ClientSystem(
  id: id,
  systemType: 'Sistema de Carregamento',
  installLocation: 'Plataforma de Carregamento',
  tag: tag,
  kind: ClientAssemblyKind.preset,
  instruments: [ClientInstrument(id: '$id-m', tag: tag, serialNumber: 'SN$id')],
);

SavedClient _cliente(String id, String name, List<ClientSystem> systems) =>
    SavedClient(
      id: id,
      name: name,
      cnpj: _cnpj,
      systems: systems,
      equipment: flattenClientSystems(systems),
      updatedAt: DateTime(2026, 11, 19, 14, 53),
    );

final _real = _cliente('1790155180581', 'Vibra Energia - BABET', [
  _ilha('101', 'Ilha 1'),
  _ilha('102', 'Ilha 2'),
  _ilha('103', 'Ilha 3'),
]);

Map<String, dynamic> _stub(SavedClient client) => {
  'id': client.id,
  'name': client.name,
  'cnpj': client.cnpj,
  'updatedAt': client.updatedAt.toIso8601String(),
  '_fileId': 'drive-${client.id}',
  '_payloadLight': true,
};

Future<void> _device(List<SavedClient> local) async {
  SharedPreferences.setMockInitialValues({
    'gs_clients_v1': jsonEncode([for (final c in local) c.toJson()]),
    'gs_clients_cloud_stamp_v1': jsonEncode({
      for (final c in local) c.id: c.updatedAt.toIso8601String(),
    }),
  });
  ClientStore.instance.resetForTest();
}

List<String> _ids() => [for (final c in ClientStore.instance.items) c.id];

void main() {
  test(
    'outro cadastro da nuvem com o mesmo CNPJ não substitui o real',
    () async {
      await _device([_real]);
      final outro = _cliente('1799999999999', 'BABET filial', [
        _ilha('201', 'Preset P26'),
      ]).copyWith(updatedAt: DateTime(2026, 11, 26, 14, 11));

      await ClientStore.instance.load(
        remoteClients: [_real.toJson(), outro.toJson()],
      );

      expect(_ids(), containsAll([_real.id, outro.id]));
      final real = ClientStore.instance.byId(_real.id)!;
      expect(real.resolvedSystems.map((s) => s.id), ['101', '102', '103']);
      expect(real.name, 'Vibra Energia - BABET');
      expect(
        ClientStore.instance.byId(outro.id)!.resolvedSystems,
        hasLength(1),
      );
    },
  );

  test(
    'aparelho contaminado pelo cliente de teste volta a ter o BABET real',
    () async {
      final vazado = _cliente('babet', 'Vibra Energia - BABET', [
        _ilha('1', 'Preset P26'),
      ]).copyWith(updatedAt: DateTime(2026, 11, 26, 14, 11));
      await _device([vazado]);

      await ClientStore.instance.load(
        remoteClients: [_stub(_real), vazado.toJson()],
      );

      expect(ClientStore.instance.byId('babet'), isNull);
      expect(_ids(), contains(_real.id));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('gs_clients_deleted_ids_v1'),
        contains('babet'),
      );
      expect(prefs.getString('gs_clients_v1'), isNot(contains('"babet"')));
    },
  );

  test('cliente de teste da nuvem nunca entra num aparelho limpo', () async {
    await _device([_real]);
    final vazado = _cliente('babet', 'BABET', [_ilha('1', 'Preset P26')]);

    await ClientStore.instance.load(
      remoteClients: [_real.toJson(), vazado.toJson()],
    );

    expect(_ids(), [_real.id]);
    expect(ClientStore.instance.byId(_real.id)!.resolvedSystems, hasLength(3));
  });

  test('cadastro criado offline ainda se liga ao da nuvem pelo CNPJ', () async {
    final offline = _cliente('local-1', 'Vibra Energia - BABET', [
      _ilha('101', 'Ilha 1'),
    ]).copyWith(updatedAt: DateTime(2026, 11, 1));
    SharedPreferences.setMockInitialValues({
      'gs_clients_v1': jsonEncode([offline.toJson()]),
    });
    ClientStore.instance.resetForTest();

    await ClientStore.instance.load(remoteClients: [_real.toJson()]);

    expect(_ids(), [_real.id]);
    expect(ClientStore.instance.byId(_real.id)!.resolvedSystems, hasLength(3));
  });
}
