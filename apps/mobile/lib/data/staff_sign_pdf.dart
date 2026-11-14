import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:gs_mobile/data/e_signature.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Carimba a assinatura eletrônica no PDF original (última página, centro).
Future<Uint8List> stampSignatureOnStaffPdf({
  required Uint8List pdfBytes,
  required String staffName,
  String cargo = '',
  DateTime? signedAt,
  Uint8List? signaturePng,
}) async {
  final document = sf.PdfDocument(inputBytes: pdfBytes);
  try {
    if (document.pages.count == 0) {
      throw StateError('PDF sem páginas');
    }
    final page = document.pages[document.pages.count - 1];
    final size = page.getClientSize();
    const boxW = 260.0;
    const boxH = 88.0;
    final x = (size.width - boxW) / 2;
    final y = (size.height * 0.50) - (boxH / 2);

    // Fundo branco com borda dourada elegante
    page.graphics.drawRectangle(
      brush: sf.PdfSolidBrush(sf.PdfColor(255, 255, 255)),
      pen: sf.PdfPen(sf.PdfColor(197, 158, 57), width: 1.5),
      bounds: Rect.fromLTWH(x, y, boxW, boxH),
    );

    final fontSmall = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 7.5);
    final fontBold = sf.PdfStandardFont(
      sf.PdfFontFamily.helvetica,
      9.5,
      style: sf.PdfFontStyle.bold,
    );
    final fontTitle = sf.PdfStandardFont(
      sf.PdfFontFamily.helvetica,
      7.5,
      style: sf.PdfFontStyle.bold,
    );
    final textBrush = sf.PdfSolidBrush(sf.PdfColor(12, 31, 51));

    final lines = electronicSignatureLines(
      name: staffName,
      cargo: cargo,
      signedAt: signedAt ?? DateTime.now(),
    );

    var currentY = y + 8.0;
    for (var i = 0; i < lines.length; i++) {
      final font = (i == 0)
          ? fontTitle
          : (i == 1)
              ? fontBold
              : fontSmall;
      page.graphics.drawString(
        lines[i],
        font,
        brush: textBrush,
        bounds: Rect.fromLTWH(x + 10, currentY, boxW - 20, 14),
      );
      currentY += (i == 1 ? 14.0 : 12.0);
    }

    final stamped = Uint8List.fromList(await document.save());
    return stamped;
  } finally {
    document.dispose();
  }
}

Future<Uint8List> buildStaffSignPdf({
  required String staffName,
  required String cargo,
  required String documentName,
  required DateTime signedAt,
  Uint8List? signaturePng,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  final pdf = pw.Document();
  final stamp = DateFormat('dd/MM/yyyy HH:mm').format(signedAt.toLocal());
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TERMO DE CIÊNCIA E ASSINATURA',
              style: pw.TextStyle(
                font: bold,
                fontSize: 16,
                color: PdfColor.fromInt(0xFF0C1F33),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              gsCompanyName,
              style: pw.TextStyle(font: bold, fontSize: 12),
            ),
            pw.Text(
              'CNPJ $gsCompanyCnpj',
              style: pw.TextStyle(font: regular, fontSize: 11),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Documento: $documentName',
              style: pw.TextStyle(font: regular, fontSize: 12),
            ),
            pw.Text(
              'Funcionário: $staffName',
              style: pw.TextStyle(font: regular, fontSize: 12),
            ),
            if (cargo.trim().isNotEmpty)
              pw.Text(
                'Cargo: $cargo',
                style: pw.TextStyle(font: regular, fontSize: 12),
              ),
            pw.Text(
              'Assinado em: $stamp',
              style: pw.TextStyle(font: regular, fontSize: 12),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Declaro que li o documento acima, estou ciente do conteúdo e assino eletronicamente neste aplicativo.',
              style: pw.TextStyle(font: regular, fontSize: 12, lineSpacing: 4),
            ),
            pw.SizedBox(height: 24),
            if (signaturePng != null)
              pw.Container(
                width: 280,
                height: 110,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFC59E39)),
                ),
                child: pw.Image(pw.MemoryImage(signaturePng), fit: pw.BoxFit.contain),
              )
            else
              pw.Text(
                electronicSignatureLines(
                  name: staffName,
                  cargo: cargo,
                  signedAt: signedAt,
                ).join('\n'),
                style: pw.TextStyle(font: regular, fontSize: 11),
              ),
          ],
        );
      },
    ),
  );
  return Uint8List.fromList(await pdf.save());
}
