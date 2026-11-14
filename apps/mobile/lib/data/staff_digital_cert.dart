import 'dart:convert';

import 'package:gs_mobile/auth/staff_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E-mails com certificado digital ICP-Brasil cadastrado.
/// Enquanto não houver, o PDF assinado usa assinatura eletrônica.
const _prefsKey = 'gs_staff_digital_certs';

Set<String> _digitalEmails = {};
var _loaded = false;

Future<void> loadStaffDigitalCertificates() async {
  if (_loaded) return;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null || raw.isEmpty) {
    _digitalEmails = {};
    _loaded = true;
    return;
  }
  try {
    final list = jsonDecode(raw);
    if (list is List) {
      _digitalEmails = {
        for (final item in list)
          if ('$item'.trim().contains('@')) '$item'.trim().toLowerCase(),
      };
    }
  } catch (_) {
    _digitalEmails = {};
  }
  _loaded = true;
}

Future<void> setStaffDigitalCertificate(String email, bool enabled) async {
  await loadStaffDigitalCertificates();
  final key = email.trim().toLowerCase();
  if (!key.contains('@')) return;
  if (enabled) {
    _digitalEmails.add(key);
  } else {
    _digitalEmails.remove(key);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, jsonEncode(_digitalEmails.toList()..sort()));
}

bool staffEmailHasDigitalCertificate(String email) {
  final key = email.trim().toLowerCase();
  if (!key.contains('@')) return false;
  return _digitalEmails.contains(key);
}

/// Quem já tem ICP-Brasil: deixa espaço para assinatura digital.
/// Quem não tem: carimbo eletrônico no PDF quando o usuário pede “assinado”.
bool personHasDigitalCertificate({String email = '', String name = ''}) {
  final mail = email.trim().toLowerCase();
  if (mail.contains('@') && _digitalEmails.contains(mail)) return true;
  final want = personFoldKey(name);
  if (want.isEmpty) return false;
  for (final user in StaffStore.instance.employees) {
    if (!staffEmailHasDigitalCertificate(user.email)) continue;
    if (personFoldKey(user.name) == want) return true;
  }
  return false;
}

String personFoldKey(String raw) {
  return raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c');
}

String? staffEmailForName(String name) {
  final want = personFoldKey(name);
  if (want.isEmpty) return null;
  for (final user in StaffStore.instance.employees) {
    if (personFoldKey(user.name) == want) return user.email;
  }
  return null;
}

String staffCargoForName(String name, {String fallback = defaultTechnicianCargo}) {
  final want = personFoldKey(name);
  if (want.isEmpty) return fallback;
  for (final user in StaffStore.instance.employees) {
    if (personFoldKey(user.name) != want) continue;
    final cargo = user.cargo.trim();
    if (cargo.isNotEmpty) return cargo;
  }
  return fallback;
}
