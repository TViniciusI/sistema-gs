import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gs_mobile/core/app_date_picker.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_bundle_pdf.dart';
import 'package:gs_mobile/data/calibration_label_pdf.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/certificate_sign_dialog.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/drive_archive.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/office_mail.dart';
import 'package:gs_mobile/data/rdo_refresh.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/data/week_agenda.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/calibration/calibration_from_os_page.dart';
import 'package:gs_mobile/features/os/attachment_rename.dart';
import 'package:gs_mobile/features/os/calibration_label_pick_dialog.dart';
import 'package:gs_mobile/features/os/calibration_label_size_dialog.dart';
import 'package:gs_mobile/features/os/calibration_slots_group.dart';
import 'package:gs_mobile/features/os/certificate_book_pick_dialog.dart';
import 'package:gs_mobile/features/os/os_create_page.dart';
import 'package:gs_mobile/features/os/os_delete_actions.dart';
import 'package:gs_mobile/features/os/os_share_actions.dart';
import 'package:gs_mobile/features/os/rdo_form_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class OsHubPage extends StatefulWidget {
  const OsHubPage({super.key, required this.osId, this.officeMode = false});

  final String osId;
  final bool officeMode;

  @override
  State<OsHubPage> createState() => _OsHubPageState();
}

class _OsHubPageState extends State<OsHubPage> {
  final _picker = ImagePicker();
  final _selectedRdoIds = <String>{};
  final _selectedAttachments = <String>{};
  final _ephemeral = <DraftFile>[];
  late final TextEditingController _techEmails;
  var _busy = false;
  var _compressZip = true;
  String? _editLockWarning;
  String? _slotMismatchWarning;
  Timer? _lockHeartbeat;

  @override
  void initState() {
    super.initState();
    _techEmails = TextEditingController();
    FieldStore.instance.sync().then((_) async {
      refreshClientSignedPdfs();
      await FieldStore.instance.hydrateOs(widget.osId);
      final hydrated = FieldStore.instance.byId(widget.osId);
      if (hydrated != null) {
        await FieldStore.instance.hydrateOsFiles(hydrated);
      }
      // sync() da OS marca tudo como fresco; load() aqui pulava a nuvem.
      await CalibrationStore.instance.sync();
      await FieldStore.instance.refreshCalibrationSlotsForOs(
        widget.osId,
        jobs: CalibrationStore.instance.items,
      );
      await _detachForeignCertificateNumbers();
      await _applyIntegrityGuards();
      final os = _os;
      if (os != null && mounted) {
        _techEmails.text = destinationEmailsFor(audience: MailAudience.office);
        setState(() {});
      }
    });
  }

  Future<void> _applyIntegrityGuards() async {
    final os = _os;
    if (os == null || !mounted) return;
    final email = AuthSession.instance.user?.email ?? '';
    final mismatches = FieldStore.instance.calibrationSlotMismatches(
      os,
      CalibrationStore.instance.items,
    );
    String? lockWarn;
    if (os.calibrationEditHeldByOther(email)) {
      lockWarn =
          'Atenção: ${os.calibrationEditBy} está com esta OS aberta '
          'para calibração. Evite editar os mesmos certificados ao mesmo tempo.';
    } else if (email.trim().isNotEmpty) {
      await FieldStore.instance.claimCalibrationEdit(
        osId: widget.osId,
        email: email,
      );
      _lockHeartbeat?.cancel();
      _lockHeartbeat = Timer.periodic(const Duration(minutes: 12), (_) {
        FieldStore.instance.claimCalibrationEdit(
          osId: widget.osId,
          email: email,
        );
      });
    }
    if (!mounted) return;
    setState(() {
      _editLockWarning = lockWarn;
      _slotMismatchWarning = mismatches.isEmpty
          ? null
          : 'Nuvem e aparelho divergem em ${mismatches.length} certificado(s): '
                '${mismatches.take(3).join(', ')}'
                '${mismatches.length > 3 ? '…' : ''}. '
                'Atualize a página antes de editar.';
    });
  }

  @override
  void dispose() {
    _lockHeartbeat?.cancel();
    final email = AuthSession.instance.user?.email ?? '';
    if (email.trim().isNotEmpty) {
      FieldStore.instance.releaseCalibrationEdit(
        osId: widget.osId,
        email: email,
      );
    }
    _techEmails.dispose();
    super.dispose();
  }

  /// Se o slot usa nº de certificado que já pertence a outra OS, gera nº novo
  /// e solta o jobId (evita 0031 preenchido em duas OS).
  Future<void> _detachForeignCertificateNumbers() async {
    final os = _os;
    if (os == null || os.calibrationSlots.isEmpty) return;
    await CalibrationStore.instance.load();
    final nextSlots = <OsCalibrationSlot>[];
    var changed = 0;
    final reserved = <String>[
      for (final s in os.calibrationSlots) s.certificateNumber,
    ];
    for (final slot in os.calibrationSlots) {
      final number = slot.certificateNumber.trim();
      if (number.isEmpty) {
        nextSlots.add(slot);
        continue;
      }
      CalibrationJob? foreign;
      for (final job in CalibrationStore.instance.items) {
        if (job.number.trim().toLowerCase() != number.toLowerCase()) continue;
        final jOs = job.osId.trim();
        if (jOs.isNotEmpty && jOs != os.id) {
          foreign = job;
          break;
        }
        final jNum = job.osNumber.trim().toLowerCase();
        if (jOs.isEmpty &&
            jNum.isNotEmpty &&
            jNum != os.number.trim().toLowerCase()) {
          foreign = job;
          break;
        }
      }
      final linked = _linkedJob(os, slot);
      final ownedHere =
          linked != null &&
          (linked.osId.trim().isEmpty || linked.osId.trim() == os.id) &&
          (linked.osNumber.trim().isEmpty ||
              linked.osNumber.trim().toLowerCase() ==
                  os.number.trim().toLowerCase());
      if (foreign == null || ownedHere) {
        nextSlots.add(slot);
        continue;
      }
      final kind = calibrationKindFrom(slot.kind);
      final fresh = CalibrationStore.instance.nextNumber(
        kind,
        reserved: reserved,
      );
      reserved.add(fresh);
      changed++;
      nextSlots.add(slot.copyWith(certificateNumber: fresh, jobId: ''));
    }
    if (changed == 0) return;
    await FieldStore.instance.saveCalibrationSlots(
      osId: os.id,
      slots: nextSlots,
    );
    if (mounted) {
      _toast(
        context,
        changed == 1
            ? '1 certificado usava número de outra OS — geramos número novo.'
            : '$changed certificados usavam número de outra OS — geramos números novos.',
      );
    }
  }

  SavedOs? get _os => FieldStore.instance.byId(widget.osId);

  bool _canFillRdo(SavedOs os) {
    if (!os.canFillRdo) return false;
    if (!widget.officeMode) return true;
    final user = AuthSession.instance.user;
    if (user == null) return false;
    return os.isAssignedToAny(assigneeKeysFor(user));
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _openRdo(
    BuildContext context,
    SavedOs os, {
    SavedRdo? existing,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RdoFormPage(os: os, existing: existing),
      ),
    );
  }

  Future<void> _removeCalibrationSlotsOfKind(
    SavedOs os,
    CalibrationKind kind,
  ) async {
    if (os.isClosed) {
      _toast(context, 'OS encerrada — não dá para remover certificados.');
      return;
    }
    final count = os.calibrationSlots.where((s) => s.kind == kind.name).length;
    if (count == 0) return;
    final label = calibrationKindLabel(kind);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover $label?'),
        content: Text(
          'Apaga os $count certificado(s) de $label nesta OS. '
          'Os outros tipos ficam. Não dá para desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: Key('os-cal-remove-kind-${kind.name}'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover todos'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final next = [
        for (final slot in os.calibrationSlots)
          if (slot.kind != kind.name) slot,
      ];
      await FieldStore.instance.saveCalibrationSlots(osId: os.id, slots: next);
      if (!mounted) return;
      _toast(context, '$count certificado(s) de $label removido(s).');
    } catch (error) {
      if (mounted) _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Etiquetas na área do técnico: quem emite certificado ou vê todas as OS
  /// (Cleber/adm colocam data e geram adesivo sem precisar de emitir_cert).
  bool get _canPrintLabels {
    if (widget.officeMode) return false;
    if (_canIssueCertificate) return true;
    return AuthSession.instance.user?.seesAllFieldOs == true;
  }

  Widget _calibrationGroupActions(SavedOs os, CalibrationKind kind) {
    final canPrint = _canPrintLabels;
    final canDelete = widget.officeMode && !os.isClosed;
    if (!canPrint && !canDelete) return const SizedBox.shrink();
    final label = calibrationKindLabel(kind);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canPrint)
          IconButton(
            key: Key('os-cal-print-group-${kind.name}'),
            tooltip: 'Escolher e imprimir adesivos · $label',
            onPressed: _busy
                ? null
                : () => _printCalibrationLabels(os, kind: kind),
            icon: const Icon(Icons.local_offer_outlined),
            color: GsTheme.navy,
          ),
        if (canDelete)
          IconButton(
            key: Key('os-cal-remove-group-${kind.name}'),
            tooltip: 'Remover todos de $label',
            onPressed: _busy
                ? null
                : () => _removeCalibrationSlotsOfKind(os, kind),
            icon: const Icon(Icons.delete_sweep_outlined),
            color: const Color(0xFF8A3B3B),
          ),
      ],
    );
  }

  Widget _calibrationKindSummary(SavedOs os) {
    final groups = groupCalibrationSlotsByKind(os.calibrationSlots);
    return Column(
      children: [
        for (final group in groups)
          Container(
            key: Key('os-cal-summary-${group.kind.name}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD9DEE5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${calibrationKindLabel(group.kind)} · ${group.items.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GsTheme.navy,
                    ),
                  ),
                ),
                _calibrationGroupActions(os, group.kind),
              ],
            ),
          ),
      ],
    );
  }

  bool get _canIssueCertificate =>
      AuthSession.instance.user?.canIssueCertificate == true;

  CalibrationJob? _linkedJob(SavedOs os, OsCalibrationSlot slot) {
    return CalibrationStore.instance.jobForSlot(
      slot,
      osId: os.id,
      osNumber: os.number,
    );
  }

  Future<CalibrationJob> _jobForLabel(
    SavedOs os,
    OsCalibrationSlot slot,
  ) async {
    await CalibrationStore.instance.load();
    await ClientStore.instance.load();
    final existing = _linkedJob(os, slot);
    if (existing != null) {
      return prepareCertificateJob(
        existing.copyWith(
          osId: existing.osId.trim().isEmpty ? os.id : existing.osId,
          osNumber: existing.osNumber.trim().isEmpty
              ? os.number
              : existing.osNumber,
          calibrationSlotId: existing.calibrationSlotId.trim().isEmpty
              ? slot.id
              : existing.calibrationSlotId,
        ),
      );
    }
    final user = AuthSession.instance.user;
    var job = jobFromOsCalibrationSlot(
      os: os,
      slot: slot,
      technicianName: user?.name ?? '',
    );
    job = resolveCalibrationJobInstrument(job, slot: slot);
    if (job.calibrationDate.trim().isEmpty) {
      final when = os.startsAt ?? os.createdAt;
      job = job.copyWith(
        calibrationDate: DateFormat('dd/MM/yyyy').format(when),
      );
    }
    return job;
  }

  String _labelDateFor(SavedOs os, OsCalibrationSlot slot) {
    final job = _linkedJob(os, slot);
    if (job == null) return slot.labelDate.trim();
    return calibrationLabelDate(job, slot: slot);
  }

  /// Data só do adesivo deste item; [clear] volta para a do certificado.
  Future<void> _editSlotLabelDate(
    SavedOs os,
    OsCalibrationSlot slot, {
    bool clear = false,
  }) async {
    var value = '';
    if (!clear) {
      final now = DateTime.now();
      final picked = await pickAppDate(
        context,
        initialDate: parseCalibrationDateLabel(_labelDateFor(os, slot)) ?? now,
        firstDate: DateTime(now.year - 3),
        lastDate: DateTime(now.year + 1, 12, 31),
      );
      if (picked == null || !mounted) return;
      value = formatCalibrationDateLabel(picked);
    }
    setState(() => _busy = true);
    try {
      final current = FieldStore.instance.byId(os.id) ?? os;
      await FieldStore.instance.saveCalibrationSlots(
        osId: os.id,
        slots: [
          for (final item in current.calibrationSlots)
            if (item.id == slot.id) item.copyWith(labelDate: value) else item,
        ],
      );
      if (mounted) {
        _toast(
          context,
          clear
              ? '${slot.certificateNumber}: adesivo volta a usar a data do certificado.'
              : '${slot.certificateNumber}: adesivo sai com $value.',
        );
      }
    } catch (error) {
      if (mounted) _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<SavedOs> _syncSlotsFromJobs(SavedOs os) async {
    await CalibrationStore.instance.load();
    final refreshed = await FieldStore.instance.refreshCalibrationSlotsForOs(
      os.id,
      jobs: CalibrationStore.instance.items,
    );
    return refreshed ?? FieldStore.instance.byId(os.id) ?? os;
  }

  Future<List<CalibrationJob>> _relatedJobsOnOs(
    SavedOs os,
    CalibrationJob job,
  ) async {
    final pool = <CalibrationJob>[];
    for (final slot in os.calibrationSlots) {
      final linked = _linkedJob(os, slot);
      if (!calibrationSlotReadyForLabel(slot, job: linked)) continue;
      try {
        pool.add(await _jobForLabel(os, slot));
      } catch (_) {}
    }
    return relatedCalibrationJobsForMeter(job, pool);
  }

  Future<void> _printCalibrationSlot(SavedOs os, int index) async {
    setState(() => _busy = true);
    SavedOs synced;
    OsCalibrationSlot slot;
    CalibrationJob job;
    List<CalibrationJob> related;
    try {
      synced = await _syncSlotsFromJobs(os);
      if (!mounted) return;
      if (index < 0 || index >= synced.calibrationSlots.length) {
        _toast(context, 'Certificado não encontrado na OS.');
        return;
      }
      slot = synced.calibrationSlots[index];
      await CalibrationStore.instance.load();
      final linked = _linkedJob(synced, slot);
      if (!calibrationSlotReadyForLabel(slot, job: linked)) {
        _toast(
          context,
          linked == null
              ? '${slot.certificateNumber} não tem calibração — é sobressalente. '
                    'Remova os sem calibração ou preencha TAG/N/S.'
              : '${slot.certificateNumber} ainda está sem TAG/N/S no certificado. '
                    'Preencha (ou puxe do cadastro) antes do adesivo.',
        );
        return;
      }
      job = await _jobForLabel(synced, slot);
      related = await _relatedJobsOnOs(synced, job);
    } catch (error) {
      if (mounted) {
        _toast(context, '$error');
        setState(() => _busy = false);
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    final options = await showCalibrationLabelSizeDialog(
      context,
      currentDate: _labelDateFor(synced, slot),
      sameMeterCount: related.length,
    );
    if (options == null || !mounted) return;
    final size = options.size;
    setState(() => _busy = true);
    try {
      final relatedForLabel =
          options.combineSameMeter && related.length > 1 ? related : const <CalibrationJob>[];
      final bytes = await buildCalibrationLabel(
        job,
        relatedCertificates: relatedForLabel,
        size: size,
        calibrationDateOverride: options.dateOverride,
      );
      final fileName = calibrationLabelFileName(job);
      final savedAt = await saveLocalFile(
        fileName: fileName,
        bytes: bytes,
        subfolder: 'GS Campo/Adesivos',
      );
      final inDrive = await saveGeneratedPdfToDrive(
        osId: synced.id,
        osNumber: synced.number,
        folder: driveLabelsFolder,
        fileName: fileName,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {});
      final togetherMsg = relatedForLabel.length > 1
          ? ' · ${relatedForLabel.length} certificados no mesmo adesivo'
          : '';
      _toast(
        context,
        (kIsWeb
                ? 'Adesivo ${size.displayLabel} gerado (com QR)$togetherMsg. Veja em Downloads.'
                : 'Adesivo ${size.displayLabel} gerado (com QR)$togetherMsg:\n$savedAt') +
            driveSavedSuffix(inDrive),
      );
    } catch (error) {
      if (mounted) _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Adesivos da OS em um PDF; [kind] nulo = todos os tipos.
  /// Abre a mesma ideia do livro: marca quais imprimir (com/sem data).
  Future<void> _printCalibrationLabels(
    SavedOs os, {
    CalibrationKind? kind,
  }) async {
    final label = kind == null ? 'da OS' : calibrationKindLabel(kind);
    setState(() => _busy = true);
    SavedOs synced;
    List<CalibrationLabelPickItem> candidates;
    try {
      synced = await _syncSlotsFromJobs(os);
      if (!mounted) return;
      await CalibrationStore.instance.load();
      candidates = <CalibrationLabelPickItem>[];
      for (final slot in synced.calibrationSlots) {
        if (kind != null && slot.kind != kind.name) continue;
        final linked = _linkedJob(synced, slot);
        candidates.add(
          CalibrationLabelPickItem(
            slot: slot,
            job: linked,
            dateLabel: _labelDateFor(synced, slot),
            ready: calibrationSlotReadyForLabel(slot, job: linked),
            hasCalibrationDate: slotHasExplicitCalibrationDate(slot, linked),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _toast(context, '$error');
        setState(() => _busy = false);
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;
    if (candidates.isEmpty) {
      _toast(context, 'Nenhum certificado $label nesta OS.');
      return;
    }
    final picked = await showCalibrationLabelPickDialog(
      context,
      items: candidates,
      title: 'Adesivos $label · OS ${synced.number}',
    );
    if (picked == null || !mounted) return;
    if (picked.isEmpty) {
      _toast(context, 'Marque ao menos um adesivo para imprimir.');
      return;
    }

    setState(() => _busy = true);
    final resolved = <({CalibrationLabelPickItem item, CalibrationJob job})>[];
    try {
      for (final item in picked) {
        resolved.add((item: item, job: await _jobForLabel(synced, item.slot)));
      }
    } catch (error) {
      if (mounted) {
        _toast(context, '$error');
        setState(() => _busy = false);
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    final jobs = [for (final r in resolved) r.job];
    final sameMeterMax = () {
      final byKey = <String, int>{};
      var max = 1;
      for (final job in jobs) {
        final key = calibrationMeterGroupKey(job);
        final next = (byKey[key] ?? 0) + 1;
        byKey[key] = next;
        if (next > max) max = next;
      }
      return max;
    }();

    final options = await showCalibrationLabelSizeDialog(
      context,
      sameMeterCount: sameMeterMax,
    );
    if (options == null || !mounted) return;
    final size = options.size;

    setState(() => _busy = true);
    try {
      final pdfs = <Uint8List>[];
      var failed = 0;
      if (options.combineSameMeter && sameMeterMax > 1) {
        final seen = <String>{};
        for (final entry in resolved) {
          final key = calibrationMeterGroupKey(entry.job);
          if (!seen.add(key)) continue;
          final group = [
            for (final other in resolved)
              if (calibrationMeterGroupKey(other.job) == key) other.job,
          ];
          try {
            pdfs.add(
              await buildCalibrationLabel(
                entry.job,
                relatedCertificates: group,
                size: size,
                calibrationDateOverride: options.dateOverride,
              ),
            );
          } catch (_) {
            failed++;
          }
        }
      } else {
        for (final entry in resolved) {
          try {
            pdfs.add(
              await buildCalibrationLabel(
                entry.job,
                size: size,
                calibrationDateOverride: options.dateOverride,
              ),
            );
          } catch (_) {
            failed++;
          }
        }
      }
      if (pdfs.isEmpty) {
        if (mounted) {
          _toast(
            context,
            'Não gerou nenhum adesivo. Confira TAG/N/S e a data no certificado.',
          );
        }
        return;
      }
      final merged = await mergeCalibrationPdfs(pdfs);
      final safeOs = synced.number
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
          .replaceAll(RegExp(r'\s+'), '_');
      final safeKind = label
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = kind == null
          ? 'OS_${safeOs}_adesivos.pdf'
          : 'OS_${safeOs}_${safeKind}_adesivos.pdf';
      final savedAt = await saveLocalFile(
        fileName: fileName,
        bytes: merged,
        subfolder: 'GS Campo/Adesivos',
      );
      final inDrive = await saveGeneratedPdfToDrive(
        osId: synced.id,
        osNumber: synced.number,
        folder: driveLabelsFolder,
        fileName: fileName,
        bytes: merged,
      );
      if (!mounted) return;
      final ok = pdfs.length;
      final skipMsg = failed > 0 ? ' · $failed não gerou' : '';
      final modeMsg = options.combineSameMeter && sameMeterMax > 1
          ? ' · medidor junto'
          : '';
      setState(() {});
      _toast(
        context,
        (kIsWeb
                ? 'PDF com $ok adesivo(s) $label (${size.displayLabel})$modeMsg.$skipMsg Veja em Downloads.'
                : 'PDF com $ok adesivo(s) $label (${size.displayLabel})$modeMsg:\n$savedAt$skipMsg') +
            driveSavedSuffix(inDrive),
      );
    } catch (error) {
      if (mounted) _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeOrphanCalibrationSlots(SavedOs os) async {
    if (os.isClosed) {
      _toast(context, 'OS encerrada — não dá para remover certificados.');
      return;
    }
    await CalibrationStore.instance.load();
    final orphans = [
      for (final slot in os.calibrationSlots)
        if (calibrationSlotIsOrphanWithoutJob(slot, job: _linkedJob(os, slot)))
          slot,
    ];
    if (orphans.isEmpty) {
      _toast(context, 'Não há sobressalentes sem calibração nesta OS.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover sobressalentes?'),
        content: Text(
          'Apaga ${orphans.length} certificado(s) vazio(s): sem TAG/N/S e sem '
          'calibração iniciada. Os que têm instrumento escolhido ou certificado '
          'preenchido ficam. Não dá para desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('os-cal-remove-orphans'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover sobressalentes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final removeIds = {for (final slot in orphans) slot.id};
      final next = [
        for (final slot in os.calibrationSlots)
          if (!removeIds.contains(slot.id)) slot,
      ];
      await FieldStore.instance.saveCalibrationSlots(osId: os.id, slots: next);
      if (!mounted) return;
      _toast(
        context,
        orphans.length == 1
            ? '1 sobressalente removido.'
            : '${orphans.length} sobressalentes removidos.',
      );
    } catch (error) {
      if (mounted) _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCertificatesForOs(SavedOs os) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationFromOsPage(osId: os.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pullEmptySerialsFromCatalog(SavedOs os) async {
    setState(() => _busy = true);
    try {
      final serialBefore = {
        for (final slot in os.calibrationSlots)
          slot.id: slot.serialNumber.trim(),
      };
      await CalibrationStore.instance.load();
      final refreshedOs = await FieldStore.instance
          .refreshCalibrationSlotsForOs(
            os.id,
            jobs: CalibrationStore.instance.items,
            onlyFillEmptySerial: true,
          );
      if (!mounted) return;
      final fresh = refreshedOs ?? _os ?? os;
      final filled = fresh.calibrationSlots
          .where(
            (slot) =>
                slot.serialNumber.trim().isNotEmpty &&
                slot.serialNumber.trim() != serialBefore[slot.id],
          )
          .length;
      final after = fresh.calibrationSlots
          .where((slot) => slot.serialNumber.trim().isEmpty)
          .length;
      _toast(
        context,
        filled > 0
            ? 'Cadastro preencheu $filled certificado(s). '
                  'Os que já têm certificado ou conferência não foram trocados.'
            : after == 0
            ? 'Todos os certificados desta OS já têm N/S. Nada foi trocado.'
            : 'Ainda há $after sem N/S no cadastro deste cliente. '
                  'Os que já tinham N/S continuam iguais.',
      );
      setState(() {});
    } catch (error) {
      if (mounted) _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printCertificateBook(
    SavedOs os, {
    bool saveToDrive = false,
  }) async {
    if (!_canIssueCertificate) {
      _toast(context, 'Sem permissão para emitir certificados.');
      return;
    }
    if (saveToDrive) {
      final ready = await ensureDriveReady(context);
      if (!ready || !mounted) return;
    }
    await CalibrationStore.instance.load();
    await ClientStore.instance.load();
    final candidates = <CalibrationJob>[];
    final seenJobIds = <String>{};
    for (final slot in os.calibrationSlots) {
      final existing = _linkedJob(os, slot);
      if (existing == null || !seenJobIds.add(existing.id)) continue;
      candidates.add(prepareCertificateJob(existing));
    }
    if (candidates.isEmpty) {
      if (mounted) {
        _toast(
          context,
          'Nenhum certificado preenchido nesta OS. '
          'Abra cada item em Calibração, finalize e depois gere o livro.',
        );
      }
      return;
    }
    if (!mounted) return;
    final jobs = await showCertificateBookPickDialog(
      context,
      jobs: candidates,
      title: saveToDrive
          ? 'Salvar livro da OS ${os.number} no Drive'
          : 'Livro da OS ${os.number}',
    );
    if (jobs == null || !mounted) return;
    if (jobs.isEmpty) {
      _toast(context, 'Marque ao menos um certificado para gerar o livro.');
      return;
    }
    final signed = await askCertificateSignatureMode(
      context,
      title: 'Assinatura do livro',
    );
    if (signed == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final client = ClientStore.instance.findMatch(
        cnpj: os.rdo.cnpj,
        name: os.rdo.client,
      );
      final requester =
          [
                for (final job in jobs)
                  if (job.serviceRequester.trim().isNotEmpty)
                    job.serviceRequester.trim(),
              ]
              .followedBy([
                if ((client?.requester ?? '').trim().isNotEmpty)
                  client!.requester.trim(),
              ])
              .firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final bytes = await buildCalibrationCertificateBundle(
        jobs: jobs,
        requesterName: requester,
        clientName: os.rdo.client,
        osNumber: os.number,
        withSignature: signed,
      );
      final fileName = calibrationBundleFileName(
        osNumber: os.number,
        requester: requester,
      );
      final savedAt = await saveLocalFile(
        fileName: fileName,
        bytes: bytes,
        subfolder: 'GS Campo/Certificados',
      );
      var inDrive = false;
      if (saveToDrive) {
        inDrive = await saveGeneratedPdfToDrive(
          osId: os.id,
          osNumber: os.number,
          folder: driveBookFolder,
          fileName: fileName,
          bytes: bytes,
        );
      }
      if (!mounted) return;
      if (saveToDrive) {
        _toast(
          context,
          inDrive
              ? 'Livro salvo no Google Drive '
                    '(Certificados de Calibração/Book · ${jobs.length} cert.).'
              : 'Livro gerado no aparelho, mas não entrou no Google Drive. '
                    'Confira a pasta das OS em Configurações.',
        );
      } else {
        _toast(
          context,
          kIsWeb
              ? 'Livro gerado (${jobs.length} cert.). Veja em Downloads. '
                    'Use “Salvar livro no Google Drive” para enviar à pasta da OS.'
              : 'Livro gerado:\n$savedAt\n'
                    'Use “Salvar livro no Google Drive” para enviar à pasta da OS.',
        );
      }
    } catch (error) {
      if (mounted) _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _calibrationSlotCard(SavedOs os, int index) {
    final slot = os.calibrationSlots[index];
    final job = _linkedJob(os, slot);
    final labelReady = calibrationSlotReadyForLabel(slot, job: job);
    final orphan = calibrationSlotIsOrphanWithoutJob(slot, job: job);
    final shown = job == null
        ? null
        : calibrationJobForCertificatePrint(job, slot: slot);
    final presetTag = (shown?.presetTag ?? slot.presetTag).trim();
    final presetSerial = (shown?.presetSerial ?? slot.presetSerial).trim();
    return Container(
      key: Key('os-hub-cal-${slot.id}'),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slot.certificateNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: GsTheme.navy,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (_canPrintLabels)
                  IconButton(
                    key: Key('os-cal-print-${slot.id}'),
                    tooltip: !labelReady
                        ? (orphan
                              ? 'Sem calibração — sem etiqueta'
                              : 'Certificado sem TAG/N/S — sem etiqueta')
                        : 'Imprimir etiqueta',
                    onPressed: _busy || !labelReady
                        ? null
                        : () => _printCalibrationSlot(os, index),
                    icon: const Icon(Icons.local_offer_outlined, size: 20),
                    color: GsTheme.navy,
                  ),
              ],
            ),
            Text(
              osCalibrationSlotDetailLine(slot, job: job),
              style: const TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
            ),
            if (presetTag.isNotEmpty || presetSerial.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (presetTag.isNotEmpty) 'Preset $presetTag',
                  if (presetSerial.isNotEmpty) 'N/S preset $presetSerial',
                ].join(' · '),
                style: const TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
              ),
            ],
            if (_canPrintLabels && labelReady) ...[
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  ActionChip(
                    key: Key('os-cal-label-date-${slot.id}'),
                    avatar: const Icon(Icons.event, size: 16),
                    label: Text(
                      'Data no adesivo: ${_labelDateFor(os, slot)}'
                      '${slot.labelDate.trim().isNotEmpty ? ' (alterada)' : ''}',
                    ),
                    onPressed: _busy
                        ? null
                        : () => _editSlotLabelDate(os, slot),
                  ),
                  if (slot.labelDate.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'Voltar para a data do certificado',
                      visualDensity: VisualDensity.compact,
                      onPressed: _busy
                          ? null
                          : () => _editSlotLabelDate(os, slot, clear: true),
                      icon: const Icon(Icons.undo, size: 18),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickRdoDay(BuildContext context, SavedOs os) async {
    final picked = await pickAppDate(
      context,
      initialDate: DateTime.now(),
      firstDate: os.startDay.subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (!context.mounted || picked == null) return;
    await _openRdo(context, os, existing: os.rdoOnDay(picked));
  }

  void _toggleRdo(String id, bool? value) {
    setState(() {
      if (value == true) {
        _selectedRdoIds.add(id);
      } else {
        _selectedRdoIds.remove(id);
      }
    });
  }

  void _toggleAttachment(String name, bool? value, {bool hasBytes = true}) {
    if (value == true && !hasBytes) {
      _toast(
        context,
        'Este arquivo não está neste aparelho. Anexe de novo para salvar.',
      );
      return;
    }
    setState(() {
      if (value == true) {
        _selectedAttachments.add(name);
      } else {
        _selectedAttachments.remove(name);
      }
    });
  }

  void _selectAll(SavedOs os) {
    final mine = FieldStore.instance.viewerAttachments(os);
    setState(() {
      _selectedRdoIds
        ..clear()
        ..addAll(os.rdos.map((e) => e.id));
      _selectedAttachments
        ..clear()
        ..addAll([
          for (final f in mine)
            if (FieldStore.instance.hasLocalBytes(f)) f.name,
        ])
        ..addAll([
          for (final f in _ephemeral)
            if (f.bytes != null && f.bytes!.isNotEmpty) f.name,
        ]);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedRdoIds.clear();
      _selectedAttachments.clear();
    });
  }

  Future<void> _confirmDeleteRdos(SavedOs os) async {
    final chosen = [
      for (final entry in os.rdos)
        if (_selectedRdoIds.contains(entry.id)) entry,
    ];
    if (chosen.isEmpty) {
      _toast(context, 'Marque o RDO que quer apagar.');
      return;
    }
    final fmt = DateFormat('dd/MM/yyyy');
    final dates = [for (final entry in chosen) fmt.format(entry.date)];
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: GsTheme.paper,
          title: Text(
            chosen.length == 1 ? 'Apagar este RDO?' : 'Apagar estes RDOs?',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: GsTheme.navy,
            ),
          ),
          content: Text(
            chosen.length == 1
                ? 'O RDO de ${dates.first} sai desta OS na planilha. Não dá para desfazer.'
                : 'Os RDOs de ${dates.join(', ')} saem desta OS na planilha. Não dá para desfazer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B3A3A),
              ),
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final ids = [for (final entry in chosen) entry.id];
      await FieldStore.instance.removeRdos(os.id, ids);
      if (!mounted) return;
      setState(() {
        _selectedRdoIds.removeAll(ids);
      });
      _toast(
        context,
        ids.length == 1 ? 'RDO apagado.' : '${ids.length} RDOs apagados.',
      );
    } catch (error) {
      if (!mounted) return;
      _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _selectionCount =>
      _selectedRdoIds.length + _selectedAttachments.length;

  void _setEmailField(String line, String toast) {
    _techEmails.value = TextEditingValue(
      text: line,
      selection: TextSelection.collapsed(offset: line.length),
    );
    setState(() {});
    _toast(context, toast);
  }

  void _fillAdminEmails() {
    final line = destinationEmailsFor(audience: MailAudience.office);
    if (line.trim().isEmpty) {
      _toast(context, 'Nenhum e-mail administrativo cadastrado.');
      return;
    }
    _setEmailField(
      line,
      'E-mails administrativos. Ajuste se quiser antes de enviar.',
    );
  }

  void _fillTechnicianEmails(SavedOs os) {
    final line = technicianEmailsLineForOs(os);
    if (line.isEmpty) {
      _toast(context, 'Esta OS ainda não tem e-mail de técnico cadastrado.');
      return;
    }
    _setEmailField(
      line,
      'E-mails dos técnicos da OS. Ajuste se quiser antes de enviar.',
    );
  }

  void _fillAdminAndTechnicianEmails(SavedOs os) {
    final admin = parseRecipientEmails(
      destinationEmailsFor(audience: MailAudience.office),
    );
    final tech = technicianEmailsForOs(os);
    final merged = <String>{...admin, ...tech}.toList()..sort();
    if (merged.isEmpty) {
      _toast(context, 'Nenhum e-mail de técnico ou administrativo encontrado.');
      return;
    }
    _setEmailField(
      merged.join(', '),
      'Administrativos e técnicos juntos. Ajuste se quiser antes de enviar.',
    );
  }

  void _fillClientEmails(SavedOs os) {
    final line = destinationEmailsFor(
      audience: MailAudience.client,
      clientEmail: clientRdoEmail(os),
    );
    if (line.trim().isEmpty) {
      _toast(
        context,
        'Cadastre o e-mail da base nesta OS para enviar ao cliente.',
      );
      return;
    }
    _setEmailField(
      line,
      'E-mail do cliente (base). Ajuste se quiser antes de enviar.',
    );
  }

  void _fillClientAndAdminEmails(SavedOs os) {
    if (clientRdoEmail(os) == null) {
      _toast(
        context,
        'Cadastre o e-mail da base nesta OS para incluir o cliente.',
      );
      return;
    }
    final line = destinationEmailsFor(
      audience: MailAudience.both,
      clientEmail: clientRdoEmail(os),
    );
    _setEmailField(
      line,
      'Cliente e administrativos. Ajuste se quiser antes de enviar.',
    );
  }

  void _fillClientAndTechnicianEmails(SavedOs os) {
    final client = clientRdoEmail(os);
    final tech = technicianEmailsForOs(os);
    final merged = <String>{
      if (client != null) client,
      ...tech,
    }.toList()
      ..sort();
    if (client == null) {
      _toast(
        context,
        'Cadastre o e-mail da base nesta OS para incluir o cliente.',
      );
      return;
    }
    if (merged.isEmpty) {
      _toast(context, 'Nenhum e-mail de cliente ou técnico encontrado.');
      return;
    }
    _setEmailField(
      merged.join(', '),
      'Cliente e técnicos. Ajuste se quiser antes de enviar.',
    );
  }

  void _fillAllEmails(SavedOs os) {
    final admin = parseRecipientEmails(
      destinationEmailsFor(audience: MailAudience.office),
    );
    final client = clientRdoEmail(os);
    final tech = technicianEmailsForOs(os);
    final merged = <String>{
      ...admin,
      if (client != null) client,
      ...tech,
    }.toList()
      ..sort();
    if (merged.isEmpty) {
      _toast(context, 'Nenhum e-mail encontrado para esta OS.');
      return;
    }
    _setEmailField(
      merged.join(', '),
      'Todos os destinatários. Ajuste se quiser antes de enviar.',
    );
  }

  OsFileKind _kindFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.webp')) {
      return OsFileKind.photo;
    }
    return OsFileKind.certificate;
  }

  Future<void> _keep(List<DraftFile> drafts) async {
    if (drafts.isEmpty) return;
    try {
      await FieldStore.instance.addOsFiles(widget.osId, drafts);
      setState(() {
        for (final d in drafts) {
          _selectedAttachments.add(d.name);
        }
      });
    } catch (_) {
      setState(() {
        _ephemeral.addAll(drafts);
        for (final d in drafts) {
          _selectedAttachments.add(d.name);
        }
      });
      if (!mounted) return;
      _toast(
        context,
        'Não deu para gravar neste aparelho. O arquivo segue na seleção para envio.',
      );
    }
  }

  Future<void> _pickFiles() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'xlsx',
          'xlsm',
          'xls',
          'jpg',
          'jpeg',
          'png',
          'heic',
        ],
      );
      if (picked == null) return;
      final drafts = <DraftFile>[];
      for (final file in picked.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        var name = file.name;
        final isImage = _kindFor(name) == OsFileKind.photo;
        if (isImage && mounted) {
          setState(() => _busy = false);
          final renamed = await promptAttachmentName(
            context,
            currentName: name,
            title: 'Nome da foto',
          );
          if (!mounted) return;
          setState(() => _busy = true);
          if (renamed == null) continue;
          name = renamed;
        }
        drafts.add(DraftFile(name: name, kind: _kindFor(name), bytes: bytes));
      }
      await _keep(drafts);
    } catch (_) {
      if (!mounted) return;
      _toast(context, 'Não foi possível abrir o arquivo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto({ImageSource source = ImageSource.camera}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      if (!mounted) return;
      setState(() => _busy = false);
      final renamed = await promptAttachmentName(
        context,
        currentName: picked.name,
        title: 'Nome da foto',
      );
      if (!mounted) return;
      setState(() => _busy = true);
      if (renamed == null) return;
      await _keep([
        DraftFile(name: renamed, kind: OsFileKind.photo, bytes: bytes),
      ]);
    } catch (_) {
      if (source == ImageSource.camera) {
        await _pickPhoto(source: ImageSource.gallery);
        return;
      }
      if (!mounted) return;
      _toast(context, 'Não foi possível abrir a foto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadSaved(SavedFile file) async {
    final bytes = await FieldStore.instance.ensureBytes(file);
    if (bytes == null || bytes.isEmpty) {
      _toast(context, 'Este arquivo não está neste aparelho. Anexe de novo.');
      return;
    }
    try {
      await downloadRdoFile(fileName: file.name, bytes: bytes);
    } catch (error) {
      _toast(context, 'Não baixou o arquivo. $error');
    }
  }

  Future<void> _downloadSelection(SavedOs os) async {
    if (_selectionCount == 0) {
      _toast(context, 'Marque RDOs e/ou anexos para baixar.');
      return;
    }
    setState(() => _busy = true);
    try {
      await downloadOsSelection(
        os: os,
        rdoIds: {..._selectedRdoIds},
        attachmentNames: {..._selectedAttachments},
        drafts: [..._ephemeral],
        asZip: _compressZip || _selectionCount > 1,
      );
      if (!mounted) return;
      _toast(
        context,
        _compressZip || _selectionCount > 1
            ? 'Download do ZIP iniciado.'
            : 'Download iniciado.',
      );
    } catch (error) {
      if (!mounted) return;
      _toast(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadDraft(DraftFile file) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _toast(context, 'Arquivo vazio.');
      return;
    }
    try {
      await downloadRdoFile(fileName: file.name, bytes: bytes);
    } catch (error) {
      _toast(context, 'Não baixou o arquivo. $error');
    }
  }

  Future<void> _emailSelection(SavedOs os) async {
    if (_selectionCount == 0) {
      _toast(context, 'Marque o que quer enviar (RDO, planilha, foto ou PDF).');
      return;
    }
    setState(() => _busy = true);
    try {
      await emailSelectedOsItems(
        context,
        os: os,
        rdoIds: {..._selectedRdoIds},
        attachmentNames: {..._selectedAttachments},
        drafts: [..._ephemeral],
        emailsField: _techEmails.text,
        compressZip: _compressZip,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cloudSelection(SavedOs os) async {
    if (_selectionCount == 0) {
      _toast(context, 'Marque o que quer salvar na pasta da OS.');
      return;
    }
    final attachmentNames = {..._selectedAttachments};
    setState(() => _busy = true);
    try {
      final ok = await cloudSelectedOsItems(
        context,
        os: os,
        rdoIds: {..._selectedRdoIds},
        attachmentNames: attachmentNames,
        drafts: [..._ephemeral],
      );
      if (!mounted || !ok) return;
      setState(() {
        _ephemeral.removeWhere((d) => attachmentNames.contains(d.name));
        _selectedAttachments.removeWhere(attachmentNames.contains);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        FieldStore.instance,
        CalibrationStore.instance,
      ]),
      builder: (context, _) {
        final os = _os;
        if (os == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('OS')),
            body: const Center(child: Text('Esta OS não foi encontrada.')),
          );
        }
        final canFill = _canFillRdo(os);
        final header = os.rdo;
        final myAttachments = FieldStore.instance.viewerAttachments(os);
        final hasItems =
            os.rdos.isNotEmpty ||
            myAttachments.isNotEmpty ||
            _ephemeral.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text('OS ${os.number}'),
            actions: [
              if (widget.officeMode &&
                  AuthSession.instance.user?.canGenerateOs == true)
                IconButton(
                  key: Key('os-hub-delete-${os.id}'),
                  tooltip: 'Apagar OS',
                  onPressed: () async {
                    final ok = await deleteOsWithConfirm(context, os);
                    if (ok && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              if (widget.officeMode && os.status != OsStatus.encerrada)
                IconButton(
                  tooltip: 'Editar OS',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OsCreatePage(existing: os),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (_editLockWarning != null) ...[
                _IntegrityBanner(
                  color: const Color(0xFF8A5A00),
                  background: const Color(0xFFFFF4D6),
                  message: _editLockWarning!,
                ),
                const SizedBox(height: 10),
              ],
              if (_slotMismatchWarning != null) ...[
                _IntegrityBanner(
                  color: const Color(0xFF8B1E1E),
                  background: const Color(0xFFFFE8E8),
                  message: _slotMismatchWarning!,
                ),
                const SizedBox(height: 10),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      osStatusLabel(os.status),
                      style: const TextStyle(
                        color: GsTheme.brass,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (os.status == OsStatus.servicoEncerrado && canFill)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'O serviço foi marcado como encerrado, mas você ainda pode lançar RDO do dia até o escritório fechar a OS.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: Color(0xFF5C6570),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      header.client.isEmpty ? 'OS ${os.number}' : header.client,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GsTheme.navy,
                      ),
                    ),
                    if (header.cnpj.isNotEmpty)
                      Text(
                        'CNPJ ${header.cnpj}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5C6570),
                        ),
                      ),
                    if (header.site.isNotEmpty)
                      Text(
                        header.site,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5C6570),
                        ),
                      ),
                    if (header.service.isNotEmpty)
                      Text(
                        header.service,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5C6570),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      osStartLabel(os),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5C6570),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      os.technicianLabel.isEmpty
                          ? 'Sem técnico amarrado'
                          : os.assigneeEmails.length > 1
                          ? 'Técnicos: ${os.technicianLabel}'
                          : 'Técnico: ${os.technicianLabel}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: GsTheme.navy,
                      ),
                    ),
                  ],
                ),
              ),
              if (os.hasCalibrationPlan) ...[
                const SizedBox(height: 18),
                Text(
                  widget.officeMode
                      ? 'Calibração nesta OS'
                      : 'Etiquetas desta OS',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.officeMode
                      ? 'Os certificados são preenchidos em Gerar certificados '
                            'da OS. RDO, anexos e envio ficam na área do técnico.'
                      : 'Imprima as etiquetas dos certificados preenchidos pelo '
                            'escritório. Item sem TAG/N/S fica sem etiqueta.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5C6570),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.officeMode) ...[
                  FilledButton.icon(
                    key: const Key('os-gerar-certificados'),
                    onPressed: _busy ? null : () => _openCertificatesForOs(os),
                    style: FilledButton.styleFrom(
                      backgroundColor: GsTheme.navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Gerar certificados da OS'),
                  ),
                  if (_canIssueCertificate) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('os-cal-book-pdf'),
                      onPressed: _busy ? null : () => _printCertificateBook(os),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GsTheme.navy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Gerar livro (neste aparelho)'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('os-cal-book-drive'),
                      onPressed: _busy
                          ? null
                          : () => _printCertificateBook(os, saveToDrive: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: GsTheme.navy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.drive_folder_upload_outlined),
                      label: const Text('Salvar livro no Google Drive'),
                    ),
                  ],
                ],
                if (_canPrintLabels) ...[
                  OutlinedButton.icon(
                    key: const Key('os-cal-print-all'),
                    onPressed: _busy ? null : () => _printCalibrationLabels(os),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GsTheme.navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('Imprimir etiquetas (escolher)'),
                  ),
                ],
                if (widget.officeMode &&
                    os.calibrationSlots.any((s) => s.isCatalogPending)) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Text(
                      '${os.calibrationSlots.where((s) => s.isCatalogPending).length} instrumento(s) aguardando aprovação no cadastro.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (widget.officeMode &&
                    os.calibrationSlots.any((s) => s.isDivergent)) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Text(
                      widget.officeMode
                          ? '${os.calibrationSlots.where((s) => s.isDivergent).length} certificado(s) com divergência — confira com o técnico ou na pasta da OS.'
                          : 'Há certificado(s) divergente(s). Anexe evidência e use Enviar/Salvar abaixo.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (widget.officeMode) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('os-puxar-ns-cadastro'),
                      onPressed: _busy
                          ? null
                          : () => _pullEmptySerialsFromCatalog(os),
                      icon: const Icon(Icons.sync),
                      label: const Text('Puxar N/S do cadastro'),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final orphanCount = os.calibrationSlots
                          .where(
                            (s) => calibrationSlotIsOrphanWithoutJob(
                              s,
                              job: _linkedJob(os, s),
                            ),
                          )
                          .length;
                      if (orphanCount == 0 || os.isClosed) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            key: const Key('os-cal-remove-orphans-btn'),
                            onPressed: _busy
                                ? null
                                : () => _removeOrphanCalibrationSlots(os),
                            icon: const Icon(Icons.playlist_remove),
                            label: Text(
                              'Remover $orphanCount vazio(s) (sem TAG/N/S)',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
                if (widget.officeMode)
                  _calibrationKindSummary(os)
                else
                  CalibrationSlotsGroupedList(
                    slots: os.calibrationSlots,
                    isCadastroPending: (slot) => calibrationSlotNeedsCadastro(
                      slot,
                      job: _linkedJob(os, slot),
                    ),
                    itemBuilder: (index, slot) =>
                        _calibrationSlotCard(os, index),
                    groupActionsBuilder: (group) =>
                        _calibrationGroupActions(os, group.kind),
                  ),
              ],
              if (!widget.officeMode) ...[
                const SizedBox(height: 18),
                Text(
                  os.rdos.isEmpty
                      ? 'Nenhum RDO ainda'
                      : '${os.rdos.length} RDO(s) nesta OS',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Marque o que quer enviar ou salvar. Assim não manda de novo o que já foi. Fotos do RDO vão junto quando o RDO estiver marcado.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
                ),
                if (hasItems) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _selectAll(os),
                        child: const Text('Marcar tudo'),
                      ),
                      TextButton(
                        onPressed: _selectionCount == 0
                            ? null
                            : _clearSelection,
                        child: Text(
                          _selectionCount == 0
                              ? 'Limpar'
                              : 'Limpar ($_selectionCount)',
                        ),
                      ),
                      if ((canFill || widget.officeMode) && !os.isClosed)
                        TextButton.icon(
                          key: const Key('os-delete-rdos'),
                          onPressed: _busy || _selectedRdoIds.isEmpty
                              ? null
                              : () => _confirmDeleteRdos(os),
                          icon: const Icon(Icons.delete_outline),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8B3A3A),
                          ),
                          label: Text(
                            _selectedRdoIds.length <= 1
                                ? 'Apagar RDO'
                                : 'Apagar RDOs (${_selectedRdoIds.length})',
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (os.rdos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Ainda não há relatório do dia.',
                      style: TextStyle(color: Color(0xFF5C6570)),
                    ),
                  )
                else
                  for (final entry in os.rdos) ...[
                    _RdoTile(
                      os: os,
                      entry: entry,
                      canEdit: canFill,
                      selected: _selectedRdoIds.contains(entry.id),
                      onSelected: (v) => _toggleRdo(entry.id, v),
                    ),
                    const SizedBox(height: 8),
                  ],
                if (canFill) ...[
                  FilledButton.icon(
                    onPressed: () {
                      final today = os.rdoOnDay(DateTime.now());
                      _openRdo(context, os, existing: today);
                    },
                    icon: const Icon(Icons.edit_calendar_outlined),
                    style: FilledButton.styleFrom(
                      backgroundColor: GsTheme.brass,
                      foregroundColor: Colors.black,
                    ),
                    label: Text(
                      os.rdoOnDay(DateTime.now()) == null
                          ? 'Preencher RDO de hoje'
                          : 'Continuar RDO de hoje',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _pickRdoDay(context, os),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo RDO (outro dia)'),
                  ),
                ],
                const SizedBox(height: 22),
                const Text(
                  'Anexos da OS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Planilha, PDF ou foto deste login. Depois de salvar na pasta da OS, o anexo sai daqui (fica só na nuvem).',
                  style: TextStyle(fontSize: 15, color: Color(0xFF5C6570)),
                ),
                const SizedBox(height: 10),
                if (myAttachments.isEmpty && _ephemeral.isEmpty)
                  const Text(
                    'Nenhum anexo ainda.',
                    style: TextStyle(color: Color(0xFF5C6570)),
                  )
                else ...[
                  for (final file in myAttachments)
                    _AttachTile(
                      name: file.name,
                      kind: file.kind,
                      subtitle: FieldStore.instance.hasLocalBytes(file)
                          ? null
                          : 'Sem arquivo neste aparelho — anexe de novo',
                      selected: FieldStore.instance.hasLocalBytes(file) &&
                          _selectedAttachments.contains(file.name),
                      onSelected: (v) => _toggleAttachment(
                        file.name,
                        v,
                        hasBytes: FieldStore.instance.hasLocalBytes(file),
                      ),
                      onDownload: () => _downloadSaved(file),
                      onRename: () async {
                        final renamed = await promptAttachmentName(
                          context,
                          currentName: file.name,
                          title: file.kind == OsFileKind.photo
                              ? 'Renomear foto'
                              : 'Renomear arquivo',
                        );
                        if (renamed == null || !mounted) return;
                        final old = file.name;
                        await FieldStore.instance.renameOsFile(
                          os.id,
                          file,
                          renamed,
                        );
                        setState(() {
                          if (_selectedAttachments.remove(old)) {
                            _selectedAttachments.add(renamed);
                          }
                        });
                      },
                      onRemove: () async {
                        await FieldStore.instance.removeOsFile(os.id, file);
                        setState(
                          () => _selectedAttachments.remove(file.name),
                        );
                      },
                    ),
                  for (final file in _ephemeral)
                    _AttachTile(
                      name: file.name,
                      kind: file.kind,
                      subtitle: 'Só neste aparelho · ainda não gravou na OS',
                      selected: _selectedAttachments.contains(file.name),
                      onSelected: (v) => _toggleAttachment(
                        file.name,
                        v,
                        hasBytes: file.bytes != null && file.bytes!.isNotEmpty,
                      ),
                      onDownload: () => _downloadDraft(file),
                      onRename: () async {
                        final renamed = await promptAttachmentName(
                          context,
                          currentName: file.name,
                          title: file.kind == OsFileKind.photo
                              ? 'Renomear foto'
                              : 'Renomear arquivo',
                        );
                        if (renamed == null || !mounted) return;
                        final idx = _ephemeral.indexOf(file);
                        if (idx < 0) return;
                        final old = file.name;
                        setState(() {
                          _ephemeral[idx] = file.copyWith(name: renamed);
                          if (_selectedAttachments.remove(old)) {
                            _selectedAttachments.add(renamed);
                          }
                        });
                      },
                      onRemove: () => setState(() {
                        _ephemeral.remove(file);
                        _selectedAttachments.remove(file.name);
                      }),
                    ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Anexar planilha ou PDF'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Anexar foto'),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Enviar ou salvar seleção',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectionCount == 0
                      ? 'Nada marcado. Selecione RDO e/ou anexos acima.'
                      : '$_selectionCount item(ns) marcado(s).',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5C6570),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enviar para',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GsTheme.navy,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _techEmails,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'E-mails',
                    hintText: 'Administrativos, Cliente ou Técnicos',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fillAdminEmails,
                      icon: const Icon(Icons.business_outlined),
                      label: const Text('Administrativos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _fillClientEmails(os),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Cliente'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _fillClientAndAdminEmails(os),
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: const Text('Cliente e adm.'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _fillTechnicianEmails(os),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('Técnicos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _fillClientAndTechnicianEmails(os),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Cliente e técnicos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _fillAdminAndTechnicianEmails(os),
                      icon: const Icon(Icons.merge_type),
                      label: const Text('Adm. e técnicos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _fillAllEmails(os),
                      icon: const Icon(Icons.select_all),
                      label: const Text('Todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cliente = e-mail da base nesta OS (RDO ao cliente sai assinado pelo responsável). '
                  'Administrativos = escritório. Técnicos = quem está na OS. '
                  'Todos = cliente + administrativos + técnicos.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Compactar seleção em ZIP',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GsTheme.navy,
                    ),
                  ),
                  subtitle: const Text(
                    'Recomendado com vários RDOs: um arquivo só no e-mail e no download.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                  ),
                  value: _compressZip,
                  activeThumbColor: GsTheme.navy,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _compressZip = value),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy || _selectionCount == 0
                      ? null
                      : () => _emailSelection(os),
                  icon: const Icon(Icons.email_outlined),
                  style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                  label: Text(_busy ? 'Preparando…' : 'Enviar por e-mail'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy || _selectionCount == 0
                      ? null
                      : () => _downloadSelection(os),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    _busy
                        ? 'Preparando…'
                        : (_compressZip || _selectionCount > 1
                              ? 'Baixar seleção (ZIP)'
                              : 'Baixar seleção'),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy || _selectionCount == 0
                      ? null
                      : () => _cloudSelection(os),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                  label: Text(_busy ? 'Preparando…' : 'Salvar na pasta da OS'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Se o arquivo já estiver na pasta, o app pergunta se quer sobrescrever ou gravar como cópia. '
                  'Se o Drive falhar por permissão, use Baixar seleção (ZIP) e rode authorizeDriveFiles no Apps Script.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                ),
              ],
              if (os.canMarkServiceDone && (canFill || widget.officeMode)) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await FieldStore.instance.markServiceDone(os.id);
                      if (!context.mounted) return;
                      _toast(
                        context,
                        'Serviço marcado como encerrado. O Cleber precisa encerrar a OS de verdade.',
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      _toast(context, '$error');
                    }
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Finalizar serviço'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Isso não fecha a OS. O Cleber confere e encerra de verdade.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
                ),
              ],
              if (AuthSession.instance.user?.canFinalizeAndReopenOs == true &&
                  os.canReopenOs) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await FieldStore.instance.reopenOs(os.id);
                      if (!context.mounted) return;
                      _toast(
                        context,
                        'OS ${os.number} reativada. Os técnicos podem lançar RDO de novo.',
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      _toast(context, '$error');
                    }
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Reativar OS'),
                ),
              ],
              if (widget.officeMode && os.status == OsStatus.rascunho) ...[
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () async {
                    try {
                      await FieldStore.instance.dispatchToTechnician(os.id);
                      if (!context.mounted) return;
                      _toast(
                        context,
                        'OS enviada para a agenda de ${os.technicianLabel}.',
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      _toast(context, '$error');
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                  child: const Text('Enviar à agenda do técnico'),
                ),
              ],
              if (AuthSession.instance.user?.canFinalizeAndReopenOs == true &&
                  os.canCloseOs) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await FieldStore.instance.closeOs(os.id);
                      if (!context.mounted) return;
                      _toast(context, 'OS ${os.number} encerrada de verdade.');
                    } catch (error) {
                      if (!context.mounted) return;
                      _toast(context, '$error');
                    }
                  },
                  icon: const Icon(Icons.lock_outline),
                  style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                  label: const Text('Encerrar OS (Cleber)'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _IntegrityBanner extends StatelessWidget {
  const _IntegrityBanner({
    required this.message,
    required this.color,
    required this.background,
  });

  final String message;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RdoTile extends StatelessWidget {
  const _RdoTile({
    required this.os,
    required this.entry,
    required this.canEdit,
    required this.selected,
    required this.onSelected,
  });

  final SavedOs os;
  final SavedRdo entry;
  final bool canEdit;
  final bool selected;
  final ValueChanged<bool?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListTile(
        leading: Checkbox(
          value: selected,
          onChanged: onSelected,
          activeColor: GsTheme.navy,
        ),
        title: Text(
          'RDO ${DateFormat('dd/MM/yyyy').format(entry.date)}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: GsTheme.navy,
          ),
        ),
        subtitle: Text(
          [
            rdoClockRange(entry.clockIn, entry.clockOut),
            if (entry.responsibleName.trim().isNotEmpty)
              entry.responsibleName.trim(),
            if (entry.bothSigned) 'Assinado por técnico e cliente',
            if (entry.clientSigned && !entry.bothSigned)
              'Cliente: ${entry.clientSignedName}',
            if (entry.description.trim().isNotEmpty) entry.description.trim(),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Baixar RDO',
          onPressed: () async {
            try {
              await downloadSavedRdoEntry(os, entry);
            } catch (error) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: GsTheme.navy,
                  content: Text('$error'),
                ),
              );
            }
          },
          icon: const Icon(Icons.download),
        ),
        onTap: canEdit
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RdoFormPage(os: os, existing: entry),
                  ),
                );
              }
            : () => onSelected(!selected),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.name,
    required this.kind,
    this.subtitle,
    required this.selected,
    required this.onSelected,
    required this.onDownload,
    this.onRename,
    required this.onRemove,
  });

  final String name;
  final OsFileKind kind;
  final String? subtitle;
  final bool selected;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onDownload;
  final VoidCallback? onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        child: ListTile(
          leading: Checkbox(
            value: selected,
            onChanged: onSelected,
            activeColor: GsTheme.navy,
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: GsTheme.navy,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5C6570),
                  ),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                kind == OsFileKind.photo
                    ? Icons.photo_outlined
                    : Icons.attach_file,
                color: GsTheme.navy,
                size: 20,
              ),
              if (onRename != null)
                IconButton(
                  tooltip: 'Renomear',
                  onPressed: onRename,
                  icon: const Icon(Icons.drive_file_rename_outline),
                ),
              IconButton(
                tooltip: 'Baixar',
                onPressed: onDownload,
                icon: const Icon(Icons.download),
              ),
              IconButton(
                tooltip: 'Remover',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          onTap: () => onSelected(!selected),
        ),
      ),
    );
  }
}
