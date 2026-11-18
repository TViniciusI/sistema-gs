import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_store.dart';
import 'package:gs_mobile/data/os_zip.dart';
import 'package:gs_mobile/data/rdo_pdf.dart';
import 'package:gs_mobile/data/rdo_refresh.dart';
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

Future<({String name, List<int> bytes})> rdoEntryDownloadBytes(
  SavedOs os,
  SavedRdo entry, {
  bool withSignature = true,
}) async {
  final signed = withSignature && entry.isSigned;
  final stored = signed ? entry.pdf : null;
  if (stored != null) {
    final local =
        await FieldStore.instance.ensureBytes(stored) ??
        OfficeStore.instance.bytesFor(stored);
    if (local != null && local.isNotEmpty) {
      return (name: stored.name, bytes: local);
    }
  }
  final bytes = await buildRdoPdfForEntry(
    os,
    entry,
    withSignature: signed,
  );
  final name = signed
      ? rdoFileName(os.number, entry.date)
      : rdoUnsignedFileName(os.number, entry.date);
  return (name: name, bytes: bytes);
}

Future<void> downloadSavedRdoEntry(SavedOs os, SavedRdo entry) async {
  final packed = await rdoEntryDownloadBytes(os, entry);
  await downloadRdoFile(fileName: packed.name, bytes: packed.bytes);
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
      await FieldStore.instance.ensureBytes(file) ??
      OfficeStore.instance.bytesFor(file);
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Não foi possível abrir o arquivo do RDO');
  }
  await downloadRdoFile(fileName: file.name, bytes: bytes);
}

/// Baixa vários RDOs/anexos de uma vez (ZIP se houver mais de um).
Future<void> downloadOsSelection({
  required SavedOs os,
  required Set<String> rdoIds,
  required Set<String> attachmentNames,
  Iterable<DraftFile> drafts = const [],
  bool asZip = true,
}) async {
  final current = FieldStore.instance.byId(os.id) ?? os;
  final files = <({String name, List<int> bytes})>[];
  final seen = <String>{};

  for (final entry in current.rdos) {
    if (!rdoIds.contains(entry.id)) continue;
    final packed = await rdoEntryDownloadBytes(current, entry);
    if (!seen.add(packed.name.toLowerCase())) continue;
    files.add(packed);
  }

  for (final file in current.attachments) {
    if (!attachmentNames.contains(file.name)) continue;
    if (!seen.add(file.name.toLowerCase())) continue;
    final bytes = await FieldStore.instance.ensureBytes(file);
    if (bytes == null || bytes.isEmpty) continue;
    files.add((name: file.name, bytes: bytes));
  }

  for (final draft in drafts) {
    if (!attachmentNames.contains(draft.name)) continue;
    if (!seen.add(draft.name.toLowerCase())) continue;
    final bytes = draft.bytes;
    if (bytes == null || bytes.isEmpty) continue;
    files.add((name: draft.name, bytes: bytes));
  }

  if (files.isEmpty) {
    throw StateError(
      'Nada para baixar. Marque RDOs/anexos ou gere o PDF de novo.',
    );
  }

  if (!asZip || files.length == 1) {
    for (final file in files) {
      await downloadRdoFile(fileName: file.name, bytes: file.bytes);
    }
    return;
  }

  final zipBytes = zipOsFiles(files, folderInside: 'OS_${current.number}');
  await downloadRdoFile(
    fileName: zipSelectionFileName(current.number),
    bytes: zipBytes,
  );
}
