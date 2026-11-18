import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mailto.dart';
import 'package:gs_mobile/data/rdo_pdf.dart';
import 'package:gs_mobile/data/rdo_refresh.dart';
import 'package:gs_mobile/data/certificate_sign_dialog.dart';
import 'package:intl/intl.dart';

const _maxBatchBytes = 9 * 1024 * 1024;

/// Scripts antigos só gravam os 20 primeiros arquivos de cada envio.
const _maxBatchFiles = 15;

String osFolderName(String number) {
  return number.trim().replaceAll('/', '-').replaceAll(RegExp(r'[\\:*?"<>|]'), '-');
}

/// Confere se o script alcança a pasta das OS no Google Drive.
Future<bool> ensureDriveReady(BuildContext context) async {
  final status = await AccountApi.instance.driveStatus();
  if (status.connected) return true;
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: GsTheme.navy,
      content: Text(
        friendlySheetError(status.error) ??
            'A pasta das OS no Google Drive não respondeu. Tente de novo.',
      ),
    ),
  );
  return false;
}

Future<bool> _showDriveFailure(
  BuildContext context,
  AccountResult? last,
) async {
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: GsTheme.navy,
      content: Text(
        friendlySheetError(last?.error) ?? 'Não salvou no Google Drive.',
      ),
    ),
  );
  return false;
}

Future<void> archiveOsToDrive(
  BuildContext context,
  SavedOs os, {
  Iterable<String>? rdoIds,
  bool withSignature = true,
  bool includeOsAttachments = true,
}) async {
  try {
    if (!await ensureDriveReady(context)) return;
    if (!context.mounted) return;

    final selected = rdoIds?.toList() ?? [for (final entry in os.rdos) entry.id];
    if (selected.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text('Marque pelo menos um RDO para salvar.'),
        ),
      );
      return;
    }

    var current = FieldStore.instance.byId(os.id) ?? os;
    final chosen = [
      for (final entry in current.rdos)
        if (selected.contains(entry.id)) entry,
    ];
    if (withSignature && chosen.any((entry) => !entry.isSigned)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'Esse RDO ainda não tem assinatura. Salve sem assinatura ou assine antes.',
          ),
        ),
      );
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            withSignature
                ? 'Salvando RDO com assinatura no Google Drive…'
                : 'Salvando RDO no Google Drive…',
          ),
        ),
      );
    }

    final files = <Map<String, String>>[];
    for (final entry in chosen) {
      final draft = await _rdoDraft(current, entry, withSignature);
      files.add(_filePayload(draft.name, 'RDO', draft.bytes));
    }
    for (final entry in chosen) {
      for (final photo in entry.photos) {
        final bytes = FieldStore.instance.bytesFor(photo);
        if (bytes == null || bytes.isEmpty) continue;
        files.add(_filePayload(photo.name, 'Fotos', bytes));
      }
    }
    if (includeOsAttachments) {
      final seen = <String>{};
      for (final file in FieldStore.instance.viewerAttachments(current)) {
        if (!seen.add(file.name)) continue;
        final bytes = FieldStore.instance.bytesFor(file);
        if (bytes == null || bytes.isEmpty) continue;
        final folder = file.kind == OsFileKind.photo ? 'Fotos' : 'Anexos';
        files.add(_filePayload(file.name, folder, bytes));
      }
      if (!context.mounted) return;
      final ok = await _uploadDriveBatches(context, current, files);
      if (ok && seen.isNotEmpty) {
        await FieldStore.instance.removeOsAttachmentsByNames(current.id, seen);
      }
      return;
    }

    if (!context.mounted) return;
    await _uploadDriveBatches(context, current, files);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(
          friendlySheetError('$error') ?? 'Não salvou no Google Drive. $error',
        ),
      ),
    );
  }
}

/// Sobe anexos/fotos da OS (ou uma lista específica) para a pasta no Google Drive.
Future<void> archiveOsAttachmentsToDrive(
  BuildContext context,
  SavedOs os, {
  Iterable<SavedFile>? only,
  Iterable<DraftFile>? drafts,
  bool includeStoredAttachments = true,
}) async {
  try {
    if (!await ensureDriveReady(context)) return;
    if (!context.mounted) return;

    final current = FieldStore.instance.byId(os.id) ?? os;
    final files = <Map<String, String>>[];
    final seen = <String>{};

    void addBytes(String name, OsFileKind kind, List<int> bytes) {
      if (bytes.isEmpty || !seen.add(name)) return;
      final folder = kind == OsFileKind.photo ? 'Fotos' : 'Anexos';
      files.add(_filePayload(name, folder, bytes));
    }

    if (only != null) {
      for (final file in only) {
        final bytes = FieldStore.instance.bytesFor(file);
        if (bytes == null || bytes.isEmpty) continue;
        addBytes(file.name, file.kind, bytes);
      }
    } else {
      if (includeStoredAttachments) {
        for (final file in FieldStore.instance.viewerAttachments(current)) {
          final bytes = FieldStore.instance.bytesFor(file);
          if (bytes == null || bytes.isEmpty) continue;
          addBytes(file.name, file.kind, bytes);
        }
      }
      for (final draft in drafts ?? const <DraftFile>[]) {
        final bytes = draft.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        addBytes(draft.name, draft.kind, bytes);
      }
    }

    if (files.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            'Não há anexo neste aparelho para salvar. Anexe de novo e tente.',
          ),
        ),
      );
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text('Salvando anexos no Google Drive…'),
        ),
      );
    }

    final ok = await _uploadDriveBatches(context, current, files);
    if (ok) {
      await FieldStore.instance.removeOsAttachmentsByNames(current.id, seen);
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(
          friendlySheetError('$error') ?? 'Não salvou no Google Drive. $error',
        ),
      ),
    );
  }
}

Future<bool> _uploadDriveBatches(
  BuildContext context,
  SavedOs current,
  List<Map<String, String>> files, {
  String conflict = 'replace',
}) async {
  if (files.isEmpty) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text('Não há arquivos para salvar nesta OS.'),
      ),
    );
    return false;
  }

  AccountResult? last;
  final batches = _batches(files);
  for (var i = 0; i < batches.length; i++) {
    if (i > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    last = await AccountApi.instance.saveOsToDrive(
      osId: current.id,
      osNumber: current.number,
      files: batches[i],
      conflict: conflict,
    );
    if (last.sent != true && last.ok != true) {
      break;
    }
  }

  if (!context.mounted) return false;
  if (last == null || (last.sent != true && last.ok != true)) {
    return _showDriveFailure(context, last);
  }

  try {
    await FieldStore.instance.markEmailed(current.id);
  } catch (_) {}

  if (!context.mounted) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: GsTheme.navy,
      content: Text('OS ${current.number} salva no Google Drive.'),
    ),
  );
  return true;
}

Future<bool> uploadOsFilesToDrive(
  BuildContext context,
  SavedOs os, {
  required List<Map<String, String>> files,
  String conflict = 'replace',
}) async {
  final current = FieldStore.instance.byId(os.id) ?? os;
  return _uploadDriveBatches(
    context,
    current,
    files,
    conflict: conflict,
  );
}

String calibrationKindFolder(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      return 'Volumétrica';
    case CalibrationKind.pressure:
      return 'Pressão';
    case CalibrationKind.temperature:
    case CalibrationKind.temperatureMesh:
      return 'Temperatura';
    case CalibrationKind.density:
      return 'Densidade';
    case CalibrationKind.conductivity:
      return 'Condutividade';
    case CalibrationKind.telemetry:
      return 'Telemetria';
  }
}

const driveBookFolder = 'Certificados de Calibração/Book';
const driveLabelsFolder = 'Certificados de Calibração/Etiquetas';

/// Número da OS onde o certificado vai no Drive (cai no cliente se não houver OS).
String calibrationJobOsFolderKey(CalibrationJob job) {
  var osKey = job.osNumber.trim();
  if (osKey.isEmpty && job.osId.trim().isNotEmpty) {
    final linked = FieldStore.instance.byId(job.osId.trim());
    if (linked != null && linked.number.trim().isNotEmpty) {
      osKey = linked.number.trim();
    }
  }
  if (osKey.isEmpty && job.clientName.trim().isNotEmpty) {
    final clientNameNorm = job.clientName.trim().toLowerCase();
    final clientCnpjNorm = job.clientCnpj.replaceAll(RegExp(r'\D'), '');
    for (final o in FieldStore.instance.officeItems) {
      if (clientCnpjNorm.isNotEmpty && o.rdo.cnpj.replaceAll(RegExp(r'\D'), '') == clientCnpjNorm) {
        osKey = o.number.trim();
        break;
      }
      if (clientNameNorm.isNotEmpty && o.rdo.client.trim().toLowerCase() == clientNameNorm) {
        osKey = o.number.trim();
        break;
      }
    }
  }
  if (osKey.isEmpty) {
    final order = job.orderNumber.trim();
    final lower = order.toLowerCase();
    if (order.isNotEmpty && lower != 's/n' && lower != 'sn' && lower != 'n/a' && lower != 'na' && lower != '-') {
      osKey = order;
    }
  }
  if (osKey.isEmpty) {
    osKey = job.clientName.trim().isNotEmpty ? job.clientName.trim() : 'Certificados';
  }
  return osKey;
}

/// Grava um PDF já gerado (book, etiquetas) na pasta da OS no Google Drive.
/// Não mostra aviso: quem chama junta o resultado à mensagem dele.
Future<bool> saveGeneratedPdfToDrive({
  required String osId,
  required String osNumber,
  required String folder,
  required String fileName,
  required List<int> bytes,
}) {
  return saveGeneratedFilesToDrive(
    osId: osId,
    osNumber: osNumber,
    files: [(folder: folder, name: fileName, bytes: bytes)],
  );
}

Future<bool> saveGeneratedFilesToDrive({
  required String osId,
  required String osNumber,
  required List<({String folder, String name, List<int> bytes})> files,
}) async {
  final payload = [
    for (final file in files)
      if (file.bytes.isNotEmpty) _filePayload(file.name, file.folder, file.bytes),
  ];
  if (osNumber.trim().isEmpty || payload.isEmpty) return false;
  try {
    for (final batch in _batches(payload)) {
      final result = await AccountApi.instance.saveOsToDrive(
        osId: osId.trim().isEmpty ? osNumber.trim() : osId.trim(),
        osNumber: osNumber.trim(),
        files: batch,
      );
      if (result.ok != true && result.sent != true) return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Sobe sozinho o PDF do RDO assinado (e as fotos do dia) para a pasta da OS.
Future<bool> autoSaveRdoToDrive(
  SavedOs os,
  SavedRdo entry, {
  bool withPhotos = true,
}) async {
  if (!entry.isSigned) return false;
  final pdf = entry.pdf;
  final pdfBytes = pdf == null ? null : FieldStore.instance.bytesFor(pdf);
  final files = <({String folder, String name, List<int> bytes})>[
    if (pdf != null && pdfBytes != null && pdfBytes.isNotEmpty)
      (
        folder: 'RDO',
        name: pdf.name.trim().isEmpty
            ? rdoFileName(os.number, entry.date)
            : pdf.name,
        bytes: pdfBytes,
      ),
    if (withPhotos)
      for (final photo in entry.photos)
        if (FieldStore.instance.bytesFor(photo) case final bytes?
            when bytes.isNotEmpty)
          (folder: 'Fotos', name: photo.name, bytes: bytes),
  ];
  if (files.isEmpty) return false;
  return saveGeneratedFilesToDrive(
    osId: os.id,
    osNumber: os.number,
    files: files,
  );
}

String driveSavedSuffix(bool saved) => saved
    ? ' Cópia salva no Google Drive.'
    : ' Não salvou no Google Drive (fica só neste aparelho).';

Future<bool> archiveCalibrationJobsToDrive(
  BuildContext context,
  List<CalibrationJob> jobs, {
  String conflict = 'replace',
  bool? withSignature,
}) async {
  if (jobs.isEmpty) return false;
  try {
    if (!await ensureDriveReady(context)) return false;
    if (!context.mounted) return false;

    final signed = withSignature ??
        await askCertificateSignatureMode(
          context,
          title: 'Assinatura ao salvar no Drive',
        );
    if (signed == null) return false;
    if (!context.mounted) return false;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text(
            signed
                ? 'Gerando PDFs assinados e enviando ${jobs.length} certificado(s)…'
                : 'Gerando PDFs sem assinatura e enviando ${jobs.length} certificado(s)…',
          ),
        ),
      );
    }

    final byOs = <String, List<CalibrationJob>>{};
    for (final job in jobs) {
      byOs.putIfAbsent(calibrationJobOsFolderKey(job), () => []).add(job);
    }

    var totalSaved = 0;
    var totalErrors = 0;

    for (final entry in byOs.entries) {
      final osNumber = entry.key;
      final osJobs = entry.value;
      final files = <Map<String, String>>[];
      final builtJobs = <CalibrationJob>[];

      for (final job in osJobs) {
        try {
          final pdfBytes = await buildCalibrationCertificate(
            job,
            withSignature: signed,
          );
          final fileName = calibrationPdfFileName(job, withSignature: signed);
          final folderName = 'Certificados de Calibração/${calibrationKindFolder(job.kind)}';
          files.add(_filePayload(fileName, folderName, pdfBytes));
          files.add(
            _filePayload(
              '${job.number.trim().isEmpty ? job.id : job.number}_backup.json',
              'Certificados de Calibração/Backup',
              utf8.encode(const JsonEncoder.withIndent('  ').convert(job.toJson())),
            ),
          );
          builtJobs.add(job);
        } catch (e) {
          totalErrors++;
        }
      }

      if (files.isNotEmpty) {
        AccountResult? last;
        for (final batch in _batches(files)) {
          last = await AccountApi.instance.saveOsToDrive(
            osId: osJobs.first.osId.isNotEmpty ? osJobs.first.osId : osNumber,
            osNumber: osNumber,
            files: batch,
            conflict: conflict,
          );
          if (last.sent != true && last.ok != true) {
            break;
          }
        }
        if (last?.ok == true || last?.sent == true) {
          totalSaved += builtJobs.length;
          await _markCalibrationJobsDone(builtJobs);
        } else {
          totalErrors += builtJobs.length;
        }
      }
    }

    if (context.mounted) {
      if (totalErrors > 0 && totalSaved == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erro ao salvar certificados no Google Drive.'),
          ),
        );
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GsTheme.navy,
          content: Text('$totalSaved certificado(s) salvo(s) nas pastas da OS no Google Drive!'),
        ),
      );
    }
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(friendlySheetError('$error') ?? 'Não salvou no Google Drive. $error'),
      ),
    );
    return false;
  }
}

/// Certificado salvo no Google Drive conta como emitido (igual a "Gerar certificado").
Future<void> _markCalibrationJobsDone(List<CalibrationJob> jobs) async {
  for (final job in jobs) {
    final current = CalibrationStore.instance.byId(job.id) ?? job;
    if (current.status == CalibrationJobStatus.done) continue;
    if (!current.hasMeasurements) continue;
    try {
      await CalibrationStore.instance.save(
        current.copyWith(status: CalibrationJobStatus.done),
      );
    } catch (_) {}
  }
}

Map<String, String> _filePayload(String name, String folder, List<int> bytes) {
  return {
    'name': name,
    'folder': folder,
    'mime': officeFileMime(name),
    'data': base64Encode(bytes),
  };
}

List<List<Map<String, String>>> _batches(List<Map<String, String>> files) {
  final batches = <List<Map<String, String>>>[];
  var current = <Map<String, String>>[];
  var size = 0;
  for (final file in files) {
    final weight = file['data']?.length ?? 0;
    if (current.isNotEmpty &&
        (size + weight > _maxBatchBytes || current.length >= _maxBatchFiles)) {
      batches.add(current);
      current = [];
      size = 0;
    }
    current.add(file);
    size += weight;
  }
  if (current.isNotEmpty) batches.add(current);
  return batches;
}

Future<({String name, List<int> bytes})> _rdoDraft(
  SavedOs os,
  SavedRdo entry,
  bool withSignature,
) async {
  if (withSignature) {
    final stored = entry.pdf;
    if (stored != null) {
      final storedBytes = await FieldStore.instance.ensureBytes(stored);
      if (storedBytes != null && storedBytes.isNotEmpty) {
        return (name: stored.name, bytes: storedBytes);
      }
    }
  }
  final bytes = await buildRdoPdfForEntry(
    os,
    entry,
    withSignature: withSignature,
  );
  final name = withSignature
      ? rdoFileName(os.number, entry.date)
      : rdoUnsignedFileName(os.number, entry.date);
  return (name: name, bytes: bytes);
}

Future<void> showArchiveOsSheet(
  BuildContext context,
  SavedOs os, {
  Iterable<String>? rdoIds,
}) async {
  if (os.rdos.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text('Ainda não há RDO emitido nesta OS.'),
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GsTheme.paper,
    builder: (sheetContext) {
      return _ArchiveOsSheet(os: os, rdoIds: rdoIds, host: context);
    },
  );
}

class _ArchiveOsSheet extends StatefulWidget {
  const _ArchiveOsSheet({
    required this.os,
    required this.host,
    this.rdoIds,
  });

  final SavedOs os;
  final BuildContext host;
  final Iterable<String>? rdoIds;

  @override
  State<_ArchiveOsSheet> createState() => _ArchiveOsSheetState();
}

class _ArchiveOsSheetState extends State<_ArchiveOsSheet> {
  late final Set<String> _selected;

  SavedOs get _os => FieldStore.instance.byId(widget.os.id) ?? widget.os;

  @override
  void initState() {
    super.initState();
    final os = widget.os;
    _selected = {
      if (widget.rdoIds != null)
        ...widget.rdoIds!
      else
        for (final entry in os.rdos) entry.id,
    };
  }

  bool get _canSaveSigned {
    if (_selected.isEmpty) return false;
    return _os.rdos
        .where((entry) => _selected.contains(entry.id))
        .every((entry) => entry.isSigned);
  }

  Future<void> _save({required bool withSignature}) async {
    final host = widget.host;
    Navigator.of(context).pop();
    await archiveOsToDrive(
      host,
      _os,
      rdoIds: _selected,
      withSignature: withSignature,
    );
  }

  @override
  Widget build(BuildContext context) {
    final os = _os;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Salvar na pasta da OS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Grava RDO, fotos e anexos no Google Drive / ${osFolderName(os.number)}.',
                style: const TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 12),
              for (final entry in os.rdos)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(entry.id),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selected.add(entry.id);
                      } else {
                        _selected.remove(entry.id);
                      }
                    });
                  },
                  title: Text(
                    'RDO ${DateFormat('dd/MM/yyyy').format(entry.date)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GsTheme.navy,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (entry.responsibleName.trim().isNotEmpty)
                        entry.responsibleName.trim(),
                      if (entry.isSigned)
                        'Com assinatura eletrônica'
                      else
                        'Sem assinatura — salvar com assinatura bloqueado',
                    ].join(' · '),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _canSaveSigned
                    ? () => _save(withSignature: true)
                    : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                label: const Text('Salvar com assinatura'),
              ),
              if (!_canSaveSigned) ...[
                const SizedBox(height: 6),
                const Text(
                  'Assine o RDO para liberar o salvamento com assinatura.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => _save(withSignature: false),
                icon: const Icon(Icons.folder_outlined),
                label: const Text('Salvar sem assinatura'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
