import 'dart:io';
import 'dart:typed_data';

import 'package:gs_mobile/data/field_files_base.dart';
import 'package:path_provider/path_provider.dart';

export 'package:gs_mobile/data/field_files_base.dart';

class IoFieldFiles implements FieldFiles {
  @override
  Future<String> save({
    required String ownerEmail,
    required String osId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final safeOwner = ownerEmail.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final folder = Directory('${root.path}/gs_campo/$safeOwner/$osId');
    await folder.create(recursive: true);
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${folder.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<Uint8List?> read(String path) async {
    if (path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}

FieldFiles createFieldFiles() => IoFieldFiles();
