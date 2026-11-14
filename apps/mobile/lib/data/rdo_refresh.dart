import 'dart:async';

import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/rdo_pdf.dart';
import 'package:gs_mobile/demo/auth.dart';

Future<void> refreshClientSignedPdfs() async {
  for (final os in List<SavedOs>.from(FieldStore.instance.officeItems)) {
    for (final entry in os.rdos) {
      if (!entry.clientSigned) continue;
      final stamp =
          entry.clientSignedAt?.toIso8601String() ?? entry.clientSignedName;
      if (entry.clientStampOnPdf == stamp) continue;
      try {
        await rebuildRdoPdf(os, entry);
      } catch (_) {}
    }
  }
}

Future<List<int>> buildRdoPdfForEntry(
  SavedOs os,
  SavedRdo entry, {
  bool withSignature = true,
}) async {
  final lead = entry.responsibleName.trim().isNotEmpty
      ? entry.responsibleName.trim()
      : os.technicianName.split(',').first.trim();
  final team = presentTeamForRdo(os, entry, signedBy: lead);
  final cargos = snapshotTechnicianCargos(os, [lead, ...team]);
  return buildRdoPdf(
    osNumber: os.number,
    technicianName: uniquePersonNames([lead, ...team].join(', ')),
    rdo: os.rdo.copyWith(technicianCargos: cargos).mergedWithDay(entry),
    date: entry.date,
    signerName: os.rdo.baseName,
    responsibleName: lead,
    teamFuncoes: os.rdo.technicianFuncoes,
    teamCargos: cargos,
    signedAt: withSignature ? (entry.signedAt ?? entry.createdAt) : null,
    clientSignedAt: entry.clientSignedAt,
    withSignature: withSignature,
    photos: [
      for (final photo in entry.photos)
        if (FieldStore.instance.bytesFor(photo) case final bytes?
            when bytes.isNotEmpty)
          RdoPdfPhoto(
            label: (photo.label ?? '').trim().isEmpty ? photo.name : photo.label!,
            bytes: bytes,
          ),
    ],
  );
}

Future<void> rebuildRdoPdf(
  SavedOs os,
  SavedRdo entry, {
  bool withSignature = true,
}) async {
  final stamp =
      entry.clientSignedAt?.toIso8601String() ?? entry.clientSignedName;
  final pdfBytes = await buildRdoPdfForEntry(
    os,
    entry,
    withSignature: withSignature,
  );
  final files = [
    for (final file in entry.files)
      if (file.kind != OsFileKind.rdo) file,
  ];
  final next = entry.copyWith(
    files: [
      ...files,
      SavedFile(
        name: withSignature
            ? rdoFileName(os.number, entry.date)
            : rdoUnsignedFileName(os.number, entry.date),
        path: '',
        kind: OsFileKind.rdo,
        bytes: pdfBytes,
      ),
    ],
    clientStampOnPdf: stamp,
  );
  final updated = await FieldStore.instance.replaceRdoEntry(os, next);
  if (withSignature && next.clientSigned) {
    final entry =
        updated.rdos.where((item) => item.id == next.id).firstOrNull ?? next;
    unawaited(autoSaveRdoToDrive(updated, entry, withPhotos: false));
  }
}
