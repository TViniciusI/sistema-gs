import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_store.dart';
import 'package:gs_mobile/data/rdo_share_io.dart'
    if (dart.library.js_interop) 'package:gs_mobile/data/rdo_share_web.dart'
    as platform;

Future<void> downloadRdoFile({
  required String fileName,
  required List<int> bytes,
}) {
  return platform.saveAndShareRdo(fileName: fileName, bytes: bytes);
}

/// Grava o arquivo neste computador, sem abrir o Compartilhar do Windows.
Future<String> saveLocalFile({
  required String fileName,
  required List<int> bytes,
  String subfolder = 'GS Campo',
}) {
  return platform.saveFileOnDevice(
    fileName: fileName,
    bytes: bytes,
    subfolder: subfolder,
  );
}

Future<void> shareOrDownloadRdoFile({
  required String fileName,
  required List<int> bytes,
}) {
  return platform.shareOrDownloadRdoFile(fileName: fileName, bytes: bytes);
}

Future<void> downloadSavedRdoEntry(SavedOs os, SavedRdo entry) async {
  final file = entry.pdf ?? os.rdoFile;
  if (file == null) {
    throw StateError('Este dia ainda não tem RDO em PDF');
  }
  final bytes =
      FieldStore.instance.bytesFor(file) ?? OfficeStore.instance.bytesFor(file);
  if (bytes == null) {
    throw StateError('Não foi possível abrir o arquivo do RDO');
  }
  await downloadRdoFile(fileName: file.name, bytes: bytes);
}

Future<void> downloadSavedRdo(SavedOs os) async {
  if (os.rdos.isNotEmpty) {
    await downloadSavedRdoEntry(os, os.rdos.first);
    return;
  }
  final file = os.rdoFile;
  if (file == null) {
    throw StateError('Esta OS ainda não tem RDO gerado');
  }
  final bytes =
      FieldStore.instance.bytesFor(file) ?? OfficeStore.instance.bytesFor(file);
  if (bytes == null) {
    throw StateError('Não foi possível abrir o arquivo do RDO');
  }
  await downloadRdoFile(fileName: file.name, bytes: bytes);
}
