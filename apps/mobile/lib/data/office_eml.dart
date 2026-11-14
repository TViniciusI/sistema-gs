import 'dart:convert';

import 'package:gs_mobile/data/office_mailto.dart';

const _boundary = '----=_GS_Campo_RDO';

List<int> buildOfficeEml({
  required List<String> to,
  List<String> cc = const [],
  required String subject,
  required String body,
  required List<OfficeMailFile> files,
}) {
  final dest = [
    for (final email in to)
      if (email.trim().contains('@')) email.trim(),
  ];
  final copy = [
    for (final email in cc)
      if (email.trim().contains('@')) email.trim(),
  ];
  final buffer = StringBuffer();
  _line(buffer, 'MIME-Version: 1.0');
  _line(buffer, 'X-Unsent: 1');
  if (dest.isNotEmpty) _line(buffer, 'To: ${dest.join(', ')}');
  if (copy.isNotEmpty) _line(buffer, 'Cc: ${copy.join(', ')}');
  _line(buffer, 'Subject: ${_rfc2047(subject)}');
  _line(buffer, 'Content-Type: multipart/mixed; boundary="$_boundary"');
  _line(buffer, '');
  _line(buffer, '--$_boundary');
  _line(buffer, 'Content-Type: text/plain; charset=UTF-8');
  _line(buffer, 'Content-Transfer-Encoding: base64');
  _line(buffer, '');
  _line(buffer, _foldBase64(base64.encode(utf8.encode(body))));
  for (final file in files) {
    if (file.bytes.isEmpty) continue;
    final name = _headerFileName(file.name);
    _line(buffer, '--$_boundary');
    _line(buffer, 'Content-Type: ${officeFileMime(file.name)}; name="$name"');
    _line(buffer, 'Content-Transfer-Encoding: base64');
    _line(
      buffer,
      'Content-Disposition: attachment; filename="$name"',
    );
    _line(buffer, '');
    _line(buffer, _foldBase64(base64.encode(file.bytes)));
  }
  _line(buffer, '--$_boundary--');
  return utf8.encode(buffer.toString());
}

String officeEmlFileName(String subject) {
  var safe = subject
      .replaceAll('/', '-')
      .replaceAll('\\', '-')
      .replaceAll('—', '-')
      .replaceAll(RegExp(r'[:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (safe.length > 72) safe = safe.substring(0, 72).trim();
  if (safe.isEmpty) safe = 'mensagem_GS_Campo';
  return '$safe.eml';
}

void _line(StringBuffer buffer, String value) {
  buffer.write(value);
  buffer.write('\r\n');
}

String _rfc2047(String text) {
  if (RegExp(r'^[\x20-\x7E]+$').hasMatch(text)) return text;
  return '=?UTF-8?B?${base64.encode(utf8.encode(text))}?=';
}

String _headerFileName(String name) {
  final safe = name.replaceAll('"', '').replaceAll('\r', '').replaceAll('\n', '');
  if (RegExp(r'^[\x20-\x7E]+$').hasMatch(safe)) return safe;
  return '=?UTF-8?B?${base64.encode(utf8.encode(safe))}?=';
}

String _foldBase64(String data) {
  if (data.isEmpty) return data;
  final out = StringBuffer();
  for (var i = 0; i < data.length; i += 76) {
    final end = i + 76 > data.length ? data.length : i + 76;
    if (i > 0) out.write('\r\n');
    out.write(data.substring(i, end));
  }
  return out.toString();
}
