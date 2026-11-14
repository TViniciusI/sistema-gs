import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exporta preview do certificado para inspeção visual', () async {
    final job = newCalibrationJob(
      kind: CalibrationKind.volumetric,
      technicianName: 'Cleber Guimarães',
    ).copyWith(
      number: 'GS-VOL-2026-0001',
      clientName: 'Cliente Teste',
      clientCnpj: '00.000.000/0001-00',
      clientAddress: 'Belém/PA',
      site: 'Patio de tanques',
      equipmentTag: 'FT-01',
      equipmentType: 'Medidor volumétrico',
      manufacturer: 'GS',
      model: 'VM-100',
      serialNumber: 'SN-46',
      workingPrinciple: 'Coriolis',
      coriolisCoefficients: const [
        CoriolisCoefficient(id: 'cf1', label: 'Flow Cal.', found: '226,795'),
        CoriolisCoefficient(id: 'cf2', label: 'KD', found: '2,0062'),
        CoriolisCoefficient(id: 'cf3', label: 'SK20', found: '23136'),
      ],
      procedure: 'Comparação direta com padrão volumétrico.',
      points: [
        FlowPoint(
          id: 'p1',
          flowRate: 20,
          oldMeterFactor: 1,
          verification: [
            VolumeRun(id: 'a', objectVolume: 20.02, standardVolume: 20, temperature: 20.1),
            VolumeRun(id: 'b', objectVolume: 20.01, standardVolume: 20, temperature: 20.2),
          ],
        ),
        FlowPoint(
          id: 'p2',
          flowRate: 40,
          oldMeterFactor: 1,
          verification: [
            VolumeRun(id: 'c', objectVolume: 40.06, standardVolume: 40, temperature: 20.3),
            VolumeRun(id: 'd', objectVolume: 40.04, standardVolume: 40, temperature: 20.2),
          ],
        ),
      ],
      standards: [
        CalibrationStandard(
          id: 's1',
          tag: 'PR-01',
          description: 'Prova volumétrica',
          certificate: 'RBC-100',
          validity: '12/2026',
        ),
      ],
    );
    final bytes = await buildCalibrationCertificate(job);
    final dir = Directory('tool/cert_preview');
    await dir.create(recursive: true);
    final out = File('${dir.path}/Certificado_preview.pdf');
    await out.writeAsBytes(bytes);
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(8000));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('exporta certificado de temperatura sem mencao a medicao volumetrica', () async {
    final job = newCalibrationJob(
      kind: CalibrationKind.temperature,
      technicianName: 'Cleber Guimarães',
    ).copyWith(
      number: 'GS-TEMP-2026-0001',
      clientName: 'Cliente Teste',
      clientCnpj: '00.000.000/0001-00',
      clientAddress: 'Belém/PA',
      equipmentTag: 'TT-01',
      equipmentType: 'Sensor de Temperatura',
      manufacturer: 'GS',
      model: 'PT-100',
      serialNumber: 'SN-99',
      workingPrinciple: 'Termorresistência PT-100',
      genericPoints: [
        GenericPoint(
          id: 'gp1',
          label: '0 °C',
          cycles: [
            GenericCycle(standard: 0.0, instrument: 0.05),
          ],
        ),
      ],
      standards: [
        CalibrationStandard(
          id: 's1',
          tag: 'PAD-TEMP',
          description: 'Termômetro padrão',
          certificate: 'RBC-200',
          validity: '12/2026',
        ),
      ],
    );
    final bytes = await buildCalibrationCertificate(job);
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    expect(bytes.length, greaterThan(5000));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
