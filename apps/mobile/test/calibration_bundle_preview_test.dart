import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_bundle_pdf.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('exporta preview do livro (capa na página 1)', () async {
    final jobs = [
      CalibrationJob(
        id: '1',
        number: 'GS-VOL-2026-0001',
        kind: CalibrationKind.volumetric,
        createdAt: DateTime(2026, 9, 16),
        installLocation: 'Plataforma 1',
        site: 'DTC RIO VERDE',
        clientName: 'VIBRA ENERGIA S.A.',
        osNumber: '047/26',
        serialNumber: '2412-52258U',
        equipmentTag: 'FT 4',
        calibrationDate: '16/09/2026',
      ),
      CalibrationJob(
        id: '2',
        number: 'GS-TEMP-2026-0001',
        kind: CalibrationKind.temperature,
        createdAt: DateTime(2026, 9, 16),
        installLocation: 'Plataforma 1',
        site: 'DTC RIO VERDE',
        clientName: 'VIBRA ENERGIA S.A.',
        osNumber: '047/26',
        serialNumber: 'T-100',
        equipmentTag: 'TE 1',
        calibrationDate: '16/09/2026',
      ),
    ];
    final bytes = await buildCalibrationCertificateBundle(
      jobs: jobs,
      coverPlace: 'DTC RIO VERDE',
      clientName: 'VIBRA ENERGIA S.A.',
      osNumber: '047/26',
      issuedAt: DateTime(2026, 9, 16),
    );
    final dir = Directory('tool/cert_bundle_preview');
    await dir.create(recursive: true);
    final out = File('${dir.path}/livro_preview.pdf');
    await out.writeAsBytes(bytes);
    expect(out.existsSync(), isTrue);
    expect(bytes.length, greaterThan(1000));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
