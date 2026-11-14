import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:gs_mobile/data/office_eml.dart';
import 'package:gs_mobile/data/office_mailto.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

bool prefersOfficeEmlDownload() => false;

Future<OfficeSendKind?> tryImmediateClientMail({
  required String subject,
  required String body,
  required List<OfficeMailFile> files,
  required List<String> to,
  required List<String> cc,
  List<String> attachmentPaths = const [],
}) async {
  if (files.isEmpty && attachmentPaths.isEmpty) return null;
  try {
    await _sendNativeEmail(
      to: to.isEmpty ? officeEmails : to,
      cc: cc,
      subject: subject,
      body: body,
      files: files,
      attachmentPaths: attachmentPaths,
    );
    return OfficeSendKind.shared;
  } on MailShareCancelled {
    rethrow;
  } catch (_) {
    return null;
  }
}

Future<OfficeSendKind> sendPreparedEmail({
  required String subject,
  required String body,
  required List<String> attachmentPaths,
  List<OfficeMailFile> files = const [],
  List<String> to = officeEmails,
  List<String> cc = const [],
}) async {
  final dest = to.isEmpty ? officeEmails : to;
  if (files.isEmpty && attachmentPaths.isEmpty) {
    await launchOfficeMailto(
      to: dest,
      cc: cc,
      subject: subject,
      body: body,
    );
    return OfficeSendKind.mailto;
  }
  try {
    await _sendNativeEmail(
      to: dest,
      cc: cc,
      subject: subject,
      body: body,
      files: files,
      attachmentPaths: attachmentPaths,
    );
    return OfficeSendKind.shared;
  } on MailShareCancelled {
    rethrow;
  } catch (_) {
    return OfficeSendKind.needsServer;
  }
}

Future<OfficeSendKind> openAttachedMailFallback({
  required String subject,
  required String body,
  required List<OfficeMailFile> files,
  required List<String> to,
  required List<String> cc,
  List<String> attachmentPaths = const [],
}) async {
  final dest = to.isEmpty ? officeEmails : to;
  try {
    await _sendNativeEmail(
      to: dest,
      cc: cc,
      subject: subject,
      body: body,
      files: files,
      attachmentPaths: attachmentPaths,
    );
    return OfficeSendKind.shared;
  } on MailShareCancelled {
    rethrow;
  } catch (_) {
    await _downloadMailFiles(files);
    try {
      await launchOfficeMailto(
        to: dest,
        cc: cc,
        subject: subject,
        body: body,
      );
      return OfficeSendKind.mailto;
    } catch (_) {}
    try {
      final paths = await _saveMailAttachmentPaths(
        files: files,
        attachmentPaths: attachmentPaths,
      );
      final result = await Share.shareXFiles(
        [
          for (final path in paths)
            XFile(path, mimeType: officeFileMime(_basename(path))),
        ],
        subject: subject,
        text: officeShareMailText(
          to: dest,
          cc: cc,
          subject: subject,
          body: body,
        ),
      );
      if (result.status == ShareResultStatus.dismissed) {
        throw MailShareCancelled();
      }
      return OfficeSendKind.shared;
    } on MailShareCancelled {
      rethrow;
    } catch (_) {
      await downloadRdoFile(
        fileName: officeEmlFileName(subject),
        bytes: buildOfficeEml(
          to: dest,
          cc: cc,
          subject: subject,
          body: body,
          files: files,
        ),
      );
      return OfficeSendKind.eml;
    }
  }
}

Future<void> _downloadMailFiles(List<OfficeMailFile> files) async {
  for (final file in files) {
    if (file.bytes.isEmpty) continue;
    await downloadRdoFile(fileName: file.name, bytes: file.bytes);
  }
}

Future<List<String>> _saveMailAttachmentPaths({
  required List<OfficeMailFile> files,
  required List<String> attachmentPaths,
}) async {
  final dir = await getTemporaryDirectory();
  final paths = <String>[
    for (final path in attachmentPaths)
      if (path.trim().isNotEmpty && File(path).existsSync()) path,
  ];
  for (final file in files) {
    if (file.bytes.isEmpty) continue;
    final name = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final saved = File('${dir.path}/$name');
    await saved.writeAsBytes(file.bytes, flush: true);
    paths.add(saved.path);
  }
  if (paths.isEmpty) {
    throw StateError('Nenhum arquivo para anexar.');
  }
  return paths;
}

String _basename(String path) {
  final parts = path.split(RegExp(r'[\\/]'));
  return parts.isEmpty ? path : parts.last;
}

Future<void> _sendNativeEmail({
  required List<String> to,
  required List<String> cc,
  required String subject,
  required String body,
  required List<OfficeMailFile> files,
  required List<String> attachmentPaths,
}) async {
  final paths = await _saveMailAttachmentPaths(
    files: files,
    attachmentPaths: attachmentPaths,
  );
  await FlutterEmailSender.send(
    Email(
      body: body,
      subject: subject,
      recipients: to,
      cc: cc,
      attachmentPaths: paths,
      isHTML: false,
    ),
  );
}
