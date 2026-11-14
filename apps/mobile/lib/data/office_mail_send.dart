import 'package:gs_mobile/data/office_mailto.dart';

bool prefersOfficeEmlDownload() => false;

Future<OfficeSendKind?> tryImmediateClientMail({
  required String subject,
  required String body,
  required List<OfficeMailFile> files,
  required List<String> to,
  required List<String> cc,
  List<String> attachmentPaths = const [],
}) async {
  return null;
}

Future<OfficeSendKind> sendPreparedEmail({
  required String subject,
  required String body,
  required List<String> attachmentPaths,
  List<OfficeMailFile> files = const [],
  List<String> to = officeEmails,
  List<String> cc = const [],
}) async {
  if (files.isNotEmpty || attachmentPaths.isNotEmpty) {
    return OfficeSendKind.needsServer;
  }
  await launchOfficeMailto(
    to: to.isEmpty ? officeEmails : to,
    cc: cc,
    subject: subject,
    body: body,
  );
  return OfficeSendKind.mailto;
}

Future<OfficeSendKind> openAttachedMailFallback({
  required String subject,
  required String body,
  required List<OfficeMailFile> files,
  required List<String> to,
  required List<String> cc,
  List<String> attachmentPaths = const [],
}) async {
  if (files.isEmpty && attachmentPaths.isEmpty) {
    await launchOfficeMailto(
      to: to.isEmpty ? officeEmails : to,
      cc: cc,
      subject: subject,
      body: body,
    );
    return OfficeSendKind.mailto;
  }
  throw Exception(
    'Este aparelho não montou o e-mail com o PDF anexo.',
  );
}
