import 'dart:js_interop';
import 'dart:typed_data';

import 'package:gs_mobile/data/office_eml.dart';
import 'package:gs_mobile/data/office_mailto.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

bool prefersOfficeEmlDownload() => !_isMobileBrowser();

bool _tooHeavyForScript(List<OfficeMailFile> files) {
  var total = 0;
  for (final file in files) {
    total += file.bytes.length;
    if (total > 800000) return true;
  }
  return false;
}

bool _isMobileBrowser() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  if (ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod') ||
      ua.contains('android') ||
      ua.contains('mobi')) {
    return true;
  }
  final platform = web.window.navigator.platform.toLowerCase();
  return platform.contains('mac') && web.window.navigator.maxTouchPoints > 1;
}

bool _prefersGmailCompose() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('android') || ua.contains('chrome');
}

Future<OfficeSendKind?> tryImmediateClientMail({
  required String subject,
  required String body,
  required List<OfficeMailFile> files,
  required List<String> to,
  required List<String> cc,
  List<String> attachmentPaths = const [],
}) async {
  if (!_isMobileBrowser() || files.isEmpty) return null;
  try {
    await _downloadMailFiles(files);
    return await _launchPrefilledCompose(
      to: to,
      cc: cc,
      subject: subject,
      body: body,
    );
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
  if (files.isNotEmpty &&
      prefersOfficeEmlDownload() &&
      _tooHeavyForScript(files)) {
    return openAttachedMailFallback(
      subject: subject,
      body: body,
      files: files,
      to: dest,
      cc: cc,
    );
  }
  if (files.isNotEmpty) {
    return OfficeSendKind.needsServer;
  }
  await launchOfficeMailto(
    to: dest,
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
  final dest = to.isEmpty ? officeEmails : to;
  if (_isMobileBrowser()) {
    await _downloadMailFiles(files);
    try {
      return await _launchPrefilledCompose(
        to: dest,
        cc: cc,
        subject: subject,
        body: body,
      );
    } catch (composeError) {
      try {
        await _shareMailFilesWeb(
          files: files,
          subject: subject,
          to: dest,
          cc: cc,
          body: body,
        );
        return OfficeSendKind.shared;
      } on MailShareCancelled {
        rethrow;
      } catch (_) {
        throw Exception(
          'Baixamos o PDF do RDO. Abra seu e-mail (Gmail ou Titan), '
          'preencha destinatário e texto, anexe o arquivo e envie. $composeError',
        );
      }
    }
  }
  final name = officeEmlFileName(subject);
  await downloadRdoFile(
    fileName: name,
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

Future<OfficeSendKind> _launchPrefilledCompose({
  required List<String> to,
  required List<String> cc,
  required String subject,
  required String body,
}) async {
  final dest = to.isEmpty ? officeEmails : to;
  try {
    await launchOfficeMailto(
      to: dest,
      cc: cc,
      subject: subject,
      body: body,
    );
    return OfficeSendKind.mailto;
  } catch (_) {}
  if (_prefersGmailCompose()) {
    await _launchGmailCompose(
      to: dest,
      cc: cc,
      subject: subject,
      body: body,
    );
    return OfficeSendKind.gmail;
  }
  throw Exception('Não foi possível abrir o aplicativo de e-mail');
}

Future<void> _downloadMailFiles(List<OfficeMailFile> files) async {
  for (final file in files) {
    if (file.bytes.isEmpty) continue;
    await downloadRdoFile(fileName: file.name, bytes: file.bytes);
  }
}

Future<void> _launchGmailCompose({
  required List<String> to,
  required List<String> cc,
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
    throw Exception('Não foi possível abrir o Gmail');
  }
}

Future<void> _shareMailFilesWeb({
  required List<OfficeMailFile> files,
  required String subject,
  required List<String> to,
  required List<String> cc,
  required String body,
}) async {
  final attached = [
    for (final file in files)
      if (file.bytes.isNotEmpty) file,
  ];
  if (attached.isEmpty) {
    throw StateError('Nenhum arquivo para compartilhar.');
  }
  final jsFiles = _toWebFiles(attached);
  final shareText = officeShareMailText(
    to: to,
    cc: cc,
    subject: subject,
    body: body,
  );
  if (await _tryWebShare(
    web.ShareData(
      title: subject,
      text: shareText,
      files: jsFiles.toJS,
    ),
  )) {
    return;
  }
  if (await _tryWebShare(
    web.ShareData(text: shareText, files: jsFiles.toJS),
  )) {
    return;
  }
  if (await _tryWebShare(
    web.ShareData(files: jsFiles.toJS),
  )) {
    return;
  }
  if (await _tryWebShare(
    web.ShareData(title: subject, files: jsFiles.toJS),
  )) {
    return;
  }
  if (attached.length > 1) {
    for (final file in attached) {
      final one = _toWebFiles([file]);
      if (await _tryWebShare(web.ShareData(files: one.toJS))) {
        return;
      }
    }
  }
  throw Exception('Compartilhamento indisponível neste navegador.');
}

List<web.File> _toWebFiles(List<OfficeMailFile> files) {
  return [
    for (final file in files)
      web.File(
        [Uint8List.fromList(file.bytes).toJS].toJS,
        file.name,
        web.FilePropertyBag(type: officeFileMime(file.name)),
      ),
  ];
}

Future<bool> _tryWebShare(web.ShareData data) async {
  final nav = web.window.navigator;
  try {
    if (!nav.canShare(data)) return false;
  } catch (_) {}
  try {
    await nav.share(data).toDart;
    return true;
  } catch (error) {
    if ('$error'.contains('AbortError')) {
      throw MailShareCancelled();
    }
    return false;
  }
}
