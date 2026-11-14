import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';

/// `true` = assinado (digital se a pessoa tiver ICP, senão eletrônica).
/// `false` = sem assinatura. `null` = cancelou.
Future<bool?> askCertificateSignatureMode(
  BuildContext context, {
  String title = 'Assinatura do certificado',
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: GsTheme.paper,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        content: const Text(
          'Quem já tem certificado digital ICP-Brasil deixa o espaço para '
          'assinatura digital. Quem ainda não tem recebe assinatura eletrônica '
          'no PDF. Ou baixe sem assinatura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Sem assinatura'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
            child: const Text('Baixar assinado'),
          ),
        ],
      );
    },
  );
}
