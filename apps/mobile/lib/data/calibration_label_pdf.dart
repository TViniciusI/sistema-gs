import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/gs_brand_pdf.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Tamanho físico do adesivo (mm). Padrão de campo: 40 × 60.
class CalibrationLabelSize {
  const CalibrationLabelSize({
    required this.widthMm,
    required this.heightMm,
    this.label = '',
  });

  final double widthMm;
  final double heightMm;
  final String label;

  static const standard = CalibrationLabelSize(
    widthMm: 40,
    heightMm: 60,
    label: '40 × 60 mm',
  );

  static const presets = <CalibrationLabelSize>[
    standard,
    CalibrationLabelSize(widthMm: 50, heightMm: 70, label: '50 × 70 mm'),
    CalibrationLabelSize(widthMm: 50, heightMm: 80, label: '50 × 80 mm'),
    CalibrationLabelSize(widthMm: 60, heightMm: 90, label: '60 × 90 mm'),
  ];

  String get displayLabel {
    if (label.trim().isNotEmpty) return label.trim();
    return '${_fmt(widthMm)} × ${_fmt(heightMm)} mm';
  }

  PdfPageFormat get pageFormat => PdfPageFormat(
        widthMm * PdfPageFormat.mm,
        heightMm * PdfPageFormat.mm,
        marginAll: 0,
      );

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

/// Etiqueta física padrão 40 × 60 mm (adesivo de campo).
final calibrationLabelPageFormat = CalibrationLabelSize.standard.pageFormat;

const _labelBlack = PdfColor.fromInt(0xFF000000);
const _labelWhite = PdfColor.fromInt(0xFFFFFFFF);

const _labelPublicBase = 'https://gs-campo.netlify.app';

/// Título do tipo no adesivo (legado / testes).
String calibrationLabelPrincipleName(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
      return 'Calibração de vazão';
    case CalibrationKind.volumetricInverted:
      return 'Calibração de vazão (invertida)';
    case CalibrationKind.temperature:
      return 'Calibração de temperatura';
    case CalibrationKind.temperatureMesh:
      return 'Calibração de malha de temperatura';
    case CalibrationKind.density:
      return 'Calibração de densidade';
    case CalibrationKind.pressure:
      return 'Calibração de pressão';
    case CalibrationKind.conductivity:
      return 'Calibração de condutividade';
    case CalibrationKind.telemetry:
      return 'Calibração de telemetria';
  }
}

/// Título no layout novo (ex.: Certificado de Vazão).
String calibrationLabelCertificateKind(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      return 'Certificado de Vazão';
    case CalibrationKind.temperature:
      return 'Certificado de Temperatura';
    case CalibrationKind.temperatureMesh:
      return 'Certificado de Malha de Temperatura';
    case CalibrationKind.density:
      return 'Certificado de Densidade';
    case CalibrationKind.pressure:
      return 'Certificado de Pressão';
    case CalibrationKind.conductivity:
      return 'Certificado de Condutividade';
    case CalibrationKind.telemetry:
      return 'Certificado de Telemetria';
  }
}

/// Primeira linha do adesivo: mesmo tipo de serviço do certificado.
String calibrationLabelServiceType(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      return 'CALIBRAÇÃO VOLUMÉTRICA';
    case CalibrationKind.temperature:
      return 'CALIBRAÇÃO DE TEMPERATURA';
    case CalibrationKind.temperatureMesh:
      return 'CALIBRAÇÃO DE MALHA DE TEMPERATURA';
    case CalibrationKind.density:
      return 'CALIBRAÇÃO DE DENSIDADE';
    case CalibrationKind.pressure:
      return 'CALIBRAÇÃO DE PRESSÃO';
    case CalibrationKind.conductivity:
      return 'CALIBRAÇÃO DE CONDUTIVIDADE';
    case CalibrationKind.telemetry:
      return 'CALIBRAÇÃO DE TELEMETRIA';
  }
}

String calibrationLabelFileName(CalibrationJob job) {
  final raw = (job.number.trim().isNotEmpty ? job.number : job.id)
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  return 'Adesivo_$raw.pdf';
}

/// Link do QR: página pública com os dados do certificado (sem login).
/// A consulta exige número + id do certificado (ou id da OS).
String calibrationLabelQrUrl(CalibrationJob job) {
  final cert = _certNumber(job);
  final params = <String, String>{
    if (cert.isNotEmpty) 'n': cert,
    if (job.id.trim().isNotEmpty) 'id': job.id.trim(),
    if (job.osId.trim().isNotEmpty) 'os': job.osId.trim(),
  };
  return Uri.parse('$_labelPublicBase/c')
      .replace(queryParameters: params)
      .toString();
}

DateTime? parseCalibrationDateLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
  if (dmy != null) {
    return DateTime(
      int.parse(dmy.group(3)!),
      int.parse(dmy.group(2)!),
      int.parse(dmy.group(1)!),
    );
  }
  return DateTime.tryParse(value);
}

String formatCalibrationDateLabel(DateTime date) =>
    DateFormat('dd/MM/yyyy').format(date);

/// Próxima calibração padrão: +1 ano (prazo usual em campo).
String nextCalibrationDateLabel(String calibrationDate, {DateTime? fallback}) {
  final base = parseCalibrationDateLabel(calibrationDate) ?? fallback;
  if (base == null) return '';
  final next = DateTime(base.year + 1, base.month, base.day);
  return formatCalibrationDateLabel(next);
}

String _certNumber(CalibrationJob job) {
  final n = job.number.trim();
  return n.isNotEmpty ? n : job.id.trim();
}

String _serial(CalibrationJob job) => job.serialNumber.trim();

/// Data que sai no adesivo: a do item da OS (técnico) ou a do certificado.
String calibrationLabelDate(CalibrationJob job, {OsCalibrationSlot? slot}) {
  final own = slot?.labelDate.trim() ?? '';
  if (own.isNotEmpty) return own;
  return _calibrationDate(job);
}

String _calibrationDate(CalibrationJob job) {
  final raw = job.calibrationDate.trim();
  if (raw.isNotEmpty) {
    final parsed = parseCalibrationDateLabel(raw);
    if (parsed != null) return formatCalibrationDateLabel(parsed);
    return raw;
  }
  return formatCalibrationDateLabel(job.createdAt);
}

Future<pw.MemoryImage?> _labelLogoBw() async {
  try {
    final data = await rootBundle.load('assets/cert/logo_label_bw.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    try {
      final data = await rootBundle.load('assets/cert/logo_label.jpg');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final data = await rootBundle.load('assets/cert/logo_mark.png');
        return pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
  }
}

/// Título curto do tipo no adesivo combinado (vários produtos).
String calibrationLabelKindShort(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      return 'Vazão';
    case CalibrationKind.temperature:
      return 'Temp.';
    case CalibrationKind.temperatureMesh:
      return 'Malha';
    case CalibrationKind.density:
      return 'Dens.';
    case CalibrationKind.pressure:
      return 'Pressão';
    case CalibrationKind.conductivity:
      return 'Cond.';
    case CalibrationKind.telemetry:
      return 'Telem.';
  }
}

String calibrationLabelServiceTypeForJobs(List<CalibrationJob> jobs) {
  if (jobs.isEmpty) return 'CALIBRAÇÃO';
  final kinds = {for (final job in jobs) job.kind};
  if (kinds.length == 1) return calibrationLabelServiceType(kinds.first);
  return 'CALIBRAÇÃO';
}

/// Números de certificado na etiqueta (um por linha; com tipo se forem mistos).
String calibrationLabelCertificateValue(List<CalibrationJob> jobs) {
  if (jobs.isEmpty) return '';
  final kinds = {for (final job in jobs) job.kind};
  final multiKind = kinds.length > 1;
  return [
    for (final job in jobs)
      () {
        final number = _certNumber(job);
        if (number.isEmpty) return '';
        if (!multiKind) return number;
        return '${calibrationLabelKindShort(job.kind)} $number';
      }(),
  ].where((line) => line.isNotEmpty).join('\n');
}

/// Há 2+ certificados marcados do mesmo medidor/preset.
bool calibrationLabelsShareMeter(Iterable<CalibrationJob> jobs) {
  final byKey = <String, int>{};
  for (final job in jobs) {
    final key = calibrationMeterGroupKey(job);
    byKey[key] = (byKey[key] ?? 0) + 1;
    if ((byKey[key] ?? 0) >= 2) return true;
  }
  return false;
}

Future<Uint8List> buildCalibrationLabel(
  CalibrationJob job, {
  /// Outros certificados do mesmo medidor (preset/sistema) para a mesma etiqueta.
  /// Vazio = só este certificado.
  List<CalibrationJob> relatedCertificates = const [],
  /// @deprecated Use [relatedCertificates]. Mantido para chamadas antigas.
  List<CalibrationJob> relatedPool = const [],
  CalibrationLabelSize size = CalibrationLabelSize.standard,

  /// dd/MM/yyyy escolhida na impressão; vence a data do item e do certificado.
  String calibrationDateOverride = '',
}) async {
  await loadGsBrandPdf();
  await ClientStore.instance.load();
  OsCalibrationSlot? slot;
  if (job.osId.trim().isNotEmpty &&
      job.calibrationSlotId.trim().isNotEmpty) {
    final os = FieldStore.instance.byId(job.osId);
    for (final item in os?.calibrationSlots ?? const <OsCalibrationSlot>[]) {
      if (item.id == job.calibrationSlotId) {
        slot = item;
        break;
      }
    }
  }
  job = calibrationJobForCertificatePrint(job, slot: slot);
  if (slot != null && slot.certificateNumber.trim().isNotEmpty) {
    job = job.copyWith(number: slot.certificateNumber.trim());
  }

  var certJobs = <CalibrationJob>[
    if (relatedCertificates.isNotEmpty)
      ...relatedCertificates
    else if (relatedPool.isNotEmpty)
      ...relatedCalibrationJobsForMeter(job, relatedPool)
    else
      job,
  ];
  if (certJobs.isEmpty) certJobs = [job];
  // Normaliza números a partir do slot quando existir.
  certJobs = [
    for (final item in certJobs)
      () {
        OsCalibrationSlot? itemSlot;
        if (item.osId.trim().isNotEmpty &&
            item.calibrationSlotId.trim().isNotEmpty) {
          final os = FieldStore.instance.byId(item.osId);
          for (final s in os?.calibrationSlots ?? const <OsCalibrationSlot>[]) {
            if (s.id == item.calibrationSlotId) {
              itemSlot = s;
              break;
            }
          }
        }
        var prepared = calibrationJobForCertificatePrint(item, slot: itemSlot);
        if (itemSlot != null &&
            itemSlot.certificateNumber.trim().isNotEmpty) {
          prepared = prepared.copyWith(
            number: itemSlot.certificateNumber.trim(),
          );
        }
        return prepared;
      }(),
  ];
  // Ordena como no livro (vazão → temp → densidade…).
  certJobs = relatedCalibrationJobsForMeter(certJobs.first, certJobs);
  final primary = certJobs.first;

  final logo = await _labelLogoBw();
  final bold = gsPdfBold ?? pw.Font.helveticaBold();
  final regular = gsPdfRegular ?? pw.Font.helvetica();
  final cert = calibrationLabelCertificateValue(certJobs);
  final serial = _serial(primary).isNotEmpty ? _serial(primary) : _serial(job);
  final calibDate = calibrationDateOverride.trim().isNotEmpty
      ? calibrationDateOverride.trim()
      : calibrationLabelDate(job, slot: slot);
  final serviceType = calibrationLabelServiceTypeForJobs(certJobs);
  final qrUrl = calibrationLabelQrUrl(primary);
  final certLines = certJobs.length.clamp(1, 6);
  final certFlex = 2 + certLines;

  // Escala a partir da largura (base 40 mm).
  final s = (size.widthMm / 40.0).clamp(0.85, 1.8);
  final pad = 2.6 * s;
  final qrSide = 44.0 * s;
  final certValueSize =
      (certJobs.length <= 1 ? 10.5 : (certJobs.length <= 3 ? 8.2 : 7.0)) * s;

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: size.pageFormat,
      build: (context) {
        return pw.Container(
          color: _labelWhite,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                color: _labelBlack,
                padding: pw.EdgeInsets.all(pad),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.SizedBox(
                        height: qrSide,
                        child: logo != null
                            ? pw.Image(logo, fit: pw.BoxFit.contain)
                            : pw.Center(
                                child: pw.Text(
                                  'GS',
                                  style: pw.TextStyle(
                                    font: bold,
                                    fontSize: 18 * s,
                                    color: _labelWhite,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    pw.SizedBox(width: pad),
                    pw.Container(
                      width: qrSide,
                      height: qrSide,
                      padding: pw.EdgeInsets.all(1.6 * s),
                      color: _labelWhite,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrUrl,
                        color: _labelBlack,
                        backgroundColor: _labelWhite,
                        drawText: false,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.fromLTRB(pad, pad, pad, pad),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.FittedBox(
                            fit: pw.BoxFit.scaleDown,
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Text(
                              serviceType,
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 7.2 * s,
                                letterSpacing: 0.2 * s,
                                color: _labelBlack,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                      _divider(s),
                      pw.Expanded(
                        flex: certFlex,
                        child: _infoLine(
                          bold: bold,
                          regular: regular,
                          label: certJobs.length > 1
                              ? 'Nº dos certificados'
                              : 'Nº do certificado',
                          value: cert,
                          valueSize: certValueSize,
                          scale: s,
                          maxLines: certLines,
                        ),
                      ),
                      _divider(s),
                      pw.Expanded(
                        flex: 3,
                        child: _infoLine(
                          bold: bold,
                          regular: regular,
                          label: 'Nº de série',
                          value: serial,
                          valueSize: 9 * s,
                          scale: s,
                        ),
                      ),
                      _divider(s),
                      pw.Expanded(
                        flex: 3,
                        child: _infoLine(
                          bold: bold,
                          regular: regular,
                          label: 'Data da calibração',
                          value: calibDate,
                          valueSize: 9 * s,
                          scale: s,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  return doc.save();
}

pw.Widget _divider(double scale) {
  return pw.Container(
    height: 0.8 * scale,
    color: _labelBlack,
    margin: pw.EdgeInsets.symmetric(vertical: 0.6 * scale),
  );
}

pw.Widget _infoLine({
  required pw.Font bold,
  required pw.Font regular,
  required String label,
  required String value,
  required double valueSize,
  required double scale,
  int maxLines = 1,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.center,
    children: [
      pw.Text(
        label.toUpperCase(),
        style: pw.TextStyle(
          font: regular,
          fontSize: 5.2 * scale,
          letterSpacing: 0.3 * scale,
          color: _labelBlack,
        ),
      ),
      pw.SizedBox(height: 0.6 * scale),
      pw.Expanded(
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            value.isEmpty ? '—' : value,
            style: pw.TextStyle(
              font: bold,
              fontSize: valueSize,
              color: _labelBlack,
              lineSpacing: 1.05,
            ),
            maxLines: maxLines,
          ),
        ),
      ),
    ],
  );
}

