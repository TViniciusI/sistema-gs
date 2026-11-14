import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const officeRdosPrefsKey = 'gs_office_rdos';
const workOrdersPrefsKey = 'gs_work_orders_v2';
const calibrationDoneBackupsPrefsKey = 'gs_calibration_done_backups_v1';
const staffDocsPrefsKey = 'gs_staff_docs_v1';

/// localStorage is ~5 MB. PDFs in JSON blow that quota.
const maxPrefsJsonChars = 700000;

dynamic stripStoredFileBytes(dynamic value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key.toString() != 'data')
          entry.key.toString(): stripStoredFileBytes(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) stripStoredFileBytes(item)];
  }
  return value;
}

Future<bool> writePrefsString(String key, String value) async {
  try {
    var payload = value;
    if (payload.length > maxPrefsJsonChars) {
      try {
        payload = jsonEncode(stripStoredFileBytes(jsonDecode(payload)));
      } catch (_) {}
    }
    if (payload.length > maxPrefsJsonChars && key != workOrdersPrefsKey) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(key, payload);
  } catch (_) {
    return false;
  }
}

Future<bool> writePrefsJson(String key, Object payload) {
  return writePrefsString(key, jsonEncode(stripStoredFileBytes(payload)));
}

Future<void> removePrefsKey(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  } catch (_) {}
}

Future<String?> readPrefsString(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    if (raw.length <= maxPrefsJsonChars) return raw;
    try {
      final compact = jsonEncode(stripStoredFileBytes(jsonDecode(raw)));
      try {
        await prefs.setString(key, compact);
      } catch (_) {}
      return compact;
    } catch (_) {
      return raw;
    }
  } catch (_) {
    return null;
  }
}

/// Libera o localStorage sem perder dado que só existe no aparelho:
/// cópias de segurança e PDFs de RH que já estão na nuvem.
Future<void> dropBloatedLocalCaches() async {
  await removePrefsKey(officeRdosPrefsKey);
  await removePrefsKey(calibrationDoneBackupsPrefsKey);
  await _dropSyncedStaffDocBytes();
}

Future<void> _dropSyncedStaffDocBytes() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(staffDocsPrefsKey);
    if (raw == null || !raw.contains('"data"')) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    var changed = false;
    final next = [
      for (final item in decoded)
        if (item is Map && item['cloudSynced'] == true && item['data'] != null)
          () {
            changed = true;
            return {
              for (final entry in item.entries)
                if (entry.key.toString() != 'data')
                  entry.key.toString(): entry.value,
            };
          }()
        else
          item,
    ];
    if (changed) await prefs.setString(staffDocsPrefsKey, jsonEncode(next));
  } catch (_) {}
}
