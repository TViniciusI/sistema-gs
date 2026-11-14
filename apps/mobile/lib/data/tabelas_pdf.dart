import 'package:flutter/services.dart';
import 'package:gs_mobile/data/tabelas20.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _gold = PdfColor.fromInt(0xFFC39F2F);
const _ink = PdfColor.fromInt(0xFF1A2330);

pw.MemoryImage? _headerImage;
pw.MemoryImage? _footerImage;
pw.Font? _baseFont;
pw.Font? _boldFont;

class Tabela20PdfData {
  const Tabela20PdfData({
    required this.kindLabel,
    required this.standard,
    required this.date,
    required this.productName,
    required this.systemNumber,
    required this.technicianName,
    required this.densityAmbient,
    required this.temperatureSample,
    required this.volumeAmbient,
    required this.temperatureCt,
    required this.volumeObjeto,
    required this.result,
    this.showVariancePercent = true,
  });

  final String kindLabel;
  final String standard;
  final DateTime date;
  final String productName;
  final String systemNumber;
  final String technicianName;
  final String densityAmbient;
  final String temperatureSample;
  final String volumeAmbient;
  final String temperatureCt;
  final String volumeObjeto;
  final DerivadosResult result;
  final bool showVariancePercent;
}

String tabela20FileName({
  required String kind,
  required DateTime date,
  String product = '',
  String system = '',
}) {
  final day =
      '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year.toString().substring(2)}';
  final extra = [product, system]
      .map((value) => value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-'))
      .where((value) => value.isNotEmpty)
      .join('_');
  final suffix = extra.isEmpty ? day : '${extra}_$day';
  return 'Tabela20_${kind}_$suffix.pdf';
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

Future<List<int>> buildTabela20Pdf(Tabela20PdfData data) async {
  await _loadBrand();
  final day = DateFormat('dd/MM/yyyy').format(data.date);
  final result = data.result;
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!),
      margin: const pw.EdgeInsets.fromLTRB(28, 16, 28, 14),
      header: (_) => pw.Image(
        _headerImage!,
        height: 36,
        fit: pw.BoxFit.fitWidth,
      ),
      footer: (_) => pw.Image(
        _footerImage!,
        height: 38,
        fit: pw.BoxFit.fitWidth,
      ),
      build: (context) {
        return [
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'CORREÇÃO VOLUMÉTRICA A 20 °C',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              '${data.kindLabel} · ${data.standard}',
              style: const pw.TextStyle(fontSize: 10, color: _ink),
            ),
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('Identificação'),
          _box(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _field('Data:', day),
                _field('Nome do produto:', _orDash(data.productName)),
                _field('Número do sistema:', _orDash(data.systemNumber)),
                _field('Técnico:', _orDash(data.technicianName)),
              ],
            ),
          ),
          _sectionTitle('Amostra'),
          _table(
            headers: const ['Campo', 'Valor'],
            rows: [
              ['Densidade da amostra', '${data.densityAmbient} kg/m³'],
              ['Temperatura da amostra', '${data.temperatureSample} °C'],
              ['Volume ambiente', '${data.volumeAmbient} L'],
              ['Temperatura do CT', '${data.temperatureCt} °C'],
              ['Volume a 20 do objeto', '${data.volumeObjeto} L20'],
            ],
          ),
          _sectionTitle('Resultado a 20 °C'),
          _table(
            headers: const ['Campo', 'Valor'],
            rows: [
              if (result.inpm != null)
                ['Grau INPM do álcool', '${formatPt(result.inpm!, 2)} % massa'],
              ['Densidade a 20 °C', '${formatPt(result.density20, 3)} kg/m³'],
              ['Fator de correção (CTL)', formatPt(result.ctl, 4)],
              [
                'Volume a 20 °C',
                '${formatPt(result.volume20, result.inpm != null ? 0 : 2)} L20',
              ],
              ['Peso', '${formatPt(result.weight, 3)} kg'],
              [
                'Perda & sobra',
                data.showVariancePercent && result.variancePercent != null
                    ? '${formatPt(result.variancePercent!, 3)} % · ${formatPt(result.variance ?? 0, result.inpm != null ? 0 : 2)} L20'
                    : '${formatPt(result.variance ?? 0, result.inpm != null ? 0 : 2)} L20',
              ],
            ],
          ),
        ];
      },
    ),
  );

  return doc.save();
}

String _orDash(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '—' : trimmed;
}

pw.Widget _sectionTitle(String title) {
  return pw.Container(
    width: double.infinity,
    color: _gold,
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Center(
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ),
  );
}

pw.Widget _box({required pw.Widget child}) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        left: pw.BorderSide(color: _ink, width: 0.6),
        right: pw.BorderSide(color: _ink, width: 0.6),
        bottom: pw.BorderSide(color: _ink, width: 0.6),
      ),
    ),
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
    ),
  );
}

pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  pw.Widget cell(String text, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _ink,
        ),
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: _ink, width: 0.6),
    columnWidths: const {
      0: pw.FlexColumnWidth(2),
      1: pw.FlexColumnWidth(1.4),
    },
    children: [
      pw.TableRow(
        children: [for (final header in headers) cell(header, header: true)],
      ),
      for (final row in rows)
        pw.TableRow(children: [for (final value in row) cell(value)]),
    ],
  );
}
