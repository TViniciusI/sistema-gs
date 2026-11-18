import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/core/app_version.dart';
import 'package:http/http.dart' as http;

/// Avisa quando o site tem publicação mais nova que a deste navegador.
/// O PWA offline-first segue rodando a versão em cache até recarregar.
///
/// `version.json` (build Flutter) usa o `+N` do pubspec. O `appBuild` em
/// `app_version.dart` **precisa** ser o mesmo N — senão a faixa amarela
/// fica presa para sempre (ex.: json 287 vs app 286 na 1.2.94).
class AppUpdate extends ChangeNotifier {
  AppUpdate._();
  static final instance = AppUpdate._();

  String _newVersion = '';
  int _newBuild = 0;
  var _checking = false;

  bool get available => _newBuild > appBuild && _newVersion.isNotEmpty;
  String get newVersion => _newVersion;

  void _clearBanner() {
    if (_newBuild == 0 && _newVersion.isEmpty) return;
    _newBuild = 0;
    _newVersion = '';
    notifyListeners();
  }

  Future<void> check() async {
    if (!kIsWeb || _checking) return;
    _checking = true;
    try {
      // Query diferente de ?v= passa direto pelo service worker do Flutter.
      final uri = Uri.base
          .resolve('version.json')
          .replace(
            queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
          );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (data is! Map) return;
      final build = int.tryParse('${data['build_number']}') ?? 0;
      final version = '${data['version'] ?? ''}'.trim();
      // Já estamos nesta publicação (ou mais nova): some a faixa.
      if (build <= 0 || build <= appBuild) {
        _clearBanner();
        return;
      }
      if (build == _newBuild && version == _newVersion) return;
      _newBuild = build;
      _newVersion = version.isEmpty ? 'nova' : version;
      notifyListeners();
    } catch (error) {
      debugPrint('AppUpdate: $error');
    } finally {
      _checking = false;
    }
  }
}
