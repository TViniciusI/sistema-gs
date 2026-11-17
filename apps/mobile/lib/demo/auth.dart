import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/core/config.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/cloud_sync_gate.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUser {
  const AppUser({
    required this.email,
    required this.login,
    required this.name,
    required this.role,
    required this.isDeveloper,
    required this.isClient,
    this.isTechnician = false,
    this.aliases = const [],
    this.phone = '',
    this.sector = '',
    this.status = 'aprovado',
    this.funcao = '',
    this.cargo = '',
    this.calibrationAccess = CalibrationAccess.none,
    this.permissions = 'geral',
  });

  final String email;
  final String login;
  final String name;
  final String role;
  final bool isDeveloper;
  final bool isClient;
  final bool isTechnician;
  final List<String> aliases;
  final String phone;
  final String sector;
  final String status;
  final String funcao;
  final String cargo;
  final CalibrationAccess calibrationAccess;
  final String permissions;

  /// Lista explícita de módulos (chips), sem `geral`/`todos`.
  bool get hasCustomPermissions {
    final list = permissionKeys;
    if (list.isEmpty) return false;
    return !list.contains('geral') && !list.contains('todos');
  }

  bool get isGeneralAccess => !hasCustomPermissions;

  List<String> get permissionKeys => [
    for (final p in permissions.split(','))
      if (p.trim().isNotEmpty) p.trim().toLowerCase(),
  ];

  /// Módulos padrão do técnico quando a planilha ainda está em `geral`/vazio.
  static const technicianDefaultModules = {'tecnico', 'documentos'};

  bool canAccess(String moduleKey) {
    if (hasFullAccess) return true;
    final key = moduleKey.trim().toLowerCase();
    if (key.isEmpty) return false;
    final list = permissionKeys;
    if (hasCustomPermissions) {
      if (list.contains(key)) return true;
      // Pacote de campo: quem tem Área do Técnico também vê Meus documentos (RH).
      if (key == 'documentos' && list.contains('tecnico')) return true;
      return false;
    }

    // `geral` / vazio: admin/ambos liberam tudo; técnico só o pacote de campo.
    if (resolvedSector == 'admin' ||
        role.toLowerCase().contains('admin') ||
        role.toLowerCase().contains('ambos')) {
      return true;
    }
    return technicianDefaultModules.contains(key);
  }

  String get resolvedSector {
    if (sector.isNotEmpty) return sector;
    if (isDeveloper) return 'dev';
    if (isTechnician) return 'tecnico';
    return 'admin';
  }

  bool get canManageClients => hasFullAccess || canAccess('clientes');

  /// Baixar/importar planilha de cadastro de instrumentos (escritório).
  /// Técnico de campo não deve alterar a base pelo Excel.
  bool get canManageClientCadastro =>
      hasFullAccess || canManageClients || canGenerateOs;

  bool get canGenerateOs => hasFullAccess || canAccess('gerar_os');

  bool get hasFullAccess => isCompanyOwner || isDeveloper || isDevAccount;

  /// Campo (RDO/etiquetas): técnico, Cleber/adm e quem vê todas as OS.
  bool get canWorkField =>
      hasFullAccess || canAccess('tecnico') || seesAllFieldOs;

  bool get canSeeTables => hasFullAccess || canAccess('tabelas');

  CalibrationAccess get effectiveCalibrationAccess => resolvedCalibrationAccess(
    stored: calibrationAccess,
    email: email,
    login: login,
  );

  /// Aba e preenchimento: quem tiver acesso geral, calibração ou autorização.
  bool get canSeeCalibration =>
      hasFullAccess ||
      canAccess('calibracao') ||
      canAccess('emitir_cert') ||
      effectiveCalibrationAccess != CalibrationAccess.none;

  bool get canFillCalibration => canSeeCalibration;

  /// PDF do certificado: quem tiver acesso a emitir certificado.
  bool get canIssueCertificate =>
      hasFullAccess ||
      canAccess('emitir_cert') ||
      effectiveCalibrationAccess == CalibrationAccess.issue;

  bool get isDevAccount =>
      isDeveloper || isDeveloperIdentity(email: email, login: login);

  /// Escritório / administrativo (inclui “ambos” e Cleber no papel misto).
  bool get isAdministrative {
    final sector = resolvedSector.toLowerCase();
    if (sector == 'admin') return true;
    final roleFold = role.toLowerCase();
    return roleFold.contains('admin') || roleFold.contains('escrit');
  }

  /// Vê OS da empresa (não só as atribuídas): escritório e administrativo.
  bool get seesAllFieldOs =>
      hasFullAccess ||
      isAdministrative ||
      canAccess('gerar_os') ||
      canAccess('horas') ||
      canAccess('pesquisar_os');

  bool get canManageStaff => hasFullAccess || canAccess('funcionarios');

  bool get isCompanyOwner => isCompanyOwnerIdentity(email: email, login: login);

  bool get isCleber => isCleberIdentity(email: email, login: login);

  /// Planilha de cadastro (baixar/importar) só para manutenção pelo desenvolvedor;
  /// o escritório cadastra pelas páginas do app.
  bool get canUseClientExcel => isDevAccount;

  /// Vê em Configurações a pasta das OS no Google Drive do escritório.
  bool get canSeeOfficeDrive => isCleber || isDeveloper;

  /// Só Cleber encerra a OS de verdade, reativa e pesquisa OS fechadas (ou quem tiver permissão).
  bool get canFinalizeAndReopenOs =>
      isCleber || isDeveloper || canAccess('pesquisar_os');

  bool get canSeeDocs => hasFullAccess || canAccess('documentos');

  bool get isOffice => canGenerateOs;

  /// No Início, técnicos (incluindo Cleber) veem só a própria agenda e horas.
  bool get homeAgendaOnlyMine => isTechnician || !seesAllFieldOs;

  Map<String, dynamic> toJson() => {
    'email': email,
    'login': login,
    'name': name,
    'role': role,
    'isDeveloper': isDeveloper,
    'isClient': isClient,
    'isTechnician': isTechnician,
    'aliases': aliases,
    'phone': phone,
    'sector': resolvedSector,
    'status': status,
    'funcao': funcao,
    'cargo': cargo,
    'calibrationAccess': calibrationAccessToSheet(calibrationAccess),
    'permissoes': permissions,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      email: json['email'] as String? ?? '',
      login: json['login'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'Técnico',
      isDeveloper:
          json['isDeveloper'] == true ||
          isDeveloperIdentity(
            email: json['email'] as String? ?? '',
            login: json['login'] as String? ?? '',
          ),
      isClient: json['isClient'] == true,
      isTechnician: json['isTechnician'] == true,
      aliases: [
        for (final item in (json['aliases'] as List? ?? const []))
          item.toString(),
      ],
      phone: json['phone'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      status: json['status'] as String? ?? 'aprovado',
      funcao: json['funcao'] as String? ?? '',
      cargo: json['cargo'] as String? ?? '',
      calibrationAccess: parseCalibrationAccess(
        json['calibrationAccess']?.toString() ?? json['calibracao']?.toString(),
      ),
      permissions:
          json['permissoes']?.toString() ??
          json['permissions']?.toString() ??
          'geral',
    );
  }

  AppUser copyWith({
    String? email,
    String? login,
    String? name,
    String? role,
    bool? isDeveloper,
    bool? isClient,
    bool? isTechnician,
    List<String>? aliases,
    String? phone,
    String? sector,
    String? status,
    String? funcao,
    String? cargo,
    CalibrationAccess? calibrationAccess,
    String? permissions,
  }) {
    return AppUser(
      email: email ?? this.email,
      login: login ?? this.login,
      name: name ?? this.name,
      role: role ?? this.role,
      isDeveloper: isDeveloper ?? this.isDeveloper,
      isClient: isClient ?? this.isClient,
      isTechnician: isTechnician ?? this.isTechnician,
      aliases: aliases ?? this.aliases,
      phone: phone ?? this.phone,
      sector: sector ?? this.sector,
      status: status ?? this.status,
      funcao: funcao ?? this.funcao,
      cargo: cargo ?? this.cargo,
      calibrationAccess: calibrationAccess ?? this.calibrationAccess,
      permissions: permissions ?? this.permissions,
    );
  }

  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? 'GS' : parts.first;
  }
}

AppUser appUserFromRemote(RemoteAccount account) {
  if (isPrincipalIdentity(email: account.email, login: account.login)) {
    final login = account.login;
    final migratedLogin =
        login.isEmpty || login == 'cleber' || login == 'administrativo'
        ? gsUser.login
        : login;
    final name = account.name.trim();
    final migratedName = name.isEmpty || name == 'Cleber Guimarães'
        ? gsUser.name
        : name;
    return gsUser.copyWith(
      email: account.email.isEmpty ? gsUser.email : account.email,
      login: migratedLogin,
      name: migratedName,
      phone: account.phone,
      status: 'aprovado',
      funcao: account.funcao,
      cargo: account.cargo,
      calibrationAccess: account.calibrationAccess,
    );
  }
  if (isCleberIdentity(email: account.email, login: account.login)) {
    final login = account.login;
    final migratedLogin =
        login.isEmpty || login.startsWith('cleber ') || login.startsWith('dup-')
        ? cleberUser.login
        : login;
    return cleberUser.copyWith(
      email: account.email.isEmpty ? cleberUser.email : account.email,
      login: migratedLogin,
      name: cleberUser.name,
      phone: account.phone,
      status: 'aprovado',
      funcao: account.funcao,
      cargo: account.cargo.isEmpty ? defaultTechnicianCargo : account.cargo,
      calibrationAccess: account.calibrationAccess,
    );
  }
  if (isDeveloperIdentity(email: account.email, login: account.login)) {
    final login = account.login;
    final migratedLogin = login.isEmpty || login.startsWith('dup-')
        ? viniciusUser.login
        : login;
    return viniciusUser.copyWith(
      email: account.email.isEmpty ? viniciusUser.email : account.email,
      login: migratedLogin,
      name: account.name.trim().isEmpty ? viniciusUser.name : account.name,
      phone: account.phone,
      status: 'aprovado',
      funcao: account.funcao,
      cargo: account.cargo,
      calibrationAccess: account.calibrationAccess,
    );
  }
  final isAmbos = account.role == 'ambos';
  final sector = account.role == 'admin' || isAmbos
      ? 'admin'
      : account.role == 'dev'
      ? 'dev'
      : 'tecnico';
  final name = account.name.isEmpty ? account.login : account.name;
  final rawLogin = account.login.isEmpty
      ? account.email.split('@').first
      : account.login;
  var user = AppUser(
    email: account.email,
    login: canonicalTechnicianLogin(
      login: rawLogin,
      email: account.email,
      name: name,
    ),
    name: name,
    role: isAmbos
        ? 'Técnico e administrativo'
        : sector == 'admin'
        ? 'Administrativo'
        : sector == 'dev'
        ? 'Desenvolvedor'
        : 'Técnico',
    isDeveloper: sector == 'dev',
    isClient: account.email == gsUser.email,
    isTechnician: sector == 'tecnico' || sector == 'dev' || isAmbos,
    phone: account.phone,
    sector: sector,
    status: account.status,
    funcao: account.funcao,
    cargo: account.cargo,
    calibrationAccess: account.calibrationAccess,
    permissions: account.permissions,
  );
  for (final known in allowedUsers) {
    if (!known.isTechnician) continue;
    final overlap = technicianIdentityKeys(known).intersection(
      assignmentIdsFor(email: account.email, login: rawLogin, aliases: [name]),
    );
    if (overlap.isEmpty) continue;
    user = user.copyWith(
      aliases: [
        ...{...known.aliases, ...user.aliases},
      ],
    );
    break;
  }
  return user;
}

const gsUser = AppUser(
  email: 'administrativo@gssolucoestec.com.br',
  login: 'gssolucoes',
  name: 'GS Soluções',
  role: 'Administrativo',
  isDeveloper: false,
  isClient: true,
  sector: 'admin',
  aliases: ['gs', 'administrativo', 'gs soluções', 'gs solucoes', 'gssolucoes'],
);

const cleberUser = AppUser(
  email: 'cleber@gssolucoestec.com.br',
  login: 'cleber',
  name: 'Cleber Guimarães',
  role: 'Técnico e administrativo',
  isDeveloper: false,
  isClient: false,
  isTechnician: true,
  sector: 'admin',
  aliases: ['cleber guimarães', 'cleber guimaraes', 'cleberguimaraes'],
  cargo: defaultTechnicianCargo,
);

const felipeUser = AppUser(
  email: 'felipe@gssolucoestec.com.br',
  login: 'felps1255',
  name: 'Felipe Souza',
  role: 'Técnico',
  isDeveloper: false,
  isClient: false,
  isTechnician: true,
  sector: 'tecnico',
  aliases: ['felipe', 'felps1255'],
  cargo: defaultTechnicianCargo,
  permissions: 'tecnico,documentos',
);

const andreUser = AppUser(
  email: 'andre@gssolucoestec.com.br',
  login: 'nascimento',
  name: 'André',
  role: 'Técnico',
  isDeveloper: false,
  isClient: false,
  isTechnician: true,
  sector: 'tecnico',
  aliases: ['andre', 'andré', 'nascimento', 'andre nascimento'],
  cargo: defaultTechnicianCargo,
  permissions: 'tecnico,documentos',
);

const viniciusUser = AppUser(
  email: 'viniciusmagalhaes2y@gmail.com',
  login: 'vinicius',
  name: 'Vinicius Magalhães',
  role: 'Desenvolvedor',
  isDeveloper: true,
  isClient: false,
  isTechnician: true,
  sector: 'dev',
);

const allowedUsers = [gsUser, cleberUser, felipeUser, andreUser, viniciusUser];

const seedPassHashes = {
  'gssolucoes':
      'b06b393ba66d6dd7f7f9ecabc154f12e24e6be8413689f902e1e1c158c13201b',
  'cleber': 'ad7d93d193cd354bad0bb1442129124cf7ffe65568517e7db215dc03eba6342a',
  'vinicius':
      '35d3069de28a6c4824e5c84114be99b0880009290feef92d70b9ae08871d4323',
};

List<AppUser> get fieldTechnicians {
  final list = <AppUser>[];

  void consider(AppUser user) {
    if (!user.isTechnician) return;
    final normalized = _withCanonicalFieldLogin(user);
    final index = list.indexWhere(
      (item) => sameFieldTechnician(item, normalized),
    );
    if (index < 0) {
      list.add(normalized);
      return;
    }
    if (_preferFieldTechnician(normalized, list[index])) {
      list[index] = normalized;
    }
  }

  for (final remote in StaffStore.instance.technicianAccounts) {
    consider(appUserFromRemote(remote));
  }
  if (StaffStore.instance.users.isEmpty) {
    for (final user in allowedUsers) {
      consider(user);
    }
  }
  return list;
}

Map<String, String> technicianRdoCargos() {
  final map = <String, String>{};
  for (final user in fieldTechnicians) {
    final value = user.cargo.trim();
    if (value.isEmpty) continue;
    final key = personFirstKey(user.name);
    if (key.isEmpty) continue;
    map[key] = value;
  }
  return map;
}

String technicianCargoFor(String name, {RdoData? rdo}) {
  final key = personFirstKey(name);
  if (key.isNotEmpty) {
    for (final user in fieldTechnicians) {
      if (personFirstKey(user.name) != key) continue;
      if (user.cargo.trim().isNotEmpty) return user.cargo.trim();
    }
    for (final user in StaffStore.instance.employees) {
      if (personFirstKey(user.name) != key) continue;
      if (user.cargo.trim().isNotEmpty) return user.cargo.trim();
    }
    final stored = rdo?.technicianCargos[key]?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
  }
  final fallback = rdo?.technicianCargo.trim() ?? '';
  if (fallback.isNotEmpty) return fallback;
  return defaultTechnicianCargo;
}

Map<String, String> snapshotTechnicianCargos(
  SavedOs os,
  Iterable<String> names, {
  Map<String, String> overrides = const {},
}) {
  final map = Map<String, String>.from(os.rdo.technicianCargos);
  for (final name in names) {
    final key = personFirstKey(name);
    if (key.isEmpty) continue;
    final override = overrides[key]?.trim() ?? '';
    map[key] = override.isNotEmpty
        ? override
        : technicianCargoFor(name, rdo: os.rdo);
  }
  return map;
}

Future<void> persistTechnicianCargo(String name, String cargo) async {
  final value = cargo.trim();
  if (value.isEmpty) return;
  final key = personFirstKey(name);
  if (key.isEmpty) return;
  AppUser? user;
  for (final item in fieldTechnicians) {
    if (personFirstKey(item.name) != key) continue;
    user = item;
    break;
  }
  if (user == null) return;
  final email = user.email.trim();
  if (email.isEmpty || !email.contains('@')) return;
  await StaffStore.instance.patchCargo(email, value);
  await AccountApi.instance.setCargo(email: email, cargo: value);
}

Map<String, String> technicianRdoFuncoes() {
  final map = <String, String>{};
  for (final user in fieldTechnicians) {
    final value = user.funcao.trim();
    if (value.isEmpty) continue;
    final key = personFirstKey(user.name);
    if (key.isEmpty) continue;
    map[key] = value;
  }
  return map;
}

List<String> teamNamesForOs(SavedOs os, {String signedBy = ''}) {
  final byKey = <String, String>{};
  final order = <String>[];

  void add(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name == '-') return;
    final key = personFirstKey(name);
    if (key.isEmpty) return;
    if (!byKey.containsKey(key)) {
      order.add(key);
      byKey[key] = name;
    } else if (name.length > byKey[key]!.length) {
      byKey[key] = name;
    }
  }

  for (final part in os.technicianName.split(',')) {
    add(part);
  }
  for (final assignee in os.assigneeEmails) {
    final value = assignee.trim().toLowerCase();
    if (value.isEmpty) continue;
    for (final tech in fieldTechnicians) {
      final keys = technicianIdentityKeys(tech);
      if (keys.contains(value) ||
          (value.contains('@') && keys.contains(value.split('@').first))) {
        add(tech.name);
        break;
      }
    }
  }
  if (order.isEmpty) add(signedBy);
  if (order.isEmpty) return const ['-'];
  return [for (final key in order) byKey[key]!];
}

bool personInNames(String name, Iterable<String> names) {
  final key = personFirstKey(name);
  if (key.isEmpty) return false;
  return names.any((item) => personFirstKey(item) == key);
}

/// Equipe da OS que esteve no dia deste RDO (sem os marcados como ausentes).
/// Sempre inclui quem assinou o RDO — mesmo se não estiver na lista da OS
/// (antes sumia do card "Horas da equipe").
List<String> presentTeamForRdo(
  SavedOs os,
  SavedRdo rdo, {
  String signedBy = '',
}) {
  final lead = (signedBy.trim().isNotEmpty
          ? signedBy
          : rdo.responsibleName)
      .trim();
  final team = teamNamesForOs(os, signedBy: lead);
  final candidates = <String>[
    for (final name in team)
      if (name.trim().isNotEmpty && name != '-') name.trim(),
  ];
  if (lead.isNotEmpty && lead != '-' && !personInNames(lead, candidates)) {
    candidates.add(lead);
  }
  if (rdo.absentNames.isEmpty) {
    return candidates.isEmpty ? const ['-'] : candidates;
  }
  final present = [
    for (final name in candidates)
      if (!personInNames(name, rdo.absentNames)) name,
  ];
  return present.isEmpty ? const ['-'] : present;
}

AppUser _withCanonicalFieldLogin(AppUser user) {
  final login = canonicalTechnicianLogin(
    login: user.login,
    email: user.email,
    name: user.name,
  );
  if (login == user.login) return user;
  return user.copyWith(login: login);
}

bool _isSeedTechnicianStub(AppUser user) {
  final login = foldPersonKey(user.login);
  final mail = user.email.trim().toLowerCase();
  if (login == 'felipe' && login != 'felps1255') return true;
  if (mail == 'felipe@gssolucoestec.com.br' && login != 'felps1255') {
    return true;
  }
  if (mail == 'andre@gssolucoestec.com.br') return true;
  if (login == 'andre') return true;
  return false;
}

bool _isRemoteTechnician(AppUser user) {
  return StaffStore.instance.technicianAccounts.any(
    (item) => sameFieldTechnician(appUserFromRemote(item), user),
  );
}

bool _preferFieldTechnician(AppUser incoming, AppUser current) {
  final incomingStub = _isSeedTechnicianStub(incoming);
  final currentStub = _isSeedTechnicianStub(current);
  if (currentStub && !incomingStub) return true;
  if (incomingStub && !currentStub) return false;
  final incomingLogin = foldPersonKey(incoming.login);
  final currentLogin = foldPersonKey(current.login);
  if (incomingLogin == 'felps1255' && currentLogin != 'felps1255') return true;
  if (currentLogin == 'felps1255') return false;
  if (incomingLogin == 'nascimento' && currentLogin != 'nascimento') {
    return true;
  }
  if (currentLogin == 'nascimento') return false;
  final incomingRemote = _isRemoteTechnician(incoming);
  final currentRemote = _isRemoteTechnician(current);
  if (incomingRemote && !currentRemote) return true;
  if (currentRemote && !incomingRemote) return false;
  return incoming.name.trim().length > current.name.trim().length;
}

Set<String> technicianIdentityKeys(AppUser user) {
  final keys = assignmentIdsFor(
    email: user.email,
    login: user.login,
    aliases: user.aliases,
  );
  final first = personFirstKey(user.name);
  final login = foldPersonKey(user.login);
  if (first == 'felipe' || login == 'felipe' || login == 'felps1255') {
    keys.addAll(const {'felipe', 'felps1255'});
  }
  if (first == 'andre' ||
      first == 'nascimento' ||
      login == 'andre' ||
      login == 'nascimento') {
    keys.addAll(const {'andre', 'andré', 'nascimento'});
  }
  keys.removeWhere((item) => item.isEmpty);
  return keys;
}

bool sameFieldTechnician(AppUser a, AppUser b) {
  final aKeys = technicianIdentityKeys(a);
  final bKeys = technicianIdentityKeys(b);
  return aKeys.intersection(bKeys).isNotEmpty;
}

Set<String> assigneeKeysFor(AppUser user) {
  final keys = technicianIdentityKeys(user);
  for (final remote in StaffStore.instance.technicianAccounts) {
    final other = appUserFromRemote(remote);
    if (!sameFieldTechnician(user, other)) continue;
    keys.addAll(assignmentIdsFor(email: remote.email, login: remote.login));
  }
  return keys;
}

AppUser canonicalSessionUser(AppUser account) {
  final byLogin = matchUser(account.login);
  final byEmail = matchUser(account.email);
  final base = byLogin ?? byEmail;
  if (base != null) {
    return base.copyWith(
      phone: account.phone.isNotEmpty ? account.phone : base.phone,
      funcao: account.funcao.isNotEmpty ? account.funcao : base.funcao,
      cargo: account.cargo.isNotEmpty ? account.cargo : base.cargo,
      status: account.status.isNotEmpty ? account.status : base.status,
      calibrationAccess: account.calibrationAccess,
      // Sempre mantém o que veio da planilha / sessão (não volta para seed `geral`).
      permissions: account.permissions.trim().isNotEmpty
          ? account.permissions
          : base.permissions,
      sector: account.sector.isNotEmpty ? account.sector : base.sector,
      role: account.role.isNotEmpty ? account.role : base.role,
      isTechnician: account.isTechnician || base.isTechnician,
    );
  }
  if (isCleberIdentity(email: account.email, login: account.login)) {
    return cleberUser.copyWith(
      email: account.email.isEmpty ? cleberUser.email : account.email,
      login: account.login.isEmpty ? cleberUser.login : account.login,
      name: cleberUser.name,
      phone: account.phone,
      funcao: account.funcao,
      cargo: account.cargo.isNotEmpty ? account.cargo : cleberUser.cargo,
      permissions: account.permissions.trim().isNotEmpty
          ? account.permissions
          : cleberUser.permissions,
      calibrationAccess: account.calibrationAccess,
    );
  }
  if (isPrincipalIdentity(email: account.email, login: account.login)) {
    return gsUser.copyWith(
      email: account.email.isEmpty ? gsUser.email : account.email,
      login: account.login.isEmpty ? gsUser.login : account.login,
      name: gsUser.name,
      phone: account.phone,
      permissions: account.permissions.trim().isNotEmpty
          ? account.permissions
          : gsUser.permissions,
      calibrationAccess: account.calibrationAccess,
    );
  }
  return account;
}

AppUser? matchUser(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return null;
  for (final user in allowedUsers) {
    if (user.email == value || user.login == value) return _withPatch(user);
    if (user.aliases.contains(value)) return _withPatch(user);
    final localPart = user.email.split('@').first;
    if (localPart == value) return _withPatch(user);
  }
  for (final patch in _identityPatches.values) {
    final login = (patch['login'] ?? '').toLowerCase();
    final email = (patch['email'] ?? '').toLowerCase();
    final aliases = (patch['aliases'] ?? '')
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty);
    if (value == login || value == email || aliases.contains(value)) {
      final baseEmail = patch['baseEmail'] ?? email;
      AppUser? base;
      for (final user in allowedUsers) {
        if (user.email == baseEmail || user.login == baseEmail) {
          base = user;
          break;
        }
      }
      if (base != null) {
        return base.copyWith(
          email: email.isEmpty ? base.email : email,
          login: login.isEmpty ? base.login : login,
          name: (patch['name'] ?? '').isEmpty ? base.name : patch['name'],
          phone: patch['phone'] ?? base.phone,
        );
      }
    }
  }
  for (final remote in StaffStore.instance.users) {
    if (remote.status != 'aprovado' || !remote.active) continue;
    if (remote.email == value || remote.login == value) {
      return _withPatch(appUserFromRemote(remote));
    }
    if (remote.email.split('@').first == value) {
      return _withPatch(appUserFromRemote(remote));
    }
  }
  return null;
}

AppUser _withPatch(AppUser user) {
  final patch = _identityPatches[user.email] ?? _identityPatches[user.login];
  if (patch == null) return user;
  return user.copyWith(
    email: (patch['email'] ?? '').isEmpty ? user.email : patch['email'],
    login: (patch['login'] ?? '').isEmpty ? user.login : patch['login'],
    name: (patch['name'] ?? '').isEmpty ? user.name : patch['name'],
    phone: patch['phone'] ?? user.phone,
  );
}

Map<String, Map<String, String>> _identityPatches = {};
Map<String, String> _passOverrides = {};

class AuthSession extends ChangeNotifier {
  AuthSession._();
  static final instance = AuthSession._();

  static const _sessionKey = 'gs_session_login';
  static const _profileKey = 'gs_session_profile';
  static const _patchesKey = 'gs_account_patches';
  static const _passKey = 'gs_pass_overrides';
  static const _greetKey = 'gs_pref_greet_full_name';

  AppUser? user;
  var greetWithFullName = false;
  String? _sessionPassword;

  bool get isSignedIn => user != null;

  String get greetingName {
    final current = user;
    if (current == null) return 'GS';
    return greetWithFullName ? current.name : current.shortName;
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    await StaffStore.instance.loadCache();
    await _loadLocalPrefs(prefs);
    final saved = prefs.getString(_sessionKey);
    if (saved == null) return;
    AppUser? matched;
    final rawProfile = prefs.getString(_profileKey);
    if (rawProfile != null && rawProfile.isNotEmpty) {
      try {
        matched = AppUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawProfile) as Map),
        );
      } catch (_) {}
    }
    matched ??= matchUser(saved);
    if (matched == null) return;
    matched = canonicalSessionUser(matched);
    matched = _applyRosterPermissions(matched);
    user = matched;
    await prefs.setString(_profileKey, jsonEncode(matched.toJson()));
    // Abre na hora com o que está no aparelho; a planilha sincroniza depois.
    await CloudSyncGate.localOnly(() => _loadLocalStores(matched!));
    notifyListeners();
    unawaited(_syncAfterRestore(matched));
  }

  Future<void> _loadLocalStores(AppUser matched) async {
    await Future.wait([
      FieldStore.instance.load(
        matched.email,
        seeAll: matched.seesAllFieldOs,
        login: matched.login,
        aliases: matched.aliases,
        viewerIds: assigneeKeysFor(matched),
      ),
      ClientStore.instance.load(),
      CalibrationCatalog.instance.load(),
      CalibrationStore.instance.load(),
    ]);
  }

  /// Puxa da planilha o que outros aparelhos salvaram (volta ao app, timer).
  Future<void> backgroundSync() async {
    if (user == null || CloudSyncGate.pending || CloudSyncGate.isFresh) return;
    CloudSyncGate.pending = true;
    try {
      await Future.wait<Object?>([
        FieldStore.instance.sync(),
        CalibrationStore.instance.sync(),
        ClientStore.instance.sync(),
        CalibrationCatalog.instance.sync(),
      ]);
      CloudSyncGate.markSynced();
    } catch (error) {
      debugPrint('AuthSession backgroundSync: $error');
    } finally {
      CloudSyncGate.pending = false;
    }
  }

  Future<void> _syncAfterRestore(AppUser matched) async {
    CloudSyncGate.pending = true;
    try {
      await _loadStores(matched, waitStaff: false);
    } catch (error) {
      debugPrint('AuthSession sync: $error');
    } finally {
      CloudSyncGate.pending = false;
    }
    final current = user;
    if (current == null) return;
    final refreshed = _applyRosterPermissions(current);
    if (refreshed.permissions != current.permissions) {
      user = refreshed;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, jsonEncode(refreshed.toJson()));
    }
    notifyListeners();
  }

  AppUser _applyRosterPermissions(AppUser account) {
    if (account.hasFullAccess) return account;
    final email = account.email.trim().toLowerCase();
    final login = account.login.trim().toLowerCase();
    for (final remote in StaffStore.instance.directory) {
      final remoteEmail = remote.email.trim().toLowerCase();
      final remoteLogin = remote.login.trim().toLowerCase();
      if (remoteEmail != email &&
          remoteLogin != login &&
          remoteEmail.split('@').first != login) {
        continue;
      }
      final perms = remote.permissions.trim();
      if (perms.isEmpty) return account;
      return account.copyWith(permissions: perms);
    }
    return account;
  }

  Future<void> _loadLocalPrefs(SharedPreferences prefs) async {
    greetWithFullName = prefs.getBool(_greetKey) ?? false;
    _passOverrides = {
      for (final entry in (prefs.getStringList(_passKey) ?? const <String>[]))
        if (entry.contains('='))
          entry.substring(0, entry.indexOf('=')): entry.substring(
            entry.indexOf('=') + 1,
          ),
    };
    final rawPatches = prefs.getString(_patchesKey);
    _identityPatches = {};
    if (rawPatches == null || rawPatches.isEmpty) return;
    try {
      final decoded = jsonDecode(rawPatches);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is Map) {
            _identityPatches[key.toString()] = {
              for (final item in value.entries)
                item.key.toString(): item.value.toString(),
            };
          }
        });
      }
    } catch (_) {}
  }

  Future<void> setGreetWithFullName(bool value) async {
    greetWithFullName = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_greetKey, value);
    notifyListeners();
  }

  Future<String?> signIn(String login, {String password = ''}) async {
    final preview = matchUser(login);
    final remoteLogin = preview?.login ?? login.trim();
    final extraLogins = <String>[
      login,
      remoteLogin,
      ...?preview?.aliases,
      ..._patchLoginsFor(preview),
    ];
    var remote = await AccountApi.instance.login(
      remoteLogin,
      password,
      email: preview?.email ?? '',
      extraLogins: extraLogins,
    );
    if (!remote.ok && !remote.reachable) {
      remote = await AccountApi.instance.login(
        remoteLogin,
        password,
        email: preview?.email ?? '',
        extraLogins: extraLogins,
      );
    }
    // Planilha manda nas permissões: se o login remoto ok, usa esse usuário.
    if (remote.ok && remote.user != null) {
      return _enter(appUserFromRemote(remote.user!), password: password);
    }
    if (remote.pending) {
      return remote.error ?? 'Conta aguardando aprovação do escritório.';
    }
    if (remote.wrongPassword) {
      return remote.error ?? 'Senha incorreta.';
    }
    final seeded = preview ?? matchUser(login);
    final matched = seeded;
    if (remote.reachable && remote.error != null) {
      final notFound = (remote.error ?? '').toLowerCase().contains(
        'não encontrado',
      );
      if (notFound &&
          matched != null &&
          await _passwordOk(matched, password, extraLogins: extraLogins)) {
        return _enter(matched, password: password);
      }
      return remote.error;
    }
    if (matched == null) {
      return remote.error ?? 'Usuário não autorizado';
    }
    // Sem resposta da nuvem a senha só pode liberar, nunca recusar: a senha
    // guardada no app pode ser antiga e a da planilha é a que vale.
    if (!await _passwordOk(matched, password, extraLogins: extraLogins)) {
      if (!AccountApi.useRemote || AppConfig.loginGateUrl.isEmpty) {
        return 'Senha incorreta.';
      }
      return 'A nuvem não respondeu para conferir a senha. '
          'Confira a internet e toque em Entrar de novo.';
    }
    return _enter(matched, password: password);
  }

  Iterable<String> _patchLoginsFor(AppUser? account) {
    if (account == null) return const [];
    final email = account.email.trim().toLowerCase();
    final login = account.login.trim().toLowerCase();
    final out = <String>{};
    for (final patch in _identityPatches.values) {
      final patchEmail = (patch['email'] ?? '').toLowerCase();
      final base = (patch['baseEmail'] ?? '').toLowerCase();
      final patchLogin = (patch['login'] ?? '').toLowerCase();
      if (patchEmail == email ||
          base == email ||
          patchLogin == login ||
          patchEmail == login) {
        out.add(patchLogin);
        out.add(patchEmail);
        out.addAll(
          (patch['aliases'] ?? '').split(',').map((item) => item.trim()),
        );
      }
    }
    return out;
  }

  Iterable<String> _idsFor(
    AppUser account, {
    Iterable<String> extraLogins = const [],
  }) {
    return passwordIdentities(
      login: account.login,
      email: account.email,
      extraLogins: [
        ...account.aliases,
        ...extraLogins,
        ..._patchLoginsFor(account),
      ],
    );
  }

  String _matchingPassHash(
    AppUser account,
    String password, {
    Iterable<String> extraLogins = const [],
  }) {
    final ids = _idsFor(account, extraLogins: extraLogins);
    final hashes = {for (final id in ids) passwordHash(id, password)};
    for (final id in ids) {
      final expected = seedPassHashes[id];
      if (expected != null &&
          expected.isNotEmpty &&
          hashes.contains(expected)) {
        return expected;
      }
    }
    for (final stored in _passOverrides.values) {
      if (stored.isNotEmpty && hashes.contains(stored)) return stored;
    }
    return passwordHash(account.login, password);
  }

  bool _typedPasswordOk(
    AppUser account,
    String password, {
    Iterable<String> extraLogins = const [],
  }) {
    if (_sessionPassword != null &&
        _sessionPassword!.isNotEmpty &&
        _sessionPassword == password) {
      return true;
    }
    final ids = _idsFor(account, extraLogins: extraLogins);
    final hashes = {for (final id in ids) passwordHash(id, password)};
    var hasOverride = false;
    for (final id in ids) {
      final stored = _passOverrides[id];
      if (stored == null || stored.isEmpty) continue;
      hasOverride = true;
      if (hashes.contains(stored)) return true;
    }
    for (final stored in _passOverrides.values) {
      if (stored.isNotEmpty && hashes.contains(stored)) return true;
    }
    if (hasOverride) return false;
    for (final id in ids) {
      final expected = seedPassHashes[id];
      if (expected != null && expected.isNotEmpty) {
        return hashes.contains(expected);
      }
    }
    return true;
  }

  Future<bool> _passwordOk(
    AppUser account,
    String password, {
    Iterable<String> extraLogins = const [],
  }) async {
    return _typedPasswordOk(account, password, extraLogins: extraLogins);
  }

  bool _hasStoredPassword(AppUser account) {
    for (final id in _idsFor(account)) {
      final stored = _passOverrides[id];
      if (stored != null && stored.isNotEmpty) return true;
      final expected = seedPassHashes[id];
      if (expected != null && expected.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _savePassOverride(
    String email,
    String login,
    String hash, {
    Iterable<String> extraLogins = const [],
  }) async {
    final keys = passwordIdentities(
      login: login,
      email: email,
      extraLogins: extraLogins,
    );
    for (final key in keys) {
      _passOverrides[key] = hash;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_passKey, [
      for (final entry in _passOverrides.entries) '${entry.key}=${entry.value}',
    ]);
  }

  Future<void> _savePatch(AppUser account, {String? baseEmail}) async {
    final key = baseEmail ?? account.email;
    final previous =
        _identityPatches[key] ??
        _identityPatches[account.email] ??
        _identityPatches[account.login];
    final aliases = <String>{
      ...(previous?['aliases'] ?? '').split(','),
      previous?['login'] ?? '',
      previous?['email'] ?? '',
      account.login,
      account.email,
    }..removeWhere((item) => item.trim().isEmpty);
    final patch = {
      'baseEmail': previous?['baseEmail'] ?? key,
      'email': account.email,
      'login': account.login,
      'name': account.name,
      'phone': account.phone,
      'aliases': aliases.join(','),
    };
    _identityPatches[key] = patch;
    _identityPatches[account.email] = patch;
    _identityPatches[account.login] = patch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_patchesKey, jsonEncode(_identityPatches));
  }

  Future<String?> updateProfile({
    required String name,
    required String login,
    required String email,
    required String phone,
    required String currentPassword,
  }) async {
    final current = user;
    if (current == null) return 'Sessão expirada.';
    final nextName = name.trim();
    final nextLogin = login.trim().toLowerCase();
    final nextEmail = email.trim().toLowerCase();
    final nextPhone = phone.trim();
    if (nextName.isEmpty) return 'Informe o nome.';
    if (nextLogin.length < 3) {
      return 'O usuário precisa ter ao menos 3 caracteres.';
    }
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(nextLogin)) {
      return 'Use só letras, números, ponto, hífen ou underline.';
    }
    if (nextEmail.isEmpty || !nextEmail.contains('@')) {
      return 'Informe um e-mail válido.';
    }
    if (_hasStoredPassword(current)) {
      if (currentPassword.isEmpty) {
        return 'Digite a senha atual para confirmar.';
      }
      if (!await _passwordOk(
        current,
        currentPassword,
        extraLogins: [nextLogin, current.login],
      )) {
        return 'Senha atual incorreta.';
      }
    }
    final taken = matchUser(nextLogin);
    if (taken != null &&
        taken.email != current.email &&
        taken.login != current.login) {
      return 'Este usuário já está em uso.';
    }
    final extraLogins = <String>[
      current.login,
      nextLogin,
      ...current.aliases,
      ..._patchLoginsFor(current),
    ];
    final remote = await AccountApi.instance.updateProfile(
      email: current.email,
      login: current.login,
      password: currentPassword,
      name: nextName,
      newLogin: nextLogin,
      newEmail: nextEmail,
      phone: nextPhone,
      passHash: _matchingPassHash(
        current,
        currentPassword,
        extraLogins: extraLogins,
      ),
      extraLogins: extraLogins,
    );
    if (remote.ok && remote.user != null) {
      if (currentPassword.isNotEmpty) {
        await _savePassOverride(
          nextEmail,
          nextLogin,
          passwordHash(nextLogin, currentPassword),
          extraLogins: extraLogins,
        );
      }
      final merged = appUserFromRemote(remote.user!).copyWith(
        name: nextName,
        login: nextLogin,
        email: nextEmail,
        phone: nextPhone,
      );
      await _savePatch(merged, baseEmail: current.email);
      return _enter(merged, password: currentPassword);
    }
    // Salvar só neste aparelho faz a conta divergir da planilha: nos outros
    // navegadores o login passa a falhar.
    return _cloudAccountError(remote) ??
        remote.error ??
        'Não foi possível salvar o perfil.';
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final current = user;
    if (current == null) return 'Sessão expirada.';
    if (newPassword.trim().length < 4) {
      return 'A senha nova precisa ter ao menos 4 caracteres.';
    }
    if (newPassword != confirmPassword) {
      return 'As senhas não conferem.';
    }
    // Quem confere a senha atual é a nuvem: a deste aparelho pode estar velha.
    if (_hasStoredPassword(current) && currentPassword.isEmpty) {
      return 'Digite a senha atual.';
    }
    final extraLogins = <String>[
      current.login,
      ...current.aliases,
      ..._patchLoginsFor(current),
    ];
    final remote = await AccountApi.instance.changePassword(
      email: current.email,
      login: current.login,
      currentPassword: currentPassword,
      newPassword: newPassword,
      passHash: _matchingPassHash(
        current,
        currentPassword,
        extraLogins: extraLogins,
      ),
      extraLogins: extraLogins,
    );
    if (remote.ok) {
      await _savePassOverride(
        current.email,
        current.login,
        passwordHash(current.login, newPassword),
        extraLogins: extraLogins,
      );
      _sessionPassword = newPassword;
      if (remote.user != null) {
        return _enter(appUserFromRemote(remote.user!), password: newPassword);
      }
      notifyListeners();
      return null;
    }
    return _cloudAccountError(remote) ??
        remote.error ??
        'Não foi possível mudar a senha.';
  }

  String? _cloudAccountError(AccountResult remote) {
    if (!remote.reachable) {
      return 'Sem conexão com a nuvem. Tente de novo com internet: '
          'a conta precisa ser salva na nuvem para valer em todos os aparelhos.';
    }
    final error = (remote.error ?? '').toLowerCase();
    if (remote.wrongPassword ||
        error.contains('senha atual incorreta') ||
        error.contains('senha incorreta')) {
      return 'A senha atual não confere com a da nuvem. Digite a senha que '
          'funciona nos outros aparelhos.';
    }
    return null;
  }

  Future<String?> _enter(AppUser matched, {String? password}) async {
    if (password != null) _sessionPassword = password;
    matched = canonicalSessionUser(matched);
    matched = _applyRosterPermissions(matched);
    user = matched;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, matched.email);
    await prefs.setString(_profileKey, jsonEncode(matched.toJson()));
    await _loadStores(matched);
    final refreshed = _applyRosterPermissions(user!);
    if (refreshed.permissions != user!.permissions) {
      user = refreshed;
      await prefs.setString(_profileKey, jsonEncode(refreshed.toJson()));
    }
    notifyListeners();
    return null;
  }

  Future<void> _loadStores(AppUser matched, {bool waitStaff = true}) async {
    final snap = await AccountApi.instance.snapshot();
    await Future.wait([
      FieldStore.instance.load(
        matched.email,
        seeAll: matched.seesAllFieldOs,
        login: matched.login,
        aliases: matched.aliases,
        viewerIds: assigneeKeysFor(matched),
        remoteOrders: snap.ok ? snap.orders : null,
      ),
      ClientStore.instance.load(remoteClients: snap.ok ? snap.clients : null),
      CalibrationCatalog.instance.load(
        remoteStandards: snap.ok ? snap.standards : null,
        remoteFluids: snap.ok ? snap.fluids : null,
      ),
      CalibrationStore.instance.load(
        remoteCalibrations: snap.ok ? snap.calibrations : null,
        remoteDeletedIds: snap.ok ? snap.deletedCalibrationIds : null,
      ),
    ]);
    await ClientStore.instance.importFromOrders(
      FieldStore.instance.officeItems,
    );
    if (snap.ok) CloudSyncGate.markSynced();
    if (snap.ok && snap.users.isNotEmpty) {
      await StaffStore.instance.applyResult(snap);
    } else if (waitStaff) {
      await StaffStore.instance.refresh();
    } else {
      StaffStore.instance.refresh();
    }
  }

  Future<void> signOut() async {
    user = null;
    _sessionPassword = null;
    CloudSyncGate.clear();
    FieldStore.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_profileKey);
    notifyListeners();
  }

  @visibleForTesting
  void resetForTests() {
    user = null;
    greetWithFullName = false;
    _sessionPassword = null;
    _identityPatches = {};
    _passOverrides = {};
  }
}
