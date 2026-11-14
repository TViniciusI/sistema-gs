import 'package:flutter/services.dart';
import 'package:gs_mobile/data/hours_report.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _navy = PdfColor.fromInt(0xFF0C1F33);
const _brass = PdfColor.fromInt(0xFFC59E39);
const _ink = PdfColor.fromInt(0xFF1A2330);
const _muted = PdfColor.fromInt(0xFF5C6570);

Future<List<int>> buildHoursReportPdf(HoursReport report) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  final dayFmt = DateFormat('dd/MM/yyyy');
  final doc = pw.Document();
  final headers = [
    'Data',
    'Dia',
    'Feriado',
    'Cliente',
    'Horas',
    'Extras',
    'Noturno',
  ];
  final data = [
    for (final day in report.days)
      [
        dayFmt.format(day.date),
        day.weekdayLabel,
        day.holidayLabel,
        day.place,
        formatWorkedHours(day.workedMinutes),
        formatWorkedHours(day.extraMinutes),
        formatWorkedHours(day.nightMinutes),
      ],
    [
      'Total',
      '',
      '',
      '',
      formatWorkedHours(report.totalWorkedMinutes),
      formatWorkedHours(report.totalExtraMinutes),
      formatWorkedHours(report.totalNightMinutes),
    ],
  ];
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GS Soluções Técnicas',
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              color: _brass,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Relatório de horas',
            style: pw.TextStyle(
              font: bold,
              fontSize: 18,
              color: _navy,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${report.technicianName}  ·  ${dayFmt.format(report.from)} a ${dayFmt.format(report.to)}',
            style: pw.TextStyle(font: regular, fontSize: 11, color: _muted),
          ),
          pw.SizedBox(height: 10),
        ],
      ),
      footer: (context) => pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}  ·  Fechamento: dia 24 ao 23. Extra: 8h/dia + 1h almoço; sábado 4h; domingo e feriado o dia todo, só com horário preenchido. Noturno: 22h às 05h. Duas OS no mesmo dia: horário sobreposto conta uma vez.',
        style: pw.TextStyle(font: regular, fontSize: 8, color: _muted),
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            font: bold,
            fontSize: 9,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: _navy),
          cellStyle: pw.TextStyle(font: regular, fontSize: 8, color: _ink),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          columnWidths: {
            0: const pw.FixedColumnWidth(62),
            1: const pw.FixedColumnWidth(82),
            2: const pw.FlexColumnWidth(1.3),
            3: const pw.FlexColumnWidth(2.0),
            4: const pw.FixedColumnWidth(58),
            5: const pw.FixedColumnWidth(58),
            6: const pw.FixedColumnWidth(62),
          },
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Total de horas: ${formatWorkedHours(report.totalWorkedMinutes)}   ·   Horas extras: ${formatWorkedHours(report.totalExtraMinutes)}   ·   Adicional noturno: ${formatWorkedHours(report.totalNightMinutes)}',
          style: pw.TextStyle(font: bold, fontSize: 11, color: _navy),
        ),
      ],
    ),
  );
  return doc.save();
}
