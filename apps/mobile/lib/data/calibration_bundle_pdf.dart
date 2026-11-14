import 'dart:typed_data';

import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/gs_brand_pdf.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

/// Ordem dos tipos no livro (volumétrica → temperatura → densidade → demais).
int calibrationBundleKindOrder(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
    case CalibrationKind.volumetricInverted:
      return 0;
    case CalibrationKind.temperature:
    case CalibrationKind.temperatureMesh:
      return 1;
    case CalibrationKind.density:
      return 2;
    case CalibrationKind.pressure:
      return 3;
    case CalibrationKind.conductivity:
      return 4;
    case CalibrationKind.telemetry:
      return 5;
  }
}

String calibrationBundleKindTitle(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
      return 'Calibração volumétrica';
    case CalibrationKind.volumetricInverted:
      return 'Calibração volumétrica (invertida)';
    case CalibrationKind.temperature:
      return 'Calibração de temperatura';
    case CalibrationKind.temperatureMesh:
      return 'Calibração de malha de temperatura';
    case CalibrationKind.density:
      return 'Calibração de densidade';
    case CalibrationKind.pressure:
      return 'Calibração de pressão';
    case CalibrationKind.conductivity:
      return 'Calibração de condutividade';
    case CalibrationKind.telemetry:
      return 'Calibração de telemetria';
  }
}

/// Local do cadastro (plataforma/ilha). Nunca endereço nem "In Loco".
String calibrationBundleLocationLabel(
  CalibrationJob job, {
  SavedClient? client,
}) {
  final local = calibrationSystemLocal(job, client: client);
  if (local.isNotEmpty) return local;
  return 'Sem local do sistema';
}

String calibrationBundleFileName({
  required String osNumber,
  String requester = '',
}) {
  final os = osNumber.trim().isEmpty
      ? 'OS'
      : osNumber.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  final who = requester
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), '_');
  if (who.isEmpty) return 'Book_Certificado_Calibracao_$os.pdf';
  return 'Book_Certificado_Calibracao_${who}_$os.pdf';
}

/// Garante a identidade da lista (TAG/N/S/preset do certificado) antes do livro.
/// Não puxa o medidor de outra plataforma só porque divide o mesmo local.
CalibrationJob prepareJobForCertificateBundle(CalibrationJob job) {
  return prepareCertificateJob(job);
}

class CalibrationBundleLocationGroup {
  CalibrationBundleLocationGroup(this.location);
  final String location;
  final Map<CalibrationKind, List<CalibrationJob>> byKind = {};
}

List<CalibrationBundleLocationGroup> groupJobsForCertificateBundle(
  List<CalibrationJob> jobs,
) {
  final prepared = [
    for (final job in jobs) prepareJobForCertificateBundle(job),
  ];

  // 1ª passagem: resolve local de cada certificado.
  final resolvedJobs = <CalibrationJob>[];
  final presetToLocal = <String, String>{};
  for (final job in prepared) {
    final client = ClientStore.instance.byId(job.clientId) ??
        ClientStore.instance.findMatch(
          cnpj: job.clientCnpj,
          name: job.clientName,
        );
    var resolved = resolveCertificateInstallLocation(job, client: client);
    if (resolved.isEmpty) {
      final slot = slotLinkedToCalibrationJob(job);
      final slotLocal = slot?.installLocation.trim() ?? '';
      if (isUsefulSystemLocal(
            slotLocal,
            site: job.site,
            client: client,
            clientName: job.clientName,
            serviceRequester: job.serviceRequester,
          ) &&
          !installLocationLooksLikePresetTag(job, slotLocal)) {
        resolved = normalizeInstallLocationLabel(slotLocal);
      }
    }
    final withLocal = resolved.isNotEmpty
        ? job.copyWith(installLocation: resolved)
        : job;
    resolvedJobs.add(withLocal);
    final preset = calibrationIdentityKey(withLocal.presetTag);
    if (preset.isNotEmpty &&
        resolved.isNotEmpty &&
        resolved != 'Sem local do sistema') {
      presetToLocal.putIfAbsent(preset, () => resolved);
    }
  }

  // 2ª passagem: mesmo preset herda a ilha já resolvida (vol/temp/dens juntos).
  final byLocation = <String, CalibrationBundleLocationGroup>{};
  for (final job in resolvedJobs) {
    final client = ClientStore.instance.byId(job.clientId) ??
        ClientStore.instance.findMatch(
          cnpj: job.clientCnpj,
          name: job.clientName,
        );
    var local = calibrationSystemLocal(job, client: client);
    if (local.isEmpty) {
      final preset = calibrationIdentityKey(job.presetTag);
      local = presetToLocal[preset] ?? '';
    }
    final withLocal = local.isNotEmpty
        ? job.copyWith(installLocation: local)
        : job;
    final location = calibrationBundleLocationLabel(withLocal, client: client);
    final groupKey = calibrationIdentityKey(location);
    final group = byLocation.putIfAbsent(
      groupKey,
      () => CalibrationBundleLocationGroup(location),
    );
    group.byKind.putIfAbsent(withLocal.kind, () => []).add(withLocal);
  }

  int certOrder(String raw) {
    final digits = RegExp(r'(\d+)(?!.*\d)').firstMatch(raw)?.group(1);
    return int.tryParse(digits ?? '') ?? 0;
  }

  final groups = byLocation.values.toList()
    ..sort((a, b) => compareInstallLocationLabels(a.location, b.location));

  for (final group in groups) {
    for (final entry in group.byKind.entries) {
      entry.value.sort((a, b) {
        final byNum = certOrder(a.number).compareTo(certOrder(b.number));
        if (byNum != 0) return byNum;
        return a.number.toLowerCase().compareTo(b.number.toLowerCase());
      });
    }
  }
  return groups;
}

Future<Uint8List> _buildBundleCoverPdf({
  required String requesterName,
  required String clientName,
  required String osNumber,
  required String issuedDate,
}) async {
  await loadGsBrandPdf();
  final doc = pw.Document();
  final requester = requesterName.trim();
  final coverLogo = gsPdfLogoWidget(height: 48, cover: true);
  doc.addPage(
    pw.Page(
      pageTheme: gsCoverTheme(),
      build: (_) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (coverLogo != null)
              coverLogo
            else
              pw.Text(
                'GS SOLUÇÕES',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfGoldLight,
                ),
              ),
            pw.Spacer(flex: 2),
            pw.Text(
              'BOOK DE CERTIFICADO DE CALIBRAÇÃO',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfGoldLight,
                letterSpacing: 1.8,
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Container(width: 52, height: 3.2, color: gsPdfPrimaryGold),
            pw.SizedBox(height: 18),
            pw.Text(
              'CERTIFICADO',
              style: pw.TextStyle(
                fontSize: 36,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfTextLight,
                letterSpacing: 1.4,
                height: 1.05,
              ),
            ),
            pw.Text(
              'DE',
              style: pw.TextStyle(
                fontSize: 36,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfTextLight,
                letterSpacing: 1.4,
                height: 1.05,
              ),
            ),
            pw.Text(
              'CALIBRAÇÃO',
              style: pw.TextStyle(
                fontSize: 36,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfGoldLight,
                letterSpacing: 1.4,
                height: 1.05,
              ),
            ),
            if (requester.isNotEmpty) ...[
              pw.SizedBox(height: 22),
              pw.Text(
                'SOLICITANTE',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryGold,
                  letterSpacing: 1.6,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: gsPdfPrimaryGold, width: 1.1),
                ),
                child: pw.Text(
                  requester.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: gsPdfTextLight,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
            pw.Spacer(flex: 3),
            if (clientName.trim().isNotEmpty) ...[
              pw.Text(
                'CONTRATANTE',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryGold,
                  letterSpacing: 1.6,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                gsCertPrint(clientName),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfTextLight,
                ),
              ),
              pw.SizedBox(height: 12),
            ],
            if (osNumber.trim().isNotEmpty) ...[
              pw.Text(
                'ORDEM DE SERVIÇO',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryGold,
                  letterSpacing: 1.6,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                osNumber.trim(),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfTextLight,
                ),
              ),
              pw.SizedBox(height: 12),
            ],
            pw.Text(
              'DATA DE EMISSÃO',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfPrimaryGold,
                letterSpacing: 1.6,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              issuedDate,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfTextLight,
              ),
            ),
          ],
        );
      },
    ),
  );
  return doc.save();
}

Future<Uint8List> _buildLetterheadSeparatorPdf({
  required String kicker,
  required String title,
  String subtitle = '',
  String osNumber = '',
}) async {
  await loadGsBrandPdf();
  final doc = pw.Document();
  final cleanSubtitle = subtitle.trim();
  final cleanOs = osNumber.trim();
  // Evita OS duplicada (subtitle "OS …" + rodapé).
  final subtitleLooksLikeOs = cleanSubtitle.toLowerCase().startsWith('os ');
  final showSubtitle =
      cleanSubtitle.isNotEmpty && !subtitleLooksLikeOs;
  doc.addPage(
    pw.Page(
      pageTheme: gsCertificateTheme(),
      build: (_) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.SizedBox(height: 8),
            if (gsPdfLogoWidget(height: 34) case final logo?)
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: logo,
              ),
            pw.Spacer(flex: 2),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    kicker.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: gsPdfGoldDeep,
                      letterSpacing: 2.4,
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Container(width: 56, height: 2.6, color: gsPdfPrimaryGold),
                  pw.SizedBox(height: 18),
                  pw.Text(
                    title,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: gsPdfPrimaryDark,
                      letterSpacing: 0.6,
                      height: 1.15,
                    ),
                  ),
                  if (showSubtitle) ...[
                    pw.SizedBox(height: 12),
                    pw.Text(
                      cleanSubtitle,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: gsPdfMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.Spacer(flex: 3),
            if (cleanOs.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  'OS $cleanOs',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: gsPdfMuted,
                  ),
                ),
              ),
            pw.SizedBox(height: 8),
          ],
        );
      },
    ),
  );
  return doc.save();
}

Future<Uint8List> _buildBundleFinalPdf({required String issuedDate}) async {
  await loadGsBrandPdf();
  final doc = pw.Document();
  final coverLogo = gsPdfLogoWidget(height: 42, cover: true);
  doc.addPage(
    pw.Page(
      pageTheme: gsCoverTheme(),
      build: (_) {
        pw.Widget row(String label, String value) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 7),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$label: ',
                    style: pw.TextStyle(
                      font: gsPdfBold,
                      fontSize: 10.5,
                      color: gsPdfGoldLight,
                    ),
                  ),
                  pw.TextSpan(
                    text: value,
                    style: pw.TextStyle(
                      font: gsPdfRegular,
                      fontSize: 10.5,
                      color: gsPdfTextLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (coverLogo != null)
              coverLogo
            else
              pw.Text(
                'GS SOLUÇÕES',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfGoldLight,
                ),
              ),
            pw.Spacer(flex: 2),
            pw.Text(
              'INFORMAÇÕES',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfGoldLight,
                letterSpacing: 2.4,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(width: 44, height: 2.4, color: gsPdfPrimaryGold),
            pw.SizedBox(height: 18),
            row('Empresa', gsCompanyTradeName),
            row('CNPJ', gsCompanyCnpj),
            row('E-mail', gsCompanyEmail),
            row('Telefone', gsCompanyPhone),
            row('Site', gsCompanySite.replaceFirst(RegExp(r'/$'), '')),
            pw.SizedBox(height: 22),
            pw.Text(
              'Este certificado apresenta os resultados da calibração realizada '
              'nas condições especificadas neste documento. Os resultados são '
              'válidos exclusivamente para o instrumento identificado neste '
              'certificado e nas condições em que o serviço foi executado.',
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: gsPdfTextLight,
                lineSpacing: 1.35,
              ),
            ),
            pw.SizedBox(height: 28),
            pw.Center(
              child: pw.Container(
                width: 120,
                height: 1.2,
                color: gsPdfPrimaryGold,
              ),
            ),
            pw.Spacer(flex: 2),
            pw.Text(
              'Emitido em $issuedDate',
              style: const pw.TextStyle(
                fontSize: 10,
                color: gsPdfGoldLight,
              ),
            ),
          ],
        );
      },
    ),
  );
  return doc.save();
}

/// Monta o livro: capa → (local → tipo → certificados…) → página final.
/// Páginas de local/tipo só entram quando o local ou o tipo muda.
Future<Uint8List> buildCalibrationCertificateBundle({
  required List<CalibrationJob> jobs,
  String requesterName = '',
  String clientName = '',
  String osNumber = '',
  @Deprecated('Use requesterName') String coverPlace = '',
  DateTime? issuedAt,
  bool withSignature = false,
}) async {
  if (jobs.isEmpty) {
    throw StateError('Nenhum certificado para montar o livro.');
  }

  await ClientStore.instance.load();
  // Cadastro completo (ilhas/sistemas) — stub da lista não resolve LOCAL no book.
  // FieldStore já deve estar carregado na sessão (OS/hub); o prepare usa os slots.
  final clientIds = <String>{};
  for (final job in jobs) {
    final id = job.clientId.trim();
    if (id.isNotEmpty) clientIds.add(id);
    final match = (id.isNotEmpty ? ClientStore.instance.byId(id) : null) ??
        ClientStore.instance.findMatch(
          cnpj: job.clientCnpj,
          name: job.clientName,
        );
    final matchId = match?.id.trim() ?? '';
    if (matchId.isNotEmpty) clientIds.add(matchId);
  }
  for (final id in clientIds) {
    // Sem force: nunca sobrescreve cadastro local rico com nuvem incompleta.
    await ClientStore.instance.ensureFull(id);
  }
  final issued = DateFormat('dd/MM/yyyy').format(issuedAt ?? DateTime.now());
  final requester = requesterName.trim().isNotEmpty
      ? requesterName.trim()
      : jobs
          .map((j) => j.serviceRequester.trim())
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
  final client = clientName.trim().isNotEmpty
      ? clientName.trim()
      : jobs
          .map((j) => j.clientName.trim())
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
  final os = osNumber.trim().isNotEmpty
      ? osNumber.trim()
      : jobs
          .map((j) => j.osNumber.trim())
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');

  final parts = <Uint8List>[
    await _buildBundleCoverPdf(
      requesterName: requester,
      clientName: client,
      osNumber: os,
      issuedDate: issued,
    ),
  ];

  final groups = groupJobsForCertificateBundle(jobs);
  for (final group in groups) {
    // Uma página de local só quando muda o local de instalação do cadastro.
    parts.add(
      await _buildLetterheadSeparatorPdf(
        kicker: 'Local da instalação',
        title: group.location,
        osNumber: os,
      ),
    );

    final kinds = group.byKind.keys.toList()
      ..sort(
        (a, b) =>
            calibrationBundleKindOrder(a).compareTo(calibrationBundleKindOrder(b)),
      );

    for (final kind in kinds) {
      final kindJobs = group.byKind[kind] ?? const <CalibrationJob>[];
      if (kindJobs.isEmpty) continue;
      // Uma página de tipo por local — certificados seguem em sequência.
      parts.add(
        await _buildLetterheadSeparatorPdf(
          kicker: 'Tipo de calibração',
          title: calibrationBundleKindTitle(kind),
          subtitle: group.location,
          osNumber: os,
        ),
      );
      for (final job in kindJobs) {
        parts.add(
          await buildCalibrationCertificate(
            job,
            withSignature: withSignature,
            signedAt: issuedAt,
          ),
        );
      }
    }
  }

  parts.add(await _buildBundleFinalPdf(issuedDate: issued));
  return mergeCalibrationPdfs(parts);
}
