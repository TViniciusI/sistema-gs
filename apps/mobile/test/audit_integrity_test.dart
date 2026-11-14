// Auditoria: cada teste afirma o comportamento CORRETO. Falha = defeito.
// Sem rede: qualquer conexão é recusada (nada chega à planilha de produção).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException('rede bloqueada no teste');
}

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

ClientSystem _preset(
  String id,
  String island,
  String preset,
  List<ClientInstrument> meters, {
  String serial = '',
}) => ClientSystem(
  id: id,
  systemType: 'Sistema de Carregamento',
  installLocation: 'Plataforma de Carregamento',
  tag: island,
  kind: ClientAssemblyKind.preset,
  manufacturer: 'Daniel Measurement',
  model: 'DL6000',
  assemblyTag: preset,
  serialNumber: serial,
  meterCount: meters.length,
  instruments: meters,
).syncedCounts();

List<ClientSystem> _apply(
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

OsCalibrationSlot _volSlot(String id, int n, {String tag = '', String sn = ''}) =>
    OsCalibrationSlot(
      id: id,
      kind: 'volumetric',
      certificateNumber: 'GS-VOL-2026-${n.toString().padLeft(4, '0')}',
      equipmentTag: tag,
      serialNumber: sn,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cadastro (ilhas/presets/medidores)', () {
    final islands = [
      _preset('i1p01', 'Ilha 1', 'P01', [
        _meter('ga', 'GA', 'SN-GA'),
        _meter('aa', 'AA', 'SN-AA'),
      ]),
      _preset('i1p03', 'Ilha 1', 'P03', [
        _meter('da', 'DA', 'SN-DA'),
        _meter('ba', 'BA', 'SN-BA-B100'),
      ]),
      _preset('i2p01', 'Ilha 2', 'P01', [
        _meter('gb', 'GB', 'SN-GB'),
        _meter('ab', 'AB', 'SN-AB'),
      ]),
    ];

    test('slot velho (systemId do P01, dados do P03) não renomeia o P01', () {
      const stale = OsCalibrationSlot(
        id: 'stale',
        kind: 'volumetric',
        certificateNumber: 'GS-VOL-2026-0231',
        equipmentId: 'ga',
        equipmentTag: 'GA',
        serialNumber: 'SN-GA',
        equipmentType: 'Medidor',
        systemId: 'i1p01',
        systemTag: 'Ilha 1',
        assemblyKind: 'preset',
        presetTag: 'P03',
        presetSerial: 'SN-BA-B100',
        instrumentRole: 'meter',
      );
      final after = _apply(islands, [stale]);
      final p01 = after.firstWhere((s) => s.id == 'i1p01');
      expect(p01.assemblyTag, 'P01', reason: 'P01 virou P03');
      expect(p01.serialNumber, isEmpty, reason: 'N/S vazio do preset foi preenchido');
    });

    test('slot sem ilha não altera o P01 de outra ilha', () {
      const noIsland = OsCalibrationSlot(
        id: 'semilha',
        kind: 'volumetric',
        certificateNumber: 'GS-VOL-2026-0300',
        equipmentTag: 'XX',
        serialNumber: 'SN-XX',
        equipmentType: 'Medidor',
        assemblyKind: 'preset',
        presetTag: 'P01',
        instrumentRole: 'meter',
      );
      final after = _apply(islands, [noIsland]);
      expect(after.firstWhere((s) => s.id == 'i1p01').meters, hasLength(2));
      expect(after.firstWhere((s) => s.id == 'i2p01').meters, hasLength(2));
    });

    test('slots vazios do P01 não aumentam 2 medidores para 5', () {
      final empties = [
        for (var i = 0; i < 3; i++)
          OsCalibrationSlot(
            id: 'vazio$i',
            kind: 'volumetric',
            certificateNumber: 'GS-VOL-2026-04$i',
            equipmentId: 'id-de-outro-navegador-$i',
            equipmentType: 'Medidor',
            systemId: 'i1p01',
            systemTag: 'Ilha 1',
            assemblyKind: 'preset',
            presetTag: 'P01',
            instrumentRole: 'meter',
          ),
      ];
      final after = _apply(islands, empties);
      final p01 = after.firstWhere((s) => s.id == 'i1p01');
      expect(p01.meters, hasLength(2), reason: 'medidores: ${p01.meters.length}');
      expect(p01.meterCount, 2);
    });

    test('reduzir de 5 para 2 medidores sobrevive à releitura (JSON)', () {
      final five = _preset('p', 'Ilha 1', 'P01', [
        for (var i = 0; i < 5; i++) _meter('m$i', 'T$i', 'SN$i'),
      ]);
      final two = five.copyWith(
        meterCount: 2,
        instruments: five.instruments.take(2).toList(),
      );
      final again = ClientSystem.fromJson(
        jsonDecode(jsonEncode(two.toJson())) as Map<String, dynamic>,
      );
      expect(again.meters, hasLength(2));
      expect(again.meterCount, 2);
    });

    test('editar um preset (rebase com a nuvem) não mexe nos outros', () {
      final base = SavedClient(
        id: 'c1',
        name: 'Cliente',
        cnpj: '',
        updatedAt: DateTime(2026, 10, 1),
        systems: islands,
      );
      final draft = base.copyWith(
        systems: [
          for (final s in islands)
            s.id == 'i1p03' ? s.copyWith(model: 'Novo modelo') : s,
        ],
      );
      final cloud = base.copyWith(
        systems: [
          for (final s in islands)
            s.id == 'i2p01' ? s.copyWith(manufacturer: 'Outro (nuvem)') : s,
        ],
      );
      final merged = rebaseClientEdit(draft: draft, base: base, cloud: cloud);
      final byId = {for (final s in merged.resolvedSystems) s.id: s};
      expect(byId['i1p03']!.model, 'Novo modelo');
      expect(byId['i2p01']!.manufacturer, 'Outro (nuvem)');
      expect(
        jsonEncode(byId['i1p01']!.toJson()),
        jsonEncode(islands.first.toJson()),
      );
    });
  });

  group('certificados da OS', () {
    test('dedupe não descarta certificado legítimo com nº repetido', () {
      final slots = [
        _volSlot('a', 231, tag: 'GA', sn: 'SN-GA'),
        _volSlot('b', 231, tag: 'AA', sn: 'SN-AA'),
      ];
      final out = dedupeCalibrationSlotsByCertificateNumber(slots);
      expect(out.map((s) => s.id).toSet(), {'a', 'b'});
    });

    test('62 vol + 5 temp + 5 dens = 72 certificados; vazios contados à parte',
        () {
      final slots = <OsCalibrationSlot>[
        for (var i = 0; i < 62; i++)
          i < 49
              ? _volSlot('v$i', 231 + i, tag: 'T$i', sn: 'SN$i')
              : _volSlot('v$i', 231 + i),
        for (var i = 0; i < 5; i++)
          OsCalibrationSlot(
            id: 't$i',
            kind: 'temperature',
            certificateNumber: 'GS-TMP-2026-00$i',
          ),
        for (var i = 0; i < 5; i++)
          OsCalibrationSlot(
            id: 'd$i',
            kind: 'density',
            certificateNumber: 'GS-DEN-2026-00$i',
          ),
      ];
      expect(dedupeCalibrationSlotsByCertificateNumber(slots), hasLength(72));
      final empty = slots
          .where((s) => calibrationSlotIsOrphanWithoutJob(s, job: null))
          .length;
      expect(empty, 13 + 5 + 5);
    });
  });

  group('sincronização e falhas (sem rede)', () {
    setUp(() {
      HttpOverrides.global = _NoNetwork();
      AccountApi.useRemote = true;
    });
    tearDown(() {
      HttpOverrides.global = null;
      AccountApi.useRemote = false;
    });

    SavedOs os(List<OsCalibrationSlot> slots) => SavedOs(
      id: 'audit-os',
      number: 'AUD/26',
      ownerEmail: 'a@gs',
      createdAt: DateTime(2026, 9, 1),
      files: const [],
      status: OsStatus.emAndamento,
      calibrationSlots: slots,
      updatedAt: DateTime(2026, 10, 1),
    );

    test('falha ao gravar na nuvem é informada ao usuário', () async {
      SharedPreferences.setMockInitialValues({
        'gs_work_orders_v2': jsonEncode([
          os([_volSlot('s1', 1, tag: 'A')]).toJson(),
        ]),
      });
      await FieldStore.instance.load('a@gs', seeAll: true);
      await expectLater(
        FieldStore.instance.saveCalibrationSlots(
          osId: 'audit-os',
          slots: [_volSlot('s1', 1, tag: 'A'), _volSlot('s2', 2, tag: 'B')],
        ),
        throwsA(isA<CloudSyncException>()),
      );
    });

    test('apagar TODOS os certificados da OS chega à nuvem', () async {
      // Simula: aparelho apaga os 2; a nuvem continua devolvendo os 2.
      SharedPreferences.setMockInitialValues({
        'gs_work_orders_v2': jsonEncode([
          os([_volSlot('s1', 1, tag: 'A'), _volSlot('s2', 2, tag: 'B')])
              .toJson(),
        ]),
      });
      await FieldStore.instance.load('a@gs', seeAll: true);
      try {
        await FieldStore.instance.saveCalibrationSlots(
          osId: 'audit-os',
          slots: const [],
        );
      } on CloudSyncException {
        // sem rede
      }
      AccountApi.useRemote = false;
      await FieldStore.instance.load(
        'a@gs',
        seeAll: true,
        remoteOrders: [
          os([_volSlot('s1', 1, tag: 'A'), _volSlot('s2', 2, tag: 'B')])
              .toJson(),
        ],
      );
      final local = FieldStore.instance.byId('audit-os')!;
      // Correto = aparelho e nuvem iguais. Aqui o aparelho esconde (0) e a
      // nuvem mantém (2): outro navegador continua vendo os 2.
      expect(
        local.calibrationSlots.length,
        2,
        reason: 'aparelho mostra ${local.calibrationSlots.length}, nuvem 2',
      );
    });
  });

  group('dados reais (somente leitura, arquivos baixados)', () {
    final dir = Platform.environment['GS_PROBE_DIR'];
    final hasData = dir != null && File('$dir/os048_cloud_now.json').existsSync();

    test('OS 048 na nuvem: contagem por tipo e vazios', () {
      final raw = jsonDecode(File('$dir/os048_cloud_now.json').readAsStringSync());
      final order = SavedOs.fromJson(
        Map<String, dynamic>.from(raw['order'] ?? (raw['orders'] as List).first),
      );
      final byKind = <String, int>{};
      for (final s in order.calibrationSlots) {
        byKind[s.kind] = (byKind[s.kind] ?? 0) + 1;
      }
      final numbers = order.calibrationSlots
          .map((s) => s.certificateNumber.trim().toUpperCase())
          .where((n) => n.isNotEmpty)
          .toList();
      final ids = order.calibrationSlots.map((s) => s.id).toList();
      final empty = order.calibrationSlots.where((s) => s.needsCadastro);
      final emptyByKind = <String, int>{};
      for (final s in empty) {
        emptyByKind[s.kind] = (emptyByKind[s.kind] ?? 0) + 1;
      }
      // ignore: avoid_print
      print(
        'OS 048: total ${order.calibrationSlots.length} por tipo $byKind | '
        'sem TAG/N/S ${empty.length} $emptyByKind | '
        'nº repetidos ${numbers.length - numbers.toSet().length} | '
        'ids repetidos ${ids.length - ids.toSet().length}',
      );
      expect(numbers.toSet(), hasLength(numbers.length));
      expect(ids.toSet(), hasLength(ids.length));
    }, skip: hasData ? false : 'sem GS_PROBE_DIR');
  });
}
