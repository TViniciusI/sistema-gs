import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Extensão do arquivo (sem ponto), minúscula.
String attachmentExtension(String fileName, {String fallback = 'jpg'}) {
  final match = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(fileName.trim());
  if (match == null) return fallback;
  return match.group(1)!.toLowerCase();
}

/// Nome sem extensão.
String attachmentStem(String fileName) {
  final trimmed = fileName.trim();
  final dot = trimmed.lastIndexOf('.');
  if (dot <= 0) return trimmed;
  return trimmed.substring(0, dot);
}

String sanitizeAttachmentStem(String raw) {
  var value = raw.trim();
  value = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ');
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.isEmpty) {
    value = 'foto_${DateFormat('dd-MM-yyyy_HH-mm').format(DateTime.now())}';
  }
  if (value.length > 80) value = value.substring(0, 80).trim();
  return value;
}

String buildAttachmentFileName(String stem, String extension) {
  final clean = sanitizeAttachmentStem(stem);
  final ext = extension.trim().toLowerCase().replaceAll('.', '');
  return ext.isEmpty ? clean : '$clean.$ext';
}

/// Sugestão legível quando a câmera/galeria manda IMG_xxxx / image.jpg.
String suggestedPhotoStem({String? originalName, String? hint}) {
  final hintClean = (hint ?? '').trim();
  if (hintClean.isNotEmpty) return sanitizeAttachmentStem(hintClean);
  final original = (originalName ?? '').trim();
  final stem = attachmentStem(original);
  final lower = stem.toLowerCase();
  final looksGeneric = stem.isEmpty ||
      lower.startsWith('img_') ||
      lower.startsWith('image') ||
      lower.startsWith('photo') ||
      lower.startsWith('pxl_') ||
      RegExp(r'^\d{10,}').hasMatch(lower);
  if (!looksGeneric && stem.length >= 3) return sanitizeAttachmentStem(stem);
  return 'foto_${DateFormat('dd-MM-yyyy_HH-mm').format(DateTime.now())}';
}

/// Diálogo para nomear/renomear anexo. `null` = cancelou.
Future<String?> promptAttachmentName(
  BuildContext context, {
  required String currentName,
  String title = 'Nome da foto',
  String? hint,
}) async {
  final ext = attachmentExtension(currentName);
  final initial = suggestedPhotoStem(
    originalName: currentName,
    hint: hint ?? attachmentStem(currentName),
  );
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Escolha um nome fácil de achar depois (ex.: plaqueta FIQ1, divergência TAG TE 1).',
              style: TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nome',
                suffixText: '.$ext',
              ),
              onSubmitted: (value) {
                Navigator.pop(
                  context,
                  buildAttachmentFileName(value, ext),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                buildAttachmentFileName(controller.text, ext),
              );
            },
            child: const Text('Salvar nome'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}
