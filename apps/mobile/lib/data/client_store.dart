import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/data/client_excel.dart' show mergeEquipment;
import 'package:gs_mobile/data/cloud_sync_gate.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/prefs_json.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Junta a edição feita sobre [base] com a versão mais nova da nuvem:
/// o que o usuário mudou vale; o que ele não mexeu vem da nuvem
/// (ilhas novas, correções e nome trocados em outro aparelho).
SavedClient rebaseClientEdit({
  required SavedClient draft,
  required SavedClient base,
  required SavedClient cloud,
}) {
  String pick(String mine, String before, String theirs) =>
      mine.trim() == before.trim() ? theirs : mine;

  String key(ClientSystem system) => jsonEncode(system.toJson());

  final baseById = {for (final s in base.resolvedSystems) s.id: s};
  final draftById = {for (final s in draft.resolvedSystems) s.id: s};
  final cloudById = {for (final s in cloud.resolvedSystems) s.id: s};
  final systems = <ClientSystem>[];
  for (final mine in draft.resolvedSystems) {
    final before = baseById[mine.id];
    final theirs = cloudById[mine.id];
    if (before != null && key(before) == key(mine)) {
      // Não mexeu: segue a nuvem (inclusive se outro aparelho apagou).
      if (theirs != null) systems.add(theirs);
      continue;
    }
    systems.add(mine);
  }
  for (final theirs in cloud.resolvedSystems) {
    if (draftById.containsKey(theirs.id)) continue;
    // Apagada nesta tela: continua apagada.
    if (baseById.containsKey(theirs.id)) continue;
    systems.add(theirs);
  }

  final sameSites = base.sites.join('|') == draft.sites.join('|');
  final sameContacts =
      jsonEncode([for (final c in base.resolvedBaseContacts) c.toJson()]) ==
      jsonEncode([for (final c in draft.resolvedBaseContacts) c.toJson()]);
  final sameStored =
      jsonEncode([for (final e in base.storedEquipment) e.toJson()]) ==
      jsonEncode([for (final e in draft.storedEquipment) e.toJson()]);

  return draft.copyWith(
    name: pick(draft.name, base.name, cloud.name),
    requester: pick(draft.requester, base.requester, cloud.requester),
    cnpj: pick(draft.cnpj, base.cnpj, cloud.cnpj),
    sites: sameSites ? cloud.sites : draft.sites,
    cep: pick(draft.cep, base.cep, cloud.cep),
    street: pick(draft.street, base.street, cloud.street),
    number: pick(draft.number, base.number, cloud.number),
    complement: pick(draft.complement, base.complement, cloud.complement),
    neighborhood: pick(
      draft.neighborhood,
      base.neighborhood,
      cloud.neighborhood,
    ),
    city: pick(draft.city, base.city, cloud.city),
    state: pick(draft.state, base.state, cloud.state),
    service: pick(draft.service, base.service, cloud.service),
    systemType: pick(draft.systemType, base.systemType, cloud.systemType),
    baseContacts: sameContacts
        ? cloud.resolvedBaseContacts
        : draft.resolvedBaseContacts,
    systems: systems,
    // Com ilhas, a lista plana só completa detalhes: une as duas.
    equipment: sameStored
        ? cloud.storedEquipment
        : (draft.systems.isNotEmpty
              ? mergeEquipment(cloud.storedEquipment, draft.storedEquipment)
              : draft.storedEquipment),
  );
}

class ClientSyncResult {
  const ClientSyncResult({required this.ok, this.remoteCount = 0, this.error});

  final bool ok;
  final int remoteCount;
  final String? error;
}

class ClientStore extends ChangeNotifier {
  ClientStore._();
  static final instance = ClientStore._();

  static const _key = 'gs_clients_v1';
  static const _deletedKey = 'gs_clients_deleted_ids_v1';
  static const _cloudStampKey = 'gs_clients_cloud_stamp_v1';
  static const _dirtyKey = 'gs_clients_dirty_v1';

  List<SavedClient> _all = [];
  final _remoteIds = <String>{};
  final _deletedIds = <String>{};

  /// Cliente grande: a lista traz só o resumo e a versão da nuvem ainda
  /// não foi baixada neste aparelho.
  final _staleIds = <String>{};
  var _refreshingStale = false;

  /// id → updatedAt da nuvem já recebido aqui. Comparar com a data local
  /// não serve: versões antigas regravavam o cliente com a hora do aparelho.
  final _cloudStamp = <String, String>{};

  /// Edição feita aqui que a nuvem ainda não confirmou.
  final _dirtyIds = <String>{};

  List<SavedClient> get items => List<SavedClient>.unmodifiable(_all);

  /// Última gravação local não coube no navegador (dados só em memória/nuvem).
  bool localCacheFull = false;

  void resetForTest() {
    _all = [];
    _remoteIds.clear();
    _deletedIds.clear();
    _staleIds.clear();
    _cloudStamp.clear();
    _dirtyIds.clear();
  }

  Future<void> load({List<Map<String, dynamic>>? remoteClients}) async {
    if (_all.isNotEmpty && remoteClients == null && CloudSyncGate.isFresh) {
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final deletedList = prefs.getStringList(_deletedKey) ?? [];
    _deletedIds.addAll(deletedList);
    _dirtyIds
      ..clear()
      ..addAll(prefs.getStringList(_dirtyKey) ?? const []);
    _cloudStamp.clear();
    try {
      final stamps = jsonDecode(prefs.getString(_cloudStampKey) ?? '{}');
      if (stamps is Map) {
        stamps.forEach((key, value) => _cloudStamp['$key'] = '$value');
      }
    } catch (_) {}
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _all = [];
    } else {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _all = [
        for (final item in decoded)
          SavedClient.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    }
    if (remoteClients != null || !CloudSyncGate.isFresh) {
      await _pullRemote(seed: remoteClients);
    }
    _sort();
    notifyListeners();
  }

  Future<ClientSyncResult> sync() async {
    try {
      final result = await AccountApi.instance.listClients();
      if (!result.ok) {
        return ClientSyncResult(
          ok: false,
          error: result.error ?? 'Não sincronizou os clientes da nuvem.',
        );
      }
      await _pullRemote(seed: result.clients);
      CloudSyncGate.markSynced();
      _sort();
      notifyListeners();
      return ClientSyncResult(ok: true, remoteCount: result.clients.length);
    } catch (error) {
      debugPrint('ClientStore sync: $error');
      return ClientSyncResult(ok: false, error: '$error');
    }
  }

  /// Baixa o cadastro completo (planilha/Drive) quando a lista veio só com
  /// stub ou a nuvem está mais nova que o aparelho. [force]: sempre baixa.
  Future<SavedClient?> ensureFull(String id, {bool force = false}) async {
    final local = byId(id);
    if (!force &&
        !_staleIds.contains(id) &&
        local != null &&
        (local.equipment.isNotEmpty || local.resolvedSystems.isNotEmpty)) {
      return local;
    }
    try {
      final fetched = await _fetchCloud(id);
      if (fetched == null) return local;
      final incoming = fetched.client;
      _staleIds.remove(incoming.id);
      _remoteIds.add(incoming.id);
      _cloudStamp[incoming.id] = fetched.stamp;
      await _saveMeta();
      final existing = byId(incoming.id);
      if (existing == null) {
        _all = [incoming, ..._all];
      } else {
        final merged = _absorbRemote(existing, incoming);
        if (_dirtyIds.contains(existing.id)) unawaited(_pushRemote(merged));
        _all = [
          merged,
          ..._all.where(
            (client) => client.id != existing.id && client.id != incoming.id,
          ),
        ];
      }
      await _persist();
      _sort();
      notifyListeners();
      return byId(incoming.id) ?? incoming;
    } catch (error) {
      debugPrint('ClientStore ensureFull: $error');
      return local;
    }
  }

  Future<({SavedClient client, String stamp})?> _fetchCloud(String id) async {
    if (!AccountApi.useRemote || id.trim().isEmpty) return null;
    final result = await AccountApi.instance.getClient(id);
    if (!result.ok || result.clients.isEmpty) return null;
    final raw = result.clients.first;
    // Resumo no lugar do arquivo completo: unir com ele apagava os
    // responsáveis e deixava cada aparelho com ilhas diferentes.
    if (raw['_payloadLight'] == true ||
        '${raw['_fileId'] ?? ''}'.trim().isNotEmpty) {
      return null;
    }
    final incoming = SavedClient.fromJson(raw);
    if (incoming.id.isEmpty) return null;
    return (client: incoming, stamp: _stampOf(raw));
  }

  static String _stampOf(Map<String, dynamic> raw) =>
      '${raw['updatedAt'] ?? ''}'.trim();

  bool _hasCatalog(SavedClient client) =>
      client.storedEquipment.isNotEmpty || client.systems.isNotEmpty;

  /// A nuvem é a verdade; só uma edição local ainda não enviada é unida.
  SavedClient _absorbRemote(SavedClient local, SavedClient remote) {
    if (_dirtyIds.contains(local.id)) return _mergeRemoteClient(local, remote);
    if (_hasCatalog(remote) || !_hasCatalog(local)) return remote;
    // Nuvem sem instrumentos não apaga o cadastro deste aparelho.
    return remote.copyWith(
      systems: local.systems,
      equipment: local.storedEquipment,
    );
  }

  Future<void> _saveMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cloudStampKey, jsonEncode(_cloudStamp));
      await prefs.setStringList(_dirtyKey, _dirtyIds.toList());
    } catch (error) {
      debugPrint('ClientStore meta: $error');
    }
  }

  Future<void> _refreshStaleClients() async {
    if (_refreshingStale) return;
    _refreshingStale = true;
    try {
      for (final id in List<String>.from(_staleIds)) {
        await ensureFull(id);
      }
    } finally {
      _refreshingStale = false;
    }
  }

  /// Grava a edição da tela de cadastro sem apagar o que outro aparelho
  /// mandou para a nuvem depois que a tela abriu ([base]).
  Future<SavedClient> saveEdited(SavedClient draft, {SavedClient? base}) async {
    var record = draft;
    if (base != null && draft.id == base.id) {
      try {
        // Sempre une: a data de [base] pode estar inflada em aparelho antigo.
        final cloud = await _fetchCloud(base.id);
        if (cloud != null) {
          record = rebaseClientEdit(
            draft: draft,
            base: base,
            cloud: cloud.client,
          );
        }
      } catch (error) {
        debugPrint('ClientStore saveEdited: $error');
      }
    }
    return save(record);
  }

  SavedClient? byId(String id) {
    for (final client in _all) {
      if (client.id == id) return client;
    }
    return null;
  }

  static String _cleanStr(String raw) {
    var value = raw.trim().toLowerCase();
    const from = 'áàãâäéèêëíìîïóòõôöúùûüçñº°';
    const to = 'aaaaaeeeeiiiiooooouuuucn  ';
    for (var i = 0; i < from.length; i++) {
      value = value.replaceAll(from[i], to[i]);
    }
    return value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  SavedClient? findMatch({String cnpj = '', String name = ''}) {
    final digits = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final padded = digits.padLeft(14, '0');
      for (final client in _all) {
        final cDigits = client.cnpjDigits;
        if (cDigits.isNotEmpty &&
            (cDigits == digits || cDigits.padLeft(14, '0') == padded)) {
          return client;
        }
      }
    }
    final label = _cleanStr(name);
    if (label.isNotEmpty) {
      for (final client in _all) {
        final cl = _cleanStr(client.name);
        if (cl == label) return client;
      }
      for (final client in _all) {
        final cl = _cleanStr(client.name);
        if (cl.isNotEmpty && (cl.contains(label) || label.contains(cl))) {
          return client;
        }
      }
    }
    return null;
  }

  Future<SavedClient> save(SavedClient client, {bool syncRemote = true}) async {
    final name = client.name.trim();
    final cnpj = client.cnpj.trim();
    if (name.isEmpty && cnpj.isEmpty) {
      throw ArgumentError('Informe o contratante ou o CNPJ');
    }
    final sites = [
      for (final site in client.sites)
        if (site.trim().isNotEmpty) site.trim(),
    ];
    final seen = <String>{};
    final uniqueSites = <String>[];
    for (final site in sites) {
      final key = site.toLowerCase();
      if (seen.add(key)) uniqueSites.add(site);
    }
    final record = SavedClient(
      id: client.id,
      name: name.isEmpty ? cnpj : name,
      requester: client.requester.trim(),
      cnpj: cnpj,
      sites: uniqueSites,
      cep: client.cep.trim(),
      street: client.street.trim(),
      number: client.number.trim(),
      complement: client.complement.trim(),
      neighborhood: client.neighborhood.trim(),
      city: client.city.trim(),
      state: client.state.trim().toUpperCase(),
      service: client.service.trim(),
      systemType: client.systemType.trim(),
      baseName: client.baseName.trim(),
      baseCargo: client.baseCargo.trim(),
      baseEmail: client.baseEmail.trim(),
      basePhone: client.basePhone.trim(),
      equipment: [
        for (final item
            in (client.storedEquipment.isNotEmpty
                ? client.storedEquipment
                : client.equipment))
          if (item.title.trim().isNotEmpty) item,
      ],
      systems: client.resolvedSystems,
      updatedAt: DateTime.now(),
    );
    _deletedIds.remove(record.id);
    _all = [record, ..._all.where((item) => item.id != record.id)];
    _sort();
    await _persist();
    if (syncRemote) await _pushRemote(record);
    unawaited(FieldStore.instance.refreshCalibrationSlotsForClient(record));
    notifyListeners();
    return record;
  }

  Future<SavedClient> upsertFromRdo(
    RdoData rdo, {
    bool syncRemote = true,
  }) async {
    if (rdo.client.trim().isEmpty && rdo.cnpj.trim().isEmpty) {
      return SavedClient.fromRdo(rdo);
    }
    final existing = findMatch(cnpj: rdo.cnpj, name: rdo.client);
    final incoming = SavedClient.fromRdo(rdo, id: existing?.id);
    if (existing == null) {
      return save(incoming, syncRemote: syncRemote);
    }
    final next = existing.copyWith(
      name: incoming.name.isEmpty ? existing.name : incoming.name,
      cnpj: incoming.cnpj.isEmpty ? existing.cnpj : incoming.cnpj,
      baseName: incoming.baseName.isEmpty
          ? existing.baseName
          : incoming.baseName,
      baseCargo: incoming.baseCargo.isEmpty
          ? existing.baseCargo
          : incoming.baseCargo,
      baseEmail: incoming.baseEmail.isEmpty
          ? existing.baseEmail
          : incoming.baseEmail,
      basePhone: incoming.basePhone.isEmpty
          ? existing.basePhone
          : incoming.basePhone,
      cep: existing.cep,
      street: existing.street,
      number: existing.number,
      complement: existing.complement,
      neighborhood: existing.neighborhood,
      city: existing.city,
      state: existing.state,
      equipment: existing.storedEquipment.isNotEmpty
          ? existing.storedEquipment
          : existing.equipment,
      systems: existing.resolvedSystems,
    );
    final sameContact =
        next.name == existing.name &&
        next.cnpj == existing.cnpj &&
        next.baseName == existing.baseName &&
        next.baseCargo == existing.baseCargo &&
        next.baseEmail == existing.baseEmail &&
        next.basePhone == existing.basePhone;
    // Nada mudou: regravar com updatedAt novo passaria por cima da nuvem.
    if (sameContact) return existing;
    // Contato da OS não deve sobrescrever na nuvem um cadastro rico da planilha.
    if (syncRemote && existing.equipment.isNotEmpty) {
      return saveEdited(next, base: existing);
    }
    return save(next, syncRemote: false);
  }

  Future<void> importFromOrders(List<SavedOs> orders) async {
    var changed = false;
    for (final os in orders) {
      if (os.rdo.client.trim().isEmpty && os.rdo.cnpj.trim().isEmpty) {
        continue;
      }
      final before = _all.length;
      await upsertFromRdo(os.rdo, syncRemote: false);
      if (_all.length != before) changed = true;
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> importMany(Iterable<SavedClient> clients) async {
    for (final client in clients) {
      await save(client, syncRemote: false);
    }
    for (final client in clients) {
      unawaited(_pushRemote(client));
    }
  }

  Future<void> delete(String id) async {
    _deletedIds.add(id);
    _all = [
      for (final client in _all)
        if (client.id != id) client,
    ];
    _remoteIds.remove(id);
    await _persist();
    unawaited(AccountApi.instance.deleteClient(id));
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final full = jsonEncode(_all.map((item) => item.toJson()).toList());
    final slim = jsonEncode(
      _all.map((item) => item.toJson(slim: true)).toList(),
    );
    Future<bool> write(String payload) async {
      try {
        return await prefs.setString(_key, payload);
      } catch (error) {
        debugPrint('ClientStore persist: $error');
        return false;
      }
    }

    var saved = await write(slim);
    if (!saved) {
      await dropBloatedLocalCaches();
      saved = await write(slim);
    }
    if (!saved && slim != full) {
      saved = await write(full);
    }
    // Sem espaço local o cadastro segue em memória e vai para a nuvem;
    // abortar aqui deixava a OS e a nuvem sem os instrumentos importados.
    localCacheFull = !saved;
    try {
      await prefs.setStringList(_deletedKey, _deletedIds.toList());
    } catch (error) {
      debugPrint('ClientStore deleted ids: $error');
    }
  }

  void _sort() {
    _all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _pullRemote({List<Map<String, dynamic>>? seed}) async {
    try {
      List<Map<String, dynamic>> rows;
      if (seed != null) {
        rows = seed;
      } else {
        final result = await AccountApi.instance.listClients();
        if (!result.ok) return;
        rows = result.clients;
      }
      var changed = false;
      for (final item in rows) {
        final incoming = SavedClient.fromJson(item);
        if (incoming.id.isEmpty) continue;
        _remoteIds.add(incoming.id);
        if (_deletedIds.contains(incoming.id)) continue;
        final lightStub =
            item['_payloadLight'] == true ||
            (item['_fileId'] != null &&
                incoming.equipment.isEmpty &&
                incoming.systems.isEmpty);
        final stamp = _stampOf(item);
        final existing =
            byId(incoming.id) ??
            findMatch(cnpj: incoming.cnpj, name: incoming.name);
        // Resumo da lista: o completo é baixado em seguida se esta versão
        // da nuvem ainda não chegou aqui. O resumo nunca apaga instrumentos.
        if (lightStub) {
          if (_cloudStamp[incoming.id] != stamp) _staleIds.add(incoming.id);
          if (existing == null) {
            _all = [incoming, ..._all];
            changed = true;
          }
          continue;
        }
        _cloudStamp[incoming.id] = stamp;
        if (existing == null) {
          _all = [incoming, ..._all];
          changed = true;
          continue;
        }
        final merged = _absorbRemote(existing, incoming);
        if (merged.id != existing.id ||
            merged.updatedAt != existing.updatedAt ||
            merged.equipment.length != existing.equipment.length ||
            merged.resolvedSystems.length != existing.resolvedSystems.length ||
            merged.name != existing.name ||
            merged.cnpj != existing.cnpj) {
          _all = [
            merged,
            ..._all.where(
              (client) => client.id != existing.id && client.id != incoming.id,
            ),
          ];
          changed = true;
        }
      }
      if (changed) await _persist();
      await _saveMeta();
      for (final client in List<SavedClient>.from(_all)) {
        if (_deletedIds.contains(client.id)) continue;
        // Edição local que não chegou na nuvem: já foi unida acima; os
        // resumos são unidos e reenviados depois de baixar o completo.
        if (_dirtyIds.contains(client.id) && _remoteIds.contains(client.id)) {
          if (!_staleIds.contains(client.id)) unawaited(_pushRemote(client));
        } else if (!_remoteIds.contains(client.id)) {
          unawaited(_pushRemote(client));
        }
      }
      if (_staleIds.isNotEmpty) unawaited(_refreshStaleClients());
    } catch (error) {
      debugPrint('ClientStore pull: $error');
    }
  }

  /// Une cadastro local com a nuvem sem perder instrumentos da planilha.
  SavedClient _mergeRemoteClient(SavedClient local, SavedClient remote) {
    final localEq = local.equipment.length;
    final remoteEq = remote.equipment.length;
    final remoteNewer = remote.updatedAt.isAfter(local.updatedAt);

    // Cadastro com instrumentos na nuvem sempre prevalece sobre local vazio,
    // mesmo se o app local tiver updatedAt mais recente (ex.: OS aberta).
    // Nuvem mais nova com cadastro manda: outro aparelho pode ter
    // acrescentado, corrigido ou removido ilhas.
    final remoteHasCatalog = remoteEq > 0 || remote.resolvedSystems.isNotEmpty;
    final preferRemoteCatalog =
        (remoteNewer && remoteHasCatalog) ||
        (remoteEq > localEq) ||
        (localEq == 0 && remoteEq > 0);

    final catalog = preferRemoteCatalog ? remote : local;
    final contact = remoteNewer ? remote : local;
    final otherContact = remoteNewer ? local : remote;

    final systems = catalog.resolvedSystems.isNotEmpty
        ? catalog.resolvedSystems
        : (preferRemoteCatalog
              ? local.resolvedSystems
              : remote.resolvedSystems);
    final equipment = catalog.storedEquipment.isNotEmpty
        ? catalog.storedEquipment
        : (catalog.equipment.isNotEmpty
              ? catalog.equipment
              : (preferRemoteCatalog
                    ? (local.storedEquipment.isNotEmpty
                          ? local.storedEquipment
                          : local.equipment)
                    : (remote.storedEquipment.isNotEmpty
                          ? remote.storedEquipment
                          : remote.equipment)));

    final sites = <String>[];
    final seen = <String>{};
    for (final site in [...local.sites, ...remote.sites]) {
      final key = site.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      sites.add(site.trim());
    }

    return SavedClient(
      id: remote.id.isNotEmpty ? remote.id : local.id,
      name: contact.name.trim().isNotEmpty ? contact.name : otherContact.name,
      requester: contact.requester.trim().isNotEmpty
          ? contact.requester
          : otherContact.requester,
      cnpj: contact.cnpj.trim().isNotEmpty ? contact.cnpj : otherContact.cnpj,
      sites: sites,
      cep: contact.cep.trim().isNotEmpty ? contact.cep : otherContact.cep,
      street: contact.street.trim().isNotEmpty
          ? contact.street
          : otherContact.street,
      number: contact.number.trim().isNotEmpty
          ? contact.number
          : otherContact.number,
      complement: contact.complement.trim().isNotEmpty
          ? contact.complement
          : otherContact.complement,
      neighborhood: contact.neighborhood.trim().isNotEmpty
          ? contact.neighborhood
          : otherContact.neighborhood,
      city: contact.city.trim().isNotEmpty ? contact.city : otherContact.city,
      state: contact.state.trim().isNotEmpty
          ? contact.state
          : otherContact.state,
      service: contact.service.trim().isNotEmpty
          ? contact.service
          : otherContact.service,
      systemType: contact.systemType.trim().isNotEmpty
          ? contact.systemType
          : otherContact.systemType,
      baseName: contact.baseName.trim().isNotEmpty
          ? contact.baseName
          : otherContact.baseName,
      baseCargo: contact.baseCargo.trim().isNotEmpty
          ? contact.baseCargo
          : otherContact.baseCargo,
      baseEmail: contact.baseEmail.trim().isNotEmpty
          ? contact.baseEmail
          : otherContact.baseEmail,
      basePhone: contact.basePhone.trim().isNotEmpty
          ? contact.basePhone
          : otherContact.basePhone,
      baseContacts:
          contact.resolvedBaseContacts.length >=
              otherContact.resolvedBaseContacts.length
          ? contact.resolvedBaseContacts
          : otherContact.resolvedBaseContacts,
      systems: systems,
      equipment: equipment,
      updatedAt: remoteNewer ? remote.updatedAt : local.updatedAt,
    );
  }

  Future<void> _pushRemote(SavedClient client) async {
    _dirtyIds.add(client.id);
    await _saveMeta();
    try {
      final result = await AccountApi.instance.saveClient({
        'id': client.id,
        'name': client.name,
        'requester': client.requester,
        'cnpj': client.cnpj,
        'sites': client.sites.join('|'),
        'cep': client.cep,
        'street': client.street,
        'number': client.number,
        'complement': client.complement,
        'neighborhood': client.neighborhood,
        'city': client.city,
        'state': client.state,
        'service': client.service,
        'systemType': client.systemType,
        'baseName': client.baseName,
        'baseCargo': client.baseCargo,
        'baseEmail': client.baseEmail,
        'basePhone': client.basePhone,
        'equipment': jsonEncode([
          for (final item in client.equipment) item.toJson(),
        ]),
        'systems': jsonEncode([
          for (final item in client.resolvedSystems) item.toJson(),
        ]),
        'payload': jsonEncode(client.toJson()),
        'updatedAt': client.updatedAt.toIso8601String(),
      });
      if (result.ok) {
        _remoteIds.add(client.id);
        _dirtyIds.remove(client.id);
        _cloudStamp[client.id] = client.updatedAt.toIso8601String();
        await _saveMeta();
      }
      if (!result.ok && result.reachable) {
        debugPrint('ClientStore push: ${result.error}');
      }
    } catch (error) {
      debugPrint('ClientStore push: $error');
    }
  }
}
