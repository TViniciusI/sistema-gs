import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mail.dart';
import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/data/os_zip.dart';
import 'package:gs_mobile/data/rdo_pdf.dart';
import 'package:gs_mobile/data/rdo_refresh.dart';
import 'package:gs_mobile/data/send_os.dart';

enum DriveNameConflict { replace, copy }

Future<DriveNameConflict?> askDriveConflict(
  BuildContext context,
  List<String> existing,
) {
  final preview = existing.take(4).join('\n');
  final more = existing.length > 4 ? '\n… e mais ${existing.length - 4}' : '';
  return showDialog<DriveNameConflict>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: GsTheme.paper,
        title: const Text(
          'Arquivo já na pasta',
          style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
        ),
        content: Text(
          'Já existe na pasta da OS:\n$preview$more\n\n'
          'Sobrescrever atualiza o arquivo. Cópia grava com outro nome (_copia) para não encher a pasta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, DriveNameConflict.copy),
            child: const Text('Salvar como cópia'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, DriveNameConflict.replace),
            style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
            child: const Text('Sobrescrever'),
          ),
        ],
      );
    },
  );
}

class SelectedOsPayload {
  const SelectedOsPayload({
    required this.files,
    this.missingAttachmentNames = const [],
  });

  final List<Map<String, String>> files;
  final List<String> missingAttachmentNames;
}

Future<SelectedOsPayload> collectSelectedOsPayload({
  required SavedOs os,
  required Set<String> rdoIds,
  required Set<String> attachmentNames,
  Iterable<DraftFile> drafts = const [],
  bool withSignature = true,
}) async {
  final current = FieldStore.instance.byId(os.id) ?? os;
  final files = <Map<String, String>>[];
  final seen = <String>{};
  final missing = <String>[];
  final draftNames = {for (final d in drafts) d.name};

  void addFile(String name, String folder, List<int> bytes) {
    if (bytes.isEmpty) return;
    final key = '$folder/${name.toLowerCase()}';
    if (!seen.add(key)) return;
    files.add({
      'name': name,
      'folder': folder,
      'mime': officeFileMime(name),
      'data': base64Encode(bytes),
    });
  }

  for (final entry in current.rdos) {
    if (!rdoIds.contains(entry.id)) continue;
    final signed = withSignature && entry.isSigned;
    final stored = signed ? entry.pdf : null;
    final storedBytes =
        stored == null ? null : await FieldStore.instance.ensureBytes(stored);
    if (storedBytes != null && storedBytes.isNotEmpty) {
      addFile(stored!.name, 'RDO', storedBytes);
    } else {
      final bytes = await buildRdoPdfForEntry(
        current,
        entry,
        withSignature: signed,
      );
      final name = signed
          ? rdoFileName(current.number, entry.date)
          : rdoUnsignedFileName(current.number, entry.date);
      addFile(name, 'RDO', bytes);
    }
    for (final photo in entry.photos) {
      final pb = await FieldStore.instance.ensureBytes(photo);
      if (pb == null || pb.isEmpty) continue;
      addFile(photo.name, 'Fotos', pb);
    }
  }

  for (final file in current.attachments) {
    if (!attachmentNames.contains(file.name)) continue;
    final bytes = await FieldStore.instance.ensureBytes(file);
    if (bytes == null || bytes.isEmpty) {
      if (!draftNames.contains(file.name)) missing.add(file.name);
      continue;
    }
    final folder = file.kind == OsFileKind.photo ? 'Fotos' : 'Anexos';
    addFile(file.name, folder, bytes);
  }

  for (final draft in drafts) {
    if (!attachmentNames.contains(draft.name)) continue;
    final bytes = draft.bytes;
    if (bytes == null || bytes.isEmpty) {
      missing.add(draft.name);
      continue;
    }
    final folder = draft.kind == OsFileKind.photo ? 'Fotos' : 'Anexos';
    addFile(draft.name, folder, bytes);
  }

  for (final name in attachmentNames) {
    if (seen.any((k) => k.endsWith('/${name.toLowerCase()}'))) continue;
    if (missing.contains(name)) continue;
    if (current.attachments.any((f) => f.name == name)) continue;
    if (draftNames.contains(name)) continue;
    missing.add(name);
  }

  return SelectedOsPayload(
    files: files,
    missingAttachmentNames: missing,
  );
}

Future<void> emailSelectedOsItems(
  BuildContext context, {
  required SavedOs os,
  required Set<String> rdoIds,
  required Set<String> attachmentNames,
  Iterable<DraftFile> drafts = const [],
  required String emailsField,
  bool compressZip = false,
}) async {
  final extra = <DraftFile>[];
  final current = FieldStore.instance.byId(os.id) ?? os;
  final seen = <String>{};
  final recipients = parseRecipientEmails(emailsField);
  final toClient = mailRecipientsIncludeClient(current, recipients);
  // Envio ao cliente: RDO já sai com assinatura do responsável do serviço.
  final withSignature = toClient;

  if (toClient && rdoIds.isNotEmpty) {
    final unsigned = [
      for (final entry in current.rdos)
        if (rdoIds.contains(entry.id) && !entry.isSigned) entry,
    ];
    if (unsigned.isNotEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'Para enviar ao cliente, assine o RDO antes '
            '(responsável do serviço).',
          ),
        ),
      );
      return;
    }
  }

  for (final entry in current.rdos) {
    if (!rdoIds.contains(entry.id)) continue;
    final draft = await _rdoAsDraft(
      current,
      entry,
      withSignature: withSignature,
    );
    if (!seen.add(draft.name)) continue;
    extra.add(draft);
  }
  final missing = <String>[];
  for (final file in current.attachments) {
    if (!attachmentNames.contains(file.name)) continue;
    if (!seen.add(file.name)) continue;
    final bytes = await FieldStore.instance.ensureBytes(file);
    if (bytes == null || bytes.isEmpty) {
      missing.add(file.name);
      continue;
    }
    extra.add(DraftFile(name: file.name, kind: file.kind, bytes: bytes));
  }
  for (final draft in drafts) {
    if (!attachmentNames.contains(draft.name)) continue;
    if (!seen.add(draft.name)) continue;
    if (draft.bytes == null || draft.bytes!.isEmpty) {
      missing.add(draft.name);
      continue;
    }
    extra.add(draft);
  }
  if (extra.isEmpty) {
    if (!context.mounted) return;
    final msg = missing.isNotEmpty
        ? 'Anexo sem arquivo neste aparelho. Anexe de novo: '
            '${missing.take(3).join(', ')}'
            '${missing.length > 3 ? '…' : ''}.'
        : 'Marque pelo menos um RDO ou anexo para enviar.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: GsTheme.navy, content: Text(msg)),
    );
    return;
  }
  final payload = compressZip && extra.length > 1
      ? <DraftFile>[zipAsDraft(osNumber: current.number, files: extra)]
      : extra;
  if (missing.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(
          'Sem arquivo local: ${missing.take(3).join(', ')}'
          '${missing.length > 3 ? '…' : ''}. Os outros seguem no e-mail.',
        ),
      ),
    );
  }
  final audience = toClient
      ? (recipients.any(officeRecipientEmails().contains)
            ? MailAudience.both
            : MailAudience.client)
      : MailAudience.office;
  await sendOsFromUi(
    context,
    current,
    includeRdo: false,
    includeAttachments: false,
    audience: audience,
    extraFiles: payload,
    rdoIds: rdoIds,
    clientEmailOverride: emailsField,
    withSignature: withSignature,
  );
}

Future<DraftFile> _rdoAsDraft(
  SavedOs os,
  SavedRdo entry, {
  bool withSignature = false,
}) async {
  final stored = entry.pdf;
  if (stored != null) {
    final bytes = await FieldStore.instance.ensureBytes(stored);
    if (bytes != null && bytes.isNotEmpty) {
      return DraftFile(name: stored.name, kind: OsFileKind.rdo, bytes: bytes);
    }
  }
  final bytes = await buildRdoPdfForEntry(
    os,
    entry,
    withSignature: withSignature,
  );
  return DraftFile(
    name: withSignature
        ? rdoFileName(os.number, entry.date)
        : rdoUnsignedFileName(os.number, entry.date),
    kind: OsFileKind.rdo,
    bytes: bytes,
  );
}

/// `true` se gravou na pasta da OS (anexos locais já foram limpos).
Future<bool> cloudSelectedOsItems(
  BuildContext context, {
  required SavedOs os,
  required Set<String> rdoIds,
  required Set<String> attachmentNames,
  Iterable<DraftFile> drafts = const [],
  bool withSignature = true,
}) async {
  SelectedOsPayload payload;
  try {
    payload = await collectSelectedOsPayload(
      os: os,
      rdoIds: rdoIds,
      attachmentNames: attachmentNames,
      drafts: drafts,
      withSignature: withSignature,
    );
  } catch (error) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: GsTheme.navy, content: Text('$error')),
    );
    return false;
  }
  if (payload.files.isEmpty) {
    if (!context.mounted) return false;
    final missing = payload.missingAttachmentNames;
    final msg = missing.isNotEmpty
        ? 'Anexo sem arquivo neste aparelho. Anexe de novo: '
            '${missing.take(3).join(', ')}'
            '${missing.length > 3 ? '…' : ''}.'
        : (attachmentNames.isNotEmpty || rdoIds.isNotEmpty)
        ? 'Não deu para montar o arquivo marcado. Anexe de novo e tente salvar.'
        : 'Marque pelo menos um RDO ou anexo para salvar.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: GsTheme.navy, content: Text(msg)),
    );
    return false;
  }

  if (!context.mounted) return false;
  if (!await ensureDriveReady(context)) return false;
  if (!context.mounted) return false;

  final check = await AccountApi.instance.checkOsFolderFiles(
    osId: os.id,
    osNumber: os.number,
    files: [
      for (final f in payload.files)
        {'name': f['name']!, 'folder': f['folder']!},
    ],
  );
  if (!check.ok) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(
          friendlySheetError(check.error) ??
              'Não conferiu a pasta da OS no Google Drive.',
        ),
      ),
    );
    return false;
  }
  var conflictMode = 'replace';
  if (check.existingFiles.isNotEmpty) {
    if (!context.mounted) return false;
    final choice = await askDriveConflict(context, check.existingFiles);
    if (choice == null) return false;
    conflictMode =
        choice == DriveNameConflict.copy ? 'rename' : 'replace';
  }

  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: GsTheme.navy,
      content: Text('Salvando seleção no Google Drive…'),
    ),
  );

  final ok = await uploadOsFilesToDrive(
    context,
    os,
    files: payload.files,
    conflict: conflictMode,
  );
  if (!ok) return false;

  // Anexos já estão na pasta da OS — saem do aparelho para não atrapalhar novos envios.
  if (attachmentNames.isNotEmpty) {
    await FieldStore.instance.removeOsAttachmentsByNames(
      os.id,
      attachmentNames,
    );
  }
  return true;
}
