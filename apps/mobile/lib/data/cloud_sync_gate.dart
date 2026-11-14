import 'package:flutter/foundation.dart';

/// Evita sync/rede repetido logo após o login (snapshot) ou sync manual.
class CloudSyncGate {
  CloudSyncGate._();

  static DateTime? _lastFullSyncAt;
  static const _freshFor = Duration(seconds: 90);
  static var _localOnly = false;

  /// Sincronização completa rodando em segundo plano (abertura do app).
  static final syncing = ValueNotifier<bool>(false);

  static bool get pending => syncing.value;
  static set pending(bool value) => syncing.value = value;

  static void markSynced() {
    _lastFullSyncAt = DateTime.now();
  }

  static void clear() {
    _lastFullSyncAt = null;
    pending = false;
  }

  /// Carrega só o que está salvo no aparelho; a nuvem vem depois.
  static Future<T> localOnly<T>(Future<T> Function() run) async {
    _localOnly = true;
    try {
      return await run();
    } finally {
      _localOnly = false;
    }
  }

  /// true = dados ainda frescos; pode pular list*/pull de rede.
  static bool get isFresh {
    if (_localOnly) return true;
    final at = _lastFullSyncAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _freshFor;
  }
}
