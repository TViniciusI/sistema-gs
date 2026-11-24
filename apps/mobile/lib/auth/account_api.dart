import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:gs_mobile/auth/gas_http.dart';
import 'package:gs_mobile/core/app_version.dart';
import 'package:gs_mobile/core/config.dart';
import 'package:gs_mobile/data/office_mailto.dart';
import 'package:gs_mobile/data/work_schedule.dart';

String passwordHash(String login, String password) {
  return sha256
      .convert(utf8.encode('gs-campo|${login.trim().toLowerCase()}|$password'))
      .toString();
}

Set<String> passwordIdentities({
  required String login,
  String email = '',
  Iterable<String> extraLogins = const [],
}) {
  final ids = <String>{
    login.trim().toLowerCase(),
    email.trim().toLowerCase(),
    ...extraLogins.map((item) => item.trim().toLowerCase()),
  };
  if (email.contains('@')) {
    ids.add(email.split('@').first.trim().toLowerCase());
  }
  if (isPrincipalIdentity(email: email, login: login)) {
    ids.addAll(const {'gssolucoes', 'gs', 'administrativo'});
  }
  if (isCleberIdentity(email: email, login: login)) {
    ids.addAll(const {
      'cleber',
      'cleber guimarães',
      'cleber guimaraes',
      'cleberguimaraes',
    });
  }
  if (login.trim().toLowerCase() == 'vinicius' ||
      email.trim().toLowerCase() == developerEmail) {
    ids.add('vinicius');
  }
  ids.removeWhere((item) => item.isEmpty);
  return ids;
}

Set<String> passwordHashCandidates({
  required String password,
  required String login,
  String email = '',
  Iterable<String> extraLogins = const [],
}) {
  return {
    for (final id in passwordIdentities(
      login: login,
      email: email,
      extraLogins: extraLogins,
    ))
      passwordHash(id, password),
  };
}

const companyOwnerEmail = 'administrativo@gssolucoestec.com.br';
const cleberEmail = 'cleber@gssolucoestec.com.br';
const developerEmail = 'viniciusmagalhaes2y@gmail.com';
const companyOwnerEmails = {companyOwnerEmail, cleberEmail};

bool isPrincipalIdentity({required String email, required String login}) {
  final mail = email.trim().toLowerCase();
  final user = login.trim().toLowerCase();
  if (mail == companyOwnerEmail) return true;
  return user == 'gssolucoes' ||
      user == 'gs' ||
      user == 'administrativo' ||
      user == 'gs soluções' ||
      user == 'gs solucoes';
}

bool isCleberIdentity({required String email, required String login}) {
  final mail = email.trim().toLowerCase();
  final user = login.trim().toLowerCase();
  if (mail == cleberEmail) return true;
  if (user == 'cleber') return true;
  final compact = user.replaceAll(RegExp(r'[\s._-]+'), '');
  if (compact == 'cleber' || compact.startsWith('cleberguimar')) {
    return true;
  }
  if (user.startsWith('cleber ') ||
      user.startsWith('cleber_') ||
      user.startsWith('cleber-') ||
      user.startsWith('cleber.')) {
    return true;
  }
  return mail.split('@').first == 'cleber';
}

bool isCompanyOwnerIdentity({required String email, required String login}) {
  return isPrincipalIdentity(email: email, login: login) ||
      isCleberIdentity(email: email, login: login);
}

bool isDeveloperIdentity({required String email, required String login}) {
  final mail = email.trim().toLowerCase();
  final user = login.trim().toLowerCase();
  if (mail == developerEmail) return true;
  if (user == 'vinicius') return true;
  if (user.split(RegExp(r'[\s._-]+')).first == 'vinicius') return true;
  return mail.split('@').first == 'viniciusmagalhaes2y';
}

enum CalibrationAccess { none, fill, issue }

bool calibrationAccessLocked({required String email, required String login}) {
  return isCleberIdentity(email: email, login: login) ||
      isPrincipalIdentity(email: email, login: login) ||
      isDeveloperIdentity(email: email, login: login);
}

CalibrationAccess parseCalibrationAccess(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'preencher':
    case 'fill':
    case 'usar':
      return CalibrationAccess.fill;
    case 'emitir':
    case 'issue':
    case 'certificado':
      return CalibrationAccess.issue;
    default:
      return CalibrationAccess.none;
  }
}

CalibrationAccess resolvedCalibrationAccess({
  required CalibrationAccess stored,
  required String email,
  required String login,
}) {
  if (calibrationAccessLocked(email: email, login: login)) {
    return CalibrationAccess.issue;
  }
  return stored;
}

String calibrationAccessToSheet(CalibrationAccess access) {
  switch (access) {
    case CalibrationAccess.none:
      return 'nao';
    case CalibrationAccess.fill:
      return 'preencher';
    case CalibrationAccess.issue:
      return 'emitir';
  }
}

String calibrationAccessLabel(CalibrationAccess access) {
  switch (access) {
    case CalibrationAccess.none:
      return 'Sem acesso';
    case CalibrationAccess.fill:
      return 'Preencher e enviar';
    case CalibrationAccess.issue:
      return 'Emitir certificado';
  }
}

String? reservedSignupError({required String email, required String login}) {
  final mail = email.trim().toLowerCase();
  final user = login.trim().toLowerCase();
  final mailUser = mail.split('@').first;
  if (mail == cleberEmail || mailUser == 'cleber') {
    return 'Este e-mail é do Cleber. Use outro e-mail para cadastrar.';
  }
  if (mail == companyOwnerEmail ||
      isPrincipalIdentity(email: mail, login: '')) {
    return 'Este e-mail é do acesso principal da GS Soluções. Use outro e-mail.';
  }
  if (mail == developerEmail) {
    return 'Este e-mail é do desenvolvedor. Use outro e-mail para cadastrar.';
  }
  if (isCleberIdentity(email: '', login: user) ||
      user.split(RegExp(r'[\s._-]+')).first == 'cleber') {
    return 'O login cleber já existe. Use outro usuário.';
  }
  if (isPrincipalIdentity(email: '', login: user) ||
      user.split(RegExp(r'[\s._-]+')).first == 'gssolucoes') {
    return 'Este usuário é do acesso principal. Use outro login.';
  }
  if (user == 'vinicius' ||
      user.split(RegExp(r'[\s._-]+')).first == 'vinicius') {
    return 'Este usuário é do desenvolvedor. Use outro login.';
  }
  return null;
}

const Map<String, String> staffModuleLabels = {
  'clientes': 'Clientes e Sistemas',
  'gerar_os': 'Gerar OS e Propostas',
  'pesquisar_os': 'Pesquisar e Reativar OS',
  'tecnico': 'Área do Técnico (RDO de Campo)',
  'calibracao': 'Calibração (Preencher)',
  'emitir_cert': 'Emitir Certificados de Calibração',
  'tabelas': 'Tabelas de Vazão',
  'documentos': 'Meus Documentos (RH)',
  'horas': 'Análise de Horas da Equipe',
  'funcionarios': 'Gestão de Funcionários e Acessos',
};

class RemoteAccount {
  const RemoteAccount({
    required this.email,
    required this.login,
    required this.name,
    required this.phone,
    required this.role,
    required this.status,
    required this.active,
    this.funcao = '',
    this.cargo = '',
    this.calibrationAccess = CalibrationAccess.none,
    this.permissions = 'geral',
    this.schedules = const [],
  });

  final String email;
  final String login;
  final String name;
  final String phone;
  final String role;
  final String status;
  final bool active;
  final String funcao;
  final String cargo;
  final CalibrationAccess calibrationAccess;
  final String permissions;
  final List<WorkSchedulePeriod> schedules;

  bool get isGeneralAccess {
    final clean = permissions.trim().toLowerCase();
    return clean.isEmpty || clean == 'geral' || clean == 'todos';
  }

  List<String> get permissionList {
    if (isGeneralAccess) return staffModuleLabels.keys.toList();
    return [
      for (final p in permissions.split(','))
        if (p.trim().isNotEmpty) p.trim().toLowerCase(),
    ];
  }

  bool hasPermission(String key) {
    if (isGeneralAccess) return true;
    return permissionList.contains(key.trim().toLowerCase());
  }

  String get permissionsSummary {
    if (isGeneralAccess) return 'Acesso Geral';
    final list = permissionList;
    if (list.isEmpty) return 'Nenhum módulo liberado';
    final names = [
      for (final k in list)
        if (staffModuleLabels.containsKey(k)) staffModuleLabels[k]! else k,
    ];
    return names.join(', ');
  }

  RemoteAccount copyWith({
    String? email,
    String? login,
    String? name,
    String? phone,
    String? role,
    String? status,
    bool? active,
    String? funcao,
    String? cargo,
    CalibrationAccess? calibrationAccess,
    String? permissions,
    List<WorkSchedulePeriod>? schedules,
  }) {
    return RemoteAccount(
      email: email ?? this.email,
      login: login ?? this.login,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      active: active ?? this.active,
      funcao: funcao ?? this.funcao,
      cargo: cargo ?? this.cargo,
      calibrationAccess: calibrationAccess ?? this.calibrationAccess,
      permissions: permissions ?? this.permissions,
      schedules: schedules ?? this.schedules,
    );
  }

  factory RemoteAccount.fromJson(Map<String, dynamic> json) {
    return RemoteAccount(
      email: (json['email'] as String? ?? '').trim().toLowerCase(),
      login: (json['login'] as String? ?? '').trim().toLowerCase(),
      name: (json['name'] as String? ?? json['nome'] as String? ?? '').trim(),
      phone: (json['phone'] as String? ?? json['telefone'] as String? ?? '')
          .trim(),
      role: (json['role'] as String? ?? json['papel'] as String? ?? 'tecnico')
          .trim()
          .toLowerCase(),
      status: (json['status'] as String? ?? 'aprovado').trim().toLowerCase(),
      active: json['active'] == true || json['ativo'] == true,
      funcao: (json['funcao'] as String? ?? json['função'] as String? ?? '')
          .trim(),
      cargo: (json['cargo'] as String? ?? '').trim(),
      calibrationAccess: parseCalibrationAccess(
        json['calibracao']?.toString() ?? json['calibrationAccess']?.toString(),
      ),
      permissions:
          (json['permissoes']?.toString() ??
                  json['permissions']?.toString() ??
                  'geral')
              .trim(),
      schedules: decodeWorkSchedules(
        json['jornada'] ?? json['schedules'] ?? json['carga'],
      ),
    );
  }
}

class AccountResult {
  const AccountResult({
    required this.ok,
    this.error,
    this.pending = false,
    this.sent = false,
    this.wrongPassword = false,
    this.reachable = true,
    this.skipped = false,
    this.remoteUpdatedAt,
    this.user,
    this.users = const [],
    this.orders = const [],
    this.clients = const [],
    this.standards = const [],
    this.calibrations = const [],
    this.deletedCalibrationIds = const [],
    this.fluids = const [],
    this.docs = const [],
    this.message,
    this.connected = false,
    this.clientId,
    this.folderUrl,
    this.account,
    this.deployerEmail,
    this.folderOwnerEmail,
    this.wrongOwner = false,
    this.warning,
    this.existingFiles = const [],
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.needsReconnect = false,
    this.confidential = false,
    this.legacyScript = false,
    this.fileData,
    this.fileName,
  });

  final bool ok;
  final String? error;
  final bool pending;
  final bool sent;
  final bool wrongPassword;
  final bool reachable;
  /// Gate preservou versão mais nova (ex.: exclusão no escritório).
  final bool skipped;
  final String? remoteUpdatedAt;
  final RemoteAccount? user;
  final List<RemoteAccount> users;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> standards;
  final List<Map<String, dynamic>> calibrations;

  /// Certificados excluídos na nuvem — o app apaga do cache e não reenvia.
  final List<String> deletedCalibrationIds;
  final List<Map<String, dynamic>> fluids;
  final List<Map<String, dynamic>> docs;
  final String? message;
  final bool connected;
  final String? clientId;
  final String? folderUrl;
  final String? account;

  /// Conta que implantou o Apps Script (deve ser administrativo@).
  final String? deployerEmail;

  /// Dono da pasta das OS no Drive (deve ser administrativo@).
  final String? folderOwnerEmail;

  /// Script ou pasta ainda não estão sob administrativo@.
  final bool wrongOwner;
  final String? warning;
  final List<String> existingFiles;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final bool needsReconnect;
  final bool confidential;

  /// Script publicado ainda é o antigo (OneDrive); falta colar o novo.
  final bool legacyScript;
  final String? fileData;
  final String? fileName;
}

class AccountApi {
  AccountApi._();
  static final instance = AccountApi._();

  static var useRemote = true;

  Future<AccountResult> signup({
    required String name,
    required String login,
    required String password,
    required String phone,
    required String email,
    required String role,
  }) {
    return _call({
      'action': 'signup',
      'name': name.trim(),
      'login': login.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'role': role,
      'passHash': passwordHash(login, password),
    });
  }

  Future<AccountResult> login(
    String login,
    String password, {
    String email = '',
    Iterable<String> extraLogins = const [],
  }) {
    final hashes = password.isEmpty
        ? <String>{}
        : passwordHashCandidates(
            password: password,
            login: login,
            email: email,
            extraLogins: extraLogins,
          );
    // Planilha fria passa de 15 s; desistir cedo caía na senha antiga do app.
    return _call({
      'action': 'login',
      'login': login.trim(),
      'passHash': password.isEmpty ? '' : passwordHash(login, password),
      'passHashes': hashes.join(','),
    }, timeout: const Duration(seconds: 45));
  }

  Future<AccountResult> listUsers() {
    return _call({'action': 'users', 'token': AppConfig.loginGateToken});
  }

  Future<AccountResult> decide({
    required String email,
    required String status,
    required String role,
    String? permissions,
  }) {
    return _call({
      'action': 'decide',
      'token': AppConfig.loginGateToken,
      'email': email,
      'status': status,
      'role': role,
      if (permissions != null && permissions.isNotEmpty)
        'permissoes': permissions,
    });
  }

  Future<AccountResult> setPermissions({
    required String email,
    required String permissions,
  }) {
    return _call({
      'action': 'setpermissoes',
      'token': AppConfig.loginGateToken,
      'email': email,
      'permissoes': permissions,
    });
  }

  Future<AccountResult> setRole({required String email, required String role}) {
    return _call({
      'action': 'setpapel',
      'token': AppConfig.loginGateToken,
      'email': email,
      'role': role,
    });
  }

  Future<AccountResult> setFuncao({
    required String email,
    required String funcao,
  }) {
    return _call({
      'action': 'setfuncao',
      'token': AppConfig.loginGateToken,
      'email': email,
      'funcao': funcao,
    });
  }

  Future<AccountResult> setCargo({
    required String email,
    required String cargo,
  }) {
    return _call({
      'action': 'setcargo',
      'token': AppConfig.loginGateToken,
      'email': email,
      'cargo': cargo,
    });
  }

  Future<AccountResult> setSchedules({
    required String email,
    required List<WorkSchedulePeriod> schedules,
  }) {
    return _call({
      'action': 'setjornada',
      'token': AppConfig.loginGateToken,
      'email': email,
      'jornada': encodeWorkSchedules(schedules),
    });
  }

  Future<AccountResult> setCalibrationAccess({
    required String email,
    required CalibrationAccess access,
  }) {
    return _call({
      'action': 'setcalibracao',
      'token': AppConfig.loginGateToken,
      'email': email,
      'calibracao': calibrationAccessToSheet(access),
    });
  }

  Future<AccountResult> requestClientSign({
    required String osId,
    required String osNumber,
    required List<String> rdoIds,
  }) {
    return _call({
      'action': 'signrequest',
      'token': AppConfig.loginGateToken,
      'osId': osId,
      'osNumber': osNumber,
      'rdoIds': rdoIds.join(','),
    });
  }

  Future<AccountResult> setActive({
    required String email,
    required bool active,
  }) {
    return _call({
      'action': 'setativo',
      'token': AppConfig.loginGateToken,
      'email': email,
      'value': active ? '1' : '0',
    });
  }

  Future<AccountResult> updateProfile({
    required String email,
    required String login,
    required String password,
    required String name,
    required String newLogin,
    required String newEmail,
    required String phone,
    String passHash = '',
    Iterable<String> extraLogins = const [],
  }) {
    final hashes = passwordHashCandidates(
      password: password,
      login: login,
      email: email,
      extraLogins: [newLogin, ...extraLogins],
    );
    return _call({
      'action': 'setperfil',
      'cmd': 'setperfil',
      'email': email.trim().toLowerCase(),
      'login': login.trim().toLowerCase(),
      'passHash': passHash.isEmpty ? passwordHash(login, password) : passHash,
      'passHashes': hashes.join(','),
      'name': name.trim(),
      'newLogin': newLogin.trim().toLowerCase(),
      'newEmail': newEmail.trim().toLowerCase(),
      'phone': phone.trim(),
      'newPassHash': password.isEmpty ? '' : passwordHash(newLogin, password),
    });
  }

  Future<AccountResult> changePassword({
    required String email,
    required String login,
    required String currentPassword,
    required String newPassword,
    String? newLogin,
    String passHash = '',
    Iterable<String> extraLogins = const [],
  }) {
    final nextLogin = (newLogin ?? login).trim().toLowerCase();
    final hashes = passwordHashCandidates(
      password: currentPassword,
      login: login,
      email: email,
      extraLogins: extraLogins,
    );
    return _call({
      'action': 'setsenha',
      'cmd': 'setsenha',
      'email': email.trim().toLowerCase(),
      'login': login.trim().toLowerCase(),
      'passHash': passHash.isEmpty
          ? passwordHash(login, currentPassword)
          : passHash,
      'passHashes': hashes.join(','),
      'newLogin': nextLogin,
      'newPassHash': passwordHash(nextLogin, newPassword),
    });
  }

  Future<AccountResult> saveWorkOrder(Map<String, String> fields) {
    return _sendFlexible({'action': 'saveos', ...fields});
  }

  Future<AccountResult> saveDailyRdo(Map<String, String> fields) {
    return _sendFlexible({'action': 'saverdo', ...fields});
  }

  Future<AccountResult> listWorkOrders() {
    return _call({'action': 'listos'}, timeout: const Duration(seconds: 45));
  }

  Future<AccountResult> getWorkOrder(String id) {
    return _call({
      'action': 'getos',
      'id': id,
    }, timeout: const Duration(seconds: 45));
  }

  Future<AccountResult> deleteWorkOrder(String id) {
    return _sendFlexible({'action': 'deleteos', 'id': id});
  }

  Future<AccountResult> snapshot() {
    return _call({
      'action': 'snapshot',
      'token': AppConfig.loginGateToken,
    }, timeout: const Duration(seconds: 90));
  }

  Future<AccountResult> saveClient(Map<String, String> fields) {
    return _sendFlexible({'action': 'saveclient', ...fields});
  }

  Future<AccountResult> listClients() {
    return _call({
      'action': 'listclients',
    }, timeout: const Duration(seconds: 45));
  }

  Future<AccountResult> getClient(String id) {
    return _call({
      'action': 'getclient',
      'id': id,
    }, timeout: const Duration(seconds: 45));
  }

  Future<AccountResult> deleteClient(String id) {
    return _sendFlexible({'action': 'deleteclient', 'id': id});
  }

  Future<AccountResult> saveStandard(Map<String, String> fields) {
    return _sendFlexible({'action': 'savestandard', ...fields});
  }

  Future<AccountResult> listStandards() {
    return _call({'action': 'liststandards'});
  }

  Future<AccountResult> deleteStandard(String id) {
    return _sendFlexible({'action': 'deletestandard', 'id': id});
  }

  Future<AccountResult> saveFluid(Map<String, String> fields) {
    return _sendFlexible({'action': 'savefluid', ...fields});
  }

  Future<AccountResult> listFluids() {
    return _call({'action': 'listfluids'});
  }

  Future<AccountResult> deleteFluid(String id) {
    return _sendFlexible({'action': 'deletefluid', 'id': id});
  }

  Future<AccountResult> saveCalibrationJob(Map<String, String> fields) {
    return _sendFlexible({'action': 'savecalib', ...fields});
  }

  Future<AccountResult> listCalibrationJobs() {
    return _call({'action': 'listcalib'});
  }

  Future<AccountResult> deleteCalibrationJob(String id) {
    return _sendFlexible({'action': 'deletecalib', 'id': id});
  }

  Future<AccountResult> sendOfficeMail({
    required String osId,
    required String osNumber,
    required String subject,
    required String body,
    String replyTo = '',
    List<String> to = const [],
    List<String> cc = const [],
    List<String> extraTo = const [],
    required List<OfficeMailFile> files,
  }) async {
    if (!useRemote || AppConfig.loginGateUrl.isEmpty) {
      return const AccountResult(
        ok: false,
        reachable: false,
        error: 'Planilha não ligada neste build.',
      );
    }
    try {
      final payload = <String, dynamic>{
        'action': 'sendmail',
        'token': AppConfig.loginGateToken,
        'osId': osId,
        'osNumber': osNumber,
        'subject': subject,
        'body': body,
        'replyTo': replyTo,
        if (to.isNotEmpty) 'to': to,
        if (cc.isNotEmpty) 'cc': cc,
        if (extraTo.isNotEmpty) 'extraTo': extraTo,
        'files': [
          for (final file in files)
            {
              'name': file.name,
              'mime': officeFileMime(file.name),
              'data': base64Encode(file.bytes),
            },
        ],
      };
      await Future<void>.delayed(Duration.zero);
      // PDF em base64 pode passar de alguns MB — dá mais tempo no 4G.
      final raw = await gasPost(
        Uri.parse(AppConfig.loginGateUrl),
        jsonEncode(payload),
        timeout: const Duration(seconds: 60),
        allowOpaque: true,
      );
      final parsed = _readJson(raw);
      if (parsed != null && parsed['opaque'] != true) {
        if (isFakeMailStatus(parsed)) {
          return const AccountResult(
            ok: false,
            error:
                'O script da planilha ainda não lê o envio do RDO. Cole o login_gate.gs e publique Nova versão no mesmo lápis.',
          );
        }
        final result = _resultFrom(parsed);
        if (result.sent) {
          final attached = parsed['files'];
          if (files.isNotEmpty &&
              attached is num &&
              attached.toInt() <= 0) {
            return const AccountResult(
              ok: false,
              error:
                  'O e-mail saiu sem o PDF do RDO. Atualize o script da planilha '
                  '(login_gate.gs → Nova versão) e tente de novo.',
            );
          }
          return result;
        }
        if (result.error != null && !result.pending) {
          return result;
        }
      }
      return _waitMailStatus(osId);
    } catch (error) {
      debugPrint('AccountApi sendmail: $error');
      return AccountResult(
        ok: false,
        reachable: false,
        error: 'Não foi possível enviar o e-mail. $error',
      );
    }
  }

  Future<AccountResult> saveStaffDoc({
    required String id,
    required String staffEmail,
    required String name,
    required List<int> bytes,
    String kind = 'certificate',
    bool requiresSignature = false,
    String createdAt = '',
  }) {
    return _postJson({
      'action': 'savestaffdoc',
      'token': AppConfig.loginGateToken,
      'id': id,
      'staffEmail': staffEmail.trim().toLowerCase(),
      'name': name,
      'kind': kind,
      'requiresSignature': requiresSignature ? 'sim' : 'nao',
      if (createdAt.trim().isNotEmpty) 'createdAt': createdAt,
      'mime': officeFileMime(name),
      'data': base64Encode(bytes),
    });
  }

  /// A planilha leva 5–15 s nesta lista (mais no 4G / script frio).
  Future<AccountResult> listStaffDocs({String staffEmail = ''}) {
    return _call({
      'action': 'liststaffdocs',
      'token': AppConfig.loginGateToken,
      if (staffEmail.trim().isNotEmpty)
        'staffEmail': staffEmail.trim().toLowerCase(),
    }, timeout: const Duration(seconds: 45));
  }

  Future<AccountResult> getStaffDoc(String id) {
    return _postJson({
      'action': 'getstaffdoc',
      'token': AppConfig.loginGateToken,
      'id': id,
    });
  }

  Future<AccountResult> deleteStaffDoc(String id) {
    return _postJson({
      'action': 'deletestaffdoc',
      'token': AppConfig.loginGateToken,
      'id': id,
    });
  }

  Future<AccountResult> signStaffDoc({
    required String id,
    required String signedBy,
    String signedAt = '',
    List<int>? signPdfBytes,
    String signName = '',
  }) {
    return _postJson({
      'action': 'signstaffdoc',
      'token': AppConfig.loginGateToken,
      'id': id,
      'signedBy': signedBy,
      if (signedAt.trim().isNotEmpty) 'signedAt': signedAt,
      if (signPdfBytes != null && signPdfBytes.isNotEmpty) ...{
        'signName': signName.trim().isEmpty
            ? 'assinatura_$id.pdf'
            : signName.trim(),
        'signMime': 'application/pdf',
        'signData': base64Encode(signPdfBytes),
      },
    });
  }

  /// Pasta dos arquivos das OS no Google Drive do escritório.
  Future<AccountResult> driveStatus() async {
    final result = await _call({
      'action': 'drivestatus',
      'token': AppConfig.loginGateToken,
    });
    // "Ação inválida" chega aqui como reachable=false sem erro.
    if (result.reachable || result.error != null) return result;
    final legacy = await _call({
      'action': 'onedrivestatus',
      'token': AppConfig.loginGateToken,
    });
    return AccountResult(
      ok: legacy.ok,
      reachable: legacy.reachable,
      connected: legacy.connected,
      error: legacy.error,
      account: legacy.account,
      legacyScript: true,
    );
  }

  Future<AccountResult> saveOsToDrive({
    required String osId,
    required String osNumber,
    required List<Map<String, String>> files,
    String conflict = 'replace',
  }) async {
    if (!useRemote || AppConfig.loginGateUrl.isEmpty) {
      return const AccountResult(
        ok: false,
        reachable: false,
        error: 'Planilha não ligada neste build.',
      );
    }
    AccountResult? last;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
      last = await _saveOsToDriveOnce(
        osId: osId,
        osNumber: osNumber,
        files: files,
        conflict: conflict,
      );
      if (last.sent == true || last.ok == true) return last;
      final err = (last.error ?? '').toLowerCase();
      final rateLimited =
          err.contains('limite') ||
          err.contains('limit') ||
          err.contains('rate') ||
          err.contains('muitas vezes');
      final storageFull =
          err.contains('armazenamento') ||
          err.contains('storage') ||
          err.contains('quota') ||
          err.contains('cheio');
      if (storageFull || !rateLimited) return last;
    }
    return last ??
        const AccountResult(
          ok: false,
          reachable: true,
          error: 'Não salvou no Google Drive.',
        );
  }

  Future<AccountResult> _saveOsToDriveOnce({
    required String osId,
    required String osNumber,
    required List<Map<String, String>> files,
    required String conflict,
  }) async {
    try {
      final payload = <String, dynamic>{
        'action': 'saveosfolder',
        'token': AppConfig.loginGateToken,
        'osId': osId,
        'osNumber': osNumber,
        'conflict': conflict,
        'files': files,
      };
      final raw = await gasPost(
        Uri.parse(AppConfig.loginGateUrl),
        jsonEncode(payload),
        timeout: const Duration(seconds: 90),
        allowOpaque: true,
      );
      final parsed = _readJson(raw);
      if (parsed != null && parsed['opaque'] != true) {
        final result = _resultFrom(parsed);
        if (result.sent || (result.error != null && !result.pending)) {
          return result;
        }
      }
      return _waitOsFolderStatus(osId);
    } catch (error) {
      debugPrint('AccountApi saveosfolder: $error');
      return AccountResult(
        ok: false,
        reachable: false,
        error: 'Não foi possível salvar no Google Drive. $error',
      );
    }
  }

  Future<AccountResult> checkOsFolderFiles({
    required String osId,
    required String osNumber,
    required List<Map<String, String>> files,
  }) async {
    return _postJson({
      'action': 'checkosfolder',
      'token': AppConfig.loginGateToken,
      'osId': osId,
      'osNumber': osNumber,
      'files': files,
    });
  }

  Future<AccountResult> _waitOsFolderStatus(String osId) async {
    AccountResult last = const AccountResult(
      ok: false,
      pending: true,
      error: 'Ainda salvando no Google Drive.',
    );
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      last = await _call({
        'action': 'osfolderstatus',
        'token': AppConfig.loginGateToken,
        'osId': osId,
      });
      if (last.sent) return last;
      if (isUnsupportedSheetAction(last.error)) {
        return AccountResult(
          ok: false,
          error:
              'O script ainda não salva no Google Drive. Cole o login_gate.gs e publique Nova versão.',
        );
      }
      if (!last.pending && last.error != null) return last;
    }
    return last.sent
        ? last
        : AccountResult(
            ok: false,
            error:
                last.error ??
                'O Google Drive não confirmou. Atualize o script e tente de novo.',
          );
  }

  Future<AccountResult> _sendFlexible(Map<String, dynamic> payload) async {
    final asStrings = <String, String>{};
    var totalLen = 0;
    for (final entry in payload.entries) {
      final val = entry.value?.toString() ?? '';
      asStrings[entry.key] = val;
      totalLen += entry.key.length + val.length;
    }
    // Requisições leves (< 6KB) usam JSONP via _call para garantir 100% de sucesso no navegador sem bloqueio de CORS
    if (totalLen < 6000) {
      try {
        final getRes = await _call(asStrings);
        if (getRes.ok) return getRes;
      } catch (_) {}
    }
    return _postJson(payload);
  }

  Future<AccountResult> _postJson(Map<String, dynamic> payload) async {
    if (!useRemote || AppConfig.loginGateUrl.isEmpty) {
      return const AccountResult(
        ok: false,
        reachable: false,
        error: 'Planilha não ligada neste build.',
      );
    }
    try {
      final raw = await gasPost(
        Uri.parse(AppConfig.loginGateUrl),
        jsonEncode({...payload, 'appBuild': '$appBuild'}),
        timeout: const Duration(seconds: 90),
        allowOpaque: true,
      );
      final parsed = _readJson(raw);
      final action = '${payload['action'] ?? ''}'.toLowerCase();
      final opaque = parsed == null || parsed['opaque'] == true;
      if (opaque) {
        // Salvamentos críticos não podem assumir sucesso em resposta opaca.
        if (action.contains('save') ||
            action.contains('put') ||
            action.contains('delete')) {
          return const AccountResult(
            ok: false,
            reachable: true,
            error:
                'A planilha não confirmou. Atualize o login_gate.gs (Nova versão) e tente de novo.',
          );
        }
        return const AccountResult(ok: true, reachable: true);
      }
      return _resultFrom(parsed!);
    } catch (error) {
      return AccountResult(
        ok: false,
        reachable: false,
        error: 'Não conectou à planilha. $error',
      );
    }
  }

  Future<AccountResult> _waitMailStatus(String osId) async {
    AccountResult last = const AccountResult(
      ok: false,
      pending: true,
      error: 'Ainda enviando o e-mail.',
    );
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      last = await _call({
        'action': 'mailstatus',
        'token': AppConfig.loginGateToken,
        'osId': osId,
      });
      if (last.sent) return last;
      if (isUnsupportedSheetAction(last.error)) return last;
      if (!last.pending && last.error != null) return last;
    }
    return last.sent
        ? last
        : AccountResult(
            ok: false,
            error:
                last.error ??
                'O e-mail não saiu. Atualize o script da planilha e tente de novo.',
          );
  }

  AccountResult _resultFrom(Map<String, dynamic> payload) {
    final users = <RemoteAccount>[];
    final rawUsers = payload['users'];
    if (rawUsers is List) {
      for (final item in rawUsers) {
        if (item is Map) {
          users.add(RemoteAccount.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    RemoteAccount? user;
    if (payload['user'] is Map) {
      user = RemoteAccount.fromJson(
        Map<String, dynamic>.from(payload['user'] as Map),
      );
    }
    final orders = _mapList(payload['orders']);
    final clients = _mapList(payload['clients']);
    final standards = _mapList(payload['standards']);
    final calibrations = _mapList(payload['calibrations']);
    final fluids = _mapList(payload['fluids']);
    final docs = _mapList(payload['docs']);
    final error = payload['error']?.toString();
    final unsupported = isUnsupportedSheetAction(error);
    return AccountResult(
      ok: payload['ok'] == true && !unsupported,
      sent: payload['sent'] == true,
      error: unsupported ? null : friendlySheetError(error),
      pending: payload['pending'] == true,
      wrongPassword: payload['wrongPassword'] == true,
      reachable: !unsupported,
      skipped: payload['skipped'] == true,
      remoteUpdatedAt: payload['updatedAt']?.toString(),
      user: user,
      users: users,
      orders: orders,
      clients: clients,
      standards: standards,
      calibrations: calibrations,
      deletedCalibrationIds: _stringList(payload['deletedCalibrationIds']),
      fluids: fluids,
      docs: docs,
      message:
          payload['to']?.toString() ??
          payload['message']?.toString() ??
          payload['folderUrl']?.toString(),
      connected: payload['connected'] == true,
      clientId: payload['clientId']?.toString(),
      folderUrl: payload['folderUrl']?.toString(),
      account: payload['account']?.toString(),
      deployerEmail: payload['deployerEmail']?.toString(),
      folderOwnerEmail: payload['folderOwnerEmail']?.toString(),
      wrongOwner: driveOwnerIsWrong(
        flag: payload['wrongOwner'] == true,
        account: payload['account']?.toString(),
        deployerEmail: payload['deployerEmail']?.toString(),
        folderOwnerEmail: payload['folderOwnerEmail']?.toString(),
      ),
      warning: driveOwnerWarningText(
        warning: payload['warning']?.toString(),
        account: payload['account']?.toString(),
        deployerEmail: payload['deployerEmail']?.toString(),
        folderOwnerEmail: payload['folderOwnerEmail']?.toString(),
        wrongOwnerFlag: payload['wrongOwner'] == true,
      ),
      existingFiles: _stringList(payload['existing']),
      needsReconnect: payload['needsReconnect'] == true,
      confidential: payload['confidential'] == true,
      fileData: payload['fileData']?.toString(),
      fileName: payload['fileName']?.toString(),
    );
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if ('$item'.trim().isNotEmpty) '$item'.trim(),
    ];
  }

  Future<AccountResult> _call(
    Map<String, String> params, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!useRemote || AppConfig.loginGateUrl.isEmpty) {
      return const AccountResult(
        ok: false,
        reachable: false,
        error: 'Planilha não ligada neste build.',
      );
    }
    try {
      final uri = Uri.parse(
        AppConfig.loginGateUrl,
      ).replace(queryParameters: {...params, 'appBuild': '$appBuild'});
      final body = await gasGet(uri, timeout: timeout);
      final payload = _readJson(body);
      if (payload == null) {
        return const AccountResult(
          ok: false,
          reachable: false,
          error:
              'A planilha pediu login do Google. Implante o script com acesso: Qualquer pessoa.',
        );
      }
      return _resultFrom(payload);
    } catch (error) {
      debugPrint('AccountApi: $error');
      return const AccountResult(
        ok: false,
        reachable: false,
        error: 'Não foi possível falar com a planilha.',
      );
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Map<String, dynamic>? _readJson(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('<')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}

bool isFakeMailStatus(Map<String, dynamic> payload) {
  if (payload['sent'] == true) return false;
  return payload.containsKey('cleberBlocked') ||
      (payload['ok'] == true &&
          !payload.containsKey('files') &&
          payload['pending'] != true &&
          payload['error'] == null);
}

bool isUnsupportedSheetAction(String? error) {
  final value = (error ?? '').trim().toLowerCase();
  if (value.isEmpty) return false;
  return value == 'ação inválida' ||
      value == 'acao invalida' ||
      value.contains('ação inválida');
}

bool isPersonalDriveScriptAccount(String? email) {
  final raw = (email ?? '').trim().toLowerCase();
  if (raw.isEmpty) return false;
  if (raw == companyOwnerEmail) return false;
  return raw.contains('vinicius') || raw.endsWith('@gmail.com');
}

bool driveOwnerIsWrong({
  required bool flag,
  String? account,
  String? deployerEmail,
  String? folderOwnerEmail,
}) {
  if (flag) return true;
  if (isPersonalDriveScriptAccount(deployerEmail)) return true;
  if (isPersonalDriveScriptAccount(account)) return true;
  final folder = (folderOwnerEmail ?? '').trim().toLowerCase();
  if (folder.isNotEmpty && folder != companyOwnerEmail) return true;
  return false;
}

String? driveOwnerWarningText({
  String? warning,
  String? account,
  String? deployerEmail,
  String? folderOwnerEmail,
  bool wrongOwnerFlag = false,
}) {
  final fromScript = (warning ?? '').trim();
  if (fromScript.isNotEmpty) return fromScript;
  if (!driveOwnerIsWrong(
    flag: wrongOwnerFlag,
    account: account,
    deployerEmail: deployerEmail,
    folderOwnerEmail: folderOwnerEmail,
  )) {
    return null;
  }
  final who = (deployerEmail ?? account ?? '').trim();
  if (who.isNotEmpty && isPersonalDriveScriptAccount(who)) {
    return 'O Apps Script ainda grava como $who. '
        'O espaço do administrativo@ não conta. '
        'Publique o login_gate.gs logado em $companyOwnerEmail '
        '(dono único do projeto) e transfira a pasta das OS.';
  }
  return 'O dono do Drive/Apps Script ainda não é $companyOwnerEmail. '
      'Transfira pasta e script para essa conta (dono único).';
}

String? friendlySheetError(String? error) {
  if (error == null || error.trim().isEmpty) return error;
  final lower = error.toLowerCase();
  if (lower.contains('sem acesso à pasta de arquivos')) {
    return 'O script do Google não tem acesso à pasta de arquivos das OS. '
        'Ele precisa estar implantado com a conta dona da pasta no Google Drive.';
  }
  // Mensagem já montada pelo script novo (cota da conta dona).
  if (lower.contains('armazenamento cheio') ||
      (lower.contains('esvazie a lixeira') &&
          lower.contains('administrativo@') &&
          !lower.contains('deveria ser'))) {
    return 'O Google Drive da empresa está sem espaço. '
        'Esvazie a lixeira e libere espaço na conta '
        'administrativo@gssolucoestec.com.br, depois tente de novo.';
  }
  // "Limite excedido: Drive" no Apps Script quase sempre é a conta que
  // IMPLANTOU o script (ainda pode ser Gmail pessoal), não o administrativo@.
  if (lower.contains('limite excedido') ||
      lower.contains('limit exceeded') ||
      lower.contains('quota') ||
      lower.contains('storage')) {
    return 'O Google Drive recusou o envio (limite da conta que roda o Apps Script). '
        'Hoje o script ainda pode estar no Gmail pessoal — o espaço do '
        'administrativo@ não conta. Publique o login_gate.gs logado em '
        'administrativo@gssolucoestec.com.br (dono único) e tente de novo.';
  }
  return error;
}
