import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:gs_mobile/data/e_signature.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _gold = PdfColor.fromInt(0xFFC6A03A);
const _ink = PdfColor.fromInt(0xFF000000);
const _line = PdfColor.fromInt(0xFF000000);

class RdoPdfPhoto {
  const RdoPdfPhoto({required this.label, required this.bytes});

  final String label;
  final List<int> bytes;
}

pw.MemoryImage? _headerImage;
pw.MemoryImage? _footerImage;
pw.Font? _baseFont;
pw.Font? _boldFont;

String rdoFileName(String osNumber, [DateTime? date]) {
  return _rdoFileName(osNumber, date, signed: true);
}

String rdoUnsignedFileName(String osNumber, [DateTime? date]) {
  return _rdoFileName(osNumber, date, signed: false);
}

String _rdoFileName(String osNumber, DateTime? date, {required bool signed}) {
  final safe = osNumber.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  final suffix = signed ? '' : '_sem_assinatura';
  if (date == null) return 'RDO_OS_$safe$suffix.pdf';
  final day =
      '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year.toString().substring(2)}';
  return 'RDO_OS_${safe}_$day$suffix.pdf';
}

Future<void> _loadBrand() async {
  if (_headerImage != null &&
      _footerImage != null &&
      _baseFont != null &&
      _boldFont != null) {
    return;
  }
  final header = await rootBundle.load('assets/rdo/header.png');
  final footer = await rootBundle.load('assets/rdo/footer.png');
  final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final headerBytes = header.buffer.asUint8List(
    header.offsetInBytes,
    header.lengthInBytes,
  );
  final footerBytes = footer.buffer.asUint8List(
    footer.offsetInBytes,
    footer.lengthInBytes,
  );
  _headerImage = pw.MemoryImage(headerBytes);
  _footerImage = pw.MemoryImage(footerBytes);
  _baseFont = pw.Font.ttf(regular);
  _boldFont = pw.Font.ttf(bold);
}

Future<List<int>> buildRdoPdf({
  required String osNumber,
  required String technicianName,
  required RdoData rdo,
  required DateTime date,
  String? signerName,
  String? responsibleName,
  Map<String, String> teamFuncoes = const {},
  Map<String, String> teamCargos = const {},
  DateTime? signedAt,
  DateTime? clientSignedAt,
  bool withSignature = true,
  List<RdoPdfPhoto> photos = const [],
}) async {
  await _loadBrand();
  final day = DateFormat('dd/MM/yyyy').format(date);
  final names = _teamWithLead(_teamNames(technicianName), responsibleName);
  final fallbackCargo = _teamCargo(rdo.technicianCargo);
  final cargos = {
    ...rdo.technicianCargos,
    ...teamCargos,
  };
  final leadName = names.first == '-' ? '' : names.first;
  final leadCargo = _rowCargo(leadName, cargos, fallbackCargo);
  final baseName = rdo.baseName.trim().isNotEmpty
      ? rdo.baseName.trim()
      : (signerName?.trim() ?? '');
  final baseCargo = _plainCargo(rdo.baseCargo);
  final clockIn = rdo.clockIn.trim();
  final lunchStart = rdo.lunchStart.trim();
  final lunchEnd = rdo.lunchEnd.trim();
  final clockOut = rdo.clockOut.trim();
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!),
      margin: const pw.EdgeInsets.fromLTRB(20, 8, 20, 6),
      header: (_) => pw.Image(
        _headerImage!,
        height: 38,
        fit: pw.BoxFit.fitWidth,
      ),
      footer: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Image(
          _footerImage!,
          height: 44,
          fit: pw.BoxFit.fitWidth,
        ),
      ),
      build: (context) {
        return [
          _framed(
            top: true,
            child: pw.Column(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: pw.Center(
                    child: pw.Text(
                      'RELATÓRIO DE SERVIÇO',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                _sectionBar('Dados do Contratante'),
                _padded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 6,
                            child: _field('Contratante:', rdo.client),
                          ),
                          pw.Expanded(
                            flex: 4,
                            child: _field('CNPJ:', rdo.cnpj),
                          ),
                        ],
                      ),
                      _field('Endereço:', rdo.site),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 6,
                            child: _field('Responsável:', baseName),
                          ),
                          pw.Expanded(
                            flex: 4,
                            child: _field('Cargo:', baseCargo),
                          ),
                        ],
                      ),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 6,
                            child: _field('Telefone:', rdo.basePhone),
                          ),
                          pw.Expanded(
                            flex: 4,
                            child: _field('E-mail:', _plainCargo(rdo.baseEmail)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _sectionBar('Informações do Serviço'),
                _padded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: _field('OS Nº:', osNumber),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: _field('Serviço Contratado:', rdo.service),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: _field('Tipo de Sistema:', rdo.systemType),
                      ),
                    ],
                  ),
                ),
                _sectionBar('Equipe Técnica'),
                _teamTable(names, fallbackCargo, leadName, teamFuncoes, cargos),
                _sectionBar('Registro do Dia'),
                _dayTable(
                  day: day,
                  clockIn: clockIn,
                  lunchStart: lunchStart,
                  lunchEnd: lunchEnd,
                  clockOut: clockOut,
                ),
              ],
            ),
          ),
          _framed(child: _sectionBar('Descrição Detalhada do Serviço')),
          _framed(
            child: _padded(
              minHeight: 88,
              child: pw.Text(
                rdo.description,
                style: const pw.TextStyle(
                  fontSize: 9,
                  lineSpacing: 1.8,
                  color: _ink,
                ),
              ),
            ),
          ),
          _framed(child: _sectionBar('Informações Adicionais do Serviço')),
          _framed(
            child: _padded(
              minHeight: 36,
              child: pw.Text(
                rdo.notes,
                style: const pw.TextStyle(
                  fontSize: 9,
                  lineSpacing: 1.8,
                  color: _ink,
                ),
              ),
            ),
          ),
          _framed(
            bottom: true,
            child: pw.Column(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: withSignature
                            ? _electronicStamp(
                                name: leadName,
                                cargo: leadCargo,
                                signedAt: signedAt ?? date,
                              )
                            : _openSignBlock(
                                title: 'Responsável técnico',
                                name: leadName,
                                cargo: leadCargo,
                              ),
                      ),
                      pw.SizedBox(width: 28),
                      pw.Expanded(
                        child: clientSignedAt != null && baseName.isNotEmpty
                            ? _electronicStamp(
                                name: baseName,
                                cargo: baseCargo,
                                signedAt: clientSignedAt,
                              )
                            : _openSignBlock(
                                title: 'Responsável da base',
                                name: baseName,
                                cargo: baseCargo,
                              ),
                      ),
                    ],
                  ),
                ),
                if (!withSignature)
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: pw.Text(
                      'Este relatório segue sem assinatura eletrônica neste documento. Quando aplicável, certificados e documentos com assinatura ICP-Brasil são encaminhados separadamente pelo Adobe, conforme o procedimento adotado.',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        lineSpacing: 1.4,
                        color: _ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ..._photoSection(photos),
        ];
      },
    ),
  );

  return doc.save();
}

List<pw.Widget> _photoSection(List<RdoPdfPhoto> photos) {
  final images = <({String label, pw.ImageProvider image})>[];
  for (final photo in photos) {
    if (photo.bytes.isEmpty) continue;
    try {
      images.add(
        (
          label: photo.label.trim().isEmpty ? 'Foto' : photo.label.trim(),
          image: pw.MemoryImage(Uint8List.fromList(photo.bytes)),
        ),
      );
    } catch (_) {}
  }
  if (images.isEmpty) return const [];
  return [
    pw.SizedBox(height: 10),
    _sectionBar('Registros Fotográficos'),
    pw.SizedBox(height: 8),
    for (var i = 0; i < images.length; i += 2)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _photoCell(images[i])),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: i + 1 < images.length
                  ? _photoCell(images[i + 1])
                  : pw.SizedBox(),
            ),
          ],
        ),
      ),
  ];
}

pw.Widget _photoCell(({String label, pw.ImageProvider image}) photo) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        height: 168,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line, width: 0.5),
        ),
        child: pw.Image(photo.image, fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        photo.label,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ],
  );
}

List<String> _teamNames(String raw) {
  final unique = uniquePersonNames(raw);
  final names = [
    for (final part in unique.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
  return names.isEmpty ? const ['-'] : names;
}

List<String> _teamWithLead(List<String> names, String? responsibleName) {
  final lead = (responsibleName ?? '').trim();
  if (lead.isEmpty) return names;
  final leadKey = personFirstKey(lead);
  if (leadKey.isEmpty) return names;
  final rest = [
    for (final name in names)
      if (name != '-' && personFirstKey(name) != leadKey) name,
  ];
  return [lead, ...rest];
}

String _teamCargo(String raw) {
  final value = raw.trim();
  final folded = foldPersonKey(value);
  if (value.isEmpty ||
      folded == 'tecnico' ||
      folded == 'tecnico e administrativo' ||
      value.contains(' · ') ||
      _looksLikeTime(value)) {
    return defaultTechnicianCargo;
  }
  return value;
}

String _plainCargo(String raw) {
  final value = raw.trim();
  if (value.isEmpty || _looksLikeTime(value)) return '';
  return value;
}

bool _looksLikeTime(String value) {
  return RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value);
}

pw.Widget _framed({
  required pw.Widget child,
  bool top = false,
  bool bottom = false,
}) {
  return pw.Container(
    width: double.infinity,
    decoration: pw.BoxDecoration(
      border: pw.Border(
        left: const pw.BorderSide(color: _line, width: 0.8),
        right: const pw.BorderSide(color: _line, width: 0.8),
        top: top
            ? const pw.BorderSide(color: _line, width: 0.8)
            : pw.BorderSide.none,
        bottom: bottom
            ? const pw.BorderSide(color: _line, width: 0.8)
            : pw.BorderSide.none,
      ),
    ),
    child: child,
  );
}

pw.Widget _sectionBar(String title) {
  return pw.Container(
    width: double.infinity,
    color: _gold,
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Center(
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ),
  );
}

pw.Widget _padded({required pw.Widget child, double minHeight = 0}) {
  return pw.Container(
    width: double.infinity,
    constraints: minHeight > 0 ? pw.BoxConstraints(minHeight: minHeight) : null,
    padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 6),
    child: child,
  );
}

pw.Widget _field(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 9.5, color: _ink),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _inlineField(String label, String value) {
  return pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label ',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.TextSpan(
          text: value,
          style: const pw.TextStyle(fontSize: 9, color: _ink),
        ),
      ],
    ),
  );
}

String _rowCargo(
  String name,
  Map<String, String> cargos,
  String fallback,
) {
  if (name == '-') return '-';
  final stored = cargos[personFirstKey(name)]?.trim() ?? '';
  if (stored.isNotEmpty) return _teamCargo(stored);
  return fallback;
}

String _rowFuncao(
  String name,
  String leadKey,
  Map<String, String> funcoes,
) {
  if (name == '-') return '-';
  final stored = funcoes[personFirstKey(name)]?.trim() ?? '';
  if (stored.isNotEmpty) return stored;
  if (leadKey.isNotEmpty && personFirstKey(name) == leadKey) {
    return 'Responsável técnico';
  }
  return 'Suporte Técnico';
}

pw.Widget _teamTable(
  List<String> names,
  String fallbackCargo,
  String leadName,
  Map<String, String> funcoes,
  Map<String, String> cargos,
) {
  final leadKey = personFirstKey(leadName);
  final rows = <List<String>>[
    for (final name in names)
      [
        name,
        _rowCargo(name, cargos, fallbackCargo),
        _rowFuncao(name, leadKey, funcoes),
      ],
  ];
  while (rows.length < 4) {
    rows.add(const ['-', '-', '-']);
  }
  return pw.Column(
    children: [
      for (final row in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(10, 3, 10, 1),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 3, child: _inlineField('Nome:', row[0])),
              pw.Expanded(flex: 4, child: _inlineField('Cargo:', row[1])),
              pw.Expanded(flex: 3, child: _inlineField('Função:', row[2])),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _dayTable({
  required String day,
  required String clockIn,
  required String lunchStart,
  required String lunchEnd,
  required String clockOut,
}) {
  final headers = const [
    'Data do Serviço',
    'Entrada',
    'Início do Almoço',
    'Retorno do Almoço',
    'Saída',
  ];
  final values = [day, clockIn, lunchStart, lunchEnd, clockOut];
  final flex = const [22, 14, 18, 18, 14];

  pw.Widget cell(
    String text, {
    required bool header,
    required int flex,
    required bool last,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        decoration: pw.BoxDecoration(
          border: last
              ? null
              : const pw.Border(
                  right: pw.BorderSide(color: _line, width: 0.6),
                ),
        ),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: _ink,
          ),
        ),
      ),
    );
  }

  pw.Widget row(List<String> cells, {required bool header}) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _line, width: 0.6),
        ),
      ),
      child: pw.Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            cell(
              cells[i],
              header: header,
              flex: flex[i],
              last: i == cells.length - 1,
            ),
        ],
      ),
    );
  }

  return pw.Column(
    children: [
      row(headers, header: true),
      row(values, header: false),
    ],
  );
}

pw.Widget _electronicStamp({
  required String name,
  required String cargo,
  required DateTime signedAt,
}) {
  final lines = electronicSignatureLines(
    name: name,
    cargo: cargo,
    signedAt: signedAt,
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
              fontSize: i == 1 ? 11 : 9,
              fontWeight: i <= 1 ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _ink,
              lineSpacing: 1.15,
            ),
          ),
        ),
    ],
  );
}

pw.Widget _openSignBlock({
  required String title,
  required String name,
  required String cargo,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 28),
      pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.7)),
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        name.trim().isEmpty ? 'Nome:' : name.trim(),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
      if (cargo.trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            'Cargo: ${cargo.trim()}',
            style: const pw.TextStyle(fontSize: 9, color: _ink),
          ),
        ),
    ],
  );
}
