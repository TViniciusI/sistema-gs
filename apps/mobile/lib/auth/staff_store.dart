import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/auth/account_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffStore extends ChangeNotifier {
  StaffStore._();
  static final instance = StaffStore._();

  static const _cacheKey = 'gs_staff_users';

  List<RemoteAccount> users = [];
  String? lastError;

  List<RemoteAccount> get pending => [
    for (final user in _normalized)
      if (user.status == 'pendente') user,
  ];

  List<RemoteAccount> get employees => [
    for (final user in _normalized)
      if (user.status == 'aprovado') user,
  ];

  List<RemoteAccount> get technicianAccounts => [
    for (final user in employees)
      if (user.active &&
          (user.role == 'tecnico' ||
              user.role == 'dev' ||
              user.role == 'ambos' ||
              isCleberIdentity(email: user.email, login: user.login)))
        user,
  ];

  List<RemoteAccount> get rejected => [
    for (final user in _normalized)
      if (user.status == 'recusado') user,
  ];

  List<RemoteAccount> get directory => [..._normalized];

  List<RemoteAccount> get _normalized {
    return [for (final user in users) _canonicalize(user)];
  }

  RemoteAccount _canonicalize(RemoteAccount user) {
    if (isPrincipalIdentity(email: user.email, login: user.login)) {
      final login = user.login;
      final migratedLogin = login.isEmpty ||
              login == 'cleber' ||
              login == 'administrativo'
          ? 'gssolucoes'
          : login;
      final name = user.name.trim();
      final migratedName = name.isEmpty || name == 'Cleber Guimarães'
          ? 'GS Soluções'
          : name;
      return user.copyWith(
        email: companyOwnerEmail,
        login: migratedLogin,
        name: migratedName,
        role: 'admin',
        status: user.status == 'pendente' ? 'pendente' : 'aprovado',
        active: true,
      );
    }
    if (isCleberIdentity(email: user.email, login: user.login)) {
      final login = user.login;
      final migratedLogin = login.isEmpty ||
              login.startsWith('cleber ') ||
              login.startsWith('dup-')
          ? 'cleber'
          : login;
      return user.copyWith(
        email: user.email.isEmpty ? cleberEmail : user.email,
        login: migratedLogin,
        name: user.name.isEmpty ? 'Cleber Guimarães' : user.name,
        role: user.role == 'dev' ? 'dev' : 'ambos',
        status: user.status == 'pendente' ? 'pendente' : 'aprovado',
        active: true,
      );
    }
    return user;
  }

  Future<void> loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      users = [
        for (final item in decoded)
          RemoteAccount.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> applyResult(AccountResult result) async {
    if (!result.ok) {
      lastError = result.error;
      notifyListeners();
      return;
    }
    if (result.users.isNotEmpty) {
      users = result.users;
      lastError = null;
      await _persist();
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> patchFuncao(String email, String funcao) async {
    final key = email.trim().toLowerCase();
    users = [
      for (final user in users)
        user.email == key || user.login == key
            ? user.copyWith(funcao: funcao.trim())
            : user,
    ];
    lastError = null;
    await _persist();
    notifyListeners();
  }

  Future<void> patchCargo(String email, String cargo) async {
    final key = email.trim().toLowerCase();
    users = [
      for (final user in users)
        user.email == key || user.login == key
            ? user.copyWith(cargo: cargo.trim())
            : user,
    ];
    lastError = null;
    await _persist();
    notifyListeners();
  }

  Future<void> patchCalibrationAccess(
    String email,
    CalibrationAccess access,
  ) async {
    final key = email.trim().toLowerCase();
    users = [
      for (final user in users)
        user.email == key || user.login == key
            ? user.copyWith(calibrationAccess: access)
            : user,
    ];
    lastError = null;
    await _persist();
    notifyListeners();
  }

  Future<void> patchPermissions(String email, String permissions) async {
    final key = email.trim().toLowerCase();
    users = [
      for (final user in users)
        user.email == key || user.login == key
            ? user.copyWith(permissions: permissions.trim())
            : user,
    ];
    lastError = null;
    await _persist();
    notifyListeners();
  }

  Future<void> refresh() async {
    final result = await AccountApi.instance.listUsers();
    if (!result.ok) {
      lastError = result.error;
      notifyListeners();
      return;
    }
    users = result.users;
    lastError = null;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode([
        for (final user in users)
          {
            'email': user.email,
            'login': user.login,
            'name': user.name,
            'phone': user.phone,
            'role': user.role,
            'status': user.status,
            'active': user.active,
            'funcao': user.funcao,
            'cargo': user.cargo,
            'calibracao': calibrationAccessToSheet(user.calibrationAccess),
            'permissoes': user.permissions,
          },
      ]),
    );
  }
}
