import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_label_pdf.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('próxima calibração = data + 1 ano', () {
    expect(nextCalibrationDateLabel('10/09/2026'), '10/09/2027');
    expect(nextCalibrationDateLabel(''), '');
  });

  test('nome do princípio na etiqueta por tipo', () {
    expect(
      calibrationLabelPrincipleName(CalibrationKind.volumetric),
      'Calibração de vazão',
    );
    expect(
      calibrationLabelPrincipleName(CalibrationKind.density),
      'Calibração de densidade',
    );
    expect(
      calibrationLabelPrincipleName(CalibrationKind.temperature),
      'Calibração de temperatura',
    );
  });

  test('nome do certificado no layout novo', () {
    expect(
      calibrationLabelCertificateKind(CalibrationKind.volumetric),
      'Certificado de Vazão',
    );
    expect(
      calibrationLabelCertificateKind(CalibrationKind.temperature),
      'Certificado de Temperatura',
    );
  });

  test('QR aponta para o certificado no GS Campo', () {
    final job = CalibrationJob(
      id: 'job-label-1',
      number: 'GS-TEMP-2026-0001',
      kind: CalibrationKind.temperature,
      createdAt: DateTime(2026, 9, 10),
      osNumber: '047/26',
      osId: 'os-1',
    );
    final url = calibrationLabelQrUrl(job);
    expect(url, contains('gs-campo.netlify.app'));
    expect(url, startsWith('https://gs-campo.netlify.app/c?'));
    expect(url, contains('n=GS-TEMP-2026-0001'));
    expect(url, contains('id='));
    expect(url, contains('os='));
  });

  test('gera PDF do adesivo 40x60mm', () async {
    final job = CalibrationJob(
      id: 'job-label-1',
      number: 'GS-TEMP-2026-0001',
      kind: CalibrationKind.temperature,
      createdAt: DateTime(2026, 9, 10),
      serialNumber: '43134/1',
      equipmentTag: 'TE1',
      calibrationDate: '10/09/2026',
      osNumber: '047/26',
    );
    final bytes = await buildCalibrationLabel(job);
    expect(bytes.length, greaterThan(500));
    expect(calibrationLabelFileName(job), 'Adesivo_GS-TEMP-2026-0001.pdf');
    expect(
      calibrationLabelPageFormat.width,
      closeTo(40 * PdfPageFormat.mm, 0.5),
    );
    expect(
      calibrationLabelPageFormat.height,
      closeTo(60 * PdfPageFormat.mm, 0.5),
    );
  });

  test('gera PDF com tamanho personalizado', () async {
    final job = CalibrationJob(
      id: 'job-label-2',
      number: 'GS-VOL-2026-0003',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 8, 31),
      serialNumber: '002-01-604',
      equipmentTag: 'FT 1',
      calibrationDate: '31/08/2026',
      osNumber: '045/26',
    );
    const size = CalibrationLabelSize(widthMm: 50, heightMm: 80);
    final bytes = await buildCalibrationLabel(job, size: size);
    expect(bytes.length, greaterThan(500));
    expect(size.pageFormat.width, closeTo(50 * PdfPageFormat.mm, 0.5));
    expect(size.pageFormat.height, closeTo(80 * PdfPageFormat.mm, 0.5));
  });

  test('texto do adesivo junta certificados do mesmo medidor', () {
    final vol = CalibrationJob(
      id: 'job-v',
      number: 'GS-VOL-2026-0100',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 10, 1),
      serialNumber: 'SN-FIQ-1',
      equipmentTag: 'FT 1',
      presetTag: 'FIQ-1',
      calibrationDate: '01/10/2026',
    );
    final temp = CalibrationJob(
      id: 'job-t',
      number: 'GS-TEMP-2026-0101',
      kind: CalibrationKind.temperature,
      createdAt: DateTime(2026, 10, 1),
      serialNumber: 'SN-FIQ-1',
      equipmentTag: 'TE 1',
      presetTag: 'FIQ-1',
      calibrationDate: '01/10/2026',
    );
    final dens = CalibrationJob(
      id: 'job-d',
      number: 'GS-DEN-2026-0102',
      kind: CalibrationKind.density,
      createdAt: DateTime(2026, 10, 1),
      serialNumber: 'SN-FIQ-1',
      equipmentTag: 'DT 1',
      presetTag: 'FIQ-1',
      calibrationDate: '01/10/2026',
    );
    expect(calibrationLabelsShareMeter([vol, temp, dens]), isTrue);
    expect(calibrationLabelServiceTypeForJobs([vol, temp, dens]), 'CALIBRAÇÃO');
    final value = calibrationLabelCertificateValue([vol, temp, dens]);
    expect(value, contains('Vazão GS-VOL-2026-0100'));
    expect(value, contains('Temp. GS-TEMP-2026-0101'));
    expect(value, contains('Dens. GS-DEN-2026-0102'));
  });

  test('gera adesivo com vários certificados do mesmo medidor', () async {
    final vol = CalibrationJob(
      id: 'job-v2',
      number: 'GS-VOL-2026-0200',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 10, 2),
      serialNumber: '2412-52258',
      equipmentTag: 'FT 4',
      presetTag: 'FIQ-4',
      calibrationDate: '02/10/2026',
      osNumber: '050/26',
    );
    final dens = CalibrationJob(
      id: 'job-d2',
      number: 'GS-DEN-2026-0201',
      kind: CalibrationKind.density,
      createdAt: DateTime(2026, 10, 2),
      serialNumber: '2412-52258',
      equipmentTag: 'DT 4',
      presetTag: 'FIQ-4',
      calibrationDate: '02/10/2026',
      osNumber: '050/26',
    );
    final bytes = await buildCalibrationLabel(
      vol,
      relatedCertificates: [vol, dens],
    );
    expect(bytes.length, greaterThan(500));
  });

  test('data do adesivo: a do item da OS vence a do certificado', () async {
    final job = CalibrationJob(
      id: 'job-label-3',
      number: 'GS-VOL-2026-0024',
      kind: CalibrationKind.volumetric,
      createdAt: DateTime(2026, 9, 1),
      calibrationDate: '03/09/2026',
    );
    expect(calibrationLabelDate(job), '03/09/2026');
    const slot = OsCalibrationSlot(
      id: 's24',
      kind: 'volumetric',
      certificateNumber: 'GS-VOL-2026-0024',
      labelDate: '15/10/2026',
    );
    expect(calibrationLabelDate(job, slot: slot), '15/10/2026');
    expect(
      OsCalibrationSlot.fromJson(slot.toJson()).labelDate,
      '15/10/2026',
    );
    final bytes = await buildCalibrationLabel(
      job,
      calibrationDateOverride: '20/10/2026',
    );
    expect(bytes.length, greaterThan(500));
  });
}
