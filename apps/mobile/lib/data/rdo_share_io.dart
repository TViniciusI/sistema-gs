import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/data/office_mailto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareRdo({
  required String fileName,
  required List<int> bytes,
}) async {
  final data = Uint8List.fromList(bytes);
  final folder = await getApplicationDocumentsDirectory();
  final downloads = Directory('${folder.path}/rdos');
  await downloads.create(recursive: true);
  final file = File('${downloads.path}/$fileName');
  await file.writeAsBytes(data, flush: true);
  await Share.shareXFiles([
    XFile(
      file.path,
      name: fileName,
      mimeType: officeFileMime(fileName),
    ),
  ]);
}

Future<void> shareOrDownloadRdoFile({
  required String fileName,
  required List<int> bytes,
}) async {
  await saveAndShareRdo(fileName: fileName, bytes: bytes);
}

Future<String> saveFileOnDevice({
  required String fileName,
  required List<int> bytes,
  String subfolder = 'GS Campo',
}) async {
  final data = Uint8List.fromList(bytes);
  final root = await _preferredSaveFolder();
  final folder = Directory(
    subfolder.trim().isEmpty ? root.path : '${root.path}/$subfolder',
  );
  await folder.create(recursive: true);
  final file = File('${folder.path}/$fileName');
  await file.writeAsBytes(data, flush: true);
  if (Platform.isWindows) {
    try {
      await Process.start('explorer.exe', ['/select,', file.path]);
    } catch (_) {}
  }
  return file.path;
}

Future<Directory> _preferredSaveFolder() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  } catch (_) {}
  return getApplicationDocumentsDirectory();
}
