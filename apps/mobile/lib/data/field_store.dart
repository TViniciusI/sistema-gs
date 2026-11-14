import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/data/field_files.dart'
    if (dart.library.io) 'package:gs_mobile/data/field_files_io.dart'
    if (dart.library.js_interop) 'package:gs_mobile/data/field_files_web.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/cloud_sync_gate.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/prefs_json.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Erro de sync com mensagem limpa (sem prefixo "Bad state:" / "Exception:").
class CloudSyncException implements Exception {
  CloudSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PendingCatalogSubmission {
  const PendingCatalogSubmission({
    required this.os,
    required this.slot,
    required this.slotIndex,
  });

  final SavedOs os;
  final OsCalibrationSlot slot;
  final int slotIndex;
}

class FieldStore extends ChangeNotifier {
  FieldStore._();
  static final instance = FieldStore._();

  static const _sharedKey = 'gs_work_orders_v2';
  static const _deletedRdosKey = 'gs_deleted_rdos_v1';
  static const _deletedOsKey = 'gs_deleted_os_ids_v1';
  // v3: marcas anteriores vieram de junções que somavam certificados apagados
  // em outro aparelho; trocar a chave obriga a baixar a OS completa de novo.
  static const _fullStampKey = 'gs_os_full_stamp_v3';
  static const _legacyKeys = [
    'gs_os_full_stamp_v1',
    'gs_os_full_stamp_v2',
    'gs_os_slots_pending_v1',
  ];
  static const _slotEditsKey = 'gs_os_slot_edits_v1';
  static const _slotDeletesKey = 'gs_os_slot_deletes_v1';
  static const _rdosPendingKey = 'gs_os_rdos_pending_v1';

  final _files = createFieldFiles();
  final _memoryBytes = <String, Uint8List>{};
  final _deletedRdoIds = <String, Set<String>>{};
  final _deletedOsIds = <String>{};

  /// OS grande: a listagem traz só um resumo (sem RDOs, slots enxutos).
  /// id → updatedAt do resumo recebido.
  final _lightStamp = <String, String>{};

  /// id → updatedAt do resumo já completado com getos neste aparelho.
  final _fullStamp = <String, String>{};
  var _hydratingLight = false;

  /// osId → certificados criados/alterados aqui que a nuvem ainda não tem.
  /// Marca por certificado: marcar a OS inteira tornava "pendentes" cópias
  /// velhas apagadas em outro aparelho, e elas voltavam.
  final _slotEdits = <String, Set<String>>{};

  /// osId → certificados removidos aqui que a nuvem ainda tem.
  final _slotDeletes = <String, Set<String>>{};

  /// Já puxou a nuvem nesta sessão: antes disso a cópia do aparelho pode
  /// estar velha e não pode substituir a lista de certificados na nuvem.
  var _pulledOnce = false;

  /// osId → RDOs gravados aqui que a nuvem ainda não confirmou. RDO que só
  /// existe no aparelho e não está aqui foi apagado na nuvem.
  final _rdosPending = <String, Set<String>>{};

  String? _viewerEmail;
  var _seeAll = false;
  var _viewerIds = <String>{};
  List<SavedOs> _all = [];

  List<SavedOs> get officeItems => List<SavedOs>.unmodifiable(_all);

  List<SavedOs> get items {
    final email = _viewerEmail;
    if (email == null) return const [];
    if (_seeAll) {
      return [
        for (final os in _all)
          if (os.status != OsStatus.rascunho) os,
      ];
    }
    return [
      for (final os in _all)
        if (os.isAssignedToAny(_viewerIds) && os.status != OsStatus.rascunho)
          os,
    ];
  }

  List<SavedOs> get pendingItems => [
    for (final os in items)
      if (os.canFillRdo) os,
  ];

  Future<void> load(
    String ownerEmail, {
    bool seeAll = false,
    String login = '',
    Iterable<String> aliases = const [],
    Set<String>? viewerIds,
    List<Map<String, dynamic>>? remoteOrders,
  }) async {
    _viewerEmail = ownerEmail;
    _seeAll = seeAll;
    _viewerIds =
        viewerIds ??
        assignmentIdsFor(email: ownerEmail, login: login, aliases: aliases);
    // Após o snapshot do login, home/calibração remonta e não precisa
    // reler prefs + rede de novo (isso deixava o app lento).
    if (_all.isNotEmpty && remoteOrders == null && CloudSyncGate.isFresh) {
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gs_work_orders');
    await prefs.remove(_legacyKey(ownerEmail));
    final raw = await readPrefsString(_sharedKey);
    await _loadDeletedRdoIds();
    await _loadDeletedOsIds();
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
    await _loadFullStamps(prefs);
    _readIdMap(prefs, _slotEditsKey, _slotEdits);
    _readIdMap(prefs, _slotDeletesKey, _slotDeletes);
    if (raw == null || raw.isEmpty) {
      _all = [];
      _fullStamp.clear();
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          _all = [];
        } else {
          final loaded = <SavedOs>[];
          for (final item in decoded) {
            if (item is! Map) continue;
            try {
              final os = SavedOs.fromJson(Map<String, dynamic>.from(item));
              if (os.id.isEmpty || _deletedOsIds.contains(os.id)) continue;
              loaded.add(os);
            } catch (error) {
              debugPrint('FieldStore skip local OS: $error');
            }
          }
          _all = loaded;
        }
      } catch (error) {
        debugPrint('FieldStore local: $error');
      }
    }
    _loadRdosPending(prefs);
    // Anexos sob demanda ao abrir OS / gerar PDF — não no boot.
    if (remoteOrders != null || !CloudSyncGate.isFresh) {
      await _pullRemote(seed: remoteOrders);
    }
    notifyListeners();
    // Hidrata anexos em segundo plano (não trava a tela inicial).
    unawaited(_hydrateAllFilesInBackground());
  }

  Future<void> sync() async {
    await _pullRemote();
    CloudSyncGate.markSynced();
    notifyListeners();
  }

  Future<void> _hydrateAllFilesInBackground() async {
    final snapshot = List<SavedOs>.from(_all);
    for (final os in snapshot) {
      await hydrateOsFiles(os);
    }
  }

  /// Carrega bytes de anexos da OS (lazy; evita boot lento).
  Future<void> hydrateOsFiles(SavedOs os) async {
    for (final file in os.files) {
      await _hydrate(file);
    }
    for (final entry in os.rdos) {
      for (final file in entry.files) {
        await _hydrate(file);
      }
    }
  }

  /// Busca na nuvem o JSON completo das OS sem certificados (stubs leves).
  Future<int> hydrateMissingCalibrationSlots({int limit = 16}) async {
    final targets = [
      for (final os in _all)
        if (os.calibrationSlots.isEmpty) os,
    ];
    if (targets.isEmpty) return 0;
    var filled = 0;
    final chunk = targets.take(limit).toList();
    await Future.wait([
      for (final os in chunk)
        () async {
          try {
            final result = await AccountApi.instance.getWorkOrder(os.id);
            if (!result.ok || result.orders.isEmpty) return;
            final raw = result.orders.first;
            final incoming = _osFromRemote(raw);
            if (incoming == null || incoming.calibrationSlots.isEmpty) return;
            final existing = byId(os.id);
            if (existing == null) return;
            _upsert(
              _mergeOs(
                existing,
                incoming,
                summary: raw['rdos'] is! List,
                slimSlots: _hasSlimSlots(raw),
              ),
            );
            filled++;
          } catch (error) {
            debugPrint('FieldStore hydrate ${os.number}: $error');
          }
        }(),
    ]);
    if (filled > 0) {
      await _persist();
      notifyListeners();
    }
    return filled;
  }

  /// Garante a OS completa (RDOs e slots) ao abrir a ficha.
  Future<SavedOs?> hydrateOs(String osId) async {
    final current = byId(osId);
    if (current == null) return null;
    if (current.calibrationSlots.isNotEmpty && !needsFullOs(osId)) {
      return current;
    }
    return await _fetchFullOs(osId) ?? byId(osId) ?? current;
  }

  /// A OS no aparelho ainda é o resumo da listagem (faltam RDOs/slots completos).
  bool needsFullOs(String osId) {
    final stamp = _lightStamp[osId];
    return stamp != null && _fullStamp[osId] != stamp;
  }

  static bool _isLightRemote(Map<String, dynamic> json) =>
      json['_payloadLight'] == true || jsonText(json['_fileId']).isNotEmpty;

  static const _slimSlotKeys = {
    'id',
    'kind',
    'certificateNumber',
    'serialNumber',
    'equipmentTag',
    'jobId',
  };

  /// Certificados no formato do resumo da planilha (só 6 campos). O completo
  /// sempre grava todos os campos; a nuvem já regravou OS inteiras assim.
  static bool _hasSlimSlots(Map<String, dynamic> json) {
    final slots = json['calibrationSlots'];
    if (slots is! List || slots.isEmpty) return false;
    return slots.every(
      (slot) => slot is Map && slot.keys.every(_slimSlotKeys.contains),
    );
  }

  Future<SavedOs?> _fetchFullOs(String osId) async {
    final stamp = _lightStamp[osId];
    try {
      final result = await AccountApi.instance.getWorkOrder(osId);
      if (!result.ok || result.orders.isEmpty) return null;
      final raw = result.orders.first;
      final incoming = _osFromRemote(raw);
      final current = byId(osId);
      if (incoming == null || current == null) return null;
      final merged = _mergeOs(
        current,
        incoming,
        summary: raw['rdos'] is! List,
        slimSlots: _hasSlimSlots(raw),
      );
      _upsert(merged);
      if (stamp != null) {
        _fullStamp[osId] = stamp;
        await _saveFullStamps();
      }
      await _persist();
      notifyListeners();
      _publishIfRicher(merged, incoming);
      return merged;
    } catch (error) {
      debugPrint('FieldStore full OS $osId: $error');
      return null;
    }
  }

  /// Completa em segundo plano as OS que chegaram como resumo (abertas primeiro).
  Future<void> _hydrateLightOrders() async {
    if (_hydratingLight) return;
    _hydratingLight = true;
    try {
      final targets =
          [
            for (final os in _all)
              if (needsFullOs(os.id)) os,
          ]..sort((a, b) {
            final closedA = _isClosedStatus(a.status) ? 1 : 0;
            final closedB = _isClosedStatus(b.status) ? 1 : 0;
            if (closedA != closedB) return closedA - closedB;
            return b.lastUpdatedAt.compareTo(a.lastUpdatedAt);
          });
      for (final os in targets) {
        if (!needsFullOs(os.id)) continue;
        await _fetchFullOs(os.id);
      }
    } finally {
      _hydratingLight = false;
    }
  }

  Future<void> _loadFullStamps(SharedPreferences prefs) async {
    _fullStamp.clear();
    final raw = prefs.getString(_fullStampKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        _fullStamp['$key'] = '$value';
      });
    } catch (error) {
      debugPrint('FieldStore full stamps: $error');
    }
  }

  Future<void> _saveFullStamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fullStampKey, jsonEncode(_fullStamp));
    } catch (error) {
      debugPrint('FieldStore full stamps save: $error');
    }
  }

  void _loadRdosPending(SharedPreferences prefs) {
    _rdosPending.clear();
    final raw = prefs.getString(_rdosPendingKey);
    if (raw == null) {
      // Primeira vez com o registro: RDO recente que ainda não subiu continua
      // protegido (versões anteriores não anotavam o envio pendente).
      final since = DateTime.now().subtract(const Duration(days: 3));
      for (final os in _all) {
        for (final entry in os.rdos) {
          if (entry.createdAt.isAfter(since)) {
            _rdosPending.putIfAbsent(os.id, () => {}).add(entry.id);
          }
        }
      }
      unawaited(_saveRdosPending());
      return;
    }
    _readIdMap(prefs, _rdosPendingKey, _rdosPending);
  }

  static void _readIdMap(
    SharedPreferences prefs,
    String key,
    Map<String, Set<String>> into,
  ) {
    into.clear();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((osId, value) {
        if (value is! List) return;
        final ids = {
          for (final id in value)
            if ('$id'.trim().isNotEmpty) '$id'.trim(),
        };
        if (ids.isNotEmpty) into['$osId'] = ids;
      });
    } catch (error) {
      debugPrint('FieldStore $key: $error');
    }
  }

  static String _idMapJson(Map<String, Set<String>> map) => jsonEncode({
    for (final entry in map.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
  });

  Future<void> _saveSlotMarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_slotEditsKey, _idMapJson(_slotEdits));
      await prefs.setString(_slotDeletesKey, _idMapJson(_slotDeletes));
    } catch (error) {
      debugPrint('FieldStore slot marks save: $error');
    }
  }

  static String _slotJson(OsCalibrationSlot slot) => jsonEncode(slot.toJson());

  /// Anota o que mudou nos certificados desta OS neste aparelho (só o que
  /// mudou: o resto continua valendo como está na nuvem).
  Future<void> _noteSlotEdits(
    String osId,
    List<OsCalibrationSlot> before,
    List<OsCalibrationSlot> after,
  ) async {
    final old = {for (final slot in before) slot.id: _slotJson(slot)};
    final now = {for (final slot in after) slot.id};
    final edits = _slotEdits.putIfAbsent(osId, () => {});
    final deletes = _slotDeletes.putIfAbsent(osId, () => {});
    for (final slot in after) {
      if (slot.id.trim().isEmpty) continue;
      if (old[slot.id] == _slotJson(slot)) continue;
      edits.add(slot.id);
      deletes.remove(slot.id);
    }
    for (final id in old.keys) {
      if (id.trim().isEmpty || now.contains(id)) continue;
      deletes.add(id);
      edits.remove(id);
    }
    if (edits.isEmpty) _slotEdits.remove(osId);
    if (deletes.isEmpty) _slotDeletes.remove(osId);
    await _saveSlotMarks();
  }

  /// Nuvem confirmou: tira as marcas do que ela já tem igual.
  void _confirmSlots(String osId, Map<String, String> cloudJsonById) {
    final edits = _slotEdits[osId];
    final deletes = _slotDeletes[osId];
    if (edits == null && deletes == null) return;
    final local = byId(osId);
    final localJson = {
      for (final slot in local?.calibrationSlots ?? const <OsCalibrationSlot>[])
        slot.id: _slotJson(slot),
    };
    var changed = false;
    if (edits != null) {
      final before = edits.length;
      edits.removeWhere(
        (id) => cloudJsonById[id] != null && cloudJsonById[id] == localJson[id],
      );
      changed |= edits.length != before;
      if (edits.isEmpty) _slotEdits.remove(osId);
    }
    if (deletes != null) {
      final before = deletes.length;
      deletes.removeWhere((id) => !cloudJsonById.containsKey(id));
      changed |= deletes.length != before;
      if (deletes.isEmpty) _slotDeletes.remove(osId);
    }
    if (changed) unawaited(_saveSlotMarks());
  }

  Future<void> _saveRdosPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _rdosPendingKey,
        jsonEncode({
          for (final entry in _rdosPending.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
        }),
      );
    } catch (error) {
      debugPrint('FieldStore rdos pending save: $error');
    }
  }

  Future<void> _markRdoPending(String osId, String rdoId) async {
    if (rdoId.trim().isEmpty) return;
    _rdosPending.putIfAbsent(osId, () => {}).add(rdoId.trim());
    await _saveRdosPending();
  }

  void _clearRdoPending(String osId, Iterable<String> rdoIds) {
    final pending = _rdosPending[osId];
    if (pending == null) return;
    final before = pending.length;
    pending.removeAll(rdoIds);
    if (pending.isEmpty) _rdosPending.remove(osId);
    if (pending.length != before) unawaited(_saveRdosPending());
  }

  void clear() {
    _viewerEmail = null;
    _seeAll = false;
    _viewerIds = {};
    _all = [];
    _deletedOsIds.clear();
    _lightStamp.clear();
    _pulledOnce = false;
    notifyListeners();
  }

  /// Apaga OS criada por engano (local + nuvem). Escritório.
  Future<void> deleteOs(String osId) async {
    final id = osId.trim();
    if (id.isEmpty) throw CloudSyncException('OS sem id');
    _deletedOsIds.add(id);
    _all = [
      for (final os in _all)
        if (os.id != id) os,
    ];
    _deletedRdoIds.remove(id);
    _rdosPending.remove(id);
    unawaited(_saveRdosPending());
    _slotEdits.remove(id);
    _slotDeletes.remove(id);
    unawaited(_saveSlotMarks());
    await _persistDeletedOsIds();
    await _persistDeletedRdoIds();
    await _persist();
    notifyListeners();
    try {
      final result = await AccountApi.instance.deleteWorkOrder(id);
      if (!result.ok) {
        throw CloudSyncException(
          result.error ??
              'Não apagou a OS na nuvem. Tente sincronizar de novo.',
        );
      }
    } catch (error) {
      if (error is CloudSyncException) rethrow;
      throw CloudSyncException('$error');
    }
  }

  /// Atualiza o escopo sem recarregar (ex.: após mudança de permissão / tela de calibração).
  void applyViewerAccess({required bool seeAll}) {
    if (_seeAll == seeAll) return;
    _seeAll = seeAll;
    notifyListeners();
  }

  List<SavedOs> search(String query) {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return items;
    return items
        .where((item) => item.number.toLowerCase().contains(value))
        .toList();
  }

  SavedOs? byId(String id) {
    for (final item in _all) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<SavedOs> saveOs({
    required String number,
    required List<DraftFile> files,
    String? existingId,
    String? signerName,
    RdoData? rdo,
    String? technicianEmail,
    String? technicianName,
    List<String>? technicianEmails,
    OsStatus? status,
    List<SavedRdo>? rdos,
    DateTime? startsAt,
    List<OsCalibrationSlot>? calibrationSlots,
  }) async {
    final owner = _viewerEmail;
    if (owner == null) {
      throw StateError('Nenhum usuário logado');
    }
    final trimmed = number.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Informe o número da OS');
    }
    final existing = existingId == null ? null : byId(existingId);
    final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _deletedOsIds.remove(id);
    final savedFiles = await _persistFiles(
      ownerEmail: owner,
      osId: id,
      files: files,
    );
    final record = SavedOs(
      id: id,
      number: trimmed,
      ownerEmail: existing?.ownerEmail ?? owner,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      files: savedFiles,
      emailed: existing?.emailed ?? false,
      signerName: signerName?.trim().isEmpty == true
          ? null
          : signerName?.trim(),
      rdo: rdo ?? existing?.rdo ?? const RdoData(),
      technicianEmail: technicianEmail ?? existing?.technicianEmail ?? '',
      technicianName: technicianName ?? existing?.technicianName ?? '',
      technicianEmails:
          technicianEmails ?? existing?.technicianEmails ?? const [],
      status: status ?? existing?.status ?? OsStatus.rascunho,
      rdos: rdos ?? existing?.rdos ?? const [],
      startsAt: startsAt ?? existing?.startsAt,
      calibrationSlots: dedupeCalibrationSlotsByCertificateNumber(
        calibrationSlots ?? existing?.calibrationSlots ?? const [],
      ),
    );
    await _noteSlotEdits(
      id,
      existing?.calibrationSlots ?? const [],
      record.calibrationSlots,
    );
    _upsert(record);
    await _persist();
    await ClientStore.instance.upsertFromRdo(record.rdo, syncRemote: false);
    _ensureRemoteOk(await _pushRemote(record), 'salvar a OS');
    notifyListeners();
    return record;
  }

  Future<SavedOs> saveCalibrationSlots({
    required String osId,
    required List<OsCalibrationSlot> slots,
  }) async {
    final os = byId(osId);
    if (os == null) throw StateError('OS não encontrada');
    final unique = dedupeCalibrationSlotsByCertificateNumber(slots);
    final next = os.copyWith(calibrationSlots: unique, touchUpdatedAt: true);
    await _noteSlotEdits(osId, os.calibrationSlots, next.calibrationSlots);
    _upsert(next);
    await _persist();
    _ensureRemoteOk(await _pushRemote(next), 'salvar os certificados da OS');
    notifyListeners();
    return next;
  }

  /// Marca quem está com a OS aberta (trava leve entre aparelhos).
  Future<SavedOs?> claimCalibrationEdit({
    required String osId,
    required String email,
  }) async {
    final os = byId(osId);
    if (os == null) return null;
    final me = email.trim().toLowerCase();
    if (me.isEmpty) return os;
    if (os.calibrationEditHeldByOther(me)) return os;
    final next = os.copyWith(
      calibrationEditBy: me,
      calibrationEditAt: DateTime.now(),
    );
    _upsert(next);
    await _persist();
    unawaited(_pushRemote(next));
    notifyListeners();
    return next;
  }

  Future<void> releaseCalibrationEdit({
    required String osId,
    required String email,
  }) async {
    final os = byId(osId);
    if (os == null) return;
    final me = email.trim().toLowerCase();
    if (me.isEmpty) return;
    if (os.calibrationEditBy.trim().toLowerCase() != me) return;
    final next = os.copyWith(clearCalibrationEdit: true);
    _upsert(next);
    await _persist();
    unawaited(_pushRemote(next));
    notifyListeners();
  }

  /// Slots cujo jobId aponta para número diferente (nuvem/local bagunçados).
  List<String> calibrationSlotMismatches(
    SavedOs os,
    Iterable<CalibrationJob> jobs,
  ) {
    final byId = {for (final j in jobs) j.id: j};
    final out = <String>[];
    for (final slot in os.calibrationSlots) {
      final jobId = slot.jobId.trim();
      if (jobId.isEmpty) continue;
      final job = byId[jobId];
      if (job == null) continue;
      final slotNum = slot.certificateNumber.trim().toLowerCase();
      final jobNum = job.number.trim().toLowerCase();
      if (slotNum.isNotEmpty && jobNum.isNotEmpty && slotNum != jobNum) {
        out.add('${slot.certificateNumber} → ${job.number}');
      }
    }
    return out;
  }

  /// Atualiza slots de calibração quando o cadastro do cliente muda.
  Future<void> refreshCalibrationSlotsForClient(SavedClient client) async {
    if (!_pulledOnce) return;
    final changedIds = <String>{};
    final next = <SavedOs>[];
    for (final os in _all) {
      // Resumo da listagem tem slots enxutos: sempre "mudaria" e o envio
      // trocaria os certificados completos da nuvem.
      if (os.calibrationSlots.isEmpty || needsFullOs(os.id)) {
        next.add(os);
        continue;
      }
      final match = _osMatchesClient(os, client);
      if (!match) {
        next.add(os);
        continue;
      }
      final refreshed = refreshOsCalibrationSlots(
        slots: os.calibrationSlots,
        client: client,
        installLocation: os.rdo.site,
        systemType: os.rdo.systemType,
        jobs: const [],
      );
      if (!_sameCalibrationSlots(os.calibrationSlots, refreshed)) {
        changedIds.add(os.id);
        await _noteSlotEdits(os.id, os.calibrationSlots, refreshed);
        next.add(os.copyWith(calibrationSlots: refreshed));
      } else {
        next.add(os);
      }
    }
    if (changedIds.isEmpty) return;
    _all = next;
    await _persist();
    for (final os in _all) {
      if (changedIds.contains(os.id)) unawaited(_pushRemote(os));
    }
    notifyListeners();
  }

  Future<SavedOs?> refreshCalibrationSlotsForOs(
    String osId, {
    List<CalibrationJob> jobs = const [],
    bool forceCatalog = false,
    bool onlyFillEmptySerial = false,
  }) async {
    final before = byId(osId);
    if (before == null || before.calibrationSlots.isEmpty) return before;
    if (!_pulledOnce || needsFullOs(osId)) return before;
    await ClientStore.instance.sync();
    // A sincronização pode ter trazido a OS nova da nuvem nesse meio tempo.
    final os = byId(osId);
    if (os == null || os.calibrationSlots.isEmpty) return os;
    final client = ClientStore.instance.findMatch(
      cnpj: os.rdo.cnpj,
      name: os.rdo.client,
    );
    final refreshed = refreshOsCalibrationSlots(
      slots: os.calibrationSlots,
      client: client,
      installLocation: os.rdo.site,
      systemType: os.rdo.systemType,
      jobs: jobs,
      osId: os.id,
      osNumber: os.number,
      forceCatalog: forceCatalog,
      onlyFillEmptySerial: onlyFillEmptySerial,
    );
    if (_sameCalibrationSlots(os.calibrationSlots, refreshed)) return os;
    final next = os.copyWith(calibrationSlots: refreshed);
    await _noteSlotEdits(osId, os.calibrationSlots, refreshed);
    _upsert(next);
    await _persist();
    await _pushRemote(next);
    notifyListeners();
    return next;
  }

  /// Quando um certificado é salvo, copia TAG/N/S para o slot da OS.
  /// [knownJobs] evita dependência circular com CalibrationStore.
  Future<void> syncSlotFromSavedJob(
    CalibrationJob job, {
    List<CalibrationJob> knownJobs = const [],
  }) async {
    SavedOs? os;
    if (job.osId.trim().isNotEmpty) {
      os = byId(job.osId);
    }
    if (os == null && job.osNumber.trim().isNotEmpty) {
      final wantNum = job.osNumber.trim().toLowerCase();
      for (final item in _all) {
        if (item.number.trim().toLowerCase() == wantNum) {
          os = item;
          break;
        }
      }
    }
    // Slot id só — nunca cair no nº do certificado em outra OS.
    if (os == null) {
      final slotId = job.calibrationSlotId.trim();
      if (slotId.isNotEmpty) {
        for (final item in _all) {
          if (item.calibrationSlots.any((s) => s.id == slotId)) {
            os = item;
            break;
          }
        }
      }
    }
    if (os == null) return;
    if (needsFullOs(os.id)) {
      // Resumo tem certificados enxutos: completa antes de mexer.
      await _fetchFullOs(os.id);
      os = byId(os.id);
      if (os == null || needsFullOs(os.id)) return;
    }

    CalibrationJob? jobById(String id) {
      final needle = id.trim();
      if (needle.isEmpty) return null;
      for (final item in knownJobs) {
        if (item.id == needle) return item;
      }
      return null;
    }

    final slotId = job.calibrationSlotId.trim();
    final needle = job.number.trim().toLowerCase();
    final nextSlots = <OsCalibrationSlot>[];
    var changed = false;
    for (final slot in os.calibrationSlots) {
      final matches =
          (slotId.isNotEmpty && slot.id == slotId) ||
          (slotId.isEmpty &&
              needle.isNotEmpty &&
              slot.certificateNumber.trim().toLowerCase() == needle);
      if (!matches) {
        nextSlots.add(slot);
        continue;
      }
      final linked = jobById(slot.jobId);
      // Fantasma não rouba slot de certificado mais forte.
      if (linked != null &&
          linked.id != job.id &&
          linked.isStrongerThan(job) &&
          job.isEmptyGhost) {
        nextSlots.add(slot);
        continue;
      }
      final applied = applyCalibrationJobToOsSlot(slot, job);
      nextSlots.add(applied);
      if (applied.toJson().toString() != slot.toJson().toString()) {
        changed = true;
      }
    }
    if (!changed) return;
    final next = os.copyWith(calibrationSlots: nextSlots, touchUpdatedAt: true);
    await _noteSlotEdits(os.id, os.calibrationSlots, nextSlots);
    _upsert(next);
    await _persist();
    unawaited(_pushRemote(next));
    notifyListeners();
  }

  bool _osMatchesClient(SavedOs os, SavedClient client) {
    final digits = os.rdo.cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty && client.cnpjDigits == digits) return true;
    final name = os.rdo.client.trim().toLowerCase();
    return name.isNotEmpty && client.name.trim().toLowerCase() == name;
  }

  bool _sameCalibrationSlots(
    List<OsCalibrationSlot> a,
    List<OsCalibrationSlot> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].toJson().toString() != b[i].toJson().toString()) return false;
    }
    return true;
  }

  Future<SavedOs> saveRdo({
    required String osId,
    required SavedRdo draft,
    required List<DraftFile> files,
    Map<String, String>? technicianCargos,
    ClientBaseContact? baseSigner,
  }) async {
    final os = byId(osId);
    if (os == null) {
      throw StateError('OS não encontrada');
    }
    if (os.isClosed) {
      throw StateError('Esta OS já foi encerrada');
    }
    final owner = _viewerEmail ?? os.ownerEmail;
    final savedFiles = await _persistFiles(
      ownerEmail: owner,
      osId: '${os.id}_${draft.id}',
      files: files,
    );
    final entry = draft.copyWith(files: savedFiles);
    final rdos = [entry, ...os.rdos.where((item) => item.id != entry.id)]
      ..sort((a, b) => b.date.compareTo(a.date));
    var status = os.status;
    if (status == OsStatus.comTecnico ||
        status == OsStatus.rascunho ||
        status == OsStatus.servicoEncerrado) {
      status = OsStatus.emAndamento;
    }
    var header = technicianCargos == null
        ? os.rdo
        : os.rdo.copyWith(technicianCargos: technicianCargos);
    if (baseSigner != null && baseSigner.hasName) {
      header = header.withBaseContact(baseSigner);
    }
    final record = os.copyWith(
      rdos: rdos,
      status: status,
      rdo: header,
      touchUpdatedAt: true,
    );
    await _markRdoPending(record.id, entry.id);
    _upsert(record);
    await _persist();
    await _pushDailyRdo(record, entry);
    await _pushRemote(record);
    notifyListeners();
    return record;
  }

  Future<SavedOs> replaceRdoEntry(SavedOs os, SavedRdo entry) async {
    final owner = _viewerEmail ?? os.ownerEmail;
    final savedFiles = await _persistFiles(
      ownerEmail: owner,
      osId: '${os.id}_${entry.id}',
      files: [
        for (final file in entry.files)
          DraftFile(
            name: file.name,
            kind: file.kind,
            path: file.path.isEmpty ? null : file.path,
            bytes: bytesFor(file) ?? file.bytes,
            label: file.label,
          ),
      ],
    );
    final stored = entry.copyWith(files: savedFiles);
    final rdos = [stored, ...os.rdos.where((item) => item.id != stored.id)]
      ..sort((a, b) => b.date.compareTo(a.date));
    final record = os.copyWith(rdos: rdos);
    await _markRdoPending(record.id, stored.id);
    _upsert(record);
    await _persist();
    await _pushDailyRdo(record, stored);
    await _pushRemote(record);
    notifyListeners();
    return record;
  }

  Future<SavedOs> removeRdos(String osId, Iterable<String> rdoIds) async {
    final os = byId(osId);
    if (os == null) throw StateError('OS não encontrada');
    if (os.isClosed) {
      throw StateError('Esta OS já foi encerrada');
    }
    final drop = {
      for (final id in rdoIds) id.trim(),
    }.where((id) => id.isNotEmpty).toSet();
    if (drop.isEmpty) return os;
    for (final entry in os.rdos) {
      if (!drop.contains(entry.id)) continue;
      for (final file in entry.files) {
        if (file.path.isNotEmpty) _memoryBytes.remove(file.path);
      }
    }
    final record = os.copyWith(
      rdos: [
        for (final entry in os.rdos)
          if (!drop.contains(entry.id)) entry,
      ],
    );
    _deletedRdoIds.putIfAbsent(osId, () => {}).addAll(drop);
    _clearRdoPending(osId, drop);
    _upsert(record);
    await _persist();
    await _persistDeletedRdoIds();
    await _pushRemote(record);
    notifyListeners();
    return record;
  }

  Future<SavedOs> dispatchToTechnician(String osId) async {
    final os = byId(osId);
    if (os == null) throw StateError('OS não encontrada');
    if (os.assigneeEmails.isEmpty) {
      throw ArgumentError('Escolha pelo menos um técnico desta OS');
    }
    final record = os.copyWith(
      status: os.hasRdo ? OsStatus.emAndamento : OsStatus.comTecnico,
      emailed: true,
      touchUpdatedAt: true,
    );
    _upsert(record);
    await _persist();
    _ensureRemoteOk(await _pushRemote(record), 'enviar a OS ao técnico');
    notifyListeners();
    return record;
  }

  Future<SavedOs> markServiceDone(String osId) async {
    final os = byId(osId);
    if (os == null) throw StateError('OS não encontrada');
    if (!os.hasRdo) {
      throw ArgumentError(
        'Salve pelo menos um RDO antes de encerrar o serviço',
      );
    }
    final record = os.copyWith(
      status: OsStatus.servicoEncerrado,
      touchUpdatedAt: true,
    );
    _upsert(record);
    await _persist();
    _ensureRemoteOk(await _pushRemote(record), 'encerrar o serviço');
    notifyListeners();
    return record;
  }

  Future<SavedOs> closeOs(String osId) async {
    final os = byId(osId);
    if (os == null) throw CloudSyncException('OS não encontrada');
    final record = os.copyWith(
      status: OsStatus.encerrada,
      touchUpdatedAt: true,
    );
    _upsert(record);
    await _persist();
    _ensureRemoteOk(await _pushRemote(record), 'encerrar a OS');
    notifyListeners();
    return record;
  }

  Future<SavedOs> reopenOs(String osId) async {
    final os = byId(osId);
    if (os == null) {
      throw CloudSyncException('OS não encontrada neste aparelho.');
    }
    if (os.status != OsStatus.encerrada &&
        os.status != OsStatus.servicoEncerrado) {
      throw CloudSyncException(
        'Esta OS já está ${osStatusLabel(os.status).toLowerCase()} — não precisa reativar.',
      );
    }
    final status = os.hasRdo ? OsStatus.emAndamento : OsStatus.comTecnico;
    final record = os.copyWith(status: status, touchUpdatedAt: true);
    _upsert(record);
    await _persist();
    notifyListeners();
    final result = await _pushRemote(record);
    if (!result.ok && AccountApi.useRemote) {
      final detail = (result.error ?? '').trim();
      throw CloudSyncException(
        'OS ${record.number} reativada neste aparelho, mas a nuvem não confirmou'
        '${detail.isEmpty ? '' : ': $detail'}. '
        'Cole o login_gate.gs no Apps Script, rode authorizeClientPayloads e publique Nova versão. '
        'Sem isso a outra pessoa continua vendo a OS antiga.',
      );
    }
    return record;
  }

  Future<SavedOs> addOsFiles(String osId, List<DraftFile> extra) async {
    final os = byId(osId);
    if (os == null) throw StateError('OS não encontrada');
    if (extra.isEmpty) return os;
    final owner = _viewerEmail ?? os.ownerEmail;
    final saved = await _persistFiles(
      ownerEmail: owner,
      osId: os.id,
      files: extra,
    );
    final record = os.copyWith(files: [...os.files, ...saved]);
    _upsert(record);
    await _persist();
    await _pushRemote(record);
    notifyListeners();
    return record;
  }

  Future<SavedOs> removeOsFile(String osId, SavedFile file) async {
    final os = byId(osId);
    if (os == null) throw StateError('OS não encontrada');
    final record = os.copyWith(
      files: [
        for (final item in os.files)
          if (item.path != file.path || item.name != file.name) item,
      ],
    );
    if (file.path.isNotEmpty) _memoryBytes.remove(file.path);
    _upsert(record);
    await _persist();
    await _pushRemote(record);
    notifyListeners();
    return record;
  }

  /// Só muda o nome exibido/enviado; o path no aparelho permanece.
  Future<SavedOs> renameOsFile(
    String osId,
    SavedFile file,
    String newName,
  ) async {
    final os = byId(osId);
    if (os == null) throw StateError('OS não encontrada');
    final cleaned = newName.trim();
    if (cleaned.isEmpty || cleaned == file.name) return os;
    final record = os.copyWith(
      files: [
        for (final item in os.files)
          if (item.path == file.path && item.name == file.name)
            SavedFile(
              name: cleaned,
              path: item.path,
              kind: item.kind,
              bytes: item.bytes,
              label: item.label,
              uploadedBy: item.uploadedBy,
            )
          else
            item,
      ],
    );
    _upsert(record);
    await _persist();
    await _pushRemote(record);
    notifyListeners();
    return record;
  }

  /// Anexos da OS que o login atual pode ver (só o que ele anexou).
  List<SavedFile> viewerAttachments(SavedOs os) {
    final me = (_viewerEmail ?? '').trim().toLowerCase();
    return [
      for (final file in os.attachments)
        if (_canSeeOsAttachment(file, me)) file,
    ];
  }

  bool _canSeeOsAttachment(SavedFile file, String viewerEmail) {
    final by = (file.uploadedBy ?? '').trim().toLowerCase();
    if (by.isNotEmpty) {
      return viewerEmail.isNotEmpty && by == viewerEmail;
    }
    final bytes = bytesFor(file);
    return bytes != null && bytes.isNotEmpty;
  }

  /// Remove anexos locais após salvar na pasta da OS (Google Drive).
  Future<SavedOs?> removeOsAttachmentsByNames(
    String osId,
    Iterable<String> names,
  ) async {
    final os = byId(osId);
    if (os == null) return null;
    final drop = {for (final n in names) n.trim().toLowerCase()};
    if (drop.isEmpty) return os;
    final kept = <SavedFile>[];
    for (final file in os.files) {
      final isAttach = file.isOsAttachment;
      final match = drop.contains(file.name.trim().toLowerCase());
      if (isAttach && match) {
        if (file.path.isNotEmpty) _memoryBytes.remove(file.path);
        continue;
      }
      kept.add(file);
    }
    final record = os.copyWith(files: kept);
    _upsert(record);
    await _persist();
    await _pushRemote(record);
    notifyListeners();
    return record;
  }

  Future<void> markEmailed(String id) async {
    final os = byId(id);
    if (os == null) return;
    _upsert(os.copyWith(emailed: true));
    await _persist();
    notifyListeners();
  }

  Uint8List? bytesFor(SavedFile file) {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return Uint8List.fromList(file.bytes!);
    }
    final mem = _memoryBytes[file.path];
    if (mem != null && mem.isNotEmpty) return mem;
    return null;
  }

  bool hasLocalBytes(SavedFile file) {
    final bytes = bytesFor(file);
    return bytes != null && bytes.isNotEmpty;
  }

  /// Garante bytes em memória (disco no app / IndexedDB no web).
  Future<Uint8List?> ensureBytes(SavedFile file) async {
    final ready = bytesFor(file);
    if (ready != null && ready.isNotEmpty) return ready;
    await _hydrate(file);
    return bytesFor(file);
  }

  Uint8List? bytesForDraft(DraftFile? file) {
    if (file == null) return null;
    if (file.bytes != null) return Uint8List.fromList(file.bytes!);
    if (file.path != null) return _memoryBytes[file.path!];
    return null;
  }

  void _upsert(SavedOs record) {
    _all = [record, ..._all.where((item) => item.id != record.id)];
  }

  Future<List<SavedFile>> _persistFiles({
    required String ownerEmail,
    required String osId,
    required List<DraftFile> files,
  }) async {
    final savedFiles = <SavedFile>[];
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes != null) {
        final path = await _files.save(
          ownerEmail: ownerEmail,
          osId: osId,
          fileName: file.name,
          bytes: Uint8List.fromList(bytes),
        );
        _memoryBytes[path] = Uint8List.fromList(bytes);
        savedFiles.add(
          SavedFile(
            name: file.name,
            path: path,
            kind: file.kind,
            bytes: bytes,
            label: file.label,
            uploadedBy: ownerEmail.trim().isEmpty ? null : ownerEmail.trim(),
          ),
        );
        continue;
      }
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        final data = await _files.read(path);
        if (data != null && data.isNotEmpty) {
          final stored = await _files.save(
            ownerEmail: ownerEmail,
            osId: osId,
            fileName: file.name,
            bytes: data,
          );
          _memoryBytes[stored] = data;
          savedFiles.add(
            SavedFile(
              name: file.name,
              path: stored,
              kind: file.kind,
              bytes: data,
              label: file.label,
              uploadedBy: ownerEmail.trim().isEmpty ? null : ownerEmail.trim(),
            ),
          );
          continue;
        }
        savedFiles.add(
          SavedFile(
            name: file.name,
            path: path,
            kind: file.kind,
            bytes: _memoryBytes[path],
            label: file.label,
            uploadedBy: ownerEmail.trim().isEmpty ? null : ownerEmail.trim(),
          ),
        );
      }
    }
    return savedFiles;
  }

  Future<void> _hydrate(SavedFile file) async {
    if (file.bytes != null) {
      _memoryBytes[file.path] = Uint8List.fromList(file.bytes!);
      return;
    }
    final data = await _files.read(file.path);
    if (data != null) {
      _memoryBytes[file.path] = data;
    }
  }

  Future<void> _persist() async {
    final compact = _all.map((item) => item.toJson()).toList();
    var ok = await writePrefsJson(_sharedKey, compact);
    if (ok) return;
    await dropBloatedLocalCaches();
    await writePrefsJson(_sharedKey, compact);
  }

  Future<void> _pullRemote({List<Map<String, dynamic>>? seed}) async {
    try {
      List<Map<String, dynamic>> orders;
      if (seed != null) {
        orders = seed;
      } else {
        final result = await AccountApi.instance.listWorkOrders();
        if (!result.ok) return;
        orders = result.orders;
      }
      _pulledOnce = true;
      var changed = false;
      final remoteById = <String, SavedOs>{};
      for (final item in orders) {
        final incoming = _osFromRemote(item);
        if (incoming == null) continue;
        if (_deletedOsIds.contains(incoming.id)) continue;
        if (_isLightRemote(item)) {
          _lightStamp[incoming.id] = jsonText(item['updatedAt']);
        } else {
          _lightStamp.remove(incoming.id);
        }
        remoteById[incoming.id] = incoming;
        final existing = byId(incoming.id);
        if (existing == null) {
          _all = [incoming, ..._all];
          changed = true;
          continue;
        }
        final merged = _mergeOs(
          existing,
          incoming,
          summary: _isLightRemote(item) || item['rdos'] is! List,
          slimSlots: _hasSlimSlots(item),
        );
        if (_osSyncFingerprint(merged) != _osSyncFingerprint(existing)) {
          _upsert(merged);
          changed = true;
        }
      }
      if (changed) await _persist();
      for (final os in List<SavedOs>.from(_all)) {
        // Resumo não traz RDOs: comparar com ele reenviaria todos à toa.
        // A comparação acontece com a OS completa, em _fetchFullOs.
        if (remoteById.containsKey(os.id) && _lightStamp.containsKey(os.id)) {
          continue;
        }
        _publishIfRicher(os, remoteById[os.id]);
      }
      if (_all.any((os) => needsFullOs(os.id))) {
        unawaited(_hydrateLightOrders());
      }
    } catch (error) {
      debugPrint('FieldStore pull: $error');
    }
  }

  Future<AccountResult> _pushRemote(SavedOs os) async {
    try {
      final rdo = os.rdo;
      final fields = <String, String>{
        'id': os.id,
        'number': os.number,
        'status': os.status.name,
        'updatedAt': os.lastUpdatedAt.toIso8601String(),
        'ownerEmail': os.ownerEmail,
        'createdAt': os.createdAt.toIso8601String(),
        'startsAt': os.startDay.toIso8601String(),
        'technicianEmail': os.technicianEmail,
        'technicianName': uniquePersonNames(os.technicianName),
        'technicianEmails': os.assigneeEmails.join(','),
        'signerName': os.signerName ?? '',
        'client': _clip(rdo.client),
        'site': _clip(rdo.site),
        'cnpj': rdo.cnpj,
        'systemType': _clip(rdo.systemType),
        'service': _clip(rdo.service),
        'technicianCargo': rdo.technicianCargo,
        'baseName': _clip(rdo.baseName),
        'baseCargo': _clip(rdo.baseCargo),
        'baseEmail': rdo.baseEmail,
        'basePhone': rdo.basePhone,
        'technicianFuncoes': jsonEncode(rdo.technicianFuncoes),
        'technicianCargos': jsonEncode(rdo.technicianCargos),
      };
      // Só RDOs ainda não enviados: cópia antiga reenviada ressuscitava
      // RDO apagado em outro aparelho.
      final pendingRdos = _rdosPending[os.id] ?? const <String>{};
      final unsent = [
        for (final entry in os.rdos)
          if (pendingRdos.contains(entry.id)) entry,
      ];
      if (unsent.isNotEmpty) {
        fields['rdosJson'] = jsonEncode(_rdosShare(unsent));
      }
      // Só envia slots se houver — lista vazia apagava certificados na nuvem.
      // Slots do resumo são enxutos e apagariam os dados completos na nuvem.
      // Antes de puxar a nuvem a cópia local pode ser velha e a lista
      // enviada substitui a da nuvem.
      final sendsSlots =
          os.calibrationSlots.isNotEmpty && _pulledOnce && !needsFullOs(os.id);
      final sentSlots = <String, String>{
        if (sendsSlots)
          for (final slot in os.calibrationSlots) slot.id: _slotJson(slot),
      };
      if (sendsSlots) {
        fields['calibrationSlotsJson'] = jsonEncode([
          for (final slot in os.calibrationSlots) slot.toJson(),
        ]);
      }
      final deleted = _deletedRdoIds[os.id];
      if (deleted != null && deleted.isNotEmpty) {
        fields['deletedRdoIds'] = deleted.join(',');
      }
      final shared = [
        for (final file in os.files)
          if (!file.isOsAttachment) file,
      ];
      fields['filesJson'] = jsonEncode(_filesShare(shared));
      final result = await AccountApi.instance.saveWorkOrder(fields);
      if (result.ok && sendsSlots) _confirmSlots(os.id, sentSlots);
      if (result.ok && unsent.isNotEmpty) {
        _clearRdoPending(os.id, [for (final entry in unsent) entry.id]);
      }
      if (!result.ok) {
        debugPrint('FieldStore push: ${result.error}');
      } else if (_lightStamp.containsKey(os.id) && !needsFullOs(os.id)) {
        final stamp = fields['updatedAt']!;
        _lightStamp[os.id] = stamp;
        _fullStamp[os.id] = stamp;
        unawaited(_saveFullStamps());
      }
      return result;
    } catch (error) {
      debugPrint('FieldStore push: $error');
      return AccountResult(ok: false, reachable: false, error: '$error');
    }
  }

  void _ensureRemoteOk(AccountResult result, String action) {
    if (result.ok) return;
    if (!AccountApi.useRemote) return;
    final detail = (result.error ?? '').trim();
    throw CloudSyncException(
      detail.isEmpty
          ? 'Não foi possível $action na nuvem. '
                'Atualize o login_gate.gs no Apps Script (Nova versão) e tente de novo.'
          : 'Não foi possível $action na nuvem: $detail',
    );
  }

  Future<void> _pushDailyRdo(SavedOs os, SavedRdo entry) async {
    try {
      final result = await AccountApi.instance.saveDailyRdo({
        'osId': os.id,
        'id': os.id,
        'number': os.number,
        'status': os.status.name,
        'rdoId': entry.id,
        'date': entry.date.toIso8601String(),
        'clockIn': entry.clockIn,
        'lunchStart': entry.lunchStart,
        'lunchEnd': entry.lunchEnd,
        'clockOut': entry.clockOut,
        'description': _clip(entry.description, 20000),
        'notes': _clip(entry.notes, 8000),
        'signed': entry.isSigned ? '1' : '0',
        'createdAt': entry.createdAt.toIso8601String(),
        'responsibleName': entry.responsibleName.trim(),
        'signedAt': entry.signedAt?.toIso8601String() ?? '',
        'clientSignedName': entry.clientSignedName.trim(),
        'clientSignedAt': entry.clientSignedAt?.toIso8601String() ?? '',
        'signToken': entry.signToken.trim(),
        'filesJson': jsonEncode(_filesShare(entry.files)),
        'absentJson': jsonEncode(entry.absentNames),
      });
      if (result.ok) _clearRdoPending(os.id, [entry.id]);
      if (!result.ok && result.reachable) {
        debugPrint('FieldStore saverdo: ${result.error}');
      }
    } catch (error) {
      debugPrint('FieldStore saverdo: $error');
    }
  }

  void _publishIfRicher(SavedOs local, SavedOs? remote) {
    if (local.status == OsStatus.rascunho) return;
    if (remote == null) {
      unawaited(_pushRemote(local));
      for (final entry in local.rdos) {
        unawaited(_pushDailyRdo(local, entry));
      }
      return;
    }
    // Não reenviar cache local fechado por cima de OS já reativada na nuvem.
    if (_isClosedStatus(local.status) &&
        !_isClosedStatus(remote.status) &&
        !remote.lastUpdatedAt.isBefore(local.lastUpdatedAt)) {
      return;
    }
    final remoteRdoIds = {for (final entry in remote.rdos) entry.id};
    final pending = _rdosPending[local.id] ?? const <String>{};
    final missing = [
      for (final entry in local.rdos)
        if (!remoteRdoIds.contains(entry.id) && pending.contains(entry.id))
          entry,
    ];
    if (missing.isNotEmpty) {
      for (final entry in missing) {
        unawaited(_pushDailyRdo(local, entry));
      }
      unawaited(_pushRemote(local));
      return;
    }
    if (local.files.isNotEmpty && remote.files.isEmpty) {
      unawaited(_pushRemote(local));
    }
    if (local.calibrationSlots.isNotEmpty && remote.calibrationSlots.isEmpty) {
      unawaited(_pushRemote(local));
      return;
    }
    final slotsUnsent =
        (_slotEdits[local.id]?.isNotEmpty ?? false) ||
        (_slotDeletes[local.id]?.isNotEmpty ?? false);
    if (slotsUnsent && !needsFullOs(local.id)) {
      unawaited(_pushRemote(local));
    }
  }

  String _osSyncFingerprint(SavedOs os) {
    return [
      os.id,
      os.number,
      os.status.name,
      os.lastUpdatedAt.toIso8601String(),
      '${os.calibrationSlots.length}',
      '${os.rdos.length}',
      '${os.files.length}',
      os.technicianEmail,
      os.rdo.client,
    ].join('|');
  }

  SavedOs? _osFromRemote(Map<String, dynamic> json) {
    try {
      final id = jsonText(json['id']);
      if (id.isEmpty) return null;
      return SavedOs.fromJson({
        ...json,
        'id': id,
        'files': json['files'] ?? const [],
        'rdos': json['rdos'] ?? const [],
      });
    } catch (error) {
      debugPrint('FieldStore skip OS: $error');
      return null;
    }
  }

  /// [summary]: resumo da listagem (OS grande) — não traz RDOs nem
  /// certificados completos, então não decide o que foi apagado.
  SavedOs _mergeOs(
    SavedOs local,
    SavedOs remote, {
    bool summary = false,
    bool slimSlots = false,
  }) {
    final remoteNewer = remote.lastUpdatedAt.isAfter(local.lastUpdatedAt);
    return local.copyWith(
      technicianEmail: remote.technicianEmail.isNotEmpty
          ? remote.technicianEmail
          : null,
      technicianName: uniquePersonNames(
        remote.technicianName.isNotEmpty
            ? remote.technicianName
            : local.technicianName,
      ),
      technicianEmails: remote.technicianEmails.isNotEmpty
          ? remote.technicianEmails
          : null,
      // Nuvem manda no status após listagem (reativação / encerramento).
      status: remote.status,
      rdo: _mergeRdo(local.rdo, remote.rdo),
      signerName: remote.signerName ?? local.signerName,
      rdos: summary
          ? local.rdos
          : _mergeRdos(local.id, local.rdos, remote.rdos),
      files: _mergeFiles(local.files, remote.files),
      startsAt: _preferStartsAt(local, remote),
      calibrationSlots: summary && local.calibrationSlots.isNotEmpty
          ? local.calibrationSlots
          : slimSlots && local.calibrationSlots.isNotEmpty
          ? _overlaySlimSlots(
              local.id,
              local.calibrationSlots,
              remote.calibrationSlots,
            )
          : _mergeCalibrationSlots(
              local.id,
              local.calibrationSlots,
              remote.calibrationSlots,
            ),
      calibrationEditBy: _preferCalibrationEdit(local, remote).$1,
      calibrationEditAt: _preferCalibrationEdit(local, remote).$2,
      updatedAt: remoteNewer ? remote.lastUpdatedAt : local.lastUpdatedAt,
    );
  }

  (String, DateTime?) _preferCalibrationEdit(SavedOs local, SavedOs remote) {
    final localAt = local.calibrationEditAt;
    final remoteAt = remote.calibrationEditAt;
    final localBy = local.calibrationEditBy.trim();
    final remoteBy = remote.calibrationEditBy.trim();
    if (localBy.isEmpty && remoteBy.isEmpty) return ('', null);
    if (localBy.isEmpty) return (remoteBy, remoteAt);
    if (remoteBy.isEmpty) return (localBy, localAt);
    if (localAt != null && remoteAt != null) {
      return remoteAt.isAfter(localAt)
          ? (remoteBy, remoteAt)
          : (localBy, localAt);
    }
    if (remoteAt != null) return (remoteBy, remoteAt);
    return (localBy, localAt);
  }

  /// Nuvem com certificados enxutos: ela decide quais existem e os 6 campos
  /// que guarda; o resto (preset, ilha, fabricante…) fica como no aparelho.
  List<OsCalibrationSlot> _overlaySlimSlots(
    String osId,
    List<OsCalibrationSlot> local,
    List<OsCalibrationSlot> remote,
  ) {
    final edits = _slotEdits[osId] ?? const <String>{};
    final deletes = _slotDeletes[osId] ?? const <String>{};
    final localById = {for (final slot in local) slot.id: slot};
    final remoteIds = <String>{};
    final out = <OsCalibrationSlot>[];
    for (final slim in remote) {
      remoteIds.add(slim.id);
      if (deletes.contains(slim.id)) continue;
      final mine = localById[slim.id];
      if (mine == null) {
        out.add(slim);
      } else if (edits.contains(slim.id)) {
        out.add(mine);
      } else {
        out.add(
          mine.copyWith(
            certificateNumber: slim.certificateNumber.trim().isNotEmpty
                ? slim.certificateNumber
                : mine.certificateNumber,
            serialNumber: slim.serialNumber,
            equipmentTag: slim.equipmentTag,
            jobId: slim.jobId,
          ),
        );
      }
    }
    for (final slot in local) {
      if (edits.contains(slot.id) && !remoteIds.contains(slot.id)) {
        out.add(slot);
      }
    }
    return out;
  }

  /// Vale a nuvem; só o que este aparelho criou/alterou/removeu e ainda não
  /// subiu fica como está aqui. Comparar datas entre aparelhos não serve
  /// (relógio/versões antigas inflavam a data).
  List<OsCalibrationSlot> _mergeCalibrationSlots(
    String osId,
    List<OsCalibrationSlot> local,
    List<OsCalibrationSlot> remote,
  ) {
    // Lista vazia nunca apaga certificados na nuvem: não dá para saber.
    if (remote.isEmpty) return local;
    _confirmSlots(osId, {for (final slot in remote) slot.id: _slotJson(slot)});
    final edits = _slotEdits[osId] ?? const <String>{};
    final deletes = _slotDeletes[osId] ?? const <String>{};
    final map = <String, OsCalibrationSlot>{
      for (final slot in remote)
        if (!deletes.contains(slot.id)) slot.id: slot,
    };
    for (final slot in local) {
      if (!edits.contains(slot.id)) continue;
      final other = map[slot.id];
      if (other == null) {
        map[slot.id] = slot;
        continue;
      }
      final primary = slot;
      final secondary = other;
      map[slot.id] = primary.copyWith(
        serialNumber: primary.serialNumber.trim().isNotEmpty
            ? primary.serialNumber
            : secondary.serialNumber,
        jobId: primary.jobId.trim().isNotEmpty
            ? primary.jobId
            : secondary.jobId,
        equipmentId: primary.equipmentId.trim().isNotEmpty
            ? primary.equipmentId
            : secondary.equipmentId,
        equipmentTag: primary.equipmentTag.trim().isNotEmpty
            ? primary.equipmentTag
            : secondary.equipmentTag,
        equipmentType: primary.equipmentType.trim().isNotEmpty
            ? primary.equipmentType
            : secondary.equipmentType,
        manufacturer: primary.manufacturer.trim().isNotEmpty
            ? primary.manufacturer
            : secondary.manufacturer,
        model: primary.model.trim().isNotEmpty
            ? primary.model
            : secondary.model,
        installLocation: primary.installLocation.trim().isNotEmpty
            ? primary.installLocation
            : secondary.installLocation,
        systemType: primary.systemType.trim().isNotEmpty
            ? primary.systemType
            : secondary.systemType,
        product: primary.product.trim().isNotEmpty
            ? primary.product
            : secondary.product,
        workingPrinciple: primary.workingPrinciple.trim().isNotEmpty
            ? primary.workingPrinciple
            : secondary.workingPrinciple,
        systemId: primary.systemId.trim().isNotEmpty
            ? primary.systemId
            : secondary.systemId,
        systemTag: primary.systemTag.trim().isNotEmpty
            ? primary.systemTag
            : secondary.systemTag,
        assemblyKind: primary.assemblyKind.trim().isNotEmpty
            ? primary.assemblyKind
            : secondary.assemblyKind,
        presetTag: primary.presetTag.trim().isNotEmpty
            ? primary.presetTag
            : secondary.presetTag,
        presetManufacturer: primary.presetManufacturer.trim().isNotEmpty
            ? primary.presetManufacturer
            : secondary.presetManufacturer,
        presetModel: primary.presetModel.trim().isNotEmpty
            ? primary.presetModel
            : secondary.presetModel,
        presetSerial: primary.presetSerial.trim().isNotEmpty
            ? primary.presetSerial
            : secondary.presetSerial,
        instrumentRole: primary.instrumentRole.trim().isNotEmpty
            ? primary.instrumentRole
            : secondary.instrumentRole,
        meshTag: primary.meshTag.trim().isNotEmpty
            ? primary.meshTag
            : secondary.meshTag,
        meshEquipmentType: primary.meshEquipmentType.trim().isNotEmpty
            ? primary.meshEquipmentType
            : secondary.meshEquipmentType,
        meshManufacturer: primary.meshManufacturer.trim().isNotEmpty
            ? primary.meshManufacturer
            : secondary.meshManufacturer,
        meshModel: primary.meshModel.trim().isNotEmpty
            ? primary.meshModel
            : secondary.meshModel,
        meshSerialNumber: primary.meshSerialNumber.trim().isNotEmpty
            ? primary.meshSerialNumber
            : secondary.meshSerialNumber,
        meshWorkingPrinciple: primary.meshWorkingPrinciple.trim().isNotEmpty
            ? primary.meshWorkingPrinciple
            : secondary.meshWorkingPrinciple,
        dataCheck: primary.dataCheck.trim().isNotEmpty
            ? primary.dataCheck
            : secondary.dataCheck,
        divergentNote: primary.divergentNote.trim().isNotEmpty
            ? primary.divergentNote
            : secondary.divergentNote,
        catalogStatus: _preferCatalogStatus(slot, other),
        catalogSubmittedAt: _preferNonEmpty(
          primary.catalogSubmittedAt,
          secondary.catalogSubmittedAt,
        ),
        catalogSubmittedBy: _preferNonEmpty(
          primary.catalogSubmittedBy,
          secondary.catalogSubmittedBy,
        ),
        catalogReviewNote: _preferNonEmpty(
          primary.catalogReviewNote,
          secondary.catalogReviewNote,
        ),
        catalogReviewedAt: _preferNonEmpty(
          primary.catalogReviewedAt,
          secondary.catalogReviewedAt,
        ),
        catalogReviewedBy: _preferNonEmpty(
          primary.catalogReviewedBy,
          secondary.catalogReviewedBy,
        ),
        certificateNumber: primary.certificateNumber.trim().isNotEmpty
            ? primary.certificateNumber
            : secondary.certificateNumber,
      );
    }
    final seen = <String>{};
    final ordered = <OsCalibrationSlot>[];
    for (final slot in [...remote, ...local]) {
      if (!seen.add(slot.id)) continue;
      final merged = map[slot.id];
      if (merged != null) ordered.add(merged);
    }
    return dedupeCalibrationSlotsByCertificateNumber(ordered);
  }

  String _preferNonEmpty(String a, String b) => a.trim().isNotEmpty ? a : b;

  /// Preferência: approved/rejected com revisão > pending > vazio.
  String _preferCatalogStatus(OsCalibrationSlot a, OsCalibrationSlot b) {
    int rank(String status) {
      switch (status) {
        case 'approved':
        case 'rejected':
          return 3;
        case 'pending':
          return 2;
        default:
          return 0;
      }
    }

    final ra = rank(a.catalogStatus);
    final rb = rank(b.catalogStatus);
    if (ra != rb) return ra > rb ? a.catalogStatus : b.catalogStatus;
    final ta =
        DateTime.tryParse(
          a.catalogReviewedAt.isNotEmpty
              ? a.catalogReviewedAt
              : a.catalogSubmittedAt,
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final tb =
        DateTime.tryParse(
          b.catalogReviewedAt.isNotEmpty
              ? b.catalogReviewedAt
              : b.catalogSubmittedAt,
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return ta.isAfter(tb) ? a.catalogStatus : b.catalogStatus;
  }

  /// Instrumentos enviados pelo técnico aguardando Cleber/adm no cadastro.
  List<PendingCatalogSubmission> pendingCatalogSubmissions() {
    final out = <PendingCatalogSubmission>[];
    for (final os in officeItems) {
      for (var i = 0; i < os.calibrationSlots.length; i++) {
        final slot = os.calibrationSlots[i];
        if (!slot.isCatalogPending) continue;
        out.add(PendingCatalogSubmission(os: os, slot: slot, slotIndex: i));
      }
    }
    out.sort((a, b) {
      final ta =
          DateTime.tryParse(a.slot.catalogSubmittedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          DateTime.tryParse(b.slot.catalogSubmittedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return out;
  }

  DateTime _dayOnly(DateTime day) => DateTime(day.year, day.month, day.day);

  DateTime _preferStartsAt(SavedOs local, SavedOs remote) {
    final localDay = local.startDay;
    final remoteDay = remote.startDay;
    final localExplicit =
        local.startsAt != null && localDay != _dayOnly(local.createdAt);
    final remoteExplicit =
        remote.startsAt != null && remoteDay != _dayOnly(remote.createdAt);
    if (remoteExplicit) return remoteDay;
    if (localExplicit) return localDay;
    return remoteDay;
  }

  RdoData _mergeRdo(RdoData local, RdoData remote) {
    final useRemote =
        remote.client.trim().isNotEmpty || remote.cnpj.trim().isNotEmpty;
    var header = useRemote ? remote : local;
    if (header.technicianFuncoes.isEmpty &&
        local.technicianFuncoes.isNotEmpty) {
      header = header.copyWith(technicianFuncoes: local.technicianFuncoes);
    }
    if (header.technicianCargos.isEmpty && local.technicianCargos.isNotEmpty) {
      header = header.copyWith(technicianCargos: local.technicianCargos);
    }
    return header;
  }

  List<SavedRdo> _mergeRdos(
    String osId,
    List<SavedRdo> local,
    List<SavedRdo> remote,
  ) {
    _forgetDeletedIfGone(osId, remote);
    final gone = _deletedRdoIds[osId] ?? const <String>{};
    final map = <String, SavedRdo>{
      for (final entry in remote)
        if (!gone.contains(entry.id)) entry.id: entry,
    };
    for (final entry in local) {
      if (gone.contains(entry.id)) continue;
      final incoming = map[entry.id];
      if (incoming == null) {
        // Ausência na nuvem não prova exclusão: a nuvem já perdeu RDOs
        // assinados (gravação a partir do resumo). Só some com exclusão
        // explícita (gone); reenvio automático só dos pendentes.
        map[entry.id] = entry;
        continue;
      }
      final localHasFiles = entry.files.any(
        (file) =>
            (file.bytes != null && file.bytes!.isNotEmpty) ||
            (file.path.isNotEmpty && !file.path.startsWith('remote:')),
      );
      map[entry.id] = (localHasFiles ? entry : incoming).copyWith(
        description:
            entry.description.trim().length >=
                incoming.description.trim().length
            ? entry.description
            : incoming.description,
        notes: entry.notes.trim().length >= incoming.notes.trim().length
            ? entry.notes
            : incoming.notes,
        clientSignedName: incoming.clientSignedName.trim().isNotEmpty
            ? incoming.clientSignedName
            : entry.clientSignedName,
        clientSignedAt: incoming.clientSignedAt ?? entry.clientSignedAt,
        signToken: incoming.signToken.trim().isNotEmpty
            ? incoming.signToken
            : entry.signToken,
        responsibleName:
            (localHasFiles ? entry : incoming).responsibleName.trim().isNotEmpty
            ? (localHasFiles ? entry : incoming).responsibleName
            : incoming.responsibleName,
        // Ausentes: não apagar com resumo da nuvem sem a lista.
        absentNames: entry.absentNames.isNotEmpty
            ? entry.absentNames
            : incoming.absentNames,
      );
    }
    final byId = {for (final entry in local) entry.id: entry};
    _clearRdoPending(osId, [
      for (final entry in remote)
        if (byId[entry.id] != null && _sameRdoContent(byId[entry.id]!, entry))
          entry.id,
    ]);
    final merged = map.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }

  /// Nuvem já tem esta versão do RDO (não só o id: edição pode não ter subido).
  bool _sameRdoContent(SavedRdo a, SavedRdo b) {
    return a.date.isAtSameMomentAs(b.date) &&
        a.clockIn == b.clockIn &&
        a.lunchStart == b.lunchStart &&
        a.lunchEnd == b.lunchEnd &&
        a.clockOut == b.clockOut &&
        a.description.trim() == b.description.trim() &&
        a.notes.trim() == b.notes.trim() &&
        a.isSigned == b.isSigned &&
        a.responsibleName.trim() == b.responsibleName.trim() &&
        a.absentNames.join('|') == b.absentNames.join('|') &&
        a.files.length == b.files.length;
  }

  List<SavedFile> _mergeFiles(List<SavedFile> local, List<SavedFile> remote) {
    final me = (_viewerEmail ?? '').trim().toLowerCase();
    final map = <String, SavedFile>{};
    for (final file in remote) {
      // Não importa anexos de outros aparelhos (só o nome, sem arquivo).
      if (file.isOsAttachment) continue;
      map[_fileKey(file)] = file;
    }
    for (final file in local) {
      if (file.isOsAttachment && !_canSeeOsAttachment(file, me)) {
        continue;
      }
      final key = _fileKey(file);
      final incoming = map[key];
      final hasBytes =
          (file.bytes != null && file.bytes!.isNotEmpty) ||
          _memoryBytes[file.path] != null;
      if (incoming == null || hasBytes) {
        map[key] = file;
      }
    }
    return map.values.toList();
  }

  String _fileKey(SavedFile file) {
    return '${file.kind.name}|${file.label ?? ''}|${file.name}';
  }

  List<Map<String, dynamic>> _rdosShare(List<SavedRdo> rdos) {
    return [
      for (final entry in rdos.take(40))
        {
          'id': entry.id,
          'date': entry.date.toIso8601String(),
          'clockIn': entry.clockIn,
          'lunchStart': entry.lunchStart,
          'lunchEnd': entry.lunchEnd,
          'clockOut': entry.clockOut,
          'description': _clip(entry.description, 20000),
          'notes': _clip(entry.notes, 8000),
          'signed': entry.isSigned,
          'createdAt': entry.createdAt.toIso8601String(),
          if (entry.responsibleName.trim().isNotEmpty)
            'responsibleName': entry.responsibleName.trim(),
          if (entry.signedAt != null)
            'signedAt': entry.signedAt!.toIso8601String(),
          if (entry.clientSignedName.trim().isNotEmpty)
            'clientSignedName': entry.clientSignedName.trim(),
          if (entry.clientSignedAt != null)
            'clientSignedAt': entry.clientSignedAt!.toIso8601String(),
          if (entry.signToken.trim().isNotEmpty) 'signToken': entry.signToken,
          if (entry.absentNames.isNotEmpty) 'absent': entry.absentNames,
          'files': _filesShare(entry.files),
        },
    ];
  }

  List<Map<String, dynamic>> _filesShare(List<SavedFile> files) {
    return [
      for (final file in files.take(16))
        {
          'name': _clip(file.name, 80),
          'kind': file.kind.name,
          if (file.label != null && file.label!.isNotEmpty)
            'label': _clip(file.label!, 40),
        },
    ];
  }

  Future<void> _loadDeletedRdoIds() async {
    try {
      final raw = await readPrefsString(_deletedRdosKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _deletedRdoIds
        ..clear()
        ..addAll({
          for (final entry in decoded.entries)
            if (entry.value is List)
              entry.key.toString(): {
                for (final id in entry.value as List)
                  if ('$id'.trim().isNotEmpty) '$id'.trim(),
              },
        });
    } catch (error) {
      debugPrint('FieldStore deleted rdos: $error');
    }
  }

  Future<void> _loadDeletedOsIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_deletedOsKey) ?? const [];
      _deletedOsIds
        ..clear()
        ..addAll(list.where((id) => id.trim().isNotEmpty));
    } catch (error) {
      debugPrint('FieldStore deleted os: $error');
    }
  }

  Future<void> _persistDeletedOsIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedOsKey, _deletedOsIds.toList());
  }

  Future<void> _persistDeletedRdoIds() async {
    await writePrefsJson(_deletedRdosKey, {
      for (final entry in _deletedRdoIds.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
    });
  }

  void _forgetDeletedIfGone(String osId, List<SavedRdo> remote) {
    final gone = _deletedRdoIds[osId];
    if (gone == null || gone.isEmpty) return;
    final remoteIds = {for (final entry in remote) entry.id};
    final before = gone.length;
    gone.removeWhere((id) => !remoteIds.contains(id));
    if (gone.isEmpty) _deletedRdoIds.remove(osId);
    if (gone.length != before) unawaited(_persistDeletedRdoIds());
  }

  bool _isClosedStatus(OsStatus status) => isClosedOsStatus(status);

  String _clip(String value, [int max = 400]) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return trimmed.substring(0, max);
  }

  String _legacyKey(String email) => 'gs_os_$email';
}
