import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/cloud_sync_gate.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/prefs_json.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalibrationStore extends ChangeNotifier {
  CalibrationStore._();
  static final instance = CalibrationStore._();

  static const _key = 'gs_calibration_jobs_v1';
  static const _deletedKey = 'gs_calibration_deleted_ids_v1';
  static const _syncedIdsKey = 'gs_calibration_synced_ids_v1';
  static const _doneBackupKey = calibrationDoneBackupsPrefsKey;
  static const _maxDoneBackups = 20;

  List<CalibrationJob> _all = [];
  final _remoteJobIds = <String>{};

  /// Certificados cuja versão local é igual à da nuvem. Só esses podem sair
  /// do cache quando o localStorage enche.
  final _syncedIds = <String>{};
  final _deletedIds = <String>{};
  var _loaded = false;
  var _persistBatchDepth = 0;
  var _persistDirty = false;

  List<CalibrationJob> get items => List.unmodifiable(_all);
  Set<String> get remoteJobIds => Set.unmodifiable(_remoteJobIds);

  bool isRemote(String id) => _remoteJobIds.contains(id);

  CalibrationJob createCopy(CalibrationJob job) {
    final newId = 'calib-${DateTime.now().microsecondsSinceEpoch}';
    final newNumber = nextNumber(job.kind);
    return job.copyWith(
      id: newId,
      number: newNumber,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @visibleForTesting
  void resetForTest() {
    _all = [];
    _remoteJobIds.clear();
    _syncedIds.clear();
    _deletedIds.clear();
    _loaded = false;
  }

  Future<void> load({
    List<Map<String, dynamic>>? remoteCalibrations,
    List<String>? remoteDeletedIds,
  }) async {
    if (_loaded && remoteCalibrations == null && CloudSyncGate.isFresh) {
      notifyListeners();
      return;
    }
    if (!_loaded) {
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList(_deletedKey) ?? [];
      _deletedIds.addAll(deletedList);
      _syncedIds.addAll(prefs.getStringList(_syncedIdsKey) ?? const []);
      final raw = await readPrefsString(_key) ?? prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        _all = [];
      } else {
        try {
          final decoded = jsonDecode(raw) as List<dynamic>;
          _all = [
            for (final item in decoded)
              if (item is Map)
                CalibrationJob.fromJson(Map<String, dynamic>.from(item)),
          ]..removeWhere((job) => _deletedIds.contains(job.id));
          _sort();
        } catch (_) {
          _all = [];
        }
      }
      _loaded = true;
    }
    if (remoteCalibrations != null || !CloudSyncGate.isFresh) {
      await _pullRemoteCalibrations(
        seed: remoteCalibrations,
        seedDeletedIds: remoteDeletedIds,
      );
    }
    _sort();
    notifyListeners();
  }

  Future<void> sync() async {
    await _pullRemoteCalibrations();
    CloudSyncGate.markSynced();
    _sort();
    notifyListeners();
  }

  bool _jobHasMeasurements(CalibrationJob job) => job.hasMeasurements;

  /// Status mais avançado + medições: nunca regride no sync.
  CalibrationJobStatus _preferStatus(
    CalibrationJobStatus incoming,
    CalibrationJobStatus previous,
  ) {
    int rank(CalibrationJobStatus s) => switch (s) {
      CalibrationJobStatus.done => 4,
      CalibrationJobStatus.pendingReview => 3,
      CalibrationJobStatus.inProgress => 2,
      CalibrationJobStatus.draft => 1,
    };
    return rank(previous) > rank(incoming) ? previous : incoming;
  }

  /// Job local/remoto mais forte com o mesmo nº (mesma OS) ou mesmo slot.
  CalibrationJob? _strongerPeer(CalibrationJob job) {
    CalibrationJob? best;
    final number = job.number.trim().toLowerCase();
    final slotId = job.calibrationSlotId.trim();
    final osId = job.osId.trim();
    for (final other in _all) {
      if (other.id == job.id) continue;
      final sameNumber =
          number.isNotEmpty && other.number.trim().toLowerCase() == number;
      final sameSlot =
          slotId.isNotEmpty && other.calibrationSlotId.trim() == slotId;
      if (!sameNumber && !sameSlot) continue;
      if (sameNumber && osId.isNotEmpty && other.osId.trim().isNotEmpty) {
        if (other.osId.trim() != osId) continue;
      }
      if (best == null || other.isStrongerThan(best)) best = other;
    }
    if (best != null && best.isStrongerThan(job)) return best;
    return null;
  }

  /// Rascunho vazio não deve ir para a nuvem se já existe certificado forte.
  bool shouldRefuseRemotePush(CalibrationJob job) {
    if (!job.isEmptyGhost) return false;
    return _strongerPeer(job) != null;
  }

  /// Nunca troca medições preenchidas por payload vazio (cache slim / sync).
  /// Também nunca apaga fluido/TAG/N/S já preenchidos com string vazia da nuvem.
  CalibrationJob _preserveMeasurements(
    CalibrationJob incoming,
    CalibrationJob? previous,
  ) {
    if (previous == null) return incoming;
    final keepPoints =
        previous.points.any((p) => p.hasReadings) &&
        !incoming.points.any((p) => p.hasReadings);
    final keepGenericPoints =
        previous.genericPoints.any((p) => p.hasReadings) &&
        !incoming.genericPoints.any((p) => p.hasReadings);
    final keepTelemetry =
        previous.telemetryChannels.any((c) => c.hasReadings) &&
        !incoming.telemetryChannels.any((c) => c.hasReadings);
    final keepMeasurementShape =
        keepPoints || keepGenericPoints || keepTelemetry;
    String keepText(String next, String prev) =>
        next.trim().isNotEmpty ? next : prev;
    final merged = incoming.copyWith(
      status: _preferStatus(incoming.status, previous.status),
      points: keepPoints ? previous.points : incoming.points,
      genericPoints: keepGenericPoints
          ? previous.genericPoints
          : incoming.genericPoints,
      telemetryChannels: keepTelemetry
          ? previous.telemetryChannels
          : incoming.telemetryChannels,
      standards: previous.standards.isNotEmpty && incoming.standards.isEmpty
          ? previous.standards
          : incoming.standards,
      coriolisCoefficients:
          previous.coriolisCoefficients.isNotEmpty &&
              incoming.coriolisCoefficients.isEmpty
          ? previous.coriolisCoefficients
          : incoming.coriolisCoefficients,
      runCount: keepMeasurementShape ? previous.runCount : incoming.runCount,
      flowCount: keepMeasurementShape ? previous.flowCount : incoming.flowCount,
      cycleCount: keepMeasurementShape
          ? previous.cycleCount
          : incoming.cycleCount,
      limits: keepMeasurementShape ? previous.limits : incoming.limits,
      fluid: keepText(incoming.fluid, previous.fluid),
      equipmentTag: keepText(incoming.equipmentTag, previous.equipmentTag),
      serialNumber: keepText(incoming.serialNumber, previous.serialNumber),
      presetTag: keepText(incoming.presetTag, previous.presetTag),
      presetSerial: keepText(incoming.presetSerial, previous.presetSerial),
      manufacturer: keepText(incoming.manufacturer, previous.manufacturer),
      model: keepText(incoming.model, previous.model),
      installLocation: keepText(
        incoming.installLocation,
        previous.installLocation,
      ),
      clientName: keepText(incoming.clientName, previous.clientName),
      serviceRequester: keepText(
        incoming.serviceRequester,
        previous.serviceRequester,
      ),
    );
    if (previous.fluid.trim().isNotEmpty && incoming.fluid.trim().isEmpty) {
      debugPrint(
        '[DATA_CHANGE] sync ${previous.number}: nuvem sem fluid — '
        'preservado "${previous.fluid}"',
      );
    }
    return merged;
  }

  Future<void> _backupDoneJob(CalibrationJob job) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_doneBackupKey);
      final list = <dynamic>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) list.addAll(decoded);
      }
      list.removeWhere(
        (item) => item is Map && '${item['id'] ?? ''}' == job.id,
      );
      list.insert(0, {
        'id': job.id,
        'number': job.number,
        'savedAt': DateTime.now().toIso8601String(),
        'job': job.toJson(slimMeasurements: false),
      });
      while (list.length > _maxDoneBackups) {
        list.removeLast();
      }
      await prefs.setString(_doneBackupKey, jsonEncode(list));
    } catch (error) {
      debugPrint('CalibrationStore backup done: $error');
    }
  }

  /// Apaga do cache local o que a nuvem marcou como excluído.
  bool _applyRemoteTombstones(List<String> ids) {
    if (ids.isEmpty) return false;
    final dead = {for (final id in ids) id.trim()}..remove('');
    if (dead.isEmpty) return false;
    final before = _all.length;
    _all = [
      for (final job in _all)
        if (!dead.contains(job.id)) job,
    ];
    final added = dead.difference(_deletedIds).isNotEmpty;
    _deletedIds.addAll(dead);
    _remoteJobIds.removeAll(dead);
    _syncedIds.removeAll(dead);
    return before != _all.length || added;
  }

  Future<void> _pullRemoteCalibrations({
    List<Map<String, dynamic>>? seed,
    List<String>? seedDeletedIds,
  }) async {
    try {
      List<Map<String, dynamic>> rows;
      var tombstones = seedDeletedIds ?? const <String>[];
      if (seed != null) {
        rows = seed;
      } else {
        final result = await AccountApi.instance.listCalibrationJobs();
        if (!result.ok) return;
        rows = result.calibrations;
        tombstones = result.deletedCalibrationIds;
      }
      var changed = _applyRemoteTombstones(tombstones);
      for (final item in rows) {
        final incoming = CalibrationJob.fromJson(item);
        if (incoming.id.isEmpty) continue;
        _remoteJobIds.add(incoming.id);
        if (_deletedIds.contains(incoming.id)) continue;

        // Fantasma na nuvem: já temos certificado mais forte (mesmo nº/slot).
        final peer = _strongerPeer(incoming);
        if (incoming.isEmptyGhost && peer != null) {
          debugPrint(
            'CalibrationStore pull: ignora fantasma ${incoming.number} '
            '(mantém ${peer.number} ${peer.status.name})',
          );
          continue;
        }

        final existing = byId(incoming.id);
        if (existing == null) {
          _all.add(incoming);
          _syncedIds.add(incoming.id);
          changed = true;
          continue;
        }

        // done local nunca perde para rascunho vazio remoto (mesmo com data nova).
        if (existing.integrityScore > incoming.integrityScore &&
            (existing.hasMeasurements ||
                existing.status == CalibrationJobStatus.done) &&
            incoming.isEmptyGhost) {
          debugPrint(
            'CalibrationStore pull: preserva ${existing.number} '
            '(${existing.status.name}) contra sync vazio',
          );
          _syncedIds.remove(incoming.id);
          continue;
        }

        final inAt = incoming.updatedAt ?? incoming.createdAt;
        final exAt = existing.updatedAt ?? existing.createdAt;
        final replace = inAt.isAfter(exAt) ||
            (_jobHasMeasurements(incoming) && !_jobHasMeasurements(existing)) ||
            incoming.integrityScore > existing.integrityScore;
        if (replace) {
          final idx = _all.indexWhere((j) => j.id == incoming.id);
          if (idx >= 0) {
            _all[idx] = _preserveMeasurements(incoming, existing);
            changed = true;
          }
        }
        // Só conta como "igual à nuvem" quando nada local ficou de fora dela.
        final cloudHasAll = replace
            ? (_jobHasMeasurements(incoming) || !_jobHasMeasurements(existing))
            : inAt.isAtSameMomentAs(exAt);
        if (cloudHasAll) {
          _syncedIds.add(incoming.id);
        } else {
          _syncedIds.remove(incoming.id);
        }
      }
      if (changed) {
        await _persist();
      } else {
        await _writeIdLists();
      }
      for (final job in List<CalibrationJob>.from(_all)) {
        if (!_remoteJobIds.contains(job.id) && !_deletedIds.contains(job.id)) {
          if (shouldRefuseRemotePush(job)) {
            debugPrint('CalibrationStore: não reenvia fantasma ${job.number}');
            continue;
          }
          unawaited(pushRemoteJob(job));
        }
      }
    } catch (error) {
      debugPrint('CalibrationStore pull: $error');
    }
  }

  Future<AccountResult> pushRemoteJob(CalibrationJob job) async {
    if (shouldRefuseRemotePush(job)) {
      debugPrint(
        'CalibrationStore push recusado: fantasma ${job.number} '
        '(já existe certificado mais completo)',
      );
      return const AccountResult(
        ok: false,
        error: 'Rascunho vazio não sobrescreve certificado já preenchido',
      );
    }
    try {
      final result = await AccountApi.instance.saveCalibrationJob({
        'id': job.id,
        'number': job.number,
        'kind': job.kind.name,
        'clientName': job.clientName,
        'payload': jsonEncode(job.toJson()),
        'updatedAt': (job.updatedAt ?? job.createdAt).toIso8601String(),
      });
      if (result.ok) {
        _remoteJobIds.add(job.id);
        if (identical(byId(job.id), job)) _syncedIds.add(job.id);
        unawaited(_writeIdLists());
        notifyListeners();
      }
      return result;
    } catch (error) {
      debugPrint('CalibrationStore push: $error');
      return AccountResult(ok: false, error: '$error');
    }
  }

  Future<void> _deleteRemoteJob(String id) async {
    try {
      await AccountApi.instance.deleteCalibrationJob(id);
      _remoteJobIds.remove(id);
    } catch (error) {
      debugPrint('CalibrationStore delete: $error');
    }
  }

  CalibrationJob? byId(String id) {
    for (final job in _all) {
      if (job.id == id) return job;
    }
    return null;
  }

  CalibrationJob? byNumber(String number) {
    final needle = number.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final job in _all) {
      if (job.number.trim().toLowerCase() == needle) return job;
    }
    return null;
  }

  /// Certificado ligado ao slot. Com [osId]/[osNumber], não cruza OS
  /// (evita Phoenix puxar job de Rio Verde pelo mesmo nº de certificado).
  CalibrationJob? jobForSlot(
    OsCalibrationSlot slot, {
    String? osId,
    String? osNumber,
  }) {
    bool belongs(CalibrationJob job) {
      return calibrationJobBelongsToOs(
        job,
        osId: osId ?? '',
        osNumber: osNumber ?? '',
        slotId: slot.id,
      );
    }

    // Vários jobs no mesmo slot (rascunho criado por outro aparelho): vale o
    // mais completo, senão a lista mostrava "Em andamento" com o done salvo.
    CalibrationJob? best;
    void consider(CalibrationJob job) {
      final current = best;
      if (current == null ||
          job.isStrongerThan(current) ||
          (job.integrityScore == current.integrityScore &&
              (job.updatedAt ?? job.createdAt).isAfter(
                current.updatedAt ?? current.createdAt,
              ))) {
        best = job;
      }
    }

    if (slot.jobId.trim().isNotEmpty) {
      final found = byId(slot.jobId);
      if (found != null && belongs(found)) consider(found);
    }
    final slotId = slot.id.trim();
    if (slotId.isNotEmpty) {
      for (final job in _all) {
        if (job.calibrationSlotId.trim() == slotId && belongs(job)) {
          consider(job);
        }
      }
    }
    if (best != null) return best;
    if (slot.certificateNumber.trim().isNotEmpty) {
      final needle = slot.certificateNumber.trim().toLowerCase();
      CalibrationJob? byNumberSameOs;
      for (final job in _all) {
        if (job.number.trim().toLowerCase() != needle) continue;
        if (!belongs(job)) continue;
        final jSlot = job.calibrationSlotId.trim();
        // Nº igual mas slot diferente na mesma OS → não reutiliza o job
        // (abria sobressalente e caía na calibração de outro certificado).
        if (slotId.isNotEmpty && jSlot.isNotEmpty && jSlot != slotId) {
          continue;
        }
        if (slotId.isNotEmpty && jSlot == slotId) return job;
        if (job.osId.trim().isNotEmpty || job.osNumber.trim().isNotEmpty) {
          if (byNumberSameOs == null || job.isStrongerThan(byNumberSameOs)) {
            byNumberSameOs = job;
          }
        }
      }
      return byNumberSameOs;
    }
    return null;
  }

  String _prefixFor(CalibrationKind kind) {
    return switch (kind) {
      CalibrationKind.volumetric => 'GS-VOL',
      CalibrationKind.volumetricInverted => 'GS-VOLI',
      CalibrationKind.temperature => 'GS-TEMP',
      CalibrationKind.temperatureMesh => 'GS-MALHA',
      CalibrationKind.density => 'GS-DENS',
      CalibrationKind.pressure => 'GS-PRESS',
      CalibrationKind.conductivity => 'GS-COND',
      CalibrationKind.telemetry => 'GS-TEL',
    };
  }

  /// Próximo número do certificado. Considera calibrações salvas, slots nas OS
  /// e números já reservados nesta edição (`reserved`).
  String nextNumber(
    CalibrationKind kind, {
    Iterable<String> reserved = const [],
  }) {
    final year = DateTime.now().year;
    final prefix = _prefixFor(kind);
    final needle = '$prefix-$year-';
    var max = 0;

    void consider(String raw) {
      final number = raw.trim();
      if (!number.startsWith(needle)) return;
      final tail = int.tryParse(number.substring(needle.length)) ?? 0;
      if (tail > max) max = tail;
    }

    for (final job in _all) {
      if (job.kind != kind) continue;
      consider(job.number);
    }
    for (final os in FieldStore.instance.officeItems) {
      for (final slot in os.calibrationSlots) {
        if (calibrationKindFrom(slot.kind) != kind) continue;
        consider(slot.certificateNumber);
      }
    }
    for (final item in reserved) {
      consider(item);
    }
    return '$needle${(max + 1).toString().padLeft(4, '0')}';
  }

  Future<CalibrationJob> save(
    CalibrationJob job, {
    bool pushRemote = true,
  }) async {
    await load();
    var stored = job;
    if (stored.number.trim().isEmpty) {
      stored = stored.copyWith(number: nextNumber(stored.kind));
    }
    final previous = byId(stored.id);
    stored = _preserveMeasurements(stored, previous);

    // Não deixa rascunho vazio “tomar” o id de um certificado done no mesmo nº.
    final numberKey = stored.number.trim().toLowerCase();
    if (numberKey.isNotEmpty) {
      final clash = byNumber(stored.number);
      if (clash != null && clash.id != stored.id) {
        final sameOs =
            stored.osId.trim().isNotEmpty &&
            clash.osId.trim().isNotEmpty &&
            stored.osId.trim() == clash.osId.trim();
        final bothOrphan =
            stored.osId.trim().isEmpty && clash.osId.trim().isEmpty;
        final storedSlot = stored.calibrationSlotId.trim();
        final clashSlot = clash.calibrationSlotId.trim();
        final sameSlot =
            storedSlot.isNotEmpty &&
            clashSlot.isNotEmpty &&
            storedSlot == clashSlot;
        final canMergeSlot =
            sameSlot || storedSlot.isEmpty || clashSlot.isEmpty;
        if ((sameOs || bothOrphan) && canMergeSlot) {
          if (clash.isStrongerThan(stored) && stored.isEmptyGhost) {
            if (sameSlot) {
              // Slot já tem certificado forte — não cria fantasma nem renumera o slot.
              return clash;
            }
            // Outro contexto com mesmo nº: novo número, não mexe no done.
            stored = stored.copyWith(number: nextNumber(stored.kind));
          } else {
            // Mesma OS/slot (ou ambos sem OS): atualiza o existente.
            stored = _preserveMeasurements(
              stored.copyWith(id: clash.id),
              clash,
            );
          }
        } else {
          // Outra OS, ou outro slot na mesma OS com o mesmo nº —
          // NÃO funde (abria 0060 e caía no job/dados de 0057 / nº 0146).
          stored = stored.copyWith(number: nextNumber(stored.kind));
        }
      }
    }
    final becameDone =
        stored.status == CalibrationJobStatus.done &&
        previous?.status != CalibrationJobStatus.done;
    stored = stored.copyWith(updatedAt: DateTime.now());
    _deletedIds.remove(stored.id);
    final next = <CalibrationJob>[];
    var found = false;
    var dropStoredGhost = false;
    CalibrationJob? keptStronger;
    final finalNumberKey = stored.number.trim().toLowerCase();
    for (final item in _all) {
      if (item.id == stored.id) {
        next.add(stored);
        found = true;
      } else if (finalNumberKey.isNotEmpty &&
          item.number.trim().toLowerCase() == finalNumberKey &&
          item.osId.trim().isNotEmpty &&
          stored.osId.trim().isNotEmpty &&
          item.osId.trim() == stored.osId.trim()) {
        // Duplicata na mesma OS: se a antiga é mais forte e o novo é fantasma, mantém a antiga.
        if (item.isStrongerThan(stored) && stored.isEmptyGhost) {
          next.add(item);
          dropStoredGhost = true;
          keptStronger = item;
          continue;
        }
        // Duplicata fraca: descarta.
        continue;
      } else {
        next.add(item);
      }
    }
    if (!found && !dropStoredGhost) next.add(stored);
    _all = next;
    if (!dropStoredGhost) _syncedIds.remove(stored.id);
    _sort();
    await _persist();
    final effective = dropStoredGhost ? (keptStronger ?? stored) : stored;
    if (becameDone && !dropStoredGhost) {
      unawaited(_backupDoneJob(stored));
    }
    if (pushRemote && !dropStoredGhost) {
      final push = await pushRemoteJob(stored);
      if (!push.ok && AccountApi.useRemote) {
        debugPrint('CalibrationStore push após save: ${push.error}');
      }
    }
    notifyListeners();
    if (!dropStoredGhost) {
      unawaited(
        FieldStore.instance.syncSlotFromSavedJob(stored, knownJobs: _all),
      );
    }
    return effective;
  }

  /// Vários saves sem gravar o localStorage a cada um (evita QuotaExceeded).
  Future<T> runPersistBatch<T>(Future<T> Function() body) async {
    _persistBatchDepth++;
    try {
      return await body();
    } finally {
      _persistBatchDepth--;
      if (_persistBatchDepth == 0 && _persistDirty) {
        await _persist();
        _persistDirty = false;
      }
    }
  }

  Future<void> delete(String id) async {
    await load();
    _deletedIds.add(id);
    _syncedIds.remove(id);
    _all = [
      for (final item in _all)
        if (item.id != id) item,
    ];
    await _writeIdLists();
    unawaited(_deleteRemoteJob(id));
    notifyListeners();
    try {
      await _persist();
    } on StateError catch (error) {
      // A exclusão já está gravada na lista de excluídos; o cache volta a
      // caber quando a nuvem responder.
      debugPrint('CalibrationStore delete persist: $error');
    }
  }

  Future<void> _writeIdLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_deletedKey, _deletedIds.toList());
      await prefs.setStringList(_syncedIdsKey, _syncedIds.toList());
    } catch (_) {}
  }

  void _sort() {
    _all.sort((a, b) {
      final aAt = a.updatedAt ?? a.createdAt;
      final bAt = b.updatedAt ?? b.createdAt;
      return bAt.compareTo(aAt);
    });
  }

  List<Map<String, dynamic>> _encodeJobs(Iterable<CalibrationJob> jobs) {
    return [for (final job in jobs) job.toJson(slimMeasurements: false)];
  }

  Future<void> _persist() async {
    if (_persistBatchDepth > 0) {
      _persistDirty = true;
      return;
    }
    Future<bool> write(List<Map<String, dynamic>> payload) async {
      final ok = await writePrefsJson(_key, payload);
      if (!ok) return false;
      await _writeIdLists();
      return true;
    }

    // Nunca grava medições vazias de propósito (slim). Se a cota encher,
    // tira do cache local os jobs remotos mais antigos — eles voltam do pull.
    if (await write(_encodeJobs(_all))) return;
    await dropBloatedLocalCaches();
    if (await write(_encodeJobs(_all))) return;

    final remoteOldest =
        [
          for (final job in _all)
            if (_syncedIds.contains(job.id)) job,
        ]..sort((a, b) {
          final aAt = a.updatedAt ?? a.createdAt;
          final bAt = b.updatedAt ?? b.createdAt;
          return aAt.compareTo(bAt);
        });
    var keepIds = {for (final job in _all) job.id};
    for (final drop in remoteOldest) {
      if (keepIds.length <= 8) break;
      keepIds.remove(drop.id);
      final subset = [
        for (final job in _all)
          if (keepIds.contains(job.id)) job,
      ];
      if (await write(_encodeJobs(subset))) return;
    }

    throw StateError(
      'Memória do navegador cheia (localStorage). '
      'Feche abas do GS Campo, limpe dados do site (Ctrl+Shift+Del) '
      'ou use outro navegador e sincronize de novo. '
      'Os certificados na nuvem não são apagados — '
      'não use “atualizar do cadastro” até liberar espaço.',
    );
  }
}
