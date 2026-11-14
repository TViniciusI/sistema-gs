import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/auth/gas_http.dart';
import 'package:gs_mobile/core/config.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessGate extends ChangeNotifier {
  AccessGate._();
  static final instance = AccessGate._();

  static const _blockedKey = 'gs_cleber_blocked';

  var cleberBlocked = false;
  var remoteLinked = false;
  String? lastError;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    cleberBlocked = prefs.getBool(_blockedKey) ?? false;
    notifyListeners();
    // Não segura a abertura esperando o Apps Script responder.
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final url = AppConfig.loginGateUrl;
    if (url.isEmpty) {
      remoteLinked = false;
      notifyListeners();
      _kickClientIfNeeded();
      return;
    }
    try {
      final uri = Uri.parse(url).replace(queryParameters: {'action': 'status'});
      final body = await gasGet(uri);
      final payload = _readJson(body);
      if (payload == null) {
        lastError =
            'A planilha pediu login do Google. No Apps Script, implante de novo com acesso: Qualquer pessoa.';
        remoteLinked = false;
      } else if (payload['ok'] == true) {
        cleberBlocked = payload['cleberBlocked'] == true;
        remoteLinked = true;
        lastError = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_blockedKey, cleberBlocked);
      } else {
        lastError = payload['error']?.toString();
      }
    } catch (error) {
      lastError = 'Não foi possível falar com a planilha.';
      debugPrint('AccessGate.refresh: $error');
    }
    notifyListeners();
    _kickClientIfNeeded();
  }

  Future<void> setCleberBlocked(bool blocked) async {
    cleberBlocked = blocked;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blockedKey, blocked);
    notifyListeners();
    _kickClientIfNeeded();

    final url = AppConfig.loginGateUrl;
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url).replace(
        queryParameters: {
          'action': 'block',
          'value': blocked ? '1' : '0',
          'token': AppConfig.loginGateToken,
        },
      );
      final body = await gasGet(uri);
      final payload = _readJson(body);
      if (payload == null) {
        lastError =
            'A planilha pediu login do Google. Implante de novo com acesso: Qualquer pessoa.';
        remoteLinked = false;
      } else {
        remoteLinked = payload['ok'] == true;
        lastError = remoteLinked ? null : payload['error']?.toString();
      }
    } catch (error) {
      lastError = 'Bloqueio salvo neste aparelho. A planilha não respondeu.';
      debugPrint('AccessGate.setCleberBlocked: $error');
    }
    notifyListeners();
  }

  void _kickClientIfNeeded() {
    final current = AuthSession.instance.user;
    if (cleberBlocked && current != null && current.isClient) {
      AuthSession.instance.signOut();
    }
  }

  Map<String, dynamic>? _readJson(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('<')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
