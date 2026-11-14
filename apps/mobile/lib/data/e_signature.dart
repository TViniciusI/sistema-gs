import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:intl/intl.dart';

String electronicSignatureStamp(DateTime when) {
  final local = when.toLocal();
  final date = DateFormat('dd/MM/yyyy HH:mm:ss').format(local);
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '$date $sign$hours:$minutes';
}

List<String> electronicSignatureLines({
  required String name,
  String cargo = '',
  DateTime? signedAt,
}) {
  final who = name.trim().isEmpty ? 'Nome do funcionário' : name.trim();
  return [
    'Assinado eletronicamente por:',
    who,
    if (cargo.trim().isNotEmpty) 'Cargo: ${cargo.trim()}',
    'Data: ${electronicSignatureStamp(signedAt ?? DateTime.now())}',
    '$gsCompanyName CNPJ:',
    gsCompanyCnpj,
  ];
}

Future<Uint8List> buildElectronicSignaturePng({
  required String name,
  String cargo = '',
  DateTime? signedAt,
}) async {
  const width = 900.0;
  const height = 320.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = Colors.white,
  );

  final lines = electronicSignatureLines(
    name: name,
    cargo: cargo,
    signedAt: signedAt,
  );
  var y = 16.0;
  for (var i = 0; i < lines.length; i++) {
    final style = i == 0
        ? const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2330),
            height: 1.25,
          )
        : i == 1
        ? const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2330),
            height: 1.2,
          )
        : const TextStyle(
            fontSize: 18,
            color: Color(0xFF1A2330),
            height: 1.25,
          );
    final painter = TextPainter(
      text: TextSpan(text: lines[i], style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: width - 40);
    painter.paint(canvas, Offset(20, y));
    y += painter.height + 4;
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  if (bytes == null) {
    throw StateError('Não foi possível gerar a assinatura eletrônica.');
  }
  return bytes.buffer.asUint8List();
}

class ElectronicSignatureCard extends StatelessWidget {
  const ElectronicSignatureCard({
    super.key,
    required this.name,
    this.cargo = '',
    this.signedAt,
    this.title,
  });

  final String name;
  final String cargo;
  final DateTime? signedAt;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final lines = electronicSignatureLines(
      name: name,
      cargo: cargo,
      signedAt: signedAt,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: GsTheme.brass, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.trim().isNotEmpty) ...[
            Text(
              title!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: GsTheme.navy,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < lines.length; i++) ...[
            Text(
              lines[i],
              style: TextStyle(
                fontSize: i == 0
                    ? 13
                    : i == 1
                    ? 18
                    : 15,
                fontWeight: i <= 1 ? FontWeight.w700 : FontWeight.w500,
                color: GsTheme.navy,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OpenClientSignCard extends StatelessWidget {
  const OpenClientSignCard({
    super.key,
    required this.name,
    this.cargo = '',
  });

  final String name;
  final String cargo;

  @override
  Widget build(BuildContext context) {
    final who = name.trim().isEmpty ? 'Nome do responsável da base' : name.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: GsTheme.brass, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prévia no PDF · cliente',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Responsável da base',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: GsTheme.navy),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            who,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          if (cargo.trim().isNotEmpty)
            Text(
              'Cargo: ${cargo.trim()}',
              style: const TextStyle(fontSize: 15, color: GsTheme.navy, height: 1.35),
            ),
          const SizedBox(height: 6),
          const Text(
            'Fica em branco para o cliente assinar no Adobe.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
          ),
        ],
      ),
    );
  }
}
