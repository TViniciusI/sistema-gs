import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> saveAndShareRdo({
  required String fileName,
  required List<int> bytes,
}) async {
  await _downloadInBrowser(fileName: fileName, bytes: bytes);
}

Future<void> shareOrDownloadRdoFile({
  required String fileName,
  required List<int> bytes,
}) async {
  final data = Uint8List.fromList(bytes);
  final mime = _mimeFor(fileName);
  final file = web.File(
    [data.toJS].toJS,
    fileName,
    web.FilePropertyBag(type: mime),
  );
  final nav = web.window.navigator;
  try {
    final shareData = web.ShareData(
      title: fileName,
      files: [file].toJS,
    );
    if (nav.canShare(shareData)) {
      await nav.share(shareData).toDart;
      return;
    }
  } catch (_) {}
  await _downloadInBrowser(fileName: fileName, bytes: bytes);
}

Future<String> saveFileOnDevice({
  required String fileName,
  required List<int> bytes,
  String subfolder = 'GS Campo',
}) async {
  await _downloadInBrowser(fileName: fileName, bytes: bytes);
  return fileName;
}

Future<void> _downloadInBrowser({
  required String fileName,
  required List<int> bytes,
}) async {
  final data = Uint8List.fromList(bytes);
  final mime = _mimeFor(fileName);
  final blob = web.Blob(
    [data.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

String _mimeFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.eml')) return 'message/rfc822';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.xlsm')) {
    return 'application/vnd.ms-excel.sheet.macroEnabled.12';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.csv')) return 'text/csv';
  return 'application/octet-stream';
}
