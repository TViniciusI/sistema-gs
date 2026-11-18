import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mail.dart';
import 'package:gs_mobile/data/office_store.dart';
import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/data/rdo_pdf.dart';
import 'package:gs_mobile/data/rdo_refresh.dart';
import 'package:gs_mobile/demo/auth.dart';

export 'package:gs_mobile/data/drive_archive.dart' show showArchiveOsSheet;

Future<void> showSendRdoSheet(
  BuildContext context,
  SavedOs os, {
  Iterable<String>? rdoIds,
}) {
  return showArchiveOsSheet(context, os, rdoIds: rdoIds);
}

Future<void> sendOsFromUi(
  BuildContext context,
  SavedOs os, {
  Iterable<String>? rdoIds,
  bool withSignature = true,
  MailAudience audience = MailAudience.both,
  bool includeRdo = true,
  bool includeAttachments = false,
  List<DraftFile> extraFiles = const [],
  String? clientEmailOverride,
}) async {
  final user = AuthSession.instance.user;
  final selected = includeRdo
      ? (rdoIds?.toList() ?? [for (final entry in os.rdos) entry.id])
      : const <String>[];
  // IDs para o texto do e-mail mesmo quando o PDF já veio em extraFiles.
  final bodyRdoIds = rdoIds?.toList() ?? selected;
  try {
    if (includeRdo && !os.hasRdo) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text('Ainda não há RDO nesta OS para enviar.'),
        ),
      );
      return;
    }
    if (includeRdo && selected.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text('Marque pelo menos um RDO para enviar.'),
        ),
      );
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            includeRdo
                ? (withSignature
                    ? 'Preparando o RDO com assinatura…'
                    : 'Preparando o RDO sem assinatura…')
                : 'Preparando os anexos internos…',
          ),
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    var current = FieldStore.instance.byId(os.id) ?? os;
    final extra = <DraftFile>[...extraFiles];
    if (includeRdo) {
      final chosen = [
        for (final entry in current.rdos)
          if (selected.contains(entry.id)) entry,
      ];
      if (withSignature && chosen.any((entry) => !entry.isSigned)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GsTheme.navy,
            content: Text(
              'Esse RDO ainda não tem assinatura. Envie sem assinatura ou assine antes.',
            ),
          ),
        );
        return;
      }
      for (final entry in chosen) {
        extra.add(await _rdoMailDraft(current, entry, withSignature));
      }
    } else if (includeAttachments) {
      extra.addAll(_attachmentMailDrafts(current));
    }
    final listed = parseRecipientEmails(clientEmailOverride);
    final officeSet = officeRecipientEmails().toSet();
    final wantClient =
        audience == MailAudience.client || audience == MailAudience.both;
    final clientFromField = [
      for (final email in listed)
        if (!officeSet.contains(email)) email,
    ];
    final clientEmail = wantClient
        ? (clientFromField.isNotEmpty
            ? clientFromField.first
            : _resolvedClientEmail(current, null))
        : null;
    final extraTo = <String>[
      if (listed.isNotEmpty)
        ...listed
      else if (clientEmail != null)
        clientEmail,
    ];
    final mail = prepareOsMail(
      os: current,
      technicianName: user?.name ?? 'Técnico GS',
      extra: extra,
      rdoIds: bodyRdoIds.isEmpty ? null : bodyRdoIds,
      extraTo: extraTo,
      recipients: listed,
      includeStoredRdo: false,
      includeAttachments: false,
      withSignature: withSignature,
      attachmentsOnly: !includeRdo && extra.every((f) => f.kind != OsFileKind.rdo),
      audience: audience,
    );
    if (!context.mounted) return;
    final attachmentsOnly = !includeRdo;
    final opened = await showPreparedMailDialog(
      context,
      mail,
      osId: current.id,
      osNumber: current.number,
      replyTo: user?.email ?? '',
      attachmentsOnly: attachmentsOnly,
    );
    if (opened == null) return;
    try {
      await OfficeStore.instance.receive(current);
    } catch (_) {}
    if (opened == OfficeSendKind.server) {
      try {
        await FieldStore.instance.markEmailed(current.id);
      } catch (_) {}
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(_sentLabel(opened, attachmentsOnly: attachmentsOnly)),
      ),
    );
    if (wantClient && clientEmail == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'Esta OS não tem e-mail da base. O envio vai só para os administrativos.',
          ),
        ),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text('Não enviou o e-mail. $error'),
      ),
    );
  }
}

String? _resolvedClientEmail(SavedOs os, String? override) {
  final typed = (override ?? '').trim().toLowerCase();
  if (isMailAddress(typed)) return typed;
  return clientRdoEmail(os);
}

List<DraftFile> _attachmentMailDrafts(SavedOs os) {
  final extra = <DraftFile>[];
  final seen = <String>{};
  for (final file in os.attachments) {
    if (!seen.add(file.name)) continue;
    final bytes = FieldStore.instance.bytesFor(file);
    if (bytes == null || bytes.isEmpty) continue;
    extra.add(DraftFile(name: file.name, kind: file.kind, bytes: bytes));
  }
  return extra;
}

Future<DraftFile> _rdoMailDraft(
  SavedOs os,
  SavedRdo entry,
  bool withSignature,
) async {
  if (withSignature) {
    final stored = entry.pdf;
    if (stored != null) {
      final storedBytes = FieldStore.instance.bytesFor(stored);
      if (storedBytes != null && storedBytes.isNotEmpty) {
        return DraftFile(
          name: stored.name,
          kind: OsFileKind.rdo,
          bytes: storedBytes,
        );
      }
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

String _sentLabel(OfficeSendKind kind, {bool attachmentsOnly = false}) {
  if (kind == OfficeSendKind.server) {
    return attachmentsOnly
        ? 'E-mail enviado com os anexos.'
        : 'E-mail enviado com o PDF do RDO.';
  }
  if (kind == OfficeSendKind.eml) {
    return attachmentsOnly
        ? 'Mensagem baixada. Abra o arquivo .eml no Outlook e clique em Enviar.'
        : 'Mensagem baixada com o PDF do RDO. Abra o arquivo .eml e clique em Enviar.';
  }
  if (kind == OfficeSendKind.mailto) {
    return attachmentsOnly
        ? 'E-mail aberto com destinatário e texto. Anexe os PDFs baixados e envie.'
        : 'E-mail aberto com destinatário, assunto e texto. Anexe o PDF baixado e envie.';
  }
  if (kind == OfficeSendKind.gmail) {
    return attachmentsOnly
        ? 'Gmail aberto com destinatário e texto. Anexe os arquivos baixados e envie.'
        : 'Gmail aberto com destinatário, assunto e texto. Anexe o PDF baixado e envie.';
  }
  if (kind == OfficeSendKind.shared) {
    return attachmentsOnly
        ? 'Confira Para, Assunto e texto no e-mail. Se estiverem vazios, copie da mensagem do app e anexe os arquivos.'
        : 'Confira Para, Assunto e texto no e-mail. Se estiverem vazios, preencha e anexe o PDF baixado.';
  }
  return 'Confira destinatário, assunto e anexos antes de enviar.';
}

Future<OfficeSendKind?> showPreparedMailDialog(
  BuildContext context,
  PreparedOfficeMail mail, {
  required String osId,
  required String osNumber,
  String replyTo = '',
  bool attachmentsOnly = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final desktop = prefersOfficeEmlDownload();
  final subjectController = TextEditingController(text: mail.subject);
  final bodyController = TextEditingController(text: mail.body);
  return showDialog<OfficeSendKind>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      var busy = false;
      var started = false;
      return StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            backgroundColor: GsTheme.paper,
            title: const Text(
              'Mensagem pronta',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: GsTheme.navy,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desktop
                          ? (attachmentsOnly
                                ? 'O app tenta enviar pela planilha com os anexos. Se não der, baixa uma mensagem .eml para abrir no Outlook.'
                                : 'O app tenta enviar pela planilha com o PDF do RDO anexo. Se não der, baixa uma mensagem .eml para abrir no Outlook.')
                          : (attachmentsOnly
                                ? 'O app tenta enviar pela planilha com os anexos. Se não der, baixa os arquivos e abre o e-mail para você anexar.'
                                : 'O app tenta enviar pela planilha com o PDF do RDO anexo. Se não der, baixa o PDF e abre o e-mail para você anexar.'),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5C6570),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MailDetail(label: 'Para', value: mail.to.join(', ')),
                    if (mail.cc.isNotEmpty)
                      _MailDetail(label: 'Cópia', value: mail.cc.join(', ')),
                    const SizedBox(height: 4),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Assunto',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyController,
                      minLines: 6,
                      maxLines: 14,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem',
                        alignLabelWithHint: true,
                        hintText: 'Edite o texto do e-mail antes de enviar',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MailDetail(
                      label: 'Anexos',
                      value: mail.files.map((file) => file.name).join('\n'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Agora não'),
              ),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        if (started) return;
                        started = true;
                        try {
                          final edited = PreparedOfficeMail(
                            to: mail.to,
                            cc: mail.cc,
                            subject: subjectController.text.trim().isEmpty
                                ? mail.subject
                                : subjectController.text.trim(),
                            body: bodyController.text,
                            files: mail.files,
                            attachmentPaths: mail.attachmentPaths,
                          );
                          final kind = await _deliverPreparedMail(
                            mail: edited,
                            osId: osId,
                            osNumber: osNumber,
                            replyTo: replyTo,
                            onBusy: () {
                              if (dialogContext.mounted) {
                                setDialog(() => busy = true);
                              }
                            },
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(kind);
                          }
                        } on MailShareCancelled {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (error) {
                          started = false;
                          setDialog(() => busy = false);
                          if (!dialogContext.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: GsTheme.navy,
                              content: Text('Não enviou o e-mail. $error'),
                            ),
                          );
                        }
                      },
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(desktop ? Icons.attach_file : Icons.send),
                style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                label: Text(
                  busy
                      ? (desktop ? 'Enviando…' : 'Abrindo…')
                      : 'Enviar',
                ),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    subjectController.dispose();
    bodyController.dispose();
  });
}

Future<OfficeSendKind> _deliverPreparedMail({
  required PreparedOfficeMail mail,
  required String osId,
  required String osNumber,
  required String replyTo,
  required VoidCallback onBusy,
}) async {
  onBusy();
  await Future<void>.delayed(const Duration(milliseconds: 16));

  // 1) Envio pela planilha com PDF anexo de verdade (MailApp).
  // Antes o celular abria Gmail/mailto sem anexo e o e-mail ia “vazio”.
  if (mail.files.isNotEmpty) {
    try {
      final result = await AccountApi.instance.sendOfficeMail(
        osId: osId,
        osNumber: osNumber,
        subject: mail.subject,
        body: mail.body,
        replyTo: replyTo,
        to: mail.to,
        cc: mail.cc,
        files: mail.files,
      );
      if (result.sent) return OfficeSendKind.server;
    } on MailShareCancelled {
      rethrow;
    } catch (_) {}
  }

  // 2) Sem arquivo: só abre o cliente de e-mail.
  if (mail.files.isEmpty) {
    await launchOfficeMailto(
      to: mail.to,
      cc: mail.cc,
      subject: mail.subject,
      body: mail.body,
    );
    return OfficeSendKind.mailto;
  }

  // 3) Fallback: .eml no PC, ou baixa o PDF + abre o compose no celular
  // (aí a pessoa ainda precisa anexar o arquivo baixado).
  try {
    final kind = await sendPreparedEmail(
      subject: mail.subject,
      body: mail.body,
      attachmentPaths: mail.attachmentPaths,
      files: mail.files,
      to: mail.to,
      cc: mail.cc,
    );
    if (kind != OfficeSendKind.needsServer) return kind;
  } on MailShareCancelled {
    rethrow;
  } catch (_) {}

  try {
    final quick = await tryImmediateClientMail(
      subject: mail.subject,
      body: mail.body,
      files: mail.files,
      to: mail.to,
      cc: mail.cc,
      attachmentPaths: mail.attachmentPaths,
    );
    if (quick != null) return quick;
  } on MailShareCancelled {
    rethrow;
  } catch (_) {}

  return openAttachedMailFallback(
    subject: mail.subject,
    body: mail.body,
    files: mail.files,
    to: mail.to,
    cc: mail.cc,
    attachmentPaths: mail.attachmentPaths,
  );
}

class _MailDetail extends StatelessWidget {
  const _MailDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2B3138)),
          ),
        ],
      ),
    );
  }
}

class MailAudiencePicker extends StatelessWidget {
  const MailAudiencePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.registeredClientEmail,
    this.clientEmail,
    this.clientEmailController,
    this.onClientEmailChanged,
  });

  final MailAudience value;
  final ValueChanged<MailAudience> onChanged;
  final String? registeredClientEmail;
  final String? clientEmail;
  final TextEditingController? clientEmailController;
  final ValueChanged<String>? onClientEmailChanged;

  String? get _registered {
    final typed = (registeredClientEmail ?? clientEmail ?? '').trim();
    return isMailAddress(typed) ? typed : null;
  }

  void _select(MailAudience audience) {
    final text = destinationEmailsFor(
      audience: audience,
      clientEmail: _registered,
    );
    final controller = clientEmailController;
    if (controller != null && controller.text != text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    onClientEmailChanged?.call(text);
    onChanged(audience);
  }

  @override
  Widget build(BuildContext context) {
    final hasClient = _registered != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enviar para',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: clientEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'E-mails',
            hintText: 'toque em Administrativos ou Cliente',
          ),
          onChanged: onClientEmailChanged,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Administrativos'),
              selected: value == MailAudience.office,
              onSelected: (_) => _select(MailAudience.office),
            ),
            ChoiceChip(
              label: const Text('Cliente'),
              selected: value == MailAudience.client,
              onSelected: hasClient
                  ? (_) => _select(MailAudience.client)
                  : null,
            ),
            ChoiceChip(
              label: const Text('Cliente e administrativos'),
              selected: value == MailAudience.both,
              onSelected: hasClient
                  ? (_) => _select(MailAudience.both)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hasClient
              ? (value == MailAudience.office
                    ? 'E-mails cadastrados como administrativos.'
                    : value == MailAudience.client
                    ? 'E-mail do cliente cadastrado nesta OS.'
                    : 'Cliente no destino e administrativos em cópia.')
              : 'Cadastre o e-mail da base na OS para enviar ao cliente. Administrativos já aparecem acima.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF5C6570)),
        ),
      ],
    );
  }
}
