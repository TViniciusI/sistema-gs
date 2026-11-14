import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_store.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/calibration/calibration_job_page.dart';
import 'package:gs_mobile/features/os/os_hub_page.dart';
import 'package:web/web.dart' as web;

/// Lê `?cert=` / `?os=` do QR do adesivo e abre o registro no app (web).
Future<void> consumeCalibrationQrDeepLink(BuildContext context) async {
  final user = AuthSession.instance.user;
  if (user == null) return;

  final uri = Uri.base;
  final cert = (uri.queryParameters['cert'] ?? '').trim();
  final osId = (uri.queryParameters['osId'] ?? '').trim();
  final osNumber = (uri.queryParameters['os'] ?? '').trim();
  final abrir = (uri.queryParameters['abrir'] ?? '').trim().toLowerCase();
  if (cert.isEmpty && osId.isEmpty && osNumber.isEmpty) return;
  if (abrir.isNotEmpty && abrir != 'cert' && abrir != 'os' && abrir != 'app') {
    return;
  }

  _clearDeepLinkQuery();

  await CalibrationStore.instance.load();
  if (FieldStore.instance.officeItems.isEmpty &&
      FieldStore.instance.items.isEmpty) {
    await FieldStore.instance.load(
      user.email,
      seeAll: user.seesAllFieldOs,
      login: user.login,
      aliases: user.aliases,
    );
  }
  if (!context.mounted) return;

  if (cert.isNotEmpty) {
    final job = CalibrationStore.instance.byNumber(cert);
    if (job != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CalibrationJobPage(jobId: job.id),
        ),
      );
      return;
    }
  }

  final foundOs = _findOs(osId: osId, osNumber: osNumber);
  if (foundOs != null) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OsHubPage(
          osId: foundOs.id,
          officeMode: user.seesAllFieldOs,
        ),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: GsTheme.navy,
      content: Text(
        cert.isNotEmpty
            ? 'QR do adesivo: certificado $cert não encontrado neste aparelho. Sincronize a nuvem e tente de novo.'
            : 'QR do adesivo: OS não encontrada neste aparelho.',
      ),
    ),
  );
}

SavedOs? _findOs({required String osId, required String osNumber}) {
  if (osId.isNotEmpty) {
    final byId = FieldStore.instance.byId(osId);
    if (byId != null) return byId;
  }
  final needle = osNumber.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final item in [
    ...FieldStore.instance.items,
    ...FieldStore.instance.officeItems,
  ]) {
    if (item.number.trim().toLowerCase() == needle) return item;
  }
  return null;
}

void _clearDeepLinkQuery() {
  try {
    final path = web.window.location.pathname;
    web.window.history.replaceState(null, web.document.title, path);
  } catch (_) {}
}
