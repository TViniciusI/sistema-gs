import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/cloud_sync_gate.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CalibrationStore.instance.resetForTest();
    CloudSyncGate.markSynced(); // evita pull de rede no load() dos testes
  });

  test('save não funde o mesmo nº entre OS diferentes', () async {
    final store = CalibrationStore.instance;
    final filledPoint = FlowPoint(
      id: 'p1',
      verification: const [
        VolumeRun(id: 'r1', objectVolume: 100, standardVolume: 99.5),
      ],
    );
    final phoenix = await store.save(
      CalibrationJob(
        id: 'job-phx',
        number: 'GS-VOL-2026-0031',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 1),
        osId: 'os-phoenix',
        osNumber: '043/26',
        equipmentTag: 'FT 1',
        serialNumber: 'SN-PHX',
        fluid: 'Anidro',
        points: [filledPoint],
      ),
      pushRemote: false,
    );
    expect(phoenix.number, 'GS-VOL-2026-0031');
    expect(phoenix.points.first.hasReadings, isTrue);

    final other = await store.save(
      CalibrationJob(
        id: 'job-rv',
        number: 'GS-VOL-2026-0031',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 2),
        osId: 'os-rio',
        osNumber: '045/26',
        equipmentTag: 'Plact 7',
        serialNumber: 'SN-RV',
        fluid: 'Etanol',
      ),
      pushRemote: false,
    );

    expect(other.id, 'job-rv');
    expect(other.number, isNot(equals('GS-VOL-2026-0031')));
    expect(store.byId('job-phx')?.points.first.hasReadings, isTrue);
    expect(store.byId('job-phx')?.serialNumber, 'SN-PHX');
    expect(store.byNumber('GS-VOL-2026-0031')?.id, 'job-phx');
  });

  test('save não apaga medições com payload vazio', () async {
    final store = CalibrationStore.instance;
    await store.save(
      CalibrationJob(
        id: 'job-1',
        number: 'GS-VOL-2026-0100',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 1),
        osId: 'os-1',
        points: [
          FlowPoint(
            id: 'p1',
            verification: const [
              VolumeRun(id: 'r1', objectVolume: 50, standardVolume: 49.8),
            ],
          ),
        ],
      ),
      pushRemote: false,
    );
    final wiped = await store.save(
      CalibrationJob(
        id: 'job-1',
        number: 'GS-VOL-2026-0100',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 1),
        osId: 'os-1',
        fluid: 'S500',
        points: const [],
      ),
      pushRemote: false,
    );
    expect(wiped.fluid, 'S500');
    expect(wiped.points, isNotEmpty);
    expect(wiped.points.first.hasReadings, isTrue);
  });

  test('save não funde o mesmo nº entre slots diferentes na mesma OS', () async {
    final store = CalibrationStore.instance;
    await store.save(
      CalibrationJob(
        id: 'job-a',
        number: 'GS-VOL-2026-0060',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 1),
        osId: 'os-043',
        osNumber: '043/26',
        calibrationSlotId: 'slot-a',
        equipmentTag: 'FT 4',
        serialNumber: 'SN-OLD',
      ),
      pushRemote: false,
    );

    final created = await store.save(
      CalibrationJob(
        id: 'job-b',
        number: 'GS-VOL-2026-0060',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 2),
        osId: 'os-043',
        osNumber: '043/26',
        calibrationSlotId: 'slot-b',
        equipmentTag: '',
        serialNumber: '',
      ),
      pushRemote: false,
    );

    expect(created.id, 'job-b');
    expect(created.number, isNot(equals('GS-VOL-2026-0060')));
    expect(store.byId('job-a')?.equipmentTag, 'FT 4');
    expect(store.byId('job-a')?.serialNumber, 'SN-OLD');
    expect(created.equipmentTag, isEmpty);
    expect(created.serialNumber, isEmpty);
  });

  test('jobForSlot não reutiliza job de outro slot pelo mesmo nº', () async {
    final store = CalibrationStore.instance;
    await store.save(
      CalibrationJob(
        id: 'job-a',
        number: 'GS-VOL-2026-0060',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 1),
        osId: 'os-043',
        osNumber: '043/26',
        calibrationSlotId: 'slot-a',
        equipmentTag: 'FT 4',
      ),
      pushRemote: false,
    );

    final orphan = OsCalibrationSlot(
      id: 'slot-b',
      kind: CalibrationKind.volumetric.name,
      certificateNumber: 'GS-VOL-2026-0060',
    );
    expect(
      store.jobForSlot(orphan, osId: 'os-043', osNumber: '043/26'),
      isNull,
    );
  });

  test('rascunho vazio não sobrescreve done no mesmo slot', () async {
    final store = CalibrationStore.instance;
    final done = await store.save(
      CalibrationJob(
        id: 'job-done',
        number: 'GS-VOL-2026-0055',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 1),
        osId: 'os-043',
        osNumber: '043/26',
        calibrationSlotId: 'slot-55',
        status: CalibrationJobStatus.done,
        fluid: 'Gasolina',
        points: [
          FlowPoint(
            id: 'p1',
            verification: const [
              VolumeRun(id: 'r1', objectVolume: 10, standardVolume: 9.9),
            ],
          ),
        ],
      ),
      pushRemote: false,
    );
    expect(done.status, CalibrationJobStatus.done);

    final ghost = await store.save(
      CalibrationJob(
        id: 'job-ghost',
        number: 'GS-VOL-2026-0055',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 2),
        osId: 'os-043',
        osNumber: '043/26',
        calibrationSlotId: 'slot-55',
        status: CalibrationJobStatus.draft,
      ),
      pushRemote: false,
    );

    expect(ghost.id, 'job-done');
    expect(store.byId('job-done')?.fluid, 'Gasolina');
    expect(store.byId('job-done')?.hasMeasurements, isTrue);
    expect(store.byId('job-ghost'), isNull);
  });

  test('shouldRefuseRemotePush bloqueia fantasma com peer done', () async {
    final store = CalibrationStore.instance;
    await store.save(
      CalibrationJob(
        id: 'job-strong',
        number: 'GS-VOL-2026-0040',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 1),
        osId: 'os-043',
        status: CalibrationJobStatus.done,
        points: [
          FlowPoint(
            id: 'p1',
            verification: const [
              VolumeRun(id: 'r1', objectVolume: 1, standardVolume: 1),
            ],
          ),
        ],
      ),
      pushRemote: false,
    );
    final ghost = CalibrationJob(
      id: 'job-weak',
      number: 'GS-VOL-2026-0040',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 2),
      osId: 'os-043',
      status: CalibrationJobStatus.draft,
    );
    expect(store.shouldRefuseRemotePush(ghost), isTrue);
    expect(store.shouldRefuseRemotePush(store.byId('job-strong')!), isFalse);
  });
}
