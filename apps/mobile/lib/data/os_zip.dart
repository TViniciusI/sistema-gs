import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:intl/intl.dart';

/// Compacta arquivos em um ZIP (Deflate) para caber no e-mail / download.
Uint8List zipOsFiles(
  Iterable<({String name, List<int> bytes})> files, {
  String? folderInside,
}) {
  final archive = Archive();
  final used = <String>{};
  for (final file in files) {
    if (file.bytes.isEmpty) continue;
    final safe = _uniqueName(file.name, used);
    final path = folderInside == null || folderInside.trim().isEmpty
        ? safe
        : '${folderInside.trim().replaceAll(RegExp(r'[/\\]+'), '_')}/$safe';
    archive.addFile(ArchiveFile(path, file.bytes.length, file.bytes));
  }
  if (archive.isEmpty) {
    throw StateError('Nenhum arquivo para compactar.');
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String zipSelectionFileName(String osNumber) {
  final stamp = DateFormat('ddMMyy_HHmm').format(DateTime.now());
  final key = osNumber.trim().replaceAll('/', '-').replaceAll(RegExp(r'\s+'), '');
  return 'OS_${key}_selecao_$stamp.zip';
}

DraftFile zipAsDraft({
  required String osNumber,
  required Iterable<DraftFile> files,
}) {
  final packed = zipOsFiles([
    for (final file in files)
      if (file.bytes != null && file.bytes!.isNotEmpty)
        (name: file.name, bytes: file.bytes!),
  ]);
  return DraftFile(
    name: zipSelectionFileName(osNumber),
    kind: OsFileKind.certificate,
    bytes: packed,
  );
}

String _uniqueName(String raw, Set<String> used) {
  var name = raw.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (name.isEmpty) name = 'arquivo';
  if (used.add(name.toLowerCase())) return name;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var i = 2; i < 999; i++) {
    final candidate = '${stem}_$i$ext';
    if (used.add(candidate.toLowerCase())) return candidate;
  }
  return '${stem}_${used.length}$ext';
}
