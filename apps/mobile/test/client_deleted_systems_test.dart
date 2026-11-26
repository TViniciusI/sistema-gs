import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

ClientSystem _preset(String id, String tag, {String serial = ''}) =>
    ClientSystem(
      id: id,
      systemType: 'Sistema de Carregamento',
      installLocation: 'Plataforma de Carregamento',
      tag: tag,
      kind: ClientAssemblyKind.preset,
      instruments: [
        ClientInstrument(id: '$id-m', tag: tag, serialNumber: serial),
      ],
    );

SavedClient _cliente(
  String name,
  List<ClientSystem> systems,
  int minute, {
  List<String> deleted = const [],
}) => SavedClient(
  id: 'babet',
  name: name,
  cnpj: '34.274.233/0025-71',
  systems: systems,
  deletedSystemIds: deleted,
  equipment: flattenClientSystems(systems),
  updatedAt: DateTime(2026, 11, 26, 14, minute),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ClientStore.instance.resetForTest();
  });

  final p26 = _preset('1', 'Preset P26');
  final fiq = _preset('2', 'Preset FIQ-30');

  test(
    'edição que apaga um sistema não deixa as linhas dele na lista plana',
    () {
      final base = _cliente('BABET', [p26, fiq], 0);
      final cloud = _cliente('BABET', [p26, fiq], 10);
      final draft = _cliente('BABET', [p26], 20);

      final merged = rebaseClientEdit(draft: draft, base: base, cloud: cloud);

      expect(merged.resolvedSystems.map((s) => s.id), ['1']);
      expect(merged.storedEquipment.where((e) => e.systemId == '2'), isEmpty);
    },
  );

  test(
    'sistema apagado no aparelho não volta quando a nuvem ainda tem a cópia antiga',
    () async {
      final store = ClientStore.instance;
      await store.load(
        remoteClients: [
          _cliente('BABET', [p26, fiq], 0).toJson(),
        ],
      );
      final base = store.byId('babet')!;
      expect(base.resolvedSystems.map((s) => s.id), ['1', '2']);

      await store.saveEdited(_cliente('BABET', [p26], 20), base: base);
      expect(store.byId('babet')!.resolvedSystems.map((s) => s.id), ['1']);

      await store.load(
        remoteClients: [
          _cliente('BABET', [p26, fiq], 0).toJson(),
        ],
      );

      expect(store.byId('babet')!.resolvedSystems.map((s) => s.id), ['1']);
    },
  );

  test(
    'outro aparelho apagou sistema: a cópia local antiga e maior não o devolve',
    () async {
      final store = ClientStore.instance;
      await store.load(
        remoteClients: [
          _cliente('BABET', [p26, fiq], 0).toJson(),
        ],
      );
      expect(store.byId('babet')!.resolvedSystems.map((s) => s.id), ['1', '2']);

      await store.load(
        remoteClients: [
          _cliente('BABET', [p26], 20, deleted: ['2']).toJson(),
        ],
      );

      expect(store.byId('babet')!.resolvedSystems.map((s) => s.id), ['1']);
      expect(store.byId('babet')!.deletedSystemIds, ['2']);
    },
  );

  test('o sistema apagado continua apagado depois de salvar e sincronizar', () {
    final base = _cliente('BABET', [p26, fiq], 0);
    final draft = _cliente('BABET', [p26], 20, deleted: ['2']);
    final cloud = _cliente('BABET', [p26, fiq], 10);

    final merged = rebaseClientEdit(draft: draft, base: base, cloud: cloud);
    final reloaded = SavedClient.fromJson(
      Map<String, dynamic>.from(merged.toJson()),
    );

    expect(reloaded.resolvedSystems.map((s) => s.id), ['1']);
    expect(reloaded.deletedSystemIds, ['2']);
    expect(reloaded.storedEquipment.where((e) => e.systemId == '2'), isEmpty);
  });
}
