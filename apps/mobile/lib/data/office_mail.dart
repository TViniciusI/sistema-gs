import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mail_send.dart'
    if (dart.library.io) 'package:gs_mobile/data/office_mail_io.dart'
    if (dart.library.js_interop) 'package:gs_mobile/data/office_mail_web.dart';
import 'package:gs_mobile/data/office_mailto.dart';
import 'package:gs_mobile/data/office_recipients.dart';
import 'package:gs_mobile/data/rdo_pdf.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:intl/intl.dart';

export 'package:gs_mobile/data/office_eml.dart'
    show buildOfficeEml, officeEmlFileName;
export 'package:gs_mobile/data/office_mail_send.dart'
    if (dart.library.io) 'package:gs_mobile/data/office_mail_io.dart'
    if (dart.library.js_interop) 'package:gs_mobile/data/office_mail_web.dart';
export 'package:gs_mobile/data/office_mailto.dart'
    show
        officeEmail,
        officeEmailAmanda,
        officeEmails,
        officeEmailTo,
        OfficeMailFile,
        OfficeSendKind,
        MailShareCancelled,
        isMailAddress,
        officeFileMime,
        gmailComposeUri,
        officeMailtoUri,
        launchGmailCompose,
        launchOfficeMailto;

export 'package:gs_mobile/data/office_recipients.dart'
    show officeRecipientEmails, officeRecipientTo;

enum MailAudience { office, client, both }

List<String> parseRecipientEmails(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  final emails = <String>{};
  for (final part in raw.split(RegExp(r'[;,\s]+'))) {
    final email = part.trim().toLowerCase();
    if (isMailAddress(email)) emails.add(email);
  }
  return emails.toList();
}

String destinationEmailsFor({
  required MailAudience audience,
  String? clientEmail,
}) {
  final office = officeRecipientTo();
  final client = (clientEmail ?? '').trim();
  final hasClient = isMailAddress(client);
  switch (audience) {
    case MailAudience.office:
      return office;
    case MailAudience.client:
      return hasClient ? client : '';
    case MailAudience.both:
      if (hasClient && office.isNotEmpty) return '$client, $office';
      if (hasClient) return client;
      return office;
  }
}

String? _resolvedTechnicianEmail(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return null;
  if (isMailAddress(value)) return value;
  // Handle tipo "@willcardim" ou só o login: resolve pelo cadastro.
  final login = value.startsWith('@') ? value.substring(1).trim() : value;
  if (login.isEmpty) return null;
  final matched = matchUser(login);
  final mail = matched?.email.trim().toLowerCase() ?? '';
  return isMailAddress(mail) ? mail : null;
}

/// E-mails dos técnicos delegados nesta OS (para copiar e colar no envio).
List<String> technicianEmailsForOs(SavedOs os) {
  final emails = <String>{};
  for (final raw in os.assigneeEmails) {
    final mail = _resolvedTechnicianEmail(raw);
    if (mail != null) emails.add(mail);
  }
  for (final user in StaffStore.instance.technicianAccounts) {
    final mail = user.email.trim().toLowerCase();
    if (!isMailAddress(mail)) continue;
    if (!os.isAssignedToAny(
      assignmentIdsFor(
        email: user.email,
        login: user.login,
        aliases: [user.name],
      ),
    )) {
      continue;
    }
    emails.add(mail);
  }
  for (final known in fieldTechnicians) {
    final mail = known.email.trim().toLowerCase();
    if (!isMailAddress(mail)) continue;
    if (!os.isAssignedToAny(assigneeKeysFor(known))) continue;
    emails.add(mail);
  }
  final list = emails.toList()..sort();
  return list;
}

String technicianEmailsLineForOs(SavedOs os) =>
    technicianEmailsForOs(os).join(', ');

String officeEmailSubject(
  String osNumber, {
  bool withSignature = true,
  bool attachmentsOnly = false,
}) {
  if (attachmentsOnly) {
    return 'Anexos da Ordem de Serviço $osNumber — GS Soluções Técnicas';
  }
  return 'RDO da Ordem de Serviço $osNumber — GS Soluções Técnicas';
}

String officeEmailBody({
  required SavedOs os,
  required String technicianName,
  bool withSignature = true,
  bool attachmentsOnly = false,
  Iterable<String>? rdoIds,
}) {
  final selected = rdoIds == null
      ? os.rdos
      : [
          for (final entry in os.rdos)
            if (rdoIds.contains(entry.id)) entry,
        ];
  final rdo = os.rdo;
  final sender = technicianName.trim().isEmpty
      ? 'Equipe GS'
      : technicianName.trim();
  final client = rdo.client.trim().isEmpty
      ? 'não informado'
      : rdo.client.trim();
  final baseName = rdo.baseName.trim().isEmpty
      ? (os.signerName?.trim().isNotEmpty == true
            ? os.signerName!.trim()
            : 'não informado')
      : rdo.baseName.trim();
  final baseEmail = rdo.baseEmail.trim().isEmpty
      ? 'não informado'
      : rdo.baseEmail.trim();
  final basePhone = rdo.basePhone.trim().isEmpty
      ? 'não informado'
      : rdo.basePhone.trim();

  if (attachmentsOnly) {
    final docs = [
      for (final file in os.attachments) file.name,
    ];
    return '''Prezados,

Encaminho, para conhecimento e registro interno da equipe GS, os anexos da Ordem de Serviço nº ${os.number}.
Estes arquivos são de uso interno e não substituem o envio do RDO ao cliente.

Informações da execução:
Técnico responsável: $sender
Contratante: $client
Ordem de Serviço: ${os.number}

Documentos anexos:
${_joinDocumentLines(docs)}

Fico à disposição para quaisquer esclarecimentos ou informações adicionais que sejam necessárias.

Atenciosamente,
$sender
GS Soluções Técnicas
''';
  }

  final many = selected.length != 1;
  final rdoLabel = many
      ? 'os Relatórios Diários de Obra (RDOs)'
      : 'o Relatório Diário de Obra (RDO)';
  final correspond = many
      ? 'Os documentos correspondem'
      : 'O documento corresponde';
  final signBlock = withSignature
      ? 'Informo que ${many ? 'os RDOs seguem' : 'o RDO segue'} com assinatura eletrônica do técnico responsável neste envio.'
      : '''Informo que ${many ? 'os RDOs seguem' : 'o RDO segue'} sem assinatura eletrônica neste envio.
Quando aplicável, os respectivos certificados e documentos com assinatura ICP-Brasil serão encaminhados separadamente pelo Adobe, conforme o procedimento adotado.''';
  final docs = [
    for (final entry in selected)
      '${entry.pdf?.name ?? (withSignature ? rdoFileName(os.number, entry.date) : rdoUnsignedFileName(os.number, entry.date))} - referente às atividades de ${DateFormat('dd/MM/yyyy').format(entry.date)}',
  ];
  final clientClause = rdo.client.trim().isEmpty
      ? ''
      : ', tendo como contratante a $client';

  return '''Prezados,

Encaminho, para conhecimento e registro, $rdoLabel referente${many ? 's' : ''} à Ordem de Serviço nº ${os.number}, executada pela GS Soluções Técnicas.

$correspond às atividades realizadas ${_activityDaysPhrase(selected)}$clientClause.

Informações da execução:
Técnico responsável: $sender
Responsável pela base: $baseName
E-mail da base: $baseEmail
Telefone: $basePhone
Contratante: $client
Ordem de Serviço: ${os.number}

$signBlock

Documentos anexos:
${_joinDocumentLines(docs)}

Fico à disposição para quaisquer esclarecimentos ou informações adicionais que sejam necessárias.

Atenciosamente,
$sender
GS Soluções Técnicas
''';
}

String _activityDaysPhrase(List<SavedRdo> selected) {
  final fmt = DateFormat('dd/MM/yyyy');
  final days = [
    for (final entry in selected) fmt.format(entry.date),
  ];
  if (days.isEmpty) return 'na presente data';
  if (days.length == 1) return 'no dia ${days.first}';
  if (days.length == 2) return 'nos dias ${days[0]} e ${days[1]}';
  return 'nos dias ${days.sublist(0, days.length - 1).join(', ')} e ${days.last}';
}

String _joinDocumentLines(List<String> lines) {
  if (lines.isEmpty) return 'Nenhum documento anexo neste envio.';
  if (lines.length == 1) return '${lines.first}.';
  final out = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    out.writeln(
      i == lines.length - 1 ? '${lines[i]}.' : '${lines[i]};',
    );
  }
  return out.toString().trimRight();
}

List<String> officeMailAttachmentPaths(
  SavedOs os, {
  Iterable<String>? rdoIds,
  bool includeRdo = true,
  bool includeAttachments = true,
}) {
  return [
    for (final file in os.mailFilesFor(
      rdoIds: rdoIds,
      includeRdo: includeRdo,
      includeAttachments: includeAttachments,
    ))
      if (file.path.isNotEmpty && !file.path.startsWith('web/')) file.path,
  ];
}

List<String> mergeMailRecipients(Iterable<String> extraTo) {
  final emails = <String>{
    for (final email in officeRecipientEmails()) email.trim().toLowerCase(),
  };
  for (final raw in extraTo) {
    final email = raw.trim().toLowerCase();
    if (isMailAddress(email)) emails.add(email);
  }
  emails.removeWhere((email) => !isMailAddress(email));
  return emails.toList();
}

String? clientRdoEmail(SavedOs os) {
  final email = os.rdo.baseEmail.trim().toLowerCase();
  if (isMailAddress(email)) return email;
  return null;
}

/// Destinatários incluem o cliente (e-mail da base ou outro fora do escritório/técnicos).
bool mailRecipientsIncludeClient(SavedOs os, List<String> recipients) {
  if (recipients.isEmpty) return false;
  final client = clientRdoEmail(os);
  if (client != null && recipients.contains(client)) return true;
  final office = officeRecipientEmails().toSet();
  final tech = technicianEmailsForOs(os).toSet();
  return recipients.any(
    (email) => !office.contains(email) && !tech.contains(email),
  );
}

class PreparedOfficeMail {
  const PreparedOfficeMail({
    required this.to,
    required this.cc,
    required this.subject,
    required this.body,
    required this.files,
    required this.attachmentPaths,
  });

  final List<String> to;
  final List<String> cc;
  final String subject;
  final String body;
  final List<OfficeMailFile> files;
  final List<String> attachmentPaths;
}

PreparedOfficeMail prepareOsMail({
  required SavedOs os,
  required String technicianName,
  List<DraftFile> extra = const [],
  Iterable<String>? rdoIds,
  List<String> extraTo = const [],
  List<String> recipients = const [],
  bool includeStoredRdo = true,
  bool includeAttachments = false,
  bool withSignature = true,
  bool attachmentsOnly = false,
  MailAudience audience = MailAudience.both,
}) {
  final files = _fitMailFiles([
    for (final file in os.mailFilesFor(
      rdoIds: rdoIds,
      includeRdo: includeStoredRdo,
      includeAttachments: includeAttachments,
    ))
      if (_mailBytes(file) case final bytes?)
        OfficeMailFile(name: file.name, bytes: bytes),
    for (final file in extra)
      if (file.bytes != null && file.bytes!.isNotEmpty)
        OfficeMailFile(name: file.name, bytes: file.bytes!),
  ]);
  if (files.isEmpty) {
    throw StateError(
      'Os arquivos não estão neste navegador. Envie do aparelho que gerou o RDO.',
    );
  }
  final office = officeRecipientEmails();
  final listed = parseRecipientEmails(
    (recipients.isNotEmpty ? recipients : extraTo).join(', '),
  );
  final routed = _routeMailRecipients(
    audience: audience,
    listed: listed,
    extraTo: extraTo,
    office: office,
  );
  return PreparedOfficeMail(
    to: routed.to,
    cc: routed.cc,
    subject: officeEmailSubject(
      os.number,
      withSignature: withSignature,
      attachmentsOnly: attachmentsOnly,
    ),
    body: officeEmailBody(
      os: os,
      technicianName: technicianName,
      withSignature: withSignature,
      attachmentsOnly: attachmentsOnly,
      rdoIds: rdoIds,
    ),
    files: files,
    attachmentPaths: officeMailAttachmentPaths(
      os,
      rdoIds: rdoIds,
      includeRdo: includeStoredRdo,
      includeAttachments: includeAttachments,
    ),
  );
}

Future<OfficeSendKind> sendOsToOffice({
  required SavedOs os,
  required String technicianName,
  String replyTo = '',
  List<DraftFile> extra = const [],
  Iterable<String>? rdoIds,
  List<String> extraTo = const [],
  bool includeStoredRdo = true,
  bool includeAttachments = false,
  bool withSignature = true,
  bool attachmentsOnly = false,
  MailAudience audience = MailAudience.both,
}) async {
  final mail = prepareOsMail(
    os: os,
    technicianName: technicianName,
    extra: extra,
    rdoIds: rdoIds,
    extraTo: extraTo,
    includeStoredRdo: includeStoredRdo,
    includeAttachments: includeAttachments,
    withSignature: withSignature,
    attachmentsOnly: attachmentsOnly,
    audience: audience,
  );
  return sendPreparedEmail(
    subject: mail.subject,
    body: mail.body,
    attachmentPaths: mail.attachmentPaths,
    files: mail.files,
    to: mail.to,
    cc: mail.cc,
  );
}

({List<String> to, List<String> cc}) _routeMailRecipients({
  required MailAudience audience,
  required List<String> listed,
  required List<String> extraTo,
  required List<String> office,
}) {
  final officeSet = {
    for (final email in office) email.trim().toLowerCase(),
  }..removeWhere((email) => email.isEmpty);
  final parsedExtra = [
    for (final email in extraTo)
      if (isMailAddress(email)) email.trim().toLowerCase(),
  ];
  switch (audience) {
    case MailAudience.office:
      return (to: listed.isNotEmpty ? listed : office, cc: const <String>[]);
    case MailAudience.client:
      final clients = [
        for (final email in listed)
          if (!officeSet.contains(email)) email,
      ];
      final to = clients.isNotEmpty
          ? clients
          : (listed.isNotEmpty
                ? listed
                : parsedExtra);
      return (
        to: to.isNotEmpty ? to : office,
        cc: const <String>[],
      );
    case MailAudience.both:
      final clients = [
        for (final email in listed)
          if (!officeSet.contains(email)) email,
      ];
      final admins = [
        for (final email in listed)
          if (officeSet.contains(email)) email,
      ];
      final clientTo = clients.isNotEmpty ? clients : parsedExtra;
      final adminCc = admins.isNotEmpty ? admins : office;
      if (clientTo.isEmpty) {
        return (to: adminCc, cc: const <String>[]);
      }
      return (
        to: clientTo,
        cc: [
          for (final email in adminCc)
            if (!clientTo.contains(email)) email,
        ],
      );
  }
}

List<OfficeMailFile> _fitMailFiles(List<OfficeMailFile> files) {
  const maxBytes = 9 * 1024 * 1024;
  var total = 0;
  final out = <OfficeMailFile>[];
  for (final file in files) {
    if (file.bytes.isEmpty) continue;
    if (total + file.bytes.length > maxBytes) continue;
    total += file.bytes.length;
    out.add(file);
  }
  return out;
}

List<int>? _mailBytes(SavedFile file) {
  final bytes = FieldStore.instance.bytesFor(file);
  if (bytes == null || bytes.isEmpty) return null;
  return bytes;
}
