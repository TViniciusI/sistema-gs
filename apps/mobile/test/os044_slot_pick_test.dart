import 'dart:convert';
import 'dart:io';

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
    CloudSyncGate.markSynced();
  });

  test('slot com rascunho e certificado concluído mostra o concluído', () async {
    final rows = [
      for (final item
          in jsonDecode(
                File('test/fixtures/os044_temp_0038.json').readAsStringSync(),
              )
              as List)
        Map<String, dynamic>.from(item as Map),
    ];
    final store = CalibrationStore.instance;
    await store.load(remoteCalibrations: rows);
    expect(store.items.length, 2);

    final job = store.jobForSlot(
      const OsCalibrationSlot(
        id: '1789149905095000_2',
        kind: 'temperature',
        certificateNumber: 'GS-TEMP-2026-0038',
      ),
      osId: '1786906906918',
      osNumber: '044/26',
    );
    expect(job?.id, '1791294590252000-1');
    expect(job?.status, CalibrationJobStatus.done);
    expect(job?.calibrationDate, '24/08/2026');
  });
}
