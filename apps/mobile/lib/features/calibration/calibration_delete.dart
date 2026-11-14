import 'package:flutter/material.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/demo/auth.dart';

enum _DeleteChoice { calibrationOnly, certificate }

/// Exclui a calibração. Se ela é de um certificado da OS, pergunta se tira
/// também o número da OS (senão ele fica lá como "Sem calibração").
/// Retorna true se apagou algo.
Future<bool> confirmDeleteCalibration(
  BuildContext context,
  CalibrationJob job,
) async {
  final os = osLinkedToCalibrationJob(job);
  final slot = slotLinkedToCalibrationJob(job);
  final canRemoveSlot = os != null &&
      slot != null &&
      !os.isClosed &&
      AuthSession.instance.user?.canGenerateOs == true;
  final filled =
      job.status == CalibrationJobStatus.done || job.hasMeasurements;

  final choice = await showDialog<_DeleteChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        canRemoveSlot
            ? 'Excluir ${slot.certificateNumber}?'
            : 'Excluir calibração?',
      ),
      content: Text(
        [
          if (canRemoveSlot) ...[
            'Apagar certificado: tira o ${slot.certificateNumber} da '
                'OS ${os.number}.',
            'Só a calibração: o número continua na OS, sem calibração.',
          ] else
            'Isso apaga ${job.title} desta lista.',
          if (filled) 'ATENÇÃO: já tem medições, que serão apagadas.',
          'Não dá para desfazer.',
        ].join('\n\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('calibracao-excluir-confirmar'),
          onPressed: () =>
              Navigator.pop(context, _DeleteChoice.calibrationOnly),
          child: Text(canRemoveSlot ? 'Só a calibração' : 'Excluir'),
        ),
        if (canRemoveSlot)
          TextButton(
            key: const Key('calibracao-excluir-certificado'),
            onPressed: () => Navigator.pop(context, _DeleteChoice.certificate),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8A1F1F),
            ),
            child: const Text('Apagar certificado'),
          ),
      ],
    ),
  );
  if (choice == null) return false;

  String? cloudError;
  if (choice == _DeleteChoice.certificate && canRemoveSlot) {
    try {
      await FieldStore.instance.saveCalibrationSlots(
        osId: os.id,
        slots: [
          for (final item in os.calibrationSlots)
            if (item.id != slot.id) item,
        ],
      );
    } on CloudSyncException catch (error) {
      cloudError = '$error';
    }
  }
  await CalibrationStore.instance.delete(job.id);
  if (context.mounted) {
    final what = choice == _DeleteChoice.certificate
        ? 'Certificado ${slot?.certificateNumber ?? job.number} apagado da OS.'
        : 'Calibração excluída.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cloudError == null ? what : '$what Só neste aparelho: $cloudError',
        ),
      ),
    );
  }
  return true;
}
