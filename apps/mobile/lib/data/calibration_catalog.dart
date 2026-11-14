import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/cloud_sync_gate.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const commonUncertaintyUnits = <String>[
  '°C',
  '%',
  'bar',
  'psi',
  'mm',
  'kg/m³',
  'µS/cm',
  'mS/cm',
  'S/m',
  'L',
  'cSt',
  'mA',
  'ppm',
];

String applyUncertaintyUnit(String current, String unit) {
  final trimmed = current.trim();
  if (trimmed.isEmpty) {
    return unit == '%' ? '%' : ' $unit'.trim();
  }
  final numMatch = RegExp(r'^(\s*±?\s*[\d\.,]+)').firstMatch(trimmed);
  if (numMatch != null) {
    final numPart = numMatch.group(1)!.trim();
    if (unit == '%') {
      return '$numPart%';
    }
    return '$numPart $unit';
  }
  if (unit == '%') {
    return '$trimmed%';
  }
  return '$trimmed $unit';
}

enum StandardValidity { valid, expiring, expired, unknown }

DateTime? parseCatalogDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(text);
  if (match != null) {
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    return DateTime(year, int.parse(match.group(2)!), int.parse(match.group(1)!));
  }
  return DateTime.tryParse(text);
}

String formatCatalogDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// Para que serve o padrão. Só organiza a lista e a escolha no certificado.
enum StandardCategory {
  volumetric('volumetrica', 'Volumétrica'),
  temperature('temperatura', 'Temperatura'),
  density('densidade', 'Densidade'),
  conductivity('condutividade', 'Condutividade'),
  pressure('pressao', 'Pressão'),
  telemetry('telemetria', 'Telemetria');

  const StandardCategory(this.key, this.label);

  final String key;
  final String label;

  static StandardCategory? fromKey(String raw) {
    final key = raw.trim().toLowerCase();
    for (final item in values) {
      if (item.key == key) return item;
    }
    return null;
  }
}

StandardCategory standardCategoryForKind(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      return StandardCategory.volumetric;
    case CalibrationKind.temperature:
    case CalibrationKind.temperatureMesh:
      return StandardCategory.temperature;
    case CalibrationKind.density:
      return StandardCategory.density;
    case CalibrationKind.conductivity:
      return StandardCategory.conductivity;
    case CalibrationKind.pressure:
      return StandardCategory.pressure;
    case CalibrationKind.telemetry:
      return StandardCategory.telemetry;
  }
}

/// Sugestão de categoria para padrões antigos, pelo nome/tipo/unidade.
StandardCategory? guessStandardCategory({
  required String name,
  required String type,
  required String uncertainty,
}) {
  final nameKey = foldPersonKey(name);
  final text = foldPersonKey('$name $type');
  final unit = uncertainty.toLowerCase();
  // "GS 001 - T" / "GS 001 - D": o mesmo Coriolis cadastrado por grandeza.
  if (RegExp(r'\st$').hasMatch(nameKey) ||
      text.contains('termometro') ||
      text.contains('temperatura') ||
      text.contains('pt100') ||
      text.contains('bloco seco') ||
      unit.contains('°c')) {
    return StandardCategory.temperature;
  }
  if (RegExp(r'\sd$').hasMatch(nameKey) ||
      text.contains('densimetro') ||
      text.contains('densidade') ||
      unit.contains('kg/m')) {
    return StandardCategory.density;
  }
  if (text.contains('condutiv') || unit.contains('s/cm') || unit.contains('s/m')) {
    return StandardCategory.conductivity;
  }
  if (text.contains('manometro') ||
      text.contains('pressao') ||
      unit.contains('bar') ||
      unit.contains('psi')) {
    return StandardCategory.pressure;
  }
  if (text.contains('trena') || text.contains('telemetria') || unit.contains('mm')) {
    return StandardCategory.telemetry;
  }
  if (text.contains('coriolis') ||
      text.contains('prova') ||
      text.contains('volumetric') ||
      unit.contains('%') ||
      RegExp(r'(^|\s)l$').hasMatch(unit)) {
    return StandardCategory.volumetric;
  }
  return null;
}

const standardOwnerGs = 'gs';
const standardOwnerClient = 'client';

class CatalogStandard {
  const CatalogStandard({
    required this.id,
    this.name = '',
    this.type = 'Outro',
    this.serial = '',
    this.certificate = '',
    this.validity = '',
    this.uncertainty = '',
    this.coverageK = '',
    this.categories = const [],
    this.owner = standardOwnerGs,
    this.ownerClientId = '',
    this.ownerClientName = '',
    this.locations = const [],
  });

  final String id;
  final String name;
  final String type;
  final String serial;
  final String certificate;
  final String validity;
  final String uncertainty;
  /// Fator k do certificado deste padrão (cálculo de U), não do medidor.
  final String coverageK;
  final List<StandardCategory> categories;
  /// [standardOwnerGs] ou [standardOwnerClient]. Não sai no certificado.
  final String owner;
  final String ownerClientId;
  final String ownerClientName;
  /// Onde o padrão é usado (ex.: cliente com o mesmo padrão em vários estados).
  final List<String> locations;

  bool get isClientOwned => owner == standardOwnerClient;

  String get ownerLabel => isClientOwned
      ? (ownerClientName.trim().isEmpty
          ? 'Do cliente'
          : 'Cliente: ${ownerClientName.trim()}')
      : 'GS Soluções';

  String get locationsLabel => [
    for (final item in locations)
      if (item.trim().isNotEmpty) item.trim(),
  ].join(', ');

  StandardCategory? get suggestedCategory => guessStandardCategory(
    name: name,
    type: type,
    uncertainty: uncertainty,
  );

  /// Local cadastrado que bate com o lugar do certificado, ou vazio.
  String locationMatching(String place) {
    final target = foldPersonKey(place);
    if (target.isEmpty) return '';
    final targetWords = {
      for (final word in target.split(' '))
        if (word.length >= 4) word,
    };
    for (final raw in locations) {
      final location = foldPersonKey(raw);
      if (location.isEmpty) continue;
      if (target.contains(location) || location.contains(target)) return raw;
      for (final word in location.split(' ')) {
        if (word.length >= 4 && targetWords.contains(word)) return raw;
      }
    }
    return '';
  }

  bool belongsToClient({required String clientId, required String clientName}) {
    if (!isClientOwned) return false;
    final id = clientId.trim();
    if (id.isNotEmpty && ownerClientId.trim() == id) return true;
    final name = foldPersonKey(clientName);
    return name.isNotEmpty && foldPersonKey(ownerClientName) == name;
  }

  DateTime? get validityDate => parseCatalogDate(validity);

  StandardValidity get validityStatus {
    final date = validityDate;
    if (date == null) return StandardValidity.unknown;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final until = DateTime(date.year, date.month, date.day);
    if (until.isBefore(day)) return StandardValidity.expired;
    if (!until.isAfter(day.add(const Duration(days: 30)))) {
      return StandardValidity.expiring;
    }
    return StandardValidity.valid;
  }

  String get validityLabel {
    switch (validityStatus) {
      case StandardValidity.valid:
        return 'Válido';
      case StandardValidity.expiring:
        return 'A vencer';
      case StandardValidity.expired:
        return 'Vencido';
      case StandardValidity.unknown:
        return 'Sem data';
    }
  }

  int? get daysToExpire {
    final date = validityDate;
    if (date == null) return null;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final until = DateTime(date.year, date.month, date.day);
    return until.difference(day).inDays;
  }

  bool get isFilled => name.trim().isNotEmpty || serial.trim().isNotEmpty;

  CatalogStandard copyWith({
    String? id,
    String? name,
    String? type,
    String? serial,
    String? certificate,
    String? validity,
    String? uncertainty,
    String? coverageK,
    List<StandardCategory>? categories,
    String? owner,
    String? ownerClientId,
    String? ownerClientName,
    List<String>? locations,
  }) {
    return CatalogStandard(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      serial: serial ?? this.serial,
      certificate: certificate ?? this.certificate,
      validity: validity ?? this.validity,
      uncertainty: uncertainty ?? this.uncertainty,
      coverageK: coverageK ?? this.coverageK,
      categories: categories ?? this.categories,
      owner: owner ?? this.owner,
      ownerClientId: ownerClientId ?? this.ownerClientId,
      ownerClientName: ownerClientName ?? this.ownerClientName,
      locations: locations ?? this.locations,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'serial': serial,
    'certificate': certificate,
    'validity': validity,
    'uncertainty': uncertainty,
    'coverageK': coverageK,
    'categories': [for (final item in categories) item.key],
    'owner': owner,
    'ownerClientId': ownerClientId,
    'ownerClientName': ownerClientName,
    'locations': locations,
  };

  factory CatalogStandard.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final rawLocations = json['locations'];
    final owner = jsonText(json['owner']);
    return CatalogStandard(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      name: jsonText(json['name']),
      type: jsonText(json['type']).isEmpty ? 'Outro' : jsonText(json['type']),
      serial: jsonText(json['serial']),
      certificate: jsonText(json['certificate']),
      validity: jsonText(json['validity']),
      uncertainty: jsonText(json['uncertainty']),
      coverageK: jsonText(json['coverageK']),
      categories: [
        if (rawCategories is List)
          for (final item in rawCategories)
            if (StandardCategory.fromKey('$item') case final category?)
              category,
      ],
      owner: owner == standardOwnerClient ? standardOwnerClient : standardOwnerGs,
      ownerClientId: jsonText(json['ownerClientId']),
      ownerClientName: jsonText(json['ownerClientName']),
      locations: [
        if (rawLocations is List)
          for (final item in rawLocations)
            if ('$item'.trim().isNotEmpty) '$item'.trim(),
      ],
    );
  }
}

class CatalogFluid {
  const CatalogFluid({
    required this.id,
    this.name = '',
    this.densityMin = '',
    this.densityMax = '',
    this.viscosityMin = '',
    this.viscosityMax = '',
    this.densityRefTemp = fluidDensityRefTempDefault,
    this.viscosityRefTemp = fluidViscosityRefTempDefault,
  });

  final String id;
  final String name;
  final String densityMin;
  final String densityMax;
  final String viscosityMin;
  final String viscosityMax;
  /// Temperatura de referência da densidade (Norma: 20 °C).
  final String densityRefTemp;
  /// Temperatura de referência da viscosidade (Norma: 40 °C).
  final String viscosityRefTemp;

  /// Getter legado para manter compatibilidade
  String get temperature => densityRefTemp;

  bool get isFilled => name.trim().isNotEmpty;

  String get densityRangeLabel => catalogRangeLabel(densityMin, densityMax);

  String get viscosityRangeLabel =>
      catalogRangeLabel(viscosityMin, viscosityMax);

  String get summary {
    return [
      if (densityRangeLabel.isNotEmpty) 'Dens. $densityRangeLabel ($densityRefTemp)',
      if (viscosityRangeLabel.isNotEmpty) 'Visc. $viscosityRangeLabel ($viscosityRefTemp)',
    ].join(' · ');
  }

  CatalogFluid copyWith({
    String? id,
    String? name,
    String? densityMin,
    String? densityMax,
    String? viscosityMin,
    String? viscosityMax,
    String? densityRefTemp,
    String? viscosityRefTemp,
    String? temperature,
  }) {
    return CatalogFluid(
      id: id ?? this.id,
      name: name ?? this.name,
      densityMin: densityMin ?? this.densityMin,
      densityMax: densityMax ?? this.densityMax,
      viscosityMin: viscosityMin ?? this.viscosityMin,
      viscosityMax: viscosityMax ?? this.viscosityMax,
      densityRefTemp: densityRefTemp ?? (temperature ?? this.densityRefTemp),
      viscosityRefTemp: viscosityRefTemp ?? this.viscosityRefTemp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'densityMin': densityMin,
    'densityMax': densityMax,
    'viscosityMin': viscosityMin,
    'viscosityMax': viscosityMax,
    'densityRefTemp': densityRefTemp.trim().isEmpty
        ? fluidDensityRefTempDefault
        : densityRefTemp,
    'viscosityRefTemp': viscosityRefTemp.trim().isEmpty
        ? fluidViscosityRefTempDefault
        : viscosityRefTemp,
    // Legado: apps antigos liam um único campo de temperatura.
    'temperature': densityRefTemp.trim().isEmpty
        ? fluidDensityRefTempDefault
        : densityRefTemp,
    'density': densityRangeLabel,
    'viscosity': viscosityRangeLabel,
  };

  factory CatalogFluid.fromJson(Map<String, dynamic> json) {
    final legacyDensity = jsonText(json['density']);
    final legacyViscosity = jsonText(json['viscosity']);
    final densityMin = jsonText(json['densityMin']);
    final densityMax = jsonText(json['densityMax']);
    final viscosityMin = jsonText(json['viscosityMin']);
    final viscosityMax = jsonText(json['viscosityMax']);
    final legacyTemp = jsonText(json['temperature']);
    final densityRefTemp = jsonText(json['densityRefTemp']);
    final viscosityRefTemp = jsonText(json['viscosityRefTemp']);
    return CatalogFluid(
      id: jsonText(json['id']).isEmpty ? _id() : jsonText(json['id']),
      name: jsonText(json['name']),
      densityMin: densityMin.isNotEmpty ? densityMin : legacyDensity,
      densityMax: densityMax,
      viscosityMin: viscosityMin.isNotEmpty ? viscosityMin : legacyViscosity,
      viscosityMax: viscosityMax,
      densityRefTemp: densityRefTemp.isNotEmpty
          ? densityRefTemp
          : (legacyTemp.isNotEmpty ? legacyTemp : fluidDensityRefTempDefault),
      viscosityRefTemp: viscosityRefTemp.isNotEmpty
          ? viscosityRefTemp
          : fluidViscosityRefTempDefault,
    );
  }
}

/// Temperatura de referência padrão da densidade (Norma).
const fluidDensityRefTempDefault = '20 °C';
/// Temperatura de referência padrão da viscosidade (Norma).
const fluidViscosityRefTempDefault = '40 °C';

/// Constante legada mantida para retrocompatibilidade
const fluidReferenceTemperatureDefault = fluidDensityRefTempDefault;

String catalogRangeLabel(String min, String max) {
  final a = min.trim();
  final b = max.trim();
  if (a.isEmpty && b.isEmpty) return '';
  if (a.isNotEmpty && b.isNotEmpty) return '$a – $b';
  return a.isNotEmpty ? a : b;
}

class StandardAlert {
  const StandardAlert({required this.standard, required this.message});

  final CatalogStandard standard;
  final String message;
}

class CalibrationCatalog extends ChangeNotifier {
  CalibrationCatalog._();
  static final instance = CalibrationCatalog._();

  static const _standardsKey = 'gs_calibration_standards_v1';
  static const _deletedStandardsKey = 'gs_calibration_deleted_standards_v1';
  static const _fluidsKey = 'gs_calibration_fluids_v1';
  static const _deletedFluidsKey = 'gs_calibration_deleted_fluids_v1';

  List<CatalogStandard> _standards = [];
  List<CatalogFluid> _fluids = [];
  final _remoteStandardIds = <String>{};
  final _deletedStandardIds = <String>{};
  final _remoteFluidIds = <String>{};
  final _deletedFluidIds = <String>{};
  var _loaded = false;

  List<CatalogStandard> get standards => List.unmodifiable(_standards);
  List<CatalogFluid> get fluids => List.unmodifiable(_fluids);

  List<StandardAlert> get alerts {
    final items = <StandardAlert>[];
    for (final item in _standards) {
      final days = item.daysToExpire;
      if (days == null) continue;
      if (days < 0) {
        items.add(
          StandardAlert(
            standard: item,
            message:
                '${item.name} vencido há ${-days} dia(s) (val. ${item.validity}).',
          ),
        );
      } else if (days <= 30) {
        items.add(
          StandardAlert(
            standard: item,
            message:
                '${item.name} vence em $days dia(s) (${item.validity}).',
          ),
        );
      }
    }
    items.sort((a, b) => (a.standard.daysToExpire ?? 0).compareTo(b.standard.daysToExpire ?? 0));
    return items;
  }

  @visibleForTesting
  void resetForTest() {
    _standards = [];
    _fluids = [];
    _remoteStandardIds.clear();
    _deletedStandardIds.clear();
    _remoteFluidIds.clear();
    _deletedFluidIds.clear();
    _loaded = false;
  }

  Future<void> load({
    List<Map<String, dynamic>>? remoteStandards,
    List<Map<String, dynamic>>? remoteFluids,
  }) async {
    if (_loaded &&
        remoteStandards == null &&
        remoteFluids == null &&
        CloudSyncGate.isFresh) {
      notifyListeners();
      return;
    }
    if (!_loaded) {
      final prefs = await SharedPreferences.getInstance();
      final deletedStandardsList = prefs.getStringList(_deletedStandardsKey) ?? [];
      _deletedStandardIds.addAll(deletedStandardsList);
      final deletedFluidsList = prefs.getStringList(_deletedFluidsKey) ?? [];
      _deletedFluidIds.addAll(deletedFluidsList);
      _standards = _readStandards(prefs.getString(_standardsKey));
      _fluids = _readFluids(prefs.getString(_fluidsKey));
      _loaded = true;
    }
    if (remoteStandards != null ||
        remoteFluids != null ||
        !CloudSyncGate.isFresh) {
      await Future.wait([
        _pullRemoteStandards(seed: remoteStandards),
        _pullRemoteFluids(seed: remoteFluids),
      ]);
    }
    notifyListeners();
  }

  Future<void> sync() async {
    await Future.wait([
      _pullRemoteStandards(),
      _pullRemoteFluids(),
    ]);
    CloudSyncGate.markSynced();
    notifyListeners();
  }

  Future<void> _pullRemoteStandards({List<Map<String, dynamic>>? seed}) async {
    try {
      List<Map<String, dynamic>> rows;
      if (seed != null) {
        rows = seed;
      } else {
        final result = await AccountApi.instance.listStandards();
        if (!result.ok) return;
        rows = result.standards;
      }
      var changed = false;
      for (final item in rows) {
        final incoming = CatalogStandard.fromJson(item);
        if (incoming.id.isEmpty) continue;
        _remoteStandardIds.add(incoming.id);
        if (_deletedStandardIds.contains(incoming.id)) continue;
        final idx = _standards.indexWhere((s) => s.id == incoming.id);
        if (idx < 0) {
          _standards.add(incoming);
          changed = true;
        } else {
          _standards[idx] = incoming;
          changed = true;
        }
      }
      if (changed) {
        await _persistStandards();
      }
      for (final std in List<CatalogStandard>.from(_standards)) {
        if (!_remoteStandardIds.contains(std.id) && !_deletedStandardIds.contains(std.id) && std.isFilled) {
          unawaited(_pushRemoteStandard(std));
        }
      }
    } catch (error) {
      debugPrint('CalibrationCatalog pull standards: $error');
    }
  }

  Future<void> _pushRemoteStandard(CatalogStandard standard) async {
    try {
      final result = await AccountApi.instance.saveStandard({
        'id': standard.id,
        'name': standard.name,
        'type': standard.type,
        'serial': standard.serial,
        'certificate': standard.certificate,
        'validity': standard.validity,
        'uncertainty': standard.uncertainty,
        'coverageK': standard.coverageK,
        'payload': jsonEncode(standard.toJson()),
      });
      if (result.ok) _remoteStandardIds.add(standard.id);
    } catch (error) {
      debugPrint('CalibrationCatalog push standard: $error');
    }
  }

  Future<void> _deleteRemoteStandard(String id) async {
    try {
      await AccountApi.instance.deleteStandard(id);
      _remoteStandardIds.remove(id);
    } catch (error) {
      debugPrint('CalibrationCatalog delete standard: $error');
    }
  }

  Future<void> _pullRemoteFluids({List<Map<String, dynamic>>? seed}) async {
    try {
      List<Map<String, dynamic>> rows;
      if (seed != null) {
        rows = seed;
      } else {
        final result = await AccountApi.instance.listFluids();
        if (!result.ok) return;
        rows = result.fluids;
      }
      var changed = false;
      for (final item in rows) {
        final incoming = CatalogFluid.fromJson(item);
        if (incoming.id.isEmpty) continue;
        _remoteFluidIds.add(incoming.id);
        if (_deletedFluidIds.contains(incoming.id)) continue;
        final idx = _fluids.indexWhere((f) => f.id == incoming.id);
        if (idx < 0) {
          _fluids.add(incoming);
          changed = true;
        } else {
          _fluids[idx] = incoming;
          changed = true;
        }
      }
      if (changed) {
        await _persistFluids();
      }
      for (final f in List<CatalogFluid>.from(_fluids)) {
        if (!_remoteFluidIds.contains(f.id) && !_deletedFluidIds.contains(f.id) && f.isFilled) {
          unawaited(_pushRemoteFluid(f));
        }
      }
    } catch (error) {
      debugPrint('CalibrationCatalog pull fluids: $error');
    }
  }

  Future<void> _pushRemoteFluid(CatalogFluid fluid) async {
    try {
      final result = await AccountApi.instance.saveFluid({
        'id': fluid.id,
        'name': fluid.name,
        'densityMin': fluid.densityMin,
        'densityMax': fluid.densityMax,
        'viscosityMin': fluid.viscosityMin,
        'viscosityMax': fluid.viscosityMax,
        'densityRefTemp': fluid.densityRefTemp,
        'viscosityRefTemp': fluid.viscosityRefTemp,
        'payload': jsonEncode(fluid.toJson()),
      });
      if (result.ok) _remoteFluidIds.add(fluid.id);
    } catch (error) {
      debugPrint('CalibrationCatalog push fluid: $error');
    }
  }

  Future<void> _deleteRemoteFluid(String id) async {
    try {
      await AccountApi.instance.deleteFluid(id);
      _remoteFluidIds.remove(id);
    } catch (error) {
      debugPrint('CalibrationCatalog delete fluid: $error');
    }
  }

  Future<CatalogStandard> saveStandard(CatalogStandard item) async {
    await load();
    var stored = item.id.trim().isEmpty
        ? item.copyWith(id: newCatalogId())
        : item;
    _deletedStandardIds.remove(stored.id);
    final next = <CatalogStandard>[];
    var found = false;
    for (final current in _standards) {
      if (current.id == stored.id) {
        next.add(stored);
        found = true;
      } else {
        next.add(current);
      }
    }
    if (!found) next.add(stored);
    _standards = next;
    await _persistStandards();
    unawaited(_pushRemoteStandard(stored));
    notifyListeners();
    return stored;
  }

  Future<void> deleteStandard(String id) async {
    await load();
    _deletedStandardIds.add(id);
    _standards = [for (final item in _standards) if (item.id != id) item];
    await _persistStandards();
    unawaited(_deleteRemoteStandard(id));
    notifyListeners();
  }

  Future<CatalogFluid> saveFluid(CatalogFluid item) async {
    await load();
    final stored = item.id.trim().isEmpty
        ? item.copyWith(id: newCatalogId())
        : item;
    _deletedFluidIds.remove(stored.id);
    final next = <CatalogFluid>[];
    var found = false;
    for (final current in _fluids) {
      if (current.id == stored.id) {
        next.add(stored);
        found = true;
      } else {
        next.add(current);
      }
    }
    if (!found) next.add(stored);
    _fluids = next;
    await _persistFluids();
    unawaited(_pushRemoteFluid(stored));
    notifyListeners();
    return stored;
  }

  Future<void> deleteFluid(String id) async {
    await load();
    _deletedFluidIds.add(id);
    _fluids = [for (final item in _fluids) if (item.id != id) item];
    await _persistFluids();
    unawaited(_deleteRemoteFluid(id));
    notifyListeners();
  }

  Future<void> _persistStandards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _standardsKey,
      jsonEncode(_standards.map((item) => item.toJson()).toList()),
    );
    await prefs.setStringList(_deletedStandardsKey, _deletedStandardIds.toList());
  }

  Future<void> _persistFluids() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _fluidsKey,
      jsonEncode(_fluids.map((item) => item.toJson()).toList()),
    );
    await prefs.setStringList(_deletedFluidsKey, _deletedFluidIds.toList());
  }

  List<CatalogStandard> _readStandards(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in decoded)
        CatalogStandard.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  List<CatalogFluid> _readFluids(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in decoded)
        CatalogFluid.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }
}

var _seq = 0;

String newCatalogId() {
  _seq += 1;
  return 'cat-${DateTime.now().microsecondsSinceEpoch}-$_seq';
}

String _id() => newCatalogId();
