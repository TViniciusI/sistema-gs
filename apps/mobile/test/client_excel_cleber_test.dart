import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/models.dart';

const cleberHeadersV2 = [
  'Cliente',
  'CNPJ',
  'Tipo de sistema',
  'local de Instalação do sistema',
  'Preset ou transmissor',
  'Fabricante do preset',
  'Modelo do preset',
  'Numero de serie do preset',
  'Tag do preset',
  'Fabricante do transmissor',
  'Modelo do transmissor',
  'N/S do transmissor',
  'Tag do transmissor',
  'Principio do Medidor',
  'Dimensoes do medidor',
  'Fabricante do medidor',
  'Modelo do medidor',
  'Numero de serie do medidor',
  'Tag do medidor',
  'Produto utilizado no medidor',
  'Principio do Sensor de temperatura',
  'Fabricante do sensor de temperatura',
  'Modelo do sensor de temperatura',
  'N/S do sensor de temperatura',
  'Tag do sensor de temperatura',
  'Principio do Sensor do densimetro',
  'Fabricante do densimetro',
  'Modelo do densimetro',
  'N/S do densimetro',
  'Tag do densimetro',
  'Principio da malha',
  'Fabricante da malha',
  'Modelo da malha',
  'N/S da malha',
  'Tag da malha',
  'Principio da telemetria',
  'Fabricante da telemetria',
  'Modelo da telemetria',
  'N/S da telemetria',
  'Tag da telemetria',
  'Produto do tanque - Telemetria',
  'Tipo do Instrumento de pressao',
  'Fabricante da pressao',
  'Modelo da pressao',
  'N/S da pressao',
  'Tag da pressao',
];

void main() {
  test('export Instrumentos headers match Cleber Phoenix v2 (46 cols)', () {
    final bytes = buildClientExcelTemplate(withExample: true);
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel['Instrumentos'];
    final headers = [for (final cell in sheet.rows.first) _cellText(cell)];

    expect(headers.length, 46);
    expect(headers, cleberHeadersV2);
    expect(headers.contains('Tipo de equipamento'), isFalse);
    expect(headers.contains('Quantidade'), isFalse);
    expect(headers.contains('Principio da pressao'), isFalse);
    expect(headers.contains('Tipo da malha'), isFalse);

    final row = sheet.rows[1];
    expect(_cellText(row[3]), 'Plataforma 1');
    expect(_cellText(row[5]), 'ZYLIX'); // Fabricante do preset
    expect(_cellText(row[8]), 'FIQ 1'); // Tag do preset
    expect(_cellText(row[18]), 'FT 1'); // Tag do medidor
    expect(_cellText(row[19]), 'Hidratado');
    expect(_cellText(row[20]), 'Termorresistência'); // Principio sensor temp
    expect(_cellText(row[23]), '43134/1'); // N/S sensor
    expect(_cellText(row[24]), 'TE1'); // Tag sensor
    expect(_cellText(row[25]), 'ALUTAL'); // Principio densimetro
  });

  test('import Cleber Phoenix v2 workbook (typos ok)', () {
    final file = File('tool/GS_Calibracao_padrao_Cleber_Phoenix.xlsx');
    expect(file.existsSync(), isTrue);
    final parsed = parseClientWorkbook(file.readAsBytesSync());
    expect(parsed.instruments.length, greaterThanOrEqualTo(28));

    final meters = parsed.instruments.where((item) {
      final eq = item.equipment;
      return clientInstrumentRoleFrom(eq.instrumentRole) ==
          ClientInstrumentRole.meter;
    }).toList();
    expect(meters.length, greaterThanOrEqualTo(20));

    final dens = parsed.instruments.where(
      (item) =>
          clientInstrumentRoleFrom(item.equipment.instrumentRole) ==
              ClientInstrumentRole.densimeter ||
          item.equipment.workingPrinciple.trim().toUpperCase() == 'ALUTAL',
    );
    final pts = parsed.instruments
        .where(
          (item) =>
              clientInstrumentRoleFrom(item.equipment.instrumentRole) ==
              ClientInstrumentRole.pt100,
        )
        .toList();
    expect(pts.length, greaterThanOrEqualTo(1));
    // Densímetro na Phoenix às vezes vem só no princípio (deslocado da coluna temp).
    expect(dens.length, greaterThanOrEqualTo(1));
    expect(dens.length + pts.length, greaterThanOrEqualTo(2));

    // Colunas deslocadas: ALUTAL→dens; Termorresistência→princípio; TE*→tag.
    for (final item in pts) {
      final eq = item.equipment;
      expect(eq.workingPrinciple.toLowerCase(), contains('termorresist'));
      expect(eq.workingPrinciple.toUpperCase(), isNot('PT100'));
      expect(eq.workingPrinciple.toUpperCase(), isNot('ALUTAL'));
      expect(
        eq.tag.toUpperCase().startsWith('TE') ||
            eq.serialNumber.trim().isNotEmpty,
        isTrue,
        reason: 'PT100 deve ter TAG TE* ou N/S real após normalizar',
      );
    }
    expect(
      dens.any(
        (item) =>
            item.equipment.workingPrinciple.trim().toUpperCase() == 'ALUTAL',
      ),
      isTrue,
    );

    final client = SavedClient(
      id: 'phoenix',
      name: parsed.instruments.first.clientName,
      cnpj: parsed.instruments.first.cnpj,
      systems: systemsFromEquipment([
        for (final item in parsed.instruments) item.equipment,
      ]),
      updatedAt: DateTime.now(),
    );
    final out = buildClientExcelTemplate(clients: [client]);
    final excel = Excel.decodeBytes(out);
    final headers = [
      for (final cell in excel['Instrumentos'].rows.first) _cellText(cell),
    ];
    expect(headers.length, 46);
    expect(headers[13], 'Principio do Medidor');
    expect(headers[40], 'Produto do tanque - Telemetria');
  });

  test(
    'import mantém serial do preset separado do serial vazio do medidor',
    () {
      final excel = Excel.createExcel();
      final sheet = excel['Instrumentos'];
      sheet.appendRow([
        for (final header in cleberHeadersV2) TextCellValue(header),
      ]);
      final row = List<CellValue>.filled(46, TextCellValue(''));
      row[0] = TextCellValue('PHOENIX');
      row[1] = TextCellValue('09.158.456/0001-59');
      row[2] = TextCellValue('Carregamento');
      row[7] = TextCellValue('PRESET-LEFT');
      row[8] = TextCellValue('FIQ 3.1');
      row[18] = TextCellValue('FT 3.1');
      row[19] = TextCellValue('S500');
      sheet.appendRow(row);

      final parsed = parseClientWorkbook(excel.save()!);
      final meter = parsed.instruments.single.equipment;
      expect(meter.presetSerial, 'PRESET-LEFT');
      expect(meter.serialNumber, isEmpty);
      expect(meter.tag, 'FT 3.1');
      expect(meter.product, 'S500');
    },
  );
}

String _cellText(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is TextCellValue) return (value.value.text ?? '').trim();
  if (value is IntCellValue) return '${value.value}';
  if (value is DoubleCellValue) return '${value.value}';
  return '$value'.trim();
}
