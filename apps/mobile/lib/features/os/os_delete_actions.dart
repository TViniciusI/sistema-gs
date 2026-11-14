import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/demo/auth.dart';

/// Confirma e apaga OS (local + nuvem). Retorna true se apagou.
Future<bool> deleteOsWithConfirm(BuildContext context, SavedOs os) async {
  final canDelete = AuthSession.instance.user?.canGenerateOs == true;
  if (!canDelete) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(
          'Só o escritório pode apagar OS.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
    return false;
  }
  final extras = <String>[
    if (os.rdos.isNotEmpty) '${os.rdos.length} RDO(s)',
    if (os.calibrationSlots.isNotEmpty)
      '${os.calibrationSlots.length} certificado(s)',
  ];
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Apagar OS ${os.number}?'),
      content: Text(
        extras.isEmpty
            ? 'Isso remove a OS da lista e da planilha da empresa. Não dá para desfazer.'
            : 'Isso remove a OS da lista e da planilha da empresa, '
                'incluindo ${extras.join(' e ')}. Não dá para desfazer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('os-delete-confirmar'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Apagar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await FieldStore.instance.deleteOs(os.id);
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(
          'OS ${os.number} apagada.',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text('$error', style: const TextStyle(fontSize: 16)),
      ),
    );
    return false;
  }
}
