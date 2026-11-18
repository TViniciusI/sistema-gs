import 'package:url_launcher/url_launcher.dart';

const officeEmail = 'administrativo@gssolucoestec.com.br';
const officeEmailAmanda = 'amanda@gssolucoestec.com.br';
const officeEmails = [officeEmail, officeEmailAmanda];
const officeEmailTo = '$officeEmail, $officeEmailAmanda';

class OfficeMailFile {
  const OfficeMailFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

enum OfficeSendKind { server, shared, gmail, mailto, eml, needsServer }

class MailShareCancelled implements Exception {}

/// E-mail utilizável: precisa de parte local e domínio com ponto.
/// Rejeita handles tipo `@willcardim` e logins sem domínio.
bool isMailAddress(String? raw) {
  final email = (raw ?? '').trim().toLowerCase();
  if (email.isEmpty) return false;
  final at = email.indexOf('@');
  if (at <= 0 || at != email.lastIndexOf('@')) return false;
  final local = email.substring(0, at);
  final domain = email.substring(at + 1);
  if (local.isEmpty || domain.isEmpty) return false;
  if (domain.startsWith('.') || domain.endsWith('.')) return false;
  if (!domain.contains('.')) return false;
  return !email.contains(' ');
}

String officeShareMailText({
  required List<String> to,
  required List<String> cc,
  required String subject,
  required String body,
}) {
  final buffer = StringBuffer()
    ..writeln('Para: ${to.join(', ')}');
  if (cc.isNotEmpty) {
    buffer.writeln('Cópia: ${cc.join(', ')}');
  }
  buffer
    ..writeln('Assunto: $subject')
    ..writeln()
    ..write(body);
  return buffer.toString().trim();
}

String officeFileMime(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.zip')) return 'application/zip';
  if (lower.endsWith('.eml')) return 'message/rfc822';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.xlsm')) {
    return 'application/vnd.ms-excel.sheet.macroEnabled.12';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.csv')) return 'text/csv';
  if (lower.endsWith('.json')) return 'application/json';
  return 'application/octet-stream';
}

List<String> _mailAddresses(Iterable<String> emails) {
  return [
    for (final email in emails)
      if (isMailAddress(email)) email.trim(),
  ];
}

String _clipMailBody(String body, int max) {
  final compact = body.trim();
  if (compact.length <= max) return compact;
  return '${compact.substring(0, max)}\n…';
}

String _mailtoQuery(Map<String, String> params) {
  return [
    for (final entry in params.entries)
      if (entry.value.isNotEmpty)
        '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
  ].join('&');
}

Uri officeMailtoUri({
  required List<String> to,
  List<String> cc = const [],
  required String subject,
  required String body,
}) {
  final dest = _mailAddresses(to);
  final copy = _mailAddresses(cc);
  if (dest.isEmpty) dest.addAll(officeEmails);
  return Uri(
    scheme: 'mailto',
    path: dest.join(','),
    query: _mailtoQuery({
      if (copy.isNotEmpty) 'cc': copy.join(','),
      'subject': subject,
      'body': _clipMailBody(body, 4000),
    }),
  );
}

Uri gmailComposeUri({
  required List<String> to,
  List<String> cc = const [],
  required String subject,
  required String body,
}) {
  return Uri.https('mail.google.com', '/mail/u/0/', {
    'view': 'cm',
    'fs': '1',
    'to': to.join(','),
    if (cc.isNotEmpty) 'cc': cc.join(','),
    'su': subject,
    'body': _clipMailBody(body, 1600),
  });
}

Future<void> launchGmailCompose({
  required List<String> to,
  List<String> cc = const [],
  required String subject,
  required String body,
}) async {
  final uri = gmailComposeUri(
    to: to,
    cc: cc,
    subject: subject,
    body: body,
  );
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!ok) {
    await launchOfficeMailto(
      to: to,
      cc: cc,
      subject: subject,
      body: body,
    );
  }
}

Future<void> launchOfficeMailto({
  required String subject,
  required String body,
  List<String> to = officeEmails,
  List<String> cc = const [],
}) async {
  final uri = officeMailtoUri(
    to: to,
    cc: cc,
    subject: subject,
    body: body,
  );
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!ok) {
    throw Exception('Não foi possível abrir o aplicativo de e-mail');
  }
}
