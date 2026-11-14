import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gs_mobile/core/app_version.dart';
import 'package:http/http.dart' as http;

/// Avisa quando o site tem publicação mais nova que a deste navegador.
/// O PWA offline-first segue rodando a versão em cache até recarregar.
class AppUpdate extends ChangeNotifier {
  AppUpdate._();
  static final instance = AppUpdate._();

  String _newVersion = '';
  int _newBuild = 0;
  var _checking = false;

  bool get available => _newBuild > appBuild;
  String get newVersion => _newVersion;

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
      if (build <= _newBuild || build <= appBuild) return;
      _newBuild = build;
      _newVersion = '${data['version'] ?? ''}';
      notifyListeners();
    } catch (error) {
      debugPrint('AppUpdate: $error');
    } finally {
      _checking = false;
    }
  }
}
