import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_label_pdf.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('exporta preview do adesivo com QR', () async {
    final job = CalibrationJob(
      id: 'label-preview',
      number: 'GS-VOL-2026-0033',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 16),
      serialNumber: '2412-52258U-1-10',
      equipmentTag: 'FT 4',
      calibrationDate: '16/09/2026',
      osNumber: '047/26',
      osId: 'os-preview',
      installLocation: 'Plataforma 1',
      clientName: 'VIBRA ENERGIA S.A.',
    );
    final bytes = await buildCalibrationLabel(job);
    final dir = Directory('tool/cert_bundle_preview');
    await dir.create(recursive: true);
    final out = File('${dir.path}/adesivo_preview.pdf');
    await out.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(500));
    expect(out.existsSync(), isTrue);
  });
}
