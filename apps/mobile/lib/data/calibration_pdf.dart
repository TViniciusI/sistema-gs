import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_label_pdf.dart'
    show calibrationLabelQrUrl;
import 'package:gs_mobile/data/calibration_math.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/e_signature.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/gs_brand_pdf.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/staff_digital_cert.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _pq30005 =
    'O instrumento foi calibrado de acordo com a instrução de trabalho '
    'GS SOLUÇÕES PQ-30.005 Rev.01. Este processo consiste em efetuar, pelo '
    'método de comparação direta, as indicações do instrumento sob calibração '
    'em relação às indicadas pelo sistema padrão nas instalações do cliente, '
    'baseado na Portaria nº 291, de 07 de julho de 2021 do Inmetro — para '
    'sistemas de medição dinâmica de líquidos.';

const _tempProcedureText =
    'O instrumento foi calibrado de acordo com a instrução de trabalho '
    'GS SOLUÇÕES PQ-30.005 Rev.01. Este processo consiste em efetuar, pelo '
    'método de comparação direta, as indicações do instrumento sob calibração '
    'em relação às indicadas pelo sistema padrão nas instalações do cliente, '
    'baseado na Portaria NBR IEC 60751 — para especificar os requisitos e a '
    'relação temperatura/resistência de sensores industriais de temperatura de '
    'platina (como os populares Pt100), definindo curvas de calibração e '
    'classes de tolerância.';

const gsVolumetricFlowColumnTitle = 'Sistema padrão vazão média';

const _volumetricNotes = [
  'A calibração foi realizada nas instalações do Cliente.',
  'As vazões de calibração foram acordadas com o cliente, para uma melhor performance do sistema.',
  'Os resultados apresentados referem-se exclusivamente ao item calibrado, não sendo extensivo a quaisquer lotes.',
  'Este certificado de calibração só deve ser reproduzido por completo. Reprodução de partes requer aprovação por escrito da Empresa GS SOLUÇÕES.',
  'O erro do instrumento foi determinado pela relação entre o volume de referência (Display Master Totalizado) e o volume indicado (Display Teste Totalizado).',
  'Cálculo do erro percentual: Erro(%) = ((Vi − Vc) / Vc) × 100, em que Vc é o valor de referência e Vi o valor indicado.',
  'Cálculo do fator de correção Fc = volume de referência / volume do instrumento.',
  'Cálculo do meter factor novo (Mfn) = meter factor antigo (Mfa) × fator de correção (Fc).',
  'A incerteza expandida de medição U e o fator de abrangência k constam na tabela de resultados.',
  'Este certificado atende ao procedimento AG-PQ 30.005, de calibração de medidor de vazão de líquidos utilizando um padrão certificado como referência, e à Portaria nº 291, de 07 de julho de 2021 do Inmetro.',
  'Os resultados acima são válidos nas condições de calibração. Cabe ao usuário estimar as mudanças por utilizar o medidor em condições diferentes e as contribuições adicionais de incerteza.',
];

const _volumetricNotesInverted = [
  'A calibração foi realizada nas instalações do Cliente.',
  'As vazões de calibração foram acordadas com o cliente, para uma melhor performance do sistema.',
  'Os resultados apresentados referem-se exclusivamente ao item calibrado, não sendo extensivo a quaisquer lotes.',
  'Este certificado de calibração só deve ser reproduzido por completo. Reprodução de partes requer aprovação por escrito da Empresa GS SOLUÇÕES.',
  'Calibração volumétrica com cálculo invertido: o fator segue o equipamento, Fc = volume do instrumento / volume de referência.',
  'Cálculo do fator de correção Fc = volume do instrumento (Display Teste Totalizado) / volume de referência (Display Master Totalizado).',
  'Cálculo do erro percentual: Erro(%) = (1 − Fc) × 100.',
  'Cálculo do meter factor novo (Mfn) = meter factor antigo (Mfa) × fator de correção (Fc).',
  'A incerteza expandida de medição U e o fator de abrangência k constam na tabela de resultados.',
  'Este certificado atende ao procedimento AG-PQ 30.005, de calibração de medidor de vazão de líquidos utilizando um padrão certificado como referência, e à Portaria nº 291, de 07 de julho de 2021 do Inmetro.',
  'Os resultados acima são válidos nas condições de calibração. Cabe ao usuário estimar as mudanças por utilizar o medidor em condições diferentes e as contribuições adicionais de incerteza.',
];

List<String> _genericNotes(CalibrationJob job) {
  final k = job.coverageKLabel.isNotEmpty
      ? job.coverageKLabel
      : (job.standards.any((s) => s.coverageK.trim().isNotEmpty)
          ? job.standards.firstWhere((s) => s.coverageK.trim().isNotEmpty).coverageK.trim()
          : '2,00');
  final veff = job.veffLabel.isNotEmpty ? job.veffLabel : '∞';

  if (job.isConductivity) {
    return [
      'A incerteza expandida de medição foi calculada conforme procedimento estabelecido pelo laboratório, considerando as contribuições relevantes para o processo de calibração. Fator de abrangência (k): $k. Probabilidade de abrangência: aproximadamente 95%.',
      'Os padrões utilizados na calibração são rastreáveis ao Sistema Internacional de Unidades (SI), por meio de certificados de calibração emitidos por laboratórios competentes.',
      'Com base nos resultados obtidos, o instrumento apresentou os resultados descritos neste certificado nas condições estabelecidas durante a calibração.',
      'Observação: A declaração de conformidade com uma tolerância ou especificação somente deve ser realizada quando o critério de aceitação estiver previamente definido.',
      'Não é permitida a reprodução parcial deste documento.',
    ];
  }

  return [
  'A calibração foi realizada nas instalações do Cliente.',
    'Os resultados apresentados neste Certificado são válidos exclusivamente para o objeto verificado, não sendo extensivos a quaisquer lotes, mesmo que similares.',
    'Não é permitida a reprodução parcial deste documento.',
    'A incerteza expandida de medição relatada é declarada como a incerteza padrão da medição multiplicada pelo fator de abrangência k = $k, o qual para uma distribuição t com Veff = $veff graus de liberdades efetivos correspondente a uma probabilidade de abrangência de aproximadamente 95%. A incerteza padrão de medição foi determinada de acordo com a instrução de trabalho IT-5.4.8, a qual foi baseada na publicação EA-4/02.',
  'Os resultados acima são válidos nas condições de calibração.',
];
}

String calibrationPdfFileName(
  CalibrationJob job, {
  bool withSignature = false,
}) {
  final number = job.number.trim().isEmpty ? job.id : job.number.trim();
  final safe = number.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  if (withSignature) return 'Certificado_${safe}_assinado.pdf';
  return 'Certificado_$safe.pdf';
}

/// Junta vários certificados em um único PDF (páginas na ordem recebida).
Future<Uint8List> mergeCalibrationPdfs(List<Uint8List> parts) async {
  if (parts.isEmpty) {
    throw StateError('Nenhum PDF para juntar.');
  }
  if (parts.length == 1) return parts.first;

  final out = sf.PdfDocument();
  try {
    sf.PdfSection? section;
    for (final bytes in parts) {
      final src = sf.PdfDocument(inputBytes: bytes);
      try {
        for (var i = 0; i < src.pages.count; i++) {
          final template = src.pages[i].createTemplate();
          if (section == null ||
              section.pageSettings.size.width != template.size.width ||
              section.pageSettings.size.height != template.size.height) {
            section = out.sections!.add();
            section.pageSettings.size = template.size;
            section.pageSettings.margins.all = 0;
          }
          section.pages
              .add()
              .graphics
              .drawPdfTemplate(template, const Offset(0, 0));
        }
      } finally {
        src.dispose();
      }
    }
    return Uint8List.fromList(await out.save());
  } finally {
    out.dispose();
  }
}

Future<Uint8List> buildCalibrationCertificate(
  CalibrationJob job, {
  bool withSignature = false,
  DateTime? signedAt,
}) async {
  await loadGsBrandPdf();
  await CalibrationCatalog.instance.load();
  await ClientStore.instance.load();
  await loadStaffDigitalCertificates();
  job = prepareCertificateJob(job);
  job = _enrichFluidFromCatalog(job);
  final date = job.calibrationDate.trim().isNotEmpty
      ? job.calibrationDate.trim()
      : DateFormat('dd/MM/yyyy').format(job.createdAt);
  final issued = DateFormat('dd/MM/yyyy').format(job.updatedAt ?? job.createdAt);
  final number = _certNumber(job);
  final qrUrl = calibrationLabelQrUrl(job);
  final stampAt = signedAt ?? DateTime.now();
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: 16,
      pageTheme: gsCertificateTheme(),
      header: (_) => gsDocHeader(date: date, qrUrl: qrUrl),
      footer: (context) => gsDocFooter(context),
      build: (_) => [
        gsDocTitle(
          title: 'CERTIFICADO DE CALIBRAÇÃO',
          subtitle: _serviceTitle(job),
          number: number,
        ),
        if (_hasClient(job)) ...[
            gsSectionBar('Dados do Cliente'),
          _clientHeaderBlock(job),
            gsTwoColPairs(_clientPairs(job)),
        ],
        if (!job.isTelemetry) ...[
            gsSectionBar('Dados do Sistema'),
            gsTwoColPairs(_systemPairs(job)),
          gsSectionBar('Características do Instrumento Calibrado'),
          ..._instrumentsBlock(job, date: date),
        ],
        if (job.isTelemetry && _hasInstrument(job)) ...[
            gsSectionBar('Instrumento sob Prova'),
            gsTwoColPairs(_telemetryInstrumentPairs(job)),
        ],
          gsSectionBar('Metodologia de Execução'),
          ..._serviceDescription(job),
        if (_hasConditions(job) || job.isTelemetry) ...[
            gsSectionBar(
              job.isTelemetry
                  ? 'Condições das Atividades'
                  : 'Condições da Calibração',
            ),
            if (job.isTelemetry)
              pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  telemetryFieldConditions,
                  style: const pw.TextStyle(
                    fontSize: 8.2,
                    color: gsPdfInk,
                  lineSpacing: 1.2,
                  ),
                ),
              ),
            gsTwoColPairs(
              job.isTelemetry
                  ? _telemetryConditionPairs(job)
                  : _conditionPairs(job),
            ),
        ],
        if (job.standards.any((item) => item.isFilled)) ...[
            gsSectionBar('Padrões Envolvidos na Calibração'),
            if (job.isTelemetry)
              _telemetryStandards(job)
            else
              _standardsTable(job),
        ],
        if (job.isVolumetric && job.filledPoints.isNotEmpty) ...[
          gsKeep([
            gsSectionBar('Resultados de Calibração'),
            _resultsIntro(job),
            pw.SizedBox(height: 6),
            _meansTable(job, found: true),
          ]),
          if (_chartPoints(job).isNotEmpty)
            gsKeep([
              gsSectionBar('Representação Gráfica dos Resultados'),
              _errorChart(job),
            ]),
          gsKeep([
            gsSectionBar('Valores Encontrados'),
            _coriolisMeterFactorBlock(job, found: true),
            _calibrationFactorBar(job, found: true),
          ]),
          gsKeep([
            gsSectionBar('Resultados das Medições com os fatores encontrados'),
            _runsTable(job, found: true),
          ]),
            gsKeep([
              gsSectionBar('Valores Deixados'),
              _coriolisMeterFactorBlock(job, found: false),
              _calibrationFactorBar(job, found: false),
            ]),
          if (_hasLeftValues(job))
            gsKeep([
              gsSectionBar(
                'Resultados das Medições com os novos fatores aplicado na calibração',
              ),
              _runsTable(job, found: false),
            ]),
          gsKeep([
            gsSectionBar('Informações do resultado'),
            gsBulletList(
              job.invertedVolumetric
                  ? _volumetricNotesInverted
                  : _volumetricNotes,
            ),
          ]),
        ],
        if (job.isTelemetry && job.filledTelemetryChannels.isNotEmpty) ...[
          if (job.telemetryChannels.any((channel) => channel.hasFound)) ...[
            gsKeep([
              gsSectionBar('Resultado da Verificação'),
              pw.Text(
                'A verificação com os resultados encontrados no instrumento sob prova, conforme dados e configurações informados neste documento, está detalhada nas tabelas a seguir.',
                style: const pw.TextStyle(
                  fontSize: 8.2,
                  color: gsPdfInk,
                  lineSpacing: 1.25,
                ),
              ),
              pw.SizedBox(height: 6),
            ]),
            ..._telemetryResultTables(job, found: true),
          ],
          if (job.telemetryChannels.any((channel) => channel.hasLeft)) ...[
            gsKeep([
              gsSectionBar('Resultado da Calibração'),
              pw.Text(
                'A calibração com os dados deixados no instrumento sob prova, conforme dados e configurações informados neste documento, está detalhada nas tabelas a seguir.',
                style: const pw.TextStyle(
                  fontSize: 8.2,
                  color: gsPdfInk,
                  lineSpacing: 1.25,
                ),
              ),
              pw.SizedBox(height: 6),
            ]),
            ..._telemetryResultTables(job, found: false),
          ],
        ] else if (!job.isVolumetric && job.filledGenericPoints.isNotEmpty) ...[
          () {
            final isTempJob = job.kind == CalibrationKind.temperature ||
                job.kind == CalibrationKind.temperatureMesh;
            final isConductivityJob = job.isConductivity;
            final showFactors = job.filledGenericPoints.any(
              (p) => p.oldFactor != null || p.newValue != null,
            );
            final hasConferences = job.filledGenericPoints.any(
              (p) => p.conferences.any((c) => c.isFilled),
            );
            final hasMultipleCycles = job.filledGenericPoints.any(
              (p) => p.cycles.where((c) => c.isFilled).length > 1,
            );
            final showSummaryTable = isTempJob || isConductivityJob
                ? job.filledGenericPoints.isNotEmpty
                : hasMultipleCycles || showFactors || hasConferences;
            final tempUsesConference = isTempJob && job.hasTemperatureConferenceCycles;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (showSummaryTable)
          gsKeep([
            gsSectionBar('Resultados de Calibração'),
                    if (isTempJob) ...[
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          tempUsesConference
                              ? 'Os resultados da calibração referem-se aos valores médios dos '
                                  'ciclos de conferência (após ajuste) em cada ponto (temperatura) '
                                  'e estão contidos na(s) tabela(s) a seguir.'
                              : 'Os resultados da calibração referem-se aos valores médios de '
                                  'todos os ciclos em cada ponto (temperatura) e estão contidos '
                                  'na(s) tabela(s) a seguir.',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            height: 1.35,
                            color: gsPdfInk,
                          ),
                        ),
                      ),
                    ],
            _genericTable(job),
          ]),
          if (_genericChartPoints(job).isNotEmpty)
            gsKeep([
              gsSectionBar('Representação Gráfica dos Resultados'),
              _genericChart(job),
            ]),
          gsKeep([
            gsSectionBar('Resultados das Medições'),
            _genericRunsTable(job),
          ]),
          gsKeep([
            gsSectionBar('Informações do resultado'),
                  gsBulletList(_genericNotes(job)),
          ]),
              ],
            );
          }(),
        ],
        if (job.isTelemetry)
          gsKeep([
            gsSectionBar('Conclusão'),
            _notes(job),
          ])
        else if (job.notes.trim().isNotEmpty || job.passed == false)
          gsKeep([
            gsSectionBar('Observação'),
            _notes(job),
          ]),
        gsKeep([
          gsSectionBar(
            job.isTelemetry ? 'Signatários' : 'Signatário Autorizado',
          ),
          job.isTelemetry
              ? _telemetrySignatory(
                  job,
                  date,
                  issued,
                  withSignature: withSignature,
                  signedAt: stampAt,
                )
              : _signatory(
                  job,
                  issued,
                  withSignature: withSignature,
                  signedAt: stampAt,
                ),
        ]),
      ],
    ),
  );
  final saved = await doc.save();
  return Uint8List.fromList(saved);
}

String _certNumber(CalibrationJob job) {
  final number = job.number.trim();
  if (number.isNotEmpty) return number;
  return job.id;
}

String _serviceTitle(CalibrationJob job) {
  switch (job.kind) {
    case CalibrationKind.volumetric:
      return 'Serviço de Calibração Volumétrica';
    case CalibrationKind.volumetricInverted:
      return 'Serviço de Calibração Volumétrica (cálculo invertido)';
    case CalibrationKind.temperature:
      return 'Serviço de Calibração de Temperatura';
    case CalibrationKind.temperatureMesh:
      return 'Serviço de Calibração de Malha de Temperatura';
    case CalibrationKind.density:
      return 'Serviço de Calibração de Densidade';
    case CalibrationKind.pressure:
      return 'Serviço de Calibração de Pressão';
    case CalibrationKind.conductivity:
      return 'Serviço de Calibração de Condutividade';
    case CalibrationKind.telemetry:
      return 'Serviço de Calibração de Telemetria';
  }
}

List<pw.Widget> _serviceDescription(CalibrationJob job) {
  final isTemp = job.kind == CalibrationKind.temperature ||
      job.kind == CalibrationKind.temperatureMesh;
  if (isTemp) {
    final custom = job.procedure.trim();
    final isCustom = custom.isNotEmpty &&
        custom.toLowerCase() != 'comparação direta' &&
        custom.toLowerCase() != 'comparacao direta' &&
        !custom.contains('PQ-30.005');
    if (isCustom) {
      return [
        pw.Text(
          custom,
          style: const pw.TextStyle(fontSize: 8.2, color: gsPdfInk, lineSpacing: 1.25),
        ),
      ];
    }
    return [
      pw.Text(
        _tempProcedureText,
        style: const pw.TextStyle(fontSize: 8.2, color: gsPdfInk, lineSpacing: 1.25),
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        'O erro do instrumento foi determinado conforme expressão a seguir:',
        style: const pw.TextStyle(fontSize: 8.2, color: gsPdfInk, lineSpacing: 1.25),
      ),
      pw.SizedBox(height: 3),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 10),
        child: pw.Text(
          'Erro = Vi - Vc',
          style: pw.TextStyle(
            fontSize: 8.8,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfNavy,
          ),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'onde:\nVc -> Valor Convencional (padrão)\nVi -> Valor Indicado no Instrumento',
        style: const pw.TextStyle(fontSize: 8.0, color: gsPdfInk, lineSpacing: 1.25),
      ),
    ];
  }
  return [
    pw.Text(
      _methodText(job),
      style: const pw.TextStyle(fontSize: 8.2, color: gsPdfInk, lineSpacing: 1.25),
    ),
  ];
}

List<(String, String)> _telemetryInstrumentPairs(CalibrationJob job) {
  final principle = job.workingPrinciple.trim().isNotEmpty
      ? job.workingPrinciple.trim()
      : 'Servo Operado';
  return [
    ('Instrumento', job.equipmentType.trim()),
    ('TAG', job.equipmentTag.trim()),
    ('Fabricante', job.manufacturer.trim()),
    ('Modelo', job.model.trim()),
    if (principle.isNotEmpty)
      ('Princípio de Funcionamento', principle),
    ('Concentradora', job.concentrator.trim()),
    ('Device ID', job.deviceId.trim()),
    ('Nº de série', job.serialNumber.trim()),
    ('Local de instalação', job.installLocation.trim()),
  ];
}

List<(String, String)> _telemetryConditionPairs(CalibrationJob job) {
  return [
    ('Tipo de tanque', job.tankType.trim()),
    ('Local / base', job.site.trim()),
  ];
}

pw.Widget _telemetryStandards(CalibrationJob job) {
  final items = _uniqueStandards(job);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) pw.SizedBox(height: 8),
        pw.Text(
          items[i].description.trim().isEmpty
              ? 'Padrão ${i + 1}'
              : items[i].description.trim(),
          style: pw.TextStyle(
            fontSize: 8.4,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfNavy,
          ),
        ),
        pw.SizedBox(height: 3),
        gsTwoColPairs([
          ('Fabricante', items[i].manufacturer.trim()),
          ('Modelo', items[i].model.trim()),
          ('N.º de série', items[i].serialNumber.trim()),
          ('TAG', items[i].tag.trim()),
          ('Certificado de calibração', items[i].certificate.trim()),
          ('Executante', items[i].executant.trim()),
          ('Data de calibração', items[i].calibrationDate.trim()),
          ('Validade', items[i].validity.trim()),
        ]),
      ],
    ],
  );
}

List<pw.Widget> _telemetryResultTables(
  CalibrationJob job, {
  required bool found,
}) {
  final widgets = <pw.Widget>[];
  for (final channel in job.telemetryChannels) {
    final takes = [
      for (final take in channel.takes(found: found))
        if (take.isFilled) take,
    ];
    if (takes.isEmpty) continue;
    widgets.add(
      gsKeep([
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4, top: 4),
          child: pw.Text(
            found
                ? (channel.isLevel
                      ? 'Verificação do transmissor de nível'
                      : 'Verificação do transmissor de temperatura')
                : (channel.isLevel
                      ? 'Calibração do transmissor de nível'
                      : 'Calibração do transmissor de temperatura'),
            style: pw.TextStyle(
              fontSize: 8.2,
              fontWeight: pw.FontWeight.bold,
              color: gsPdfNavy,
            ),
          ),
        ),
        _telemetryChannelTable(channel, takes, found: found),
        pw.SizedBox(height: 8),
      ]),
    );
  }
  return widgets;
}

pw.Widget _telemetryChannelTable(
  TelemetryChannel channel,
  List<TelemetryTake> takes, {
  required bool found,
}) {
  final unit = channel.unit.trim().isEmpty ? '' : channel.unit.trim();
  final mean = channel.meanError(found: found);
  final showMean = channel.isLevel && takes.length > 1;
  return pw.Table(
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: {
      0: const pw.FlexColumnWidth(1.1),
      1: const pw.FlexColumnWidth(1.15),
      2: const pw.FlexColumnWidth(1.25),
      3: const pw.FlexColumnWidth(0.9),
      if (showMean) 4: const pw.FlexColumnWidth(0.95),
    },
    children: [
      ...gsTableHeader([
        GsColHead(channel.isLevel ? 'Tomada de prova' : 'Sensor'),
        GsColHead('Padrão utilizado', unit: unit),
        GsColHead('Instrumento sob prova', unit: unit),
        GsColHead('Erro', unit: unit),
        if (showMean) GsColHead('Erro médio', unit: unit),
      ]),
      for (var i = 0; i < takes.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isOdd ? gsPdfRow : PdfColors.white,
          ),
          children: [
            gsTableCell(
              channel.isLevel ? '${i + 1}' : channel.label,
            ),
            gsTableCell(_fmt(takes[i].standard, digits: 1)),
            gsTableCell(_fmt(takes[i].instrument, digits: 1)),
            gsTableCell(_fmt(takes[i].error, digits: 1)),
            if (showMean) gsTableCell(i == 0 ? _fmt(mean, digits: 1) : ''),
          ],
        ),
    ],
  );
}

pw.Widget _telemetrySignatory(
  CalibrationJob job,
  String date,
  String issued, {
  bool withSignature = false,
  DateTime? signedAt,
}) {
  final field = job.fieldTechnicianName.trim();
  final signer = job.technicianName.trim();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (date.isNotEmpty) gsKv('Data da calibração', date),
            if (issued.isNotEmpty) gsKv('Data da emissão', issued),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (field.isNotEmpty)
            pw.Expanded(
              child: _signatureBlock(
                name: field,
                role: staffCargoForName(field),
                withSignature: withSignature,
                digital: personHasDigitalCertificate(name: field),
                signedAt: signedAt,
              ),
            ),
          if (field.isNotEmpty) pw.SizedBox(width: 24),
          pw.Expanded(
            child: _signatureBlock(
              name: signer.isEmpty ? '—' : signer,
              role: signer.toLowerCase().contains('cleber')
                  ? 'Diretor / Signatário autorizado'
                  : 'Signatário autorizado',
              withSignature: withSignature,
              digital: personHasDigitalCertificate(name: signer),
              signedAt: signedAt,
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _signatureBlock({
  required String name,
  required String role,
  bool withSignature = false,
  bool digital = false,
  DateTime? signedAt,
}) {
  if (withSignature && !digital && name.trim().isNotEmpty && name != '—') {
    final lines = electronicSignatureLines(
      name: name,
      cargo: role,
      signedAt: signedAt ?? DateTime.now(),
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              lines[i],
              style: pw.TextStyle(
                fontSize: i == 1 ? 11 : 8.5,
                fontWeight: i <= 1 ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: gsPdfNavy,
              ),
            ),
          ),
      ],
    );
  }
  return pw.Column(
    children: [
      pw.SizedBox(height: 28),
      pw.Container(width: 180, height: 1.4, color: gsPdfGold),
      pw.SizedBox(height: 5),
      pw.Text(
        name,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: gsPdfNavy,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        role,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 8, color: gsPdfMuted),
      ),
      if (withSignature && digital) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          'Espaço para assinatura digital ICP-Brasil',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7.5, color: gsPdfMuted),
        ),
      ],
    ],
  );
}

String _formatCnpj(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 14) {
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12, 14)}';
  }
  return raw.trim();
}

pw.Widget _clientHeaderBlock(CalibrationJob job) {
  final client = ClientStore.instance.byId(job.clientId) ??
      ClientStore.instance.findMatch(cnpj: job.clientCnpj, name: job.clientName);
  final requester = gsCertPrint(
    job.serviceRequester.trim().isNotEmpty
        ? job.serviceRequester.trim()
        : (client?.requester.trim() ?? ''),
  );
  final clientName = gsCertPrint(
    job.clientName.trim().isNotEmpty
        ? job.clientName.trim()
        : (client?.name.trim() ?? ''),
  );

  final items = <pw.Widget>[];

  if (requester.isNotEmpty) {
    items.add(
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(2, 1, 2, 2),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: 'Solicitante do serviço:  ',
                style: pw.TextStyle(
                  fontSize: 7.8,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryGold,
                ),
              ),
              pw.TextSpan(
                text: requester,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  if (clientName.isNotEmpty) {
    items.add(
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(2, 1, 2, 3),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: requester.isNotEmpty ? 'Cliente / Contratante:  ' : 'Contratante:  ',
                style: pw.TextStyle(
                  fontSize: 7.8,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryGold,
                ),
              ),
              pw.TextSpan(
                text: clientName,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: items,
  );
}

List<(String, String)> _clientPairs(CalibrationJob job) {
  final client = ClientStore.instance.byId(job.clientId) ??
      ClientStore.instance.findMatch(cnpj: job.clientCnpj, name: job.clientName);

  final cnpj = _formatCnpj(
    job.clientCnpj.trim().isNotEmpty
        ? job.clientCnpj.trim()
        : (client?.cnpj.trim() ?? ''),
  );

  final address = job.clientAddress.trim().isNotEmpty
      ? job.clientAddress.trim()
      : (client?.addressLine.trim() ?? '');

  final order = job.orderNumber.trim();

  return [
    if (cnpj.isNotEmpty) ('CNPJ', cnpj),
    if (order.isNotEmpty) ('Nº do Pedido', order),
    if (address.isNotEmpty) ('Endereço', address),
  ];
}

SavedOs? osLinkedToCalibrationJob(CalibrationJob job) {
  final osId = job.osId.trim();
  if (osId.isNotEmpty) {
    final os = FieldStore.instance.byId(osId);
    if (os != null) return os;
  }
  final want = job.osNumber.trim().toLowerCase();
  if (want.isEmpty) return null;
  for (final item in FieldStore.instance.items) {
    if (item.number.trim().toLowerCase() == want) return item;
  }
  return null;
}

/// Slot da mesma OS. A lista mostra estes TAG/N/S; o PDF tem que repetir.
OsCalibrationSlot? slotLinkedToCalibrationJob(CalibrationJob job) {
  final os = osLinkedToCalibrationJob(job);
  if (os == null) return null;
  final slotId = job.calibrationSlotId.trim();
  if (slotId.isNotEmpty) {
    for (final slot in os.calibrationSlots) {
      if (slot.id == slotId) return slot;
    }
  }
  final number = job.number.trim().toLowerCase();
  if (number.isEmpty) return null;
  for (final slot in os.calibrationSlots) {
    if (slot.certificateNumber.trim().toLowerCase() == number) return slot;
  }
  return null;
}

/// Prepara o certificado para o PDF/livro sem trocar o medidor por outro do local.
CalibrationJob prepareCertificateJob(CalibrationJob job) {
  final slot = slotLinkedToCalibrationJob(job);
  var next = calibrationJobForCertificatePrint(job, slot: slot);
  final client = ClientStore.instance.byId(next.clientId) ??
      ClientStore.instance.findMatch(
        cnpj: next.clientCnpj,
        name: next.clientName,
      );
  if (client != null &&
      next.serviceRequester.trim().isEmpty &&
      client.requester.trim().isNotEmpty) {
    next = next.copyWith(serviceRequester: client.requester.trim());
  }
  // Mesma base do campo "Local" no PDF: sistema casado por N/S/preset/systemId.
  // Sem isso o book agrupa tudo em BASPA/vazio e some a página LOCAL por ilha.
  var systemLocal = '';
  var equipmentLocal = '';
  if (client != null) {
    final systems = client.resolvedSystems;
    final equipment = client.equipment;
    final system = systemForCertificate(
      next,
      systems: systems,
      equipment: equipment,
    );
    systemLocal = system?.installLocation.trim() ?? '';
    final serialKey = next.serialNumber.trim().toLowerCase();
    if (serialKey.isNotEmpty) {
      for (final item in equipment) {
        if (item.serialNumber.trim().toLowerCase() != serialKey) continue;
        final loc = item.installLocation.trim();
        if (isUsefulSystemLocal(loc, site: next.site) &&
            !installLocationLooksLikePresetTag(next, loc)) {
          equipmentLocal = loc;
          break;
        }
      }
    }
  }
  final local = resolveCertificateInstallLocation(
    next,
    client: client,
    systemLocal: systemLocal,
    equipmentLocal: equipmentLocal,
  );
  if (local.isNotEmpty) {
    next = next.copyWith(installLocation: local);
  } else if (!isUsefulSystemLocal(next.installLocation, site: next.site) ||
      installLocationLooksLikePresetTag(next)) {
    next = next.copyWith(installLocation: '');
  }
  return next;
}

bool _sameKey(String a, String b) {
  final left = a.trim().toLowerCase();
  final right = b.trim().toLowerCase();
  return left.isNotEmpty && left == right;
}

ClientSystem? _systemById(List<ClientSystem> systems, String id) {
  final needle = id.trim();
  if (needle.isEmpty) return null;
  for (final system in systems) {
    if (system.id == needle) return system;
  }
  return null;
}

/// Sistema deste certificado: N/S, TAG ou preset. Local sozinho não escolhe
/// a primeira plataforma quando há várias no mesmo lugar.
ClientSystem? systemForCertificate(
  CalibrationJob job, {
  required List<ClientSystem> systems,
  required List<ClientEquipment> equipment,
}) {
  final serial = job.serialNumber.trim().toLowerCase();
  final tag = job.equipmentTag.trim().toLowerCase();
  final preset = job.presetTag.trim().toLowerCase();

  ClientSystem? only(Iterable<ClientSystem> hits) {
    ClientSystem? found;
    for (final system in hits) {
      if (found != null && found.id != system.id) return null;
      found = system;
    }
    return found;
  }

  // N/S e TAG separados: TAG repetida entre ilhas (FT em 3A e 5B) não pode
  // anular o N/S único no mesmo `only()` com OR.
  // Inclui medidor, PT100 e densímetro (temp/dens caíam em "Sem local").
  bool hasSerial(ClientSystem system) => system.instruments.any(
        (item) => item.serialNumber.trim().toLowerCase() == serial,
      );
  bool hasTag(ClientSystem system) =>
      system.instruments.any((item) => item.tag.trim().toLowerCase() == tag);

  if (serial.isNotEmpty) {
    final bySerial = only([
      for (final system in systems)
        if (hasSerial(system)) system,
    ]);
    if (bySerial != null) return bySerial;
  }
  if (tag.isNotEmpty) {
    final byTag = only([
      for (final system in systems)
        if (hasTag(system)) system,
    ]);
    if (byTag != null) return byTag;
  }

  if (preset.isNotEmpty) {
    final byPreset = only([
      for (final system in systems)
        if (_sameKey(system.assemblyTag, preset) || _sameKey(system.tag, preset))
          system,
    ]);
    if (byPreset != null) return byPreset;
  }

  ClientEquipment? matched;
  if (serial.isNotEmpty) {
    for (final item in equipment) {
      if (item.serialNumber.trim().toLowerCase() == serial) {
        matched = item;
        break;
      }
    }
  }
  if (matched == null && tag.isNotEmpty) {
    ClientEquipment? onlyTag;
    for (final item in equipment) {
      if (item.tag.trim().toLowerCase() != tag) continue;
      if (onlyTag != null &&
          onlyTag.systemId.trim() != item.systemId.trim()) {
        onlyTag = null;
        break;
      }
      onlyTag = item;
    }
    matched = onlyTag;
  }
  final fromEquipment = _systemById(systems, matched?.systemId ?? '');
  if (fromEquipment != null) return fromEquipment;

  final stored = _systemById(systems, job.systemId);
  if (stored != null) {
    final assembly = stored.assemblyTag.trim().toLowerCase();
    if (preset.isEmpty || assembly.isEmpty || assembly == preset) return stored;
  }

  final local = calibrationSystemLocal(job).toLowerCase();
  if (local.isNotEmpty) {
    final atPlace = [
      for (final system in systems)
        if (system.installLocation.trim().toLowerCase() == local) system,
    ];
    if (atPlace.length == 1) return atPlace.first;
  }
  return null;
}

/// Medidor deste certificado. Nunca o primeiro da plataforma vizinha.
ClientInstrument? meterForCertificate(ClientSystem? system, CalibrationJob job) {
  if (system == null) return null;
  final meters = system.meters;
  final serial = job.serialNumber.trim().toLowerCase();
  final tag = job.equipmentTag.trim().toLowerCase();
  for (final meter in meters) {
    if (serial.isNotEmpty &&
        meter.serialNumber.trim().toLowerCase() == serial) {
      return meter;
    }
  }
  for (final meter in meters) {
    if (tag.isNotEmpty && meter.tag.trim().toLowerCase() == tag) return meter;
  }
  if (serial.isEmpty && tag.isEmpty && meters.length == 1) return meters.first;
  return null;
}

List<(String, String)> _systemPairs(CalibrationJob job) {
  final client = ClientStore.instance.byId(job.clientId) ??
      ClientStore.instance.findMatch(cnpj: job.clientCnpj, name: job.clientName);
  final systems = client?.resolvedSystems ?? const [];
  final equipment = client?.equipment ?? const [];
  final system = systemForCertificate(
    job,
    systems: systems,
    equipment: equipment,
  );
  ClientEquipment? matchedEq;
  final serialKey = job.serialNumber.trim().toLowerCase();
  final tagKey = job.equipmentTag.trim().toLowerCase();
  for (final item in equipment) {
    if (serialKey.isNotEmpty &&
        item.serialNumber.trim().toLowerCase() == serialKey) {
      matchedEq = item;
      break;
    }
  }
  if (matchedEq == null && tagKey.isNotEmpty) {
    for (final item in equipment) {
      if (item.tag.trim().toLowerCase() == tagKey) {
        matchedEq = item;
        break;
      }
    }
  }

  final sysType = job.systemType.trim().isNotEmpty
      ? job.systemType.trim()
      : (system?.systemType.trim().isNotEmpty == true
          ? system!.systemType.trim()
          : (matchedEq?.systemType.trim().isNotEmpty == true
              ? matchedEq!.systemType.trim()
              : '—'));
  final tag = job.systemTag.trim().isNotEmpty
      ? job.systemTag.trim()
      : (system?.tag.trim().isNotEmpty == true
          ? system!.tag.trim()
          : (matchedEq?.systemTag.trim() ?? ''));
  final location = calibrationSystemLocal(
    job,
    systemLocal: system?.installLocation ?? '',
    equipmentLocal: matchedEq?.installLocation ?? '',
  );

  final pairs = <(String, String)>[
    ('Tipo de sistema', sysType),
    if (tag.isNotEmpty) ('TAG do sistema', tag),
    if (location.isNotEmpty) ('Local', location),
  ];

  // Complementary instruments of the system (preset, etc.)
  final isMeterJob = job.isVolumetric ||
      job.kind == CalibrationKind.volumetric ||
      job.kind == CalibrationKind.volumetricInverted;
  final isTempJob = job.kind == CalibrationKind.temperature ||
      job.kind == CalibrationKind.temperatureMesh;
  final isDensityJob = job.kind == CalibrationKind.density;

  // Preset
  final presetTag = job.presetTag.trim().isNotEmpty
      ? job.presetTag.trim()
      : (system?.assemblyTag.trim() ?? '');
  final presetMfg = job.presetManufacturer.trim().isNotEmpty
      ? job.presetManufacturer.trim()
      : (system?.manufacturer.trim() ?? '');
  final presetModel = job.presetModel.trim().isNotEmpty
      ? job.presetModel.trim()
      : (system?.model.trim() ?? '');
  final presetSerial = job.presetSerial.trim().isNotEmpty
      ? job.presetSerial.trim()
      : (system?.serialNumber.trim() ?? '');
  if (presetTag.isNotEmpty || presetSerial.isNotEmpty || presetModel.isNotEmpty) {
    final presetDesc = [
      if (presetTag.isNotEmpty) 'TAG: $presetTag',
      if (presetMfg.isNotEmpty) 'Fab.: $presetMfg',
      if (presetModel.isNotEmpty) 'Mod.: $presetModel',
      if (presetSerial.isNotEmpty) 'N/S: $presetSerial',
    ].join(' | ');
    pairs.add(('Preset do Sistema', presetDesc));
  }

  // If this is NOT a meter calibration, include the system's meter in system data
  if (!isMeterJob) {
    final meter = system?.meters.firstOrNull;
    if (meter != null && (meter.tag.isNotEmpty || meter.serialNumber.isNotEmpty)) {
      final meterDesc = [
        if (meter.tag.isNotEmpty) 'TAG: ${meter.tag}',
        if (meter.manufacturer.isNotEmpty) 'Fab.: ${meter.manufacturer}',
        if (meter.model.isNotEmpty) 'Mod.: ${meter.model}',
        if (meter.serialNumber.isNotEmpty) 'N/S: ${meter.serialNumber}',
      ].join(' | ');
      pairs.add(('Medidor do Sistema', meterDesc));
    }
  }

  // If this is NOT a densimeter calibration, include densimeter in system data
  if (!isDensityJob) {
    final dens = system?.densimeters.firstOrNull;
    if (dens != null && (dens.tag.isNotEmpty || dens.serialNumber.isNotEmpty)) {
      final densDesc = [
        if (dens.tag.isNotEmpty) 'TAG: ${dens.tag}',
        if (dens.manufacturer.isNotEmpty) 'Fab.: ${dens.manufacturer}',
        if (dens.model.isNotEmpty) 'Mod.: ${dens.model}',
        if (dens.serialNumber.isNotEmpty) 'N/S: ${dens.serialNumber}',
      ].join(' | ');
      pairs.add(('Densímetro do Sistema', densDesc));
    }
  }

  // If this is NOT a temp calibration, include temp sensor in system data
  if (!isTempJob) {
    final pt = system?.pt100s.firstOrNull;
    final ptIsCalibratedItem = pt != null &&
        pt.serialNumber.trim().isNotEmpty &&
        pt.serialNumber.trim() == job.serialNumber.trim();
    if (pt != null &&
        !ptIsCalibratedItem &&
        (pt.tag.isNotEmpty || pt.serialNumber.isNotEmpty)) {
      final ptDesc = [
        if (pt.tag.isNotEmpty) 'TAG: ${pt.tag}',
        if (pt.manufacturer.isNotEmpty) 'Fab.: ${pt.manufacturer}',
        if (pt.model.isNotEmpty) 'Mod.: ${pt.model}',
        if (pt.serialNumber.isNotEmpty) 'N/S: ${pt.serialNumber}',
      ].join(' | ');
      pairs.add(('Sensor de Temp. do Sistema', ptDesc));
    }
  }

  return pairs;
}

pw.Widget _instrumentSubSection(String title, List<(String, String)> pairs) {
  final visible = [
    for (final pair in pairs)
      if (gsCertPrint(pair.$2).isNotEmpty) (pair.$1, gsCertPrint(pair.$2)),
  ];
  if (visible.isEmpty) return pw.SizedBox();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 8.8,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfNavy,
          ),
        ),
        pw.SizedBox(height: 1),
        gsTwoColPairs(visible),
      ],
    ),
  );
}

List<pw.Widget> _instrumentsBlock(CalibrationJob job, {required String date}) {
  final client = ClientStore.instance.byId(job.clientId) ??
      ClientStore.instance.findMatch(cnpj: job.clientCnpj, name: job.clientName);
  final systems = client?.resolvedSystems ?? const [];
  final system = systemForCertificate(
    job,
    systems: systems,
    equipment: client?.equipment ?? const [],
  );
  final matchedMeter = meterForCertificate(system, job);

  String meterDimensions = matchedMeter?.dimensions.trim() ?? '';
  if (meterDimensions.isEmpty) {
    for (final m in system?.meters ?? const <ClientInstrument>[]) {
      if (job.equipmentTag.trim().isNotEmpty &&
          m.tag.trim().toLowerCase() != job.equipmentTag.trim().toLowerCase()) {
        continue;
      }
      if (m.dimensions.trim().isNotEmpty) {
        meterDimensions = m.dimensions.trim();
        break;
      }
    }
  }

  final blocks = <pw.Widget>[];

  final isMeterJob = job.isVolumetric ||
      job.kind == CalibrationKind.volumetric ||
      job.kind == CalibrationKind.volumetricInverted;
  final isTempJob = job.kind == CalibrationKind.temperature ||
      job.kind == CalibrationKind.temperatureMesh;
  final isDensityJob = job.kind == CalibrationKind.density;
  final isPressureJob = job.kind == CalibrationKind.pressure;
  final isConductivityJob = job.isConductivity;

  if (isMeterJob) {
    // CARACTERÍSTICAS DO INSTRUMENTO CALIBRADO: Medidor
    final meterPrinciple = job.workingPrinciple.trim().isNotEmpty
        ? job.workingPrinciple.trim()
        : (matchedMeter != null && matchedMeter.workingPrinciple.trim().isNotEmpty
            ? matchedMeter.workingPrinciple.trim()
            : (job.equipmentType.toLowerCase().contains('coriolis') ? 'Coriolis' : 'Medição Volumétrica'));
    blocks.add(
      _instrumentSubSection('Medidor de Vazão:', [
        ('Fabricante', job.manufacturer.trim().isNotEmpty ? job.manufacturer.trim() : (matchedMeter?.manufacturer.trim() ?? '')),
        ('Nº de série', job.serialNumber.trim().isNotEmpty ? job.serialNumber.trim() : (matchedMeter?.serialNumber.trim() ?? '')),
        if (meterDimensions.isNotEmpty) ('Diâmetro do Medidor', meterDimensions),
        ('Modelo', job.model.trim().isNotEmpty ? job.model.trim() : (matchedMeter?.model.trim() ?? '')),
        if (meterPrinciple.isNotEmpty)
          ('Princípio de Funcionamento', meterPrinciple),
        ('Tag', job.equipmentTag.trim().isNotEmpty ? job.equipmentTag.trim() : (matchedMeter?.tag.trim() ?? '')),
        if (job.installLocation.trim().isNotEmpty)
          ('Local de Instalação', job.installLocation.trim()),
        ('Data da calibração', date),
      ]),
    );
  } else if (isTempJob) {
    // CARACTERÍSTICAS DO INSTRUMENTO CALIBRADO: Temperatura (PT100 / Termorresistência / Transmissor)
    final pt100List = system?.pt100s ?? const <ClientInstrument>[];
    final matchedPt = pt100List.firstWhere(
      (pt) =>
          (job.serialNumber.trim().isNotEmpty &&
              (pt.serialNumber.trim().toLowerCase() == job.serialNumber.trim().toLowerCase() ||
                  pt.meshSerialNumber.trim().toLowerCase() == job.serialNumber.trim().toLowerCase())) ||
          (job.equipmentTag.trim().isNotEmpty &&
              (pt.tag.trim().toLowerCase() == job.equipmentTag.trim().toLowerCase() ||
                  pt.meshTag.trim().toLowerCase() == job.equipmentTag.trim().toLowerCase())) ||
          job.equipmentId == pt.id ||
          job.equipmentId == '${pt.id}-mesh',
      orElse: () => const ClientInstrument(id: ''),
    );

    final mfg = job.manufacturer.trim().isNotEmpty
        ? job.manufacturer.trim()
        : (matchedPt.manufacturer.trim().isNotEmpty ? matchedPt.manufacturer.trim() : system?.pt100s.firstOrNull?.manufacturer.trim() ?? '');
    final serial = job.serialNumber.trim().isNotEmpty
        ? job.serialNumber.trim()
        : (matchedPt.serialNumber.trim().isNotEmpty ? matchedPt.serialNumber.trim() : system?.pt100s.firstOrNull?.serialNumber.trim() ?? '');
    final tag = job.equipmentTag.trim().isNotEmpty
        ? job.equipmentTag.trim()
        : (matchedPt.tag.trim().isNotEmpty ? matchedPt.tag.trim() : system?.pt100s.firstOrNull?.tag.trim() ?? '');
    final model = job.model.trim().isNotEmpty
        ? job.model.trim()
        : (matchedPt.model.trim().isNotEmpty ? matchedPt.model.trim() : system?.pt100s.firstOrNull?.model.trim() ?? '');
    final isMesh = job.kind == CalibrationKind.temperatureMesh;
    final defaultPrinciple = isMesh ? 'Malha de temperatura' : 'Termorresistência';
    final principle = job.workingPrinciple.trim().isNotEmpty
        ? job.workingPrinciple.trim()
        : (matchedPt.workingPrinciple.trim().isNotEmpty
            ? matchedPt.workingPrinciple.trim()
            : (isMesh && matchedPt.meshWorkingPrinciple.trim().isNotEmpty
                ? matchedPt.meshWorkingPrinciple.trim()
                : defaultPrinciple));

    final hasMeshInfo = matchedPt.meshTag.trim().isNotEmpty ||
        matchedPt.meshSerialNumber.trim().isNotEmpty ||
        matchedPt.meshModel.trim().isNotEmpty ||
        matchedPt.meshManufacturer.trim().isNotEmpty;

    final title = isMesh
        ? 'Sensor de Temperatura / Malha:'
        : 'Sensor de Temperatura / PT100:';

    blocks.add(
      _instrumentSubSection(title, [
        ('Fabricante', mfg),
        ('Nº de série', serial),
        ('Tag', tag),
        ('Modelo', model),
        if (principle.isNotEmpty)
          ('Princípio de Funcionamento', principle),
        if (hasMeshInfo && matchedPt.meshTag.trim().isNotEmpty)
          ('Tag da Malha', matchedPt.meshTag.trim()),
        if (hasMeshInfo && matchedPt.meshModel.trim().isNotEmpty)
          ('Modelo da Malha', matchedPt.meshModel.trim()),
        if (hasMeshInfo && matchedPt.meshSerialNumber.trim().isNotEmpty)
          ('Nº de Série da Malha', matchedPt.meshSerialNumber.trim()),
        if (hasMeshInfo &&
            matchedPt.meshWorkingPrinciple.trim().isNotEmpty &&
            matchedPt.meshWorkingPrinciple.trim() != principle)
          ('Princípio da Malha', matchedPt.meshWorkingPrinciple.trim()),
        if (job.installLocation.trim().isNotEmpty)
          ('Local de Instalação', job.installLocation.trim()),
        ('Data da calibração', date),
      ]),
    );
  } else if (isDensityJob) {
    // CARACTERÍSTICAS DO INSTRUMENTO CALIBRADO: Densímetro
    final densList = system?.densimeters ?? const <ClientInstrument>[];
    final matchedDens = densList.firstWhere(
      (d) =>
          (job.serialNumber.trim().isNotEmpty && d.serialNumber.trim().toLowerCase() == job.serialNumber.trim().toLowerCase()) ||
          (job.equipmentTag.trim().isNotEmpty && d.tag.trim().toLowerCase() == job.equipmentTag.trim().toLowerCase()) ||
          job.equipmentId == d.id,
      orElse: () => const ClientInstrument(id: ''),
    );
    final mfg = job.manufacturer.trim().isNotEmpty
        ? job.manufacturer.trim()
        : (matchedDens.manufacturer.trim().isNotEmpty ? matchedDens.manufacturer.trim() : system?.densimeters.firstOrNull?.manufacturer.trim() ?? '');
    final serial = job.serialNumber.trim().isNotEmpty
        ? job.serialNumber.trim()
        : (matchedDens.serialNumber.trim().isNotEmpty ? matchedDens.serialNumber.trim() : system?.densimeters.firstOrNull?.serialNumber.trim() ?? '');
    final tag = job.equipmentTag.trim().isNotEmpty
        ? job.equipmentTag.trim()
        : (matchedDens.tag.trim().isNotEmpty ? matchedDens.tag.trim() : system?.densimeters.firstOrNull?.tag.trim() ?? '');
    final model = job.model.trim().isNotEmpty
        ? job.model.trim()
        : (matchedDens.model.trim().isNotEmpty ? matchedDens.model.trim() : system?.densimeters.firstOrNull?.model.trim() ?? '');
    final principle = job.workingPrinciple.trim().isNotEmpty
        ? job.workingPrinciple.trim()
        : (matchedDens.workingPrinciple.trim().isNotEmpty ? matchedDens.workingPrinciple.trim() : 'Tubo Vibratório');

    blocks.add(
      _instrumentSubSection('Densímetro:', [
        ('Fabricante', mfg),
        ('Nº de série', serial),
        ('Tag', tag),
        ('Modelo', model),
        if (principle.isNotEmpty)
          ('Princípio de Funcionamento', principle),
        if (job.installLocation.trim().isNotEmpty)
          ('Local de Instalação', job.installLocation.trim()),
        ('Data da calibração', date),
      ]),
    );
  } else if (isPressureJob) {
    // CARACTERÍSTICAS DO INSTRUMENTO CALIBRADO: Pressão (Manômetro / Pressostato / PSV / Transmissor)
    String pressureTitle = 'Instrumento de Pressão:';
    final eqLow = '${job.equipmentType} ${job.title}'.toLowerCase();
    if (eqLow.contains('pressost')) {
      pressureTitle = 'Pressostato:';
    } else if (eqLow.contains('psv') || eqLow.contains('valvula') || eqLow.contains('alivio') || eqLow.contains('seguranca')) {
      pressureTitle = 'Válvula de Segurança (PSV):';
    } else if (eqLow.contains('transm')) {
      pressureTitle = 'Transmissor de Pressão:';
    } else if (eqLow.contains('manom') || eqLow.isEmpty) {
      pressureTitle = 'Manômetro:';
    }

    final principle = job.workingPrinciple.trim().isNotEmpty
        ? job.workingPrinciple.trim()
        : (eqLow.contains('pressost')
            ? 'Eletromecânico'
            : (eqLow.contains('psv')
                ? 'Mola calibrada'
                : (eqLow.contains('transm')
                    ? 'Piezorresistivo'
                    : 'Deformação elástica (Bourdon)')));

    blocks.add(
      _instrumentSubSection(pressureTitle, [
        ('Fabricante', job.manufacturer.trim()),
        ('Nº de série', job.serialNumber.trim()),
        ('Tag', job.equipmentTag.trim()),
        ('Modelo', job.model.trim()),
        if (principle.isNotEmpty)
          ('Princípio de Funcionamento', principle),
        if (job.installLocation.trim().isNotEmpty)
          ('Local de Instalação', job.installLocation.trim()),
        ('Data da calibração', date),
      ]),
    );
  } else if (isConductivityJob) {
    final principle = job.workingPrinciple.trim().isNotEmpty
        ? job.workingPrinciple.trim()
        : 'Célula de condutividade';
    blocks.add(
      _instrumentSubSection('Condutivímetro:', [
        ('Fabricante', job.manufacturer.trim()),
        ('Nº de série', job.serialNumber.trim()),
        ('Tag', job.equipmentTag.trim()),
        ('Modelo', job.model.trim()),
        if (principle.isNotEmpty)
          ('Princípio de Funcionamento', principle),
        if (job.measurementUnit.trim().isNotEmpty)
          ('Unidade de medida', job.measurementUnit.trim()),
        if (job.installLocation.trim().isNotEmpty)
          ('Local de Instalação', job.installLocation.trim()),
        ('Data da calibração', date),
      ]),
    );
  } else {
    // Telemetria ou outro
    final principle = job.workingPrinciple.trim().isNotEmpty
        ? job.workingPrinciple.trim()
        : (job.isTelemetry ? 'Servo Operado' : '');
    blocks.add(
      _instrumentSubSection('Instrumento:', [
        ('Fabricante', job.manufacturer.trim()),
        ('Nº de série', job.serialNumber.trim()),
        ('Tag', job.equipmentTag.trim()),
        ('Modelo', job.model.trim()),
        if (principle.isNotEmpty)
          ('Princípio de Funcionamento', principle),
        if (job.installLocation.trim().isNotEmpty)
          ('Local de Instalação', job.installLocation.trim()),
        ('Data da calibração', date),
      ]),
    );
  }

  return blocks;
}

List<(String, String)> _conditionPairs(CalibrationJob job) {
  final hasFluid = job.fluid.trim().isNotEmpty;
  final densityMin = job.fluidDensityMin.trim();
  final densityMax = job.fluidDensityMax.trim();
  final viscosityMin = job.fluidViscosityMin.trim();
  final viscosityMax = job.fluidViscosityMax.trim();
  final hasDensityCadastro =
      hasFluid && (densityMin.isNotEmpty || densityMax.isNotEmpty);
  final hasViscosityCadastro =
      hasFluid && (viscosityMin.isNotEmpty || viscosityMax.isNotEmpty);
  final densityCadastro = catalogRangeLabel(densityMin, densityMax);
  final viscosityCadastro = catalogRangeLabel(viscosityMin, viscosityMax);
  final densityRefTemp = job.fluidDensityRefTemp.trim().isNotEmpty
      ? job.fluidDensityRefTemp.trim()
      : (job.fluidReferenceTemp.trim().isNotEmpty
          ? job.fluidReferenceTemp.trim()
          : fluidDensityRefTempDefault);
  final viscosityRefTemp = job.fluidViscosityRefTemp.trim().isNotEmpty
      ? job.fluidViscosityRefTemp.trim()
      : fluidViscosityRefTempDefault;
  // Só o que o usuário preencheu — não inventa a partir das medições.
  final productDensity = job.productDensity.trim();
  final productTemp = job.productTemperature.trim();

  return [
    ('Temperatura ambiente', _unit(job.ambientTemp, '°C')),
    ('Umidade relativa do ar', _unit(job.humidity, '%ur')),
    ('Pressão média atmosférica', _unit(job.pressure, 'hPa')),
    if (hasFluid) ('Produto / fluido', job.fluid.trim()),
    if (hasDensityCadastro) ...[
      if (densityMin.isNotEmpty && densityMax.isNotEmpty) ...[
        ('Densidade mínima (cadastro)', densityMin),
        ('Densidade máxima (cadastro)', densityMax),
      ] else ...[
        ('Densidade do produto (cadastro)', densityCadastro),
      ],
      (
        'Temperatura de referência da densidade (cadastro)',
        densityRefTemp,
      ),
    ],
    if (hasViscosityCadastro) ...[
      if (viscosityMin.isNotEmpty && viscosityMax.isNotEmpty) ...[
        ('Viscosidade mínima (cadastro)', viscosityMin),
        ('Viscosidade máxima (cadastro)', viscosityMax),
      ] else ...[
        ('Viscosidade do produto (cadastro)', viscosityCadastro),
      ],
      (
        'Temperatura de referência da viscosidade (cadastro)',
        viscosityRefTemp,
      ),
    ],
    if (productDensity.isNotEmpty)
      ('Densidade do produto na calibração', productDensity),
    if (productTemp.isNotEmpty)
      ('Temperatura do produto na calibração', productTemp),
  ];
}

CalibrationJob _enrichFluidFromCatalog(CalibrationJob job) {
  final name = job.fluid.trim().toLowerCase();
  if (name.isEmpty) return job;
  final hasDensity =
      job.fluidDensityMin.trim().isNotEmpty ||
      job.fluidDensityMax.trim().isNotEmpty;
  final hasViscosity =
      job.fluidViscosityMin.trim().isNotEmpty ||
      job.fluidViscosityMax.trim().isNotEmpty;
  if (hasDensity &&
      hasViscosity &&
      job.fluidDensityRefTemp.trim().isNotEmpty &&
      job.fluidViscosityRefTemp.trim().isNotEmpty) {
    return job;
  }
  CatalogFluid? match;
  for (final item in CalibrationCatalog.instance.fluids) {
    if (item.name.trim().toLowerCase() == name) {
      match = item;
      break;
    }
  }
  if (match == null) return job;
  return job.copyWith(
    fluidDensityMin: hasDensity ? job.fluidDensityMin : match.densityMin,
    fluidDensityMax: hasDensity ? job.fluidDensityMax : match.densityMax,
    fluidViscosityMin:
        hasViscosity ? job.fluidViscosityMin : match.viscosityMin,
    fluidViscosityMax:
        hasViscosity ? job.fluidViscosityMax : match.viscosityMax,
    fluidDensityRefTemp: job.fluidDensityRefTemp.trim().isEmpty
        ? match.densityRefTemp
        : job.fluidDensityRefTemp,
    fluidViscosityRefTemp: job.fluidViscosityRefTemp.trim().isEmpty
        ? match.viscosityRefTemp
        : job.fluidViscosityRefTemp,
    fluidReferenceTemp: job.fluidDensityRefTemp.trim().isEmpty
        ? match.densityRefTemp
        : job.fluidDensityRefTemp,
  );
}

pw.Widget _standardsTable(CalibrationJob job) {
  if (job.isConductivity) {
    final unit = _genericUnit(job);
    return pw.Table(
      border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
      children: [
        ...gsTableHeader([
          const GsColHead('Padrão'),
          GsColHead('Valor nominal', unit: unit),
          GsColHead('Valor certificado', unit: unit),
          const GsColHead('Certificado nº'),
          const GsColHead('Validade'),
        ]),
        for (final item in _uniqueStandards(job))
          pw.TableRow(
            children: [
              gsTableCell(_dash(item.tag.trim().isNotEmpty ? item.tag : item.description)),
              gsTableCell(_dash(item.nominalValue)),
              gsTableCell(_dash(item.certifiedValue)),
              gsTableCell(_dash(item.certificate)),
              gsTableCell(_dash(item.validity)),
            ],
          ),
      ],
    );
  }
  return pw.Table(
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
    children: [
      gsTableHead([
        'Identificação',
        'Nº de série',
        'Nº do certificado',
        'Descrição',
        'Incerteza',
        'Validade',
      ]),
      for (final item in _uniqueStandards(job))
        pw.TableRow(
          children: [
            gsTableCell(_dash(item.tag)),
            gsTableCell(_dash(item.serialNumber)),
            gsTableCell(_dash(item.certificate)),
            gsTableCell(_dash(item.description)),
            gsTableCell(_dash(item.uncertaintyLabel)),
            gsTableCell(_dash(item.validity)),
          ],
        ),
    ],
  );
}

List<CalibrationStandard> _uniqueStandards(CalibrationJob job) {
  final seen = <String>{};
  final out = <CalibrationStandard>[];
  for (final item in job.standards) {
    if (!item.isFilled) continue;
    final serial = item.serialNumber.trim().toLowerCase();
    final cert = item.certificate.trim().toLowerCase();
    final tag = item.tag.trim().toLowerCase();
    final key = serial.isNotEmpty
        ? 's:$serial'
        : cert.isNotEmpty
            ? 'c:$cert|t:$tag'
            : [
                tag,
                item.description.trim().toLowerCase(),
              ].join('|');
    if (key.replaceAll('|', '').isEmpty) continue;
    if (!seen.add(key)) continue;
    out.add(item);
  }
  return out;
}

pw.Widget _resultsIntro(CalibrationJob job) {
  final sample = _uncertaintySample(job);
  final u = sample == null ? '' : job.resultULabel(sample, found: true);
  final k = sample == null ? '' : job.resultKLabel(sample, found: true);
  final veff = sample == null ? '' : job.resultVeffLabel(sample, found: true);
  final linearity = job.linearityApplicable && job.linearity != null
      ? formatPercent(job.linearity)
      : '';
  final kText = k.isEmpty ? 'k' : 'k = $k';
  final veffText = veff.isEmpty ? 'Veff' : 'Veff = $veff';
  final uText = u.isEmpty ? 'U' : 'U = $u';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Os resultados da calibração referem-se aos valores médios de '
        '${job.runCount} medições para cada ponto calibrado e estão contidos '
        'na(s) tabela(s) a seguir. A incerteza expandida de medição $uText '
        'relatada é declarada como a incerteza padrão de medição multiplicada '
        'pelo fator de abrangência $kText, o qual para uma distribuição t de '
        'Student com $veffText graus efetivos de liberdade, corresponde a uma '
        'probabilidade de abrangência de aproximadamente 95 %. A incerteza '
        'padrão de medição foi determinada de acordo com a publicação EA-4/02 '
        'de abril de 1998. Quando k for igual a 2,00, a distribuição de '
        'probabilidade é Normal.',
        style: const pw.TextStyle(
          fontSize: 8,
          color: gsPdfInk,
          lineSpacing: 1.2,
        ),
      ),
      if (u.isNotEmpty ||
          k.isNotEmpty ||
          veff.isNotEmpty ||
          linearity.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _ukVeffSummary(u: u, k: k, veff: veff, linearity: linearity),
      ],
    ],
  );
}

FlowPoint? _uncertaintySample(CalibrationJob job) {
  for (final point in job.filledPoints) {
    if (job.resultULabel(point, found: true).isNotEmpty) return point;
  }
  return job.filledPoints.isEmpty ? null : job.filledPoints.first;
}

pw.Widget _ukVeffSummary({
  required String u,
  required String k,
  required String veff,
  String linearity = '',
}) {
  final headers = <String>[
    'Incerteza de Medição (U)',
    'Fator de Abrangência (k)',
    'Grau efetivo de liberdade (Veff)',
    if (linearity.isNotEmpty) 'Erro de Linearidade (%)',
  ];
  return pw.Table(
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      gsTableHead(headers),
      pw.TableRow(
        children: [
          gsTableCell(_dash(u)),
          gsTableCell(_dash(k)),
          gsTableCell(_dash(veff)),
          if (linearity.isNotEmpty) gsTableCell(_dash(linearity)),
        ],
      ),
    ],
  );
}

pw.Widget _meansTable(CalibrationJob job, {required bool found}) {
  final flowUnit = _flowUnitLabel(job);
  final volumeUnit = _volumeUnitLabel(job);
  return pw.Table(
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: const {
      0: pw.FlexColumnWidth(1.15),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(0.85),
      4: pw.FlexColumnWidth(0.9),
      5: pw.FlexColumnWidth(0.9),
      6: pw.FlexColumnWidth(1.1),
      7: pw.FlexColumnWidth(1.05),
      8: pw.FlexColumnWidth(1.15),
    },
    children: [
      ...gsTableHeader([
        GsColHead(gsVolumetricFlowColumnTitle, unit: flowUnit),
        GsColHead('Display Master Totalizado', unit: volumeUnit),
        GsColHead('Display Teste Totalizado', unit: volumeUnit),
        const GsColHead('Erro de indicação', unit: '(%)'),
        const GsColHead('Desvio padrão amostral', unit: '(%)'),
        const GsColHead('Repetibilidade', unit: '(%)'),
        const GsColHead('Incerteza de Medição', unit: '(U)'),
        const GsColHead('Fator de Abrangência', unit: '(k)'),
        const GsColHead('Grau efetivo de liberdade', unit: 'Veff'),
      ]),
      for (final point in job.filledPoints)
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: gsPdfRow),
          children: [
            gsTableCell(_flow(point)),
            gsTableCell(_fmt(_meanVolume(point, found: found, standard: true))),
            gsTableCell(_fmt(_meanVolume(point, found: found, standard: false))),
            gsTableCell(_pct(_result(point, job, found: found)?.meanError)),
            gsTableCell(
              _pct(
                sampleStdev(_result(point, job, found: found)?.errors ?? const []),
              ),
            ),
            gsTableCell(_pct(_result(point, job, found: found)?.repeatability)),
            gsTableCell(_dash(job.resultULabel(point, found: found))),
            gsTableCell(_dash(job.resultKLabel(point, found: found))),
            gsTableCell(_dash(job.resultVeffLabel(point, found: found))),
          ],
        ),
    ],
  );
}

pw.Widget _coriolisMeterFactorBlock(
  CalibrationJob job, {
  required bool found,
}) {
  final items = job.coriolisFactorsOnCertificate(found: found);
  if (items.isEmpty) return pw.SizedBox();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
    child: pw.Table(
      border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const pw.IntrinsicColumnWidth(),
        for (var i = 0; i < items.length; i++) i + 1: const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: gsPdfPrimaryGold),
          children: [
            _meterFactorTitleCell(),
            for (final item in items) gsTableCell(item.label, header: true),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(color: gsPdfPrimaryGold, child: pw.SizedBox(height: 18)),
            for (final item in items)
              gsTableCell(item.valueFor(found: found), header: false),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _meterFactorTitleCell() {
  return _factorBarTitleCell('Fator do Medidor:');
}

pw.Widget _factorBarTitleCell(String title) {
  return pw.Container(
    color: gsPdfPrimaryGold,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    alignment: pw.Alignment.centerLeft,
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: gsPdfPrimaryDark,
      ),
    ),
  );
}

pw.Widget _calibrationFactorBar(CalibrationJob job, {required bool found}) {
  final points = job.filledPoints;
  if (points.isEmpty) return pw.SizedBox();
  final unit = _flowUnitLabel(job);
  final factors = job.meterFactors(found: found);
  final mean = meanOrNull(factors);
  final kValue = (found
          ? job.meterKFactorFound
          : (job.meterKFactorLeft.trim().isNotEmpty
              ? job.meterKFactorLeft
              : job.meterKFactorFound))
      .trim();
  final showK = kValue.isNotEmpty;
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
    child: pw.Table(
      border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const pw.IntrinsicColumnWidth(),
        for (var i = 0; i < points.length + 1 + (showK ? 1 : 0); i++)
          i + 1: const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: gsPdfPrimaryGold),
          children: [
            _factorBarTitleCell('Fator de Calibração'),
            for (final point in points)
              gsTableCell(_flowWithUnit(point, unit), header: true),
            gsTableCell('Fator de Cal. Médio', header: true),
            if (showK) gsTableCell('Fator k', header: true),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(
              color: gsPdfPrimaryGold,
              child: pw.SizedBox(height: 18),
            ),
            for (final factor in factors)
              gsTableCell(_fmt(factor, digits: job.mfDigits)),
            gsTableCell(_fmt(mean, digits: job.mfDigits)),
            if (showK) gsTableCell(kValue),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _runsTable(CalibrationJob job, {required bool found}) {
  final flowUnit = _flowUnitLabel(job);
  final volumeUnit = _volumeUnitLabel(job);
  final rows = <pw.TableRow>[
    ...gsTableHeader([
      GsColHead(gsVolumetricFlowColumnTitle, unit: flowUnit),
      GsColHead('Display Master Totalizado', unit: volumeUnit),
      GsColHead('Display Teste Totalizado', unit: volumeUnit),
      const GsColHead('Erro de indicação', unit: '(%)'),
      const GsColHead('Desvio Médio', unit: '(%)'),
      const GsColHead('Fator de Correção', unit: 'Fc'),
      const GsColHead('Repetibilidade', unit: '(%)'),
      const GsColHead('Incerteza de Medição', unit: '(U)'),
      const GsColHead('Fator de Abrangência', unit: '(K)'),
      const GsColHead('Grau efetivo de liberdade', unit: 'Veff'),
    ]),
  ];
  var alt = false;
  for (final point in job.filledPoints) {
    final runs = _runs(point, found: found);
    if (runs.isEmpty) continue;
    final result = _result(point, job, found: found);
    final color = alt ? gsPdfRow : PdfColors.white;
    for (final run in runs) {
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: color),
          children: [
            gsTableCell(_flow(point)),
            gsTableCell(_fmt(run.standardVolume)),
            gsTableCell(_fmt(run.objectVolume)),
            gsTableCell(_pct(run.errorPercentFor(inverted: job.invertedVolumetric))),
            gsTableCell(_pct(result?.meanError)),
            gsTableCell(_fmt(run.factorFor(inverted: job.invertedVolumetric), digits: job.mfDigits)),
            gsTableCell(_pct(result?.repeatability)),
            gsTableCell(_dash(job.resultULabel(point, found: found))),
            gsTableCell(_dash(job.resultKLabel(point, found: found))),
            gsTableCell(_dash(job.resultVeffLabel(point, found: found))),
          ],
        ),
      );
    }
    alt = !alt;
  }
  return pw.Table(
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.4),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: const {
      0: pw.FlexColumnWidth(1.25),
      1: pw.FlexColumnWidth(1.05),
      2: pw.FlexColumnWidth(1.1),
      3: pw.FlexColumnWidth(0.9),
      4: pw.FlexColumnWidth(0.85),
      5: pw.FlexColumnWidth(0.85),
      6: pw.FlexColumnWidth(0.9),
      7: pw.FlexColumnWidth(0.95),
      8: pw.FlexColumnWidth(0.85),
      9: pw.FlexColumnWidth(0.95),
    },
    children: rows,
  );
}

class _TempSummaryRow {
  const _TempSummaryRow({
    required this.pointLabel,
    required this.meanStandard,
    required this.meanInstrument,
    required this.meanError,
    this.meanConferenceError,
    this.oldFactor,
    this.newValue,
    required this.cycleCount,
    this.conferenceCount = 0,
  });

  final String pointLabel;
  final double? meanStandard;
  final double? meanInstrument;
  final double? meanError;
  final double? meanConferenceError;
  final double? oldFactor;
  final double? newValue;
  final int cycleCount;
  final int conferenceCount;
}

List<_TempSummaryRow> _temperatureSummaryRows(CalibrationJob job) {
  // GenericPoint = ciclo; GenericCycle = ponto (temperatura).
  // Média do resultado: ciclos de conferência se houver; senão todos.
  final ciclos = job.temperatureResultCycles;
  var maxPontos = 0;
  for (final ciclo in ciclos) {
    final n = ciclo.cycles.where((c) => c.isFilled).length;
    if (n > maxPontos) maxPontos = n;
  }

  final rows = <_TempSummaryRow>[];
  for (var ponto = 0; ponto < maxPontos; ponto++) {
    final standards = <double>[];
    final instruments = <double>[];
    final errors = <double>[];
    var cycleCount = 0;
    double? oldFactor;
    double? newValue;

    for (final ciclo in ciclos) {
      if (ponto < ciclo.cycles.length && ciclo.cycles[ponto].isFilled) {
        final reading = ciclo.cycles[ponto];
        if (reading.standard != null) standards.add(reading.standard!);
        if (reading.instrument != null) instruments.add(reading.instrument!);
        if (reading.error != null) errors.add(reading.error!);
        cycleCount++;
      }
      oldFactor ??= ciclo.oldFactor;
      newValue ??= ciclo.newValue;
    }

    if (standards.isEmpty && instruments.isEmpty) continue;

    rows.add(
      _TempSummaryRow(
        pointLabel: '${ponto + 1}',
        meanStandard: meanOrNull(standards),
        meanInstrument: meanOrNull(instruments),
        meanError: meanOrNull(errors),
        meanConferenceError: null,
        oldFactor: oldFactor,
        newValue: newValue,
        cycleCount: cycleCount,
        conferenceCount: 0,
      ),
    );
  }
  return rows;
}

/// Erro coerente com as médias exibidas (2 casas): Instrumento − Padrão.
double? _tempDisplayedError(double? meanStandard, double? meanInstrument) {
  if (meanStandard == null || meanInstrument == null) return null;
  final std = double.parse(meanStandard.toStringAsFixed(2));
  final inst = double.parse(meanInstrument.toStringAsFixed(2));
  return inst - std;
}

pw.Widget _genericTable(CalibrationJob job) {
  final unit = _genericUnit(job);
  final isTemp = job.kind == CalibrationKind.temperature ||
      job.kind == CalibrationKind.temperatureMesh;
  final isDensity = job.kind == CalibrationKind.density;
  final isConductivity = job.isConductivity;
  final hasTempInDensity = isDensity &&
      job.filledGenericPoints.any((p) => p.temperatureValues.isNotEmpty);
  final showFactors = job.filledGenericPoints.any(
    (point) => point.oldFactor != null || point.newValue != null,
  );
  final hasConferences = job.filledGenericPoints.any(
    (point) => point.conferences.any((c) => c.isFilled),
  );

  if (isTemp) {
    final rows = _temperatureSummaryRows(job);
  return pw.Table(
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      ...gsTableHeader([
        const GsColHead('Ponto'),
          const GsColHead('Sistema Padrão (Temperatura)', unit: '°C'),
          const GsColHead('Instrumento (Temperatura)', unit: '°C'),
          const GsColHead('Erro médio', unit: '°C'),
        if (showFactors) const GsColHead('Fator antigo'),
        if (showFactors) const GsColHead('Valor novo'),
          const GsColHead('Ciclos'),
      ]),
        for (final row in rows)
        pw.TableRow(
          children: [
              gsTableCell(row.pointLabel),
              gsTableCell(_fmt(row.meanStandard, digits: 2)),
              gsTableCell(_fmt(row.meanInstrument, digits: 2)),
            gsTableCell(
                _fmt(
                  _tempDisplayedError(row.meanStandard, row.meanInstrument) ??
                      row.meanError,
                  digits: 2,
                ),
              ),
              if (showFactors) gsTableCell(_fmtFactor(row.oldFactor)),
              if (showFactors) gsTableCell(_fmtFactor(row.newValue)),
              gsTableCell('${row.cycleCount}'),
            ],
          ),
      ],
    );
  }

  if (isConductivity) {
    final uDisplay = _expandedUncertaintyDisplay(job);
    return pw.Table(
      border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        ...gsTableHeader([
          const GsColHead('Ponto'),
          GsColHead('Valor de referência', unit: unit),
          GsColHead('Indicação', unit: unit),
          GsColHead('Erro', unit: unit),
          GsColHead('Incerteza expandida', unit: '± $unit'),
          if (showFactors) const GsColHead('Fator antigo'),
          if (showFactors) const GsColHead('Valor novo'),
        ]),
        for (var i = 0; i < job.filledGenericPoints.length; i++) ...[
          () {
            final point = job.filledGenericPoints[i];
            final pLabel = point.label.trim().isNotEmpty
                ? point.label.trim()
                : '${i + 1}';
            return pw.TableRow(
              children: [
                gsTableCell(pLabel),
                gsTableCell(_fmt(point.meanStandard, digits: 2)),
                gsTableCell(_fmt(point.meanInstrument, digits: 2)),
                gsTableCell(_fmt(point.meanError, digits: 3)),
                gsTableCell(uDisplay),
                if (showFactors) gsTableCell(_fmtFactor(point.oldFactor)),
                if (showFactors) gsTableCell(_fmtFactor(point.newValue)),
              ],
            );
          }(),
        ],
      ],
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.45),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      ...gsTableHeader([
        const GsColHead('Ponto'),
        if (hasTempInDensity) const GsColHead('Temp. Padrão', unit: '°C'),
        GsColHead(
          isTemp
              ? 'Temp. Padrão'
              : (isDensity ? 'Padrão (Densidade)' : 'Padrão (Ref.)'),
          unit: unit,
        ),
        GsColHead(
          isDensity ? 'Indicação (Densidade)' : 'Indicação Média',
          unit: unit,
        ),
        GsColHead(hasConferences ? 'Erro médio (Verif.)' : 'Erro médio', unit: unit),
        if (hasConferences) GsColHead('Erro médio (Conf.)', unit: unit),
        if (showFactors) const GsColHead('Fator antigo'),
        if (showFactors) const GsColHead('Valor novo'),
        const GsColHead('Ciclos'),
      ]),
      for (var i = 0; i < job.filledGenericPoints.length; i++) ...[
        () {
          final point = job.filledGenericPoints[i];
          final pLabel = point.label.trim().isNotEmpty
              ? point.label.trim()
              : '${i + 1}º Ponto';
          return pw.TableRow(
            children: [
              gsTableCell(pLabel),
              if (hasTempInDensity)
                gsTableCell(_fmt(point.meanTemperature, digits: 2)),
              gsTableCell(_fmt(point.meanStandard, digits: 2)),
              gsTableCell(_fmt(point.meanInstrument, digits: 2)),
              gsTableCell(_fmt(point.meanError, digits: 3)),
              if (hasConferences)
                gsTableCell(_fmt(point.meanConferenceError, digits: 3)),
              if (showFactors) gsTableCell(_fmtFactor(point.oldFactor)),
              if (showFactors) gsTableCell(_fmtFactor(point.newValue)),
              gsTableCell(
                '${point.cycles.where((cycle) => cycle.isFilled).length}'
                '${point.conferences.any((c) => c.isFilled) ? ' + ${point.conferences.where((c) => c.isFilled).length} conf.' : ''}',
              ),
            ],
          );
        }(),
      ],
    ],
  );
}

pw.Widget _genericRunsTable(CalibrationJob job) {
  final unit = _genericUnit(job);
  final isTemp = job.kind == CalibrationKind.temperature ||
      job.kind == CalibrationKind.temperatureMesh;
  final isDensity = job.kind == CalibrationKind.density;
  final isConductivity = job.isConductivity;
  final standardColTitle = isTemp
      ? 'Sistema Padrão (Temperatura)'
      : (isDensity
          ? 'Sistema Padrão (Densidade)'
          : (isConductivity
              ? 'Valor de referência'
              : 'Sistema Padrão'));
  final instColTitle = isTemp
      ? 'Instrumento (Temperatura)'
      : (isDensity
          ? 'Instrumento (Densidade)'
          : (isConductivity ? 'Indicação' : 'Instrumento'));

  // Incerteza (U) e Fator k
  String rawU = job.measurementUncertainty.trim();
  if (rawU.isEmpty) {
    for (final s in job.standards) {
      if (s.uncertainty.trim().isNotEmpty) {
        rawU = s.uncertainty.trim();
        break;
      }
    }
  }
  if (rawU.isEmpty) rawU = '0,50';

  String uUnit = '(%)';
  if (rawU.contains('%')) {
    uUnit = '(%)';
  } else if (rawU.contains('°') || isTemp) {
    uUnit = '°C';
  } else if (isDensity || rawU.toLowerCase().contains('kg')) {
    uUnit = unit;
  }
  final cleanU = rawU.replaceAll(RegExp(r'[^0-9,\.\-]'), '').trim();
  final uDisplay = cleanU.isNotEmpty ? cleanU : rawU;

  String kDisplay = job.coverageFactor.trim();
  if (kDisplay.isEmpty && job.coverageKLabel.isNotEmpty) {
    kDisplay = job.coverageKLabel;
  }
  if (kDisplay.isEmpty) {
    for (final s in job.standards) {
      if (s.coverageK.trim().isNotEmpty) {
        kDisplay = s.coverageK.trim();
        break;
      }
    }
  }
  if (kDisplay.isEmpty) kDisplay = '2,00';

  var maxCycles = 0;
  for (final p in job.filledGenericPoints) {
    if (p.cycles.length > maxCycles) maxCycles = p.cycles.length;
  }
  var maxConferences = 0;
  for (final p in job.filledGenericPoints) {
    if (p.conferences.length > maxConferences) {
      maxConferences = p.conferences.length;
    }
  }

  final widgets = <pw.Widget>[];

  if (isTemp) {
    // Temperatura: GenericPoint = ciclo; cada GenericCycle = ponto (temperatura).
    // Todos os ciclos aparecem nas medições; a média do resultado (resumo) usa
    // só conferência quando marcada — sem rótulo Verificação/Conferência aqui.
    for (var ci = 0; ci < job.filledGenericPoints.length; ci++) {
      final ciclo = job.filledGenericPoints[ci];
      final filledPontos = [
        for (var pi = 0; pi < ciclo.cycles.length; pi++)
          if (ciclo.cycles[pi].isFilled) (pi, ciclo.cycles[pi]),
      ];
      if (filledPontos.isEmpty) continue;

      if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 8));
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            '${ci + 1}º Ciclo de Medição',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: gsPdfNavy,
            ),
          ),
        ),
      );
      widgets.add(
        pw.Table(
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.4),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: const {
            0: pw.FlexColumnWidth(0.85),
            1: pw.FlexColumnWidth(1.15),
            2: pw.FlexColumnWidth(1.15),
            3: pw.FlexColumnWidth(0.8),
            4: pw.FlexColumnWidth(1.05),
            5: pw.FlexColumnWidth(0.9),
    },
    children: [
      ...gsTableHeader([
        const GsColHead('Ponto'),
              GsColHead(standardColTitle, unit: unit),
              GsColHead(instColTitle, unit: unit),
        GsColHead('Erro', unit: unit),
              GsColHead('Incerteza de Medição (U)', unit: uUnit),
              const GsColHead('Fator de Abrangência', unit: 'k'),
      ]),
            for (final entry in filledPontos)
            pw.TableRow(
              children: [
                  gsTableCell('${entry.$1 + 1}'),
                  gsTableCell(_fmt(entry.$2.standard, digits: 2)),
                  gsTableCell(_fmt(entry.$2.instrument, digits: 2)),
                  gsTableCell(_fmt(entry.$2.error, digits: 2)),
                  gsTableCell(uDisplay),
                  gsTableCell(kDisplay),
              ],
            ),
    ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  final filledPoints = job.filledGenericPoints;
  final showPointCol = isDensity && filledPoints.length > 1;
  for (var c = 0; c < maxCycles; c++) {
    final rows = <(GenericPoint, GenericCycle)>[];
    for (final p in filledPoints) {
      if (c < p.cycles.length && p.cycles[c].isFilled) {
        rows.add((p, p.cycles[c]));
      }
    }
    if (rows.isEmpty) continue;

    if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 8));

    if (maxCycles > 1 || maxConferences > 0) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            '${c + 1}º Ciclo de Medição',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: gsPdfNavy,
            ),
          ),
        ),
      );
    }

    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(color: gsPdfLine, width: 0.4),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        columnWidths: isDensity
            ? {
                for (final (i, w) in [
                  if (showPointCol) 0.6,
                  0.95,
                  1.15,
                  1.15,
                  0.8,
                  1.05,
                  0.9,
                ].indexed)
                  i: pw.FlexColumnWidth(w),
              }
            : const {
                0: pw.FlexColumnWidth(1.2),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(0.85),
                3: pw.FlexColumnWidth(1.1),
                4: pw.FlexColumnWidth(1.0),
              },
        children: [
          ...gsTableHeader([
            if (showPointCol) const GsColHead('Ponto'),
            if (isDensity) const GsColHead('Temp. Padrão', unit: '°C'),
            GsColHead(standardColTitle, unit: unit),
            GsColHead(instColTitle, unit: unit),
            GsColHead('Erro', unit: unit),
            GsColHead('Incerteza de Medição (U)', unit: uUnit),
            const GsColHead('Fator de Abrangência', unit: 'k'),
          ]),
          for (final entry in rows)
            pw.TableRow(
              children: [
                if (showPointCol)
                  gsTableCell('${filledPoints.indexOf(entry.$1) + 1}º'),
                if (isDensity)
                  gsTableCell(_fmt(entry.$2.temperature, digits: 2)),
                gsTableCell(_fmt(entry.$2.standard, digits: 2)),
                gsTableCell(_fmt(entry.$2.instrument, digits: 2)),
                gsTableCell(_fmt(entry.$2.error, digits: 2)),
                gsTableCell(uDisplay),
                gsTableCell(kDisplay),
              ],
            ),
        ],
      ),
    );
  }

  for (var c = 0; c < maxConferences; c++) {
    final rows = <(GenericPoint, GenericCycle)>[];
    for (final p in job.filledGenericPoints) {
      if (c < p.conferences.length && p.conferences[c].isFilled) {
        rows.add((p, p.conferences[c]));
      }
    }
    if (rows.isEmpty) continue;

    if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 8));

    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(
          maxConferences > 1
              ? '${c + 1}º Ciclo de Conferência (Após Ajuste)'
              : 'Conferência (Após Ajuste)',
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfNavy,
          ),
        ),
      ),
    );

    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(color: gsPdfLine, width: 0.4),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        columnWidths: isDensity
            ? const {
                0: pw.FlexColumnWidth(0.95),
                1: pw.FlexColumnWidth(1.15),
                2: pw.FlexColumnWidth(1.15),
                3: pw.FlexColumnWidth(0.8),
                4: pw.FlexColumnWidth(1.05),
                5: pw.FlexColumnWidth(0.9),
              }
            : isTemp
                ? const {
                    0: pw.FlexColumnWidth(0.85),
                    1: pw.FlexColumnWidth(1.15),
                    2: pw.FlexColumnWidth(1.15),
                    3: pw.FlexColumnWidth(0.8),
                    4: pw.FlexColumnWidth(1.05),
                    5: pw.FlexColumnWidth(0.9),
                  }
                : const {
                    0: pw.FlexColumnWidth(1.2),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(0.85),
                    3: pw.FlexColumnWidth(1.1),
                    4: pw.FlexColumnWidth(1.0),
                  },
        children: [
          ...gsTableHeader([
            if (isTemp) const GsColHead('Ponto'),
            if (isDensity) const GsColHead('Temp. Padrão', unit: '°C'),
            GsColHead(standardColTitle, unit: unit),
            GsColHead(instColTitle, unit: unit),
            GsColHead('Erro', unit: unit),
            GsColHead('Incerteza de Medição (U)', unit: uUnit),
            const GsColHead('Fator de Abrangência', unit: 'k'),
          ]),
          for (var ri = 0; ri < rows.length; ri++)
            pw.TableRow(
              children: [
                if (isTemp)
                  gsTableCell(
                    rows[ri].$1.label.trim().isNotEmpty
                        ? rows[ri].$1.label.trim()
                        : '${job.filledGenericPoints.indexOf(rows[ri].$1) + 1}',
                  ),
                if (isDensity)
                  gsTableCell(_fmt(rows[ri].$2.temperature, digits: 2)),
                gsTableCell(_fmt(rows[ri].$2.standard, digits: 2)),
                gsTableCell(_fmt(rows[ri].$2.instrument, digits: 2)),
                gsTableCell(_fmt(rows[ri].$2.error, digits: 2)),
                gsTableCell(uDisplay),
                gsTableCell(kDisplay),
              ],
            ),
        ],
      ),
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: widgets,
  );
}

List<String> _telemetryNotes(CalibrationJob job) {
  final custom = job.notes.trim();
  if (custom.isNotEmpty) return [custom];
  final model = job.model.trim();
  final tag = job.equipmentTag.trim();
  if (model.isNotEmpty && tag.isNotEmpty) {
    return [
      'O equipamento $model do $tag encontra-se aferido e calibrado, operando em perfeitas condições, sem demais observações.',
    ];
  }
  if (tag.isNotEmpty) {
    return [
      'O equipamento do $tag encontra-se aferido e calibrado, operando em perfeitas condições, sem demais observações.',
    ];
  }
  return [
    'O equipamento encontra-se aferido e calibrado, operando em perfeitas condições, sem demais observações.',
  ];
}

pw.Widget _notes(CalibrationJob job) {
  final items = <String>[];
  if (job.isTelemetry) {
    items.addAll(_telemetryNotes(job));
  } else {
    final custom = job.notes.trim();
    if (custom.isNotEmpty) {
      items.add(custom);
    }
  }

  // Se reprovado / fora do critério aceitável, acrescenta NÃO CONFORME nas observações
  if (job.passed == false) {
    final failedFlows = <String>[];
    if (job.isVolumetric) {
      for (final point in job.filledPoints) {
        if (point.isApproved(job.limits, inverted: job.invertedVolumetric)) {
          continue;
        }
        final flow = point.flowRate == null
            ? 'vazão'
            : '${formatCalibNumber(point.flowRate, digits: 0)} ${point.flowUnit}';
        failedFlows.add(flow);
      }
      if (!job.linearityOk) {
        failedFlows.add('linearidade');
      }
    }
    final detail = failedFlows.isEmpty
        ? 'Um ou mais pontos apresentaram erro fora do limite máximo admissível.'
        : 'Fora do limite em: ${failedFlows.join(', ')}.';
    items.add('NÃO CONFORME: $detail');
  }

    if (items.isEmpty) {
      return pw.Text(
        '—',
        style: const pw.TextStyle(fontSize: 8, color: gsPdfMuted),
      );
    }
    return gsBulletList(items);
}

pw.Widget _signatory(
  CalibrationJob job,
  String issued, {
  bool withSignature = false,
  DateTime? signedAt,
}) {
  final name = job.technicianName.trim();
  final role = name.toLowerCase().contains('cleber')
      ? 'Diretor / $defaultTechnicianCargo'
      : staffCargoForName(name);
  final digital = personHasDigitalCertificate(name: name);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            gsKv('Data da emissão', issued),
          ],
        ),
      ),
      pw.Center(
        child: _signatureBlock(
          name: _dash(name),
          role: role,
          withSignature: withSignature,
          digital: digital,
          signedAt: signedAt,
        ),
      ),
    ],
  );
}

pw.Widget _errorChart(CalibrationJob job) {
  final points = _chartPoints(job);
  final xs = [for (final point in points) point.$1];
  final ys = [for (final point in points) point.$2];
  final xTicks = _axisTicks(xs.reduce(math.min), xs.reduce(math.max));
  final yTicks = _axisTicks(ys.reduce(math.min), ys.reduce(math.max));
  return _chartBox(
    left: 'Erro (%)',
    bottom: 'Vazão (L/min)',
    xTicks: xTicks,
    yTicks: yTicks,
    series: [
      (
        'Erro médio',
        [for (final point in points) pw.PointChartValue(point.$1, point.$2)],
        gsPdfNavy,
        true,
      ),
    ],
  );
}

pw.Widget _genericChart(CalibrationJob job) {
  final points = _genericChartPoints(job);
  final xs = [for (var i = 0; i < points.length; i++) i.toDouble()];
  final ys = [for (final point in points) point.$2];
  final xTicks = points.length > 1
      ? [for (var i = 0; i < points.length; i++) i.toDouble()]
      : const [-1.0, 0.0, 1.0];
  final yTicks = _axisTicks(ys.reduce(math.min), ys.reduce(math.max));
  return _chartBox(
    left: 'Erro',
    bottom: 'Ponto',
    xTicks: xTicks,
    yTicks: yTicks,
    xFormat: (value) {
      final index = value.round();
      if ((value - index).abs() > 0.01 || index < 0 || index >= points.length) {
        return '';
      }
      return points[index].$1;
    },
    series: [
      (
        'Erro médio',
        [
          for (var i = 0; i < points.length; i++)
            pw.PointChartValue(xs[i], points[i].$2),
        ],
        gsPdfNavy,
        true,
      ),
    ],
  );
}

pw.Widget _chartBox({
  required String left,
  required String bottom,
  required List<double> xTicks,
  required List<double> yTicks,
  required List<(String, List<pw.PointChartValue>, PdfColor, bool)> series,
  String Function(num value)? xFormat,
}) {
  return pw.Container(
    width: double.infinity,
    height: 168,
    padding: const pw.EdgeInsets.fromLTRB(6, 8, 8, 4),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: gsPdfLine, width: 0.6),
      color: PdfColors.white,
    ),
    child: pw.Chart(
      left: pw.Padding(
        padding: const pw.EdgeInsets.only(right: 4),
        child: pw.Text(left, style: const pw.TextStyle(fontSize: 7, color: gsPdfMuted)),
      ),
      bottom: pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(bottom, style: const pw.TextStyle(fontSize: 7, color: gsPdfMuted)),
      ),
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis(
          xTicks,
          divisions: true,
          ticks: true,
          format: xFormat ?? (value) => formatCalibNumber(value.toDouble(), digits: 1),
        ),
        yAxis: pw.FixedAxis(
          yTicks,
          divisions: true,
          ticks: true,
          format: (value) => formatCalibNumber(value.toDouble(), digits: 2),
        ),
      ),
      datasets: [
        for (final item in series)
          pw.LineDataSet(
            legend: item.$1,
            data: item.$2,
            color: item.$3,
            lineWidth: item.$4 ? 1.3 : 0.7,
            drawPoints: item.$4,
            pointSize: item.$4 ? 4 : 0,
            pointColor: gsPdfGold,
            drawLine: true,
          ),
      ],
    ),
  );
}

bool _hasClient(CalibrationJob job) =>
    gsCertPrint(job.clientName).isNotEmpty ||
    job.serviceRequester.trim().isNotEmpty ||
    job.clientCnpj.trim().isNotEmpty ||
    job.clientAddress.trim().isNotEmpty ||
    job.site.trim().isNotEmpty;

bool _hasInstrument(CalibrationJob job) =>
    job.equipmentType.trim().isNotEmpty ||
    job.manufacturer.trim().isNotEmpty ||
    job.model.trim().isNotEmpty ||
    job.serialNumber.trim().isNotEmpty ||
    job.workingPrinciple.trim().isNotEmpty ||
    job.installLocation.trim().isNotEmpty ||
    job.equipmentTag.trim().isNotEmpty ||
    job.concentrator.trim().isNotEmpty ||
    job.deviceId.trim().isNotEmpty;

bool _hasConditions(CalibrationJob job) =>
    job.ambientTemp.trim().isNotEmpty ||
    job.humidity.trim().isNotEmpty ||
    job.pressure.trim().isNotEmpty ||
    job.fluid.trim().isNotEmpty ||
    (job.fluid.trim().isNotEmpty &&
        (job.fluidDensityMin.trim().isNotEmpty ||
    job.fluidDensityMax.trim().isNotEmpty ||
    job.fluidViscosityMin.trim().isNotEmpty ||
            job.fluidViscosityMax.trim().isNotEmpty)) ||
    job.productDensity.trim().isNotEmpty ||
    job.productTemperature.trim().isNotEmpty ||
    job.tankType.trim().isNotEmpty;

bool _hasLeftValues(CalibrationJob job) =>
    job.filledPoints.any((point) => point.leftConference != null);

String _methodText(CalibrationJob job) {
  final custom = job.procedure.trim();
  if (custom.isNotEmpty &&
      custom.toLowerCase() != 'comparação direta' &&
      custom.toLowerCase() != 'comparacao direta') {
    return custom;
  }
  if (job.isVolumetric) return _pq30005;
  if (job.kind == CalibrationKind.temperature ||
      job.kind == CalibrationKind.temperatureMesh) {
    return _tempProcedureText;
  }
  if (job.isTelemetry) return telemetryProcedureDefault;
  return custom.isEmpty ? 'Comparação direta com o padrão nas instalações do cliente.' : custom;
}

String _flow(FlowPoint point) {
  final value = point.flowRate;
  if (value == null) return '—';
  final digits = (value - value.roundToDouble()).abs() < 1e-9 ? 0 : 1;
  return formatCalibNumber(value, digits: digits);
}

String _flowWithUnit(FlowPoint point, String unit) {
  final flow = _flow(point);
  if (flow == '—') return '—';
  return '$flow $unit';
}

String _flowUnitLabel(CalibrationJob job) {
  for (final point in job.filledPoints) {
    final unit = point.flowUnit.trim();
    if (unit.isNotEmpty) return unit;
  }
  return 'L/min';
}

String _genericUnit(CalibrationJob job) => resolvedMeasurementUnit(job);

String _expandedUncertaintyDisplay(CalibrationJob job) {
  String rawU = job.measurementUncertainty.trim();
  if (rawU.isEmpty) {
    for (final s in job.standards) {
      if (s.uncertainty.trim().isNotEmpty) {
        rawU = s.uncertainty.trim();
        break;
      }
    }
  }
  if (rawU.isEmpty) return '—';
  final clean = rawU.replaceAll(RegExp(r'^±\s*'), '').trim();
  return clean.isEmpty ? '—' : clean;
}

String _volumeUnitLabel(CalibrationJob job) {
  final unit = job.volumeUnit.trim();
  return unit.isEmpty ? 'L' : unit;
}

String _dash(String value) => value.trim().isEmpty ? '—' : value.trim();

String _unit(String raw, String unit) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.toLowerCase().contains(unit.toLowerCase().replaceAll('%ur', 'ur'))) {
    return value;
  }
  return '$value $unit';
}

String _fmt(double? value, {int digits = 2, String suffix = ''}) {
  if (value == null) return '—';
  return '${formatCalibNumber(value, digits: digits)}$suffix';
}

String _fmtFactor(double? value) {
  if (value == null) return '—';
  var str = value.toStringAsFixed(6);
  if (str.contains('.')) {
    str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return str.replaceAll('.', ',');
}

String _pct(double? value) {
  if (value == null) return '—';
  return '${value.toStringAsFixed(2).replaceAll('.', ',')}%';
}

RunSetResult? _result(FlowPoint point, CalibrationJob job, {required bool found}) {
  if (found) {
    return point.verificationResult(
      job.limits,
      inverted: job.invertedVolumetric,
    );
  }
  final left = point.leftConference;
  final leftResult = left == null
      ? null
      : point.conferenceResult(
          left,
          job.limits,
          inverted: job.invertedVolumetric,
        );
  return leftResult ??
      point.verificationResult(job.limits, inverted: job.invertedVolumetric);
}

List<VolumeRun> _runs(FlowPoint point, {required bool found}) {
  if (found) {
    return [for (final run in point.verification) if (run.isFilled) run];
  }
  final last = point.leftConference;
  if (last != null) {
    final filled = [for (final run in last.runs) if (run.isFilled) run];
    if (filled.isNotEmpty) return filled;
  }
  return const [];
}

double? _meanVolume(
  FlowPoint point, {
  required bool found,
  required bool standard,
}) {
  final runs = _runs(point, found: found);
  final values = [
    for (final run in runs)
      standard ? run.standardVolume! : run.objectVolume!,
  ];
  return meanOrNull(values);
}

List<(double, double)> _chartPoints(CalibrationJob job) {
  final points = <(double, double)>[];
  for (final point in job.filledPoints) {
    final error = _result(point, job, found: true)?.meanError;
    if (error == null || point.flowRate == null) continue;
    points.add((point.flowRate!, error));
  }
  return points;
}

List<(String, double)> _genericChartPoints(CalibrationJob job) {
  final isTemp = job.kind == CalibrationKind.temperature ||
      job.kind == CalibrationKind.temperatureMesh;
  if (isTemp) {
    return [
      for (final row in _temperatureSummaryRows(job))
        if ((_tempDisplayedError(row.meanStandard, row.meanInstrument) ??
                row.meanError) !=
            null)
          (
            row.pointLabel,
            _tempDisplayedError(row.meanStandard, row.meanInstrument) ??
                row.meanError!,
          ),
    ];
  }
  return [
    for (var i = 0; i < job.filledGenericPoints.length; i++)
      if (job.filledGenericPoints[i].meanError != null)
        (
          job.filledGenericPoints[i].label.trim().isEmpty
              ? '${i + 1}'
              : job.filledGenericPoints[i].label.trim(),
          job.filledGenericPoints[i].meanError!,
        ),
  ];
}

List<double> _axisTicks(double min, double max, {int count = 5}) {
  if (!min.isFinite || !max.isFinite) return const [-1, 0, 1];
  if ((max - min).abs() < 1e-9) {
    final pad = min.abs() < 1e-9 ? 1.0 : min.abs() * 0.25;
    min -= pad;
    max += pad;
  }
  final span = max - min;
  min -= span * 0.08;
  max += span * 0.08;
  final step = (max - min) / (count - 1);
  final ticks = <double>[];
  for (var i = 0; i < count; i++) {
    final value = min + step * i;
    if (ticks.isEmpty || value > ticks.last) ticks.add(value);
  }
  if (ticks.length == 1) ticks.add(ticks.first + 1);
  return ticks;
}
