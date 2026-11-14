import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _osId = 'os-cloud-first';

OsCalibrationSlot _slot(String id) => OsCalibrationSlot(
  id: id,
  kind: 'volumetric',
  certificateNumber: '',
  equipmentTag: 'TAG $id',
);

SavedRdo _rdo(String id, DateTime createdAt) => SavedRdo(
  id: id,
  date: createdAt,
  clockIn: '08:00',
  lunchStart: '12:00',
  lunchEnd: '13:00',
  clockOut: '17:00',
  description: 'RDO $id',
  notes: '',
  files: const [],
  createdAt: createdAt,
);

SavedOs _os({
  required List<OsCalibrationSlot> slots,
  required List<SavedRdo> rdos,
  required DateTime updatedAt,
}) => SavedOs(
  id: _osId,
  number: '048/26',
  ownerEmail: 'teste@gs',
  createdAt: DateTime(2026, 9, 1),
  files: const [],
  status: OsStatus.emAndamento,
  calibrationSlots: slots,
  rdos: rdos,
  updatedAt: updatedAt,
);

final _old = DateTime.now().subtract(const Duration(days: 10));

Future<SavedOs> _loadWith({
  required SavedOs local,
  required Map<String, dynamic> remote,
  Map<String, Object> extraPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'gs_work_orders_v2': jsonEncode([local.toJson()]),
    ...extraPrefs,
  });
  await FieldStore.instance.load(
    'teste@gs',
    seeAll: true,
    remoteOrders: [remote],
  );
  return FieldStore.instance.byId(_osId)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AccountApi.useRemote = false;

  final local = _os(
    slots: [_slot('s1'), _slot('s2'), _slot('s3'), _slot('s4')],
    rdos: [_rdo('r1', _old), _rdo('r2', _old)],
    updatedAt: DateTime(2026, 10, 14),
  );

  test(
    'nuvem completa manda nos certificados; RDO ausente nela fica',
    () async {
      final remote = _os(
        slots: [_slot('s1'), _slot('s2')],
        rdos: [_rdo('r1', _old)],
        updatedAt: DateTime(2026, 10, 15),
      ).toJson();
      final os = await _loadWith(
        local: local,
        remote: remote,
        extraPrefs: {'gs_os_rdos_pending_v1': '{}'},
      );
      expect(os.calibrationSlots.map((s) => s.id), ['s1', 's2']);
      expect(os.rdos.map((r) => r.id).toSet(), {'r1', 'r2'});
    },
  );

  test('OS enxuta da nuvem não apaga detalhes dos certificados', () async {
    final rich = local.copyWith(
      calibrationSlots: [
        _slot('s1').copyWith(presetTag: 'P01', systemTag: 'Ilha 1'),
        _slot('s2').copyWith(presetTag: 'P02', systemTag: 'Ilha 1'),
      ],
    );
    final remote = _os(
      slots: const [],
      rdos: [_rdo('r1', _old)],
      updatedAt: DateTime(2026, 10, 15),
    ).toJson();
    remote['calibrationSlots'] = [
      {
        'id': 's1',
        'kind': 'volumetric',
        'certificateNumber': 'GS-0101',
        'serialNumber': '',
        'equipmentTag': 'TAG s1',
        'jobId': '',
      },
      {
        'id': 's2',
        'kind': 'volumetric',
        'certificateNumber': '',
        'serialNumber': '',
        'equipmentTag': 'TAG s2',
        'jobId': '',
      },
    ];
    final os = await _loadWith(
      local: rich,
      remote: remote,
      extraPrefs: {'gs_os_rdos_pending_v1': '{}'},
    );
    expect(os.calibrationSlots.map((s) => s.id), ['s1', 's2']);
    expect(os.calibrationSlots.map((s) => s.presetTag), ['P01', 'P02']);
    expect(os.calibrationSlots.map((s) => s.systemTag), ['Ilha 1', 'Ilha 1']);
    expect(os.calibrationSlots.first.certificateNumber, 'GS-0101');
    expect(os.rdos.map((r) => r.id).toSet(), {'r1', 'r2'});
  });

  test('replay real: cópia do Chrome x OS enxuta da nuvem', () async {
    final localPath = Platform.environment['GS_REPLAY_LOCAL'];
    final cloudPath = Platform.environment['GS_REPLAY_CLOUD'];
    if (localPath == null || cloudPath == null) return;
    final orders = jsonDecode(File(localPath).readAsStringSync()) as List;
    final cloudRaw = jsonDecode(File(cloudPath).readAsStringSync());
    final cloud = Map<String, dynamic>.from(
      cloudRaw['order'] ?? (cloudRaw['orders'] as List).first,
    );
    final localJson = Map<String, dynamic>.from(
      orders.firstWhere((o) => o['id'] == cloud['id']) as Map,
    );
    final before = SavedOs.fromJson(localJson);
    SharedPreferences.setMockInitialValues({
      'gs_work_orders_v2': jsonEncode([localJson]),
      'gs_os_rdos_pending_v1': '{}',
    });
    await FieldStore.instance.load(
      'teste@gs',
      seeAll: true,
      remoteOrders: [cloud],
    );
    final after = FieldStore.instance.byId(before.id)!;
    expect(
      after.rdos.map((r) => r.id).toSet(),
      containsAll(before.rdos.map((r) => r.id)),
    );
    expect(after.calibrationSlots, hasLength(before.calibrationSlots.length));
    for (var i = 0; i < before.calibrationSlots.length; i++) {
      final a = before.calibrationSlots[i];
      final b = after.calibrationSlots.firstWhere((s) => s.id == a.id);
      expect(b.presetTag, a.presetTag);
      expect(b.systemTag, a.systemTag);
      expect(b.serialNumber, a.serialNumber);
    }
  });

  test('RDO recente ainda não enviado não se perde', () async {
    final withNew = local.copyWith(
      rdos: [...local.rdos, _rdo('r3', DateTime.now())],
    );
    final remote = _os(
      slots: [_slot('s1'), _slot('s2')],
      rdos: [_rdo('r1', _old)],
      updatedAt: DateTime(2026, 10, 15),
    ).toJson();
    final os = await _loadWith(local: withNew, remote: remote);
    expect(os.rdos.map((r) => r.id).toSet(), {'r1', 'r2', 'r3'});
  });

  test('resumo da lista (sem RDOs) não apaga nada local', () async {
    final remote = <String, dynamic>{
      'id': _osId,
      'number': '048/26',
      'ownerEmail': 'teste@gs',
      'status': 'emAndamento',
      'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 10, 15).toIso8601String(),
      '_payloadLight': true,
      '_fileId': 'drive-file',
    };
    final os = await _loadWith(
      local: local,
      remote: remote,
      extraPrefs: {'gs_os_rdos_pending_v1': '{}'},
    );
    expect(os.calibrationSlots, hasLength(4));
    expect(os.rdos.map((r) => r.id).toSet(), {'r1', 'r2'});
  });

  final remoteTwo = _os(
    slots: [_slot('s1'), _slot('s2')],
    rdos: [_rdo('r1', _old), _rdo('r2', _old)],
    updatedAt: DateTime(2026, 10, 15),
  );

  test('só o certificado criado aqui e não enviado fica', () async {
    final os = await _loadWith(
      local: local,
      remote: remoteTwo.toJson(),
      extraPrefs: {
        'gs_os_rdos_pending_v1': '{}',
        'gs_os_slot_edits_v1': jsonEncode({
          _osId: ['s3'],
        }),
      },
    );
    expect(os.calibrationSlots.map((s) => s.id), ['s1', 's2', 's3']);
  });

  test('marca antiga da OS inteira (Edge) não segura cópia velha', () async {
    final os = await _loadWith(
      local: local,
      remote: remoteTwo.toJson(),
      extraPrefs: {
        'gs_os_rdos_pending_v1': '{}',
        'gs_os_slots_pending_v1': [_osId],
      },
    );
    expect(os.calibrationSlots.map((s) => s.id), ['s1', 's2']);
  });

  test('alteração feita aqui e não enviada vence a nuvem', () async {
    final edited = local.copyWith(
      calibrationSlots: [
        _slot('s1').copyWith(serialNumber: 'NOVO'),
        _slot('s2'),
      ],
    );
    final os = await _loadWith(
      local: edited,
      remote: remoteTwo.toJson(),
      extraPrefs: {
        'gs_os_rdos_pending_v1': '{}',
        'gs_os_slot_edits_v1': jsonEncode({
          _osId: ['s1'],
        }),
      },
    );
    expect(os.calibrationSlots.first.serialNumber, 'NOVO');
  });

  test('certificado removido aqui e não enviado não volta', () async {
    final removed = local.copyWith(calibrationSlots: [_slot('s1')]);
    final os = await _loadWith(
      local: removed,
      remote: remoteTwo.toJson(),
      extraPrefs: {
        'gs_os_rdos_pending_v1': '{}',
        'gs_os_slot_deletes_v1': jsonEncode({
          _osId: ['s2'],
        }),
      },
    );
    expect(os.calibrationSlots.map((s) => s.id), ['s1']);
  });

  test('certificado lido e regravado fica idêntico (confirma envio)', () {
    final path = Platform.environment['GS_SLOT_DUMP'];
    final slots = <Map<String, dynamic>>[
      _slot('s1').copyWith(serialNumber: 'X1', presetTag: 'P01').toJson(),
    ];
    if (path != null && File(path).existsSync()) {
      final decoded = jsonDecode(File(path).readAsStringSync());
      final order = decoded['order'] ?? (decoded['orders'] as List).first;
      slots.addAll([
        for (final raw in order['calibrationSlots'] as List)
          Map<String, dynamic>.from(raw as Map),
      ]);
    }
    for (final raw in slots) {
      final first = jsonEncode(OsCalibrationSlot.fromJson(raw).toJson());
      final again = jsonEncode(
        OsCalibrationSlot.fromJson(jsonDecode(first)).toJson(),
      );
      expect(again, first);
    }
  });
}
